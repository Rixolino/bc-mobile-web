package com.example.bc_transporter_mobile

import android.app.Application

class App : Application() {
    override fun onCreate() {
        super.onCreate()
        // Inizializza canali di notifica
        NotificationHelper.createChannels(this)
        // Functions worker (periodic long-running tasks) stays scheduled here if needed
        BackgroundScheduler.scheduleFunctionsWorker(this)
    }
}
