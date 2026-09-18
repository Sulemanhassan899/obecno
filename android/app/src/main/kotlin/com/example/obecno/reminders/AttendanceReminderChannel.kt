package com.example.obecno.reminders

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AttendanceReminderChannel(
    private val activity: android.app.Activity,
    flutterEngine: FlutterEngine,
    launchIntent: Intent?,
) : MethodChannel.MethodCallHandler {
    private val channel =
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        )
    private val store = AttendanceAlarmStore(activity)

    init {
        channel.setMethodCallHandler(this)
        val payload = launchIntent?.getStringExtra(AttendanceNotifier.EXTRA_PAYLOAD)
        if (!payload.isNullOrBlank()) {
            store.setLaunchPayload(payload)
        }
    }

    fun onNewIntent(intent: Intent) {
        val payload = intent.getStringExtra(AttendanceNotifier.EXTRA_PAYLOAD) ?: return
        store.setLaunchPayload(payload)
        channel.invokeMethod("onNotificationTap", payload)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "replaceAll" -> {
                    AttendanceAlarmScheduler.replaceAll(activity, parseAlarms(call))
                    result.success(true)
                }
                "upsert" -> {
                    AttendanceAlarmScheduler.upsert(activity, parseAlarms(call))
                    result.success(true)
                }
                "cancelIds" -> {
                    val ids = call.argument<List<Int>>("ids") ?: emptyList()
                    AttendanceAlarmScheduler.cancelIds(activity, ids)
                    result.success(true)
                }
                "cancelAll" -> {
                    AttendanceAlarmScheduler.cancelAll(activity)
                    result.success(true)
                }
                "show" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: "Attendance reminder"
                    val message = call.argument<String>("message") ?: ""
                    val payload = call.argument<String>("payload")
                    AttendanceNotifier.show(activity, id, title, message, payload)
                    result.success(true)
                }
                "scheduleTest" -> {
                    val fireAt =
                        call.argument<Number>("fireAt")?.toLong()
                            ?: (System.currentTimeMillis() + 60_000L)
                    val alarm =
                        StoredAlarm(
                            id = AttendanceAlarmStore.TEST_ID,
                            type = "test",
                            title = call.argument<String>("title") ?: "Test reminder",
                            message =
                                call.argument<String>("message")
                                    ?: "Lock your phone. You don't need to keep Obecno open.",
                            fireAt = fireAt,
                            payload = "test",
                            isTest = true,
                        )
                    AttendanceAlarmScheduler.upsert(activity, listOf(alarm))
                    result.success(fireAt)
                }
                "health" -> result.success(AttendanceAlarmScheduler.health(activity))
                "ensureUnrestricted" -> {
                    AttendanceBatteryExemption.ensureUnrestricted(activity)
                    result.success(true)
                }
                "openNotificationSettings" -> {
                    AttendanceAlarmScheduler.openNotificationSettings(activity)
                    result.success(true)
                }
                "openExactAlarmSettings" -> {
                    AttendanceAlarmScheduler.openExactAlarmSettings(activity)
                    result.success(true)
                }
                "openBatterySettings" -> {
                    AttendanceAlarmScheduler.openBatterySettings(activity)
                    result.success(true)
                }
                "openAppDetails" -> {
                    AttendanceAlarmScheduler.openAppDetails(activity)
                    result.success(true)
                }
                "getLaunchPayload" -> result.success(store.consumeLaunchPayload())
                else -> result.notImplemented()
            }
        } catch (error: Exception) {
            result.error("reminder_native", error.message, null)
        }
    }

    private fun parseAlarms(call: MethodCall): List<StoredAlarm> {
        val raw = call.argument<List<Any>>("alarms") ?: return emptyList()
        return raw.mapNotNull { item ->
            val map = item as? Map<*, *> ?: return@mapNotNull null
            val id = (map["id"] as? Number)?.toInt() ?: return@mapNotNull null
            val fireAt = (map["fireAt"] as? Number)?.toLong() ?: return@mapNotNull null
            StoredAlarm(
                id = id,
                type = map["type"] as? String ?: "",
                title = map["title"] as? String ?: "",
                message = map["message"] as? String ?: "",
                fireAt = fireAt,
                payload = map["payload"] as? String ?: "",
                isTest = map["isTest"] as? Boolean ?: false,
            )
        }
    }

    companion object {
        const val CHANNEL = "com.obecno/attendance_reminders"
    }
}
