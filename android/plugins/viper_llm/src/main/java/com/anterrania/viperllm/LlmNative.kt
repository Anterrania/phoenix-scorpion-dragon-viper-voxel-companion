package com.anterrania.viperllm

/** JNI surface of libviper_llm.so (src/main/cpp/viper_llm_jni.cpp). Strings are UTF-8 byte arrays. */
internal object LlmNative {
    @Volatile var libLoaded = false
        private set
    var loadError = ""
        private set

    init {
        try {
            System.loadLibrary("viper_llm")
            libLoaded = true
        } catch (t: Throwable) {
            loadError = t.toString()
        }
    }

    interface PieceSink { fun onPiece(utf8: ByteArray): Boolean }

    external fun initBackends(libDir: ByteArray): ByteArray
    external fun load(path: ByteArray, nCtx: Int, nThreads: Int): ByteArray
    external fun unload()
    external fun isLoaded(): Boolean
    external fun abort()
    external fun setThreads(n: Int)
    external fun info(): ByteArray
    external fun countTokens(text: ByteArray): Int
    external fun generate(prompt: ByteArray, maxTokens: Int, temp: Float, topP: Float, seed: Int, sink: PieceSink?): ByteArray
}
