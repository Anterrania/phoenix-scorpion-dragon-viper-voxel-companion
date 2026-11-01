package com.anterrania.viperdevice

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.ActivityNotFoundException
import android.content.pm.PackageManager
import android.net.Uri
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.Vibrator
import org.godotengine.godot.Dictionary
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * ViperDevice: reads the device facts Godot can't, for DeviceProfile (scripts/system/device_profile.gd).
 * Everything stays on the device; nothing is stored or sent anywhere.
 *
 * Unknown values are -1 or "" (the DeviceProfile caps() schema). No polling: Godot asks on its 30 s timer
 * and on app focus, and this plugin emits "live_changed" when Android reports a thermal or network change.
 */
class ViperDevicePlugin(godot: Godot) : GodotPlugin(godot) {

    override fun getPluginName() = "ViperDevice"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(SignalInfo("live_changed"))

    private val ctx: Context? get() = activity?.applicationContext

    private var netCallback: ConnectivityManager.NetworkCallback? = null
    private var thermalListener: PowerManager.OnThermalStatusChangedListener? = null

    // ---------- static facts (read once per detect) ----------

    // v1 (v0.12-v0.13): device facts only.
    // @UsedByGodot
    // fun get_plugin_version(): Int = 1
    /** v2 (v0.14 BRIDGE-1): adds the Scorpion Viper bridge (open_app, is_app_installed, get_launch_uri). */
    @UsedByGodot
    fun get_plugin_version(): Int = 2

    @UsedByGodot
    fun get_static(): Dictionary {
        val d = Dictionary()
        val c = ctx
        d["android_api"] = Build.VERSION.SDK_INT
        d["ram_mb"] = totalRamMb(c)
        d["vram_mb"] = -1                    // Android has no VRAM API (shared memory); DeviceProfile estimates
        d["low_ram"] = lowRam(c)
        d["has_vibrator"] = hasVibrator(c)
        d["camera"] = feature(c, PackageManager.FEATURE_CAMERA_ANY)        // no permission needed
        d["mic"] = feature(c, PackageManager.FEATURE_MICROPHONE)
        d["gyro"] = feature(c, PackageManager.FEATURE_SENSOR_GYROSCOPE)
        d["accelerometer"] = feature(c, PackageManager.FEATURE_SENSOR_ACCELEROMETER)
        d["tv"] = feature(c, PackageManager.FEATURE_LEANBACK)
        d["chromeos"] = feature(c, "org.chromium.arc") == 1 || feature(c, "org.chromium.arc.device_management") == 1
        // Foldable: hinge sensor feature (API 30+). Posture needs Jetpack WindowManager, which is a dependency: skipped.
        d["hinge"] = if (Build.VERSION.SDK_INT >= 30) feature(c, PackageManager.FEATURE_SENSOR_HINGE_ANGLE) else -1
        return d
    }

    // ---------- live facts (Godot reads every 30 s and on focus) ----------

