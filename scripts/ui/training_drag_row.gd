extends PanelContainer
signal row_clicked(meta: Dictionary,ctrl: bool,shift: bool)
signal row_dropped(data: Variant,meta: Dictionary,after: bool)

const Style=preload("res://scripts/cafe_theme.gd")

var meta: Dictionary={}
var drag_payload: Dictionary={}
var selected:=false
var drop_enabled:=true
var title_text:=""
var subtitle_text:=""
var title_label: Label
var subtitle_label: Label

func setup(value_meta: Dictionary,title: String,subtitle := "",payload: Dictionary={}) -> void:
	meta=value_meta.duplicate(true)
	drag_payload=payload.duplicate(true)
	title_text=title
	subtitle_text=subtitle
	mouse_filter=Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	size_flags_horizontal=Control.SIZE_EXPAND_FILL
	custom_minimum_size.y=54
	var column:=VBoxContainer.new()
	column.mouse_filter=Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation",2)
	add_child(column)
	title_label=Label.new()
	title_label.text=title_text
	title_label.autowrap_mode=TextServer.AUTOWRAP_WORD
	title_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	title_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
	title_label.add_theme_font_size_override("font_size",16)
	column.add_child(title_label)
	if not subtitle_text.is_empty():
		subtitle_label=Label.new()
		subtitle_label.text=subtitle_text
		subtitle_label.autowrap_mode=TextServer.AUTOWRAP_WORD
		subtitle_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		subtitle_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
		subtitle_label.add_theme_font_size_override("font_size",13)
		subtitle_label.modulate=Color(0.78,0.84,0.82)
		column.add_child(subtitle_label)
	set_selected(false)

func set_selected(value: bool) -> void:
	selected=value
	var box:=Style.box(Color("315052") if selected else Color("294647"),10,10)
	if selected:
		box.set_border_width_all(2)
		box.border_color=Style.GOLD
	add_theme_stylebox_override("panel",box)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		row_clicked.emit(meta,event.ctrl_pressed or event.meta_pressed,event.shift_pressed)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_payload.is_empty(): return null
	var preview:=PanelContainer.new()
	preview.theme=Style.make()
	preview.add_theme_stylebox_override("panel",Style.box(Color("355354"),10,10))
	var text:=Label.new()
	var count: int=int(drag_payload.get("count",1))
	text.text=title_text if count<=1 else "Выбрано: %d"%count
	text.add_theme_font_size_override("font_size",15)
	preview.add_child(text)
	set_drag_preview(preview)
	return drag_payload.duplicate(true)

func _can_drop_data(_at_position: Vector2,data: Variant) -> bool:
	return drop_enabled and data is Dictionary and str(data.get("kind","")) in ["masterclass_records","queue_lessons"]

func _drop_data(at_position: Vector2,data: Variant) -> void:
	row_dropped.emit(data,meta,at_position.y>size.y*0.5)

