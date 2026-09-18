extends Node3D
## Formula research coordinates the microscope, nursery and recalibration chair.
const Props=preload("res://scripts/props.gd")
const Policy=preload("res://scripts/laboratory_progression.gd")
const Layout=preload("res://scripts/laboratory_layout.gd")
const Lounge=preload("res://scripts/lounge_layout.gd")
const BALANCE_SECONDS := 6.0
const BUTTON := Vector3(0,1.12,7.85)
const SAMPLE := Vector3(0.98,1.10,7.98)
var game: Node3D
var state := fresh_state()
var nursery: Node3D
var calibrator: Node3D
var ui: CanvasLayer
var apparatus: Node3D
var liquid: MeshInstance3D
var needle: MeshInstance3D
var button: MeshInstance3D
var caption: Label3D
var sample_mesh: MeshInstance3D
var burst_sound: AudioStreamPlayer3D
var burst_parts: Array=[]
var progress_bar: MeshInstance3D
var result_label: Label3D
var upgrade_nodes: Dictionary={}
var revision_seen := -1

static func fresh_state() -> Dictionary:
	return {"phase":"idle","cost":0,"owner":0,"level":0.0,"needle":0.0,"age":0.0,"revision":0,"notice":"","balanced":0.0,"exposure":0.0,"integral":0.0,"armed":false,"fill_quality":0.0,"needle_quality":0.0,"tempo":0.7,"low":0.7,"high":1.0,"valve":false,"damper":false}

static func zone_quality(value: float, vertical := false) -> float:
	if vertical:
		if value<0.15: return 0.0
		if value<=0.45: return 1.0
		return clampf(1.0-(value-0.45)/0.4,0,1)
	return clampf(1.0-maxf(0,absf(value-0.5)-0.10)/0.35,0,1)

static func zone_color(quality: float) -> Color:
	return Color("d66d61").lerp(Color("e2c66c"),quality*2) if quality<0.5 else Color("e2c66c").lerp(Color("83ca91"),(quality-0.5)*2)


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
	# A liquid sample replaces the old miniature clone output.
	sample_mesh=Props.cylinder(apparatus,0.09,0.20,Vector3(0.98,1.10,7.98),Color("9ad6ad"))
	Props.cylinder(apparatus,0.22,0.04,Vector3(0.98,0.98,7.98),Color("d1c398"))
	var sample_label:=Props.text(apparatus,"ОБРАЗЕЦ",Vector3(0.98,1.45,7.98),17,Color("dfd5a5"))
	sample_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; sample_label.pixel_size=0.0035
	for i in range(10):
		var drop:=Props.ball(apparatus,0.05,Vector3(-0.94,1.4,7.96),Color("c4bc61"))
		drop.hide(); burst_parts.append(drop)
	Props.box(apparatus,Vector3(0.23,0.1,0.24),Vector3(-1.48,1.09,7.88),Color("bc7869"))
	result_label=Props.text(apparatus,"",Vector3(0,2.44,8.04),20,Color("b5dbb6"))
	result_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED; result_label.pixel_size=0.004
	for item in Policy.ITEMS:
		if Policy.ITEMS[item].branch!="formula": continue
		var root:=Node3D.new(); add_child(root); root.position=to_local(Layout.fixture(item)); upgrade_nodes[item]=root
		if item=="lab_power_3":
			Props.solid_box(root,Vector3(1.0,1.45,0.8),Vector3(0,0.73,0),Color("81a798"))
			for i in range(3): Props.cylinder(root,0.1,0.65,Vector3(-0.25+i*0.25,1.40,0),Color("b4d5ac"))
		else:
			Props.box(root,Vector3(0.38,0.34,0.28),Vector3.ZERO,Color("ba9067") if "power" in item else Color("779e9b"))
			for i in range(3): Props.ball(root,0.035,Vector3(-0.1+i*0.1,0.05,-0.15),Color("b9df91"))
		var label2:=Props.text(root,str(Policy.ITEMS[item].name).get_slice(" · ",0),Vector3(0,1.95 if item=="lab_power_3" else 0.32,0),16,Color("ecd49f"))
		label2.billboard=BaseMaterial3D.BILLBOARD_ENABLED; label2.pixel_size=0.003
	nursery=preload("res://scripts/clone_nursery.gd").new()
	game.add_child(nursery); nursery.setup(game,self)
	calibrator=preload("res://scripts/clone_recalibrator.gd").new()
	game.add_child(calibrator); calibrator.setup(game,self)
	ui=preload("res://scripts/laboratory_instrument_ui.gd").new()
	game.add_child(ui); ui.setup(game)


