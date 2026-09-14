from pathlib import Path


def edit(path, old, new, count=1):
    p = Path(path)
    s = p.read_text()
    if s.count(old) < count:
        raise SystemExit(f"Expected block not found in {path}: {old[:120]!r}")
    p.write_text(s.replace(old, new, count))


# Laboratory: two active interventions separated by autonomous growth.
edit('scripts/clone_laboratory.gd',
     'const BALANCE_SECONDS := 6.0\nconst BUTTON := Vector3(0,1.12,7.85)',
     'const BALANCE_SECONDS := 6.0\nconst GROW_PREP_SECONDS := 75.0\nconst GROW_FINISH_SECONDS := 75.0\nconst BUTTON := Vector3(0,1.12,7.85)')
edit('scripts/clone_laboratory.gd',
     'var little_clone: Node3D\nvar pulse_seen := 0',
     'var little_clone: Node3D\nvar growth_legs: Node3D\nvar pulse_seen := 0')
edit('scripts/clone_laboratory.gd',
     '\tlittle_clone.hide()\n\tfor i in range(10):',
     '''\tlittle_clone.hide()
\t# The machine exposes progress physically: legs first, then the whole clone.
\tgrowth_legs = Node3D.new()
\tapparatus.add_child(growth_legs)
\tgrowth_legs.position = Vector3(0.98,1.03,7.98)
\tfor x in [-0.065,0.065]:
\t\tvar leg := Node3D.new()
\t\tgrowth_legs.add_child(leg)
\t\tleg.position.x = x
\t\tProps.box(leg,Vector3(0.095,0.36,0.12),Vector3(0,0.18,0),Color("344e48"))
\tgrowth_legs.hide()
\tfor i in range(10):''')
edit('scripts/clone_laboratory.gd',
     '''\t\t\t"fill": text="Удерживай E / ЛКМ — уровень растёт; отпусти — падает"
\t\t\t"fill_ready": text="(E / ЛКМ) К стабилизатору"
\t\t\t"tune": text="(E / ЛКМ) Зафиксировать стрелку"
\t\t\t"ready": text="(E / ЛКМ) Сохранить результат" if int(state.clone_id)>0 else "(E / ЛКМ) Выпустить клона · уже оплачено"''',
     '''\t\t\t"fill": text="Удерживай E / ЛКМ — уровень растёт; отпусти — падает"
\t\t\t"grow_blank": text="Аппарат выращивает заготовку · можно идти в кафе"
\t\t\t"stage2_ready": text="(E / ЛКМ) Заготовка готова · к стабилизатору"
\t\t\t"fill_ready": text="(E / ЛКМ) К стабилизатору"
\t\t\t"tune": text="(E / ЛКМ) Зафиксировать стрелку"
\t\t\t"grow_finish": text="Клон дозревает · можно идти в кафе"
\t\t\t"ready": text="(E / ЛКМ) Сохранить результат" if int(state.clone_id)>0 else "(E / ЛКМ) Выпустить клона · уже оплачено"''')
edit('scripts/clone_laboratory.gd',
     '''\t\t"fill_ready": state.phase="tune"; state.age=0.0; state.needle=0.0
\t\t"tune":
\t\t\t# Use the displayed server age within a bounded network-delay window for guests.
\t\t\tvar age: float=state.age
\t\t\tif peer!=1 and is_finite(observed_age) and observed_age>=age-0.35 and observed_age<=age: age=observed_age
\t\t\tstate.needle=pingpong(age*(0.42 if state.damper else 1.2),1.0)
\t\t\tstate.needle_quality=zone_quality(state.needle)
\t\t\tstate.tempo=snappedf(lerpf(state.low,state.high,state.fill_quality*0.6+state.needle_quality*0.4),0.01)
\t\t\tstate.phase="ready"
\t\t"ready":''',
     '''\t\t"fill_ready", "stage2_ready": state.phase="tune"; state.age=0.0; state.needle=0.0
\t\t"tune":
\t\t\t# Use the displayed server age within a bounded network-delay window for guests.
\t\t\tvar age: float=state.age
\t\t\tif peer!=1 and is_finite(observed_age) and observed_age>=age-0.35 and observed_age<=age: age=observed_age
\t\t\tstate.needle=pingpong(age*(0.42 if state.damper else 1.2),1.0)
\t\t\tstate.needle_quality=zone_quality(state.needle)
\t\t\tstate.tempo=snappedf(lerpf(state.low,state.high,state.fill_quality*0.6+state.needle_quality*0.4),0.01)
\t\t\tstate.phase="grow_finish" if int(state.clone_id)==0 else "ready"
\t\t\tstate.age=0.0
\t\t"grow_blank", "grow_finish": return ""
\t\t"ready":''')

