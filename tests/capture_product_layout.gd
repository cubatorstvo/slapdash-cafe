extends SceneTree
const Expansion=preload("res://scripts/cafe_expansion_layout.gd")
const TYPES=["counter","kitchen","grill_kitchen","solyanka_kitchen"]

func _initialize()->void:
	run.call_deferred()

func settle(frames:=8)->void:
	for _i in range(frames): await process_frame

func set_stage(game: Node3D,stage: int)->void:
	var p=game.service.progress
	p.stars=0 if stage==1 else stage
	p.expanded=stage>=3
	p.specialized_expanded=stage>=3
	p.orchestration_expanded=stage>=4
	p.lab_tier=clampi(stage-1,0,2)
	p.lounge_tier=clampi(stage-2,0,2)
	game.service.clear_world()
	for slot in range(Expansion.SLOT_COUNT):
		if not Expansion.slot_available(slot,stage): continue
		game.service.add_station(TYPES[slot%TYPES.size()],slot,slot==0,true)
	game._refresh_cafe_layout(true)
	game.development.refresh()

func shot(game: Node3D,name: String,position: Vector3,target: Vector3)->void:
	game.camera.global_position=position
	game.camera.look_at(target,Vector3.UP)
	await settle(4)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/sol-layout-"+name+".png")

func run()->void:
	root.size=Vector2i(1440,900)
	var game=preload("res://scenes/cafe.tscn").instantiate()
	root.add_child(game)
	await settle()
	game.set_physics_process(false)
	game.hud.hide()
	game.menu.close()
	game.cookbook.close()
	game.office.close()
	set_stage(game,1)
	await settle()
	await shot(game,"stage1-overview",Vector3(0,22,-17),Vector3(0,1.2,5))
	set_stage(game,4)
	await settle()
	await shot(game,"stage4-overview",Vector3(0,48,-42),Vector3(0,0,-4))
	await shot(game,"stage4-entrance",Vector3(0,3.0,-20.5),Vector3(0,1.5,7.0))
	await shot(game,"stage4-left",Vector3(-30,18,-4),Vector3(0,1,-4))
	await shot(game,"stage4-rear",Vector3(0,18,18.5),Vector3(0,1,-7))
	game._shutdown_tree(game)
	game.free()
	await process_frame
	quit()
