from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise RuntimeError(f"Missing anchor for {label}")
    return text.replace(old, new, 1)

# --- two-seat sofa, inward-facing chat and comic sleep poses ---
p = Path("scripts/lounge_layout.gd")
s = p.read_text()
s = replace_once(s, '{"id":"sofa","title":"Диван на троих","stage":"small","position":Vector3(6.5,0,14.7),"yaw":0.0}', '{"id":"sofa","title":"Диван на двоих","stage":"small","position":Vector3(6.5,0,14.7),"yaw":0.0}', "sofa title")
s = replace_once(s, 'slot("sofa_left","sofa",Vector3(5.62,-0.10,14.45),Vector3(5.62,0,13.65),0,"chat","Болтает на диване")', 'slot("sofa_left","sofa",Vector3(5.95,-0.10,14.45),Vector3(5.95,0,13.65),0,"chat","Болтает на диване")', "left sofa seat")
s = replace_once(s, '\n\t\tslot("sofa_middle","sofa",Vector3(6.5,-0.10,14.45),Vector3(6.5,0,13.65),0,"chat","Рассказывает историю"),', '', "remove middle sofa seat")
s = replace_once(s, 'slot("sofa_right","sofa",Vector3(7.38,-0.10,14.45),Vector3(7.38,0,13.65),0,"chat","Смеётся с соседями")', 'slot("sofa_right","sofa",Vector3(7.05,-0.10,14.45),Vector3(7.05,0,13.65),0,"chat","Смеётся с соседом")', "right sofa seat")
s = replace_once(s, 'Rect2(4.87,14.10,3.26,1.22), Rect2(5.12,10.92,2.76,0.74),', 'Rect2(5.25,14.10,2.50,1.22), Rect2(5.12,10.92,2.76,0.74),', "sofa footprint")
old_sleep = '''static func sleep_spot(leisure: Dictionary, identity: int, tier: int) -> Dictionary:\n\tvar spot: Dictionary=leisure.duplicate(true)\n\tspot.sleep_rotation=Vector3.ZERO\n\tspot.sleep_kind="standing"\n\tspot.activity="Спит стоя"\n\tmatch str(leisure.item):\n\t\t"sofa":\n\t\t\tvar layer: int=["sofa_left","sofa_middle","sofa_right"].find(leisure.id)\n\t\t\tspot.position=item_position("sofa",tier)+Vector3(-1.05,0.68+maxi(0,layer)*0.32,-0.1)\n\t\t\tspot.sleep_rotation=Vector3(0,0,-PI/2)\n\t\t\tspot.sleep_kind="lying"\n\t\t\tspot.activity="Спит поперёк дивана"\n'''
new_sleep = '''static func sleep_spot(leisure: Dictionary, identity: int, tier: int) -> Dictionary:\n\tvar spot: Dictionary=leisure.duplicate(true)\n\tspot.sleep_rotation=Vector3.ZERO\n\tspot.sleep_kind="standing"\n\tspot.activity="Спит стоя"\n\tif str(leisure.item)!="sofa" and posmod(identity,5)==2:\n\t\tspot.position=Vector3(leisure.approach)+Vector3(0,1.72,0)\n\t\tspot.sleep_kind="headstand"\n\t\tspot.activity="Спит на голове"\n\t\treturn spot\n\tmatch str(leisure.item):\n\t\t"sofa":\n\t\t\tvar layer: int=["sofa_left","sofa_right"].find(leisure.id)\n\t\t\tspot.position=item_position("sofa",tier)+Vector3(-0.86,0.72+maxi(0,layer)*0.31,-0.10)\n\t\t\tspot.sleep_kind="back"\n\t\t\tspot.activity="Спит на спине поверх соседа" if layer>0 else "Спит на спине на диване"\n'''
s = replace_once(s, old_sleep, new_sleep, "sleep pose rules")
p.write_text(s)

