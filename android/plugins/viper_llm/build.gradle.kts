// ViperLLM: self-written Godot 4 Android plugin (v2) + JNI over llama.cpp (MIT), arm64 only.
// Godot's library is compileOnly (the app ships it). Output: build/outputs/aar/viper-llm-release.aar,
// copied to addons/viper_llm/bin/ by build.sh. llama.cpp source comes from fetch_llama.sh (pinned commit).
plugins {
    id("com.android.library") version "8.7.3"
    id("org.jetbrains.kotlin.android") version "2.1.0"
}

android {
    namespace = "com.anterrania.viperllm"
    compileSdk = 34
    ndkVersion = "27.2.12479018"
    defaultConfig {
        minSdk = 24
        ndk { abiFilters += listOf("arm64-v8a") }
        externalNativeBuild {
            cmake {
                arguments += listOf("-DCMAKE_BUILD_TYPE=Release", "-DANDROID_STL=c++_shared")
                cppFlags += listOf("-O2", "-fvisibility=hidden")
            }
        }
    }
    externalNativeBuild { cmake { path("src/main/cpp/CMakeLists.txt"); version = "3.22.1" } }
    buildTypes { release { isMinifyEnabled = false } }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { buildConfig = false; resValues = false }
    // Keep the APK small: ship 3 of llama.cpp's 7 arm64 CPU variants (~0.78 MB each, uncompressed in the APK).
    // armv8.0_1 = any arm64 (baseline), armv8.2_2 = dotprod+fp16 (A75/A76/A78/A55), armv8.6_1 = +i8mm (X1+/A710+, armv9 phones).
    // Dropped: armv8.2_1 (no dotprod; 8.0_1 covers it), armv9.0_1 / armv9.2_x (SVE2/SME: no Q4_0 gain at 128-bit SVE on phones).
    packaging {
        jniLibs {
            excludes += listOf("**/libggml-cpu-android_armv8.2_1.so", "**/libggml-cpu-android_armv9.0_1.so", "**/libggml-cpu-android_armv9.2_1.so", "**/libggml-cpu-android_armv9.2_2.so")
        }
    }
}

dependencies {
    compileOnly("org.godotengine:godot:4.7.2.stable")
}
