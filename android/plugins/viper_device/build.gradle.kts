// ViperDevice: tiny self-written Godot 4 Android plugin (v2). No third-party runtime dependencies:
// Godot's own library is compileOnly (the app already ships it), and Kotlin stdlib is already in the
// Godot app template. Output: build/outputs/aar/viper-device-release.aar, which is copied to
// addons/viper_device/bin/ by build.sh.
plugins {
    id("com.android.library") version "8.7.3"
    id("org.jetbrains.kotlin.android") version "2.1.0"
}

android {
    namespace = "com.anterrania.viperdevice"
    compileSdk = 34
    defaultConfig { minSdk = 24 }
    buildTypes { release { isMinifyEnabled = false } }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }
    buildFeatures { buildConfig = false; resValues = false }
}

dependencies {
    compileOnly("org.godotengine:godot:4.7.2.stable")
}
