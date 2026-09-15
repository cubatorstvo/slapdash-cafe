extends CanvasLayer
## Microscope field and six-pulse recalibration share one modal instrument surface.
var game: Node3D
var surface: Control
var close_button: Button
var mode := ""
var result: Dictionary={}
var clock := 0.0
var shown_age := 0.0
var server_age := -1.0

func setup(owner_game: Node3D) -> void:
	game=owner_game
	layer=35
	surface=Control.new(); add_child(surface)
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.mouse_filter=Control.MOUSE_FILTER_STOP
	surface.draw.connect(draw_instrument)
	surface.gui_input.connect(func(event):
		if mode=="calibration" and event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
			pulse(); surface.accept_event())
	close_button=Button.new(); surface.add_child(close_button)
	close_button.focus_mode=Control.FOCUS_NONE
	close_button.text="Закрыть · E / Esc"
	close_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	close_button.offset_left=-240; close_button.offset_right=-35; close_button.offset_top=-74; close_button.offset_bottom=-28
	close_button.pressed.connect(cancel_or_close)
	hide()

func opened() -> bool: return not mode.is_empty()

func open(value: Dictionary) -> void:
	result=value.duplicate(true)
	mode=str(value.get("kind","microscope"))
	clock=0.0
	game.menu.close(); game.office.close(); game.cookbook.close()
	game.session.suspend_input()
	show()
	game.sync_mouse_mode()

func close() -> void:
	mode=""
	hide()
	game.sync_mouse_mode()

func cancel_or_close() -> void:
	if mode=="calibration":
		game.session.request_action({"action":"lab_cal_cancel"})
	close()

func handle_input(event: InputEvent) -> bool:
	if not opened(): return false
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_ESCAPE or (event.physical_keycode==KEY_E and mode!="calibration"): cancel_or_close()
		elif event.physical_keycode in [KEY_SPACE,KEY_E] and mode=="calibration": pulse()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and mode=="calibration": pulse()
	return true

func pulse() -> void:
	var calibration=game.laboratory.calibrator
	if calibration.state.phase!="manual": return
	game.session.request_action({"action":"lab_cal_hit","revision":calibration.state.revision,"observed_age":shown_age})

func _process(delta: float) -> void:
	if game==null: return
	var calibration=game.laboratory.calibrator
	if calibration.manual_owner()==game.session.local_id():
		if mode!="calibration":
			open({"kind":"calibration"}); server_age=-1; shown_age=0
		var age:=float(calibration.state.age)
		if age!=server_age:
			server_age=age; shown_age=age
		elif game.session.is_guest(): shown_age+=minf(delta,0.05)
	elif mode=="calibration": close()
	if not opened(): return
	if not game.session_paused or game.session.online(): clock+=delta
	close_button.text="Прервать · Esc" if mode=="calibration" else "Закрыть · E / Esc"
	surface.queue_redraw()

func line(text: String, center: Vector2, size: int, color := Color("e6efce")) -> void:
	var font: Font=ThemeDB.fallback_font
	var width:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	surface.draw_string(font,center-Vector2(width*0.5,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func draw_instrument() -> void:
	var size:=surface.size
	var center:=Vector2(size.x*0.5,size.y*0.44)
	var radius:=minf(size.x*0.36,size.y*0.31)
	surface.draw_rect(Rect2(Vector2.ZERO,size),Color(0.035,0.065,0.059,0.94))
	if mode=="microscope":
		line("МИКРОСКОП · ЖИВАЯ ФОРМУЛА",Vector2(size.x*0.5,52),26)
		surface.draw_circle(center,radius+12,Color("708c76"))
		surface.draw_circle(center,radius,Color("173d32"))
		for i in range(36):
			var at:=center+Vector2(sin(clock*0.13+i*7.2),cos(clock*0.11+i*4.9))*radius*0.8
			surface.draw_circle(at,2.0+float(i%3),Color(0.4,0.65,0.45,0.25))
		var value: String="%d%%"%roundi(float(result.get("tempo",0.7))*100)
		for i in range(4):
			var at:=center+Vector2(sin(clock*(0.13 if i==0 else 0.38)+i*1.7)*0.57,cos(clock*0.21+i*1.8)*0.50)*radius
			var scale:=1.0+sin(clock*1.4)*0.15 if i==3 else 1.0
			var angle:=clock*0.27 if i==2 else sin(clock*0.3+i)*0.05
			surface.draw_set_transform(at,angle,Vector2.ONE*scale)
			line(value,Vector2.ZERO,42 if i==0 else 28,Color("b4e59b"))
			surface.draw_set_transform(Vector2.ZERO)
		var improved: bool=result.get("improved",false)
		line("НОВАЯ ФОРМУЛА СОХРАНЕНА" if improved else "РАБОЧАЯ ФОРМУЛА БЕЗ ИЗМЕНЕНИЙ",Vector2(size.x*0.5,size.y*0.81),24)
		line("Образец %d%% · рабочая формула %d%% · версия %d"%[roundi(float(result.tempo)*100),roundi(float(result.best)*100),int(result.get("version",0))],Vector2(size.x*0.5,size.y*0.87),20)
	elif mode=="calibration":
		var calibration=game.laboratory.calibrator
		var state: Dictionary=calibration.state
		line("РЕКАЛИБРОВКА · РИТМ ИМПУЛЬСОВ",Vector2(size.x*0.5,58),26)
		line("Нажимай пробел / ЛКМ, когда импульс пересекает белую линию",Vector2(size.x*0.5,100),20)
		line("Сейчас %d%% · изученный предел %d%%"%[roundi(float(state.start)*100),roundi(float(state.target)*100)],Vector2(size.x*0.5,140),22)
		var y:=size.y*0.50
		var x:=size.x*0.43
		for i in range(3):
			surface.draw_line(Vector2(size.x*0.15,y+(i-1)*70),Vector2(size.x*0.86,y+(i-1)*70),Color("31594d"),3)
		surface.draw_line(Vector2(x,y-125),Vector2(x,y+125),Color("f0e4bd"),4)
		var age:=shown_age/calibration.scale_time() if state.phase=="manual" else 0.0
		for i in range(calibration.BEATS.size()):
			var delta: float=float(calibration.BEATS[i])-age
			var at:=Vector2(x+delta*size.x*0.19,y+(i%3-1)*70)
			if at.x<size.x*0.10 or at.x>size.x*0.90: continue
			var score: float=float(state.hits[i])
			var color:=Color("d3bc75") if score<0 else Color("89cd9f") if score>=0.9 else Color("b77864")
			surface.draw_circle(at,18,color)
		line(str(state.notice),Vector2(size.x*0.5,size.y*0.76),22)
		line("Хорошее прохождение даёт весь предел. Прежний темп сохраняется при слабом результате.",Vector2(size.x*0.5,size.y*0.83),17)
	else:
		line("РЕКАЛИБРОВКА ЗАВЕРШЕНА",Vector2(size.x*0.5,size.y*0.32),28)
		line("%d%% → %d%%"%[roundi(float(result.before)*100),roundi(float(result.tempo)*100)],Vector2(size.x*0.5,size.y*0.48),52)
		line("Результат попытки: %d%% · максимум формулы: %d%%"%[roundi(float(result.attempt)*100),roundi(float(result.best)*100)],Vector2(size.x*0.5,size.y*0.60),22)
