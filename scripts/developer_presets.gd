extends RefCounted

const Progression = preload("res://scripts/cafe_progression.gd")
const Definition = preload("res://scripts/station_definition.gd")

const CASH := 10000
const PRESETS := {
	0: {"popularity":0,"manual_served":0,"lab_tier":0,"lab_upgrades":[],"lounge_tier":0,"stations":[]},
	1: {"popularity":20,"manual_served":15,"lab_tier":0,"lab_upgrades":["lab_chair","lab_lamps"],"lounge_tier":0,"stations":[["counter",1]]},
	2: {"popularity":40,"manual_served":30,"lab_tier":1,"lab_upgrades":["lab_chair","lab_cal_focus","lab_lamps","lab_feeder","lab_irrigation","lab_planter","lab_rack"],"lounge_tier":1,"stations":[["counter",1],["counter",2],["kitchen",3]]},
	3: {"popularity":70,"manual_served":50,"lab_tier":2,"lab_upgrades":["lab_power","lab_power_2","lab_valve","lab_damper","lab_chair","lab_cal_focus","lab_cal_slow","lab_cal_auto","lab_lamps","lab_feeder","lab_irrigation","lab_planter","lab_extractor","lab_nutrients","lab_climate","lab_rack","lab_rack_2"],"lounge_tier":2,"stations":[["counter",1],["counter",2],["counter",3],["counter",4],["kitchen",6],["kitchen",7],["grill_kitchen",8]]},
	4: {"popularity":100,"manual_served":80,"lab_tier":2,"lab_upgrades":["lab_power","lab_power_2","lab_power_3","lab_valve","lab_damper","lab_feeder","lab_irrigation","lab_planter","lab_extractor","lab_production","lab_lamps","lab_nutrients","lab_climate","lab_rack","lab_rack_2","lab_chair","lab_cal_focus","lab_cal_slow","lab_cal_auto","lab_cal_speed"],"lounge_tier":2,"stations":[["counter",1],["counter",2],["counter",3],["counter",4],["counter",5],["counter",6],["kitchen",7],["kitchen",8],["kitchen",9],["kitchen",10],["grill_kitchen",11],["grill_kitchen",12],["solyanka_kitchen",13]]}
}

static func label(stage: int) -> String:
	match stage:
		0: return "0 ★ · старт"
		1: return "1 ★ · 1 стойка"
		2: return "2 ★ · 2 стойки + 1 парная кухня"
		3: return "3 ★ · больше столов + развитая лаборатория"
		4: return "4 ★ · много столов + максимальная лаборатория"
	return "%d ★" % stage

static func apply(game: Node, requested_stage: int) -> void:
	var stage := clampi(requested_stage, 0, 4)
	var service = game.service
	service.clear_world()
	service.progress = Progression.new()
	var p = service.progress
	var preset: Dictionary = PRESETS[stage]
	p.cash = CASH
	p.stars = stage
	p.popularity = int(preset.popularity)
	p.manual_served = int(preset.manual_served)
	p.day = 1 + stage * 3
	p.shift = "morning"
	p.lab_stage = 0 if stage == 0 else 3
	p.lab_step = -1
	p.lab_tier = int(preset.lab_tier)
	p.lab_upgrades = preset.lab_upgrades.duplicate()
	p.lab_auto_calibration = stage >= 4
	p.lab_production = {"enabled":stage >= 4,"target":6 if stage >= 4 else 2,"reserve":150}
	p.lounge_tier = int(preset.lounge_tier)
	p.expanded = stage >= 2
	p.specialized_expanded = stage >= 3
	p.orchestration_expanded = stage >= 4
	p.cafe_inaugurated = stage >= 1
	p.starter_reward = stage >= 1
	p.garland_owned = stage >= 2
	p.garland_complete = stage >= 2
	p.decorations = ["sign"] if stage == 1 else ["sign","lights"] if stage == 2 else ["sign","lights","plants"] if stage >= 3 else []
	p.journey_auto_served = 0 if stage < 2 else 12 * stage
	p.third_star_auto_served = 0 if stage < 3 else 10
	p.fourth_star_auto_served = 0 if stage < 4 else 14
	p.fourth_star_specialty_served = 0 if stage < 4 else 6
	service.initial_stations()
	var required_workers := 0
	for station_spec in preset.stations:
		var type_id := str(station_spec[0])
		var slot_index := int(station_spec[1])
		var station = service.add_station(type_id, slot_index, false, false)
		station.staffed = 0
		station.equipment = Definition.equipment_for_type(type_id)
		station.apply_equipment()
		required_workers += station.role_count()
	p.free_workers.clear()
	p.next_clone_id = 1
	for index in range(required_workers):
		p.free_workers.append({"id":p.next_clone_id,"tempo":1.0 + 0.05 * mini(stage, 4),"rest":1.0})
		p.next_clone_id += 1
	p.free_clones = p.free_workers.size()
	service.assign_clones()
	service.open_for_business = false
	service._refresh_progression()
	if is_instance_valid(game.laboratory): game.laboratory.recover()
	game._refresh_cafe_layout(true)
	if is_instance_valid(game.development): game.development.refresh()
	game.save_cafe()
