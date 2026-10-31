@tool
extends EditorPlugin
## Adds the ViperLLM AAR to Android (Gradle) exports. Source: android/plugins/viper_llm (build.sh).

var _export: ViperLlmExport

func _enter_tree() -> void:
	_export = ViperLlmExport.new()
	add_export_plugin(_export)

func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class ViperLlmExport extends EditorExportPlugin:
	const AAR := "viper_llm/bin/viper-llm-release.aar"   # relative to res://addons/

	func _get_name() -> String:
		return "ViperLLM"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		if not FileAccess.file_exists("res://addons/" + AAR):
			push_warning("ViperLLM AAR missing: run android/plugins/viper_llm/build.sh. Exporting without on-device AI (persona replies only).")
			return PackedStringArray()
		return PackedStringArray([AAR])
