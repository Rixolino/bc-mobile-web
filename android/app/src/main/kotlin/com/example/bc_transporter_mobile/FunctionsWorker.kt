package com.example.bc_transporter_mobile

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

class FunctionsWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    private val client = OkHttpClient()

    override suspend fun doWork(): Result {
        try {
            // Allow control via inputData (endpoint and enable flag)
            val enabled = inputData.getBoolean("enableNotifications", true)
            if (!enabled) return Result.success()

            val customEndpoint = inputData.getString("endpoint")
            val metric = inputData.getString("metric") ?: "active-connections"
            val baseUrl = inputData.getString("baseUrl") ?: "https://betacloud-transporter.is-cool.dev"

            val url = customEndpoint ?: "$baseUrl/api/$metric"

            val request = Request.Builder().url(url).get().build()

            client.newCall(request).execute().use { resp ->
                if (!resp.isSuccessful) return Result.retry()
                val body = resp.body?.string() ?: return Result.success()
                // Parse simple metric responses
                try {
                    val json = JSONObject(body)
                    val active = json.optInt("active", -1)
                    if (active >= 0) {
                        NotificationHelper.showNotification(applicationContext, NotificationHelper.CHANNEL_FUNCTIONS, "Utenti attivi", "$active utenti connessi al servizio")
                    } else {
                        // If metric not present, show generic message
                        NotificationHelper.showNotification(applicationContext, NotificationHelper.CHANNEL_FUNCTIONS, "Stato servizio", "Servizio BC Transporter attivo")
                    }
                } catch (e: Exception) {
                    NotificationHelper.showNotification(applicationContext, NotificationHelper.CHANNEL_FUNCTIONS, "Stato servizio", "Servizio BC Transporter attivo")
                }
            }

            return Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            return Result.retry()
        }
    }
}
