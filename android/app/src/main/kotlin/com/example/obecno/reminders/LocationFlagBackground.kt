package com.example.obecno.reminders

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * Exact alarms that wake the process every 5 minutes to capture a location flag
 * even when the UI is closed or the phone is locked.
 */
internal object LocationFlagAlarmScheduler {
    const val ACTION = "com.obecno.LOCATION_FLAG_TICK"
    const val EXTRA_ID = "id"
    const val DEFAULT_ID = 91001
    private const val TAG = "LocationFlagAlarm"

    fun schedule(context: Context, id: Int, fireAt: Long) {
        val app = context.applicationContext
        val manager = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pendingIntent(app, id)
        val now = System.currentTimeMillis()
        if (fireAt <= now + 1_000L) {
            LocationFlagAlarmReceiver.deliver(app, id)
            return
        }
        val canExact =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()
        try {
            when {
                canExact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    manager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        fireAt,
                        pending,
                    )
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    manager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        fireAt,
                        pending,
                    )
                }
                else -> {
                    @Suppress("DEPRECATION")
                    manager.setExact(AlarmManager.RTC_WAKEUP, fireAt, pending)
                }
            }
            prefs(app).edit().putLong(KEY_NEXT, fireAt).putInt(KEY_ID, id).apply()
        } catch (error: Exception) {
            Log.e(TAG, "schedule failed id=$id", error)
        }
    }

    fun cancel(context: Context, id: Int = DEFAULT_ID) {
        val app = context.applicationContext
        val manager = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(pendingIntent(app, id))
        prefs(app).edit().remove(KEY_NEXT).remove(KEY_ID).apply()
    }

    fun reschedulePersisted(context: Context) {
        val app = context.applicationContext
        val fireAt = prefs(app).getLong(KEY_NEXT, 0L)
        val id = prefs(app).getInt(KEY_ID, DEFAULT_ID)
        if (fireAt <= 0L) return
        val now = System.currentTimeMillis()
        if (fireAt <= now + 1_000L) {
            LocationFlagAlarmReceiver.deliver(app, id)
        } else {
            schedule(app, id, fireAt)
        }
    }

    private fun pendingIntent(context: Context, id: Int): PendingIntent {
        val intent =
            Intent(context, LocationFlagAlarmReceiver::class.java).apply {
                action = ACTION
                putExtra(EXTRA_ID, id)
            }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            intent.addFlags(Intent.FLAG_RECEIVER_FOREGROUND)
        }
        return PendingIntent.getBroadcast(
            context,
            id,
            intent,
            AttendanceNotifier.pendingFlags(),
        )
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private const val PREFS = "obecno_location_flag_alarms"
    private const val KEY_NEXT = "next_fire_at"
    private const val KEY_ID = "alarm_id"
}

class LocationFlagAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val id =
            intent.getIntExtra(
                LocationFlagAlarmScheduler.EXTRA_ID,
                LocationFlagAlarmScheduler.DEFAULT_ID,
            )
        deliver(context, id)
    }

    companion object {
        fun deliver(context: Context, id: Int) {
            LocationFlagBackgroundWorker.runTick(context.applicationContext)
        }
    }
}

/**
 * Delivers a tick to the live Flutter engine when available, otherwise starts a
 * short-lived headless engine that runs [locationFlagBackgroundMain].
 */
internal object LocationFlagBackgroundWorker {
    const val CHANNEL = "com.obecno/location_flag_bg"
    const val MAIN_ENGINE_ID = "main"
    private const val TAG = "LocationFlagBg"
    private const val ENTRYPOINT = "locationFlagBackgroundMain"

    @Volatile
    private var headless: FlutterEngine? = null

    fun runTick(context: Context) {
        val app = context.applicationContext
        val main = FlutterEngineCache.getInstance().get(MAIN_ENGINE_ID)
        if (main != null && main.dartExecutor.isExecutingDart) {
            Handler(Looper.getMainLooper()).post {
                try {
                    MethodChannel(main.dartExecutor.binaryMessenger, CHANNEL)
                        .invokeMethod("tick", null)
                } catch (error: Exception) {
                    Log.e(TAG, "live tick failed", error)
                    startHeadless(app)
                }
            }
            return
        }
        startHeadless(app)
    }

    private fun startHeadless(app: Context) {
        Handler(Looper.getMainLooper()).post {
            try {
                headless?.destroy()
                headless = null

                val loader = FlutterInjector.instance().flutterLoader()
                if (!loader.initialized()) {
                    loader.startInitialization(app)
                }
                loader.ensureInitializationComplete(app, null)

                val engine = FlutterEngine(app.applicationContext)
                headless = engine
                try {
                    io.flutter.plugins.GeneratedPluginRegistrant.registerWith(engine)
                } catch (error: Exception) {
                    Log.e(TAG, "plugin registrant failed", error)
                }

                val channel =
                    MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "schedule" -> {
                            val id =
                                call.argument<Number>("id")?.toInt()
                                    ?: LocationFlagAlarmScheduler.DEFAULT_ID
                            val fireAt =
                                call.argument<Number>("fireAt")?.toLong() ?: 0L
                            if (fireAt > 0L) {
                                LocationFlagAlarmScheduler.schedule(app, id, fireAt)
                            }
                            result.success(true)
                        }
                        "cancel" -> {
                            val id =
                                call.argument<Number>("id")?.toInt()
                                    ?: LocationFlagAlarmScheduler.DEFAULT_ID
                            LocationFlagAlarmScheduler.cancel(app, id)
                            result.success(true)
                        }
                        "done" -> {
                            result.success(true)
                            Handler(Looper.getMainLooper()).postDelayed({
                                try {
                                    engine.destroy()
                                } catch (_: Exception) {
                                }
                                if (headless === engine) headless = null
                            }, 250)
                        }
                        else -> result.notImplemented()
                    }
                }

                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        loader.findAppBundlePath(),
                        ENTRYPOINT,
                    ),
                )
            } catch (error: Exception) {
                Log.e(TAG, "headless start failed", error)
            }
        }
    }

    fun attachMainChannel(engine: FlutterEngine, context: Context) {
        val app = context.applicationContext
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "schedule" -> {
                        val id =
                            call.argument<Number>("id")?.toInt()
                                ?: LocationFlagAlarmScheduler.DEFAULT_ID
                        val fireAt =
                            call.argument<Number>("fireAt")?.toLong() ?: 0L
                        if (fireAt > 0L) {
                            LocationFlagAlarmScheduler.schedule(app, id, fireAt)
                        }
                        result.success(true)
                    }
                    "cancel" -> {
                        val id =
                            call.argument<Number>("id")?.toInt()
                                ?: LocationFlagAlarmScheduler.DEFAULT_ID
                        LocationFlagAlarmScheduler.cancel(app, id)
                        result.success(true)
                    }
                    "done" -> result.success(true)
                    else -> result.notImplemented()
                }
            }
    }
}
