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

    private fun addMonitoredTrip(tripId: String, notifyMode: String?, destinationStop: String?, endpoint: String?, country: String?) {
        val map = getMonitoredTripsMap()
        val meta = JSONObject()
        if (!notifyMode.isNullOrEmpty()) meta.put("notifyMode", notifyMode)
        if (!destinationStop.isNullOrEmpty()) meta.put("destinationStop", destinationStop)
        if (!endpoint.isNullOrEmpty()) meta.put("endpoint", endpoint)
        if (!country.isNullOrEmpty()) meta.put("country", country)
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

            // Persist monitored targets if provided
            if (!stopId.isNullOrEmpty()) addMonitoredStop(stopId, stopName)
            if (!stationId.isNullOrEmpty()) addMonitoredStation(stationId)
            if (!tripId.isNullOrEmpty()) addMonitoredTrip(tripId, notifyMode, destinationStop, endpoint, country)

            // Save interval setting for the service so it persists across restarts
            if (intervalSeconds > 0) prefs.edit().putInt("service_interval_seconds", intervalSeconds).apply()

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
            while (isActive) {
                val startTs = System.currentTimeMillis()

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
                                                val dest = dep?.optString("destination") ?: dep?.optString("to") ?: ""
                                                val rawTime = dep?.optString("time") ?: dep?.optString("scheduledTime") ?: dep?.optString("departureTime") ?: ""
                                                val time = formatTimeString(rawTime)
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

                // Handle monitored trips (per-trip notifications)
                val trips = getMonitoredTripsMap()
                if (trips.isNotEmpty()) {
                    for ((tId, metaJson) in trips) {
                        try {
                            val meta = JSONObject(metaJson)
                            val notifyMode = meta.optString("notifyMode", "general")
                            val destinationStop = meta.optString("destinationStop", "")
                            var url = meta.optString("endpoint", "")
                            if (url.isEmpty()) {
                                val country = meta.optString("country", intent.getStringExtra("country") ?: "")
                                if (country.isNullOrEmpty()) {
                                    Log.d("RealtimeService", "No endpoint or country for trip $tId, skipping fetch")
                                    continue
                                } else {
                                    url = "https://prod.cuzimmartin.dev/api/${country}/trip?tripId=${Uri.encode(tId)}"
                                }
                            }

                            Log.d("RealtimeService", "Fetching trip $tId -> $url")
                            val request = Request.Builder().url(url).get().build()
                            client.newCall(request).execute().use { resp ->
                                if (resp.isSuccessful) {
                                    val body = resp.body?.string() ?: ""
                                    val previousBody = prefs.getString("trip:$tId", null)
                                    val root = JSONObject(body)
                                    val json = root.optJSONObject("data") ?: root

                                    // Determine train title (robust fallbacks) — origin/destination can be objects
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
                                    val title = if (origin == "-" && dest == "-") trainName else "$trainName (${origin} → ${dest})"

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

                                    fun parseToInstant(v: String?): java.time.Instant? {
                                        if (v == null) return null
                                        val s = v.trim()
                                        try {
                                            val d = s.toDouble()
                                            val epochMillis = if (d < 1e11) (d * 1000L).toLong() else d.toLong()
                                            return java.time.Instant.ofEpochMilli(epochMillis)
                                        } catch (e: Exception) {
                                            // ignore
                                        }
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

                                    if (stopsArr != null) {
                                        val now = java.time.Instant.now()
                                        for (i in 0 until stopsArr.length()) {
                                            val s = stopsArr.optJSONObject(i)

                                            val name = s?.optString("stationName")
                                                ?: s?.optString("name")
                                                ?: s?.optString("stop")
                                                ?: s?.optString("stopName")
                                                ?: s?.optString("station")
                                                ?: s?.optString("station_name")
                                                ?: ""

                                            // Detect cancelled stops (various representations)
                                            val cancelled = (s?.optBoolean("cancelled", false) == true)
                                                    || (s?.optBoolean("canceled", false) == true)
                                                    || (s?.optString("status")?.equals("cancelled", ignoreCase = true) == true)

                                            if (cancelled) {
                                                // skip cancelled stops for next-stop selection but remember the name for context
                                                if (name.isNotEmpty()) {
                                                    // mark lastPassed only if it was earlier
                                                    lastPassed = name
                                                }
                                                continue
                                            }

                                            // Prefer expected/estimated/actual times over scheduled
                                            val arrKeys = listOf("expectedArrival", "estimatedArrival", "actualArrival", "expectedTime", "arrival", "scheduledArrival", "arrivalTime", "time")
                                            var arrInst: java.time.Instant? = null
                                            for (k in arrKeys) {
                                                val v = s?.optString(k)
                                                if (!v.isNullOrBlank()) {
                                                    val parsed = parseToInstant(v)
                                                    if (parsed != null) { arrInst = parsed; break }
                                                }
                                            }

                                            val depKeys = listOf("expectedDeparture", "estimatedDeparture", "actualDeparture", "departure", "scheduledDeparture", "departureTime")
                                            var depInst: java.time.Instant? = null
                                            for (k in depKeys) {
                                                val v = s?.optString(k)
                                                if (!v.isNullOrBlank()) {
                                                    val parsed = parseToInstant(v)
                                                    if (parsed != null) { depInst = parsed; break }
                                                }
                                            }

                                            // Prefer the earliest future event among arrival and departure
                                            val candidateInst = when {
                                                arrInst != null && arrInst.isAfter(now) -> {
                                                    nextEventType = "arrival"
                                                    arrInst
                                                }
                                                depInst != null && depInst.isAfter(now) -> {
                                                    nextEventType = "departure"
                                                    depInst
                                                }
                                                else -> null
                                            }

                                            if (candidateInst != null) {
                                                nextIndex = i
                                                nextStop = name
                                                nextArrivalInstant = candidateInst
                                                break
                                            }

                                            // Otherwise update lastPassed if this stop's arrival/departure are in the past
                                            if ((depInst != null && depInst.isBefore(now)) || (arrInst != null && arrInst.isBefore(now))) {
                                                if (name.isNotEmpty()) lastPassed = name
                                            }
                                        }
                                    }

                                    val delayMin = json.optInt("delayMinutes", json.optInt("delay", 0))
                                    // Try to determine delay for the next event (prefer per-stop arrival/departure delays)
                                    var nextDelay: Int? = null
                                    if (stopsArr != null && nextIndex >= 0) {
                                        val sObj = stopsArr.optJSONObject(nextIndex)
                                        if (sObj != null) {
                                            if (nextEventType == "arrival") {
                                                if (sObj.has("arrivalDelay")) nextDelay = sObj.optInt("arrivalDelay")
                                                else if (sObj.has("delay")) nextDelay = sObj.optInt("delay")
                                                else {
                                                    val est = sObj.optString("estimatedArrival", sObj.optString("expectedArrival", sObj.optString("arrival") ?: ""))
                                                    val sched = sObj.optString("scheduledArrival", sObj.optString("arrivalTime", sObj.optString("scheduledTime", "")))
                                                    val estInst = parseToInstant(if (est.isNotBlank()) est else null)
                                                    val schedInst = parseToInstant(if (sched.isNotBlank()) sched else null)
                                                    if (estInst != null && schedInst != null) nextDelay = java.time.Duration.between(schedInst, estInst).toMinutes().toInt()
                                                }
                                            } else if (nextEventType == "departure") {
                                                if (sObj.has("departureDelay")) nextDelay = sObj.optInt("departureDelay")
                                                else if (sObj.has("delay")) nextDelay = sObj.optInt("delay")
                                                else {
                                                    val est = sObj.optString("estimatedDeparture", sObj.optString("expectedDeparture", sObj.optString("departure") ?: ""))
                                                    val sched = sObj.optString("scheduledDeparture", sObj.optString("departureTime", sObj.optString("scheduledTime", "")))
                                                    val estInst = parseToInstant(if (est.isNotBlank()) est else null)
                                                    val schedInst = parseToInstant(if (sched.isNotBlank()) sched else null)
                                                    if (estInst != null && schedInst != null) nextDelay = java.time.Duration.between(schedInst, estInst).toMinutes().toInt()
                                                }
                                            }
                                        }
                                    }

                                    val status = when {
                                        nextDelay != null -> when {
                                            nextDelay!! > 0 -> "Ritardo ${nextDelay} min"
                                            nextDelay!! < 0 -> "In anticipo di ${-nextDelay} min"
                                            else -> "In orario"
                                        }
                                        delayMin > 0 -> "Ritardo ${delayMin} min"
                                        delayMin < 0 -> "In anticipo di ${-delayMin} min"
                                        else -> "In orario"
                                    }

                                    // Compute remaining stops (ignore cancelled stops)
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
                                            for (i in start + 1..end) {
                                                val sObj = stopsArr.optJSONObject(i)
                                                val cancelled = (sObj?.optBoolean("cancelled", false) == true) || (sObj?.optBoolean("canceled", false) == true) || (sObj?.optString("status")?.equals("cancelled", ignoreCase = true) == true)
                                                if (!cancelled) cnt++
                                            }
                                            remaining = cnt
                                        }
                                    } else if (nextIndex != -1 && stopsArr != null) {
                                        var cnt = 0
                                        for (i in nextIndex + 1 until stopsArr.length()) {
                                            val sObj = stopsArr.optJSONObject(i)
                                            val cancelled = (sObj?.optBoolean("cancelled", false) == true) || (sObj?.optBoolean("canceled", false) == true) || (sObj?.optString("status")?.equals("cancelled", ignoreCase = true) == true)
                                            if (!cancelled) cnt++
                                        }
                                        remaining = cnt
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
                                                    bodyText = "⚠️ La tua fermata ($destinationStop) è stata annullata."
                                                }
                                                break
                                            }
                                        }
                                    }

                                    if (bodyText.isEmpty() && notifyMode == "to_destination" && destinationStop.isNotBlank() && nextStop.trim().equals(destinationStop.trim(), ignoreCase = true)) {
                                        bodyText = "⚠️ Prepara i bagagli! Sei in arrivo alla tua fermata: $destinationStop. Prossima discesa."
                                    } else if (bodyText.isEmpty() && notifyMode == "to_destination" && destinationStop.isNotBlank() && lastPassed.trim().equals(destinationStop.trim(), ignoreCase = true) && nextIndex == -1) {
                                        bodyText = "🚉 Sei arrivato a $destinationStop. Ricordati di scendere dal treno!"
                                        // Final arrival: show final notification and remove monitor
                                        val nid = NotificationHelper.getIdForKey("train:$tId")
                                        NotificationHelper.showNotification(this@RealtimeService, NotificationHelper.CHANNEL_TRAINS, title, bodyText, nid)
                                        removeMonitoredTrip(tId)
                                        prefs.edit().putString("trip:$tId", body).apply()
                                        return@use
                                    } else {
                                        // Standard body
                                        val sdf = SimpleDateFormat("HH:mm", Locale.getDefault())
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

                                            sb.append("Prossima fermata: $nextStop ${if (platformStr.isNotEmpty()) "• Binario: $platformStr " else ""}• $eventLabel\n")
                                        } else {
                                            sb.append("Prossima fermata: --\n")
                                        }
                                        sb.append("Stato attuale: ${if (lastPassed.isNotEmpty()) lastPassed else "In transito"}\n")
                                        // Show explicit delay/advance lines
                                        if (nextDelay != null) {
                                            when {
                                                nextDelay > 0 -> sb.append("Ritardo: ${nextDelay} min\n")
                                                nextDelay < 0 -> sb.append("Anticipo: ${-nextDelay} min\n")
                                                else -> sb.append("In orario\n")
                                            }
                                        } else {
                                            when {
                                                delayMin > 0 -> sb.append("Ritardo: ${delayMin} min\n")
                                                delayMin < 0 -> sb.append("Anticipo: ${-delayMin} min\n")
                                                else -> sb.append("In orario\n")
                                            }
                                        }
                                        sb.append("Fermate rimanenti: $remaining")
                                        bodyText = sb.toString().trim()
                                    }

                                    // Debug log for parsed fields
                                    Log.d("RealtimeService", "Trip parsed: id=$tId title='${title}' nextStop='$nextStop' lastPassed='$lastPassed' delay=$delayMin remaining=$remaining notifyMode=$notifyMode destination='$destinationStop'")
                                    val nid = NotificationHelper.getIdForKey("train:$tId")
                                    if (previousBody == null || previousBody != body) {
                                        NotificationHelper.showNotification(this@RealtimeService, NotificationHelper.CHANNEL_TRAINS, title, bodyText, nid)
                                    }
                                    prefs.edit().putString("trip:$tId", body).apply()
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
