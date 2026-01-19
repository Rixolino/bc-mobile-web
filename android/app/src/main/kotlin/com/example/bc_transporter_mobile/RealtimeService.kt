package com.example.bc_transporter_mobile

import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.isActive
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import android.util.Log
import java.util.concurrent.TimeUnit

class RealtimeService : Service() {
    private val client = OkHttpClient.Builder().connectTimeout(10, TimeUnit.SECONDS).build()
    private var scope: CoroutineScope? = null
    private var job: Job? = null

    // Keep track of last known counts for stop-specific and station monitoring
    private val lastStopCounts = mutableMapOf<String, Int>()
    private val lastStationCounts = mutableMapOf<String, Int>()

    // Persistent cache for last fetched responses (so changes persist across restarts)
    private lateinit var prefs: android.content.SharedPreferences

    // Monitored targets persistence
    private fun getMonitoredStopsMap(): MutableMap<String, String> {
        val json = prefs.getString("monitored_stops", null) ?: return mutableMapOf()
        val obj = JSONObject(json)
        val map = mutableMapOf<String, String>()
        val keys = obj.keys()
        while (keys.hasNext()) {
            val k = keys.next()
            map[k] = obj.optString(k)
        }
        return map
    }

    private fun setMonitoredStopsMap(map: Map<String, String>) {
        val obj = JSONObject()
        for ((k, v) in map) obj.put(k, v)
        prefs.edit().putString("monitored_stops", obj.toString()).apply()
    }

    private fun addMonitoredStop(stopId: String, stopName: String?) {
        val map = getMonitoredStopsMap()
        map[stopId] = stopName ?: ""
        setMonitoredStopsMap(map)
        Log.d("RealtimeService", "Added monitored stop: $stopId (${stopName ?: ""})")
    }

    private fun removeMonitoredStop(stopId: String) {
        val map = getMonitoredStopsMap()
        map.remove(stopId)
        setMonitoredStopsMap(map)
    }

    private fun getMonitoredStations(): MutableSet<String> {
        val json = prefs.getString("monitored_stations", null) ?: return mutableSetOf()
        val arr = JSONObject("{\"v\":$json}").optJSONArray("v")
        val set = mutableSetOf<String>()
        if (arr != null) {
            for (i in 0 until arr.length()) set.add(arr.optString(i))
        }
        return set
    }

    private fun setMonitoredStations(set: Set<String>) {
        val arr = org.json.JSONArray()
        for (s in set) arr.put(s)
        prefs.edit().putString("monitored_stations", arr.toString()).apply()
    }

    private fun addMonitoredStation(stationId: String) {
        val set = getMonitoredStations()
        set.add(stationId)
        setMonitoredStations(set)
    }

    private fun removeMonitoredStation(stationId: String) {
        val set = getMonitoredStations()
        set.remove(stationId)
        setMonitoredStations(set)
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
    }

    private fun getCachedStopData(stopId: String): String? = prefs.getString("stop:$stopId", null)
    private fun setCachedStopData(stopId: String, data: String) = prefs.edit().putString("stop:$stopId", data).apply()