# --- physically resize the sofa to two seats ---
p = Path("scripts/lounge_furniture.gd")
s = p.read_text()
old_sofa = '''func build_sofa(parent: Node3D) -> void:\n\tlegs(parent,2.65,0.7,0.18)\n\tbox(parent,Vector3(3.15,0.34,1.12),Vector3(0,0.34,0),TEAL)\n\tbox(parent,Vector3(3.2,0.72,0.23),Vector3(0,0.85,0.46),Color("3f756e"))\n\tfor x in [-1.50,1.50]:\n\t\tbox(parent,Vector3(0.24,0.57,1.12),Vector3(x,0.68,0),TEAL)\n\tfor x in [-0.88,0.0,0.88]:\n\t\tbox(parent,Vector3(0.83,0.18,0.91),Vector3(x,0.56,-0.12),Color("6eaa96"))\n\t\tbox(parent,Vector3(0.82,0.51,0.17),Vector3(x,0.89,0.29),Color("68a18f"))\n\tfor x in [-1.05,1.05]:\n\t\tvar cushion:=box(parent,Vector3(0.35,0.33,0.13),Vector3(x,0.83,0.10),GOLD if x<0 else Color("bf8071"))\n\t\tcushion.rotation.z=x*0.20\n\tbox(parent,Vector3(0.48,0.035,0.78),Vector3(1.0,0.67,-0.14),Color("e3caa0"))\n'''
new_sofa = '''func build_sofa(parent: Node3D) -> void:\n\tlegs(parent,1.90,0.7,0.18)\n\tbox(parent,Vector3(2.40,0.34,1.12),Vector3(0,0.34,0),TEAL)\n\tbox(parent,Vector3(2.45,0.72,0.23),Vector3(0,0.85,0.46),Color("3f756e"))\n\tfor x in [-1.12,1.12]:\n\t\tbox(parent,Vector3(0.24,0.57,1.12),Vector3(x,0.68,0),TEAL)\n\tfor x in [-0.55,0.55]:\n\t\tbox(parent,Vector3(0.98,0.18,0.91),Vector3(x,0.56,-0.12),Color("6eaa96"))\n\t\tbox(parent,Vector3(0.97,0.51,0.17),Vector3(x,0.89,0.29),Color("68a18f"))\n\tfor x in [-0.72,0.72]:\n\t\tvar cushion:=box(parent,Vector3(0.32,0.31,0.13),Vector3(x,0.83,0.10),GOLD if x<0 else Color("bf8071"))\n\t\tcushion.rotation.z=x*0.20\n\tbox(parent,Vector3(0.42,0.035,0.72),Vector3(0.70,0.67,-0.14),Color("e3caa0"))\n'''
s = replace_once(s, old_sofa, new_sofa, "two-seat sofa geometry")
p.write_text(s)

# --- catalogue wording ---
p = Path("scripts/lounge_progression.gd")
s = p.read_text().replace('"sofa":{"name":"Диван на троих"', '"sofa":{"name":"Диван на двоих"', 1)
p.write_text(s)

