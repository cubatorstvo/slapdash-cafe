@tool
extends EditorPlugin
var exporter: EditorExportPlugin
class SteamExport extends EditorExportPlugin:
	func _get_name() -> String: return "SlapdashSteamAppId"
	func _export_begin(_features: PackedStringArray, _debug: bool, path: String, _flags: int) -> void:
		var file := FileAccess.open(path.get_base_dir().path_join("steam_appid.txt"), FileAccess.WRITE)
		if file != null: file.store_string("%d\n" % int(ProjectSettings.get_setting("steam/initialization/app_data/app_id", 480)))
		else: push_error("Cannot write steam_appid.txt beside the export")
func _enter_tree() -> void:
	exporter = SteamExport.new()
	add_export_plugin(exporter)
func _exit_tree() -> void:
	remove_export_plugin(exporter)
