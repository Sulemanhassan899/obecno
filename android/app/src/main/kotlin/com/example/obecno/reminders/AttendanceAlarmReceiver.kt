package com.example.obecno.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AttendanceAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val scheduled =
            intent.getLongExtra(AttendanceAlarmScheduler.EXTRA_FIRE_AT, 0L).takeIf { it > 0L }
                ?: System.currentTimeMillis()
        val alarm =
            StoredAlarm(
                id = intent.getIntExtra(AttendanceAlarmScheduler.EXTRA_ID, 0),
                type = intent.getStringExtra(AttendanceAlarmScheduler.EXTRA_TYPE).orEmpty(),
                title =
                    intent.getStringExtra(AttendanceAlarmScheduler.EXTRA_TITLE)
                        ?: "Attendance reminder",
                message = intent.getStringExtra(AttendanceAlarmScheduler.EXTRA_MESSAGE).orEmpty(),
                // Prefer the planned minute — wall-clock "now" created duplicate
                // Alerts rows next to Flutter's scheduled fireAt.
                fireAt = scheduled,
                payload =
                    intent.getStringExtra(AttendanceAlarmScheduler.EXTRA_PAYLOAD).orEmpty(),
                isTest =
                    intent.getBooleanExtra(AttendanceAlarmScheduler.EXTRA_IS_TEST, false),
            )
        deliver(context, alarm)
    }

    companion object {
        /** @return true when the banner was posted (alarm can be dropped). */
        internal fun deliver(context: Context, alarm: StoredAlarm): Boolean {
            val app = context.applicationContext
            val title =
                if (alarm.isTest) "Test successful" else alarm.title
            val message =
                if (alarm.isTest) "Your reminders are ready." else alarm.message
            val posted =
                AttendanceNotifier.show(
                    app,
                    alarm.id,
                    title,
                    message,
                    alarm.payload.ifBlank { alarm.type },
                )
            // Keep the alarm if permission blocked the banner so a later
            // reschedule can try again instead of silently consuming it.
            if (!posted) return false
            val store = AttendanceAlarmStore(app)
            store.appendFired(alarm)
            store.remove(alarm.id)
            return true
        }
    }
}