# --- avatar: correct sofa eye contact, back sleeping, headstand sleeping, post-track antics ---
p = Path("scripts/cook_avatar.gd")
s = p.read_text()
s = replace_once(s, 'var side: float=-1.0 if str(spot.id)=="sofa_right" else 1.0 if str(spot.id)=="sofa_left" else sin(clock*0.43+identity)', 'var side: float=1.0 if str(spot.id)=="sofa_right" else -1.0 if str(spot.id)=="sofa_left" else sin(clock*0.43+identity)', "sofa chat gaze")
insert_anchor = '''func celebrate(clock: float, variant: int, throwing: bool) -> void:\n'''
finished_activity = '''func finished_role_activity(home: Vector3, partner: Vector3, delta: float, clock: float, identity: int) -> void:\n\treset_lounge_accessories()\n\that.show()\n\tnotebook.hide()\n\tvar cycle: float=fposmod(clock+identity*1.91,16.0)\n\tvar mode: int=int(cycle/4.0)\n\tvar destination:=home\n\tif mode==2:\n\t\tdestination+=Vector3(0.52 if fposmod(cycle,2.0)<1.0 else -0.52,0,0.12)\n\telif mode==3:\n\t\tdestination+=Vector3(-0.38 if home.x>0 else 0.38,0,-0.42)\n\tvar walking:=not walk_to(destination,delta)\n\tbook.set_reading(false)\n\tvar left:=Vector3(-0.35,0.80,-0.14)\n\tvar right:=Vector3(0.35,0.80,-0.14)\n\tif walking:\n\t\tleft.z+=sin(phase)*0.18\n\t\tright.z-=sin(phase)*0.18\n\telse:\n\t\tvar offset: Vector3=partner-position\n\t\tif offset.length()>0.05: rotation.y=lerp_angle(rotation.y,atan2(-offset.x,-offset.z),1.0-exp(-delta*5.0))\n\t\tvar local_partner: Vector3=to_local(partner+Vector3.UP*1.45)\n\t\thead.rotation.y=clampf(atan2(-local_partner.x,-local_partner.z),-1.05,1.05)\n\t\thead.rotation.x=-0.06+sin(clock*2.1+identity)*0.05\n\t\tmatch mode:\n\t\t\t0:\n\t\t\t\tvar explain:=0.5+0.5*sin(clock*3.4+identity)\n\t\t\t\tright=right.lerp(Vector3(0.62,1.38,-0.26),explain)\n\t\t\t\tleft=left.lerp(Vector3(-0.18,1.02,-0.34),1.0-explain*0.4)\n\t\t\t1:\n\t\t\t\tbook.pose_for_gaze(0.22,true,head.position.y)\n\t\t\t\tbook.set_reading(true,"meal")\n\t\t\t\thead.rotation.x=0.24\n\t\t\t\tleft=to_local(book.cover_grip(-1))\n\t\t\t\tright=to_local(book.cover_grip(1))\n\t\t\t2:\n\t\t\t\thead.rotation.y+=sin(clock*5.0)*0.16\n\t\t\t3:\n\t\t\t\tvar fuss:=0.5+0.5*sin(clock*5.6+identity)\n\t\t\t\tleft=left.lerp(Vector3(-0.55,1.18,-0.10),fuss)\n\t\t\t\tright=right.lerp(Vector3(0.55,1.18,-0.10),1.0-fuss)\n\tP.align_line(arms[0],Vector3(-0.3,1.2,0),left)\n\tP.align_line(arms[1],Vector3(0.3,1.2,0),right)\n\n'''
s = replace_once(s, insert_anchor, finished_activity + insert_anchor, "post-track animation")
old_sleep_pose = '''func sleep_pose(spot: Dictionary, clock: float, identity: int) -> void:\n\treset_lounge_accessories()\n\that.hide()\n\tnotebook.hide()\n\tbook.set_reading(false)\n\tposition=spot.position\n\trotation=spot.sleep_rotation\n\tvar seated: bool=str(spot.sleep_kind)=="seated"\n\tif seated:\n\t\tif not is_instance_valid(lounge_legs): build_lounge_accessories(); reset_lounge_accessories()\n\t\tlounge_legs.show()\n\t\tfor leg in legs: leg.hide()\n\t\trotation.y=float(spot.get("yaw",0))\n\thead.rotation=Vector3(0.26 if seated else 0.08,0,sin(clock*1.3+identity)*0.025)\n\tposition.y+=sin(clock*1.3+identity)*0.008\n\tfor i in range(arms.size()):\n\t\tvar side: float=-1.0 if i==0 else 1.0\n\t\tvar hand:=Vector3(side*0.18,0.92,-0.26)\n\t\tif identity%3==1: hand=Vector3(side*0.38,1.52,0.08)\n\t\tP.align_line(arms[i],Vector3(side*0.3,1.2,0),hand)\n'''
new_sleep_pose = '''func sleep_pose(spot: Dictionary, clock: float, identity: int) -> void:\n\treset_lounge_accessories()\n\that.hide()\n\tnotebook.hide()\n\tbook.set_reading(false)\n\tposition=spot.position\n\tvar kind:=str(spot.sleep_kind)\n\trotation=spot.sleep_rotation\n\tvar seated: bool=kind=="seated"\n\tif kind=="back":\n\t\t# Local body axis lies along the sofa; the face normal points straight up.\n\t\tbasis=Basis(Vector3(0,0,-1),Vector3(1,0,0),Vector3(0,-1,0))\n\telif kind=="headstand":\n\t\trotation=Vector3(0,0,PI)\n\t\tfor i in range(legs.size()): legs[i].rotation.z=(-0.78 if i==0 else 0.78)\n\telif seated:\n\t\tif not is_instance_valid(lounge_legs): build_lounge_accessories(); reset_lounge_accessories()\n\t\tlounge_legs.show()\n\t\tfor leg in legs: leg.hide()\n\t\trotation.y=float(spot.get("yaw",0))\n\thead.rotation=Vector3(0.26 if seated else 0.02 if kind in ["back","headstand"] else 0.08,0,sin(clock*1.3+identity)*0.025)\n\tposition.y+=sin(clock*1.3+identity)*0.008\n\tfor i in range(arms.size()):\n\t\tvar side: float=-1.0 if i==0 else 1.0\n\t\tvar hand:=Vector3(side*0.18,0.92,-0.26)\n\t\tif kind=="back": hand=Vector3(side*0.42,0.86,-0.04)\n\t\telif kind=="headstand": hand=Vector3(side*0.48,1.43,-0.04)\n\t\telif identity%3==1: hand=Vector3(side*0.38,1.52,0.08)\n\t\tP.align_line(arms[i],Vector3(side*0.3,1.2,0),hand)\n'''
s = replace_once(s, old_sleep_pose, new_sleep_pose, "sleep pose implementation")
p.write_text(s)

