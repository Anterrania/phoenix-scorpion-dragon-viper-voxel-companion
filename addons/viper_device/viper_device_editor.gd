@tool
extends EditorPlugin
## Adds the ViperDevice AAR to Android (Gradle) exports. Source: android/plugins/viper_device (build.sh).

var _export: ViperDeviceExport

func _enter_tree() -> void:
	_export = ViperDeviceExport.new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class ViperDeviceExport extends EditorExportPlugin:
	const AAR := "viper_device/bin/viper-device-release.aar"   # relative to res://addons/

	func _get_name() -> String:
		return "ViperDevice"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if not FileAccess.file_exists("res://addons/" + AAR):
			push_warning("ViperDevice AAR missing: run android/plugins/viper_device/build.sh. Exporting without it (live keys stay unknown).")
			return PackedStringArray()
		return PackedStringArray([AAR])
