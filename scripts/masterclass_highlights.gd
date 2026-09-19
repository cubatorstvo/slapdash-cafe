extends RefCounted
## Deterministic highlight edit built only from accepted source frames.
const RATIO:=0.30
const FPS:=60.0
const ANGLES:=["wide","worktop","side","final"]

static func source_ticks(tracks: Array)->int:
	var longest:=0
	for track in tracks:
		if track is Dictionary: longest=maxi(longest,track.get("frames",[]).size())
	return longest

static func film_ticks(tracks: Array)->int:
	return maxi(1,roundi(source_ticks(tracks)*RATIO)) if source_ticks(tracks)>0 else 0

static func duration(tracks: Array)->float:
	return film_ticks(tracks)/FPS

static func build(tracks: Array)->Array:
	var total:=source_ticks(tracks)
	var target:=film_ticks(tracks)
	if total<=0 or target<=0: return []
	var count:=mini(4,target)
	var lengths: Array=[]
	var base:=target/count
	var remainder:=target%count
	for i in range(count): lengths.append(base+(1 if i<remainder else 0))
	var centers: Array=[0.16,0.42,0.68,0.91]
	var result: Array=[]
	var film_cursor:=0
	var previous_end:=0
	for i in range(count):
		var length: int=int(lengths[i])
		var desired:=roundi(float(total-1)*float(centers[i]))
		var start:=clampi(desired-length/2,0,maxi(0,total-length))
		if start<previous_end and previous_end+length<=total: start=previous_end
		var finish:=mini(total,start+length)
		if finish-start<length:
			start=maxi(0,finish-length)
		var actual:=finish-start
		result.append({"kind":ANGLES[i],"camera":i,"source_start":start,"source_end":finish,"film_start":film_cursor,"film_end":film_cursor+actual,"transition_ticks":mini(6,maxi(0,actual/4))})
		film_cursor+=actual
		previous_end=finish
	# Any rounding/overlap correction is repaired on the final source segment.
	if film_cursor<target:
		var need:=target-film_cursor
		var start:=maxi(0,total-need)
		result.append({"kind":"final","camera":3,"source_start":start,"source_end":total,"film_start":film_cursor,"film_end":target,"transition_ticks":mini(6,maxi(0,need/4))})
		film_cursor=target
	if film_cursor>target:
		var excess:=film_cursor-target
		var last: Dictionary=result.back()
		last.source_end-=excess
		last.film_end=target
		result[result.size()-1]=last
	return result

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
	var width:=5.5 if type_id=="counter" else 6.1
	var poses: Array=[
		{"position":Vector3(0,3.15,-5.25),"target":Vector3(0,1.05,0.15)},
		{"position":Vector3(0,2.45,-3.15),"target":Vector3(0,1.02,0.30)},
		{"position":Vector3(width*0.68,2.25,0.25),"target":Vector3(0,1.08,0.25)},
		{"position":Vector3(-width*0.58,2.05,-3.15),"target":Vector3(0,1.08,0.35)}
	]
	return poses[clampi(index,0,poses.size()-1)]
