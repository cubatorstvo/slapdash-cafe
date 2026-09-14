from pathlib import Path

p=Path('scripts/cafe.gd')
s=p.read_text()
s=s.replace('var local_role := -1\nvar grip := Vector3.FORWARD','var local_role := -1\nvar sleep_bed_bound := -1\nvar grip := Vector3.FORWARD')
s=s.replace('func _unhandled_input(event: InputEvent) -> void:\n\tif is_instance_valid(steam) and steam.overlay_open: return\n', '''func _unhandled_input(event: InputEvent) -> void:\n\tif is_instance_valid(steam) and steam.overlay_open: return\n\tif is_instance_valid(session) and session.local_sleeping():\n\t\tif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:\n\t\t\tsession.request_action({"action":"wake"})\n\t\treturn\n''')
old='''func _physics_process(delta: float) -> void:\n\tbind_training()\n\tif cookbook.opened and (menu.opened() or awaiting_serving_confirmation()): cookbook.close()\n\tif session_paused and not session.online(): return\n\tvar move := Vector2.ZERO if input_blocked() else Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))\n\tif not awaiting_serving_confirmation(): player.advance(delta, move.limit_length())\n'''
new='''func sync_sleep_pose() -> void:\n\tvar bed: int = session.local_sleep_bed() if is_instance_valid(session) else -1\n\tif bed >= 0:\n\t\tif sleep_bed_bound != bed:\n\t\t\tplayer.enter_sleep(Annex.player_sleep_position(bed),Annex.player_sleep_yaw(bed))\n\t\t\tsleep_bed_bound = bed\n\telif sleep_bed_bound >= 0:\n\t\tvar previous_bed := sleep_bed_bound\n\t\tsleep_bed_bound = -1\n\t\tplayer.exit_sleep(Annex.player_bed_exit(previous_bed))\n\nfunc _physics_process(delta: float) -> void:\n\tbind_training()\n\tsync_sleep_pose()\n\tif cookbook.opened and (menu.opened() or awaiting_serving_confirmation()): cookbook.close()\n\tif session_paused and not session.online(): return\n\tvar move := Vector2.ZERO if input_blocked() or session.local_sleeping() else Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))\n\tif not awaiting_serving_confirmation() and not session.local_sleeping(): player.advance(delta, move.limit_length())\n'''
if old not in s: raise SystemExit('physics block not found')
s=s.replace(old,new,1)
s=s.replace('hud.crosshair.visible = not cookbook.opened and not menu.opened() and not office.opened()','hud.crosshair.visible = not cookbook.opened and not menu.opened() and not office.opened() and not session.local_sleeping()')
old='''\thud.prompt.text = ""\n\thud.recipe_panel.hide()\n\tif not taught.book and not cookbook.opened: hud.prompt.text = "B · Книга"\n'''
new='''\thud.prompt.text = ""\n\thud.recipe_panel.hide()\n\tif session.local_sleeping():\n\t\thud.goal.text = "Сон · ожидание остальных игроков"\n\t\thud.prompt.text = session.sleep_status_text() + " · E встать"\n\t\treturn\n\tif not taught.book and not cookbook.opened: hud.prompt.text = "B · Книга"\n'''
if old not in s: raise SystemExit('hud block not found')
s=s.replace(old,new,1)
s=s.replace('''\tProps.solid_box(self, Vector3(30, 4.7, 0.18), Vector3(3, 2.3, -7.6), Color("244c50"))\n\tProps.solid_box(self, Vector3(30, 4.7, 0.18), Vector3(3, 2.3, 10.6), Color("244c50"))\n\tProps.solid_box(self, Vector3(0.18, 4.7, 18.2), Vector3(17.8, 2.3, 1.5), Color("2e5355"))\n\tAnnex.build_shell(self)\n''','''\tProps.solid_box(self, Vector3(30, 4.7, 0.18), Vector3(3, 2.3, -7.6), Color("244c50"))\n\tfor x in [-11.8,17.8]: Props.solid_box(self, Vector3(0.18, 4.7, 18.2), Vector3(x, 2.3, 1.5), Color("2e5355"))\n\tAnnex.build_shell(self)\n''',1)
s=s.replace('''func new_cafe() -> void:\n\tlaboratory.reset()\n''','''func new_cafe() -> void:\n\tif is_instance_valid(session): session.clear_sleeping()\n\tlaboratory.reset()\n''',1)
old='''func interaction_target() -> Dictionary:\n\tif is_instance_valid(shop):\n\t\tvar target: Dictionary = shop.target(camera,session.local_id())\n\t\tif not target.is_empty(): return target\n\tvar night: Dictionary = development.night_target(camera)\n\treturn night if night.get("action", "") == "next_day" else {}\n'''
new='''func interaction_target() -> Dictionary:\n\tif is_instance_valid(annex):\n\t\tvar sleep_target: Dictionary = annex.sleep_target(camera,session.local_id())\n\t\tif not sleep_target.is_empty(): return sleep_target\n\tif is_instance_valid(shop):\n\t\tvar target: Dictionary = shop.target(camera,session.local_id())\n\t\tif not target.is_empty(): return target\n\tvar night: Dictionary = development.night_target(camera)\n\treturn night if night.get("action", "") == "next_day" else {}\n'''
if old not in s: raise SystemExit('interaction target block not found')
s=s.replace(old,new,1)
p.write_text(s)

