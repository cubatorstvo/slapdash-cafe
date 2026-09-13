extends Node3D
## One host-owned physical apparatus. A cycle is transient; only a finished clone is saved.
const Props = preload("res://scripts/props.gd")
const LOW := 0.55
const HIGH := 0.72
const BUTTON := Vector3(0,1.12,7.85)
var game: Node3D
var state := {"phase":"idle", "owner":0, "level":0.0, "needle":0.0, "age":0.0, "revision":0, "notice":"", "pulse":0}
var apparatus: Node3D
var liquid: MeshInstance3D
var needle: MeshInstance3D
var button: MeshInstance3D
var caption: Label3D
var little_clone: Node3D
var pulse_seen := 0
var revision_seen := -1

func setup(owner_game: Node3D) -> void:
	game = owner_game
	apparatus = Node3D.new()
	add_child(apparatus)
	# Front faces look toward the laboratory doorway (-Z).
	Props.box(apparatus,Vector3(1.35,0.7,0.18),Vector3(0,1.55,8.12),Color("344c48"))
	Props.box(apparatus,Vector3(1.16,0.09,0.025),Vector3(0,1.64,8.015),Color("d9c89d"))
	Props.box(apparatus,Vector3(1.16*(HIGH-LOW),0.11,0.03),Vector3(-0.58+1.16*(LOW+HIGH)/2,1.64,7.995),Color("8dce96"))
	needle = Props.box(apparatus,Vector3(0.025,0.21,0.035),Vector3(-0.58,1.64,7.97),Color("e98563"))
	var label := Props.text(apparatus,"СТАБИЛИЗАТОР",Vector3(0,1.85,7.99),18,Color("efdeb4"))
	label.rotation.y = PI
	label.pixel_size = 0.0035
	Props.cylinder(apparatus,0.31,0.08,Vector3(-0.94,0.98,7.96),Color("314f4c"))
	var glass := Props.cylinder(apparatus,0.26,0.8,Vector3(-0.94,1.4,7.96),Color("afdcd4"))
	glass.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.material_override.albedo_color.a = 0.18
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	liquid = Props.cylinder(apparatus,0.23,0.76,Vector3(-0.94,1.4,7.96),Color("87bd95"))
	# A physical green band shows the acceptable fill level, even with an empty flask.
	Props.box(apparatus,Vector3(0.05,0.76*(HIGH-LOW),0.035),Vector3(-0.63,1.02+0.76*(LOW+HIGH)/2,7.94),Color("9fdfa4"))
	for i in range(11): Props.box(apparatus,Vector3(0.09 if i%5==0 else 0.05,0.012,0.025),Vector3(-0.63,1.02+i*0.076,7.915),Color("eed5a4"))
	Props.line(apparatus,Vector3(-0.94,1.9,7.96),Vector3(-0.94,2.02,7.96),0.035,Color("bf976e"))
	Props.line(apparatus,Vector3(-0.94,2.02,7.96),Vector3(-0.36,2.02,8.18),0.035,Color("bf976e"))
	button = Props.cylinder(apparatus,0.17,0.12,BUTTON,Color("d18a69"))
	caption = Props.text(apparatus,"",Vector3(0,2.18,8.04),22,Color("f0d69f"))
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.pixel_size = 0.004
	# The dubious result grows on the output pedestal and nods before joining the crew pool.
	Props.cylinder(apparatus,0.32,0.1,Vector3(0.98,0.97,7.98),Color("49605b"))
	little_clone = Node3D.new()
	apparatus.add_child(little_clone)
	little_clone.position = Vector3(0.98,1.02,7.98)
	Props.box(little_clone,Vector3(0.29,0.37,0.17),Vector3(0,0.36,0),Color("79b8a2"))
	Props.ball(little_clone,0.19,Vector3(0,0.71,0),Color("e6b984"))
	Props.cylinder(little_clone,0.20,0.16,Vector3(0,0.91,0),Color("f2e4b1"))
	for x in [-0.065,0.065]:
		Props.ball(little_clone,0.024,Vector3(x,0.73,-0.174),Color("293e38"))
		Props.box(little_clone,Vector3(0.095,0.18,0.12),Vector3(x,0.1,0),Color("344e48"))
	for x in [-0.21,0.21]: Props.box(little_clone,Vector3(0.09,0.32,0.09),Vector3(x,0.36,0),Color("79b8a2"))
	little_clone.hide()

func reset() -> void:
	state = {"phase":"idle", "owner":0, "level":0.0, "needle":0.0, "age":0.0, "revision":int(state.revision)+1, "notice":"", "pulse":int(state.pulse)}

func peer_position(peer: int) -> Vector3:
	if peer == 1: return game.player.global_position
	if not game.session.members.has(peer): return Vector3.INF
	var raw: Array = game.session.player_poses.get(peer,{}).get("position",[])
	return Vector3(raw[0],raw[1],raw[2]) if raw.size()==3 else Vector3.INF

func inside(position: Vector3) -> bool:
	return absf(position.x)<2.9 and position.z>6.5 and position.distance_to(BUTTON)<3.6