    @UsedByGodot
    fun get_live(): Dictionary {
        val d = Dictionary()
        val c = ctx
        val bat = c?.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED)) // sticky: no receiver kept
        var pct = -1
        var charging = -1
        if (bat != null) {
            val level = bat.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
            val scale = bat.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
            if (level >= 0 && scale > 0) pct = level * 100 / scale
            val plugged = bat.getIntExtra(BatteryManager.EXTRA_PLUGGED, -1)
            if (plugged >= 0) charging = if (plugged != 0) 1 else 0
        }
        d["battery_pct"] = pct
        d["charging"] = charging
        val pm = c?.getSystemService(Context.POWER_SERVICE) as? PowerManager
        d["power_save"] = if (pm == null) -1 else if (pm.isPowerSaveMode) 1 else 0
        // PowerManager.THERMAL_STATUS_NONE..SHUTDOWN are already 0..6.
        d["thermal"] = if (pm != null && Build.VERSION.SDK_INT >= 29) pm.currentThermalStatus.coerceIn(0, 6) else -1
        d["network"] = network(c)
        return d
    }

    // ---------- change events (no polling) ----------

    override fun onMainResume() {
        super.onMainResume()
        val c = ctx ?: return
        try {
            val cm = c.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            if (cm != null && netCallback == null && Build.VERSION.SDK_INT >= 24) {
                val cb = object : ConnectivityManager.NetworkCallback() {
                    override fun onCapabilitiesChanged(n: Network, nc: NetworkCapabilities) = changed()
                    override fun onLost(n: Network) = changed()
                }
                cm.registerDefaultNetworkCallback(cb)
                netCallback = cb
            }
        } catch (_: Exception) { netCallback = null }
        if (Build.VERSION.SDK_INT >= 29 && thermalListener == null) {
            val pm = c.getSystemService(Context.POWER_SERVICE) as? PowerManager
            val l = PowerManager.OnThermalStatusChangedListener { changed() }
            pm?.addThermalStatusListener(l)
            thermalListener = l
        }
    }

    override fun onMainPause() {
        // Background: drop the listeners (DeviceProfile re-reads everything on focus).
        val c = ctx
        if (c != null) {
            netCallback?.let {
                try { (c.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager)?.unregisterNetworkCallback(it) } catch (_: Exception) {}
            }
            if (Build.VERSION.SDK_INT >= 29) thermalListener?.let {
                (c.getSystemService(Context.POWER_SERVICE) as? PowerManager)?.removeThermalStatusListener(it)
            }
        }
        netCallback = null
        thermalListener = null
        super.onMainPause()
    }

    private fun changed() = emitSignal("live_changed")

    // ---------- v0.14 BRIDGE-1: Scorpion Viper social app bridge ----------
    // Only the apps on this list can be opened (and the manifest <queries> lists the same package).

    private val bridgeApps = setOf("os.viper.scorpion")

    /** The phoenixvoxel://enter?... link this activity was opened with, or "". GDScript validates it. */
    @UsedByGodot
    fun get_launch_uri(): String {
        val i = activity?.intent ?: return ""
        if (i.action != Intent.ACTION_VIEW) return ""
        val u = i.data ?: return ""
        return if (u.scheme == "phoenixvoxel") u.toString() else ""
    }

    /** Forget the link once handled, so a resume does not re-enter the same world. */
    @UsedByGodot
    fun consume_launch_uri() {
        activity?.intent?.let { it.data = null; it.action = Intent.ACTION_MAIN }
    }

    @UsedByGodot
    fun is_app_installed(pkg: String): Boolean {
        val c = ctx ?: return false
        if (pkg !in bridgeApps) return false
        return try { c.packageManager.getLaunchIntentForPackage(pkg) != null } catch (_: Exception) { false }
    }

    /** Open an allowed app: with a deep link when uri is set, else its launcher screen. false = not installed. */
    @UsedByGodot
    fun open_app(pkg: String, uri: String): Boolean {
        val a = activity ?: return false
        if (pkg !in bridgeApps) return false
        val intent = if (uri.isNotEmpty()) Intent(Intent.ACTION_VIEW, Uri.parse(uri)).setPackage(pkg)
            else a.packageManager.getLaunchIntentForPackage(pkg) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            a.startActivity(intent); true
        } catch (_: ActivityNotFoundException) {
            // the social app has no handler for that link yet: open it normally instead
            val launch = a.packageManager.getLaunchIntentForPackage(pkg) ?: return false
            try { a.startActivity(launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)); true } catch (_: Exception) { false }
        } catch (_: Exception) { false }
    }

    // ---------- helpers ----------

    private fun feature(c: Context?, name: String): Int =
        if (c == null) -1 else if (c.packageManager.hasSystemFeature(name)) 1 else 0

    private fun totalRamMb(c: Context?): Int {
        val am = c?.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return -1
        val mi = ActivityManager.MemoryInfo()
        am.getMemoryInfo(mi)
        return if (mi.totalMem > 0) (mi.totalMem / 1048576L).toInt() else -1
    }

    private fun lowRam(c: Context?): Int {
        val am = c?.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager ?: return -1
        return if (am.isLowRamDevice) 1 else 0
    }

    @Suppress("DEPRECATION")
    private fun hasVibrator(c: Context?): Int {
        val v = c?.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator ?: return -1
        return if (v.hasVibrator()) 1 else 0
    }

    private fun network(c: Context?): String {
        val cm = c?.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return ""
        return try {
            val nc = cm.getNetworkCapabilities(cm.activeNetwork) ?: return "none"
            when {
                nc.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
                    nc.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "wifi"
                nc.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cell"
                // Metered other transports (e.g. VPN over cell) count as cell for data saver.
                !nc.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED) -> "cell"
                else -> "wifi"
            }
        } catch (_: SecurityException) { "" }
    }
}
