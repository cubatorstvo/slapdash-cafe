extends RefCounted
## Deterministic event-driven highlight edit built only from accepted source frames.
const RATIO:=0.30
const FPS:=60.0
const PLAN_VERSION:=2
const MAX_SEGMENTS:=8
const PRE_EVENT_TICKS:=24
const POST_EVENT_TICKS:=48
const FINAL_MAX_TICKS:=120
const QUIET_WINDOW_TICKS:=36
const FUNNY_OBJECTS:=["boot","mug","bolt","tomato"]

static func source_ticks(tracks: Array)->int:
	var longest:=0
	for track in tracks:
		if track is Dictionary: longest=maxi(longest,track.get("frames",[]).size())
	return longest

static func film_ticks(tracks: Array)->int:
	return maxi(1,roundi(source_ticks(tracks)*RATIO)) if source_ticks(tracks)>0 else 0

static func duration(tracks: Array)->float:
	return film_ticks(tracks)/FPS

static func extract_events(tracks: Array)->Array:
	var result: Array=[]
	var total:=source_ticks(tracks)
	for role in range(tracks.size()):
		var track: Variant=tracks[role]
		if not track is Dictionary: continue
		for raw in track.get("events",[]):
			if raw is Dictionary:
				var event: Dictionary=raw.duplicate(true)
				event.tick=clampi(int(event.get("tick",0)),0,maxi(0,total-1))
				event.role=int(event.get("role",role))
				event.kind=str(event.get("kind",_input_kind(event.get("input",{}))))
				event.object=str(event.get("object",_input_object(event.get("input",{}))))
				event.importance=int(event.get("importance",_importance(str(event.kind),str(event.object))))
				result.append(event)
		var frames: Array=track.get("frames",[])
		for tick in range(1,frames.size()):
			if frames[tick-1] is Dictionary and frames[tick] is Dictionary:
				_scan_transition(result,frames[tick-1],frames[tick],tick,role)
	_deduplicate(result)
	result.sort_custom(func(a,b):
		if int(a.importance)!=int(b.importance): return int(a.importance)>int(b.importance)
		if int(a.tick)!=int(b.tick): return int(a.tick)<int(b.tick)
		if str(a.kind)!=str(b.kind): return str(a.kind)<str(b.kind)
		return int(a.role)<int(b.role))
	return result

static func build(tracks: Array, supplied_events: Array=[])->Array:
	var total:=source_ticks(tracks)
	var target:=film_ticks(tracks)
	if total<=0 or target<=0: return []
	var segment_limit: int=_segment_limit(target)
	var events: Array=supplied_events.duplicate(true) if not supplied_events.is_empty() else extract_events(tracks)
	var selected:=PackedByteArray()
	selected.resize(total)
	selected.fill(0)
	var final_length:=maxi(1,mini(target,mini(FINAL_MAX_TICKS,roundi(float(target)*0.20))))
	var selected_count:=_mark_range(selected,maxi(0,total-final_length),total,target)
	var chosen_events: Array=[]
	var kind_counts: Dictionary={}
	for event in events:
		if selected_count>=target or chosen_events.size()>=segment_limit-1: break
		var kind:=str(event.get("kind","action"))
		if int(kind_counts.get(kind,0))>=2 and int(event.get("importance",0))<90: continue
		var tick:=clampi(int(event.get("tick",0)),0,total-1)
		if tick>=total-final_length and int(event.get("importance",0))<100: continue
		var remaining:=target-selected_count
		var wanted:=mini(PRE_EVENT_TICKS+POST_EVENT_TICKS+1,remaining)
		var start:=clampi(tick-mini(PRE_EVENT_TICKS,wanted/3),0,maxi(0,total-wanted))
		var added:=_mark_range(selected,start,mini(total,start+wanted),remaining)
		if added>0:
			selected_count+=added
			chosen_events.append(event)
			kind_counts[kind]=int(kind_counts.get(kind,0))+1
	if selected_count<target:
		var motion:=_motion_candidates(tracks)
		for item in motion:
			if selected_count>=target or _segment_count(selected)>=segment_limit: break
			var remaining:=target-selected_count
			var length:=mini(QUIET_WINDOW_TICKS,remaining)
			var tick:=int(item.tick)
			var start:=clampi(tick-length/2,0,maxi(0,total-length))
			selected_count+=_mark_range(selected,start,start+length,remaining)
	if selected_count<target:
		selected_count+=_expand_selected(selected,target-selected_count)
	if selected_count<target:
		selected_count+=_mark_range(selected,0,total,target-selected_count)
	var ranges:=_ranges(selected)
	var result: Array=[]
	var film_cursor:=0
	for index in range(ranges.size()):
		var pair: Array=ranges[index]
		var start: int=int(pair[0])
		var finish: int=int(pair[1])
		if finish<=start: continue
		var event:=_best_event_for_range(events,start,finish)
		var kind: String="final" if finish==total else str(event.get("kind","motion")) if not event.is_empty() else "motion"
		var camera:=3 if finish==total else _camera_for_kind(kind,index)
		var actual:=finish-start
		result.append({"kind":kind,"camera":camera,"source_start":start,"source_end":finish,"film_start":film_cursor,"film_end":film_cursor+actual,"transition_ticks":mini(6,maxi(0,actual/4)),"event_tick":int(event.get("tick",-1)),"event_role":int(event.get("role",-1)),"event_object":str(event.get("object",""))})
		film_cursor+=actual
	return result