func reset() -> void:
	var revision:=int(state.revision)+1
	state=fresh_state(); state.revision=revision

func recover() -> void:
	reset()
	nursery.clear_transient()
	nursery.ensure_pots()
	ui.close()
	var p=game.service.progress
	if not p.lab_sample.is_empty(): p.lab_sample.carrier=0
	if int(p.lab_calibration.get("owner",0))>0 or p.lab_calibration.get("phase","idle")=="manual":
		calibrator.reset()
	elif p.lab_calibration.get("phase","idle")=="auto":
		p.lab_calibration.age=0.0

func snapshot() -> Dictionary:
	return {"research":state.duplicate(true),"nursery":nursery.snapshot()}

func restore(value: Dictionary) -> void:
	state=value.get("research",fresh_state()).duplicate(true)
	nursery.restore(value.get("nursery",{}))

func tempo_range() -> Vector2: return Policy.formula_range(game.service.progress)
func operator_position() -> Vector3: return to_global(Vector3(0,0.02,7.0))
func upgrade_position(item: String) -> Vector3:
	var point:=Layout.fixture(item)
	return point+Vector3.UP*0.8 if point.y<0.5 else point

func peer_position(peer: int) -> Vector3:
	if peer==1: return game.player.global_position
	if not game.session.members.has(peer): return Vector3.INF
	var raw: Array=game.session.player_poses.get(peer,{}).get("position",[])
	return Vector3(raw[0],raw[1],raw[2]) if raw.size()==3 else Vector3.INF

func inside(position: Vector3) -> bool:
	var local:=to_local(position)
	return absf(local.x)<2.9 and local.z>6.5 and local.distance_to(BUTTON)<3.6

func researching(peer: int) -> bool:
	return int(state.owner)==peer and state.phase in ["fill","fill_ready","tune"]

func hands_busy(peer: int) -> bool:
	return nursery.holding(peer) or nursery.pulling(peer) or game.shop.carried(peer)>=0 or game.service.progress.garland_builder==peer

func blocks_sleep() -> bool:
	return state.phase in ["fill","fill_ready","tune"] or calibrator.manual_owner()>0 or not nursery.pulls.is_empty()

func prepare_sleep() -> void: calibrator.prepare_sleep()
func reserved_clone_id() -> int: return calibrator.clone_id() if is_instance_valid(calibrator) else 0
func reserves_station(id: int) -> bool:
	if is_instance_valid(calibrator) and calibrator.reserves_station(id): return true
	var station=game.service.by_id(id)
	if station!=null and is_instance_valid(nursery):
		for member in station.crew:
			if nursery.presenting(int(member.get("clone_id",0))): return true
	return false
func presenting_clone(identity: int) -> bool: return identity>0 and (identity==reserved_clone_id() or nursery.presenting(identity))

func near_controls(peer: int) -> bool:
	var position:=peer_position(peer)
	return position.distance_to(game.shop.computer.global_position)<4.5 or position.distance_to(Layout.CHAIR)<3.5 or ("lab_production" in game.service.progress.lab_upgrades and position.distance_to(Layout.fixture("lab_production"))<3.5)

func local_holding() -> bool:
	return not game.input_blocked() and researching(game.session.local_id()) and state.phase=="fill" and (Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

func local_pull_holding() -> bool:
	return not game.input_blocked() and nursery.pulling(game.session.local_id()) and (Input.is_physical_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))

func pull_held(peer: int) -> bool:
	if peer==1: return local_pull_holding()
	var pose: Dictionary=game.session.player_poses.get(peer,{})
	return pose.get("lab_pull",false) and Time.get_ticks_msec()-int(pose.get("received_at",0))<350

