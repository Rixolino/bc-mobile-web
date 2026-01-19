package com.example.bc_transporter_mobile

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
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
                    
                    if (canPostNotifications()) {
                        showNotification(channel, title, body)
                        result.success(null)
                    } else {
                        requestNotificationPermission()
                        result.error("PERMISSION_DENIED", "Notification permission missing", null)
                    }
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
                    BackgroundScheduler.scheduleTrainsWorker(this@MainActivity, stationId, country, service, enable, endpoint)
                    result.success(null)
                }
                "cancelTrainsWorker" -> {
                    BackgroundScheduler.cancelTrainsWorker(this@MainActivity)
                    result.success(null)
                }
                "scheduleBusesWorker" -> {
                    val provider = call.argument<String>("provider")
                    val baseUrl = call.argument<String>("baseUrl")
                    val enable = call.argument<Boolean>("enableNotifications") ?: true
                    val endpoint = call.argument<String>("endpoint")
                    BackgroundScheduler.scheduleBusesWorker(this@MainActivity, provider, baseUrl, enable, endpoint)
                    result.success(null)
                }
                "cancelBusesWorker" -> {
                    BackgroundScheduler.cancelBusesWorker(this@MainActivity)
                    result.success(null)
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

    private fun showNotification(channelId: String, title: String?, body: String?) {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // We assume channels were created in App.onCreate
        val builder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)

        notificationManager.notify((System.currentTimeMillis() % Int.MAX_VALUE).toInt(), builder.build())
    }
}

