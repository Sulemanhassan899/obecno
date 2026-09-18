package com.example.obecno.reminders

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

internal data class StoredAlarm(
    val id: Int,
    val type: String,
    val title: String,
    val message: String,
    val fireAt: Long,
    val payload: String,
    val isTest: Boolean = false,
) {
    fun toJson(): JSONObject =
        JSONObject()
            .put("id", id)
            .put("type", type)
            .put("title", title)
            .put("message", message)
            .put("fireAt", fireAt)
            .put("payload", payload)
            .put("isTest", isTest)

    companion object {
        fun fromJson(obj: JSONObject): StoredAlarm =
            StoredAlarm(
                id = obj.getInt("id"),
                type = obj.optString("type"),
                title = obj.optString("title"),
                message = obj.optString("message"),
                fireAt = obj.getLong("fireAt"),
                payload = obj.optString("payload"),
                isTest = obj.optBoolean("isTest"),
            )
    }
}

internal class AttendanceAlarmStore(context: Context) {
    private val prefs =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun load(): List<StoredAlarm> {
        val raw = prefs.getString(KEY, null) ?: return emptyList()
        return try {
            val array = JSONArray(raw)
            buildList(array.length()) {
                for (i in 0 until array.length()) {
                    add(StoredAlarm.fromJson(array.getJSONObject(i)))
                }
            }
        } catch (_: Exception) {
            emptyList()
        }
    }

    fun save(alarms: List<StoredAlarm>) {
        val array = JSONArray()
        alarms.forEach { array.put(it.toJson()) }
        prefs.edit().putString(KEY, array.toString()).apply()
    }

    fun replaceNonTest(alarms: List<StoredAlarm>): List<StoredAlarm> {
        val next = load().filter { it.isTest } + alarms.filter { !it.isTest }
        save(next)
        return next
    }

    fun upsert(alarms: List<StoredAlarm>): List<StoredAlarm> {
        val byId = load().associateBy { it.id }.toMutableMap()
        alarms.forEach { byId[it.id] = it }
        val next = byId.values.sortedBy { it.fireAt }
        save(next)
        return next
    }

    fun remove(id: Int): List<StoredAlarm> {
        val next = load().filterNot { it.id == id }
        save(next)
        return next
    }

    fun removeIds(ids: Collection<Int>): List<StoredAlarm> {
        val drop = ids.toSet()
        val next = load().filterNot { drop.contains(it.id) }
        save(next)
        return next
    }

    fun clear(includeTest: Boolean) {
        if (includeTest) {
            save(emptyList())
        } else {
            save(load().filter { it.isTest })
        }
    }

    fun consumeLaunchPayload(): String? {
        val payload = prefs.getString(LAUNCH_KEY, null)
        if (!payload.isNullOrEmpty()) {
            prefs.edit().remove(LAUNCH_KEY).apply()
        }
        return payload
    }

    fun setLaunchPayload(payload: String?) {
        if (payload.isNullOrBlank()) {
            prefs.edit().remove(LAUNCH_KEY).apply()
        } else {
            prefs.edit().putString(LAUNCH_KEY, payload).apply()
        }
    }

    companion object {
        const val TEST_ID = 7399
        private const val PREFS = "obecno_attendance_alarms"
        private const val KEY = "alarms"
        private const val LAUNCH_KEY = "launch_payload"
    }
}