static func _segment_limit(target: int)->int:
	if target<=180: return 2
	if target<720: return 6
	return MAX_SEGMENTS

static func source_tick(segments: Array, film_tick: int)->Dictionary:
	if segments.is_empty(): return {}
	var tick:=maxi(0,film_tick)
	for segment in segments:
		if tick<int(segment.film_end):
			var local:=tick-int(segment.film_start)
			return {"tick":int(segment.source_start)+local,"camera":int(segment.camera),"kind":str(segment.kind),"transition":local<int(segment.get("transition_ticks",0))}
	var last: Dictionary=segments.back()
	return {"tick":maxi(int(last.source_start),int(last.source_end)-1),"camera":int(last.camera),"kind":str(last.kind),"transition":false}

static func camera_pose(type_id: String,index: int)->Dictionary:
	var poses: Array=[]
	match type_id:
		"counter":
			poses=[
				{"position":Vector3(0,3.15,-5.25),"target":Vector3(0,1.05,0.15)},
				{"position":Vector3(0,2.45,-3.15),"target":Vector3(0,1.02,0.30)},
				{"position":Vector3(3.74,2.25,0.25),"target":Vector3(0,1.08,0.25)},
				{"position":Vector3(-3.19,2.05,-3.15),"target":Vector3(0,1.08,0.35)}
			]
		"kitchen":
			poses=[
				{"position":Vector3(0,3.35,-5.55),"target":Vector3(0,1.08,0.18)},
				{"position":Vector3(-0.35,2.55,-3.25),"target":Vector3(-0.25,1.02,0.32)},
				{"position":Vector3(4.25,2.35,0.55),"target":Vector3(-0.35,1.08,0.22)},
				{"position":Vector3(-3.85,2.25,-3.55),"target":Vector3(0.15,1.10,0.38)}
			]
		"grill_kitchen":
			poses=[
				{"position":Vector3(0.35,3.00,-5.35),"target":Vector3(0.20,1.00,0.05)},
				{"position":Vector3(0.45,2.12,-2.85),"target":Vector3(0.10,1.00,0.00)},
				{"position":Vector3(4.15,1.95,-0.15),"target":Vector3(0.05,1.00,0.02)},
				{"position":Vector3(-3.55,2.15,-3.15),"target":Vector3(0.25,1.05,0.30)}
			]
		"solyanka_kitchen":
			poses=[
				{"position":Vector3(0,3.70,-5.95),"target":Vector3(0,1.18,-0.05)},
				{"position":Vector3(0,3.05,-3.65),"target":Vector3(0,1.14,-0.12)},
				{"position":Vector3(4.55,2.85,0.45),"target":Vector3(0,1.16,-0.10)},
				{"position":Vector3(-4.15,2.60,-3.80),"target":Vector3(0,1.18,0.20)}
			]
		_:
			poses=[
				{"position":Vector3(0,3.25,-5.45),"target":Vector3(0,1.05,0.15)},
				{"position":Vector3(0,2.45,-3.10),"target":Vector3(0,1.03,0.25)},
				{"position":Vector3(4.0,2.25,0.25),"target":Vector3(0,1.07,0.20)},
				{"position":Vector3(-3.55,2.15,-3.30),"target":Vector3(0,1.08,0.32)}
			]
	return poses[clampi(index,0,poses.size()-1)]