old_advance = '''func advance(delta: float) -> void:
\tif state.phase=="idle": return
\tif state.phase not in ["done","failed"] and (not inside(peer_position(int(state.owner))) or game.service.training_for(int(state.owner))!=null):
\t\tgame.service.trace("cloning_cancelled",{"reason":"left_apparatus"})
\t\treset(); game.service.assign_clones(); return
\tstate.age=float(state.age)+delta
\tmatch state.phase:
\t\t"fill":
\t\t\tvar held := local_holding() if int(state.owner)==1 else false
\t\t\tif int(state.owner)!=1:
\t\t\t\tvar pose: Dictionary=game.session.player_poses.get(int(state.owner),{})
\t\t\t\theld=pose.get("lab_hold",false) and Time.get_ticks_msec()-int(pose.get("received_at",0))<350
\t\t\tadvance_balance(delta,held)
\t\t"tune": state.needle=pingpong(float(state.age)*(0.42 if state.damper else 1.2),1.0)
\t\t"done", "failed":
\t\t\tif float(state.age)>2.5: reset()
'''
new_advance = '''func advance(delta: float) -> void:
\tif state.phase=="idle": return
\tvar owner := int(state.owner)
\tvar autonomous := state.phase in ["grow_blank","stage2_ready","grow_finish","ready"]
\tif state.phase not in ["done","failed"]:
\t\tif owner>1 and not game.session.members.has(owner):
\t\t\tgame.service.trace("cloning_cancelled",{"reason":"owner_disconnected"})
\t\t\treset(); game.service.assign_clones(); return
\t\tif not autonomous and (not inside(peer_position(owner)) or game.service.training_for(owner)!=null):
\t\t\tgame.service.trace("cloning_cancelled",{"reason":"left_apparatus"})
\t\t\treset(); game.service.assign_clones(); return
\tstate.age=float(state.age)+delta
\tmatch state.phase:
\t\t"fill":
\t\t\tvar held := local_holding() if owner==1 else false
\t\t\tif owner!=1:
\t\t\t\tvar pose: Dictionary=game.session.player_poses.get(owner,{})
\t\t\t\theld=pose.get("lab_hold",false) and Time.get_ticks_msec()-int(pose.get("received_at",0))<350
\t\t\tadvance_balance(delta,held)
\t\t"grow_blank":
\t\t\tif float(state.age)>=GROW_PREP_SECONDS:
\t\t\t\tstate.phase="stage2_ready"; state.age=0.0; state.revision=int(state.revision)+1; state.pulse=int(state.pulse)+1
\t\t\t\tstate.notice="Заготовка готова и спокойно ждёт тебя"
\t\t"tune": state.needle=pingpong(float(state.age)*(0.42 if state.damper else 1.2),1.0)
\t\t"grow_finish":
\t\t\tif float(state.age)>=GROW_FINISH_SECONDS:
\t\t\t\tstate.phase="ready"; state.age=0.0; state.revision=int(state.revision)+1; state.pulse=int(state.pulse)+1
\t\t\t\tstate.notice="Клон дозрел и ждёт выпуска"
\t\t"done", "failed":
\t\t\tif float(state.age)>2.5: reset()
'''
edit('scripts/clone_laboratory.gd', old_advance, new_advance)
edit('scripts/clone_laboratory.gd',
     '''\tif float(state.balanced)>=BALANCE_SECONDS-0.00001:
\t\tstate.fill_quality=clampf(float(state.integral)/maxf(0.001,float(state.exposure)),0,1)
\t\tstate.phase="fill_ready"; state.revision=int(state.revision)+1

func _process(_delta: float) -> void:''',
     '''\tif float(state.balanced)>=BALANCE_SECONDS-0.00001:
\t\tstate.fill_quality=clampf(float(state.integral)/maxf(0.001,float(state.exposure)),0,1)
\t\tif int(state.clone_id)==0:
\t\t\tstate.phase="grow_blank"; state.age=0.0; state.notice="Аппарат выращивает заготовку · можешь заняться кафе"
\t\telse: state.phase="fill_ready"
\t\tstate.revision=int(state.revision)+1

func countdown(total: float) -> String:
\tvar seconds := maxi(0,ceili(total-float(state.age)))
\treturn "%d:%02d" % [seconds/60,seconds%60]

func _process(_delta: float) -> void:''')
edit('scripts/clone_laboratory.gd',
     '''\tlittle_clone.visible = state.phase in ["ready","done"]
\tlittle_clone.rotation.z = sin(float(state.age)*8)*0.09 if state.phase=="done" else 0.0
\tlittle_clone.scale = Vector3.ONE * (0.85 + minf(0.15,float(state.age)*0.2) if state.phase=="done" else 0.85)''',
     '''\tgrowth_legs.visible = state.phase in ["grow_blank","stage2_ready","grow_finish"]
\tif growth_legs.visible:
\t\tvar leg_progress := clampf(float(state.age)/GROW_PREP_SECONDS,0.0,1.0) if state.phase=="grow_blank" else 1.0
\t\tgrowth_legs.scale=Vector3(1,0.25+0.75*leg_progress,1)
\t\tgrowth_legs.rotation.z=sin(float(state.age)*6.0)*0.08
\tlittle_clone.visible = state.phase in ["grow_finish","ready","done"]
\tlittle_clone.rotation.z = sin(float(state.age)*8)*0.09 if state.phase=="done" else 0.0
\tvar maturity := clampf(float(state.age)/GROW_FINISH_SECONDS,0.0,1.0) if state.phase=="grow_finish" else 1.0
\tlittle_clone.scale = Vector3.ONE * ((0.45+0.40*maturity) if state.phase=="grow_finish" else (0.85+minf(0.15,float(state.age)*0.2) if state.phase=="done" else 0.85))''')
old_titles = '''\tvar titles := {"idle":"ТЯП-КЛОН · %d–%d%%"%[roundi(limits.x*100),roundi(limits.y*100)],"fill":"1 · УДЕРЖИВАЙ УРОВЕНЬ В ЗЕЛЁНОЙ ЗОНЕ","fill_ready":"КОЛБА ГОТОВА · К СТАБИЛИЗАТОРУ","tune":"2 · ПОЙМАЙ СТРЕЛКУ","ready":"3 · РЕЗУЛЬТАТ ГОТОВ","done":"ЕЩЁ ОДИН Я!","failed":"ПШШШ! НЕ ПОЛУЧИЛОСЬ"}
\tvar fill: float=float(state.integral)/maxf(0.001,float(state.exposure))
\tresult_label.text=""
\tif state.phase!="idle": result_label.text="Колба: %d%%"%roundi(fill*100)
\tif state.phase=="ready" and int(state.clone_id)>0:
\t\tvar worker: Dictionary=game.service.clone_data(int(state.clone_id))
\t\tresult_label.text+=" · прежний темп %d%%"%roundi(float(worker.get("tempo",1.0))*100)
\tif state.phase in ["ready","done"]: result_label.text+=" · Стрелка: %d%%\\nТемп клона: %d%%"%[roundi(float(state.needle_quality)*100),roundi(float(state.tempo)*100)]
\tif state.phase=="idle": titles.idle += " · свободно %d" % game.service.progress.free_clones
\tcaption.text = str(titles[state.phase]) + ("\\n"+str(state.notice) if not str(state.notice).is_empty() else "")'''
new_titles = '''\tvar title := ""
\tmatch state.phase:
\t\t"idle": title="ТЯП-КЛОН · %d–%d%% · свободно %d"%[roundi(limits.x*100),roundi(limits.y*100),game.service.progress.free_clones]
\t\t"fill": title="1 · УДЕРЖИВАЙ УРОВЕНЬ В ЗЕЛЁНОЙ ЗОНЕ"
\t\t"grow_blank": title="РАСТУТ НОГИ · %s · ИДИ РАБОТАЙ"%countdown(GROW_PREP_SECONDS)
\t\t"stage2_ready": title="НОГИ ГОТОВЫ · НУЖЕН СТАБИЛИЗАТОР"
\t\t"fill_ready": title="КОЛБА ГОТОВА · К СТАБИЛИЗАТОРУ"
\t\t"tune": title="2 · ПОЙМАЙ СТРЕЛКУ"
\t\t"grow_finish": title="КЛОН ДОЗРЕВАЕТ · %s · ИДИ РАБОТАЙ"%countdown(GROW_FINISH_SECONDS)
\t\t"ready": title="3 · КЛОН ГОТОВ"
\t\t"done": title="ЕЩЁ ОДИН Я!"
\t\t"failed": title="ПШШШ! НЕ ПОЛУЧИЛОСЬ"
\tvar fill: float=float(state.integral)/maxf(0.001,float(state.exposure))
\tresult_label.text=""
\tif state.phase!="idle": result_label.text="Колба: %d%%"%roundi(fill*100)
\tif state.phase=="ready" and int(state.clone_id)>0:
\t\tvar worker: Dictionary=game.service.clone_data(int(state.clone_id))
\t\tresult_label.text+=" · прежний темп %d%%"%roundi(float(worker.get("tempo",1.0))*100)
\tif state.phase in ["grow_finish","ready","done"]: result_label.text+=" · Стрелка: %d%%\\nТемп клона: %d%%"%[roundi(float(state.needle_quality)*100),roundi(float(state.tempo)*100)]
\tcaption.text = title + ("\\n"+str(state.notice) if not str(state.notice).is_empty() else "")'''
edit('scripts/clone_laboratory.gd', old_titles, new_titles)

