class_name BiometricHook
extends RefCounted
## Optional Android biometric unlock. STUB: Godot 4.7 has no built-in biometric API, and no
## biometric Android plugin is bundled in this repo. If a plugin singleton is added later
## (Android plugin v2 exposing e.g. "BiometricAuth" / "GodotBiometric"), wire it here.
## Design for later: the plugin should release a DEK wrapped by an Android Keystore key
## (setUserAuthenticationRequired), stored as an extra OwnerVault slot of kind "biometric".
## Until then, biometrics never unlock anything.
const SINGLETONS := ["BiometricAuth", "GodotBiometric"]

static func plugin_name() -> String:
	for s in SINGLETONS:
		if Engine.has_singleton(s): return s
	return ""

static func available() -> bool: return OS.get_name() == "Android" and plugin_name() != ""

## Calls done.call(false, reason) today. A real plugin would call done.call(true, "") after OS auth
## and hand the keystore-unwrapped DEK to OwnerVault.unlock_with_dek().
static func request(done: Callable) -> void:
	done.call(false, "biometric plugin not installed")
