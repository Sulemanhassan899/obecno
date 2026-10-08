package com.example.obecno.reminders

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.example.obecno.MainActivity
import com.example.obecno.R

internal object AttendanceNotifier {
    const val CHANNEL_ID = "attendance_reminders"
    const val CHANNEL_NAME = "Attendance Reminders"
    const val CHANNEL_DESCRIPTION =
        "Check-in, check-out, break, and attendance reminders."
    const val EXTRA_PAYLOAD = "reminder_payload"
    private const val TAG = "AttendanceNotifier"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        // Recreate if an older install left the channel at a lower importance.
        if (existing != null && existing.importance < NotificationManager.IMPORTANCE_HIGH) {
            manager.deleteNotificationChannel(CHANNEL_ID)
        }
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = CHANNEL_DESCRIPTION
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
        manager.createNotificationChannel(channel)
    }

    fun show(
        context: Context,
        id: Int,
        title: String,
        message: String,
        payload: String?,
    ) {
        val app = context.applicationContext
        ensureChannel(app)
        val nm = NotificationManagerCompat.from(app)
        // Still attempt notify even if areNotificationsEnabled is false —
        // some OEM / emulator builds report false incorrectly. Permission
        // failures are caught below.
        val tap =
            Intent(app, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_PAYLOAD, payload)
            }
        val contentIntent =
            PendingIntent.getActivity(app, id, tap, pendingFlags())
        val color = ContextCompat.getColor(app, R.color.obecno_reminder_green)
        val notification =
            NotificationCompat.Builder(app, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_obecno)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setAutoCancel(true)
                .setOngoing(false)
                .setOnlyAlertOnce(false)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setColor(color)
                .setContentIntent(contentIntent)
                .build()
        try {
            nm.notify(id, notification)
            Log.i(
                TAG,
                "Posted id=$id title=$title enabled=${nm.areNotificationsEnabled()}",
            )
        } catch (error: SecurityException) {
            Log.e(TAG, "POST_NOTIFICATIONS missing for id=$id", error)
        } catch (error: Exception) {
            Log.e(TAG, "Failed to post id=$id", error)
        }
    }

    fun pendingFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }
}
