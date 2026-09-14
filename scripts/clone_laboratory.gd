extends Node3D
## One host-owned physical apparatus. A cycle is transient; only a finished clone is saved.
const Props = preload("res://scripts/props.gd")
const BALANCE_SECONDS := 6.0
const GROW_PREP_SECONDS := 75.0
const GROW_FINISH_SECONDS := 75.0
const BUTTON := Vector3(0,1.12,7.85)
var game: Node3D
var state := fresh_state()
var apparatus: Node3D
var liquid: MeshInstance3D
var needle: MeshInstance3D
var button: MeshInstance3D
var caption: Label3D
var little_clone: Node3D
var growth_legs: Node3D
var pulse_seen := 0
var revision_seen := -1
var burst_sound: AudioStreamPlayer3D
var burst_parts: Array = []
var progress_bar: MeshInstance3D
var result_label: Label3D
var selector_label: Label3D
var upgrade_nodes := {}

static func fresh_state() -> Dictionary:
	return {"phase":"idle","cost":0,"owner":0,"selected":0,"clone_id":0,"station":0,"level":0.0,"needle":0.0,"age":0.0,"revision":0,"notice":"","pulse":0,"balanced":0.0,"exposure":0.0,"integral":0.0,"armed":false,"fill_quality":0.0,"needle_quality":0.0,"tempo":0.7,"low":0.7,"high":1.0,"valve":false,"damper":false}

static func zone_quality(value: float, vertical := false) -> float:
	if vertical:
		if value<0.15: return 0.0
		if value<=0.45: return 1.0
		return clampf(1.0-(value-0.45)/0.4,0,1)
	return clampf(1.0-maxf(0,absf(value-0.5)-0.10)/0.35,0,1)

static func zone_color(quality: float) -> Color:
	return Color("d66d61").lerp(Color("e2c66c"),quality*2) if quality<0.5 else Color("e2c66c").lerp(Color("83ca91"),(quality-0.5)*2)

func tempo_range() -> Vector2:
	var upgrades: Array=game.service.progress.lab_upgrades
	return Vector2(1.4,2.0) if "lab_power_2" in upgrades else Vector2(1.0,1.5) if "lab_power" in upgrades else Vector2(0.7,1.0)

func reserves_station(id: int) -> bool:
	return state.phase not in ["idle","done","failed"] and int(state.station)==id


