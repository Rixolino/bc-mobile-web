package com.example.bc_transporter_mobile

import android.content.Context
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object BackgroundScheduler {
    private const val TRAINS_WORK = "trains_periodic_work"
    private const val BUSES_WORK = "buses_periodic_work"
    private const val FUNCTIONS_WORK = "functions_periodic_work"

    fun schedulePeriodicWorkers(context: Context) {
        scheduleTrainsWorker(context)
        scheduleBusesWorker(context)
        scheduleFunctionsWorker(context)
    }

    fun scheduleTrainsWorker(
        context: Context,
        stationId: String? = null,
        country: String? = null,
        service: String? = null,
        enableNotifications: Boolean = true,
        endpoint: String? = null
    ) {
        val dataBuilder = androidx.work.Data.Builder()
        dataBuilder.putBoolean("enableNotifications", enableNotifications)
        stationId?.let { dataBuilder.putString("stationId", it) }
        country?.let { dataBuilder.putString("country", it) }
        service?.let { dataBuilder.putString("service", it) }
        endpoint?.let { dataBuilder.putString("endpoint", it) }

        val trainsRequest = PeriodicWorkRequestBuilder<TrainsWorker>(15, TimeUnit.MINUTES)
            .setInputData(dataBuilder.build())
            .build()
        val wm = WorkManager.getInstance(context.applicationContext)
        wm.enqueueUniquePeriodicWork(TRAINS_WORK, ExistingPeriodicWorkPolicy.KEEP, trainsRequest)
    }

    fun scheduleBusesWorker(
        context: Context,
        provider: String? = null,
        baseUrl: String? = null,
        enableNotifications: Boolean = true,
        endpoint: String? = null
    ) {
        val dataBuilder = androidx.work.Data.Builder()
        dataBuilder.putBoolean("enableNotifications", enableNotifications)
        provider?.let { dataBuilder.putString("provider", it) }
        baseUrl?.let { dataBuilder.putString("baseUrl", it) }
        endpoint?.let { dataBuilder.putString("endpoint", it) }

        val busesRequest = PeriodicWorkRequestBuilder<BusesWorker>(15, TimeUnit.MINUTES)
            .setInputData(dataBuilder.build())
            .build()
        val wm = WorkManager.getInstance(context.applicationContext)
        wm.enqueueUniquePeriodicWork(BUSES_WORK, ExistingPeriodicWorkPolicy.KEEP, busesRequest)
    }

    fun scheduleFunctionsWorker(
        context: Context,
        metric: String? = null,
        baseUrl: String? = null,
        enableNotifications: Boolean = true,
        endpoint: String? = null
    ) {
        val dataBuilder = androidx.work.Data.Builder()
        dataBuilder.putBoolean("enableNotifications", enableNotifications)
        metric?.let { dataBuilder.putString("metric", it) }
        baseUrl?.let { dataBuilder.putString("baseUrl", it) }
        endpoint?.let { dataBuilder.putString("endpoint", it) }

        val functionsRequest = PeriodicWorkRequestBuilder<FunctionsWorker>(12, TimeUnit.HOURS)
            .setInputData(dataBuilder.build())
            .build()
        val wm = WorkManager.getInstance(context.applicationContext)
        wm.enqueueUniquePeriodicWork(FUNCTIONS_WORK, ExistingPeriodicWorkPolicy.KEEP, functionsRequest)
    }

    fun cancelAll(context: Context) {
        val wm = WorkManager.getInstance(context.applicationContext)
        wm.cancelUniqueWork(TRAINS_WORK)
        wm.cancelUniqueWork(BUSES_WORK)
        wm.cancelUniqueWork(FUNCTIONS_WORK)
    }

    fun cancelTrainsWorker(context: Context) {
        WorkManager.getInstance(context.applicationContext).cancelUniqueWork(TRAINS_WORK)
    }

    fun cancelBusesWorker(context: Context) {
        WorkManager.getInstance(context.applicationContext).cancelUniqueWork(BUSES_WORK)
    }

    fun cancelFunctionsWorker(context: Context) {
        WorkManager.getInstance(context.applicationContext).cancelUniqueWork(FUNCTIONS_WORK)
    }
}
