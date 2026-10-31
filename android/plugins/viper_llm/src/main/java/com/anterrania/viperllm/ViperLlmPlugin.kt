package com.anterrania.viperllm

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Process
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import java.io.File
import java.io.FileOutputStream
import java.io.RandomAccessFile
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * ViperLLM: on-device language model for companion chat (llama.cpp, CPU, no API key, no server).
 * Driven by LocalLLM (scripts/ai/local_llm.gd). Everything runs on this phone; the only network use is the
 * one-time model download from the URL LocalLLM passes in (Wi-Fi only unless the user allows mobile data).
 *
 * Threads: one worker for the model (load / generate, serialized), one for downloads. Godot is never blocked.
 * Signals (all emitted from worker threads; Godot queues them to the main loop):
 *   llm_loaded(ok: Boolean, detail: String)            detail = error text, or info JSON when ok
 *   llm_token(req: Int, piece: String)                 streamed text pieces (complete UTF-8)
 *   llm_done(req: Int, result_json: String)            {"text","error","stop","prompt_tokens","reused_tokens","gen_tokens","prefill_ms","gen_ms"}
 *   dl_progress(done_mb: Float, total_mb: Float)
 *   dl_done(ok: Boolean, path: String, error: String)
 */
class ViperLlmPlugin(godot: Godot) : GodotPlugin(godot) {