# Rest multiplier affects only today's effective tempo.
edit('scripts/work_station.gd',
     '''func crew_tempo() -> float:
\tvar slowest := 10.0
\tfor member in crew: slowest = minf(slowest,float(member.get("tempo",1.0)))
\treturn clampf(slowest,0.7,10.0)

func crew_name(role: int) -> String:
\treturn str(crew[role].name) + " · %d%%" % roundi(float(crew[role].get("tempo",1.0))*100)''',
     '''func crew_tempo() -> float:
\tvar slowest := 11.0
\tfor member in crew:
\t\tvar effective := float(member.get("tempo",1.0))*float(member.get("rest",1.0))
\t\tslowest = minf(slowest,effective)
\treturn clampf(slowest,0.63,11.0)

func crew_name(role: int) -> String:
\tvar base := float(crew[role].get("tempo",1.0))
\tvar rest := float(crew[role].get("rest",1.0))
\tvar text := str(crew[role].name) + " · %d%%" % roundi(base*rest*100)
\tif not is_equal_approx(rest,1.0): text += " · отдых %d%%" % roundi(rest*100)
\treturn text''')

edit('scripts/cafe_service.gd',
     '''func next_day() -> String:
\tif progress.shift != "night" or any_training(): return "Сначала заверши дела текущей смены."
\ttrace("next_day", {"day":progress.day+1})''',
     '''func next_day() -> String:
\tif progress.shift != "night" or any_training(): return "Сначала заверши дела текущей смены."
\tif game != null and is_instance_valid(game.evening): game.evening.apply_rest()
\ttrace("next_day", {"day":progress.day+1})''')
edit('scripts/cafe_service.gd',
     'announce("Кафе закрыто до утра. Можно заняться лабораторией и обустройством или отдохнуть.")',
     'announce("Смена закончена. Клоны бегут в комнату отдыха; посмотри, как устроились, или сразу начинай новый день.")')
