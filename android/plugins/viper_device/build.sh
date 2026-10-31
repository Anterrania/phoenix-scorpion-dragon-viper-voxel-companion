#!/usr/bin/env bash
# Build the ViperDevice AAR and copy it into the Godot editor plugin.
# Needs JDK 17 and an Android SDK with platforms;android-34 (ANDROID_HOME or local.properties).
set -euo pipefail
cd "$(dirname "$0")"
./gradlew --no-daemon -q assembleRelease
mkdir -p ../../../addons/viper_device/bin
cp build/outputs/aar/viper-device-release.aar ../../../addons/viper_device/bin/viper-device-release.aar
ls -l ../../../addons/viper_device/bin/viper-device-release.aar
