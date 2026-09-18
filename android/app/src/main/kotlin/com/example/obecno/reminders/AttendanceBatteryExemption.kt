package com.example.obecno.reminders

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

/**
 * Asks Android (and OEM skins) to keep attendance alarms alive in the
 * background. Stock Android gets the system "unrestricted" dialog; Xiaomi,
 * Huawei, Oppo, Vivo, Samsung, and similar skins also get their autostart
 * screen once. The OS still requires a user tap — this cannot be granted
 * silently.
 */
internal object AttendanceBatteryExemption {
    private const val PREFS = "obecno_attendance_alarms"
    private const val BATTERY_ASKED_KEY = "battery_unrestricted_asked"
    private const val OEM_ASKED_KEY = "oem_autostart_asked"

    fun ensureUnrestricted(context: Context) {
        if (isIgnoringBatteryOptimizations(context)) {
            requestOemAutostartOnce(context)
            return
        }
        requestIgnoreBatteryOptimizations(context)
    }

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        val pm = context.getSystemService(PowerManager::class.java)
        return pm?.isIgnoringBatteryOptimizations(context.packageName) == true
    }

    fun requestIgnoreBatteryOptimizations(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return
        if (isIgnoringBatteryOptimizations(context)) return
        val prefs = prefs(context)
        if (prefs.getBoolean(BATTERY_ASKED_KEY, false)) return
        val intent =
            Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                data = Uri.parse("package:${context.packageName}")
            }
        if (startSafely(context, intent)) {
            prefs.edit().putBoolean(BATTERY_ASKED_KEY, true).apply()
            return
        }
        AttendanceAlarmScheduler.openBatterySettings(context)
        prefs.edit().putBoolean(BATTERY_ASKED_KEY, true).apply()
    }

    private fun requestOemAutostartOnce(context: Context) {
        val prefs = prefs(context)
        if (prefs.getBoolean(OEM_ASKED_KEY, false)) return
        if (startFirstResolvable(context, oemIntents(context))) {
            prefs.edit().putBoolean(OEM_ASKED_KEY, true).apply()
        }
    }

    private fun oemIntents(context: Context): List<Intent> {
        val pkg = context.packageName
        return listOf(
            component(
                "com.miui.securitycenter",
                "com.miui.permcenter.autostart.AutoStartManagementActivity",
            ),
            Intent("miui.intent.action.OP_AUTO_START"),
            component(
                "com.miui.powerkeeper",
                "com.miui.powerkeeper.ui.HiddenAppsConfigActivity",
            ).putExtra("package_name", pkg).putExtra("package_label", "obecno"),
            component(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupAppControlActivity",
            ),
            component(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.optimize.process.ProtectActivity",
            ),
            component(
                "com.huawei.systemmanager",
                "com.huawei.systemmanager.appcontrol.activity.StartupAppControlActivity",
            ),
            component(
                "com.hihonor.systemmanager",
                "com.huawei.systemmanager.startupmgr.ui.StartupAppControlActivity",
            ),
            component(
                "com.coloros.safecenter",
                "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            ),
            component(
                "com.coloros.safecenter",
                "com.coloros.safecenter.startupapp.StartupAppListActivity",
            ),
            component(
                "com.oppo.safe",
                "com.oppo.safe.permission.startup.StartupAppListActivity",
            ),
            component(
                "com.vivo.permissionmanager",
                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            ),
            component(
                "com.iqoo.secure",
                "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            ),
            component(
                "com.iqoo.secure",
                "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
            ),
            component(
                "com.samsung.android.lool",
                "com.samsung.android.sm.ui.battery.BatteryActivity",
            ),
            component(
                "com.samsung.android.sm",
                "com.samsung.android.sm.ui.battery.BatteryActivity",
            ),
            component(
                "com.oneplus.security",
                "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
            ),
            component(
                "com.oplus.battery",
                "com.oplus.powermanager.fuelgaue.PowerControlActivity",
            ),
            component(
                "com.asus.mobilemanager",
                "com.asus.mobilemanager.autostart.AutoStartActivity",
            ),
            component(
                "com.letv.android.letvsafe",
                "com.letv.android.letvsafe.AutobootManageActivity",
            ),
            component(
                "com.meizu.safe",
                "com.meizu.safe.permission.SmartBGActivity",
            ),
            component(
                "com.evenwell.powersaving.g3",
                "com.evenwell.powersaving.g3.exception.PowerSaverExceptionActivity",
            ),
        )
    }

    private fun component(packageName: String, className: String): Intent =
        Intent().setComponent(ComponentName(packageName, className))

    private fun startFirstResolvable(context: Context, intents: List<Intent>): Boolean {
        val pm = context.packageManager
        for (intent in intents) {
            intent.putExtra("package_name", context.packageName)
            intent.putExtra("packageName", context.packageName)
            if (pm.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY) == null) {
                continue
            }
            if (startSafely(context, intent)) return true
        }
        return false
    }

    private fun startSafely(context: Context, intent: Intent): Boolean {
        if (context !is Activity) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            context.startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}