func setup(owner_game: Node3D) -> void:
	game = owner_game
	burst_sound=AudioStreamPlayer3D.new(); add_child(burst_sound)
	burst_sound.position=Vector3(-0.94,1.4,7.96); burst_sound.max_distance=9; burst_sound.volume_db=-12
	var pcm:=PackedByteArray(); pcm.resize(6615*2)
	for n in range(6615):
		var t:=float(n)/22050.0
		var noise:=sin(n*127.1+cos(n*311.7))*0.4
		pcm.encode_s16(n*2,int(clampf((sin(t*TAU*(130-t*240))+noise)*exp(-t*15)*0.55,-1,1)*32767))
	var sound:=AudioStreamWAV.new(); sound.format=AudioStreamWAV.FORMAT_16_BITS; sound.mix_rate=22050; sound.data=pcm
	burst_sound.stream=sound
	apparatus = Node3D.new()
	add_child(apparatus)
	# Front faces look toward the laboratory doorway (-Z).
	Props.box(apparatus,Vector3(1.35,0.7,0.18),Vector3(0,1.55,8.12),Color("344c48"))
	Props.box(apparatus,Vector3(1.16,0.09,0.025),Vector3(0,1.64,8.015),Color("d9c89d"))
	for i in range(50):
		var t := (i+0.5)/50.0
		Props.box(apparatus,Vector3(1.16/50+0.001,0.11,0.03),Vector3(-0.58+1.16*t,1.64,7.995),zone_color(zone_quality(t)))
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
	for i in range(40):
		var t := (i+0.5)/40.0
		Props.box(apparatus,Vector3(0.07,0.76/40+0.001,0.035),Vector3(-0.63,1.02+0.76*t,7.94),zone_color(zone_quality(t,true)))
	Props.box(apparatus,Vector3(0.58,0.12,0.07),Vector3(-0.94,1.88,7.91),Color("304b46"))
	progress_bar=Props.box(apparatus,Vector3(0.52,0.075,0.015),Vector3(-0.94,1.88,7.865),Color("e4c379"))
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
	# The machine exposes progress physically: legs first, then the whole clone.
	growth_legs = Node3D.new()
	apparatus.add_child(growth_legs)
	growth_legs.position = Vector3(0.98,1.03,7.98)
	for x in [-0.065,0.065]:
		var leg := Node3D.new()
		growth_legs.add_child(leg)
		leg.position.x = x
		Props.box(leg,Vector3(0.095,0.36,0.12),Vector3(0,0.18,0),Color("344e48"))
	growth_legs.hide()
	for i in range(10):
		var drop:=Props.ball(apparatus,0.05,Vector3(-0.94,1.4,7.96),Color("c4bc61"))
		drop.hide(); burst_parts.append(drop)
	for side in [-1,1]:
		Props.box(apparatus,Vector3(0.19,0.08,0.21),Vector3(side*0.42,1.12,7.76),Color("b49c75"))
		var arrow:=Props.text(apparatus,"‹" if side<0 else "›",Vector3(side*0.42,1.28,7.76),24,Color("f3dfb8")); arrow.billboard=BaseMaterial3D.BILLBOARD_ENABLED; arrow.pixel_size=0.004
	selector_label=Props.text(apparatus,"",Vector3(0,1.0,7.70),18,Color("e8d4a6")); selector_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; selector_label.pixel_size=0.003
	result_label=Props.text(apparatus,"",Vector3(0,2.44,8.04),20,Color("b5dbb6")); result_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; result_label.pixel_size=0.004
	Props.box(apparatus,Vector3(0.23,0.1,0.24),Vector3(-1.48,1.09,7.88),Color("bc7869"))
	for item in ["lab_power","lab_power_2","lab_valve","lab_damper"]:
		var root:=Node3D.new(); add_child(root); root.position=upgrade_local_position(item); upgrade_nodes[item]=root
		Props.box(root,Vector3(0.38,0.34,0.28),Vector3.ZERO,Color("ba9067") if "power" in item else Color("779e9b"))
		for i in range(3): Props.ball(root,0.035,Vector3(-0.1+i*0.1,0.05,-0.15),Color("b9df91"))
		Props.line(root,Vector3(0,-0.1,0),Vector3(-root.position.x*0.35,-0.22,-0.25),0.025,Color("514e43"))
		var label2:=Props.text(root,{"lab_power":"УСИЛИТЕЛЬ","lab_power_2":"ТУРБО","lab_valve":"КЛАПАН","lab_damper":"ДЕМПФЕР"}[item],Vector3(0,0.27,0),16,Color("ecd49f")); label2.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label2.pixel_size=0.003


func reset() -> void:
	var revision: int=state.revision
	var pulse: int=state.pulse
	var selected: int=state.get("selected",0)
	state=fresh_state(); state.revision=revision+1; state.pulse=pulse; state.selected=selected

func upgrade_local_position(item: String) -> Vector3:
	return {"lab_power":Vector3(-1.40,1.25,8.5),"lab_power_2":Vector3(1.42,1.25,8.5),"lab_valve":Vector3(-0.65,1.25,8.6),"lab_damper":Vector3(0.55,1.25,8.6)}[item]

func upgrade_position(item: String) -> Vector3:
	return to_global(upgrade_local_position(item))

func operator_position() -> Vector3:
	return to_global(Vector3(0,0.02,7.0))