static func _scan_transition(out: Array, before: Dictionary, after: Dictionary, tick: int, role: int)->void:
	var old_hand:=_hand(before,role)
	var new_hand:=_hand(after,role)
	if old_hand!=new_hand:
		if old_hand.is_empty() and not new_hand.is_empty(): _event(out,tick,"pickup",role,new_hand,62)
		elif not old_hand.is_empty() and new_hand.is_empty(): _event(out,tick,"release",role,old_hand,44)
	var old_using:=_role_bool(before,"using",role)
	var new_using:=_role_bool(after,"using",role)
	if old_using!=new_using: _event(out,tick,"action_start" if new_using else "action_end",role,new_hand if not new_hand.is_empty() else old_hand,68 if new_using else 48)
	var old_pouring:=_role_bool(before,"pouring",role) or bool(before.get("flowing",false)) or bool(before.get("guest_pour",false))
	var new_pouring:=_role_bool(after,"pouring",role) or bool(after.get("flowing",false)) or bool(after.get("guest_pour",false))
	if old_pouring!=new_pouring: _event(out,tick,"pour_start" if new_pouring else "pour_end",role,new_hand if not new_hand.is_empty() else old_hand,78 if new_pouring else 58)
	for key in ["potato_state","sausage_state","meat_state","patty_state"]:
		var old_value: Variant=_deep_value(before,key)
		var new_value: Variant=_deep_value(after,key)
		if old_value!=null and new_value!=null and str(old_value)!=str(new_value):
			var importance:=92 if str(new_value) in ["plate","tray","assembly","eaten"] or str(new_value).begins_with("plate_") else 72
			_event(out,tick,"state_change",role,key.trim_suffix("_state"),importance)
	for key in ["meat_face","patty_face"]:
		var old_face: Variant=_deep_value(before,key)
		var new_face: Variant=_deep_value(after,key)
		if old_face!=null and new_face!=null and int(old_face)!=int(new_face): _event(out,tick,"flip",role,key.trim_suffix("_face"),86)
	var old_falls_value: Variant=_deep_value(before,"falls")
	var new_falls_value: Variant=_deep_value(after,"falls")
	var old_falls:=int(old_falls_value) if old_falls_value!=null else 0
	var new_falls:=int(new_falls_value) if new_falls_value!=null else 0
	if new_falls>old_falls: _event(out,tick,"comic_fall",role,new_hand if not new_hand.is_empty() else old_hand,96)
	var old_tomato: Variant=before.get("tomato",{})
	var new_tomato: Variant=after.get("tomato",{})
	if old_tomato is Dictionary and new_tomato is Dictionary:
		if not bool(old_tomato.get("flying",false)) and bool(new_tomato.get("flying",false)): _event(out,tick,"trick",role,"tomato",100)
		if not bool(old_tomato.get("hit",false)) and bool(new_tomato.get("hit",false)): _event(out,tick,"comic_hit",role,"tomato",105)
	for key in ["served","fire_started","cheese_applied"]:
		var old_flag: Variant=_deep_value(before,key)
		var new_flag: Variant=_deep_value(after,key)
		if old_flag is bool and new_flag is bool and not old_flag and new_flag: _event(out,tick,"serving" if key=="served" else "key_action",role,key,98 if key=="served" else 82)
	var old_dumped: Variant=before.get("dumped",{})
	var new_dumped: Variant=after.get("dumped",{})
	if old_dumped is Dictionary and new_dumped is Dictionary:
		for item in new_dumped:
			if not bool(old_dumped.get(item,false)) and bool(new_dumped.get(item,false)): _event(out,tick,"trick" if str(item) in FUNNY_OBJECTS else "key_action",role,str(item),100 if str(item) in FUNNY_OBJECTS else 76)
	for key in ["filled","sausage_coating","stirred","cooked","bun_toast","sauce_amount","chili_amount","salt_amount","stir_progress","patty_season","meat_salt","pasta_salt","served_pasta"]:
		var old_number:=_number(_deep_value(before,key))
		var new_number:=_number(_deep_value(after,key))
		if new_number>old_number+0.0001:
			if old_number<=0.0001: _event(out,tick,"progress_start",role,key,60)
			if (old_number<1.0 and new_number>=1.0) or (key=="filled" and old_number<200.0 and new_number>=200.0): _event(out,tick,"progress_complete",role,key,80)
	for key in ["meat_sides","patty_sides","potato_heat"]:
		var old_array: Variant=_deep_value(before,key)
		var new_array: Variant=_deep_value(after,key)
		if old_array is Array and new_array is Array:
			for i in range(mini(old_array.size(),new_array.size())):
				if float(old_array[i])<0.999 and float(new_array[i])>=0.999: _event(out,tick,"progress_complete",role,"%s_%d"%[key,i],84)