func target(camera: Camera3D, peer: int) -> Dictionary:
	var p=game.service.progress
	if game.shop.near_ray(camera,Layout.MICROSCOPE+Vector3(0,1.5,0.1),0.42):
		return {"action":"lab_scan","sample":int(p.lab_sample.get("serial",-1)),"hint":"(E) Капнуть образец в микроскоп" if nursery.tool(peer)=="sample" else "(E) Посмотреть лучшую формулу"}
	if not p.lab_sample.is_empty() and int(p.lab_sample.get("carrier",0))==0 and game.shop.near_ray(camera,to_global(SAMPLE),0.25):
		return {"action":"lab_sample","sample":int(p.lab_sample.serial),"hint":"(E) Взять каплю · отнести к микроскопу"}
	var chair_target: Dictionary=calibrator.target(camera,peer)
	if not chair_target.is_empty(): return chair_target
	var nursery_target: Dictionary=nursery.target(camera,peer)
	if not nursery_target.is_empty(): return nursery_target
	if "lab_production" in p.lab_upgrades and game.shop.near_ray(camera,Layout.fixture("lab_production")+Vector3.UP*1.2,0.5):
		return {"action":"lab_controls","hint":"(E) Настроить производство"}
	if not inside(camera.global_position): return {}
	if game.shop.near_ray(camera,to_global(Vector3(-1.48,1.09,7.88)),0.17):
		return {"action":"lab_restart","revision":state.revision,"hint":"(E) Прервать эксперимент / убрать образец"}
	var point:=to_global(Vector3(0,1.5,8)) if state.phase!="idle" else to_global(BUTTON)
	if not game.shop.near_ray(camera,point,1.1 if state.phase!="idle" else 0.25): return {}
	var hint: String={"idle":"(E) Новый эксперимент · 20","fill":"Удерживай E / ЛКМ · уровень жидкости","fill_ready":"(E / ЛКМ) Перейти к стабилизатору","tune":"(E / ЛКМ) Зафиксировать стрелку","failed":"Жидкость испорчена · попытка оплачена"}.get(state.phase,"")
	if not p.lab_sample.is_empty(): hint="Забери образец и исследуй в микроскопе"
	if p.lab_stage<3: hint="Сначала собери лабораторию"
	elif p.stars<1: hint="Исследования откроются после первой звезды"
	elif int(state.owner) not in [0,peer]: hint="Стол занят напарником"
	return {"action":"lab_press","revision":state.revision,"observed_age":state.age,"hint":hint}

func action(peer: int, data: Dictionary) -> String:
	var name:=str(data.get("action",""))
	if name.begins_with("lab_cal_"): return calibrator.action(peer,data)
	if name in ["lab_tool","lab_pot","lab_pull"]: return nursery.action(peer,data)
	if name=="lab_production_config": return nursery.configure(peer,data)
	if name=="lab_controls":
		if not near_controls(peer): return "Подойди к пульту."
		game.session.lab_result(peer,{"kind":"controls"}); return ""
	if name=="lab_sample" or name=="lab_scan": return sample_action(peer,data)
	if name=="lab_restart":
		if not inside(peer_position(peer)) or int(data.get("revision",-1))!=int(state.revision): return ""
		if int(state.owner) not in [0,peer]: return "Стол занят напарником."
		var sample: Dictionary=game.service.progress.lab_sample
		if not sample.is_empty():
			if int(sample.get("carrier",0)) not in [0,peer]: return "Образец у напарника."
			game.service.progress.lab_sample={}
			if nursery.tool(peer)=="sample": nursery.hands.erase(peer)
		reset(); return ""
	if name=="lab_press": return press(peer,int(data.get("revision",-1)),float(data.get("observed_age",-1.0)))
	return "Действие лаборатории не найдено."

func sample_action(peer: int, data: Dictionary) -> String:
	var p=game.service.progress
	if game.service.training_for(peer)!=null or researching(peer) or calibrator.manual_owner()==peer: return "Сначала заверши текущую работу."
	if data.action=="lab_sample":
		if peer_position(peer).distance_to(to_global(SAMPLE))>3.2: return "Подойди к образцу."
		if hands_busy(peer): return "Сначала освободи руки."
		if p.lab_sample.is_empty() or int(p.lab_sample.serial)!=int(data.get("sample",-1)) or int(p.lab_sample.carrier)!=0: return ""
		p.lab_sample.carrier=peer; nursery.hands[peer]="sample"
		return ""
	if peer_position(peer).distance_to(Layout.MICROSCOPE)>3.2: return "Подойди к микроскопу."
	if nursery.tool(peer)!="sample":
		if p.lab_formula_version<=0: return "Приготовь жидкость и принеси каплю со стола."
		game.session.lab_result(peer,{"kind":"microscope","tempo":p.lab_formula_tempo,"best":p.lab_formula_tempo,"version":p.lab_formula_version,"improved":false})
		return ""
	if p.lab_sample.is_empty() or int(p.lab_sample.carrier)!=peer or int(p.lab_sample.serial)!=int(data.get("sample",-1)): return ""
	var before: float=float(p.lab_formula_tempo)
	var attempt:=float(p.lab_sample.tempo)
	var improved: bool=p.lab_formula_version<=0 or attempt>before
	if improved:
		p.lab_formula_tempo=maxf(0.70,attempt)
		p.lab_formula_version+=1
	p.lab_sample={}; nursery.hands.erase(peer); p.revision+=1
	game.service.trace("formula_examined",{"attempt":attempt,"best":p.lab_formula_tempo,"version":p.lab_formula_version})
	game.session.lab_result(peer,{"kind":"microscope","tempo":attempt,"before":before,"best":p.lab_formula_tempo,"version":p.lab_formula_version,"improved":improved})
	return ""

