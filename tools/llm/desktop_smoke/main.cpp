// viper_llm_smoke <model.gguf> <prompt_file> [max_tokens] [threads]
// Runs the prompt twice (second run shows KV prefix reuse) and prints stats as JSON lines.
#include "viper_llm_engine.h"
#include <cstdio>
#include <fstream>
#include <sstream>

int main(int argc, char ** argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s model.gguf prompt.txt [max_tokens] [threads]\n", argv[0]); return 2; }
    std::ifstream f(argv[2]); std::stringstream ss; ss << f.rdbuf();
    viper_llm::Engine::init_backends("");
    viper_llm::Engine e; std::string err;
    int threads = argc > 4 ? atoi(argv[4]) : 4;
    if (!e.load(argv[1], 2048, threads, err)) { fprintf(stderr, "load failed: %s\n", err.c_str()); return 1; }
    printf("info %s\n", e.info().c_str());
    if (viper_llm::utf8_complete_prefix("a\xC3") != 1 || viper_llm::utf8_complete_prefix("a\xC3\xA9") != 3) { fprintf(stderr, "utf8 check failed\n"); return 1; }
    viper_llm::GenParams gp; gp.max_tokens = argc > 3 ? atoi(argv[3]) : 120; gp.temperature = 0.2f; gp.seed = 42;
    for (int run = 0; run < 2; ++run) {
        viper_llm::Stats st;
        std::string out = e.generate(ss.str(), gp, [](const std::string & p) { fputs(p.c_str(), stdout); fflush(stdout); return true; }, st, err);
        printf("\n---\nstats run=%d prompt=%d reused=%d gen=%d prefill_ms=%.0f gen_ms=%.0f tok_s=%.1f pp_s=%.1f stop=%s err=%s\n",
               run, st.prompt_tokens, st.reused_tokens, st.gen_tokens, st.prefill_ms, st.gen_ms,
               st.gen_ms > 0 ? st.gen_tokens * 1000.0 / st.gen_ms : 0.0,
               st.prefill_ms > 0 ? (st.prompt_tokens - st.reused_tokens) * 1000.0 / st.prefill_ms : 0.0,
               st.stop_reason.c_str(), err.c_str());
        if (out.empty()) return 1;
    }
    return 0;
}