static func _event(out: Array,tick: int,kind: String,role: int,object: String,importance: int)->void:
	out.append({"tick":tick,"kind":kind,"role":role,"object":object,"importance":importance})

static func _input_kind(input: Variant)->String:
	if not input is Dictionary: return "action"
	if bool(input.get("feed",false)): return "serving"
	if bool(input.get("dump",false)): return "key_action"
	if bool(input.get("drop",false)): return "release"
	if not str(input.get("grab","")).is_empty(): return "pickup"
	return "action"

static func _input_object(input: Variant)->String:
	if not input is Dictionary: return ""
	return str(input.get("grab",input.get("item","")))

static func _importance(kind: String,object: String)->int:
	if kind in ["trick","comic_hit"] or object in FUNNY_OBJECTS: return 100
	if kind in ["serving","comic_fall"]: return 96
	if kind in ["flip","progress_complete","key_action"]: return 82
	if kind in ["pour_start","action_start"]: return 72
	if kind=="pickup": return 62
	return 48

static func _hand(frame: Dictionary,role: int)->String:
	if frame.has("held"): return str(frame.get("held",""))
	if frame.has("hand"): return str(frame.get("hand",""))
	var hands: Variant=frame.get("hands",[])
	if hands is Array and role<hands.size(): return str(hands[role])
	return ""

static func _role_bool(frame: Dictionary,key: String,role: int)->bool:
	var value: Variant=frame.get(key,false)
	if value is Array: return bool(value[role]) if role<value.size() else false
	return bool(value)

static func _deep_value(frame: Dictionary,key: String)->Variant:
	if frame.has(key): return frame[key]
	for nested_key in ["food","tomato"]:
		var nested: Variant=frame.get(nested_key,{})
		if nested is Dictionary and nested.has(key): return nested[key]
	return null

static func _number(value: Variant)->float:
	return float(value) if value is float or value is int else 0.0

