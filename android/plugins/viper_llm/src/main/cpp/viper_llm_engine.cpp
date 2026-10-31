// See viper_llm_engine.h. Self-written; only calls the public llama.h / ggml-backend.h API.
#include "viper_llm_engine.h"

#include "ggml-backend.h"
#include "llama.h"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstring>

namespace viper_llm {

using clk = std::chrono::steady_clock;
static double ms_since(clk::time_point t0) {
    return std::chrono::duration<double, std::milli>(clk::now() - t0).count();
}

size_t utf8_complete_prefix(const std::string & s) {
    // Walk back over at most 3 trailing bytes to see if the last code point is complete.
    size_t n = s.size();
    if (n == 0) return 0;
    size_t i = n;
    int back = 0;
    while (i > 0 && back < 4) {
        unsigned char c = (unsigned char) s[i - 1];
        if ((c & 0xC0) != 0x80) {          // lead byte or ASCII
            int need = (c < 0x80) ? 1 : ((c >> 5) == 0x6) ? 2 : ((c >> 4) == 0xE) ? 3 : ((c >> 3) == 0x1E) ? 4 : 1;
            return (n - (i - 1) >= (size_t) need) ? n : i - 1;
        }
        --i; ++back;
    }
    return n;   // malformed run of continuation bytes: pass through
}

static void quiet_log(enum ggml_log_level level, const char * text, void *) {
    if (level >= GGML_LOG_LEVEL_WARN) fputs(text, stderr);
}

std::string Engine::init_backends(const std::string & lib_dir) {
    static std::once_flag once;
    static std::string desc;
    std::call_once(once, [&] {
        llama_log_set(quiet_log, nullptr);
#ifdef VIPER_LLM_BACKEND_DL
        // Best first. ggml_backend_load() returns null when the variant's score is 0 (CPU lacks the features)
        // or the .so isn't packaged. build.gradle.kts ships only 8.6_1, 8.2_2 and 8.0_1 to keep the APK small.
        // static const char * variants[] = {
        //     "libggml-cpu-android_armv9.2_2.so", "libggml-cpu-android_armv9.2_1.so", "libggml-cpu-android_armv9.0_1.so",
        //     "libggml-cpu-android_armv8.6_1.so", "libggml-cpu-android_armv8.2_2.so", "libggml-cpu-android_armv8.2_1.so",
        //     "libggml-cpu-android_armv8.0_1.so",
        // };
        static const char * variants[] = {
            "libggml-cpu-android_armv8.6_1.so", "libggml-cpu-android_armv8.2_2.so", "libggml-cpu-android_armv8.0_1.so",
        };
        for (const char * v : variants) {
            if (ggml_backend_load(v)) { desc = v; break; }
        }
        if (desc.empty() && !lib_dir.empty()) {   // fallback: directory scan (extracted native libs)
            ggml_backend_load_all_from_path(lib_dir.c_str());
            if (ggml_backend_reg_count() > 0) desc = "scan:" + lib_dir;
        }
        if (desc.empty()) desc = "none";
#else
        (void) lib_dir;
        desc = "static";
#endif
        llama_backend_init();
    });
    return desc;
}

bool Engine::load(const std::string & path, int n_ctx, int n_threads, std::string & err) {
    std::lock_guard<std::mutex> lk(mu_);
    if (ctx_) { llama_free(ctx_); ctx_ = nullptr; }
    if (model_) { llama_model_free(model_); model_ = nullptr; }
    cached_.clear();
    if (ggml_backend_dev_count() == 0) { err = "no compute backend (CPU variant failed to load)"; return false; }

    llama_model_params mp = llama_model_default_params();
    mp.n_gpu_layers = 0;        // CPU only on phones (phase 1); mmap keeps RAM use low
    mp.load_mode = LLAMA_LOAD_MODE_MMAP;  // b12017 API (was use_mmap)
    model_ = llama_model_load_from_file(path.c_str(), mp);
    if (!model_) { err = "could not load model file"; return false; }
    vocab_ = llama_model_get_vocab(model_);

    n_ctx_ = std::max(512, std::min(n_ctx, (int) llama_model_n_ctx_train(model_)));
    n_threads_ = std::max(1, std::min(n_threads, 8));
    llama_context_params cp = llama_context_default_params();
    cp.n_ctx = n_ctx_;
    cp.n_batch = n_batch_;
    cp.n_ubatch = n_batch_;
    cp.n_seq_max = 1;
    cp.n_threads = n_threads_;
    cp.n_threads_batch = n_threads_;
    cp.no_perf = true;
    ctx_ = llama_init_from_model(model_, cp);
    if (!ctx_) { llama_model_free(model_); model_ = nullptr; err = "could not create context (out of memory?)"; return false; }
    llama_set_abort_callback(ctx_, &Engine::abort_cb, this);
    model_path_ = path;
    return true;
}

void Engine::unload() {
    std::lock_guard<std::mutex> lk(mu_);
    if (ctx_) { llama_free(ctx_); ctx_ = nullptr; }
    if (model_) { llama_model_free(model_); model_ = nullptr; }
    vocab_ = nullptr;
    cached_.clear();
}

bool Engine::abort_cb(void * self) {
    return static_cast<Engine *>(self)->abort_.load();
}

void Engine::set_threads(int n) {
    std::lock_guard<std::mutex> lk(mu_);
    n_threads_ = std::max(1, std::min(n, 8));
    if (ctx_) llama_set_n_threads(ctx_, n_threads_, n_threads_);
}

bool Engine::tokenize(const std::string & text, std::vector<int32_t> & out) {
    // add_special = true (BOS if the model wants one), parse_special = true (ChatML <|im_start|> etc.)
    int n = -llama_tokenize(vocab_, text.c_str(), (int32_t) text.size(), nullptr, 0, true, true);
    if (n <= 0) { out.clear(); return n == 0; }
    out.resize(n);
    int got = llama_tokenize(vocab_, text.c_str(), (int32_t) text.size(), out.data(), n, true, true);
    if (got < 0) { out.clear(); return false; }
    out.resize(got);
    return true;
}

int Engine::count_tokens(const std::string & text) {
    std::lock_guard<std::mutex> lk(mu_);
    if (!vocab_) return -1;
    std::vector<int32_t> t;
    return tokenize(text, t) ? (int) t.size() : -1;
}

std::string Engine::generate(const std::string & prompt, const GenParams & gp, const PieceFn & on_piece,
                             Stats & st, std::string & err) {
    std::lock_guard<std::mutex> lk(mu_);
    abort_.store(false);
    st = Stats{};
    if (!ctx_) { err = "model not loaded"; st.stop_reason = "error"; return ""; }

    std::vector<int32_t> toks;
    if (!tokenize(prompt, toks) || toks.empty()) { err = "tokenize failed"; st.stop_reason = "error"; return ""; }
    st.prompt_tokens = (int) toks.size();
    const int max_new = std::max(1, gp.max_tokens);
    if ((int) toks.size() + max_new + 4 > n_ctx_) {
        err = "context_full";   // caller trims history and retries
        st.stop_reason = "error";
        return "";
    }

    // Prefix reuse: keep the KV cache for the shared start (system prompt + earlier turns).
    size_t keep = 0;
    while (keep < cached_.size() && keep < toks.size() && cached_[keep] == toks[keep]) ++keep;
    if (keep == toks.size()) --keep;   // always decode at least the last prompt token (we need its logits)
    llama_memory_t mem = llama_get_memory(ctx_);
    if (!llama_memory_seq_rm(mem, 0, (llama_pos) keep, -1)) {
        llama_memory_clear(mem, true);
        keep = 0;
    }
    cached_.resize(keep);
    st.reused_tokens = (int) keep;

    auto t0 = clk::now();
    llama_batch batch = llama_batch_init(n_batch_, 0, 1);
    for (size_t i = keep; i < toks.size(); i += n_batch_) {
        const int n = (int) std::min<size_t>(n_batch_, toks.size() - i);
        batch.n_tokens = n;
        for (int j = 0; j < n; ++j) {
            batch.token[j] = toks[i + j];
            batch.pos[j] = (llama_pos) (i + j);
            batch.n_seq_id[j] = 1;
            batch.seq_id[j][0] = 0;
            batch.logits[j] = (i + j == toks.size() - 1);
        }
        int rc = llama_decode(ctx_, batch);
        if (rc != 0) {
            llama_batch_free(batch);
            llama_memory_clear(mem, true);
            cached_.clear();
            st.stop_reason = abort_.load() ? "aborted" : "error";
            if (!abort_.load()) err = "prompt decode failed (" + std::to_string(rc) + ")";
            return "";
        }
        cached_.insert(cached_.end(), toks.begin() + i, toks.begin() + i + n);
    }
    st.prefill_ms = ms_since(t0);

    llama_sampler * smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(smpl, llama_sampler_init_penalties(llama_vocab_n_tokens(vocab_), 64, gp.repeat_penalty, 0.0f, 0.0f));
    if (gp.temperature <= 0.0f) {
        llama_sampler_chain_add(smpl, llama_sampler_init_greedy());
    } else {
        llama_sampler_chain_add(smpl, llama_sampler_init_top_k(gp.top_k));
        llama_sampler_chain_add(smpl, llama_sampler_init_top_p(gp.top_p, 1));
        llama_sampler_chain_add(smpl, llama_sampler_init_min_p(gp.min_p, 1));
        llama_sampler_chain_add(smpl, llama_sampler_init_temp(gp.temperature));
        llama_sampler_chain_add(smpl, llama_sampler_init_dist(gp.seed));
    }

    std::string out, pending;
    auto t1 = clk::now();
    int logits_idx = -1;   // last token of the batch
    st.stop_reason = "max_tokens";
    for (int k = 0; k < max_new; ++k) {
        if (abort_.load()) { st.stop_reason = "aborted"; break; }
        llama_token tok = llama_sampler_sample(smpl, ctx_, logits_idx);
        if (llama_vocab_is_eog(vocab_, tok)) { st.stop_reason = "eos"; break; }
        char buf[256];
        int n = llama_token_to_piece(vocab_, tok, buf, sizeof(buf), 0, false);
        if (n > 0) {
            pending.append(buf, n);
            size_t ok = utf8_complete_prefix(pending);
            if (ok > 0) {
                std::string piece = pending.substr(0, ok);
                pending.erase(0, ok);
                out += piece;
                if (on_piece && !on_piece(piece)) { st.stop_reason = "callback"; st.gen_tokens++; break; }
            }
        }
        st.gen_tokens++;
        if ((int) cached_.size() + 1 >= n_ctx_) { st.stop_reason = "max_tokens"; break; }
        batch.n_tokens = 1;
        batch.token[0] = tok;
        batch.pos[0] = (llama_pos) cached_.size();
        batch.n_seq_id[0] = 1;
        batch.seq_id[0][0] = 0;
        batch.logits[0] = true;
        int rc = llama_decode(ctx_, batch);
        if (rc != 0) { st.stop_reason = abort_.load() ? "aborted" : "error"; if (!abort_.load()) err = "decode failed"; break; }
        cached_.push_back(tok);
    }
    if (!pending.empty()) out += pending;
    st.gen_ms = ms_since(t1);
    llama_sampler_free(smpl);
    llama_batch_free(batch);
    return out;
}

std::string Engine::info() const {
    std::lock_guard<std::mutex> lk(mu_);
    char desc[128] = {0};
    if (model_) llama_model_desc(model_, desc, sizeof(desc));
    std::string s = "{\"loaded\":";
    s += ctx_ ? "true" : "false";
    s += ",\"model\":\"" + std::string(desc) + "\",\"n_ctx\":" + std::to_string(n_ctx_) +
         ",\"threads\":" + std::to_string(n_threads_) +
         ",\"params\":" + std::to_string(model_ ? (long long) llama_model_n_params(model_) : 0LL) +
         ",\"size\":" + std::to_string(model_ ? (long long) llama_model_size(model_) : 0LL) + "}";
    return s;
}

} // namespace viper_llm
