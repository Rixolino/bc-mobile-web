package com.rix19.betacloud.transporter

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject

class TransportsWorker(appContext: Context, params: WorkerParameters) : CoroutineWorker(appContext, params) {
    private val client = OkHttpClient()

    override suspend fun doWork(): Result {
        try {
            // Esempio: fetch aggiornamenti treni - sostituire con API reali
            val request = Request.Builder()
                .url("https://api.example.com/transports/updates")
                .get()
                .build()

            client.newCall(request).execute().use { resp ->
                if (!resp.isSuccessful) return Result.retry()
                val body = resp.body?.string() ?: return Result.success()
                // Parse semplificato
                val json = JSONObject(body)
                val important = json.optString("important_message")
                if (important.isNotEmpty()) {
                    NotificationHelper.showNotification(applicationContext, NotificationHelper.CHANNEL_TRANSPORTS, "Aggiornamento trasporti", important)
                }
            }

            return Result.success()
        } catch (e: Exception) {
            e.printStackTrace()
            return Result.retry()
        }
    }
}