    override fun getPluginName() = "ViperLLM"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("llm_loaded", java.lang.Boolean::class.java, String::class.java),
        SignalInfo("llm_token", Integer::class.java, String::class.java),
        SignalInfo("llm_done", Integer::class.java, String::class.java),
        SignalInfo("dl_progress", java.lang.Float::class.java, java.lang.Float::class.java),
        SignalInfo("dl_done", java.lang.Boolean::class.java, String::class.java, String::class.java),
    )

    private val ctx: Context? get() = activity?.applicationContext
    private val worker = Executors.newSingleThreadExecutor { r ->
        Thread({ Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND); r.run() }, "ViperLLM")
    }
    private val dlWorker = Executors.newSingleThreadExecutor { r -> Thread(r, "ViperLLM-dl") }
    private val cancelGen = AtomicBoolean(false)
    private val cancelDl = AtomicBoolean(false)
    private val downloading = AtomicBoolean(false)
    private val queued = AtomicInteger(0)
    @Volatile private var backend = ""

    @UsedByGodot fun get_plugin_version(): Int = 1

    /** True when libviper_llm.so loaded (arm64 phone). False on unsupported ABIs: LocalLLM falls back. */
    @UsedByGodot fun native_ok(): Boolean = LlmNative.libLoaded

    @UsedByGodot fun native_error(): String = LlmNative.loadError

    /** Picks the best CPU variant for this phone (once). Returns e.g. "libggml-cpu-android_armv8.2_2.so". */
    @UsedByGodot fun init_backend(): String {
        if (!LlmNative.libLoaded) return ""
        if (backend.isEmpty()) {
            val dir = ctx?.applicationInfo?.nativeLibraryDir ?: ""
            backend = String(LlmNative.initBackends(dir.toByteArray()), Charsets.UTF_8)
        }
        return backend
    }

    @UsedByGodot fun cpu_count(): Int = Runtime.getRuntime().availableProcessors()

    @UsedByGodot fun is_loaded(): Boolean = LlmNative.libLoaded && LlmNative.isLoaded()

    @UsedByGodot fun is_busy(): Boolean = queued.get() > 0

    @UsedByGodot fun info(): String = if (LlmNative.libLoaded) String(LlmNative.info(), Charsets.UTF_8) else "{}"

    @UsedByGodot fun load_model(path: String, nCtx: Int, threads: Int) {
        if (!LlmNative.libLoaded) { emitSignal("llm_loaded", false, "native library missing: ${LlmNative.loadError}"); return }
        queued.incrementAndGet()
        worker.execute {
            try {
                init_backend()
                val err = String(LlmNative.load(path.toByteArray(), nCtx, threads), Charsets.UTF_8)
                emitSignal("llm_loaded", err.isEmpty(), if (err.isEmpty()) String(LlmNative.info(), Charsets.UTF_8) else err)
            } catch (t: Throwable) {
                emitSignal("llm_loaded", false, t.toString())
            } finally { queued.decrementAndGet() }
        }
    }

    @UsedByGodot fun unload() {
        if (!LlmNative.libLoaded) return
        LlmNative.abort()
        worker.execute { LlmNative.unload() }
    }

    @UsedByGodot fun set_threads(n: Int) { if (LlmNative.libLoaded) worker.execute { LlmNative.setThreads(n) } }

    /** Streams llm_token(req, piece) and ends with exactly one llm_done(req, json). */
    @UsedByGodot fun generate(req: Int, prompt: String, maxTokens: Int, temp: Float, topP: Float, seed: Int) {
        if (!LlmNative.libLoaded) { emitSignal("llm_done", req, "{\"text\":\"\",\"error\":\"native library missing\",\"stop\":\"error\"}"); return }
        queued.incrementAndGet()
        cancelGen.set(false)
        worker.execute {
            try {
                val sink = object : LlmNative.PieceSink {
                    override fun onPiece(utf8: ByteArray): Boolean {
                        emitSignal("llm_token", req, String(utf8, Charsets.UTF_8))
                        return !cancelGen.get()
                    }
                }
                val out = String(LlmNative.generate(prompt.toByteArray(), maxTokens, temp, topP, seed, sink), Charsets.UTF_8)
                emitSignal("llm_done", req, out)
            } catch (t: Throwable) {
                emitSignal("llm_done", req, "{\"text\":\"\",\"error\":\"${t.javaClass.simpleName}\",\"stop\":\"error\"}")
            } finally { queued.decrementAndGet() }
        }
    }

    /** Stops the running generation (llm_done still arrives, with stop = "aborted" or "callback"). */
    @UsedByGodot fun cancel() {
        cancelGen.set(true)
        if (LlmNative.libLoaded) LlmNative.abort()
    }

    // ---------- model download (resumable, SHA-256 checked) ----------

    /** "wifi" (unmetered), "cell" (metered), or "none". */
    @UsedByGodot fun network_kind(): String {
        val cm = ctx?.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager ?: return "none"
        val caps = cm.getNetworkCapabilities(cm.activeNetwork) ?: return "none"
        if (!caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) return "none"
        return if (caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)) "wifi" else "cell"
    }

    @UsedByGodot fun free_space_mb(dir: String): Int {
        val f = File(dir); f.mkdirs()
        return (f.usableSpace / (1024L * 1024L)).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
    }

    @UsedByGodot fun is_downloading(): Boolean = downloading.get()

    @UsedByGodot fun cancel_download() { cancelDl.set(true) }

    /**
     * Downloads url to dest via dest.part (resumes with an HTTP Range request), checks the size and SHA-256,
     * then renames. allowMetered=false stops (keeping the .part) as soon as the network turns metered.
     * Returns false if a download is already running.
     */
    @UsedByGodot fun download(url: String, dest: String, sha256: String, size: Long, allowMetered: Boolean): Boolean {
        if (!url.startsWith("https://")) { emitSignal("dl_done", false, dest, "only https downloads are allowed"); return false }
        if (!downloading.compareAndSet(false, true)) return false
        cancelDl.set(false)
        dlWorker.execute {
            var err = ""
            try { err = doDownload(url, dest, sha256.lowercase(), size, allowMetered) }
            catch (t: Throwable) { err = t.javaClass.simpleName + ": " + (t.message ?: "") }
            finally { downloading.set(false) }
            emitSignal("dl_done", err.isEmpty(), dest, err)
        }
        return true
    }

    private fun doDownload(url: String, dest: String, sha: String, size: Long, allowMetered: Boolean): String {
        val out = File(dest)
        out.parentFile?.mkdirs()
        val part = File("$dest.part")
        var have = if (part.exists()) part.length() else 0L
        if (size > 0 && have > size) { part.delete(); have = 0L }
        if (size <= 0 || have < size) {
            if (!allowMetered && network_kind() != "wifi") return "waiting_wifi"
            val free = (out.parentFile ?: out).usableSpace
            if (size > 0 && free < (size - have) + 64L * 1024 * 1024) return "not enough free space"
            val conn = (URL(url).openConnection() as HttpURLConnection).apply {
                connectTimeout = 20000; readTimeout = 30000; instanceFollowRedirects = true
                setRequestProperty("User-Agent", "ViperOS-LocalAI/1")
                if (have > 0) setRequestProperty("Range", "bytes=$have-")
            }
            try {
                val code = conn.responseCode
                if (code == 200 && have > 0) { have = 0L }              // server ignored Range: start over
                else if (code != 200 && code != 206) return "HTTP $code"
                val total = if (size > 0) size else have + conn.contentLengthLong.coerceAtLeast(0L)
                FileOutputStream(part, have > 0).use { fo ->
                    if (have == 0L) fo.channel.truncate(0)
                    conn.inputStream.use { inp ->
                        val buf = ByteArray(256 * 1024)
                        var done = have
                        var lastEmit = 0L
                        var lastNetCheck = System.currentTimeMillis()
                        while (true) {
                            if (cancelDl.get()) return "cancelled"
                            val now = System.currentTimeMillis()
                            if (!allowMetered && now - lastNetCheck > 3000) {
                                lastNetCheck = now
                                if (network_kind() != "wifi") return "waiting_wifi"
                            }
                            val n = inp.read(buf)
                            if (n < 0) break
                            fo.write(buf, 0, n)
                            done += n
                            if (now - lastEmit > 500) {
                                lastEmit = now
                                emitSignal("dl_progress", (done / 1048576.0).toFloat(), (total / 1048576.0).toFloat())
                            }
                        }
                    }
                }
            } finally { conn.disconnect() }
        }
        if (size > 0 && part.length() != size) return "size mismatch (${part.length()} of $size bytes)"
        if (sha.isNotEmpty()) {
            val md = MessageDigest.getInstance("SHA-256")
            RandomAccessFile(part, "r").use { raf ->
                val buf = ByteArray(1024 * 1024)
                while (true) { val n = raf.read(buf); if (n < 0) break; md.update(buf, 0, n) }
            }
            val got = md.digest().joinToString("") { "%02x".format(it) }
            if (got != sha) { part.delete(); return "checksum mismatch: file deleted, will download again" }
        }
        if (out.exists()) out.delete()
        if (!part.renameTo(out)) return "could not move the downloaded file"
        emitSignal("dl_progress", (out.length() / 1048576.0).toFloat(), (out.length() / 1048576.0).toFloat())
        return ""
    }

    override fun onMainDestroy() {
        cancelGen.set(true); cancelDl.set(true)
        if (LlmNative.libLoaded) LlmNative.abort()
        worker.shutdown(); dlWorker.shutdown()
        super.onMainDestroy()
    }
}
