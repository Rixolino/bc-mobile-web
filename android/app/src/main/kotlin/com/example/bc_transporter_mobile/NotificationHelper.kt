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
    // Channel for proximity / arrival alerts
    const val CHANNEL_TRAIN_PROXIMITY = "trains_proximity_channel"

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

            val trainProx = NotificationChannel(
                CHANNEL_TRAIN_PROXIMITY,
                "Avvisi arrivo stazione",
                NotificationManager.IMPORTANCE_HIGH
            ).apply { description = "Notifiche di preavviso per l'arrivo alla stazione selezionata" }

            val functions = NotificationChannel(
                CHANNEL_FUNCTIONS,
                "Notifiche Funzioni",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply { description = "Notifiche generali dell'app" }

            nm.createNotificationChannel(transports)
            nm.createNotificationChannel(trains)
            nm.createNotificationChannel(buses)
            nm.createNotificationChannel(trainProx)
            nm.createNotificationChannel(functions)
        }
    }

    fun getIdForKey(key: String): Int {
        var h = key.hashCode()
        if (h == Int.MIN_VALUE) h = 0
        return kotlin.math.abs(h) % Int.MAX_VALUE
    }

    fun showNotification(context: Context, channelId: String, title: String, body: String, notificationId: Int? = null) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        val builder = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            // make expandable
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)

        val id = notificationId ?: ((System.currentTimeMillis() % Int.MAX_VALUE).toInt())
        nm.notify(id, builder.build())
    }

    fun cancelNotificationByKey(context: Context, key: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val id = getIdForKey(key)
        nm.cancel(id)
    }
}
