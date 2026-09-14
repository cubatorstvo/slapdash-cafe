from pathlib import Path

fixes = {
    'scripts/cook_avatar.gd': [
        ('\tvar local_target:=to_local(target)\n', '\tvar local_target: Vector3=to_local(target)\n'),
        ('\tvar reach:=sin(clampf(pass_phase,0.0,1.0)*PI)\n', '\tvar reach: float=sin(clampf(pass_phase,0.0,1.0)*PI)\n'),
        ('\t\tvar catch:=smoothstep(0.55,1.0,pass_phase)\n', '\t\tvar catch: float=smoothstep(0.55,1.0,pass_phase)\n'),
        ('\tvar eased:=smoothstep(0.0,1.0,clampf(rise,0.0,1.0))\n', '\tvar eased: float=smoothstep(0.0,1.0,clampf(rise,0.0,1.0))\n'),
        ('\tvar kind:=posmod(variant,5)\n', '\tvar kind: int=posmod(variant,5)\n'),
        ('\tvar beat:=clock*[11.0,9.0,14.0,10.5,12.0][kind]\n', '\tvar beat: float=clock*float([11.0,9.0,14.0,10.5,12.0][kind])\n'),
        ('\tvar bounce: float=[0.08,0.20,0.045,0.11,0.14][kind]\n', '\tvar bounce: float=float([0.08,0.20,0.045,0.11,0.14][kind])\n'),
        ('*([0.62,0.82,0.95,0.70,0.78][kind])', '*float([0.62,0.82,0.95,0.70,0.78][kind])'),
    ],
    'scripts/sleep_cinematic.gd': [
        ('\tvar back:=Layout.back_z(game.service.progress.lounge_tier)\n', '\tvar back: float=Layout.back_z(game.service.progress.lounge_tier)\n'),
        ('\tvar daylight_blend:=smoothstep(0.0,1.0,clampf(age/1.45,0,1))\n', '\tvar daylight_blend: float=smoothstep(0.0,1.0,clampf(age/1.45,0,1))\n'),
        ('\tvar travel:=smoothstep(0.0,1.0,clampf((age-0.55)/4.3,0,1))\n', '\tvar travel: float=smoothstep(0.0,1.0,clampf((age-0.55)/4.3,0,1))\n'),
        ('\tvar camera_start:=Vector3(15.7,4.15,back-1.0)\n', '\tvar camera_start: Vector3=Vector3(15.7,4.15,back-1.0)\n'),
        ('\tvar camera_end:=Vector3(12.0,3.15,8.15)\n', '\tvar camera_end: Vector3=Vector3(12.0,3.15,8.15)\n'),
        ('\tvar look_start:=Vector3(10.4,1.0,maxf(13.4,back-4.0))\n', '\tvar look_start: Vector3=Vector3(10.4,1.0,maxf(13.4,back-4.0))\n'),
        ('\tvar look_end:=Vector3(3.0,1.05,-1.4)\n', '\tvar look_end: Vector3=Vector3(3.0,1.05,-1.4)\n'),
        ('\t\t\tvar layer:=game.session.local_sleep_bed()\n', '\t\t\tvar layer: int=game.session.local_sleep_bed()\n'),
        ('\t\t\tvar rise:=smoothstep(0.0,1.0,clampf(age/1.15,0,1))\n', '\t\t\tvar rise: float=smoothstep(0.0,1.0,clampf(age/1.15,0,1))\n'),
    ],
    'scripts/staff_evening.gd': [
        ('\tvar duration:=2.25\n', '\tvar duration: float=2.25\n'),
        ('\tvar turn:=int(floor(clock/duration))\n', '\tvar turn: int=int(floor(clock/duration))\n'),
        ('\tvar pass_phase:=fposmod(clock,duration)/duration\n', '\tvar pass_phase: float=fposmod(clock,duration)/duration\n'),
        ('\t\t\tvar start_delay:=0.20+float(index%10)*0.075\n', '\t\t\tvar start_delay: float=0.20+float(index%10)*0.075\n'),
        ('\t\t\tvar rise_duration:=0.82+float(id%3)*0.08\n', '\t\t\tvar rise_duration: float=0.82+float(id%3)*0.08\n'),
        ('\t\t\t\tvar rise:=smoothstep(0.0,1.0,clampf((age-start_delay)/rise_duration,0,1))\n', '\t\t\t\tvar rise: float=smoothstep(0.0,1.0,clampf((age-start_delay)/rise_duration,0,1))\n'),
        ('\t\t\t\tvar run_clock:=age-start_delay-rise_duration\n', '\t\t\t\tvar run_clock: float=age-start_delay-rise_duration\n'),
        ('\t\t\t\tvar variant:=id%5\n', '\t\t\t\tvar variant: int=id%5\n'),
        ('\t\t\t\tvar sample:=_sample_route(reverse_route,run_clock*speed)\n', '\t\t\t\tvar sample: Dictionary=_sample_route(reverse_route,run_clock*speed)\n'),
        ('\t\tvar sample:=_sample_route(route,maxf(0,t-0.85)*speed)\n', '\t\tvar sample: Dictionary=_sample_route(route,maxf(0,t-0.85)*speed)\n'),
    ],
    'scripts/lounge_layout.gd': [
        ('\t\tvar layer:=int(index/ring.size())\n', '\t\tvar layer: int=int(index/ring.size())\n'),
        ('\t\tvar yaw:=atan2(-toward.x,-toward.z)\n', '\t\tvar yaw: float=atan2(-toward.x,-toward.z)\n'),
        ('\tvar layer:=int(index/candidates.size())\n', '\tvar layer: int=int(index/candidates.size())\n'),
        ('\tvar yaw:=atan2(-toward.x,-toward.z) if toward.length()>0.05 else float(index%4)*PI/2.0\n', '\tvar yaw: float=atan2(-toward.x,-toward.z) if toward.length()>0.05 else float(index%4)*PI/2.0\n'),
    ],
    'scripts/coop_session.gd': [
        ('\tvar phase:=sleep_scene_phase()\n', '\tvar phase: String=sleep_scene_phase()\n'),
        ('\t\t\tvar layer:=int(sleeping_peers[id])\n', '\t\t\tvar layer: int=int(sleeping_peers[id])\n'),
        ('\t\t\t\tvar rise:=smoothstep(0.0,1.0,clampf(sleep_scene_age()/1.15,0.0,1.0))\n', '\t\t\t\tvar rise: float=smoothstep(0.0,1.0,clampf(sleep_scene_age()/1.15,0.0,1.0))\n'),
    ],
}

for filename, pairs in fixes.items():
    path = Path(filename)
    text = path.read_text()
    for old, new in pairs:
        if old in text:
            text = text.replace(old, new)
    path.write_text(text)
