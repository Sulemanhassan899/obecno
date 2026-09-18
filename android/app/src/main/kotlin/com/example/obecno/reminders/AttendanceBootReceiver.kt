package com.example.obecno.reminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AttendanceBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_TIME_CHANGED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            -> AttendanceAlarmScheduler.reschedulePersisted(context)
        }
    }
}