func press(peer: int, revision: int, observed_age := -1.0) -> String:
	if not inside(peer_position(peer)): return "Подойди к столу исследования."
	if hands_busy(peer) or game.service.training_for(peer)!=null or calibrator.manual_owner()==peer: return "Сначала освободи руки."
	var p=game.service.progress
	if p.lab_stage<3 or p.stars<1: return "Нужны готовая лаборатория и первая звезда."
	if int(state.owner) not in [0,peer]: return "Стол занят напарником."
	if revision!=int(state.revision): return ""
	match str(state.phase):
		"idle":
			if not p.lab_sample.is_empty(): return "Сначала исследуй приготовленный образец."
			if p.cash<Policy.EXPERIMENT_PRICE: return "Не хватает денег на эксперимент."
			p.cash-=Policy.EXPERIMENT_PRICE; p.revision+=1
			state.cost=Policy.EXPERIMENT_PRICE; state.owner=peer; state.phase="fill"; state.age=0.0
			var limits:=tempo_range(); state.low=limits.x; state.high=limits.y
			state.valve="lab_valve" in p.lab_upgrades; state.damper="lab_damper" in p.lab_upgrades
			game.save_cafe()
		"fill_ready": state.phase="tune"; state.age=0.0; state.needle=0.0
		"tune":
			var age:=float(state.age)
			if peer!=1 and is_finite(observed_age) and observed_age>=age-0.35 and observed_age<=age: age=observed_age
			state.needle=pingpong(age*(0.42 if state.damper else 1.2),1.0)
			state.needle_quality=zone_quality(state.needle)
			state.tempo=snappedf(lerpf(float(state.low),float(state.high),float(state.fill_quality)*0.6+float(state.needle_quality)*0.4),0.01)
			p.lab_sample_serial+=1
			p.lab_sample={"serial":p.lab_sample_serial,"tempo":state.tempo,"carrier":0}
			p.revision+=1
			reset()
			game.service.announce("Жидкость готова. Возьми образец и исследуй каплю в микроскопе.")
		_: return ""
	state.revision=int(state.revision)+1
	return ""

func advance(delta: float) -> void:
	nursery.advance(delta)
	calibrator.advance(delta)
	if state.phase=="idle": return
	var owner:=int(state.owner)
	if state.phase!="failed" and (not inside(peer_position(owner)) or game.service.training_for(owner)!=null):
		reset(); return
	state.age=float(state.age)+delta
	match str(state.phase):
		"fill":
			var held:=local_holding() if owner==1 else false
			if owner!=1:
				var pose: Dictionary=game.session.player_poses.get(owner,{})
				held=pose.get("lab_hold",false) and Time.get_ticks_msec()-int(pose.get("received_at",0))<350
			advance_balance(delta,held)
		"tune": state.needle=pingpong(float(state.age)*(0.42 if state.damper else 1.2),1.0)
		"failed":
			if float(state.age)>2.5: reset()

func advance_balance(delta: float, held: bool) -> void:
	state.level=clampf(float(state.level)+delta*(0.8 if held else -0.55)*(0.45 if state.valve else 1.0),0,1)
	if not state.armed:
		if float(state.level)<0.15: return
		state.armed=true
	if float(state.level)<0.15:
		state.phase="failed"; state.age=0.0; state.level=0.0; state.revision=int(state.revision)+1
		state.notice="Жидкость испорчена · −%d"%int(state.cost)
		game.service.trace("formula_failed",{"cost":state.cost})
		return
	var quality:=zone_quality(float(state.level),true)
	var speed:=1.0 if quality>=0.999 else 0.55 if quality>=0.4 else 0.25
	var sample:=minf(delta,(BALANCE_SECONDS-float(state.balanced))/speed)
	state.integral=float(state.integral)+quality*sample
	state.exposure=float(state.exposure)+sample
	state.balanced=float(state.balanced)+sample*speed
	if float(state.balanced)>=BALANCE_SECONDS-0.00001:
		state.fill_quality=clampf(float(state.integral)/maxf(0.001,float(state.exposure)),0,1)
		state.phase="fill_ready"; state.revision=int(state.revision)+1