edit('scripts/cafe_service.gd',
     '''func normalize_workers() -> void:
\twhile progress.free_workers.size() < progress.free_clones:
\t\tprogress.free_workers.append({"id":progress.next_clone_id,"tempo":1.0})
\t\tprogress.next_clone_id+=1
\tfor station in stations:
\t\tif station.manual_station: continue
\t\tfor role in range(station.role_count() if station.staffed<0 else station.staffed):
\t\t\tvar member: Dictionary = station.crew[role]
\t\t\tif not member.has("clone_id"):
\t\t\t\tmember.clone_id=progress.next_clone_id; progress.next_clone_id+=1
\t\t\tmember.tempo=clampf(float(member.get("tempo",1.0)),0.7,10.0)
\tprogress.free_clones=progress.free_workers.size()''',
     '''func normalize_workers() -> void:
\twhile progress.free_workers.size() < progress.free_clones:
\t\tprogress.free_workers.append({"id":progress.next_clone_id,"tempo":1.0,"rest":1.0})
\t\tprogress.next_clone_id+=1
\tfor worker in progress.free_workers:
\t\tworker.tempo=clampf(float(worker.get("tempo",1.0)),0.7,10.0)
\t\tworker.rest=clampf(float(worker.get("rest",1.0)),0.9,1.1)
\tfor station in stations:
\t\tif station.manual_station: continue
\t\tfor role in range(station.role_count() if station.staffed<0 else station.staffed):
\t\t\tvar member: Dictionary = station.crew[role]
\t\t\tif not member.has("clone_id"):
\t\t\t\tmember.clone_id=progress.next_clone_id; progress.next_clone_id+=1
\t\t\tmember.tempo=clampf(float(member.get("tempo",1.0)),0.7,10.0)
\t\t\tmember.rest=clampf(float(member.get("rest",1.0)),0.9,1.1)
\tprogress.free_clones=progress.free_workers.size()''')
edit('scripts/cafe_service.gd',
     '''\t\t\tstation.crew[station.staffed].clone_id=worker.id
\t\t\tstation.crew[station.staffed].tempo=worker.tempo
\t\t\tstation.staffed+=1''',
     '''\t\t\tstation.crew[station.staffed].clone_id=worker.id
\t\t\tstation.crew[station.staffed].tempo=worker.tempo
\t\t\tstation.crew[station.staffed].rest=worker.get("rest",1.0)
\t\t\tstation.staffed+=1''')
edit('scripts/cafe_service.gd',
     'progress.free_workers.append({"id":progress.next_clone_id,"tempo":clampf(tempo,0.7,10.0)})',
     'progress.free_workers.append({"id":progress.next_clone_id,"tempo":clampf(tempo,0.7,10.0),"rest":1.0})')
