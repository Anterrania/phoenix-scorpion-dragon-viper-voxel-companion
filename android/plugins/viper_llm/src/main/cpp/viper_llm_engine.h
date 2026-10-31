// ViperLLM engine: small self-written wrapper around the llama.cpp C API (MIT, pinned in build.sh).
// No JNI and no Godot here, so the same code runs in the Android plugin and in the desktop smoke test
// (tools/llm/desktop_smoke). One model, one sequence, one generation at a time (the caller serializes).
#pragma once

#include <atomic>
#include <cstdint>
#include <functional>
#include <mutex>
#include <string>
#include <vector>

struct llama_model;
struct llama_context;
struct llama_vocab;

namespace viper_llm {

struct GenParams {
    int      max_tokens     = 160;
    float    temperature    = 0.7f;
    float    top_p          = 0.9f;
    int      top_k          = 40;
    float    min_p          = 0.05f;
    float    repeat_penalty = 1.1f;
    uint32_t seed           = 0xFFFFFFFFu;   // LLAMA_DEFAULT_SEED = random
};

struct Stats {
    int         prompt_tokens  = 0;   // tokens in this prompt
    int         reused_tokens  = 0;   // prefix tokens served from the KV cache (not recomputed)
    int         gen_tokens     = 0;
    double      prefill_ms     = 0;
    double      gen_ms         = 0;
    std::string stop_reason;          // "eos" | "max_tokens" | "aborted" | "callback" | "error"
};

// Called with complete UTF-8 text pieces as they are generated. Return false to stop early.
using PieceFn = std::function<bool(const std::string &)>;

class Engine {
public:
    // Once per process. lib_dir may be empty. On Android (VIPER_LLM_BACKEND_DL) this loads the best
    // ggml CPU variant for this phone (armv8.0 ... armv9.2) by soname, which works whether or not the
    // APK extracts native libraries. Returns a short description of the chosen backend.
    static std::string init_backends(const std::string & lib_dir);

    bool load(const std::string & path, int n_ctx, int n_threads, std::string & err);
    void unload();
    bool loaded() const { return ctx_ != nullptr; }

    std::string generate(const std::string & prompt, const GenParams & gp, const PieceFn & on_piece,
                         Stats & st, std::string & err);

    void request_abort() { abort_.store(true); }
    void set_threads(int n);
    int  n_ctx() const { return n_ctx_; }
    int  count_tokens(const std::string & text);
    std::string info() const;

private:
    bool tokenize(const std::string & text, std::vector<int32_t> & out);
    static bool abort_cb(void * self);

    llama_model       * model_ = nullptr;
    llama_context     * ctx_   = nullptr;
    const llama_vocab * vocab_ = nullptr;
    std::vector<int32_t> cached_;      // tokens currently in the KV cache (sequence 0), for prefix reuse
    std::atomic<bool>  abort_{false};
    int                n_ctx_ = 0;
    int                n_threads_ = 4;
    int                n_batch_ = 256;
    std::string        model_path_;
    mutable std::mutex mu_;
};

// Utility, exposed for tests: length of the longest complete-UTF-8 prefix of s.
size_t utf8_complete_prefix(const std::string & s);

} // namespace viper_llm