func target(camera: Camera3D, peer: int) -> Dictionary:
	if not inside(camera.global_position) or not game.shop.near_ray(camera,BUTTON,0.32): return {}
	var text := ""
	if game.service.progress.lab_stage<3: text = "Сначала собери лабораторию"
	elif game.service.progress.stars<1: text = "Клонирование · нужна первая звезда"
	elif int(state.owner) not in [0,peer]: text = "Аппарат занят напарником"
	else:
		match state.phase:
			"idle": text = "(E) Наполнить колбу · клон 60"
			"fill": text = "(E) Закрыть кран в зелёной зоне"
			"tune": text = "(E) Зафиксировать стрелку в зелёной зоне"
			"ready": text = "(E) Выпустить клона · 60"
			"done": text = "Клон готов!"
	return {"action":"lab_press", "revision":state.revision, "hint":text}

func press(peer: int, revision: int) -> String:
	if not inside(peer_position(peer)): return "Подойди к аппарату."
	if game.service.training_for(peer)!=null or game.shop.carried(peer)>=0 or game.service.progress.garland_builder==peer: return "Сначала освободи руки."
	if game.service.progress.lab_stage<3 or game.service.progress.stars<1: return "Нужны готовая лаборатория и первая звезда."
	if int(state.owner) not in [0,peer]: return "Аппарат занят напарником."
	if revision != int(state.revision): return ""
	match state.phase:
		"idle":
			if game.service.progress.cash<60: return "Ингредиенты клона стоят 60."
			state.owner = peer
			state.phase = "fill"
			state.level = 0.0
			state.notice = ""
			game.service.trace("cloning_started",{"peer":peer})
		"fill":
			if float(state.level)>=LOW and float(state.level)<=HIGH:
				state.phase = "tune"; state.age = 0.0; state.needle = 0.0; state.notice = ""
			else:
				state.level = 0.0; state.notice = "Недолив! Кран открыт снова."
				game.service.trace("cloning_retry",{"step":"fill"})
		"tune":
			if float(state.needle)>=LOW and float(state.needle)<=HIGH:
				state.phase = "ready"; state.notice = ""
			else:
				state.notice = "Чуть мимо. Поймай зелёную зону."
				game.service.trace("cloning_retry",{"step":"tune"})
		"ready":
			var error: String = game.service.create_clone()
			if not error.is_empty(): return error
			state.phase = "done"; state.age = 0.0; state.pulse = int(state.pulse)+1
			game.save_cafe()
		"done": return ""
	state.revision = int(state.revision)+1
	return ""

func advance(delta: float) -> void:
	if state.phase == "idle": return
	if state.phase != "done" and (not inside(peer_position(int(state.owner))) or game.service.training_for(int(state.owner))!=null):
		game.service.trace("cloning_cancelled",{"reason":"left_apparatus"})
		reset()
		return
	state.age = float(state.age)+delta
	match state.phase:
		"fill":
			state.level = float(state.level)+delta*0.16
			if float(state.level)>1.0:
				state.level = 0.0; state.notice = "Перелив! Лишнее ушло в слив. Ещё раз."
				state.revision = int(state.revision)+1
				game.service.trace("cloning_retry",{"step":"overflow"})
		"tune": state.needle = pingpong(float(state.age)*0.25,1.0)
		"done":
			if float(state.age)>2.5: reset()

func _process(_delta: float) -> void:
	if game == null: return
	apparatus.visible = game.service.progress.lab_stage>=3
	if not apparatus.visible: return
	var level := maxf(0.006,float(state.level))
	liquid.scale.y = level
	liquid.position.y = 1.02+0.38*level
	needle.position.x = -0.58+1.16*float(state.needle)
	button.position.y = BUTTON.y - (0.035 if state.phase=="done" else 0.0)
	little_clone.visible = state.phase in ["ready","done"]
	little_clone.rotation.z = sin(float(state.age)*8)*0.09 if state.phase=="done" else 0.0
	little_clone.scale = Vector3.ONE * (0.85 + minf(0.15,float(state.age)*0.2) if state.phase=="done" else 0.85)
	var titles := {"idle":"ТЯП-КЛОН · 60", "fill":"1 · КОЛБА: ДО ЗЕЛЁНОЙ МЕТКИ", "tune":"2 · СТРЕЛКУ В ЗЕЛЁНУЮ ЗОНУ", "ready":"3 · МОЖНО ВЫПУСКАТЬ!", "done":"ЕЩЁ ОДИН Я!"}
	if state.phase=="idle": titles.idle += " · свободно %d" % game.service.progress.free_clones
	caption.text = str(titles[state.phase]) + ("\n"+str(state.notice) if not str(state.notice).is_empty() else "")
	if int(state.revision)!=revision_seen:
		if revision_seen>=0 and state.phase not in ["done","idle"] and game.camera.global_position.distance_to(BUTTON)<5: game.feedback.play_ui("click")
		revision_seen=int(state.revision)
	if int(state.pulse)!=pulse_seen:
		pulse_seen = int(state.pulse)
		if game.camera.global_position.distance_to(BUTTON)<5: game.feedback.play_ui("ready")
