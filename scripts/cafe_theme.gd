extends RefCounted
const INK := Color("213b3c")
const CREAM := Color("f2e8d2")
const GOLD := Color("eac482")
const MINT := Color("91c6b3")

static func box(color: Color, radius := 16, padding := 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = padding
	s.content_margin_right = padding
	s.content_margin_top = padding
	s.content_margin_bottom = padding
	return s

static func make(paper := false) -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	var text := INK if paper else CREAM
	for type in ["Label", "Button", "OptionButton", "CheckButton", "LineEdit", "PopupMenu"]:
		t.set_color("font_color", type, text)
		t.set_color("font_hover_color", type, INK)
		t.set_color("font_pressed_color", type, INK)
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, box(Color("e4d7bb") if paper else Color("355354"), 10, 12))
		t.set_stylebox("hover", type, box(GOLD, 10, 12))
		t.set_stylebox("pressed", type, box(MINT, 10, 12))
		var focus := box(Color(0,0,0,0), 10, 12)
		focus.set_border_width_all(2)
		focus.border_color = MINT
		t.set_stylebox("focus", type, focus)
	t.set_stylebox("panel", "PopupMenu", box(INK, 12, 10))
	t.set_color("font_color", "PopupMenu", CREAM)
	t.set_stylebox("panel", "TooltipPanel", box(Color("f4e8cb"), 10, 12))
	t.set_color("font_color", "TooltipLabel", INK)
	t.set_font_size("font_size", "TooltipLabel", 16)
	t.set_stylebox("normal", "LineEdit", box(Color("294647"), 8, 10))
	return t
