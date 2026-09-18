package com.example.obecno.reminders

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
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

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val channel =
            NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = CHANNEL_DESCRIPTION
                enableVibration(true)
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
        ensureChannel(context)
        val tap =
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_PAYLOAD, payload)
            }
        val flags = pendingFlags()
        val contentIntent =
            PendingIntent.getActivity(context, id, tap, flags)
        val color = ContextCompat.getColor(context, R.color.obecno_reminder_green)
        val notification =
            NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_obecno)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(NotificationCompat.BigTextStyle().bigText(message))
                .setAutoCancel(false)
                .setOngoing(false)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setColor(color)
                .setContentIntent(contentIntent)
                .build()
        NotificationManagerCompat.from(context).notify(id, notification)
    }

    fun pendingFlags(): Int {
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        return flags
    }
}