p=Path('scripts/cafe_annex.gd')
s=p.read_text()
s=s.replace('var occupant := game.session.sleeping_peer_for_bed(index)','var occupant: int = int(game.session.sleeping_peer_for_bed(index))')
s=s.replace('''\tif "book" in actor and actor.book: actor.book.set_reading(false)\n\tif "notebook" in actor and actor.notebook: actor.notebook.hide()\n\tif "head" in actor and actor.head: actor.head.rotation=Vector3.ZERO\n\tif "legs" in actor:\n\t\tfor leg in actor.legs: leg.rotation.x=0\n''','''\tactor.book.set_reading(false)\n\tactor.notebook.hide()\n\tactor.head.rotation=Vector3.ZERO\n\tfor leg in actor.legs: leg.rotation.x=0\n''')
p.write_text(s)

p=Path('scripts/cafe_development_view.gd')
s=p.read_text()
old='''\tvar sleep_control := Props.box(self,Vector3(0.58,0.18,0.42),Annex.PLAYER_SLEEP_POINT,Color("d8c998"))\n\tnight_controls.append({"node": sleep_control, "action": "next_day", "hint": "(E) Отдохнуть до утра"})\n\tvar sleep_label := Props.text(self,"ОТДОХНУТЬ ДО УТРА",Annex.PLAYER_SLEEP_POINT+Vector3(0,0.55,0),18,Color("e7c891"))\n\tsleep_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED\n\tsleep_label.pixel_size = 0.004\n'''
if old not in s: raise SystemExit('old sleep control not found')
s=s.replace(old,'',1)
p.write_text(s)

p=Path('scripts/cafe_service.gd')
s=p.read_text()
s=s.replace('announce("Смена закончена. Отдохни у двери, чтобы начать следующий день.")','announce("Смена закончена. Ляг на свободную кровать в комнате отдыха.")')
s=s.replace('announce("Смена закончена. Клоны бегут в комнату отдыха; посмотри, как устроились, или сразу начинай новый день.")','announce("Смена закончена. Клоны бегут в комнату отдыха. Новый день начнётся, когда все игроки лягут спать.")')
p.write_text(s)

p=Path('docs/LABORATORY_AND_RECIPE_BOOK.md')
s=p.read_text()
s=s.replace('Лаборатория и комната отдыха находятся в отдельных комнатах внешнего пристроя, физически соединённого с кафе. Переход бесшовный, без загрузки другой сцены. Двери в обе комнаты раздвигаются автоматически при приближении игрока или клона.','Лаборатория и увеличенная комната отдыха находятся за задней стеной кафе, напротив поварских станций. Переход бесшовный, без загрузки другой сцены. Двери в обе комнаты раздвигаются автоматически при приближении игрока или клона. В комнате отдыха есть отдельные кровати для игроков: ночью игрок ложится на кровать, а в мультиплеере следующий день начинается только когда спят все подключённые игроки; ожидающий игрок может встать клавишей E.')
p.write_text(s)
