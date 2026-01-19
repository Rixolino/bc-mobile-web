package com.example.bc_transporter_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

object NotificationHelper {
    const val CHANNEL_TRANSPORTS = "transports_updates_channel"
    const val CHANNEL_FUNCTIONS = "functions_updates_channel"
    const val CHANNEL_TRAINS = "trains_updates_channel"
    const val CHANNEL_BUSES = "buses_updates_channel"

    fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val transports = NotificationChannel(
                CHANNEL_TRANSPORTS,
                "Aggiornamenti Trasporti",
                NotificationManager.IMPORTANCE_HIGH
            ).apply { description = "Notifiche su treni e bus (generale)" }

            val trains = NotificationChannel(
                CHANNEL_TRAINS,
                "Aggiornamenti Treni",
                NotificationManager.IMPORTANCE_HIGH
            ).apply { description = "Notifiche specifiche sui treni" }

            val buses = NotificationChannel(
                CHANNEL_BUSES,
                "Aggiornamenti Bus",
                NotificationManager.IMPORTANCE_HIGH
            ).apply { description = "Notifiche specifiche sui bus" }

            val functions = NotificationChannel(
                CHANNEL_FUNCTIONS,
                "Notifiche Funzioni",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = "Notifiche generali dell'app" }

            nm.createNotificationChannel(transports)
            nm.createNotificationChannel(trains)
            nm.createNotificationChannel(buses)
            nm.createNotificationChannel(functions)
        }
    }

    fun showNotification(context: Context, channelId: String, title: String, body: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)

        nm.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), builder.build())
    }
}
