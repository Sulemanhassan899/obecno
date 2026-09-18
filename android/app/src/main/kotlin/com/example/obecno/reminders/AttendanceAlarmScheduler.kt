package com.example.obecno.reminders

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat

internal object AttendanceAlarmScheduler {
    const val ACTION = "com.obecno.ATTENDANCE_ALARM"
    const val EXTRA_ID = "id"
    const val EXTRA_TITLE = "title"
    const val EXTRA_MESSAGE = "message"
    const val EXTRA_PAYLOAD = "payload"
    const val EXTRA_TYPE = "type"
    const val EXTRA_IS_TEST = "isTest"

    fun replaceAll(context: Context, alarms: List<StoredAlarm>) {
        val store = AttendanceAlarmStore(context)
        val previous = store.load().filter { !it.isTest }
        previous.forEach { cancel(context, it.id) }
        val kept = store.replaceNonTest(alarms)
        kept.filter { !it.isTest }.forEach { schedule(context, it) }
    }

    fun upsert(context: Context, alarms: List<StoredAlarm>) {
        val store = AttendanceAlarmStore(context)
        store.upsert(alarms)
        alarms.forEach { schedule(context, it) }
    }

    fun cancelIds(context: Context, ids: Collection<Int>) {
        ids.forEach { cancel(context, it) }
        AttendanceAlarmStore(context).removeIds(ids)
    }

    fun cancelAll(context: Context, includeTest: Boolean = true) {
        val store = AttendanceAlarmStore(context)
        store.load().forEach { alarm ->
            if (includeTest || !alarm.isTest) cancel(context, alarm.id)
        }
        store.clear(includeTest)
    }

    fun schedule(context: Context, alarm: StoredAlarm) {
        val app = context.applicationContext
        val manager = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pending = pendingIntent(app, alarm)
        val triggerAt = alarm.fireAt
        val now = System.currentTimeMillis()
        if (triggerAt <= now + 1_000L) {
            AttendanceAlarmReceiver.deliver(app, alarm)
            return
        }
        val canExact =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.S || manager.canScheduleExactAlarms()
        if (canExact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            val show =
                PendingIntent.getActivity(
                    app,
                    alarm.id,
                    Intent(app, com.example.obecno.MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    },
                    AttendanceNotifier.pendingFlags(),
                )
            manager.setAlarmClock(AlarmManager.AlarmClockInfo(triggerAt, show), pending)
            return
        }
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                manager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pending,
                )
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                @Suppress("DEPRECATION")
                manager.setExact(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            }
            else -> {
                @Suppress("DEPRECATION")
                manager.set(AlarmManager.RTC_WAKEUP, triggerAt, pending)
            }
        }
    }

    fun cancel(context: Context, id: Int) {
        val app = context.applicationContext
        val manager = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        manager.cancel(pendingIntent(app, id = id))
    }

    fun reschedulePersisted(context: Context) {
        val now = System.currentTimeMillis()
        val store = AttendanceAlarmStore(context)
        val remaining = mutableListOf<StoredAlarm>()
        store.load().forEach { alarm ->
            val lateBy = now - alarm.fireAt
            when {
                lateBy > 2 * 60 * 1000L -> {
                    cancel(context, alarm.id)
                }
                lateBy >= -1_000L -> {
                    AttendanceAlarmReceiver.deliver(context, alarm)
                }
                else -> {
                    remaining.add(alarm)
                    schedule(context, alarm)
                }
            }
        }
        store.save(remaining)
    }

    fun health(context: Context): Map<String, Any?> {
        val app = context.applicationContext
        val notifications = NotificationManagerCompat.from(app).areNotificationsEnabled()
        val manager = app.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val exact =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                manager.canScheduleExactAlarms()
            } else {
                true
            }
        val batteryUnrestricted =
            AttendanceBatteryExemption.isIgnoringBatteryOptimizations(app)
        val next =
            AttendanceAlarmStore(app)
                .load()
                .filter { it.fireAt > System.currentTimeMillis() }
                .minByOrNull { it.fireAt }
        return mapOf(
            "notificationsAllowed" to notifications,
            "exactAlarmsAllowed" to exact,
            "batteryUnrestricted" to batteryUnrestricted,
            "nextFireAt" to next?.fireAt,
            "nextTitle" to next?.title,
            "sdk" to Build.VERSION.SDK_INT,
        )
    }

    fun openNotificationSettings(context: Context) {
        val intent =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                }
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = android.net.Uri.parse("package:${context.packageName}")
                }
            }
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    fun openExactAlarmSettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent =
                Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                    data = android.net.Uri.parse("package:${context.packageName}")
                }
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            return
        }
        openAppDetails(context)
    }

    fun openBatterySettings(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val request =
                Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = android.net.Uri.parse("package:${context.packageName}")
                }
            if (context !is android.app.Activity) {
                request.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            try {
                context.startActivity(request)
                return
            } catch (_: Exception) {
                try {
                    context.startActivity(
                        Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    return
                } catch (_: Exception) {
                    // Fall through to app details on OEM skins that hide this page.
                }
            }
        }
        openAppDetails(context)
    }

    fun openAppDetails(context: Context) {
        val intent =
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = android.net.Uri.parse("package:${context.packageName}")
            }
        context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun pendingIntent(context: Context, alarm: StoredAlarm): PendingIntent =
        pendingIntent(
            context,
            id = alarm.id,
            extras = { intent ->
                intent.putExtra(EXTRA_ID, alarm.id)
                intent.putExtra(EXTRA_TITLE, alarm.title)
                intent.putExtra(EXTRA_MESSAGE, alarm.message)
                intent.putExtra(EXTRA_PAYLOAD, alarm.payload)
                intent.putExtra(EXTRA_TYPE, alarm.type)
                intent.putExtra(EXTRA_IS_TEST, alarm.isTest)
            },
        )

    private fun pendingIntent(
        context: Context,
        id: Int,
        extras: (Intent) -> Unit = {},
    ): PendingIntent {
        val intent =
            Intent(context, AttendanceAlarmReceiver::class.java).apply {
                action = ACTION
                extras(this)
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
}
