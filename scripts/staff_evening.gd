extends Node3D
## Deterministic, cosmetic celebration; no movement or hats enter cooking recordings.
const Avatar=preload("res://scripts/cook_avatar.gd")
const Props=preload("res://scripts/props.gd")
var game: Node3D
var performers := {}

func setup(owner_game: Node3D) -> void: game=owner_game

func _process(_delta: float) -> void:
	if game==null: return
	if game.service.progress.shift!="night":
		for entry in performers.values(): entry.actor.queue_free(); entry.hat.queue_free()
		performers.clear()
		return
	for station in game.service.stations:
		if station.manual_station: continue
		for role in range(station.role_count() if station.staffed<0 else station.staffed):
			var id: int=station.station_id*4+role
			if not performers.has(id):
				var actor:=Avatar.new(); add_child(actor)
				actor.caption.text=station.crew[role].name+" · смена закончилась!"
				var hat:=Node3D.new(); add_child(hat)
				Props.cylinder(hat,0.26,0.22,Vector3.ZERO,Color("fff0cb"))
				Props.cylinder(hat,0.29,0.04,Vector3(0,-0.09,0),Color("eee0b6"))
				performers[id]={"actor":actor,"hat":hat}
			var entry: Dictionary=performers[id]
			var actor: Node3D=entry.actor
			var hat: Node3D=entry.hat
			var t:=maxf(0,game.service.progress.night_elapsed-(id%4)*0.18)
			var variant:=id%3
			var home: Vector3=station.to_global(Vector3((-1.35 if role==0 else 1.35) if station.role_count()==2 else 0,0,1.85))
			var side: float=station.global_position.x-3.12
			var route: Array=[home,Vector3(side,0,home.z),Vector3(side,0,4.8),Vector3(5,0,4.8),Vector3(5,0,10.12)]
			var speed: float=[3.6,4.6,2.9][variant]
			var distance:=maxf(0,t-0.85)*speed
			var point:=home
			var direction:=Vector3.BACK
			var done:=false
			for i in range(1,route.size()):
				var segment: Vector3=route[i]-route[i-1]
				if distance<=segment.length(): point=route[i-1]+segment.normalized()*distance; direction=segment; break
				distance-=segment.length(); point=route[i]
				if i==route.size()-1: done=true
			actor.visible=not done and not station.training.active()
			actor.position=point
			actor.rotation.y=atan2(-direction.x,-direction.z)
			actor.celebrate(t,variant,t<0.85)
			actor.hat.visible=t<0.42
			hat.visible=t>=0.42 and not station.training.active()
			var ht:=clampf(t-0.42,0,1.25)
			hat.position=home+Vector3(sin(id*2.7)*ht*1.6,maxf(0.12,1.8+2.2*ht-3.0*ht*ht),cos(id*2.7)*ht*1.5)
			hat.rotation=Vector3(ht*5,ht*3,ht*4)
			if t>1.67: hat.position.y=0.12
