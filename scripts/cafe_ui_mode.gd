extends RefCounted
const GAMEPLAY := "gameplay"
const OFFICE := "office"

static func apply(game: Node,mode: String) -> void:
	if game==null: return
	game.set_meta("ui_mode",mode)
	var hud: Variant=game.get("hud")
	if hud==null or not is_instance_valid(hud): return
	var top: CanvasItem=hud.get_node_or_null("Root/Top")
	if top!=null: top.visible=mode!=OFFICE
	if mode==OFFICE:
		for path in ["Root/EventFeed","Root/VisitStatus"]:
			var node: CanvasItem=hud.get_node_or_null(path)
			if node!=null: node.hide()
