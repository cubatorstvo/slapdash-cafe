extends RefCounted
## Compatibility facade. Runtime definitions live in scripts/progression/feature_catalog.gd
## and scripts/progression/ui_entry_catalog.gd.
const FeatureCatalog = preload("res://scripts/progression/feature_catalog.gd")
const UiEntryCatalog = preload("res://scripts/progression/ui_entry_catalog.gd")
const DEFINITIONS = FeatureCatalog.DEFINITIONS
const ACTION_FEATURES = UiEntryCatalog.ACTION_FEATURES

static func definition(id: String) -> Dictionary: return FeatureCatalog.definition(id)

static func feature_for_page(page: String) -> String:
	var entry := UiEntryCatalog.entry(page)
	var required: Array = entry.get("required_features", [])
	return str(required[0]) if not required.is_empty() else ""

static func feature_for_category(category: String) -> String:
	var entry := UiEntryCatalog.entry("shop.category." + category)
	var required: Array = entry.get("required_features", [])
	return str(required[0]) if not required.is_empty() else "shop_basic"

static func feature_for_action(action: String) -> String:
	var values := UiEntryCatalog.action_features(action)
	return str(values[0]) if not values.is_empty() else ""
