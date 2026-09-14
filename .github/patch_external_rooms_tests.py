from pathlib import Path

p=Path('tests/test_clone_laboratory.gd')
s=p.read_text()
s=s.replace('game.player.position=Vector3(0,0.02,7)','game.player.global_position=lab.operator_position()')
s=s.replace('game.session.player_poses[7]={"position":[0,0.02,7]}','var remote_lab_position: Vector3=lab.operator_position()\n\tgame.session.player_poses[7]={"position":[remote_lab_position.x,remote_lab_position.y,remote_lab_position.z]}')
p.write_text(s)

p=Path('tests/test_cafe_life.gd')
s=p.read_text()
old='game.player.position=Vector3(0,0.02,7)\n\tvar lab=game.laboratory'
new='var lab=game.laboratory\n\tgame.player.global_position=lab.operator_position()'
if old not in s: raise SystemExit('lab position block missing in cafe_life')
p.write_text(s.replace(old,new,1))

Path('tests/test_cafe_annex.gd').write_text('''extends SceneTree\nconst Annex=preload("res://scripts/cafe_annex.gd")\nvar failures:=0\nfunc _initialize() -> void: run.call_deferred()\nfunc check(ok: bool, text: String) -> void:\n\tif not ok: failures+=1; printerr("FAIL: ",text)\nfunc run() -> void:\n\tvar game=preload("res://scenes/cafe.tscn").instantiate(); root.add_child(game); await process_frame\n\tgame.set_physics_process(false)\n\tvar lab=game.laboratory\n\tvar operator: Vector3=lab.operator_position()\n\tcheck(operator.x<Annex.CAFE_WEST_X-1.0,"Laboratory operator stands outside original cafe footprint")\n\tcheck(lab.inside(operator),"Moved laboratory interaction volume follows transform")\n\tcheck(game.shop.lab_position(1).x<Annex.CAFE_WEST_X,"Laboratory deliveries target annex")\n\tcheck(Annex.rest_spot(0).position.x<Annex.CAFE_WEST_X,"Rest spots are outside original cafe footprint")\n\tcheck(absf(Annex.rest_spot(0).position.z-Annex.REST_DOOR_Z)<3.0,"Rest spots belong to rest room")\n\tgame.player.global_position=Annex.REST_DOOR_CAFE\n\tgame.annex.advance_doors(0.30)\n\tcheck(game.annex.door_openness("rest")>0.9,"Rest door opens for approaching player")\n\tgame.player.global_position=Vector3(0,0,0)\n\tfor i in range(8): game.annex.advance_doors(0.25)\n\tcheck(game.annex.door_openness("rest")<0.1,"Rest door closes after player leaves")\n\tvar clone:=Node3D.new(); game.add_child(clone); clone.add_to_group("automatic_door_actor"); clone.global_position=Annex.LAB_DOOR_ROOM\n\tgame.annex.advance_doors(0.30)\n\tcheck(game.annex.door_openness("lab")>0.9,"Laboratory door opens for approaching clone")\n\tclone.queue_free()\n\tvar station=game.service.add_station("counter",1,false,true)\n\tgame.service.progress.stars=1; game.service.progress.lab_stage=3\n\tgame.service.create_clone(1.0,true)\n\tgame.service.progress.shift="night"; game.service.progress.night_elapsed=25.0\n\tgame.evening._process(1.0/60.0)\n\tcheck(game.evening.performers.size()==1,"Night worker gets an external rest route")\n\tif game.evening.performers.size()==1:\n\t\tvar performer: Dictionary=game.evening.performers.values()[0]\n\t\tcheck(performer.actor.global_position.x<Annex.CAFE_WEST_X,"Night worker settles outside cafe in rest room")\n\t\tcheck("Отдых" in performer.actor.caption.text,"Settled worker exposes rest quality")\n\tvar planned: Array=game.evening.route_for({"home":station.global_position,"from_lab":false},Annex.rest_spot(0).position)\n\tcheck(Annex.REST_DOOR_CAFE in planned and Annex.REST_DOOR_ROOM in planned,"Night route explicitly crosses automatic rest door")\n\tgame._shutdown_tree(game); game.free()\n\tprint("PASS: external annex geometry, transformed lab targets, proximity doors and night route" if failures==0 else "FAILURES: %d"%failures)\n\tquit(0 if failures==0 else 1)\n''')

p=Path('docs/LABORATORY_AND_RECIPE_BOOK.md')
s=p.read_text()
marker='## Асинхронное выращивание и отдых'
if marker in s and 'внешнем пристрое' not in s:
    insert='\n\nЛаборатория и комната отдыха находятся в отдельных комнатах внешнего пристроя, физически соединённого с кафе. Переход бесшовный, без загрузки другой сцены. Двери в обе комнаты раздвигаются автоматически при приближении игрока или клона.'
    pos=s.index(marker)+len(marker)
    s=s[:pos]+insert+s[pos:]
    p.write_text(s)