func route_to_chair(identity: int) -> Array:
	var origin:=Layout.waiting_point(0)
	for i in range(game.service.progress.free_workers.size()):
		if int(game.service.progress.free_workers[i].id)==identity: origin=Layout.waiting_point(i)
	var route: Array=[]
	if game.evening!=null and game.evening.performers.has(identity):
		origin=game.evening.performers[identity].actor.global_position
		var approach:=origin
		for assignment in game.evening.plan():
			if int(assignment.worker.id)==identity: approach=assignment.spot.approach; break
		route=Lounge.approach_path(approach,game.service.progress.lounge_tier,game.service.progress.lounge_items)
		route.reverse(); route.push_front(origin); route.append(Vector3(10.4,0,9.75))
		route.append(Vector3(-1.1,0,9.75)); route.append(Layout.ENTRY)
	else:
		for option in game.service.clone_options():
			if int(option.id)!=identity or int(option.station)==0: continue
			var station=game.service.by_id(int(option.station))
			var role:=0
			for i in range(station.crew.size()):
				if int(station.crew[i].get("clone_id",0))==identity: role=i
			origin=station.to_global(Vector3(station.role_home_x(role),0,1.85))
			route=[origin,Vector3(origin.x,0,7.8),Vector3(-1.1,0,7.8),Vector3(-1.1,0,9.75),Layout.ENTRY]
			break
	var start: Vector3=Layout.ENTRY if not route.is_empty() else origin
	route.append_array(Layout.path(start,Layout.CHAIR+Vector3(0,0,-1.0),game.service.progress))
	route.append(Layout.CHAIR)
	return route

func _process(_delta: float) -> void:
	if game==null: return
	var p=game.service.progress
	apparatus.visible=p.lab_stage>=3
	for item in upgrade_nodes: upgrade_nodes[item].visible=item in p.lab_upgrades
	sample_mesh.visible=not p.lab_sample.is_empty() and int(p.lab_sample.get("carrier",0))==0
	if not apparatus.visible: return
	for i in range(burst_parts.size()):
		var t:=float(state.age)
		burst_parts[i].visible=state.phase=="failed" and t<0.85
		burst_parts[i].position=Vector3(-0.94,1.4,7.96)+Vector3(sin(i*2.4)*t*0.9,1.6*t-2.5*t*t,cos(i*2.4)*t*0.6)
	var level:=maxf(0.006,float(state.level))
	liquid.scale.y=level; liquid.position.y=1.02+0.38*level
	needle.position.x=-0.58+1.16*float(state.needle)
	progress_bar.scale.x=maxf(0.001,float(state.balanced)/BALANCE_SECONDS)
	progress_bar.position.x=-1.2+0.26*progress_bar.scale.x
	var limits:=tempo_range()
	var title: String={"idle":"СТОЛ ФОРМУЛЫ · эксперимент 20","fill":"1 · УДЕРЖИВАЙ УРОВЕНЬ В ЗЕЛЁНОЙ ЗОНЕ","fill_ready":"КОЛБА ГОТОВА · К СТАБИЛИЗАТОРУ","tune":"2 · ПОЙМАЙ СТРЕЛКУ","failed":"ПШШШ! ЖИДКОСТЬ ИСПОРЧЕНА"}.get(state.phase,"")
	if not p.lab_sample.is_empty(): title="ОБРАЗЕЦ ГОТОВ · ОТНЕСИ В МИКРОСКОП"
	caption.text=title+("\n"+str(state.notice) if not str(state.notice).is_empty() else "")
	result_label.text="Изучено %d%% · предел оборудования %d%%"%[roundi(p.lab_formula_tempo*100),roundi(limits.y*100)]
	if int(state.revision)!=revision_seen:
		if state.phase=="failed": burst_sound.play()
		revision_seen=int(state.revision)
