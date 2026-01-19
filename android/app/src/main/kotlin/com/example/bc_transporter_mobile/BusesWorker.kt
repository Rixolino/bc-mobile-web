package com.example.bc_transporter_mobile

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.util.Locale

class BusesWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    private val client = OkHttpClient()

    override suspend fun doWork(): Result {
        try {
            // Use inputData to determine provider and base url
            val enabled = inputData.getBoolean("enableNotifications", true)
            if (!enabled) return Result.success()

            val provider = inputData.getString("provider") ?: "bari"
            val baseUrl = inputData.getString("baseUrl") ?: "https://betacloud-transporter.is-cool.dev"
            val customEndpoint = inputData.getString("endpoint")

            val url = when {
                !customEndpoint.isNullOrEmpty() -> customEndpoint
                provider.isNotEmpty() -> "$baseUrl/api/it/bus/${provider.lowercase()}/realtime?includeTripUpdates=true"
                else -> "$baseUrl/api/it/bus/bari/bus-realtime?includeTripUpdates=true"
            }

            val request = Request.Builder()
                .url(url)
                .get()
                .build()

            client.newCall(request).execute().use { resp ->
                if (!resp.isSuccessful) return Result.retry()
                val body = resp.body?.string() ?: return Result.success()
                // Parse realtime data
                try {
                    val json = JSONObject(body)
                    val vehicles = json.optJSONArray("vehicles")
                    val tripUpdates = json.optJSONArray("tripUpdates")
                    val vCount = vehicles?.length() ?: 0
                    val tCount = tripUpdates?.length() ?: 0
                    val totalUpdates = vCount + tCount
                    if (totalUpdates > 0) {
                        val providerDisplay = provider.replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale.getDefault()) else it.toString() }
                        val title = "Aggiornamento bus ($providerDisplay)"
                        NotificationHelper.showNotification(applicationContext, NotificationHelper.CHANNEL_BUSES, title, "$totalUpdates aggiornamenti realtime disponibili")
                    }
                } catch (e: Exception) {
                    // Fallback: notify generic update
                    NotificationHelper.showNotification(applicationContext, NotificationHelper.CHANNEL_BUSES, "Aggiornamento bus", "Controlla gli orari dei bus")
                }
            }

            return Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            return Result.retry()
        }
    }
}
