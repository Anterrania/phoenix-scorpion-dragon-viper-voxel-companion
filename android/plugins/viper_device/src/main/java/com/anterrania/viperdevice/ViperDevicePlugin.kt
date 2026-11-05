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
    companion object {
        const val HOST = "appassets.androidplatform.net"
        const val ORIGIN = "https://appassets.androidplatform.net"
    }

    override fun getPluginName() = "ViperDevice"

    // override fun getPluginSignals(): Set<SignalInfo> = setOf(SignalInfo("live_changed"))
    // override fun getPluginSignals(): Set<SignalInfo> = setOf(SignalInfo("live_changed"), SignalInfo("social_closed"), SignalInfo("social_enter_world", String::class.java))
    // override fun getPluginSignals(): Set<SignalInfo> = setOf(SignalInfo("live_changed"), SignalInfo("social_closed"),
    //     SignalInfo("social_enter_world", String::class.java), SignalInfo("social_world_action", String::class.java))
    // v0.15.1 ONE-LOGIN: the social app's one owner sign-in / logout reach Godot (OwnerLogin checks the password).
    override fun getPluginSignals(): Set<SignalInfo> = setOf(SignalInfo("live_changed"), SignalInfo("social_closed"),
        SignalInfo("social_enter_world", String::class.java), SignalInfo("social_world_action", String::class.java),
        SignalInfo("social_owner_sign_in", String::class.java, String::class.java), SignalInfo("social_owner_logout"))

    private val ctx: Context? get() = activity?.applicationContext

    private var netCallback: ConnectivityManager.NetworkCallback? = null
    private var thermalListener: PowerManager.OnThermalStatusChangedListener? = null

    // ---------- static facts (read once per detect) ----------

    // v1 (v0.12-v0.13): device facts only.
    // @UsedByGodot
    // fun get_plugin_version(): Int = 1
    /** v2 (v0.14 BRIDGE-1): adds the Scorpion Viper bridge (open_app, is_app_installed, get_launch_uri). */
    // @UsedByGodot
    // fun get_plugin_version(): Int = 2
    /** v3 (v0.14.1 ONE-APP-1): adds the in-app Social panel (open_social_panel / close_social_panel). */
    // @UsedByGodot
    // fun get_plugin_version(): Int = 3
    /** v4 (v0.15 SOCIAL-SHELL): the social app is the menu: world actions + keyboard-aware panel. */
    @UsedByGodot
    // fun get_plugin_version(): Int = 4
    fun get_plugin_version(): Int = 5

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

    // ---------- v0.14.1 ONE-APP-1: Scorpion Viper inside this app ----------
    // The Scorpion Viper web app ships inside this APK (assets/social/, copied in by CI). It is shown in a
    // full-screen WebView over the world; nothing is downloaded. Only https://appassets.androidplatform.net/
    // is served (from the APK); every other address is blocked, so no outside page gets the bridge.

    private var panel: android.widget.FrameLayout? = null
    private var web: android.webkit.WebView? = null
    @Volatile private var ownerSession = false
    @Volatile private var worldActionsJson = "[]"
    private val actionIds = java.util.Collections.synchronizedSet(mutableSetOf<String>())

    /** Godot sends the world actions the social menu may run: JSON [{id,label}]. Only these ids are accepted back. */
    @UsedByGodot
    fun set_world_actions(json: String) {
        if (json.length > 8000) return
        worldActionsJson = json
        actionIds.clear()
        Regex("\"id\"\\s*:\\s*\"([A-Za-z0-9_]{1,40})\"").findAll(json).forEach { actionIds.add(it.groupValues[1]) }
    }

    /** Godot tells the panel whether the owner is unlocked in the world (the embedded app can ask). */
    @UsedByGodot
    fun set_owner_session(on: Boolean) { ownerSession = on }

    @UsedByGodot
    fun has_social_bundle(): Boolean {
        val c = ctx ?: return false
        return try { c.assets.open("social/index.html").close(); true } catch (_: Exception) { false }
    }

    @UsedByGodot
    // fun is_social_open(): Boolean = panel != null
    fun is_social_open(): Boolean = panel?.visibility == android.view.View.VISIBLE

    @UsedByGodot
    fun open_social_panel(path: String): Boolean {
        val a = activity ?: return false
        if (!has_social_bundle()) return false
        a.runOnUiThread {
            if (panel == null) buildPanel(a)
            val p = if (path.startsWith("/") && path.length < 200 && !path.contains("..")) path else "/"
            // web?.loadUrl(ORIGIN + p)
            val cur = web?.url ?: ""
            if (!cur.startsWith(ORIGIN) || p != "/") web?.loadUrl(ORIGIN + p)
            panel?.visibility = android.view.View.VISIBLE
        }
        return true
    }

    @UsedByGodot
    fun close_social_panel() {
        activity?.runOnUiThread { hidePanel() }
    }

    // v0.14.1: destroyed the WebView on close.
    // private fun hidePanel() {
    //     val p = panel ?: return
    //     (p.parent as? android.view.ViewGroup)?.removeView(p)
    //     web?.destroy(); web = null; panel = null
    //     emitSignal("social_closed")
    // }
    /** v0.15: the social app is the menu, so it stays loaded and is only hidden (opens instantly, keeps its page). */
    private fun hidePanel() {
        val p = panel ?: return
        if (p.visibility == android.view.View.GONE) return
        p.visibility = android.view.View.GONE
        emitSignal("social_closed")
    }

    @android.annotation.SuppressLint("SetJavaScriptEnabled")
    private fun buildPanel(a: android.app.Activity) {
        val root = a.window.decorView as android.view.ViewGroup
        val box = android.widget.FrameLayout(a)
        box.setBackgroundColor(android.graphics.Color.BLACK)
        val w = android.webkit.WebView(a)
        w.settings.javaScriptEnabled = true
        w.settings.domStorageEnabled = true
        w.settings.allowFileAccess = false
        w.settings.allowContentAccess = false
        w.settings.mediaPlaybackRequiresUserGesture = false
        val assets = a.assets
        w.webViewClient = object : android.webkit.WebViewClient() {
            override fun shouldOverrideUrlLoading(v: android.webkit.WebView, r: android.webkit.WebResourceRequest): Boolean =
                !r.url.toString().startsWith(ORIGIN)
            override fun shouldInterceptRequest(v: android.webkit.WebView, r: android.webkit.WebResourceRequest): android.webkit.WebResourceResponse? {
                val u = r.url
                if (u.scheme != "https" || u.host != HOST) return android.webkit.WebResourceResponse("text/plain", "utf-8", 403, "Blocked", emptyMap(), null)
                var rel = (u.path ?: "/").trimStart('/')
                if (rel.isEmpty() || rel.endsWith("/")) rel = "index.html"
                if (rel.contains("..")) return null
                return open(assets, rel) ?: if (!rel.substringAfterLast('/').contains('.')) open(assets, "index.html") else null
            }
        }
        w.addJavascriptInterface(HostBridge(), "ViperHost")
        box.addView(w, android.widget.FrameLayout.LayoutParams(-1, -1))
        val close = android.widget.Button(a)
        close.text = "✕ World"
        close.setOnClickListener { hidePanel() }
        val lp = android.widget.FrameLayout.LayoutParams(-2, -2)
        lp.gravity = android.view.Gravity.TOP or android.view.Gravity.END
        box.addView(close, lp)
        // v0.15 KB-1: pad the panel by the keyboard (IME) and system bar insets so the focused field stays visible.
        box.setOnApplyWindowInsetsListener { v, insets ->
            if (Build.VERSION.SDK_INT >= 30) {
                val ime = insets.getInsets(android.view.WindowInsets.Type.ime())
                val bars = insets.getInsets(android.view.WindowInsets.Type.systemBars())
                v.setPadding(bars.left, bars.top, bars.right, maxOf(ime.bottom, bars.bottom))
            } else {
                @Suppress("DEPRECATION")
                v.setPadding(insets.systemWindowInsetLeft, insets.systemWindowInsetTop, insets.systemWindowInsetRight, insets.systemWindowInsetBottom)
            }
            insets
        }
        @Suppress("DEPRECATION")
        a.window.setSoftInputMode(android.view.WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        root.addView(box, android.view.ViewGroup.LayoutParams(-1, -1))
        box.requestApplyInsets()
        panel = box; web = w
    }

    private fun open(assets: android.content.res.AssetManager, rel: String): android.webkit.WebResourceResponse? = try {
        android.webkit.WebResourceResponse(mime(rel), "utf-8", assets.open("social/$rel"))
    } catch (_: Exception) { null }

    private fun mime(rel: String): String = when (rel.substringAfterLast('.', "").lowercase()) {
        "html" -> "text/html"; "js", "mjs" -> "text/javascript"; "css" -> "text/css"; "svg" -> "image/svg+xml"
        "json" -> "application/json"; "png" -> "image/png"; "jpg", "jpeg" -> "image/jpeg"; "webp" -> "image/webp"
        "webmanifest" -> "application/manifest+json"; "woff2" -> "font/woff2"; "mp4" -> "video/mp4"; "mp3" -> "audio/mpeg"
        else -> "application/octet-stream"
    }

    /** window.ViperHost inside the embedded app. Read-only facts plus "go back to the world". */
    inner class HostBridge {
        @android.webkit.JavascriptInterface fun isEmbedded(): Boolean = true
        @android.webkit.JavascriptInterface fun ownerSession(): Boolean = ownerSession
        @android.webkit.JavascriptInterface fun closePanel() { activity?.runOnUiThread { hidePanel() } }
        /** v0.15.1 ONE-LOGIN: one sign-in in the social app also unlocks the world owner. Godot verifies it. */
        @android.webkit.JavascriptInterface fun ownerSignIn(user: String, password: String) {
            if (user.length > 64 || password.length > 256) return
            activity?.runOnUiThread { emitSignal("social_owner_sign_in", user, password) }
        }
        @android.webkit.JavascriptInterface fun ownerLogout() { activity?.runOnUiThread { emitSignal("social_owner_logout") } }
        @android.webkit.JavascriptInterface fun worldActions(): String = worldActionsJson
        /** Run a world action (teleport, worlds, avatar, ...). Unknown ids are ignored; the panel closes first. */
        @android.webkit.JavascriptInterface fun worldAction(id: String) {
            if (id !in actionIds) return
            activity?.runOnUiThread { hidePanel(); emitSignal("social_world_action", id) }
        }
        /** Enter World from the social app: Godot validates the link (SocialBridge.parse_enter) before travel. */
        @android.webkit.JavascriptInterface fun enterWorld(link: String) {
            if (link.length > 200) return
            activity?.runOnUiThread { hidePanel(); emitSignal("social_enter_world", link) }
        }
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
