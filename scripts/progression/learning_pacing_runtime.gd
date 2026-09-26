extends Node

const Core=preload("res://scripts/progression/learning_pacing_core.gd")
const UiMode=preload("res://scripts/cafe_ui_mode.gd")
const CafeStyle=preload("res://scripts/cafe_theme.gd")
const STORE_PATH:="user://p5_learning_pacing.cfg"
var game:Node
var cafe_id:=""
var player_key:="local"
var seen:={}
var known:={"features":{},"milestones":{}}
var queued:={}
var pending:Array[Dictionary]=[]
var current:Dictionary={}
var store:=ConfigFile.new()
var panel:PanelContainer
var title:Label
var body:Label

func _ready()->void:
	process_priority=100
	_load_identity()
	_build_overlay()

func _process(_delta:float)->void:
	if not is_instance_valid(game): _bind_scene()
	if not is_instance_valid(game): panel.hide(); return
	var snap:=_snapshot()
	var next_cafe:=str(snap.get("cafe_id",""))
	if next_cafe.is_empty(): panel.hide(); return
	if next_cafe!=cafe_id: _bind_cafe(next_cafe,snap)
	_collect(snap)
	if current.is_empty() and not pending.is_empty(): current=pending.pop_front(); queued.erase(str(current.get("id",""))); _save()
	if current.is_empty() or not Core.can_present(_state()): panel.hide(); return
	title.text=str(current.get("title","Новая возможность")); body.text=str(current.get("text",""))+"\nF1 — понятно"; panel.show()

func _unhandled_input(event:InputEvent)->void:
	if current.is_empty() or not panel.visible: return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_F1:
		seen[str(current.get("id",""))]=true; current.clear(); panel.hide(); _save(); get_viewport().set_input_as_handled()

func current_task()->Dictionary:
	if not is_instance_valid(game): return {}
	var service:Variant=game.get("service")
	if not is_instance_valid(service): return {}
	return preload("res://scripts/cafe_journey.gd").current(service.get("progress"),service.get("stations"),int(service.get("served")),bool(service.get("open_for_business")),service)

func _bind_scene()->void:
	var scene:=get_tree().current_scene
	if scene!=null and _has_property(scene,"service") and _has_property(scene,"hud"): game=scene

func _snapshot()->Dictionary:
	var service:Variant=game.get("service") if is_instance_valid(game) else null
	if not is_instance_valid(service): return {}
	var progress:Variant=service.get("progress")
	if progress==null: return {}
	var value:Variant=progress.get("feature_progress")
	return value if value is Dictionary else {}

func _bind_cafe(next_cafe:String,snap:Dictionary)->void:
	if not cafe_id.is_empty(): _save()
	cafe_id=next_cafe; pending.clear(); queued.clear(); current.clear(); panel.hide(); store=ConfigFile.new(); store.load(STORE_PATH)
	var section:=_section(); var returning:=store.has_section(section)
	seen.clear()
	for raw_id in store.get_value(section,"seen",[]): seen[str(raw_id)]=true
	known=Core.snapshot_sets(snap)
	if returning:
		for raw_id in store.get_value(section,"pending",[]):
			var definition:=Core.explanation_by_id(str(raw_id))
			if not definition.is_empty(): _enqueue(definition)
	else:
		var catchup:=Core.collapse_catchup(snap,seen)
		for raw_id in catchup.get("skip_ids",[]): seen[str(raw_id)]=true
		var definition:Variant=catchup.get("current",{})
		if definition is Dictionary and not definition.is_empty(): _enqueue(definition)
	_save()

func _collect(snap:Dictionary)->void:
	var added:=false
	for definition in Core.collect_new(snap,known,seen,queued): _enqueue(definition); added=true
	known=Core.snapshot_sets(snap)
	if added: _save()

func _enqueue(definition:Dictionary)->void:
	var id:=str(definition.get("id",""))
	if id.is_empty() or seen.has(id) or queued.has(id) or (not current.is_empty() and str(current.get("id",""))==id): return
	queued[id]=true; pending.append(definition.duplicate(true))

func _state()->Dictionary:
	var station:Variant=game.call("local_station") if game.has_method("local_station") else null
	var active:=false; var teaching:=false
	if is_instance_valid(station):
		var training:Variant=station.get("training")
		if training!=null and training.has_method("active"): active=bool(training.call("active")); teaching=active and str(training.get("purpose"))=="lesson"
	var session:Variant=game.get("session")
	var sleeping:bool=is_instance_valid(session) and ((session.has_method("local_sleeping") and bool(session.call("local_sleeping"))) or (session.has_method("sleep_scene_active") and bool(session.call("sleep_scene_active"))))
	var service:Variant=game.get("service"); var inspection:=false
	if is_instance_valid(service) and service.get("progress")!=null:
		var visit:Variant=service.get("progress").get("visit"); inspection=visit is Dictionary and str(visit.get("phase",""))=="active"
	var hud:Variant=game.get("hud"); var notice:Variant=hud.get("notice") if is_instance_valid(hud) else null
	var urgent:bool=is_instance_valid(notice) and not str(notice.get("text")).strip_edges().is_empty()
	return {"ui_mode":"world" if UiMode.resolve(game)==UiMode.WORLD else "busy","input_blocked":bool(game.call("input_blocked")) if game.has_method("input_blocked") else false,"holding_item":not str(game.get("anchored_item")).is_empty() if _has_property(game,"anchored_item") else false,"cooking":active and not teaching,"teaching":teaching,"confirming":bool(game.call("awaiting_serving_confirmation")) if game.has_method("awaiting_serving_confirmation") else false,"inspection":inspection,"sleep":sleeping,"urgent_notice":urgent}

func _build_overlay()->void:
	var layer:=CanvasLayer.new(); layer.layer=20; add_child(layer)
	panel=PanelContainer.new(); panel.set_anchors_preset(Control.PRESET_TOP_RIGHT); panel.position=Vector2(-390,96); panel.custom_minimum_size=Vector2(360,0); panel.mouse_filter=Control.MOUSE_FILTER_IGNORE; panel.theme=CafeStyle.make(); layer.add_child(panel)
	var column:=VBoxContainer.new(); column.mouse_filter=Control.MOUSE_FILTER_IGNORE; panel.add_child(column)
	title=Label.new(); title.add_theme_font_size_override("font_size",20); title.add_theme_color_override("font_color",CafeStyle.GOLD); column.add_child(title)
	body=Label.new(); body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; body.custom_minimum_size.x=330; body.mouse_filter=Control.MOUSE_FILTER_IGNORE; column.add_child(body); panel.hide()

func _load_identity()->void:
	store.load(STORE_PATH); player_key=str(store.get_value("identity","player_key","local"))
	if player_key=="local": player_key="local-%s"%str(Time.get_unix_time_from_system()); store.set_value("identity","player_key",player_key); store.save(STORE_PATH)

func _save()->void:
	if cafe_id.is_empty(): return
	var ids:Array[String]=[]
	if not current.is_empty(): ids.append(str(current.get("id","")))
	for definition in pending: ids.append(str(definition.get("id","")))
	var seen_ids:Array[String]=[]
	for id in seen:
		if bool(seen[id]): seen_ids.append(str(id))
	seen_ids.sort(); store.set_value(_section(),"seen",seen_ids); store.set_value(_section(),"pending",ids); store.save(STORE_PATH)

func _section()->String: return "cafe:%s:player:%s"%[cafe_id,player_key]
func _has_property(target:Object,name:String)->bool:
	for property in target.get_property_list():
		if str(property.get("name",""))==name: return true
	return false