# --- post-recording clone antics on multi-cook production stations ---
p = Path("scripts/work_station.gd")
s = p.read_text()
anchor = '''\tview.update_view(model, age, state != "cooking")\n\tif type_id == "counter": view._update_worker(model, age, state != "cooking")\n'''
replacement = '''\tview.update_view(model, age, state != "cooking")\n\tif type_id == "kitchen" and state=="cooking" and recipes.has(order_dish):\n\t\tvar production_tracks: Array=recipes[order_dish].get("tracks",[])\n\t\tfor role in range(mini(role_count(),production_tracks.size())):\n\t\t\tvar track: Dictionary=production_tracks[role]\n\t\t\tif track.is_empty() or track.get("frames",[]).is_empty() or order_tick<float(track.frames.size()): continue\n\t\t\tvar home:=Vector3(-1.35 if role==0 else 1.35,0,1.85)\n\t\t\tvar partner: Vector3=view.actors[1-role].position if role_count()==2 else Vector3.ZERO\n\t\t\tview.actors[role].finished_role_activity(home,partner,delta,age,station_id*7+role)\n\t\t\tview.actors[role].caption.text=crew_name(role)+"\\nЗакончил · теперь подсказывает"\n\tif type_id == "counter": view._update_worker(model, age, state != "cooking")\n'''
s = replace_once(s, anchor, replacement, "finished role hook")
p.write_text(s)

# --- free clones are dormant inventory, not lounge workers ---
p = Path("scripts/staff_evening.gd")
s = p.read_text()
old_free = '''\tfor worker in game.service.progress.free_workers:\n\t\tvar id:=int(worker.get("id",0))\n\t\tif id>0:\n\t\t\tvar home:=Annex.lab_world(Vector3(0.98,0,7.98))\n\t\t\tresult.append({"id":id,"name":"Свободный клон №%d"%id,"home":home,"station":null,"from_lab":true})\n'''
s = replace_once(s, old_free, '', "remove free workers from evening")
p.write_text(s)

p = Path("scripts/cafe_service.gd")
s = p.read_text()
s = replace_once(s, 'progress.free_workers.append({"id":progress.next_clone_id,"tempo":1.0,"rest":progress.rest_multiplier})', 'progress.free_workers.append({"id":progress.next_clone_id,"tempo":1.0,"rest":1.0})', "legacy free worker rest")
s = replace_once(s, '\t\tworker.rest=progress.rest_multiplier\n', '\t\tworker.rest=1.0\n', "normalize free worker rest")
s = replace_once(s, 'progress.free_workers.append({"id":progress.next_clone_id,"tempo":clampf(tempo,0.7,10.0),"rest":progress.rest_multiplier})', 'progress.free_workers.append({"id":progress.next_clone_id,"tempo":clampf(tempo,0.7,10.0),"rest":1.0})', "new free worker rest")
p.write_text(s)

