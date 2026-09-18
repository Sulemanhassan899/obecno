package com.example.obecno.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AttendanceAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val alarm =
            StoredAlarm(
                id = intent.getIntExtra(AttendanceAlarmScheduler.EXTRA_ID, 0),
                type = intent.getStringExtra(AttendanceAlarmScheduler.EXTRA_TYPE).orEmpty(),
                title =
                    intent.getStringExtra(AttendanceAlarmScheduler.EXTRA_TITLE)
                        ?: "Attendance reminder",
                message = intent.getStringExtra(AttendanceAlarmScheduler.EXTRA_MESSAGE).orEmpty(),
                fireAt = System.currentTimeMillis(),
                payload =
                    intent.getStringExtra(AttendanceAlarmScheduler.EXTRA_PAYLOAD).orEmpty(),
                isTest =
                    intent.getBooleanExtra(AttendanceAlarmScheduler.EXTRA_IS_TEST, false),
            )
        deliver(context, alarm)
    }

    companion object {
        internal fun deliver(context: Context, alarm: StoredAlarm) {
            val app = context.applicationContext
            val title =
                if (alarm.isTest) "Test successful" else alarm.title
            val message =
                if (alarm.isTest) "Your reminders are ready." else alarm.message
            AttendanceNotifier.show(
                app,
                alarm.id,
                title,
                message,
                alarm.payload.ifBlank { alarm.type },
            )
            AttendanceAlarmStore(app).remove(alarm.id)
        }
    }
}
