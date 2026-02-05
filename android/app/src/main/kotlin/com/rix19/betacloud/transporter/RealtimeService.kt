package com.rix19.betacloud.transporter

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
import android.net.Uri
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.Date
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

    // Monitored trips persistence (tripId -> JSON metadata)
    private fun getMonitoredTripsMap(): MutableMap<String, String> {
        val json = prefs.getString("monitored_trips", null) ?: return mutableMapOf()
        val obj = JSONObject(json)
        val map = mutableMapOf<String, String>()
        val keys = obj.keys()
        while (keys.hasNext()) {
            val k = keys.next()
            map[k] = obj.optString(k)
        }
        return map
    }

    private fun setMonitoredTripsMap(map: Map<String, String>) {
        val obj = JSONObject()
        for ((k, v) in map) obj.put(k, v)
        prefs.edit().putString("monitored_trips", obj.toString()).apply()
    }

    private fun addMonitoredTrip(tripId: String, notifyMode: String?, destinationStop: String?, endpoint: String?, country: String?, startingStop: String?) {
        val map = getMonitoredTripsMap()
        val meta = JSONObject()
        if (!notifyMode.isNullOrEmpty()) meta.put("notifyMode", notifyMode)
        if (!destinationStop.isNullOrEmpty()) meta.put("destinationStop", destinationStop)
        if (!endpoint.isNullOrEmpty()) meta.put("endpoint", endpoint)
        if (!country.isNullOrEmpty()) meta.put("country", country)
        if (!startingStop.isNullOrEmpty()) meta.put("startingStop", startingStop)
        map[tripId] = meta.toString()
        setMonitoredTripsMap(map)
        Log.d("RealtimeService", "Added monitored trip: $tripId -> ${meta.toString()}")
    }

    private fun removeMonitoredTrip(tripId: String) {
        val map = getMonitoredTripsMap()
        map.remove(tripId)
        setMonitoredTripsMap(map)
        NotificationHelper.cancelNotificationByKey(this@RealtimeService, "train:$tripId")
        Log.d("RealtimeService", "Removed monitored trip: $tripId")
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
        Log.d("RealtimeService", "Service created, realtime_cache initialized")
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
            val tripId = intent.getStringExtra("tripId")
            val notifyMode = intent.getStringExtra("notifyMode")
            val destinationStop = intent.getStringExtra("destinationStop")
            val endpoint = intent.getStringExtra("endpoint")
            val country = intent.getStringExtra("country")
            val startingStop = intent.getStringExtra("startingStop")
            // Read arrival notice minutes (used to trigger proximity alerts)
            val arrivalNoticeMinutes = intent.getIntExtra("arrivalNoticeMinutes", prefs.getInt("arrival_notice_minutes", 10))

            // Persist monitored targets if provided
            if (!stopId.isNullOrEmpty()) addMonitoredStop(stopId, stopName)
            if (!stationId.isNullOrEmpty()) addMonitoredStation(stationId)
            if (!tripId.isNullOrEmpty()) addMonitoredTrip(tripId, notifyMode, destinationStop, endpoint, country, startingStop)

            // Save interval setting for the service so it persists across restarts
            if (intervalSeconds > 0) prefs.edit().putInt("service_interval_seconds", intervalSeconds).apply()
            // Persist arrival notice preference for service restarts
            prefs.edit().putInt("arrival_notice_minutes", arrivalNoticeMinutes).apply()

            startForegroundWithNotification(type)
            startPolling(type, intent, intervalSeconds)
        } else if (action == "removeTrip") {
            val tripId = intent.getStringExtra("tripId")
            if (!tripId.isNullOrEmpty()) {
                removeMonitoredTrip(tripId)
            }
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
            var lastIterationTs = 0L
            while (isActive) {
                val startTs = System.currentTimeMillis()
                
                // Log intervallo tra le iterazioni
                if (lastIterationTs > 0) {
                    val actualIntervalSec = (startTs - lastIterationTs) / 1000
                    Log.d("RealtimeService", "â•â•â• POLLING ITERATION START â•â•â• (actual interval: ${actualIntervalSec}s, target: ${normalizedInterval}s)")
                }
                lastIterationTs = startTs

                fun formatTimeString(value: String?): String {
                    if (value.isNullOrEmpty()) return ""
                    val v = value.trim()
                    // Accept numeric integers, decimals and scientific notation
                    val numericRegex = Regex("^[0-9]+(\\.[0-9]+)?([eE][+-]?[0-9]+)?$")
                    if (numericRegex.matches(v)) {
                        try {
                            val d = v.toDouble()
                            // Heuristic: if value looks like seconds (< 1e11) treat as seconds, otherwise millis
                            val epochMillis = if (d < 1e11) (d * 1000L).toLong() else d.toLong()
                            val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())
                            return sdf.format(Date(epochMillis))
                        } catch (e: Exception) {
                            // fall through
                        }
                    }
                    // Try ISO-8601 parse (OffsetDateTime or Instant)
                    try {
                        val odt = java.time.OffsetDateTime.parse(v)
                        val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())
                        return sdf.format(Date.from(odt.toInstant()))
                    } catch (e: Exception) {
                        try {
                            val inst = java.time.Instant.parse(v)
                            val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())
                            return sdf.format(Date.from(inst))
                        } catch (e2: Exception) {
                            // fallback to original
                        }
                    }
                    return v
                }

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
                                                val dest = dep?.optString("destination") ?: dep?.optString("to") ?: dep?.optString("headsign") ?: ""
                                                val rawTime = dep?.optString("time") ?: dep?.optString("scheduledTime") ?: dep?.optString("departureTime") ?: dep?.optString("expectedTime") ?: ""
                                                val time = formatTimeString(rawTime)
                                        val part = listOf(line, time, if (dest.isNotEmpty()) "â†’ $dest" else "").filter { it.isNotEmpty() }.joinToString(" ")
                                                if (part.isNotEmpty()) items.add(part)
                                            }
                                        }
                                        val bodyText = if (items.isEmpty()) "Nessuna partenza disponibile al momento" else "Prossime partenze: " + items.joinToString(" â€¢ ")
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
                                                val dest = dep?.optString("destination") ?: dep?.optString("to") ?: ""
                                                val rawTime = dep?.optString("time") ?: dep?.optString("scheduledTime") ?: dep?.optString("departureTime") ?: ""
                                                val time = formatTimeString(rawTime)
                                                val part = listOf(train, time, if (dest.isNotEmpty()) "â†’ $dest" else "").filter { it.isNotEmpty() }.joinToString(" ")
                                                if (part.isNotEmpty()) items.add(part)
                                            }
                                        }
                                        val bodyText = if (items.isEmpty()) "Nessuna partenza disponibile" else "Prossime partenze: " + items.joinToString(" â€¢ ")
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

                // Handle monitored trips (per-trip notifications)
                val trips = getMonitoredTripsMap()
                if (trips.isNotEmpty()) {
                    for ((tId, metaJson) in trips) {
                        try {
                            val meta = JSONObject(metaJson)
                            val notifyMode = meta.optString("notifyMode", "general")
                            val destinationStop = meta.optString("destinationStop", "")
                            val country = meta.optString("country", intent.getStringExtra("country") ?: "")
                            val startingStop = meta.optString("startingStop", "")
                            var url = meta.optString("endpoint", "")
                            if (url.isEmpty()) {
                                if (country.isNullOrEmpty()) {
                                    Log.d("RealtimeService", "No endpoint or country for trip $tId, skipping fetch")
                                    continue
                                } else {
                                    url = "https://prod.cuzimmartin.dev/api/${country}/trip?tripId=${Uri.encode(tId)}"
                                }
                            }

                            Log.d("RealtimeService", "Fetching FRESH trip data $tId -> $url")
                            val request = Request.Builder().url(url).get().build()
                            client.newCall(request).execute().use { resp ->
                                if (resp.isSuccessful) {
                                    val body = resp.body?.string() ?: ""
                                    
                                    // **DEBUG:** Log fetched JSON (truncated to 1000 chars for clarity)
                                    val jsonTrunc = if (body.length > 1000) body.substring(0, 1000) + "..." else body
                                    Log.d("RealtimeService", "Trip $tId FRESH DATA FETCH (${body.length} chars): $jsonTrunc")
                                    // **IMPORTANT:** We ALWAYS process fresh API data now - no cache comparison
                                    // This ensures notifications always have the latest data from the server
                                    
                                    val root = JSONObject(body)
                                    val json = root.optJSONObject("data") ?: root

                                    // Determine train title (robust fallbacks) â€” origin/destination can be objects
                                    val category = json.optString("category").takeIf { it.isNotBlank() } ?: json.optString("type").takeIf { it.isNotBlank() } ?: ""
                                    val trainNum = json.optString("tripNumber").takeIf { it.isNotBlank() }
                                        ?: json.optString("trainNumber").takeIf { it.isNotBlank() }
                                        ?: json.optString("service").takeIf { it.isNotBlank() }
                                        ?: json.optString("id").takeIf { it.isNotBlank() }
                                        ?: tId

                                    val originObj = json.optJSONObject("origin")
                                    val origin = originObj?.optString("stationName")
                                        ?: originObj?.optString("name")
                                        ?: json.optString("origin").takeIf { it.isNotBlank() }
                                        ?: json.optString("from").takeIf { it.isNotBlank() }
                                        ?: json.optString("originName").takeIf { it.isNotBlank() }
                                        ?: "-"

                                    val destObj = json.optJSONObject("destination")
                                    val dest = destObj?.optString("stationName")
                                        ?: destObj?.optString("name")
                                        ?: json.optString("destination").takeIf { it.isNotBlank() }
                                        ?: json.optString("to").takeIf { it.isNotBlank() }
                                        ?: json.optString("destinationName").takeIf { it.isNotBlank() }
                                        ?: "-"

                                    val trainName = listOf(category, trainNum).filter { it.isNotBlank() }.joinToString(" ")
                                    val title = if (origin == "-" && dest == "-") trainName else "$trainName (${origin} \u2192 ${dest})"

                                    // Parse stops (support multiple key names and fallback arrays)
                                    val stopsArr = json.optJSONArray("stops")
                                        ?: json.optJSONArray("tripStops")
                                        ?: json.optJSONArray("stopsList")
                                        ?: json.optJSONArray("stopList")
                                        ?: json.optJSONArray("legs")
                                    var nextIndex = -1
                                    var nextStop = ""
                                    var nextArrivalInstant: java.time.Instant? = null
                                    var lastPassed = ""
                                    var nextEventType: String? = null
                                    var lastPassedIndex = -1
                                    var lastPassedDepartureScheduled: java.time.Instant? = null
                                    var lastPassedDepartureEstimated: java.time.Instant? = null

                                    fun parseToInstant(v: String?): java.time.Instant? {
                                        if (v == null) return null
                                        val s = v.trim()
                                        // Numeric epoch (seconds or milliseconds)
                                        try {
                                            val d = s.toDouble()
                                            val epochMillis = if (d < 1e11) (d * 1000L).toLong() else d.toLong()
                                            return java.time.Instant.ofEpochMilli(epochMillis)
                                        } catch (e: Exception) {
                                            // ignore
                                        }

                                        // Simple local time like "19:44" -> assume today (or tomorrow if it's already past midnight)
                                        try {
                                            val timeOnlyRegex = Regex("^\\d{1,2}:\\d{2}$")
                                            if (timeOnlyRegex.matches(s)) {
                                                val fmt = java.time.format.DateTimeFormatter.ofPattern("H:mm")
                                                val lt = java.time.LocalTime.parse(s, fmt)
                                                var candidate = java.time.LocalDate.now().atTime(lt).atZone(java.time.ZoneId.systemDefault()).toInstant()
                                                val now = java.time.Instant.now()
                                                // If candidate is far in the past (e.g., earlier day) assume it's next day
                                                if (candidate.isBefore(now) && java.time.Duration.between(candidate, now).toHours() > 12) {
                                                    candidate = candidate.plusSeconds(24 * 3600)
                                                }
                                                return candidate
                                            }
                                        } catch (e: Exception) {
                                            // ignore
                                        }

                                        // ISO offsets / instants
                                        try {
                                            return java.time.OffsetDateTime.parse(s).toInstant()
                                        } catch (e: Exception) {
                                            // ignore
                                        }
                                        try {
                                            return java.time.Instant.parse(s)
                                        } catch (e: Exception) {
                                            // ignore
                                        }
                                        return null
                                    }

                                    // Find starting stop index if provided (reference point for stop counting)
                                    var startingIndex = -1
                                    var currentStationName = ""  // Track if train is currently stopped at a station
                                    var currentStationDeparture: java.time.Instant? = null
                                    
                                    if (stopsArr != null) {
                                        val now = java.time.Instant.now()
                                        
                                        // Find starting stop index if provided
                                        if (!startingStop.isBlank() && stopsArr.length() > 0) {
                                            for (i in 0 until stopsArr.length()) {
                                                val s = stopsArr.optJSONObject(i)
                                                val name = s?.optString("stationName")
                                                    ?: s?.optString("name")
                                                    ?: s?.optString("stop")
                                                    ?: s?.optString("stopName")
                                                    ?: s?.optString("station")
                                                    ?: s?.optString("station_name")
                                                    ?: ""
                                                if (name.trim().equals(startingStop.trim(), ignoreCase = true)) {
                                                    startingIndex = i
                                                    break
                                                }
                                            }
                                            Log.d("RealtimeService", "Trip $tId: Found startingStop='$startingStop' at index $startingIndex")
                                        }
                                        
                                        // First pass: find lastPassed (completely past its estimated departure time)
                                        // CRITICAL: All logic based on ESTIMATED times, never scheduled
                                        // Start from startingIndex (or 0 if not set)
                                        val scanStart = if (startingIndex >= 0) startingIndex else 0
                                        
                                        for (i in scanStart until stopsArr.length()) {
                                            val s = stopsArr.optJSONObject(i)
                                            val name = s?.optString("stationName")
                                                ?: s?.optString("name")
                                                ?: s?.optString("stop")
                                                ?: s?.optString("stopName")
                                                ?: s?.optString("station")
                                                ?: s?.optString("station_name")
                                                ?: ""

                                            val cancelled = (s?.optBoolean("cancelled", false) == true)
                                                    || (s?.optBoolean("canceled", false) == true)
                                                    || (s?.optString("status")?.equals("cancelled", ignoreCase = true) == true)

                                            if (cancelled) continue

                                            // Get SCHEDULED times as baseline
                                            val schedArr = s?.optString("scheduledArrival") ?: s?.optString("arrivalTime") ?: ""
                                            val schedDep = s?.optString("scheduledDeparture") ?: s?.optString("departureTime") ?: ""
                                            var schedArrInst: java.time.Instant? = if (schedArr.isNotBlank()) parseToInstant(schedArr) else null
                                            var schedDepInst: java.time.Instant? = if (schedDep.isNotBlank()) parseToInstant(schedDep) else null

                                            // Get ESTIMATED times (preferred)
                                            val estArr = s?.optString("estimatedArrival") ?: s?.optString("expectedArrival") ?: s?.optString("arrival") ?: ""
                                            val estDep = s?.optString("estimatedDeparture") ?: s?.optString("expectedDeparture") ?: s?.optString("departure") ?: ""
                                            var estArrInst: java.time.Instant? = if (estArr.isNotBlank()) parseToInstant(estArr) else null
                                            var estDepInst: java.time.Instant? = if (estDep.isNotBlank()) parseToInstant(estDep) else null
                                            
                                            // If estimated not available, CALCULATE it from scheduled + delay
                                            if (estArrInst == null && schedArrInst != null) {
                                                val arrDelayMin = s?.optInt("arrivalDelay", 0) ?: 0
                                                estArrInst = schedArrInst.plusSeconds((arrDelayMin * 60).toLong())
                                            }
                                            if (estDepInst == null && schedDepInst != null) {
                                                val depDelayMin = s?.optInt("departureDelay", 0) ?: 0
                                                estDepInst = schedDepInst.plusSeconds((depDelayMin * 60).toLong())
                                            }

                                            // Check if train is **currently stopped at this station** (estimated arrival in past, estimated departure in future)
                                            if (estArrInst != null && !estArrInst.isAfter(now) && estDepInst != null && !estDepInst.isBefore(now)) {
                                                // Train HAS ARRIVED but NOT YET DEPARTED (estimated times) â†’ currently at this station
                                                currentStationName = name
                                                currentStationDeparture = estDepInst  // Use estimated departure
                                                lastPassedIndex = i
                                                lastPassed = name
                                                lastPassedDepartureScheduled = schedDepInst
                                                lastPassedDepartureEstimated = estDepInst
                                                // Don't break; keep looking for stations further ahead that might also have past arrival times
                                            } else if (estDepInst != null && estDepInst.isBefore(now)) {
                                                // Estimated departure is completely in the past â†’ train has already left
                                                lastPassedIndex = i
                                                lastPassed = name
                                                lastPassedDepartureScheduled = schedDepInst
                                                lastPassedDepartureEstimated = estDepInst
                                                // Don't override currentStation if already set; clear it if this stop is fully past
                                                if (estArrInst != null && !estArrInst.isAfter(now) && estDepInst != null && estDepInst.isBefore(now)) {
                                                    currentStationName = ""  // Train has left, no longer "at" a station
                                                    currentStationDeparture = null
                                                }
                                            } else {
                                                // Stop in the future (estimated); no need to check further for lastPassed
                                                break
                                            }
                                        }

                                        // Second pass: find next stop (first one not yet departed based on ESTIMATED times)
                                        // Start from startingIndex or 0
                                        // **RIGOROUS:** Only consider stops that are:
                                        // 1. After lastPassedIndex (to avoid going backwards)
                                        // 2. Have a scheduled time that is NOW or IN THE FUTURE (not in past)
                                        val searchStartIdx = if (lastPassedIndex >= 0) lastPassedIndex + 1 else 0
                                        for (i in searchStartIdx until stopsArr.length()) {
                                            val s = stopsArr.optJSONObject(i)

                                            val name = s?.optString("stationName")
                                                ?: s?.optString("name")
                                                ?: s?.optString("stop")
                                                ?: s?.optString("stopName")
                                                ?: s?.optString("station")
                                                ?: s?.optString("station_name")
                                                ?: ""

                                            val cancelled = (s?.optBoolean("cancelled", false) == true)
                                                    || (s?.optBoolean("canceled", false) == true)
                                                    || (s?.optString("status")?.equals("cancelled", ignoreCase = true) == true)

                                            if (cancelled) continue

                                            // Get SCHEDULED times as baseline
                                            val schedArr = s?.optString("scheduledArrival") ?: s?.optString("arrivalTime") ?: ""
                                            val schedDep = s?.optString("scheduledDeparture") ?: s?.optString("departureTime") ?: ""
                                            var schedArrInst: java.time.Instant? = if (schedArr.isNotBlank()) parseToInstant(schedArr) else null
                                            var schedDepInst: java.time.Instant? = if (schedDep.isNotBlank()) parseToInstant(schedDep) else null

                                            // Get ESTIMATED times (preferred)
                                            val estArr = s?.optString("estimatedArrival") ?: s?.optString("expectedArrival") ?: s?.optString("arrival") ?: ""
                                            val estDep = s?.optString("estimatedDeparture") ?: s?.optString("expectedDeparture") ?: s?.optString("departure") ?: ""
                                            var estArrInst: java.time.Instant? = if (estArr.isNotBlank()) parseToInstant(estArr) else null
                                            var estDepInst: java.time.Instant? = if (estDep.isNotBlank()) parseToInstant(estDep) else null
                                            
                                            // If estimated not available, CALCULATE it from scheduled + delay
                                            if (estArrInst == null && schedArrInst != null) {
                                                val arrDelayMin = s?.optInt("arrivalDelay", 0) ?: 0
                                                estArrInst = schedArrInst.plusSeconds((arrDelayMin * 60).toLong())
                                            }
                                            if (estDepInst == null && schedDepInst != null) {
                                                val depDelayMin = s?.optInt("departureDelay", 0) ?: 0
                                                estDepInst = schedDepInst.plusSeconds((depDelayMin * 60).toLong())
                                            }

                                            // **RIGID CONTROL:** Stop must have ESTIMATED time in future to be considered as next
                                            val estArrFuture = estArrInst?.takeIf { !it.isBefore(now) }
                                            val estDepFuture = estDepInst?.takeIf { !it.isBefore(now) }
                                            
                                            // If neither estimated time is in future, skip this stop (it's already passed or being processed)
                                            if (estArrFuture == null && estDepFuture == null) continue

                                            // Prefer estimated arrival/departure times for next stop selection
                                            var candidateInst: java.time.Instant? = null
                                            var candidateType: String? = null
                                            
                                            if (estArrFuture != null && estDepFuture != null) {
                                                if (!estArrFuture.isAfter(estDepFuture)) {
                                                    candidateInst = estArrFuture; candidateType = "arrival"
                                                } else {
                                                    candidateInst = estDepFuture; candidateType = "departure"
                                                }
                                            } else if (estArrFuture != null) {
                                                candidateInst = estArrFuture; candidateType = "arrival"
                                            } else if (estDepFuture != null) {
                                                candidateInst = estDepFuture; candidateType = "departure"
                                            }

                                            if (candidateInst != null) {
                                                nextIndex = i
                                                nextStop = name
                                                nextArrivalInstant = candidateInst
                                                nextEventType = candidateType
                                                Log.d("RealtimeService", "Trip $tId: Selected nextStop='$nextStop' (index=$i) with ${candidateType} at ${candidateInst}")
                                                break
                                            }
                                        }
                                    }

                                    // Normalize trip-level delay into *seconds* (canonical internal unit) to avoid premature rounding
                                    val delayRaw = json.optInt("delayMinutes", json.optInt("delay", 0))
                                    fun normalizeDelaySeconds(raw: Int?, countryHint: String?): Int? {
                                        if (raw == null) return null
                                        var v = raw
                                        // Heuristics:
                                        // - If value is very large (>1000) it's likely already in seconds
                                        // - For some providers (e.g., DE) values > 60 may be seconds
                                        // - Otherwise treat small numbers as minutes and convert to seconds
                                        if (kotlin.math.abs(v) > 1000) return v // seconds
                                        if (!countryHint.isNullOrBlank() && countryHint.equals("de", ignoreCase = true) && kotlin.math.abs(v) > 60) return v // seconds
                                        // otherwise we assume minutes -> convert to seconds
                                        return v * 60
                                    }
                                    val delaySeconds = normalizeDelaySeconds(delayRaw, country) ?: 0

                                    // If we didn't find an explicit upcoming arrival/departure earlier, try one more pass
                                    // considering scheduled times + normalized trip-level delay so we don't skip stops when estimates are missing.
                                    if (nextIndex == -1 && stopsArr != null) {
                                        val now2 = java.time.Instant.now()
                                        var bestIdx = -1
                                        var bestInst: java.time.Instant? = null
                                        var bestType: String? = null
                                        
                                        // **IMPORTANT:** Only search AFTER the lastPassed stop to avoid going backward
                                        var searchStartIdx = 0
                                        if (lastPassed.isNotEmpty()) {
                                            for (i in 0 until stopsArr.length()) {
                                                val s = stopsArr.optJSONObject(i)
                                                val name = s?.optString("stationName") ?: s?.optString("name") ?: s?.optString("stop") ?: ""
                                                if (name.trim().equals(lastPassed.trim(), ignoreCase = true)) {
                                                    searchStartIdx = i  // Start search from lastPassed index (decrease by 1 from i+1)
                                                    Log.d("RealtimeService", "Trip $tId secondPass: found lastPassed='$lastPassed' at index $i, searching from index $i")
                                                    break
                                                }
                                            }
                                        }
                                        
                                        for (i2 in searchStartIdx until stopsArr.length()) {
                                            val s2 = stopsArr.optJSONObject(i2)
                                            val name2 = s2?.optString("stationName") ?: s2?.optString("name") ?: s2?.optString("stop") ?: ""
                                            val cancelled2 = (s2?.optBoolean("cancelled", false) == true) || (s2?.optBoolean("canceled", false) == true) || (s2?.optString("status")?.equals("cancelled", ignoreCase = true) == true)
                                            if (cancelled2) continue

                                            // scheduled arrival/departure
                                            val schedArr = s2?.optString("scheduledArrival", s2?.optString("arrivalTime", s2?.optString("arrival", "")))
                                            val schedDep = s2?.optString("scheduledDeparture", s2?.optString("departureTime", s2?.optString("departure", "")))
                                            val schedArrInst = try { parseToInstant(if (!schedArr.isNullOrBlank()) schedArr else null) } catch (e: Exception) { null }
                                            val schedDepInst = try { parseToInstant(if (!schedDep.isNullOrBlank()) schedDep else null) } catch (e: Exception) { null }

                                            if (schedArrInst != null) {
                                                val cand = schedArrInst.plusSeconds(delaySeconds.toLong())
                                                if (!cand.isBefore(now2)) {
                                                    if (bestInst == null || cand.isBefore(bestInst)) { bestInst = cand; bestIdx = i2; bestType = "arrival" }
                                                }
                                            }
                                            if (schedDepInst != null) {
                                                val cand = schedDepInst.plusSeconds(delaySeconds.toLong())
                                                if (!cand.isBefore(now2)) {
                                                    if (bestInst == null || cand.isBefore(bestInst)) { bestInst = cand; bestIdx = i2; bestType = "departure" }
                                                }
                                            }
                                        }
                                        if (bestIdx != -1 && bestInst != null) {
                                            nextIndex = bestIdx
                                            val sBest = stopsArr.optJSONObject(bestIdx)
                                            nextStop = sBest?.optString("stationName") ?: sBest?.optString("name") ?: sBest?.optString("stop") ?: ""
                                            nextArrivalInstant = bestInst
                                            nextEventType = bestType
                                            Log.d("RealtimeService", "Trip $tId secondPass: found nextStop='$nextStop' at index $bestIdx")
                                        }
                                    }
                                    // **RIGID DELAY CALCULATION:** Always use next stop's ARRIVAL (estimated - scheduled)
                                    // This is the canonical delay source - NEVER use departure for delay
                                    var nextDelaySeconds: Int? = null
                                    if (stopsArr != null && nextIndex >= 0) {
                                        val nextStopObj = stopsArr.optJSONObject(nextIndex)
                                        if (nextStopObj != null) {
                                            // Get SCHEDULED ARRIVAL (immutable - the original planned arrival time)
                                            val scheduledArr = nextStopObj.optString("scheduledArrival", nextStopObj.optString("arrivalTime", ""))
                                            val scheduledArrInst = if (scheduledArr.isNotBlank()) parseToInstant(scheduledArr) else null
                                            
                                            // Get ESTIMATED ARRIVAL (current estimate)
                                            val estimatedArr = nextStopObj.optString("estimatedArrival", nextStopObj.optString("expectedArrival", nextStopObj.optString("arrival", "")))
                                            val estimatedArrInst = if (estimatedArr.isNotBlank()) parseToInstant(estimatedArr) else null
                                            
                                            // Calculate rigidly: estimated arrival - scheduled arrival (in seconds)
                                            if (scheduledArrInst != null && estimatedArrInst != null) {
                                                val delayInSeconds = java.time.Duration.between(scheduledArrInst, estimatedArrInst).seconds.toInt()
                                                nextDelaySeconds = delayInSeconds
                                                Log.d("RealtimeService", "Trip $tId RIGID delay calc (ARRIVAL): nextStop='$nextStop' scheduled=${scheduledArr} estimated=${estimatedArr} delay=${delayInSeconds}s (${delayInSeconds/60}min)")
                                            } else if (scheduledArrInst != null) {
                                                // If no estimate, assume 0 delay or trip-level delay
                                                nextDelaySeconds = 0
                                                Log.d("RealtimeService", "Trip $tId: no estimate for next stop arrival, delay=0 (no info)")
                                            }
                                        }
                                    }
                                    
                                    // **CRITICAL CONTROL:** Before updating nextStop, check if lastPassed departure time increased
                                    // (indicating an unexpected stop/delay that wasn't there before)
                                    // If so, do NOT advance to next stop yet
                                    var shouldAdvanceToNextStop = true
                                    if (lastPassedIndex >= 0 && lastPassedIndex < nextIndex && stopsArr != null) {
                                        val lastPassedObj = stopsArr.optJSONObject(lastPassedIndex)
                                        if (lastPassedObj != null) {
                                            val currentEstDep = lastPassedObj.optString("estimatedDeparture", lastPassedObj.optString("expectedDeparture", ""))
                                            val currentEstDepInst = if (currentEstDep.isNotBlank()) parseToInstant(currentEstDep) else null
                                            
                                            // Compare with cached previous estimate (if we have one)
                                            val prevEstDepKey = "trip:${tId}:lastpassed_est_dep:$lastPassed"
                                            val prevEstDepStr = prefs.getString(prevEstDepKey, null)
                                            val prevEstDepInst = if (prevEstDepStr != null) parseToInstant(prevEstDepStr) else null
                                            
                                            if (prevEstDepInst != null && currentEstDepInst != null && currentEstDepInst.isAfter(prevEstDepInst)) {
                                                val delayIncrease = java.time.Duration.between(prevEstDepInst, currentEstDepInst).seconds
                                                Log.d("RealtimeService", "Trip $tId: âš ï¸ STOP DETECTED - lastPassed=$lastPassed departure delayed by ${delayIncrease}s from ${prevEstDepStr} to ${currentEstDep}. NOT advancing to next stop")
                                                shouldAdvanceToNextStop = false
                                            }
                                            
                                            // Cache the current estimate for next check
                                            if (currentEstDepInst != null) {
                                                prefs.edit().putString(prevEstDepKey, currentEstDep).apply()
                                            }
                                        }
                                    }
                                    
                                    // Also check: if we don't have a future event for nextStop, don't advance
                                    if (nextArrivalInstant == null) {
                                        Log.d("RealtimeService", "Trip $tId: nextArrivalInstant is null, waiting for time data")
                                        shouldAdvanceToNextStop = false
                                    }
                                    
                                    if (!shouldAdvanceToNextStop) {
                                        Log.d("RealtimeService", "Trip $tId: staying at lastPassed='$lastPassed', rigid controls prevent advance")
                                        nextIndex = -1  // Reset nextIndex to indicate we're not advancing
                                        nextStop = ""
                                    }

                                    // Prepare effective/delay for notifications (start with next-specific values - in seconds)
                                    var delayForNotifySeconds: Int? = nextDelaySeconds
                                    var effectiveForNotify: java.time.Instant? = nextArrivalInstant

                                    // Helper to format seconds into user visible string (minutes [+ seconds]) without rounding
                                    fun formatDelaySeconds(sec: Int): String {
                                        val absSec = kotlin.math.abs(sec)
                                        val m = absSec / 60
                                        val s = absSec % 60
                                        return if (s == 0) {
                                            "${m} min"
                                        } else {
                                            "${m} min ${s}s"
                                        }
                                    }

                                    val status = when {
                                        delayForNotifySeconds != null -> when {
                                            delayForNotifySeconds!! > 0 -> "Ritardo ${formatDelaySeconds(delayForNotifySeconds!!)}"
                                            delayForNotifySeconds!! < 0 -> "In anticipo di ${formatDelaySeconds(-delayForNotifySeconds!!)}"
                                            else -> "In orario"
                                        }
                                        delaySeconds > 0 -> "Ritardo ${formatDelaySeconds(delaySeconds)}"
                                        delaySeconds < 0 -> "In anticipo di ${formatDelaySeconds(-delaySeconds)}"
                                        else -> "In orario"
                                    }

                                    // Compute remaining stops (ignore cancelled stops)
                                    // Count from nextIndex (prossima fermata) until destination or end of line
                                    var remaining = 0
                                    
                                    if (destinationStop.isNotEmpty() && stopsArr != null) {
                                        var destIndex = -1
                                        for (i in 0 until stopsArr.length()) {
                                            val s = stopsArr.optJSONObject(i)
                                            val name = s?.optString("stationName")
                                                ?: s?.optString("name")
                                                ?: s?.optString("stop")
                                                ?: s?.optString("stopName")
                                                ?: s?.optString("station")
                                                ?: s?.optString("station_name")
                                                ?: ""
                                            if (name.trim().equals(destinationStop.trim(), ignoreCase = true)) { destIndex = i; break }
                                        }
                                        if (destIndex != -1 && nextIndex != -1) {
                                            val start = minOf(nextIndex, destIndex)
                                            val end = maxOf(nextIndex, destIndex)
                                            var cnt = 0
                                            for (i in start until end + 1) {
                                                val sObj = stopsArr.optJSONObject(i)
                                                val cancelled = (sObj?.optBoolean("cancelled", false) == true) || (sObj?.optBoolean("canceled", false) == true) || (sObj?.optString("status")?.equals("cancelled", ignoreCase = true) == true)
                                                if (!cancelled) cnt++
                                            }
                                            remaining = cnt
                                        }
                                    } else if (nextIndex != -1 && stopsArr != null) {
                                        var cnt = 0
                                        for (i in nextIndex until stopsArr.length()) {
                                            val sObj = stopsArr.optJSONObject(i)
                                            val cancelled = (sObj?.optBoolean("cancelled", false) == true) || (sObj?.optBoolean("canceled", false) == true) || (sObj?.optString("status")?.equals("cancelled", ignoreCase = true) == true)
                                            if (!cancelled) cnt++
                                        }
                                        remaining = cnt
                                    }
                                    
                                    // **DEBUG:** Log all remaining stops and their delays for monitoring changes
                                    if (nextIndex >= 0 && stopsArr != null) {
                                        val remainingStopsDebug = StringBuilder()
                                        for (i in nextIndex until stopsArr.length()) {
                                            val sObj = stopsArr.optJSONObject(i)
                                            val cancelled = (sObj?.optBoolean("cancelled", false) == true) || (sObj?.optBoolean("canceled", false) == true) || (sObj?.optString("status")?.equals("cancelled", ignoreCase = true) == true)
                                            if (!cancelled) {
                                                val name = sObj?.optString("stationName") ?: sObj?.optString("name") ?: sObj?.optString("stop") ?: "?"
                                                val delay = sObj?.optInt("arrivalDelay") ?: sObj?.optInt("departureDelay") ?: sObj?.optInt("delayMinutes") ?: sObj?.optInt("delay") ?: 0
                                                remainingStopsDebug.append("[$name:${delay}min]")
                                            }
                                        }
                                        Log.d("RealtimeService", "Trip $tId remaining stops delays: $remainingStopsDebug")
                                    }

                                    // Special notify modes
                                    var bodyText = ""

                                    // If the user's destination is explicitly cancelled, show informative message
                                    if (destinationStop.isNotBlank() && stopsArr != null) {
                                        for (i in 0 until stopsArr.length()) {
                                            val s = stopsArr.optJSONObject(i)
                                            val name = s?.optString("stationName")
                                                ?: s?.optString("name")
                                                ?: s?.optString("stop")
                                                ?: s?.optString("stopName")
                                                ?: s?.optString("station")
                                                ?: s?.optString("station_name")
                                                ?: ""
                                            if (name.trim().equals(destinationStop.trim(), ignoreCase = true)) {
                                                val cancelled = (s?.optBoolean("cancelled", false) == true) || (s?.optBoolean("canceled", false) == true) || (s?.optString("status")?.equals("cancelled", ignoreCase = true) == true)
                                                if (cancelled) {
                                                    bodyText = "\u26A0\uFE0F La tua fermata ($destinationStop) \u00E8 stata annullata."
                                                }
                                                break
                                            }
                                        }
                                    }

                                    if (bodyText.isEmpty() && notifyMode == "to_destination" && destinationStop.isNotBlank() && nextStop.trim().equals(destinationStop.trim(), ignoreCase = true)) {
                                        // Instead of sending the 'prepare your luggage' message on the generic trains channel,
                                        // send it on the dedicated proximity channel when within the configured notice window.
                                        // Compute seconds until arrival and round up to the nearest minute (avoid '0 min' glitches)
                                        val nowInstant = java.time.Instant.now()
                                        val secondsToArrival = nextArrivalInstant?.let { java.time.Duration.between(nowInstant, it).seconds } ?: Long.MIN_VALUE
                                        // Use integer division (floor) to avoid adding an extra minute; keeps 'ritardo' consistent
                                        val minutesToArrival = when {
                                            secondsToArrival <= 0L -> 0
                                            else -> (secondsToArrival / 60).toInt()
                                        }

                                        val proxKey = "train-prox:$tId"
                                        val lastProxTs = prefs.getLong("trip_prox_ts:$tId", 0L)
                                        // Optionally send proximity alert if within pre-notice window
                                        val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())
                                        if (minutesToArrival >= 0 && minutesToArrival <= prefs.getInt("arrival_notice_minutes", 10)) {
                                            // Avoid spamming multiple notifications too frequently (rate-limit 60s)
                                            if (System.currentTimeMillis() - lastProxTs > 60_000L) {
                                                val atStr = nextArrivalInstant?.let { sdf.format(java.util.Date.from(it)) } ?: "--:--"
                                                // Compute delay to show (prefer per-stop nextDelaySeconds, otherwise propagate earlier stops, else fallback to global delaySeconds)
                                                // Find a precise seconds-based delay to show in proximity notification
                                                var delayToShowSeconds: Int? = nextDelaySeconds

                                                if ((delayToShowSeconds == null || delayToShowSeconds == 0) && stopsArr != null && nextIndex >= 0) {
                                                    for (i in 0..nextIndex) {
                                                        val sCheck = stopsArr.optJSONObject(i)
                                                        if (sCheck == null) continue
                                                        var candidateSeconds: Int? = null
                                                        when {
                                                            sCheck.has("departureDelay") -> candidateSeconds = normalizeDelaySeconds(sCheck.optInt("departureDelay"), country)
                                                            sCheck.has("arrivalDelay") -> candidateSeconds = normalizeDelaySeconds(sCheck.optInt("arrivalDelay"), country)
                                                            sCheck.has("delayMinutes") -> candidateSeconds = normalizeDelaySeconds(sCheck.optInt("delayMinutes"), country)
                                                            sCheck.has("delay") -> candidateSeconds = normalizeDelaySeconds(sCheck.optInt("delay"), country)
                                                            sCheck.has("delaySeconds") -> candidateSeconds = sCheck.optInt("delaySeconds")
                                                        }
                                                        if (candidateSeconds != null && candidateSeconds != 0) { delayToShowSeconds = candidateSeconds; break }

                                                        // If none explicit, try estimated vs scheduled on that stop (compute exact seconds)
                                                        try {
                                                            val est = sCheck.optString("estimatedArrival", sCheck.optString("estimatedDeparture", ""))
                                                            val sched = sCheck.optString("scheduledArrival", sCheck.optString("scheduledDeparture", ""))
                                                            val estInst = parseToInstant(if (est.isNotBlank()) est else null)
                                                            val schedInst = parseToInstant(if (sched.isNotBlank()) sched else null)
                                                            if (estInst != null && schedInst != null) {
                                                                val calcSec = java.time.Duration.between(schedInst, estInst).seconds.toInt()
                                                                if (calcSec != 0) { delayToShowSeconds = calcSec; break }
                                                            }
                                                        } catch (e: Exception) {
                                                            // ignore and continue
                                                        }
                                                    }
                                                }

                                                if (delayToShowSeconds == null || (delayToShowSeconds == 0 && delaySeconds != 0)) {
                                                    // prefer global delay if it indicates real delay
                                                    delayToShowSeconds = if (delaySeconds != 0) delaySeconds else delayToShowSeconds
                                                }

                                                val delayPart = when {
                                                    delayToShowSeconds == null -> "\u2022 In orario"
                                                    delayToShowSeconds > 0 -> "\u2022 Ritardo: +${formatDelaySeconds(delayToShowSeconds)}"
                                                    delayToShowSeconds < 0 -> "\u2022 Anticipo: ${formatDelaySeconds(-delayToShowSeconds)}"
                                                    else -> "\u2022 In orario"
                                                }

                                                var proxBody = "\u26A0\uFE0F Prepara i bagagli! Arrivo a $destinationStop in circa ${minutesToArrival} min (alle $atStr). $delayPart"
                                                if (notifyMode == "to_destination" && destinationStop.isNotBlank()) {
                                                    proxBody = proxBody + "\nTarget destinazione: ${destinationStop}"
                                                }
                                                val nidProx = NotificationHelper.getIdForKey(proxKey)
                                                NotificationHelper.showNotification(this@RealtimeService, NotificationHelper.CHANNEL_TRAIN_PROXIMITY, title, proxBody, nidProx)
                                                prefs.edit().putLong("trip_prox_ts:$tId", System.currentTimeMillis()).apply()
                                                Log.d("RealtimeService","Proximity notify for $tId dest=$destinationStop now=$nowInstant arrival=${nextArrivalInstant} mins=${minutesToArrival} delay=${delayToShowSeconds?.let { formatDelaySeconds(it) } ?: "In orario"}")
                                            }
                                        }

                                        // Build the standard train status body text (always show it in the trains channel)
                                        val sb = StringBuilder()
                                        if (nextStop.isNotEmpty()) {
                                            val arrStr = nextArrivalInstant?.let { sdf.format(java.util.Date.from(it)) } ?: "--:--"

                                            // try to read platform from stops array
                                            var platformStr = ""
                                            if (stopsArr != null && nextIndex >= 0) {
                                                val sObj = stopsArr.optJSONObject(nextIndex)
                                                platformStr = sObj?.optString("platform") ?: sObj?.optString("plannedPlatform") ?: ""
                                            }

                                            val timeStr = nextArrivalInstant?.let { sdf.format(java.util.Date.from(it)) } ?: "--:--"
                                            val eventLabel = if (nextEventType == "departure") "In partenza alle $timeStr" else "In arrivo alle $timeStr"

                                            sb.append("Prossima fermata: $nextStop ${if (platformStr.isNotEmpty()) "\u2022 Binario: $platformStr " else ""}\u2022 $eventLabel\n")
                                        } else {
                                            sb.append("Prossima fermata: --\n")
                                        }
                                        
                                        // Build "Stato attuale" line with departure time from lastPassed if available
                                        var statualLine = "Stato attuale: ${if (lastPassed.isNotEmpty()) lastPassed else "In transito"}"
                                        if (lastPassed.isNotEmpty() && stopsArr != null) {
                                            // Find lastPassed in stops array and get its departure time
                                            for (i in 0 until stopsArr.length()) {
                                                val s = stopsArr.optJSONObject(i)
                                                val name = s?.optString("stationName") ?: s?.optString("name") ?: s?.optString("stop") ?: ""
                                                if (name.trim().equals(lastPassed.trim(), ignoreCase = true)) {
                                                    val depStr = s?.optString("estimatedDeparture") ?: s?.optString("expectedDeparture") ?: s?.optString("scheduledDeparture") ?: s?.optString("departureTime") ?: ""
                                                    if (depStr.isNotEmpty()) {
                                                        val depInstant = try { parseToInstant(depStr) } catch (e: Exception) { null }
                                                        if (depInstant != null) {
                                                            val depTime = sdf.format(java.util.Date.from(depInstant))
                                                            statualLine += " (In partenza alle: $depTime)"
                                                        }
                                                    }
                                                    break
                                                }
                                            }
                                        }
                                        sb.append(statualLine + "\n")
                                        // Show explicit delay/advance lines
                                        if (nextDelaySeconds != null) {
                                            val ndMin = nextDelaySeconds / 60
                                            when {
                                                ndMin > 0 -> sb.append("Ritardo: ${ndMin} min\n")
                                                ndMin < 0 -> sb.append("Anticipo: ${-ndMin} min\n")
                                                else -> sb.append("In orario\n")
                                            }
                                        } else {
                                            val dm = delaySeconds / 60
                                            when {
                                                dm > 0 -> sb.append("Ritardo: ${dm} min\n")
                                                dm < 0 -> sb.append("Anticipo: ${-dm} min\n")
                                                else -> sb.append("In orario\n")
                                            }
                                        }
                                        sb.append("Fermate rimanenti: $remaining")
                                        bodyText = sb.toString().trim()
                                    } else if (bodyText.isEmpty() && notifyMode == "to_destination" && destinationStop.isNotBlank() && lastPassed.trim().equals(destinationStop.trim(), ignoreCase = true) && nextIndex == -1) {
                                        bodyText = "\uD83D\uDE89 Sei arrivato a $destinationStop. Ricordati di scendere dal treno!"
                                        // Final arrival: show final notification and remove monitor
                                        val nid = NotificationHelper.getIdForKey("train:$tId")
                                        NotificationHelper.showNotification(this@RealtimeService, NotificationHelper.CHANNEL_TRAINS, title, bodyText, nid)
                                        removeMonitoredTrip(tId)
                                        prefs.edit().putString("trip:$tId", body).apply()
                                        return@use
                                    } else {
                                        // Standard body
                                        val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())

                                        // Compute an effective arrival instant and delay to show for the trains channel
                                        // Prefer explicit destination estimate; otherwise compute from scheduled + most recent observed delay up to destination
                                        var effectiveForNotify: java.time.Instant? = nextArrivalInstant
                                        var delayForNotify: Int? = nextDelaySeconds?.div(60) // minutes legacy value derived from canonical seconds

                                        // If there's an estimate for the next stop use it
                                        if (effectiveForNotify == null && stopsArr != null && nextIndex >= 0) {
                                            val sObj = stopsArr.optJSONObject(nextIndex)
                                            if (sObj != null) {
                                                val est = sObj.optString("estimatedArrival", sObj.optString("estimatedDeparture", ""))
                                                val sched = sObj.optString("scheduledArrival", sObj.optString("scheduledDeparture", ""))
                                                val estInst = parseToInstant(if (est.isNotBlank()) est else null)
                                                val schedInst = parseToInstant(if (sched.isNotBlank()) sched else null)
                                                if (estInst != null) {
                                                    // Compute exact delay as seconds (estimated - scheduled) and prefer estimated instant
                                                    if (schedInst != null) {
                                                        val calcSec = java.time.Duration.between(schedInst, estInst).seconds.toInt()
                                                        delayForNotify = calcSec / 60 // keep minute-based legacy value for text where needed (floor)
                                                        delayForNotifySeconds = calcSec
                                                        effectiveForNotify = estInst
                                                    } else {
                                                        effectiveForNotify = estInst
                                                    }
                                                }
                                            }
                                        }

                                        // If still null or delay missing, try to derive the most recent real delay observed up to destination
                                        if (stopsArr != null && nextIndex >= 0) {
                                            var observedDelay: Int? = null
                                            // try to use metadata lastDetection station as a hint (prefer closer to current observation)
                                            var detectionIndex = -1
                                            try {
                                                val lastDet = json.optJSONObject("metadata")?.optJSONObject("lastDetection")
                                                val detStation = lastDet?.optString("station")
                                                if (!detStation.isNullOrBlank()) {
                                                    for (i in 0 until stopsArr.length()) {
                                                        val s = stopsArr.optJSONObject(i)
                                                        val name = s?.optString("stationName") ?: s?.optString("name") ?: ""
                                                        if (name.equals(detStation, ignoreCase = true)) { detectionIndex = i; break }
                                                    }
                                                }
                                            } catch (e: Exception) { /* ignore */ }

                                            val scanStart = if (detectionIndex != -1) detectionIndex else 0
                                            for (i in scanStart..nextIndex) {
                                                val sCheck = stopsArr.optJSONObject(i) ?: continue
                                                var candidate: Int? = null
                                                if (sCheck.has("departureDelay")) candidate = sCheck.optInt("departureDelay")
                                                else if (sCheck.has("arrivalDelay")) candidate = sCheck.optInt("arrivalDelay")
                                                else if (sCheck.has("delayMinutes")) candidate = sCheck.optInt("delayMinutes")
                                                else if (sCheck.has("delay")) candidate = sCheck.optInt("delay")
                                                else if (sCheck.has("delaySeconds")) candidate = (sCheck.optInt("delaySeconds") / 60)

                                                if (candidate != null && candidate != 0) observedDelay = candidate

                                                // also test estimated vs scheduled if explicit delay not found
                                                if (observedDelay == null) {
                                                    val est = sCheck.optString("estimatedArrival", sCheck.optString("estimatedDeparture", ""))
                                                    val sched = sCheck.optString("scheduledArrival", sCheck.optString("scheduledDeparture", ""))
                                                    val estInst = parseToInstant(if (est.isNotBlank()) est else null)
                                                    val schedInst = parseToInstant(if (sched.isNotBlank()) sched else null)
                                                    if (estInst != null && schedInst != null) {
                                                        val calcSec = java.time.Duration.between(schedInst, estInst).seconds.toInt()
                                                        if (calcSec != 0) observedDelay = calcSec / 60 // store minutes legacy value
                                                        if (calcSec != 0 && observedDelay != null) {
                                                            // keep canonical seconds copy in sync
                                                            // observedDelay is in minutes; convert back to seconds for canonical copy
                                                            // but we will set delayForNotifySeconds later when observedDelay is used
                                                        }
                                                    }
                                                }
                                            }

                                            if (observedDelay != null) {
                                                delayForNotify = observedDelay
                                                // If provider country returns seconds for delays, convert to minutes for 'de'
                                                if (country.equals("de", ignoreCase = true)) {
                                                    delayForNotify = Math.round(delayForNotify!!.toDouble() / 60.0).toInt()
                                                }
                                                // Keep canonical seconds copy in sync so notifications and state use the same unit
                                                delayForNotifySeconds = normalizeDelaySeconds(delayForNotify, country)
                                                // compute effective based on destination scheduled if present
                                                val sObj = stopsArr.optJSONObject(nextIndex)
                                                val sched = sObj?.optString("scheduledArrival", sObj?.optString("scheduledDeparture", ""))
                                                val schedInst = parseToInstant(if (!sched.isNullOrBlank()) sched else null)
                                                if (schedInst != null) {
                                                    effectiveForNotify = schedInst.plusSeconds((delayForNotify * 60).toLong())
                                                }
                                            }

                                            // If trip-level delay is available, prefer it to keep UI and notifications consistent
                                            if (delaySeconds != 0) {
                                                delayForNotifySeconds = delaySeconds
                                                // recompute effective with trip-level delay (seconds) if scheduled exists
                                                val sObj = stopsArr?.optJSONObject(nextIndex)
                                                val sched = sObj?.optString("scheduledArrival", sObj?.optString("scheduledDeparture", ""))
                                                val schedInst = parseToInstant(if (!sched.isNullOrBlank()) sched else null)
                                                if (schedInst != null) {
                                                    effectiveForNotify = schedInst.plusSeconds(delayForNotifySeconds!!.toLong())
                                                }
                                            }
                                        }

                                        // If still null, fallback to scheduled + global delayMin
                                        if (effectiveForNotify == null && stopsArr != null && nextIndex >= 0) {
                                            val sObj = stopsArr.optJSONObject(nextIndex)
                                            if (sObj != null) {
                                                val sched = sObj.optString("scheduledArrival", sObj.optString("scheduledDeparture", ""))
                                                val schedInst = parseToInstant(if (sched.isNotBlank()) sched else null)
                                                if (schedInst != null) {
                                                    val dm = if (delayForNotifySeconds != null && delayForNotifySeconds != 0) delayForNotifySeconds else delaySeconds
                                                    effectiveForNotify = schedInst.plusSeconds(dm.toLong())
                                                    if (delayForNotifySeconds == null) delayForNotifySeconds = dm
                                                }
                                            }
                                        }

                                        // normalize suspicious large values
                                        if (delayForNotify != null && kotlin.math.abs(delayForNotify) > 1000) delayForNotify = (delayForNotify / 60)

                                        val sb = StringBuilder()

                                        if (nextStop.isNotEmpty()) {
                                            val arrStr = effectiveForNotify?.let { sdf.format(java.util.Date.from(it)) } ?: nextArrivalInstant?.let { sdf.format(java.util.Date.from(it)) } ?: "--:--"

                                            // try to read platform from stops array
                                            var platformStr = ""
                                            if (stopsArr != null && nextIndex >= 0) {
                                                val sObj = stopsArr.optJSONObject(nextIndex)
                                                platformStr = sObj?.optString("platform") ?: sObj?.optString("plannedPlatform") ?: ""
                                            }

                                            val timeStr = arrStr
                                            val eventLabel = if (nextEventType == "departure") "In partenza alle $timeStr" else "In arrivo alle $timeStr"

                                            sb.append("Prossima fermata: $nextStop ${if (platformStr.isNotEmpty()) "\u2022 Binario: $platformStr " else ""}\u2022 $eventLabel\n")
                                        } else {
                                            sb.append("Prossima fermata: --\n")
                                        }

                                        // Show the computed arrival line (calculated time + explicit delay)
                                        val arrivalLine = when {
                                            // Prefer explicit per-stop delay (seconds)
                                            delayForNotifySeconds != null -> {
                                                val dmin = delayForNotifySeconds / 60
                                                when {
                                                    dmin > 0 -> "Arrivo calcolato: ${effectiveForNotify?.let { sdf.format(java.util.Date.from(it)) } ?: "--:--"} \u2022 Ritardo: +${dmin} min\n"
                                                    dmin < 0 -> "Arrivo calcolato: ${effectiveForNotify?.let { sdf.format(java.util.Date.from(it)) } ?: "--:--"} \u2022 Anticipo: ${-dmin} min\n"
                                                    else -> "Arrivo calcolato: ${effectiveForNotify?.let { sdf.format(java.util.Date.from(it)) } ?: "--:--"} \u2022 In orario\n"
                                                }
                                            }
                                            // Fallback to trip-level delay (seconds)
                                            delaySeconds != 0 -> {
                                                val dmin = delaySeconds / 60
                                                when {
                                                    dmin > 0 -> "Arrivo calcolato: ${effectiveForNotify?.let { sdf.format(java.util.Date.from(it)) } ?: "--:--"} \u2022 Ritardo: +${dmin} min\n"
                                                    dmin < 0 -> "Arrivo calcolato: ${effectiveForNotify?.let { sdf.format(java.util.Date.from(it)) } ?: "--:--"} \u2022 Anticipo: ${-dmin} min\n"
                                                    else -> "Arrivo calcolato: ${effectiveForNotify?.let { sdf.format(java.util.Date.from(it)) } ?: "--:--"} \u2022 In orario\n"
                                                }
                                            }
                                            else -> "Arrivo calcolato: ${effectiveForNotify?.let { sdf.format(java.util.Date.from(it)) } ?: "--:--"} \n"
                                        }

                                        sb.append(arrivalLine)

                                        // Build "Stato attuale" line - determine if train is at a station or in transit
                                        var statualLine = when {
                                            currentStationName.isNotEmpty() -> {
                                                // Train is currently stopped at a station
                                                // Use estimated departure if available, otherwise calculate estimated = scheduled + delay
                                                var depTime = currentStationDeparture
                                                if (depTime == null && lastPassedDepartureScheduled != null && stopsArr != null && lastPassedIndex >= 0) {
                                                    // Calculate estimated departure = scheduled departure + departure delay
                                                    val sObj = stopsArr.optJSONObject(lastPassedIndex)
                                                    val depDelayMinutes = sObj?.optInt("departureDelay") ?: sObj?.optInt("delayMinutes") ?: sObj?.optInt("delay") ?: 0
                                                    if (depDelayMinutes != 0) {
                                                        depTime = lastPassedDepartureScheduled.plusSeconds((depDelayMinutes * 60).toLong())
                                                    } else {
                                                        depTime = lastPassedDepartureScheduled
                                                    }
                                                }
                                                val depTimeStr = depTime?.let { sdf.format(java.util.Date.from(it)) } ?: "--:--"
                                                "Stato attuale: In stazione a $currentStationName (partir\u00E0 alle $depTimeStr)"
                                            }
                                            lastPassed.isNotEmpty() -> {
                                                // Train is in transit from lastPassed station
                                                // Use estimated departure if available, otherwise calculate estimated = scheduled + delay
                                                var depTime = lastPassedDepartureEstimated
                                                if (depTime == null && lastPassedDepartureScheduled != null && stopsArr != null && lastPassedIndex >= 0) {
                                                    // Calculate estimated departure = scheduled departure + departure delay
                                                    val sObj = stopsArr.optJSONObject(lastPassedIndex)
                                                    val depDelayMinutes = sObj?.optInt("departureDelay") ?: sObj?.optInt("delayMinutes") ?: sObj?.optInt("delay") ?: 0
                                                    if (depDelayMinutes != 0) {
                                                        depTime = lastPassedDepartureScheduled.plusSeconds((depDelayMinutes * 60).toLong())
                                                    } else {
                                                        depTime = lastPassedDepartureScheduled
                                                    }
                                                }
                                                val depStr = depTime?.let { sdf.format(java.util.Date.from(it)) } ?: "--:--"
                                                "Stato attuale: In viaggio da $lastPassed (partito alle $depStr)"
                                            }
                                            else -> "Stato attuale: In transito"
                                        }
                                        sb.append(statualLine + "\n")
                                        
                                        // Show explicit delay/advance lines (use the same delay value used for arrivalLine to keep consistency)
                                        val displayDelayMin = when {
                                            delayForNotifySeconds != null -> delayForNotifySeconds / 60
                                            else -> delaySeconds / 60
                                        }
                                        when {
                                            displayDelayMin > 0 -> sb.append("Ritardo: ${displayDelayMin} min\n")
                                            displayDelayMin < 0 -> sb.append("Anticipo: ${-displayDelayMin} min\n")
                                            else -> sb.append("In orario\n")
                                        }
                                        sb.append("Fermate rimanenti: $remaining")
                                        if (notifyMode == "to_destination" && destinationStop.isNotBlank()) {
                                            sb.append("\nTarget destinazione: ${destinationStop}")
                                        }
                                        bodyText = sb.toString().trim()
                                    }

                                    // Debug log for parsed fields
                                    val delayForStateMinutes = when {
                                        delayForNotifySeconds != null -> delayForNotifySeconds / 60
                                        else -> delaySeconds / 60
                                    }
                                    Log.d("RealtimeService", "Trip parsed: id=$tId title='${title}' nextStop='$nextStop' lastPassed='$lastPassed' delay=$delayForStateMinutes remaining=$remaining notifyMode=$notifyMode destination='$destinationStop'")
                                    Log.d("RealtimeService", "Trip delays debug: nextDelaySeconds=${nextDelaySeconds ?: "null"} delayForNotifySeconds=${delayForNotifySeconds ?: "null"} tripDelaySeconds=${delaySeconds} effective=${effectiveForNotify?.toString() ?: "null"} nextArrival=${nextArrivalInstant?.toString() ?: "null"}")

                                    val nid = NotificationHelper.getIdForKey("train:$tId")

                                    // **CRITICAL:** Track time changes to force notification update when times change
                                    // Build a fingerprint of all critical times to detect changes
                                    val timesFingerprint = JSONObject()
                                    timesFingerprint.put("nextArrivalTime", nextArrivalInstant?.toString() ?: "")
                                    timesFingerprint.put("effectiveForNotify", effectiveForNotify?.toString() ?: "")
                                    timesFingerprint.put("delaySeconds", delaySeconds)
                                    timesFingerprint.put("delayForNotifySeconds", delayForNotifySeconds ?: -999)
                                    timesFingerprint.put("nextDelaySeconds", nextDelaySeconds ?: -999)
                                    
                                    val currentTimesStr = timesFingerprint.toString()
                                    val prevTimesStr = prefs.getString("trip:times:$tId", null)
                                    
                                    var timesChanged = false
                                    if (prevTimesStr != null && prevTimesStr != currentTimesStr) {
                                        timesChanged = true
                                        Log.d("RealtimeService", "Trip $tId: â° TIMES CHANGED â†’ FORCE NOTIFY\n  PREV: $prevTimesStr\n  NEW: $currentTimesStr")
                                    }
                                    
                                    prefs.edit().putString("trip:times:$tId", currentTimesStr).apply()

                                    // **RIGID STATE CONTROL:** Only notify if significant changes detected
                                    // Build state fingerprint with exact field values
                                    // Always include a fetch timestamp to force notification re-push at every interval
                                    val stateObj = JSONObject()
                                    stateObj.put("nextStop", nextStop)
                                    stateObj.put("nextEventType", nextEventType ?: "")
                                    stateObj.put("nextArrival", nextArrivalInstant?.toString() ?: "")
                                    stateObj.put("lastPassed", lastPassed)
                                    stateObj.put("nextDelaySeconds", nextDelaySeconds ?: -999)  // Use exact canonical seconds delay
                                    stateObj.put("remaining", remaining)
                                    stateObj.put("fetchTimestampMs", System.currentTimeMillis()) // Force state change at every poll to ensure notification updates

                                    val newState = stateObj.toString()
                                    val prevState = prefs.getString("trip:state:$tId", null)

                                    // **CRITICAL:** Always use fresh data from API, never rely on cached state
                                    // Always recalculate and notify with latest values - ignore previous cache
                                    Log.d("RealtimeService", "Trip $tId: ALWAYS NOTIFY WITH FRESH DATA - ignoring cache")

                                    if (true) {  // Always notify with fresh data
                                        // Apply minimal rate-limit to avoid notification spam (allow update every 1 second minimum)
                                        // BUT: Override rate-limit if times have changed (delays/arrivals updated)
                                        val lastNotifyTs = prefs.getLong("trip:notif_ts:$tId", 0L)
                                        val now = System.currentTimeMillis()
                                        val timeSinceLastNotify = now - lastNotifyTs
                                        val notifyIntervalMs = 1_000 // Minimum 1 second between notifications for the same trip to ensure fresh updates
                                        
                                        val shouldNotifyDueToTimeChange = timesChanged
                                        val shouldNotifyDueToRateLimit = timeSinceLastNotify >= notifyIntervalMs
                                        
                                        if (shouldNotifyDueToTimeChange || shouldNotifyDueToRateLimit) {
                                            val reason = when {
                                                shouldNotifyDueToTimeChange -> "TIME CHANGED (delay/arrival updated)"
                                                else -> "RATE LIMIT PASSED"
                                            }
                                            Log.d("RealtimeService", ">>> NOTIFYING Trip $tId: nextStop='$nextStop' delay=${nextDelaySeconds?.let { it/60 } ?: "?"}min eventType=$nextEventType remaining=$remaining [$reason]")
                                            NotificationHelper.showNotification(this@RealtimeService, NotificationHelper.CHANNEL_TRAINS, title, bodyText, nid)
                                            prefs.edit().putLong("trip:notif_ts:$tId", now).apply()
                                            prefs.edit().putString("trip:state:$tId", newState).apply()
                                        } else {
                                            Log.d("RealtimeService", "Trip $tId: rate-limited (${timeSinceLastNotify}ms since last notify, need ${notifyIntervalMs}ms) and times unchanged")
                                        }
                                    }

                                    // Store fresh response and state for next iteration
                                    prefs.edit().putString("trip:$tId", body).apply()
                                    if (!prevState.isNullOrEmpty()) {
                                        prefs.edit().putString("trip:state:$tId", newState).apply()
                                    }
                                } else {
                                    Log.d("RealtimeService", "Failed to fetch trip $tId: HTTP ${resp.code}")
                                }
                            }
                        } catch (e: Exception) {
                            Log.e("RealtimeService", "Error fetching trip $tId", e)
                        }
                    }
                } else {
                    Log.d("RealtimeService", "No monitored trips to fetch")
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



