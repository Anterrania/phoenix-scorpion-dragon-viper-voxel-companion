// JNI bridge for ViperLLM (com.anterrania.viperllm.LlmNative). Self-written.
// Strings cross as UTF-8 byte arrays (JNI's NewStringUTF is "modified UTF-8" and mangles emoji).
#include <jni.h>
#include <android/log.h>
#include <string>
#include "viper_llm_engine.h"

#define LOG_TAG "ViperLLM"

static viper_llm::Engine g_engine;

static std::string to_std(JNIEnv * env, jbyteArray a) {
    if (!a) return {};
    jsize n = env->GetArrayLength(a);
    std::string s((size_t) n, '\0');
    if (n > 0) env->GetByteArrayRegion(a, 0, n, reinterpret_cast<jbyte *>(&s[0]));
    return s;
}

static jbyteArray to_bytes(JNIEnv * env, const std::string & s) {
    jbyteArray a = env->NewByteArray((jsize) s.size());
    if (a && !s.empty()) env->SetByteArrayRegion(a, 0, (jsize) s.size(), reinterpret_cast<const jbyte *>(s.data()));
    return a;
}

static std::string json_escape(const std::string & s) {
    std::string o;
    o.reserve(s.size() + 8);
    for (unsigned char c : s) {
        switch (c) {
            case '"': o += "\\\""; break;
            case '\\': o += "\\\\"; break;
            case '\n': o += "\\n"; break;
            case '\r': o += "\\r"; break;
            case '\t': o += "\\t"; break;
            default:
                if (c < 0x20) { char b[8]; snprintf(b, sizeof b, "\\u%04x", c); o += b; }
                else o += (char) c;
        }
    }
    return o;
}

extern "C" {

JNIEXPORT jbyteArray JNICALL
Java_com_anterrania_viperllm_LlmNative_initBackends(JNIEnv * env, jobject, jbyteArray libDir) {
    std::string d = viper_llm::Engine::init_backends(to_std(env, libDir));
    __android_log_print(ANDROID_LOG_INFO, LOG_TAG, "backend: %s", d.c_str());
    return to_bytes(env, d);
}

JNIEXPORT jbyteArray JNICALL
Java_com_anterrania_viperllm_LlmNative_load(JNIEnv * env, jobject, jbyteArray path, jint nCtx, jint nThreads) {
    std::string err;
    bool ok = g_engine.load(to_std(env, path), nCtx, nThreads, err);
    return to_bytes(env, ok ? std::string() : (err.empty() ? std::string("load failed") : err));
}

JNIEXPORT void JNICALL
Java_com_anterrania_viperllm_LlmNative_unload(JNIEnv *, jobject) { g_engine.unload(); }

JNIEXPORT jboolean JNICALL
Java_com_anterrania_viperllm_LlmNative_isLoaded(JNIEnv *, jobject) { return g_engine.loaded() ? JNI_TRUE : JNI_FALSE; }

JNIEXPORT void JNICALL
Java_com_anterrania_viperllm_LlmNative_abort(JNIEnv *, jobject) { g_engine.request_abort(); }

JNIEXPORT void JNICALL
Java_com_anterrania_viperllm_LlmNative_setThreads(JNIEnv *, jobject, jint n) { g_engine.set_threads(n); }

JNIEXPORT jbyteArray JNICALL
Java_com_anterrania_viperllm_LlmNative_info(JNIEnv * env, jobject) { return to_bytes(env, g_engine.info()); }

JNIEXPORT jint JNICALL
Java_com_anterrania_viperllm_LlmNative_countTokens(JNIEnv * env, jobject, jbyteArray text) {
    return g_engine.count_tokens(to_std(env, text));
}

// sink: object with `boolean onPiece(byte[] utf8)`. Returns JSON {"text":..,"error":..,stats...} as UTF-8 bytes.
JNIEXPORT jbyteArray JNICALL
Java_com_anterrania_viperllm_LlmNative_generate(JNIEnv * env, jobject, jbyteArray prompt, jint maxTokens,
                                                jfloat temp, jfloat topP, jint seed, jobject sink) {
    viper_llm::GenParams gp;
    gp.max_tokens = maxTokens;
    gp.temperature = temp;
    gp.top_p = topP;
    gp.seed = seed < 0 ? 0xFFFFFFFFu : (uint32_t) seed;
    jclass cls = sink ? env->GetObjectClass(sink) : nullptr;
    jmethodID on_piece = cls ? env->GetMethodID(cls, "onPiece", "([B)Z") : nullptr;
    viper_llm::Stats st;
    std::string err;
    std::string text = g_engine.generate(to_std(env, prompt), gp, [&](const std::string & p) -> bool {
        if (!on_piece) return true;
        jbyteArray b = to_bytes(env, p);
        jboolean go = env->CallBooleanMethod(sink, on_piece, b);
        env->DeleteLocalRef(b);
        if (env->ExceptionCheck()) { env->ExceptionClear(); return false; }
        return go == JNI_TRUE;
    }, st, err);
    char nums[256];
    snprintf(nums, sizeof nums,
             "\"prompt_tokens\":%d,\"reused_tokens\":%d,\"gen_tokens\":%d,\"prefill_ms\":%.1f,\"gen_ms\":%.1f",
             st.prompt_tokens, st.reused_tokens, st.gen_tokens, st.prefill_ms, st.gen_ms);
    std::string json = "{\"text\":\"" + json_escape(text) + "\",\"error\":\"" + json_escape(err) +
                       "\",\"stop\":\"" + json_escape(st.stop_reason) + "\"," + nums + "}";
    return to_bytes(env, json);
}

} // extern "C"