edit('scripts/cafe_progression.gd',
     '\tif shift == "night": return "Ночь · лаборатория %d/3 · следующий день у двери отдыха" % lab_stage if stars == 0 else "Ночь · обустрой кафе или отдохни до утра"',
     '\tif shift == "night": return "Ночь · клоны устраиваются в комнате отдыха · следующий день у двери"')

# Deterministic rest-room crowd. Good places fill first; worker-to-place assignment rotates by day.
Path('scripts/staff_evening.gd').write_text(r'''extends Node3D
## End-of-shift celebration plus deterministic rest spots. Rest affects only the next day.
const Avatar=preload("res://scripts/cook_avatar.gd")
const Props=preload("res://scripts/props.gd")
const REST_SPOTS := [
\t{"position":Vector3(6.0,0.62,9.55),"quality":1.10,"pose":"bed"},
\t{"position":Vector3(8.7,0.62,9.55),"quality":1.08,"pose":"bed"},
\t{"position":Vector3(11.2,0.72,9.45),"quality":1.03,"pose":"bench"},
\t{"position":Vector3(13.4,0.80,9.45),"quality":1.00,"pose":"table"},
\t{"position":Vector3(7.2,0.06,8.45),"quality":0.96,"pose":"floor"},
\t{"position":Vector3(9.7,0.06,8.45),"quality":0.94,"pose":"floor"},
\t{"position":Vector3(6.0,0.92,9.55),"quality":0.92,"pose":"stack"},
\t{"position":Vector3(14.5,0.0,9.0),"quality":0.90,"pose":"stand"}
]
var game: Node3D
var performers := {}

func setup(owner_game: Node3D) -> void:
\tgame=owner_game
\t# A deliberately undersized rest area: early clones fit, later clones improvise.
\tfor x in [6.0,8.7]:
\t\tProps.solid_box(self,Vector3(2.15,0.24,0.88),Vector3(x,0.28,9.55),Color("80634f"))
\t\tProps.box(self,Vector3(1.75,0.16,0.72),Vector3(x,0.46,9.55),Color("b9a477"))
\t\tProps.box(self,Vector3(0.48,0.12,0.65),Vector3(x-0.62,0.58,9.55),Color("e5d9b8"))
\tProps.solid_box(self,Vector3(2.0,0.42,0.62),Vector3(11.2,0.25,9.45),Color("637b70"))
\tProps.solid_box(self,Vector3(1.1,0.78,0.72),Vector3(13.4,0.39,9.45),Color("8d6b50"))

func workers() -> Array:
\tvar result: Array=[]
\tfor station in game.service.stations:
\t\tif station.manual_station: continue
\t\tfor role in range(station.role_count() if station.staffed<0 else station.staffed):
\t\t\tvar member: Dictionary=station.crew[role]
\t\t\tvar id:=int(member.get("clone_id",0))
\t\t\tif id<=0: continue
\t\t\tvar home: Vector3=station.to_global(Vector3((-1.35 if role==0 else 1.35) if station.role_count()==2 else 0,0,1.85))
\t\t\tresult.append({"id":id,"name":str(member.name),"home":home,"station":station})
\tfor worker in game.service.progress.free_workers:
\t\tvar id:=int(worker.get("id",0))
\t\tif id>0: result.append({"id":id,"name":"Свободный клон №%d"%id,"home":Vector3(1.0,0,7.95),"station":null})
\tresult.sort_custom(func(a,b): return int(a.id)<int(b.id))
\treturn result

func rest_spot(index: int) -> Dictionary:
\tif index<REST_SPOTS.size(): return REST_SPOTS[index].duplicate(true)
\tvar layer:=1+int((index-REST_SPOTS.size())/2)
\tvar side: float=-1.0 if index%2==0 else 1.0
\treturn {"position":Vector3(6.0+side*0.18,0.92+layer*0.28,9.55),"quality":0.90,"pose":"stack"}

func plan() -> Array:
\tvar entries:=workers()
\tvar result: Array=[]
\tif entries.is_empty(): return result
\tfor spot_index in range(entries.size()):
\t\tvar worker_index:=posmod(spot_index+game.service.progress.day,entries.size())
\t\tresult.append({"worker":entries[worker_index],"spot":rest_spot(spot_index)})
\treturn result

func apply_rest() -> void:
\tvar summary: Array=[]
\tfor assignment in plan():
\t\tvar worker: Dictionary=game.service.clone_data(int(assignment.worker.id))
\t\tif worker.is_empty(): continue
\t\tworker.rest=clampf(float(assignment.spot.quality),0.9,1.1)
\t\tsummary.append({"id":assignment.worker.id,"rest":worker.rest})
\tgame.service.progress.revision+=1
\tgame.service.trace("rest_applied",{"day":game.service.progress.day+1,"workers":summary})

func settle(actor: Node3D, spot: Dictionary, identity: int) -> void:
\tactor.position=spot.position
\tactor.book.set_reading(false)
\tactor.notebook.hide()
\tactor.rotation=Vector3.ZERO
\tactor.head.rotation=Vector3.ZERO
\tfor leg in actor.legs: leg.rotation.x=0
\tmatch str(spot.pose):
\t\t"bed": actor.rotation.z=PI/2; actor.rotation.y=PI if identity%2==0 else 0.0
\t\t"bench": actor.rotation.z=0.35; actor.rotation.y=PI/2
\t\t"table": actor.rotation.z=1.18; actor.rotation.y=-PI/2
\t\t"floor": actor.rotation.z=PI/2; actor.rotation.y=identity*0.7
\t\t"stack": actor.rotation.z=PI/2; actor.rotation.y=PI if identity%2==0 else 0.0
\t\t"stand": actor.rotation.y=PI; actor.head.rotation.x=0.38

func _process(_delta: float) -> void:
\tif game==null: return
\tif game.service.progress.shift!="night":
\t\tfor entry in performers.values(): entry.actor.queue_free(); entry.hat.queue_free()
\t\tperformers.clear()
\t\treturn
\tvar assignments:=plan()
\tvar current_ids: Array=[]
\tfor index in range(assignments.size()):
\t\tvar info: Dictionary=assignments[index].worker
\t\tvar spot: Dictionary=assignments[index].spot
\t\tvar id:=int(info.id)
\t\tcurrent_ids.append(id)
\t\tif not performers.has(id):
\t\t\tvar actor:=Avatar.new(); add_child(actor)
\t\t\tvar hat:=Node3D.new(); add_child(hat)
\t\t\tProps.cylinder(hat,0.26,0.22,Vector3.ZERO,Color("fff0cb"))
\t\t\tProps.cylinder(hat,0.29,0.04,Vector3(0,-0.09,0),Color("eee0b6"))
\t\t\tperformers[id]={"actor":actor,"hat":hat}
\t\tvar entry: Dictionary=performers[id]
\t\tvar actor: Node3D=entry.actor
\t\tvar hat: Node3D=entry.hat
\t\tvar t:=maxf(0,game.service.progress.night_elapsed-index*0.18)
\t\tvar variant:=id%3
\t\tvar home: Vector3=info.home
\t\tvar target:=Vector3(spot.position.x,0,spot.position.z)
\t\tvar route: Array=[home,Vector3(home.x,0,4.8),Vector3(5,0,4.8),Vector3(5,0,8.15),target]
\t\tvar speed: float=[3.6,4.6,2.9][variant]
\t\tvar distance:=maxf(0,t-0.85)*speed
\t\tvar point:=home
\t\tvar direction:=Vector3.BACK
\t\tvar done:=false
\t\tfor i in range(1,route.size()):
\t\t\tvar segment: Vector3=route[i]-route[i-1]
\t\t\tif distance<=segment.length(): point=route[i-1]+segment.normalized()*distance; direction=segment; break
\t\t\tdistance-=segment.length(); point=route[i]
\t\t\tif i==route.size()-1: done=true
\t\tvar station=info.station
\t\tvar training:=station!=null and station.training.active()
\t\tactor.visible=not training
\t\tif done:
\t\t\tsettle(actor,spot,id)
\t\t\tactor.caption.text=str(info.name)+"\\nОтдых %d%%"%roundi(float(spot.quality)*100)
\t\telse:
\t\t\tactor.position=point
\t\t\tactor.rotation.y=atan2(-direction.x,-direction.z)
\t\t\tactor.caption.text=str(info.name)+" · смена закончилась!"
\t\t\tactor.celebrate(t,variant,t<0.85)
\t\tactor.hat.visible=not done and t<0.42
\t\that.visible=t>=0.42 and not training
\t\tvar ht:=clampf(t-0.42,0,1.25)
\t\that.position=home+Vector3(sin(id*2.7)*ht*1.6,maxf(0.12,1.8+2.2*ht-3.0*ht*ht),cos(id*2.7)*ht*1.5)
\t\that.rotation=Vector3(ht*5,ht*3,ht*4)
\t\tif t>1.67: hat.position.y=0.12
\tfor id in performers.keys():
\t\tif id not in current_ids:
\t\t\tperformers[id].actor.queue_free(); performers[id].hat.queue_free(); performers.erase(id)
''')

