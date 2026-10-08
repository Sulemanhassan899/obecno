package com.example.obecno

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.example.obecno.reminders.AttendanceNotifier
import com.example.obecno.reminders.AttendanceReminderChannel
import com.example.obecno.reminders.LocationFlagBackgroundWorker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var reminderChannel: AttendanceReminderChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put(LocationFlagBackgroundWorker.MAIN_ENGINE_ID, flutterEngine)
        LocationFlagBackgroundWorker.attachMainChannel(flutterEngine, this)
        reminderChannel = AttendanceReminderChannel(this, flutterEngine, intent)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PERMISSIONS_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openLocationPermissionSettings" -> {
                    result.success(openLocationPermissionSettings())
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Opens the **Location permission** screen (Allow all the time / While
     * using / …) by requesting ACCESS_BACKGROUND_LOCATION.
     *
     * This is the OS path that shows the radio-button Location page — not
     * the generic "App permissions" list.
     */
    private fun openLocationPermissionSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return false
        }

        val fine = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_COARSE_LOCATION,
        ) == PackageManager.PERMISSION_GRANTED
        if (!fine && !coarse) {
            Log.w(TAG, "Cannot open Always location UI without When-In-Use")
            return false
        }

        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
            REQUEST_BACKGROUND_LOCATION,
        )
        return true
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        maybePostDebugNotification(intent)
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        reminderChannel?.onNewIntent(intent)
        maybePostDebugNotification(intent)
    }

    /** adb: am start -n com.obecno.app/com.example.obecno.MainActivity --ez debug_notify true */
    private fun maybePostDebugNotification(intent: android.content.Intent?) {
        if (intent?.getBooleanExtra(EXTRA_DEBUG_NOTIFY, false) != true) return
        intent.removeExtra(EXTRA_DEBUG_NOTIFY)
        Log.i(TAG, "debug_notify — posting test banner")
        AttendanceNotifier.show(
            this,
            88025,
            "Location flag",
            "Debug notify from MainActivity. If you see this, native posts work.",
            "location-flag-test",
        )
    }

    companion object {
        private const val TAG = "MainActivity"
        private const val PERMISSIONS_CHANNEL = "obecno/permissions"
        private const val REQUEST_BACKGROUND_LOCATION = 48121
        const val EXTRA_DEBUG_NOTIFY = "debug_notify"
    }
}