func local_holding() -> bool:
	return not game.input_blocked() and int(state.owner)==game.session.local_id() and state.phase=="fill" and (Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

func selected_clone() -> Dictionary:
	for option in game.service.clone_options():
		if int(option.id)==int(state.selected): return option
	return {}

func selection_action(peer: int, data: Dictionary) -> String:
	if not inside(peer_position(peer)) or int(data.get("revision",-1))!=int(state.revision): return ""
	if data.action=="lab_restart":
		if int(state.owner)!=peer or state.phase in ["idle","done","failed"]: return ""
		reset(); game.service.assign_clones(); return ""
	if state.phase!="idle": return "Сначала заверши текущий цикл."
	var ids: Array=[0]
	for option in game.service.clone_options(): ids.append(int(option.id))
	state.selected=ids[posmod(maxi(0,ids.find(int(state.selected)))+(1 if int(data.get("direction",1))>0 else -1),ids.size())]
	state.revision=int(state.revision)+1
	return ""

func peer_position(peer: int) -> Vector3:
	if peer == 1: return game.player.global_position
	if not game.session.members.has(peer): return Vector3.INF
	var raw: Array = game.session.player_poses.get(peer,{}).get("position",[])
	return Vector3(raw[0],raw[1],raw[2]) if raw.size()==3 else Vector3.INF

func inside(position: Vector3) -> bool:
	var local := to_local(position)
	return absf(local.x)<2.9 and local.z>6.5 and local.distance_to(BUTTON)<3.6

func target(camera: Camera3D, peer: int) -> Dictionary:
	if not inside(camera.global_position): return {}
	if state.phase=="idle":
		for side in [-1,1]:
			if game.shop.near_ray(camera,to_global(Vector3(side*0.42,1.12,7.76)),0.15): return {"action":"lab_select","direction":side,"revision":state.revision,"hint":"(E) Выбрать клона / создание нового"}
	elif int(state.owner)==peer and state.phase not in ["done","failed"] and game.shop.near_ray(camera,to_global(Vector3(-1.48,1.09,7.88)),0.18):
		return {"action":"lab_restart","revision":state.revision,"hint":"(E) Прервать · ингредиенты потрачены"}
	var interaction_point := to_global(Vector3(0,1.5,8)) if state.phase!="idle" else to_global(BUTTON)
	if not game.shop.near_ray(camera,interaction_point,1.3 if state.phase!="idle" else 0.25): return {}
	var text := ""
	if game.service.progress.lab_stage<3: text="Сначала собери лабораторию"
	elif game.service.progress.stars<1: text="Клонирование · нужна первая звезда"
	elif int(state.owner) not in [0,peer]: text="Аппарат занят напарником"
	else:
		match state.phase:
			"idle": text="(E) Начать · 60" if selected_clone().is_empty() else "(E) Перекалибровать · попытка 20"
			"fill": text="Удерживай E / ЛКМ — уровень растёт; отпусти — падает"
			"grow_blank": text="Аппарат выращивает заготовку · можно идти в кафе"
			"stage2_ready": text="(E / ЛКМ) Заготовка готова · к стабилизатору"
			"fill_ready": text="(E / ЛКМ) К стабилизатору"
			"tune": text="(E / ЛКМ) Зафиксировать стрелку"
			"grow_finish": text="Клон дозревает · можно идти в кафе"
			"ready": text="(E / ЛКМ) Сохранить результат" if int(state.clone_id)>0 else "(E / ЛКМ) Выпустить клона · уже оплачено"
			"done": text="Готово!"
			"failed": text="Жидкость испорчена · нужна новая попытка"
	return {"action":"lab_press","revision":state.revision,"observed_age":state.age,"hint":text}

func press(peer: int, revision: int, observed_age := -1.0) -> String:
	if not inside(peer_position(peer)): return "Подойди к аппарату."
	if game.service.training_for(peer)!=null or game.shop.carried(peer)>=0 or game.service.progress.garland_builder==peer: return "Сначала освободи руки."
	if game.service.progress.lab_stage<3 or game.service.progress.stars<1: return "Нужны готовая лаборатория и первая звезда."
	if int(state.owner) not in [0,peer]: return "Аппарат занят напарником."
	if revision!=int(state.revision): return ""
	match state.phase:
		"idle":
			var selected:=selected_clone()
			if not selected.is_empty() and int(selected.station)>0:
				var station=game.service.by_id(selected.station)
				if station.state!="idle" or station.training.active() or station.customer_id>=0: return "Дождись свободной станции или закрой кафе."
			if game.service.progress.cash<(20 if not selected.is_empty() else 60): return "Не хватает денег на ингредиенты."
			state.cost=20 if not selected.is_empty() else 60
			game.service.progress.cash-=int(state.cost); game.service.progress.revision+=1
			game.save_cafe()
			state.owner=peer; state.phase="fill"; state.clone_id=selected.get("id",0); state.station=selected.get("station",0)
			var limits:=tempo_range(); state.low=limits.x; state.high=limits.y
			state.valve="lab_valve" in game.service.progress.lab_upgrades; state.damper="lab_damper" in game.service.progress.lab_upgrades
			state.level=0.0; state.age=0.0; state.balanced=0.0; state.exposure=0.0; state.integral=0.0; state.armed=false; state.notice=""
			game.service.trace("cloning_started",{"peer":peer,"clone":state.clone_id})
		"fill": return ""
		"fill_ready", "stage2_ready": state.phase="tune"; state.age=0.0; state.needle=0.0
		"tune":
			# Use the displayed server age within a bounded network-delay window for guests.
			var age: float=state.age
			if peer!=1 and is_finite(observed_age) and observed_age>=age-0.35 and observed_age<=age: age=observed_age
			state.needle=pingpong(age*(0.42 if state.damper else 1.2),1.0)
			state.needle_quality=zone_quality(state.needle)
			state.tempo=snappedf(lerpf(state.low,state.high,state.fill_quality*0.6+state.needle_quality*0.4),0.01)
			state.phase="grow_finish" if int(state.clone_id)==0 else "ready"
			state.age=0.0
		"grow_blank", "grow_finish": return ""
		"ready":
			if int(state.clone_id)>0:
				var worker: Dictionary=game.service.clone_data(int(state.clone_id))
				if worker.is_empty(): reset(); return "Клон не найден."
				if float(state.tempo)>float(worker.tempo):
					worker.tempo=state.tempo; state.notice="Перекалибровка сохранена"
				else: state.notice="Прежний темп лучше — оставлен"
				game.service.progress.revision+=1
				game.service.trace("clone_recalibrated",{"clone":state.clone_id,"attempt":state.tempo,"retained":worker.tempo})
			else:
				var error: String=game.service.create_clone(state.tempo,true)
				if not error.is_empty(): return error
			state.phase="done"; state.age=0.0; state.pulse=int(state.pulse)+1
			state.clone_id=0; state.station=0
			game.service.assign_clones(); game.save_cafe()
		"done", "failed": return ""
	state.revision=int(state.revision)+1
	return ""

func advance(delta: float) -> void:
	if state.phase=="idle": return
	var owner := int(state.owner)
	var autonomous: bool = state.phase in ["grow_blank","stage2_ready","grow_finish","ready"]
	if state.phase not in ["done","failed"]:
		if owner>1 and not game.session.members.has(owner):
			game.service.trace("cloning_cancelled",{"reason":"owner_disconnected"})
			reset(); game.service.assign_clones(); return
		if not autonomous and (not inside(peer_position(owner)) or game.service.training_for(owner)!=null):
			game.service.trace("cloning_cancelled",{"reason":"left_apparatus"})
			reset(); game.service.assign_clones(); return
	state.age=float(state.age)+delta
	match state.phase:
		"fill":
			var held := local_holding() if owner==1 else false
			if owner!=1:
				var pose: Dictionary=game.session.player_poses.get(owner,{})
				held=pose.get("lab_hold",false) and Time.get_ticks_msec()-int(pose.get("received_at",0))<350
			advance_balance(delta,held)
		"grow_blank":
			if float(state.age)>=GROW_PREP_SECONDS:
				state.phase="stage2_ready"; state.age=0.0; state.revision=int(state.revision)+1; state.pulse=int(state.pulse)+1
				state.notice="Заготовка готова и спокойно ждёт тебя"
		"tune": state.needle=pingpong(float(state.age)*(0.42 if state.damper else 1.2),1.0)
		"grow_finish":
			if float(state.age)>=GROW_FINISH_SECONDS:
				state.phase="ready"; state.age=0.0; state.revision=int(state.revision)+1; state.pulse=int(state.pulse)+1
				state.notice="Клон дозрел и ждёт выпуска"
		"done", "failed":
			if float(state.age)>2.5: reset()

func advance_balance(delta: float, held: bool) -> void:
	state.level=clampf(float(state.level)+delta*(0.8 if held else -0.55)*(0.45 if state.valve else 1.0),0,1)
	if not state.armed:
		if float(state.level)<0.15: return
		state.armed=true
	if state.armed and float(state.level)<0.15:
		state.phase="failed"; state.age=0.0; state.level=0.0; state.revision=int(state.revision)+1
		state.notice="Жидкость испорчена · −%d"%int(state.cost)
		state.clone_id=0; state.station=0
		game.service.assign_clones()
		game.service.trace("cloning_failed",{"reason":"below_green","cost":state.cost})
		return
	var quality:=zone_quality(float(state.level),true)
	var speed:=1.0 if quality>=0.999 else 0.55 if quality>=0.4 else 0.25
	var sample:=minf(delta,(BALANCE_SECONDS-float(state.balanced))/speed)
	state.integral=float(state.integral)+quality*sample
	state.exposure=float(state.exposure)+sample
	state.balanced=float(state.balanced)+sample*speed
	if float(state.balanced)>=BALANCE_SECONDS-0.00001:
		state.fill_quality=clampf(float(state.integral)/maxf(0.001,float(state.exposure)),0,1)
		if int(state.clone_id)==0:
			state.phase="grow_blank"; state.age=0.0; state.notice="Аппарат выращивает заготовку · можешь заняться кафе"
		else: state.phase="fill_ready"
		state.revision=int(state.revision)+1

func countdown(total: float) -> String:
	var seconds := maxi(0,ceili(total-float(state.age)))
	return "%d:%02d" % [seconds/60,seconds%60]

func _process(_delta: float) -> void:
	if game == null: return
	apparatus.visible = game.service.progress.lab_stage>=3
	if not apparatus.visible: return
	for i in range(burst_parts.size()):
		var t:=float(state.age)
		burst_parts[i].visible=state.phase=="failed" and t<0.85
		burst_parts[i].position=Vector3(-0.94,1.4,7.96)+Vector3(sin(i*2.4)*t*0.9,1.6*t-2.5*t*t,cos(i*2.4)*t*0.6)
	var level := maxf(0.006,float(state.level))
	liquid.scale.y = level
	liquid.position.y = 1.02+0.38*level
	needle.position.x = -0.58+1.16*float(state.needle)
	button.position.y = BUTTON.y - (0.035 if state.phase=="done" else 0.0)
	growth_legs.visible = state.phase in ["grow_blank","stage2_ready","grow_finish"]
	if growth_legs.visible:
		var leg_progress := clampf(float(state.age)/GROW_PREP_SECONDS,0.0,1.0) if state.phase=="grow_blank" else 1.0
		growth_legs.scale=Vector3(1,0.25+0.75*leg_progress,1)
		growth_legs.rotation.z=sin(float(state.age)*6.0)*0.08
	little_clone.visible = state.phase in ["grow_finish","ready","done"]
	little_clone.rotation.z = sin(float(state.age)*8)*0.09 if state.phase=="done" else 0.0
	var maturity := clampf(float(state.age)/GROW_FINISH_SECONDS,0.0,1.0) if state.phase=="grow_finish" else 1.0
	little_clone.scale = Vector3.ONE * ((0.45+0.40*maturity) if state.phase=="grow_finish" else (0.85+minf(0.15,float(state.age)*0.2) if state.phase=="done" else 0.85))
	progress_bar.scale.x=maxf(0.001,float(state.balanced)/BALANCE_SECONDS)
	progress_bar.position.x=-1.2+0.26*progress_bar.scale.x
	for item in upgrade_nodes: upgrade_nodes[item].visible=item in game.service.progress.lab_upgrades
	var selected:=selected_clone()
	selector_label.text="НОВЫЙ КЛОН" if selected.is_empty() else str(selected.name)+" · %d%%"%roundi(float(selected.tempo)*100)
	var limits:=tempo_range()
	var title := ""
	match state.phase:
		"idle": title="ТЯП-КЛОН · %d–%d%% · свободно %d"%[roundi(limits.x*100),roundi(limits.y*100),game.service.progress.free_clones]
		"fill": title="1 · УДЕРЖИВАЙ УРОВЕНЬ В ЗЕЛЁНОЙ ЗОНЕ"
		"grow_blank": title="РАСТУТ НОГИ · %s · ИДИ РАБОТАЙ"%countdown(GROW_PREP_SECONDS)
		"stage2_ready": title="НОГИ ГОТОВЫ · НУЖЕН СТАБИЛИЗАТОР"
		"fill_ready": title="КОЛБА ГОТОВА · К СТАБИЛИЗАТОРУ"
		"tune": title="2 · ПОЙМАЙ СТРЕЛКУ"
		"grow_finish": title="КЛОН ДОЗРЕВАЕТ · %s · ИДИ РАБОТАЙ"%countdown(GROW_FINISH_SECONDS)
		"ready": title="3 · КЛОН ГОТОВ"
		"done": title="ЕЩЁ ОДИН Я!"
		"failed": title="ПШШШ! НЕ ПОЛУЧИЛОСЬ"
	var fill: float=float(state.integral)/maxf(0.001,float(state.exposure))
	result_label.text=""
	if state.phase!="idle": result_label.text="Колба: %d%%"%roundi(fill*100)
	if state.phase=="ready" and int(state.clone_id)>0:
		var worker: Dictionary=game.service.clone_data(int(state.clone_id))
		result_label.text+=" · прежний темп %d%%"%roundi(float(worker.get("tempo",1.0))*100)
	if state.phase in ["grow_finish","ready","done"]: result_label.text+=" · Стрелка: %d%%\nТемп клона: %d%%"%[roundi(float(state.needle_quality)*100),roundi(float(state.tempo)*100)]
	caption.text = title + ("\n"+str(state.notice) if not str(state.notice).is_empty() else "")
	if int(state.revision)!=revision_seen:
		if state.phase=="failed": burst_sound.play()
		if revision_seen>=0 and state.phase not in ["done","idle"] and game.camera.global_position.distance_to(BUTTON)<5: game.feedback.play_ui("click")
		revision_seen=int(state.revision)
	if int(state.pulse)!=pulse_seen:
		pulse_seen = int(state.pulse)
		if game.camera.global_position.distance_to(BUTTON)<5: game.feedback.play_ui("ready")
