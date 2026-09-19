extends RefCounted
## Prepared production slots for the original cafe plus three repeatable expansion sections.
const SLOT_COUNT:=20
const BASE_SLOT_COUNT:=6
const HALL_X_MAX:=54.0
const SECTION_ROWS: Array=[
	{"name":"Секция A","z":-4.15,"slots":[6,7,8,9,10]},
	{"name":"Секция B","z":1.75,"slots":[11,12,13,14,15]},
	{"name":"Секция C","z":7.65,"slots":[16,17,18,19]}
]
const EXTRA_X: Array=[21.4,28.6,35.8,43.0,50.2]

static func position(slot_index: int)->Vector3:
	if slot_index==4: return Vector3(10.2,0,4.75)
	if slot_index==5: return Vector3(3.2,0,4.75)
	if slot_index<4:
		var width:=6.6*4+0.6*3
		var first:=3.0-width/2.0+6.6/2.0
		return Vector3(first+slot_index*7.2,0,-1.4)
	var extra:=slot_index-6
	var row:=int(extra/5)
	var col:=extra%5
	var z:=float(SECTION_ROWS[mini(row,SECTION_ROWS.size()-1)].z)
	return Vector3(float(EXTRA_X[col]),0,z)

static func section_for(slot_index: int)->String:
	if slot_index<BASE_SLOT_COUNT: return "Основной зал"
	for section in SECTION_ROWS:
		if slot_index in section.slots: return str(section.name)
	return "Расширение"

static func free_slot_ids(service: Node)->Array:
	var result: Array=[]
	for slot in range(1,SLOT_COUNT):
		if service.by_id(slot+1)==null: result.append(slot+1)
	return result

static func slot_label(station_id: int)->String:
	var slot:=station_id-1
	return "%s · место %d"%[section_for(slot),station_id]
