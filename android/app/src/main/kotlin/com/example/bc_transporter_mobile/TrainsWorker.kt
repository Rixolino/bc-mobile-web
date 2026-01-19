package com.example.bc_transporter_mobile

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

class TrainsWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    private val client = OkHttpClient()

    override suspend fun doWork(): Result {
        try {
            // Read parameters from inputData to avoid hardcoded endpoints
            val enabled = inputData.getBoolean("enableNotifications", true)
            if (!enabled) return Result.success()

            val stationId = inputData.getString("stationId") ?: ""
            val country = inputData.getString("country") ?: "IT"
            val service = inputData.getString("service") ?: "trainboardeu"
            val customEndpoint = inputData.getString("endpoint") // optional full endpoint

            // Always use production train API
            val prodBase = "https://prod.cuzimmartin.dev/api"
            val url = when {
                !customEndpoint.isNullOrEmpty() -> customEndpoint
                service == "direct" && country == "IT" && stationId.isNotEmpty() -> "$prodBase/rfi-departures?placeId=$stationId"
                stationId.isNotEmpty() -> if (country == "UK_LONDON") "$prodBase/gb/london/departures?stationId=$stationId" else "$prodBase/$country/departures?stationId=$stationId"
                else -> "$prodBase/it/departures?limit=1"
            }

            val request = Request.Builder()
                .url(url)
                .get()
                .build()

            client.newCall(request).execute().use { resp ->
                if (!resp.isSuccessful) return Result.retry()
                val body = resp.body?.string() ?: return Result.success()
                // Parse departures array and detect delays
                try {
                    val json = JSONObject(body)
                    val data = json.optJSONArray("data") ?: return Result.success()
                    var delayedTrains = 0
                    for (i in 0 until data.length()) {
                        val dep = data.optJSONObject(i)
                        val delay = dep?.optInt("delayMinutes", 0) ?: 0
                        if (delay > 0) delayedTrains++
                    }
                    if (delayedTrains > 0) {
                        val title = if (stationId.isNotEmpty()) "Ritardi treni ($stationId)" else "Ritardi treni"
                        NotificationHelper.showNotification(applicationContext, NotificationHelper.CHANNEL_TRAINS, title, "$delayedTrains treni in ritardo")
                    }
                } catch (e: Exception) {
                    // Fallback: generic update
                    NotificationHelper.showNotification(applicationContext, NotificationHelper.CHANNEL_TRAINS, "Aggiornamento treni", "Controlla gli orari dei treni")
                }
            }

            return Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            return Result.retry()
        }
    }
}