static func _deduplicate(events: Array)->void:
	var seen: Dictionary={}
	var unique: Array=[]
	for event in events:
		var key: String="%d|%s|%d|%s"%[int(event.get("tick",0)),str(event.get("kind","")),int(event.get("role",-1)),str(event.get("object",""))]
		if seen.has(key):
			var index:=int(seen[key])
			if int(event.get("importance",0))>int(unique[index].get("importance",0)): unique[index]=event
		else:
			seen[key]=unique.size()
			unique.append(event)
	events.clear()
	events.append_array(unique)

static func _motion_candidates(tracks: Array)->Array:
	var result: Array=[]
	var total:=source_ticks(tracks)
	for tick in range(1,total,6):
		var score:=0.0
		for track in tracks:
			if not track is Dictionary: continue
			var frames: Array=track.get("frames",[])
			if frames.size()<2: continue
			var a: Dictionary=frames[mini(tick-1,frames.size()-1)]
			var b: Dictionary=frames[mini(tick,frames.size()-1)]
			score+=_frame_motion(a,b)
		result.append({"tick":tick,"score":score})
	result.sort_custom(func(a,b): return float(a.score)>float(b.score) if not is_equal_approx(float(a.score),float(b.score)) else int(a.tick)<int(b.tick))
	return result

static func _frame_motion(a: Dictionary,b: Dictionary)->float:
	var score:=0.0
	for key in ["jug","cup","rag","potato","sausage","actor_position"]:
		score+=_point_distance(a.get(key,null),b.get(key,null))
	var pa: Variant=a.get("positions",{})
	var pb: Variant=b.get("positions",{})
	if pa is Dictionary and pb is Dictionary:
		for key in pa:
			if pb.has(key): score+=_point_distance(pa[key],pb[key])
	return score

static func _point_distance(a: Variant,b: Variant)->float:
	if not a is Array or not b is Array or a.size()!=b.size() or a.size()<2: return 0.0
	var sum:=0.0
	for i in range(a.size()):
		if (a[i] is float or a[i] is int) and (b[i] is float or b[i] is int): sum+=pow(float(a[i])-float(b[i]),2)
	return sqrt(sum)

static func _mark_range(selected: PackedByteArray,start: int,finish: int,limit: int)->int:
	var added:=0
	for tick in range(clampi(start,0,selected.size()),clampi(finish,0,selected.size())):
		if added>=limit: break
		if selected[tick]==0:
			selected[tick]=1
			added+=1
	return added

static func _expand_selected(selected: PackedByteArray,need: int)->int:
	var added:=0
	while added<need:
		var changed:=false
		for tick in range(selected.size()):
			if selected[tick]!=0: continue
			if (tick>0 and selected[tick-1]!=0) or (tick+1<selected.size() and selected[tick+1]!=0):
				selected[tick]=1
				added+=1
				changed=true
				if added>=need: break
		if not changed: break
	return added

static func _ranges(selected: PackedByteArray)->Array:
	var result: Array=[]
	var start:=-1
	for tick in range(selected.size()+1):
		var on:=tick<selected.size() and selected[tick]!=0
		if on and start<0: start=tick
		elif not on and start>=0:
			result.append([start,tick])
			start=-1
	return result

static func _segment_count(selected: PackedByteArray)->int:
	return _ranges(selected).size()

static func _best_event_for_range(events: Array,start: int,finish: int)->Dictionary:
	var best: Dictionary={}
	for event in events:
		var tick:=int(event.get("tick",-1))
		if tick<start or tick>=finish: continue
		if best.is_empty() or int(event.get("importance",0))>int(best.get("importance",0)) or (int(event.get("importance",0))==int(best.get("importance",0)) and tick<int(best.get("tick",0))): best=event
	return best

static func _camera_for_kind(kind: String,index: int)->int:
	if kind in ["trick","comic_hit","comic_fall","flip"]: return 2
	if kind in ["pour_start","pour_end","progress_start","progress_complete","action_start","action_end","key_action"]: return 1
	if kind in ["serving","final"]: return 3
	return index%3
