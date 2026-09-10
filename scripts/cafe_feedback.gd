extends Node
const SOUNDS := {"bell": preload("res://assets/audio/bell.wav"), "ready": preload("res://assets/audio/ready.wav"), "place": preload("res://assets/audio/place.wav"), "page": preload("res://assets/audio/page.wav"), "click": preload("res://assets/audio/click.wav"), "pour": preload("res://assets/audio/pour.wav"), "fry": preload("res://assets/audio/fry.wav"), "salt": preload("res://assets/audio/salt.wav")}
var game: Node3D
var states := {}
var audio_nodes := {}

func play_ui(sound: String) -> void:
	var voice := AudioStreamPlayer.new()
	add_child(voice)
	voice.stream = SOUNDS[sound]
	voice.volume_db = -6
	voice.finished.connect(voice.queue_free)
	voice.play()

func voice_at(station: Node3D, sound: String) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	station.add_child(voice)
	voice.position = station.bell.position if sound == "bell" else Vector3(0,1.2,0)
	voice.max_distance = 9
	voice.unit_size = 2
	voice.volume_db = -7 if sound == "bell" else -15
	voice.stream = SOUNDS[sound]
	return voice

func one_shot(station: Node3D, sound: String) -> void:
	var voice := voice_at(station,sound)
	voice.finished.connect(voice.queue_free)
	voice.play()

func announce(station: Node3D, message: String, point: Vector3) -> void:
	one_shot(station, "ready")
	station.pulse_at(point)
	if station == game.local_station(): game.hud.show_toast(message)

func update(_delta: float) -> void:
	var existing: Array = []
	for station in game.service.stations:
		existing.append(station.station_id)
		if not audio_nodes.has(station.station_id) or not is_instance_valid(audio_nodes[station.station_id].pour):
			var loops := {}
			for kind in ["pour","fry"]:
				var voice := voice_at(station,kind)
				var stream: AudioStreamWAV = SOUNDS[kind].duplicate()
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
				stream.loop_end = stream.data.size()/2
				voice.stream = stream
				voice.volume_db = -24
				loops[kind] = voice
			audio_nodes[station.station_id] = loops
			states.erase(station.station_id)
		var m = station.model
		var current := {"faces": [], "wine_ok": false, "coated": false, "served": 0, "bell": station.bell_count(), "held": "", "cooked": false, "sides": 0}
		var pour := false
		var fry := false
		var active: bool = station.training.phase == "recording" or station.state == "cooking"
		if station.type_id == "counter":
			m._store_food("potato")
			for p in m.potatoes:
				var count := 0
				for h in p.potato_heat:
					if h >= 0.999: count += 1
				current.faces.append(count)
				fry = fry or p.potato_state == "pan"
			current.wine_ok = m.filled >= 200 and m.filled <= 250
			current.coated = m.sausage_coating >= 0.9
			current.held = m.held
			pour = m.flowing or m.squeezing
		else:
			current.cooked = m.cooked >= 0.999
			for side in m.meat_sides:
				if side >= 0.999: current.sides += 1
			current.held = str(m.hands)
			fry = m.meat_state == "grill" or (m.temperature >= 99 and m.water > 0)
			pour = true in m.pouring
		for component in m.quality().components:
			if component.served: current.served += 1
		var previous: Dictionary = states.get(station.station_id,current)
		if current.bell > previous.bell:
			one_shot(station,"bell")
			station.bell_flash = 0.35
		if active:
			if station.type_id == "counter":
				for i in range(current.faces.size()):
					if i < previous.faces.size() and current.faces[i] > previous.faces[i]: announce(station,"Сторона готова · %d/6" % current.faces[i],Vector3(m.potatoes[i].potato.x,1.3,m.potatoes[i].potato.y))
				if current.wine_ok and not previous.wine_ok: announce(station,"Вина достаточно",Vector3(m.cup.x,1.5,m.cup.y))
				if current.coated and not previous.coated: announce(station,"Соуса достаточно",Vector3(m.sausage.x,1.2,m.sausage.y))
			elif current.sides > previous.sides: announce(station,"Сторона стейка готова",Vector3(-1.4,1.2,-0.15))
			if current.cooked and not previous.cooked: announce(station,"Макароны сварились",Vector3(1.4,1.3,-0.15))
			if current.served > previous.served: announce(station,"На подаче!",Vector3(0.7,1.1,0.65))
			if current.held != previous.held: one_shot(station,"place")
		for kind in ["pour","fry"]:
			var voice: AudioStreamPlayer3D = audio_nodes[station.station_id][kind]
			var wanted: bool = active and (pour if kind == "pour" else fry)
			if wanted and not voice.playing: voice.play()
			elif not wanted and voice.playing: voice.stop()
		states[station.station_id] = current
	for id in states.keys():
		if id not in existing: states.erase(id); audio_nodes.erase(id)