edit('scripts/coop_session.gd','const PROTOCOL := "slapdash-cafe-life-16"','const PROTOCOL := "slapdash-cafe-life-17"')
edit('scripts/steam_lobby.gd','const PROTOCOL := "slapdash-cafe-stations-9"','const PROTOCOL := "slapdash-cafe-stations-10"')

# Focused regression tests.
p=Path('tests/test_clone_laboratory.gd')
s=p.read_text()
old='''\tcheck(lab.state.phase=="fill_ready","Balance phase completes")
\tlab.press(1,lab.state.revision)
\tlab.advance((0.5 if good else 0.97)/(0.42 if lab.state.damper else 1.2))
\tlab.press(1,lab.state.revision)
\tcheck(lab.state.phase=="ready","Needle accepts any zone")'''
new='''\tif target_id==0:
\t\tcheck(lab.state.phase=="grow_blank","New clone starts autonomous first growth stage")
\t\tgame.player.position=Vector3(-6,0.02,0)
\t\tlab.advance(lab.GROW_PREP_SECONDS-1.0)
\t\tcheck(lab.state.phase=="grow_blank","Player may leave while blank grows")
\t\tlab.advance(1.1)
\t\tcheck(lab.state.phase=="stage2_ready","Finished stage waits for player")
\t\tlab.advance(30.0)
\t\tcheck(lab.state.phase=="stage2_ready","Ready stage waits indefinitely without penalty")
\t\tgame.player.position=Vector3(0,0.02,7)
\telse:
\t\tcheck(lab.state.phase=="fill_ready","Calibration proceeds directly to stabilizer")
\tlab.press(1,lab.state.revision)
\tlab.advance((0.5 if good else 0.97)/(0.42 if lab.state.damper else 1.2))
\tlab.press(1,lab.state.revision)
\tif target_id==0:
\t\tcheck(lab.state.phase=="grow_finish","Needle starts autonomous maturation")
\t\tgame.player.position=Vector3(-6,0.02,0)
\t\tlab.advance(lab.GROW_FINISH_SECONDS)
\t\tcheck(lab.state.phase=="ready","Mature clone waits for release")
\t\tgame.player.position=Vector3(0,0.02,7)
\telse: check(lab.state.phase=="ready","Needle accepts any zone")'''
if old not in s: raise SystemExit('test_clone_laboratory helper block not found')
p.write_text(s.replace(old,new,1).replace('PASS: balance scoring, individual tempo, calibration, upgrades, persistence and ownership','PASS: asynchronous clone growth, balance scoring, individual tempo, calibration, upgrades, persistence and ownership'))