# --- show dormant clone count prominently in the laboratory ---
p = Path("scripts/clone_laboratory.gd")
s = p.read_text()
s = replace_once(s, '"idle": title="ТЯП-КЛОН · %d–%d%% · свободно %d"%[roundi(limits.x*100),roundi(limits.y*100),game.service.progress.free_clones]', '"idle": title="ТЯП-КЛОН · %d–%d%%\\nСВОБОДНЫХ КЛОНОВ: %d"%[roundi(limits.x*100),roundi(limits.y*100),game.service.progress.free_clones]', "lab free count")
p.write_text(s)

# --- persistent local Always skip checkbox for the shared cinematic ---
p = Path("scripts/sleep_cinematic.gd")
s = p.read_text()
s = replace_once(s, 'var self_avatar: Node3D\nvar showing := false\n', 'var self_avatar: Node3D\nvar always_skip_checkbox: CheckBox\nvar auto_vote_key := ""\nvar showing := false\nconst SETTINGS_PATH := "user://cinematic_settings.cfg"\n', "cinematic preference vars")
setup_anchor = '''\tshade=ColorRect.new()\n\tsurface.add_child(shade)\n\tshade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n\tshade.mouse_filter=Control.MOUSE_FILTER_IGNORE\n\toverlay.hide()\n'''
setup_new = '''\tshade=ColorRect.new()\n\tsurface.add_child(shade)\n\tshade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)\n\tshade.mouse_filter=Control.MOUSE_FILTER_IGNORE\n\talways_skip_checkbox=CheckBox.new()\n\tsurface.add_child(always_skip_checkbox)\n\talways_skip_checkbox.text="Всегда пропускать"\n\talways_skip_checkbox.anchor_left=1.0\n\talways_skip_checkbox.anchor_right=1.0\n\talways_skip_checkbox.anchor_top=1.0\n\talways_skip_checkbox.anchor_bottom=1.0\n\talways_skip_checkbox.offset_left=-245\n\talways_skip_checkbox.offset_right=-22\n\talways_skip_checkbox.offset_top=-67\n\talways_skip_checkbox.offset_bottom=-25\n\talways_skip_checkbox.add_theme_font_size_override("font_size",18)\n\talways_skip_checkbox.z_index=5\n\talways_skip_checkbox.button_pressed=_load_always_skip()\n\talways_skip_checkbox.toggled.connect(_set_always_skip)\n\toverlay.hide()\n'''
s = replace_once(s, setup_anchor, setup_new, "always skip checkbox")
helper_anchor = '''func begin() -> void:\n'''
helpers = '''func _load_always_skip() -> bool:\n\tvar config:=ConfigFile.new()\n\treturn config.load(SETTINGS_PATH)==OK and bool(config.get_value("cinematics","always_skip",false))\n\nfunc _set_always_skip(value: bool) -> void:\n\tvar config:=ConfigFile.new()\n\tconfig.load(SETTINGS_PATH)\n\tconfig.set_value("cinematics","always_skip",value)\n\tconfig.save(SETTINGS_PATH)\n\tauto_vote_key=""\n\nfunc _auto_skip_vote() -> bool:\n\tif not is_instance_valid(always_skip_checkbox) or not always_skip_checkbox.button_pressed or not game.session.sleep_scene_active(): return false\n\tvar scene: Dictionary=game.session.sleep_scene\n\tvar key: String="%s:%s"%[str(scene.get("serial",0)),game.session.sleep_scene_phase()]\n\tif key==auto_vote_key: return false\n\tauto_vote_key=key\n\tgame.session.request_action({"action":"skip_sleep"})\n\treturn true\n\n'''
s = replace_once(s, helper_anchor, helpers + helper_anchor, "cinematic preference helpers")
s = replace_once(s, '\tInput.mouse_mode=Input.MOUSE_MODE_CAPTURED\n', '\tInput.mouse_mode=Input.MOUSE_MODE_VISIBLE\n', "visible cursor during cinematic")
process_anchor = '''\tif not active:\n\t\tif showing: finish()\n\t\treturn\n\tvar age: float=game.session.sleep_scene_age()\n'''
process_new = '''\tif not active:\n\t\tif showing: finish()\n\t\tauto_vote_key=""\n\t\treturn\n\tif _auto_skip_vote(): return\n\tvar age: float=game.session.sleep_scene_age()\n'''
s = replace_once(s, process_anchor, process_new, "auto skip vote")
p.write_text(s)

