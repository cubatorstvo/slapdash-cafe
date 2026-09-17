extends Node3D
const Journey=preload("res://scripts/cafe_journey.gd")
const Lab=preload("res://scripts/laboratory_layout.gd")
const Lounge=preload("res://scripts/lounge_layout.gd")
var game: Node3D
var marker: Label3D
var clock := 0.0

func _ready() -> void:
	marker=Label3D.new(); add_child(marker)
	marker.font_size=26; marker.pixel_size=0.003
	marker.modulate=Color("e8c77f"); marker.outline_size=8
	marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED

func _process(delta: float) -> void:
	if game==null: return
	var p=game.service.progress
	visible=game.journey_markers and p.stars<2 and not game.input_blocked() and game.local_station()==null
	if not visible: return
	clock+=delta
	var next:=Journey.current(p,game.service.stations,game.service.served,game.service.open_for_business)
	var point:=Vector3.ZERO
	var name: String=""
	match str(next.place):
		"computer": point=game.shop.computer.global_position+Vector3.UP*1.2; name="Компьютер"
		"station":
			var station=game.service.by_id(int(next.station))
			if station==null: hide(); return
			point=station.global_position+Vector3.UP*2.4; name="Станция %d"%next.station
		"laboratory": point=game.laboratory.operator_position()+Vector3.UP*2.0; name="Стол исследования"
		"sample": point=game.laboratory.to_global(game.laboratory.SAMPLE)+Vector3.UP*0.7; name="Образец"
		"microscope": point=Lab.MICROSCOPE+Vector3.UP*2.1; name="Микроскоп"
		"pot": point=Lab.pot_point(int(next.pot))+Vector3.UP*2.5; name="Горшок %d"%(int(next.pot)+1)
		"bed": point=Lounge.bed_center(p.lounge_tier)+Vector3.UP*2; name="Шеф-кровать"
		"delivery":
			var parcel:=Journey.pending(p,str(next.item),int(next.station))
			if parcel.is_empty(): hide(); return
			if int(parcel.owner)>0:
				point=game.shop.installation_position(parcel)+Vector3.UP; name="Установить"
			else:
				point=Vector3(parcel.position[0],parcel.position[1],parcel.position[2])+Vector3.UP*1.2; name="Доставка"
		_: hide(); return
	global_position=point+Vector3.UP*sin(clock*2)*0.10
	marker.text="↓ "+name
	visible=game.camera.global_position.distance_to(point)>2.1