p=Path('tests/test_cafe_life.gd')
s=p.read_text()
old='''\tp.night_elapsed=25; game.evening._process(DT)
\tcheck(not entry.actor.visible,"Staff reach rest room")
\tservice.next_day(); game.evening._process(DT)
\tcheck(game.evening.performers.is_empty(),"Morning clears night props and opens cafe")'''
new='''\tp.night_elapsed=25; game.evening._process(DT)
\tcheck(entry.actor.visible and "Отдых" in entry.actor.caption.text,"Staff settle visibly into rest spots")
\tvar resting_id: int=st.crew[0].clone_id
\tservice.next_day(); game.evening._process(DT)
\tvar rested: Dictionary=service.clone_data(resting_id)
\tcheck(float(rested.get("rest",1.0))>=0.9 and float(rested.get("rest",1.0))<=1.1,"Night assigns bounded next-day rest multiplier")
\tcheck(is_equal_approx(st.crew_tempo(),float(rested.tempo)*float(rested.rest)),"Rest multiplies effective tempo without changing permanent tempo")
\tcheck(game.evening.performers.is_empty(),"Morning clears night props and opens cafe")'''
if old not in s: raise SystemExit('test_cafe_life rest block not found')
p.write_text(s.replace(old,new,1).replace('PASS: paid flask risk, graded filling, queue, meal handoff, night celebration and auto-opening','PASS: paid flask risk, graded filling, queue, meal handoff, visible rest quality and auto-opening'))

p=Path('docs/LABORATORY_AND_RECIPE_BOOK.md')
s=p.read_text()
note='''\n## Асинхронное выращивание и отдых\n\nНовый клон создаётся параллельно дневной работе кафе. После колбы аппарат сам выращивает заготовку 75 секунд; готовый этап ждёт игрока без штрафа. После стабилизатора клон дозревает ещё 75 секунд и снова ждёт выпуска. Во время обоих автоматических этапов игрок свободно готовит, обучает клонов и занимается покупками. Перекалибровка существующего работника остаётся короткой процедурой без ожидания.\n\nПосле смены клоны бросают шапки, бегут в комнату отдыха и занимают доступные места от лучших к худшим. Место задаёт множитель темпа следующего дня в диапазоне 90–110%; постоянный темп из лаборатории не меняется, усталость между днями не накапливается. Переход к утру рассчитывает отдых сразу — ждать анимацию сна не требуется. Текущая комната использует фиксированный набор мест; покупки и расширение мест добавляются отдельным следующим слоем.\n'''
if '## Асинхронное выращивание и отдых' not in s:
    p.write_text(s.rstrip()+"\n"+note)
