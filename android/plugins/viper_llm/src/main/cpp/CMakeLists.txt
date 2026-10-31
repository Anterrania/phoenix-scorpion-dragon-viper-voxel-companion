# ViperLLM native library: self-written engine + JNI glue over llama.cpp (MIT, pinned by fetch_llama.sh).
cmake_minimum_required(VERSION 3.22.1)
project(viper_llm C CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT DEFINED VIPER_LLAMA_DIR)
  set(VIPER_LLAMA_DIR ${CMAKE_CURRENT_LIST_DIR}/../../../third_party/llama.cpp)
endif()
if(NOT EXISTS ${VIPER_LLAMA_DIR}/CMakeLists.txt)
  message(FATAL_ERROR "llama.cpp not found at ${VIPER_LLAMA_DIR}: run android/plugins/viper_llm/fetch_llama.sh")
endif()

# llama.cpp options: library only, CPU backends as loadable variants (armv8.0 .. armv9.2), picked at runtime.
set(BUILD_SHARED_LIBS ON CACHE BOOL "" FORCE)
set(LLAMA_BUILD_COMMON OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_SERVER OFF CACHE BOOL "" FORCE)
set(LLAMA_BUILD_APP OFF CACHE BOOL "" FORCE)
set(LLAMA_OPENSSL OFF CACHE BOOL "" FORCE)
set(GGML_NATIVE OFF CACHE BOOL "" FORCE)
set(GGML_BACKEND_DL ON CACHE BOOL "" FORCE)
set(GGML_CPU_ALL_VARIANTS ON CACHE BOOL "" FORCE)
set(GGML_OPENMP OFF CACHE BOOL "" FORCE)     # ggml's own thread pool; no libomp to ship
set(GGML_LLAMAFILE OFF CACHE BOOL "" FORCE)
set(GGML_CPU_KLEIDIAI OFF CACHE BOOL "" FORCE) # would download extra sources at configure time
add_subdirectory(${VIPER_LLAMA_DIR} llama-build)

add_library(viper_llm SHARED viper_llm_engine.cpp viper_llm_jni.cpp)
target_compile_definitions(viper_llm PRIVATE VIPER_LLM_BACKEND_DL=1)
target_link_libraries(viper_llm PRIVATE llama ggml ggml-base android log)
# Small and fast: strip symbols, drop unused sections, 16 KB page alignment (Android 15+).
foreach(t viper_llm llama ggml ggml-base)
  if(TARGET ${t})
    target_link_options(${t} PRIVATE "-Wl,--gc-sections" "-Wl,-z,max-page-size=16384" "-s")
  endif()
endforeach()
