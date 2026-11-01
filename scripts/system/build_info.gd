class_name BuildInfo
extends RefCounted
## v0.13 DEMO-1: one build for everyone.
## There is ONE app: the same APK / export goes to the owner, testers and anyone trying a demo, whatever
## the access method (sideloaded APK, release link, shared install, desktop export). There is no demo
## branch, demo flavor, demo feature tag or "demo mode" switch, and tests/v013_tests.gd fails if one appears.
## What differs between people is only:
##   - owner-only gates (Tiers / Profile.is_owner(): studio, flying grants, admin, Brain Cell unlock), and
##   - device capability (FeatureRegistry: a phone without a mic can't use voice chat).
## Settings > About and the main menu title show version + channel so a demo user can confirm they are
## on the same build as the owner.

const CHANNEL := "main"
const PACKAGE := "com.anterrania.phoenixvoxel"

static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.13.0"))

static func summary() -> String:
	return "Viper OS v%s · %s channel · %s" % [version(), CHANNEL, PACKAGE]
