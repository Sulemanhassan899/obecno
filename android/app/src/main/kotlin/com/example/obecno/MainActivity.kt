package com.example.obecno

import android.content.Intent
import com.example.obecno.reminders.AttendanceReminderChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var reminderChannel: AttendanceReminderChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        reminderChannel = AttendanceReminderChannel(this, flutterEngine, intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        reminderChannel?.onNewIntent(intent)
    }
}
