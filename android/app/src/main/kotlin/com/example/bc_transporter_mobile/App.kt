package com.example.bc_transporter_mobile

import android.app.Application

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        // Inizializza canali di notifica e schedulazione background
        NotificationHelper.createChannels(this)
        BackgroundScheduler.schedulePeriodicWorkers(this)
    }
}