# --- focused regression coverage ---
p = Path("tests/test_cafe_annex.gd")
s = p.read_text()
anchor = '''\tgame.service.create_clone(1.0,true)\n\tgame.service.progress.shift="night"; game.service.progress.night_elapsed=25.0\n'''
new = '''\tgame.service.create_clone(1.0,true)\n\tgame.service.create_clone(1.0,true)\n\tcheck(game.service.progress.free_workers.size()==1,"Extra clone remains dormant in laboratory inventory")\n\tcheck(game.evening.workers().size()==1,"Dormant free clone does not join lounge life")\n\tgame.service.progress.shift="night"; game.service.progress.night_elapsed=25.0\n'''
s = replace_once(s, anchor, new, "dormant free clone test")
end_anchor = '''\tvar floor_a:=Lounge.overflow_slot(0,2,[])\n'''
end_new = '''\tvar sofa_slots:=Lounge.activity_slots(0,["sofa"]).filter(func(spot): return spot.item=="sofa")\n\tcheck(sofa_slots.size()==2,"Starter sofa has exactly two leisure seats")\n\tcheck(Lounge.sleep_spot(sofa_slots[0],1,0).sleep_kind=="back" and Lounge.sleep_spot(sofa_slots[1],6,0).sleep_kind=="back","Both sofa sleepers lie face-up in the stack")\n\tvar comic_sleep:=Lounge.sleep_spot(Lounge.overflow_slot(0,2,[]),2,2)\n\tcheck(comic_sleep.sleep_kind=="headstand","Some clones use the upside-down comic sleep pose")\n\tvar floor_a:=Lounge.overflow_slot(0,2,[])\n'''
s = replace_once(s, end_anchor, end_new, "lounge polish tests")
p.write_text(s)

# --- documentation follows implemented rules ---
p = Path("docs/STAFF_LOUNGE.md")
s = p.read_text()
s = s.replace('диван на троих', 'диван на двоих')
s = s.replace('| Диван | 3 |', '| Диван | 2 |')
s = s.replace('качество трёх мест дивана', 'качество двух мест дивана')
s = s.replace('три места обычного дивана дают команде из трёх клонов +8%. Команде из шести — +4% каждому. Телевизор и растения поднимут качество этих трёх мест до 14%, а общий бонус шести работников — до +7%.', 'два места обычного дивана дают команде из двух клонов +8%. Команде из четырёх — +4% каждому. Телевизор и растения поднимут качество этих двух мест до 14%, а общий бонус четырёх работников — до +7%.')
s = s.replace('Учитываются все созданные клоны, включая свободных.', 'Учитываются только клоны, назначенные на станции. Свободные клоны заморожены в лаборатории и не участвуют в жизни кафе до назначения.')
s = s.replace('Созданные днём клоны наследуют текущий общий множитель.', 'Свободные клоны хранят нейтральный множитель 1.0 до назначения на станцию.')
s = s.replace('Сетевой протокол — `slapdash-cafe-rest-20`;', 'Сетевой протокол — `slapdash-cafe-wake-21`;')
s += '\n\n## Дополнительная живость\n\nДиван рассчитан на двух клонов: вечером они разворачиваются лицом друг к другу, а во время сна ложатся на спину лицом вверх и при необходимости складываются друг на друга. Среди остальных мест иногда выбирается шуточная поза сна на голове с ногами под углом. В катсцене есть локальная галочка **«Всегда пропускать»**; она запоминается в пользовательских настройках и автоматически отдаёт голос за пропуск каждой фазы.\n\nНа многоповарской станции клон, чья записанная дорожка уже закончилась раньше общей готовки, переходит только в визуальное ожидание: листает книгу, подсказывает соседу, следит за его действиями или нервно ходит рядом. Это не изменяет модель блюда, длительность записи и работу второго повара.\n'
p.write_text(s)