    private fun getCachedStationData(stationId: String): String? = prefs.getString("station:$stationId", null)
    private fun setCachedStationData(stationId: String, data: String) = prefs.edit().putString("station:$stationId", data).apply()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == "start") {
            val type = intent.getStringExtra("type") ?: ""
            val intervalSeconds = intent.getIntExtra("intervalSeconds", 30)
            val stopId = intent.getStringExtra("stopId")
            val stopName = intent.getStringExtra("stopName")
            val stationId = intent.getStringExtra("stationId")

            // Persist monitored targets if provided
            if (!stopId.isNullOrEmpty()) addMonitoredStop(stopId, stopName)
            if (!stationId.isNullOrEmpty()) addMonitoredStation(stationId)

            // Save interval setting for the service so it persists across restarts
            if (intervalSeconds > 0) prefs.edit().putInt("service_interval_seconds", intervalSeconds).apply()

            startForegroundWithNotification(type)
            startPolling(type, intent, intervalSeconds)
        } else if (action == "stop") {
            // Stop the whole service (clear in-memory job and keep monitored targets persisted for future restart)
            stopSelf()
        }
        return START_STICKY
    }

    private fun startForegroundWithNotification(type: String) {
        val channel = if (type == "trains") NotificationHelper.CHANNEL_TRAINS else NotificationHelper.CHANNEL_BUSES
        val title = if (type == "trains") "Notifiche treni attive" else "Notifiche autobus attive"
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager

        val builder = NotificationCompat.Builder(this, channel)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText("Servizio attivo per aggiornamenti in tempo reale")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setAutoCancel(false)

        val notification = builder.build()
        startForeground(1001, notification)
    }

    private fun startPolling(type: String, intent: Intent, intervalSeconds: Int) {
        if (job != null) return
        scope = CoroutineScope(Dispatchers.IO)

        // Use saved interval if provided earlier, otherwise the passed value or default
        val savedInterval = prefs.getInt("service_interval_seconds", 0)
        val normalizedInterval = when {
            intervalSeconds > 0 -> intervalSeconds
            savedInterval > 0 -> savedInterval
            else -> 30
        }

        job = scope?.launch {
            Log.d("RealtimeService", "Starting polling loop (interval=${normalizedInterval}s)")
            while (isActive) {
                val startTs = System.currentTimeMillis()

                // First, handle monitored stops (buses)
                val stops = getMonitoredStopsMap()
                if (stops.isNotEmpty()) {
                    for ((id, name) in stops) {
                        try {
                            val url = (intent.getStringExtra("baseUrl") ?: "https://betacloud-transporter.is-cool.dev") + "/api/it/bus/${intent.getStringExtra("provider") ?: "bari"}/stops-updates?stopId=${id}"
                            Log.d("RealtimeService", "Fetching stop updates for $id -> $url")
                            val request = Request.Builder().url(url).get().build()
                            client.newCall(request).execute().use { resp ->
                                if (resp.isSuccessful) {
                                    val body = resp.body?.string() ?: ""
                                    val previousBody = getCachedStopData(id)
                                    if (previousBody != null && previousBody != body) {
                                        Log.d("RealtimeService", "Detected change for stop $id")
                                        val json = JSONObject(body)
                                        val departures = json.optJSONArray("departures")
                                        val items = mutableListOf<String>()
                                        if (departures != null) {
                                            val max = kotlin.math.min(3, departures.length())
                                            for (i in 0 until max) {
                                                val dep = departures.optJSONObject(i)
                                                val line = dep?.optString("line") ?: dep?.optString("lineCode") ?: dep?.optString("route") ?: dep?.optString("lineRef") ?: ""
                                                val time = dep?.optString("time") ?: dep?.optString("scheduledTime") ?: dep?.optString("departureTime") ?: dep?.optString("expectedTime") ?: ""
                                                val dest = dep?.optString("destination") ?: dep?.optString("to") ?: dep?.optString("headsign") ?: ""
                                                val part = listOf(line, time, if (dest.isNotEmpty()) "→ $dest" else "").filter { it.isNotEmpty() }.joinToString(" ")
                                                if (part.isNotEmpty()) items.add(part)
                                            }
                                        }
                                        val bodyText = if (items.isEmpty()) "Nessuna partenza disponibile al momento" else "Prossime partenze: " + items.joinToString(" • ")
                                        val title = if (name.isNotEmpty()) "${name} (${id})" else "Fermata ${id}"
                                        val nid = NotificationHelper.getIdForKey("stop:$id")
                                        NotificationHelper.showNotification(this@RealtimeService, NotificationHelper.CHANNEL_BUSES, title, bodyText, nid)
                                    }
                                    setCachedStopData(id, body)
                                    val json = JSONObject(body)
                                    val departures = json.optJSONArray("departures")
                                    val count = departures?.length() ?: 0
                                    lastStopCounts[id] = count
                                } else {
                                    Log.d("RealtimeService", "Failed to fetch stop $id: HTTP ${resp.code}")
                                }
                            }
                        } catch (e: Exception) {
                            Log.e("RealtimeService", "Error fetching stop $id", e)
                        }
                    }
                } else {
                    Log.d("RealtimeService", "No monitored stops to fetch")
                }

                // Then, handle monitored stations (trains)
                val stations = getMonitoredStations()
                if (stations.isNotEmpty()) {
                    for (sid in stations) {
                        try {
                            val url = "https://prod.cuzimmartin.dev/api/it/departures?stationId=${sid}"
                            Log.d("RealtimeService", "Fetching station updates for $sid -> $url")
                            val request = Request.Builder().url(url).get().build()
                            client.newCall(request).execute().use { resp ->
                                if (resp.isSuccessful) {
                                    val body = resp.body?.string() ?: ""
                                    val previousBody = getCachedStationData(sid)
                                    if (previousBody != null && previousBody != body) {
                                        Log.d("RealtimeService", "Detected change for station $sid")
                                        val json = JSONObject(body)
                                        val departures = json.optJSONArray("departures")
                                        val items = mutableListOf<String>()
                                        if (departures != null) {
                                            val max = kotlin.math.min(3, departures.length())
                                            for (i in 0 until max) {
                                                val dep = departures.optJSONObject(i)
                                                val train = dep?.optString("trainNumber") ?: dep?.optString("service") ?: dep?.optString("train_id") ?: ""
                                                val time = dep?.optString("time") ?: dep?.optString("scheduledTime") ?: dep?.optString("departureTime") ?: ""
                                                val dest = dep?.optString("destination") ?: dep?.optString("to") ?: ""
                                                val part = listOf(train, time, if (dest.isNotEmpty()) "→ $dest" else "").filter { it.isNotEmpty() }.joinToString(" ")
                                                if (part.isNotEmpty()) items.add(part)
                                            }
                                        }
                                        val bodyText = if (items.isEmpty()) "Nessuna partenza disponibile" else "Prossime partenze: " + items.joinToString(" • ")
                                        val title = "Stazione ${sid}"
                                        val nid = NotificationHelper.getIdForKey("station:$sid")
                                        NotificationHelper.showNotification(this@RealtimeService, NotificationHelper.CHANNEL_TRAINS, title, bodyText, nid)
                                    }
                                    setCachedStationData(sid, body)
                                    val json = JSONObject(body)
                                    val departures = json.optJSONArray("departures")
                                    val count = departures?.length() ?: 0
                                    lastStationCounts[sid] = count
                                } else {
                                    Log.d("RealtimeService", "Failed to fetch station $sid: HTTP ${resp.code}")
                                }
                            }
                        } catch (e: Exception) {
                            Log.e("RealtimeService", "Error fetching station $sid", e)
                        }
                    }
                } else {
                    Log.d("RealtimeService", "No monitored stations to fetch")
                }

                // Sleep until next iteration keeping interval consistent
                val elapsed = System.currentTimeMillis() - startTs
                val waitMs = (normalizedInterval * 1000) - elapsed
                if (waitMs > 0) {
                    kotlinx.coroutines.delay(waitMs)
                } else {
                    // if processing took longer than interval, yield briefly so we don't spin
                    kotlinx.coroutines.delay(500)
                }
            }
        }
    }

    override fun onDestroy() {
        job?.cancel()
        scope?.cancel()
        stopForeground(true)
        super.onDestroy()
    }
}
