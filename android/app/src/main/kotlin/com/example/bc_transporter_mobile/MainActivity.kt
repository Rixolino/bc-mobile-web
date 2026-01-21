package com.example.bc_transporter_mobile

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.net.Uri
import android.util.Log
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.bc_transporter_mobile/notifications"
    private val PERMISSION_REQUEST_CODE = 101

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    val title = call.argument<String>("title")
                    val body = call.argument<String>("body")
                    val channel = call.argument<String>("channel") ?: "trains_updates_channel"
                    val key = call.argument<String>("key")

                    if (canPostNotifications()) {
                        if (!key.isNullOrEmpty()) {
                            val nid = NotificationHelper.getIdForKey(key)
                            NotificationHelper.showNotification(this@MainActivity, channel, title ?: "", body ?: "", nid)
                        } else {
                            showNotification(channel, title, body)
                        }
                        result.success(null)
                    } else {
                        requestNotificationPermission()
                        result.error("PERMISSION_DENIED", "Notification permission missing", null)
                    }
                }
                "cancelNotification" -> {
                    val key = call.argument<String>("key")
                    if (!key.isNullOrEmpty()) {
                        NotificationHelper.cancelNotificationByKey(this@MainActivity, key)
                    }
                    result.success(null)
                }
                "requestPermission" -> {
                    requestNotificationPermission()
                    result.success(null)
                }
                "hasNotificationPermission" -> {
                    result.success(canPostNotifications())
                }
                "scheduleBackgroundWorkers" -> {
                    BackgroundScheduler.schedulePeriodicWorkers(this@MainActivity)
                    result.success(null)
                }
                "cancelBackgroundWorkers" -> {
                    BackgroundScheduler.cancelAll(this@MainActivity)
                    result.success(null)
                }
                "scheduleTrainsWorker" -> {
                    val stationId = call.argument<String>("stationId")
                    val country = call.argument<String>("country")
                    val service = call.argument<String>("service")
                    val enable = call.argument<Boolean>("enableNotifications") ?: true
                    val endpoint = call.argument<String>("endpoint")
                    val intervalSeconds = call.argument<Int>("intervalSeconds") ?: 0
                    val tripId = call.argument<String>("tripId")
                    val notifyMode = call.argument<String>("notifyMode") // 'to_destination' or 'general'
                    val destinationStop = call.argument<String>("destinationStop")

                    // Start realtime foreground service for trains
                    val intent = android.content.Intent(this@MainActivity, RealtimeService::class.java).apply {
                        action = "start"
                        putExtra("type", "trains")
                        putExtra("stationId", stationId)
                        putExtra("country", country)
                        putExtra("service", service)
                        putExtra("endpoint", endpoint)
                        putExtra("intervalSeconds", intervalSeconds)
                        putExtra("tripId", tripId)
                        putExtra("notifyMode", notifyMode)
                        putExtra("destinationStop", destinationStop)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "cancelTrainsWorker" -> {
                    val intent = android.content.Intent(this@MainActivity, RealtimeService::class.java).apply {
                        action = "stop"
                        putExtra("type", "trains")
                    }
                    startService(intent)
                    result.success(null)
                }
                "removeMonitoredTrip" -> {
                    val tripId = call.argument<String>("tripId")
                    if (!tripId.isNullOrEmpty()) {
                        val prefs = getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
                        val json = prefs.getString("monitored_trips", null)
                        if (!json.isNullOrEmpty()) {
                            val obj = JSONObject(json)
                            if (obj.has(tripId)) {
                                obj.remove(tripId)
                                prefs.edit().putString("monitored_trips", obj.toString()).apply()
                            }
                        }
                        // cancel notification by key (train:<id>) to ensure immediate removal
                        NotificationHelper.cancelNotificationByKey(this@MainActivity, "train:$tripId")
                        Log.d("MainActivity","removeMonitoredTrip requested for $tripId")
                        // tell service to remove job and cancel notification if active
                        val intent = android.content.Intent(this@MainActivity, RealtimeService::class.java).apply {
                            action = "removeTrip"
                            putExtra("tripId", tripId)
                        }
                        startService(intent)
                    }
                    result.success(null)
                }
                "scheduleBusesWorker" -> {
                    val provider = call.argument<String>("provider")
                    val baseUrl = call.argument<String>("baseUrl")
                    val enable = call.argument<Boolean>("enableNotifications") ?: true
                    val endpoint = call.argument<String>("endpoint")
                    val intervalSeconds = call.argument<Int>("intervalSeconds") ?: 0
                    val stopId = call.argument<String>("stopId")
                    val stopName = call.argument<String>("stopName")
                    // Start realtime foreground service for buses (supports optional stopId/stopName for stop-specific notifications)
                    val intent = android.content.Intent(this@MainActivity, RealtimeService::class.java).apply {
                        action = "start"
                        putExtra("type", "buses")
                        putExtra("provider", provider)
                        putExtra("baseUrl", baseUrl)
                        putExtra("endpoint", endpoint)
                        putExtra("intervalSeconds", intervalSeconds)
                        putExtra("stopId", stopId)
                        putExtra("stopName", stopName)
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "cancelBusesWorker" -> {
                    val intent = android.content.Intent(this@MainActivity, RealtimeService::class.java).apply {
                        action = "stop"
                        putExtra("type", "buses")
                    }
                    startService(intent)
                    result.success(null)
                }
                "removeMonitoredStop" -> {
                    val stopId = call.argument<String>("stopId")
                    if (!stopId.isNullOrEmpty()) {
                        val prefs = getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
                        val json = prefs.getString("monitored_stops", null)
                        if (json != null) {
                            val obj = JSONObject(json)
                            obj.remove(stopId)
                            prefs.edit().putString("monitored_stops", obj.toString()).apply()
                        }

                        // If there are no monitored stops or stations left, stop the service to save battery
                        val remainingStops = prefs.getString("monitored_stops", null)?.let { JSONObject(it).length() } ?: 0
                        val remainingStations = prefs.getString("monitored_stations", null)?.let { org.json.JSONArray(it).length() } ?: 0
                        if (remainingStops == 0 && remainingStations == 0) {
                            val stopIntent = android.content.Intent(this@MainActivity, RealtimeService::class.java).apply {
                                action = "stop"
                                putExtra("type", "buses")
                            }
                            startService(stopIntent)
                        }
                    }
                    result.success(null)
                }
                "forceFetchStop" -> {
                    val stopId = call.argument<String>("stopId")
                    var payload: String? = null
                    if (!stopId.isNullOrEmpty()) {
                        val prefs = getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
                        try {
                            val baseUrl = prefs.getString("service_base_url", "https://betacloud-transporter.is-cool.dev")
                            val provider = prefs.getString("service_provider", "bari")
                            val url = "${baseUrl}/api/it/bus/${provider}/stops-updates?stopId=${stopId}"
                            val client = okhttp3.OkHttpClient()
                            val request = okhttp3.Request.Builder().url(url).get().build()
                            val resp = client.newCall(request).execute()
                            if (resp.isSuccessful) {
                                payload = resp.body?.string()
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                    result.success(payload)
                }
                "forceFetchStation" -> {
                    val stationId = call.argument<String>("stationId")
                    var payload: String? = null
                    if (!stationId.isNullOrEmpty()) {
                        try {
                            val url = "https://prod.cuzimmartin.dev/api/it/departures?stationId=${stationId}"
                            val client = okhttp3.OkHttpClient()
                            val request = okhttp3.Request.Builder().url(url).get().build()
                            val resp = client.newCall(request).execute()
                            if (resp.isSuccessful) payload = resp.body?.string()
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                    result.success(payload)
                }
                "getCachedStopData" -> {
                    val stopId = call.argument<String>("stopId")
                    var payload: String? = null
                    if (!stopId.isNullOrEmpty()) {
                        val prefs = getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
                        payload = prefs.getString("stop:$stopId", null)
                    }
                    result.success(payload)
                }
                "getCachedStationData" -> {
                    val stationId = call.argument<String>("stationId")
                    var payload: String? = null
                    if (!stationId.isNullOrEmpty()) {
                        val prefs = getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
                        payload = prefs.getString("station:$stationId", null)
                    }
                    result.success(payload)
                }
                "removeMonitoredStation" -> {
                    val stationId = call.argument<String>("stationId")
                    if (!stationId.isNullOrEmpty()) {
                        val prefs = getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
                        val json = prefs.getString("monitored_stations", null)
                        if (!json.isNullOrEmpty()) {
                            val arr = org.json.JSONArray(json)
                            val newArr = org.json.JSONArray()
                            for (i in 0 until arr.length()) {
                                val v = arr.optString(i)
                                if (v != stationId) newArr.put(v)
                            }
                            prefs.edit().putString("monitored_stations", newArr.toString()).apply()
                        }

                        // If there are no monitored stops or stations left, stop the service to save battery
                        val remainingStops = prefs.getString("monitored_stops", null)?.let { JSONObject(it).length() } ?: 0
                        val remainingStations = prefs.getString("monitored_stations", null)?.let { org.json.JSONArray(it).length() } ?: 0
                        if (remainingStops == 0 && remainingStations == 0) {
                            val stopIntent = android.content.Intent(this@MainActivity, RealtimeService::class.java).apply {
                                action = "stop"
                                putExtra("type", "buses")
                            }
                            startService(stopIntent)
                        }
                    }
                    result.success(null)
                }
                "isStopMonitored" -> {
                    val stopId = call.argument<String>("stopId")
                    var monitored = false
                    if (!stopId.isNullOrEmpty()) {
                        val prefs = getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
                        val json = prefs.getString("monitored_stops", null)
                        if (!json.isNullOrEmpty()) {
                            val obj = JSONObject(json)
                            monitored = obj.has(stopId)
                        }
                    }
                    result.success(monitored)
                }
                "getMonitoredStops" -> {
                    val prefs = getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
                    val json = prefs.getString("monitored_stops", null)
                    if (json.isNullOrEmpty()) {
                        result.success(mapOf<String, String>())
                    } else {
                        val obj = JSONObject(json)
                        val map = mutableMapOf<String, String>()
                        val keys = obj.keys()
                        while (keys.hasNext()) {
                            val k = keys.next()
                            map[k] = obj.optString(k)
                        }
                        result.success(map)
                    }
                }
                "getMonitoredStations" -> {
                    val prefs = getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
                    val json = prefs.getString("monitored_stations", null)
                    if (json.isNullOrEmpty()) {
                        result.success(listOf<String>())
                    } else {
                        val arr = org.json.JSONArray(json)
                        val list = mutableListOf<String>()
                        for (i in 0 until arr.length()) list.add(arr.optString(i))
                        result.success(list)
                    }
                }
                "getMonitoredTrips" -> {
                    val prefs = getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
                    val json = prefs.getString("monitored_trips", null)
                    if (json.isNullOrEmpty()) {
                        result.success(mapOf<String, String>())
                    } else {
                        val obj = JSONObject(json)
                        val map = mutableMapOf<String, String>()
                        val keys = obj.keys()
                        while (keys.hasNext()) {
                            val k = keys.next()
                            map[k] = obj.optString(k)
                        }
                        result.success(map)
                    }
                }
                "forceFetchTrip" -> {
                    val tripId = call.argument<String>("tripId")
                    val countryArg = call.argument<String>("country")?.takeIf { it.isNotBlank() }
                    var payload: String? = null
                    if (!tripId.isNullOrEmpty()) {
                        try {
                            val prefs = getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
                            val monitored = prefs.getString("monitored_trips", null)
                            var endpoint: String? = null
                            var metaCountry: String? = null
                            if (!monitored.isNullOrEmpty()) {
                                val obj = JSONObject(monitored)
                                if (obj.has(tripId)) {
                                    val meta = JSONObject(obj.getString(tripId))
                                    endpoint = meta.optString("endpoint", null)
                                    metaCountry = meta.optString("country", null)?.takeIf { it.isNotBlank() }
                                }
                            }
                            var url: String
                            if (!endpoint.isNullOrEmpty()) {
                                url = endpoint
                            } else {
                                val resolvedCountry = (countryArg ?: metaCountry)
                                if (resolvedCountry.isNullOrBlank()) {
                                    Log.d("MainActivity", "forceFetchTrip: no country or endpoint for $tripId, skipping")
                                    result.success(null)
                                    return@setMethodCallHandler
                                }
                                url = "https://prod.cuzimmartin.dev/api/${resolvedCountry.uppercase()}/trip?tripId=${Uri.encode(tripId)}"
                            }
                            val client = okhttp3.OkHttpClient()
                            val request = okhttp3.Request.Builder().url(url).get().build()
                            val resp = client.newCall(request).execute()
                            if (resp.isSuccessful) payload = resp.body?.string()
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                    result.success(payload)
                }
                "scheduleFunctionsWorker" -> {
                    val metric = call.argument<String>("metric")
                    val baseUrl = call.argument<String>("baseUrl")
                    val enable = call.argument<Boolean>("enableNotifications") ?: true
                    val endpoint = call.argument<String>("endpoint")
                    BackgroundScheduler.scheduleFunctionsWorker(this@MainActivity, metric, baseUrl, enable, endpoint)
                    result.success(null)
                }
                "cancelFunctionsWorker" -> {
                    BackgroundScheduler.cancelFunctionsWorker(this@MainActivity)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun canPostNotifications(): Boolean {
        if (Build.VERSION.SDK_INT >= 33) {
            return ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        }
        return true
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), PERMISSION_REQUEST_CODE)
        }
    }

    private fun canUseForegroundDataSync(): Boolean {
        if (Build.VERSION.SDK_INT >= 34) {
            return ContextCompat.checkSelfPermission(this, "android.permission.FOREGROUND_SERVICE_DATA_SYNC") == PackageManager.PERMISSION_GRANTED
        }
        return true
    }

    private fun requestForegroundDataSyncPermission() {
        if (Build.VERSION.SDK_INT >= 34) {
            ActivityCompat.requestPermissions(this, arrayOf("android.permission.FOREGROUND_SERVICE_DATA_SYNC"), PERMISSION_REQUEST_CODE)
        }
    }

    private fun showNotification(channelId: String, title: String?, body: String?) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // We assume channels were created in App.onCreate
        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            // Make notification expandable to show full details
            .setStyle(NotificationCompat.BigTextStyle().bigText(body ?: ""))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)

        notificationManager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), builder.build())
    }
}

