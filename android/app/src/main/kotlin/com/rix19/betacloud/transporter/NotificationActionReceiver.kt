package com.rix19.betacloud.transporter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject

class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return

        when (intent.action) {
            "STOP_FOLLOWING_TRIP" -> {
                val tripId = intent.getStringExtra("tripId") ?: return
                stopFollowingTrip(context, tripId)
            }
        }
    }

    private fun stopFollowingTrip(context: Context, tripId: String) {
        try {
            val prefs = context.getSharedPreferences("realtime_cache", Context.MODE_PRIVATE)
            
            // Remove from monitored trips
            val json = prefs.getString("monitored_trips", null)
            if (json != null) {
                val obj = JSONObject(json)
                if (obj.has(tripId)) {
                    obj.remove(tripId)
                    prefs.edit().putString("monitored_trips", obj.toString()).apply()
                    Log.d("NotificationActionReceiver", "Removed monitored trip: $tripId")
                }
            }
            
            // Cancel the notification
            NotificationHelper.cancelNotificationByKey(context, "train:$tripId")
            Log.d("NotificationActionReceiver", "Cancelled notification for trip: $tripId")
        } catch (e: Exception) {
            Log.e("NotificationActionReceiver", "Error stopping trip monitoring: ${e.message}")
        }
    }
}
