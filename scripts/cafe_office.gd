extends "res://scripts/cafe_office_core.gd"
const OverviewStyle = preload("res://scripts/cafe_theme.gd")
const OverviewDefinition = preload("res://scripts/station_definition.gd")
const UiMode = preload("res://scripts/cafe_ui_mode.gd")
var overview_live_stamp := ""
var settings_shortcut: Button

const NAV_LABELS := {
	"overview":"Кафе",
	"stations":"Магазин",
	"star":"Развитие",
	"groups":"Сотрудники",
	"videos":"Обучение",
}
const SHOP_CATEGORY_LABELS := {
	"equipment":"Оснащение",
	"tables":"Новые столы",
	"rooms":"Расширения",
	"lab":"Лаборатория",
	"lounge":"Мебель",
	"decor":"Декор",
}

func _ready() -> void:
	super()
	for key in NAV_LABELS:
		if navigation.has(key): navigation[key].text = NAV_LABELS[key]
	var top := get_node("Panel/Column/Top")
	settings_shortcut = Button.new()
	settings_shortcut.text = "⚙ Сохранение"
	settings_shortcut.flat = true
	settings_shortcut.tooltip_text = "Сохранение, помощь и настройки"
	settings_shortcut.pressed.connect(navigate.bind("settings"))
	top.add_child(settings_shortcut)
	var close_button := get_node("Panel/Column/Top/Close")
	top.move_child(settings_shortcut, close_button.get_index())
	_apply_feature_navigation()

func _feature_access():
	return game.service.feature_access if game != null and is_instance_valid(game.service) else null

func _feature_visible(feature_id: String) -> bool:
	if feature_id.is_empty(): return true
	var access = _feature_access()
	return access != null and bool(access.access(feature_id).get("visible", false))

func _resolve_page(page: String) -> String:
	var normalized := "stations" if page in ["deliveries", "decor", "night"] else page
	var access = _feature_access()
	return access.nearest_visible_page(normalized) if access != null else normalized

func _resolve_shop_category(category: String) -> String:
	var access = _feature_access()
	return access.first_visible_category(category) if access != null else category

func _apply_feature_navigation() -> void:
	if navigation.is_empty(): return
	for key in navigation:
		var show_in_sidebar := key in ["overview","stations","star","groups","videos"]
		if key == "groups": show_in_sidebar = _feature_visible("staff_roster")
		elif key == "videos": show_in_sidebar = _feature_visible("video_training")
		navigation[key].visible = show_in_sidebar
		if show_in_sidebar and NAV_LABELS.has(key): navigation[key].text = NAV_LABELS[key]
	if is_instance_valid(settings_shortcut): settings_shortcut.show()

func _focus_signature() -> Dictionary:
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null: return {}
	for key in navigation:
		if focused == navigation[key]: return {"nav":str(key)}
	if focused is Button: return {"text":focused.text}
	return {}

func _restore_focus(signature: Dictionary) -> void:
	if signature.is_empty() or not opened(): return
	var nav_key := str(signature.get("nav", ""))
	if not nav_key.is_empty() and navigation.has(nav_key) and navigation[nav_key].visible:
		navigation[nav_key].grab_focus()
		return
	var text := str(signature.get("text", ""))
	if text.is_empty(): return
	for node in panel.find_children("*", "Button", true, false):
		var candidate := node as Button
		if candidate != null and candidate.visible and candidate.text == text:
			candidate.grab_focus()
			return

func open(page := "overview") -> void:
	super(_resolve_page(page))
	UiMode.apply(game,UiMode.OFFICE)

func close() -> void:
	super()
	UiMode.apply(game,UiMode.GAMEPLAY)

func navigate(page: String) -> void:
	super(_resolve_page(page))

func open_shop(category: String) -> void:
	shop_category = _resolve_shop_category(category)
	navigate("stations")

func _set_shop_category(key: String) -> void:
	super(_resolve_shop_category(key))

func open_problem_page(page: String) -> void:
	super(_resolve_page(page))

func open_problem_group(stations: Array, course_id := 0) -> void:
	if not _feature_visible("staff_roster"):
		navigate("star")
		return
	super(stations, course_id)

func _process(delta: float) -> void:
	if game!=null and is_instance_valid(game.get("service")) and opened():
		var service=game.service
		var current: Dictionary=service.current_shift_summary()
		var problem: Dictionary=service.overview_problem()
		var production: Dictionary=service.production_overview()
		var feature_revision := service.feature_access.revision() if service.get("feature_access") != null else 0
		var live: String="%d:%d:%d:%d:%d:%d:%d:%d"%[int(current.get("day",0)),int(current.get("served",0)),int(current.get("missed",0)),int(current.get("revenue",0)),service.progress.deliveries.size(),int(problem.get("id",0)),int(production.get("working_stations",0)),feature_revision]
		if live!=overview_live_stamp:
			overview_live_stamp=live
			stamp=""
	super(delta)
	if tab=="overview" and is_instance_valid(status):
		if action_notice_left>0.0:
			status.text=action_notice
			status.show()
		else:
			status.hide()
	if opened(): UiMode.apply(game,UiMode.OFFICE)

func rebuild() -> void:
	var signature := _focus_signature()
	var resolved := _resolve_page(tab)
	if resolved != tab:
		tab = resolved
		last_page = ""
	if tab == "stations": shop_category = _resolve_shop_category(shop_category)
	super()
	_apply_feature_navigation()
	if NAV_LABELS.has(tab): heading.text = NAV_LABELS[tab]
	elif tab == "laboratory": heading.text = "Развитие · Лаборатория"
	elif tab == "lounge": heading.text = "Развитие · Отдых"
	elif tab == "stats": heading.text = "Кафе · Аналитика"
	elif tab == "settings": heading.text = "Сохранение и помощь"
	if tab == "stations": _filter_shop_categories()
	if tab == "star": _decorate_development()
	elif tab == "groups": _decorate_staff()
	call_deferred("_restore_focus", signature)

func _filter_shop_categories() -> void:
	var access = _feature_access()
	if access == null: return
	for node in content.find_children("*", "Button", true, false):
		var choice := node as Button
		if choice == null: continue
		for category in SHOP_CATEGORY_LABELS:
			if choice.text == SHOP_CATEGORY_LABELS[category]:
				choice.visible = bool(access.category_access(category).visible)
				break
	# Batch type selectors are buttons rather than product rows.
	for item in ["counter","kitchen","grill_kitchen","solyanka_kitchen"]:
		if not game.shop.ITEMS.has(item): continue
		var state: Dictionary = access.item_access(item, game.shop.ITEMS[item])
		if bool(state.visible): continue
		var title := str(game.shop.ITEMS[item].name)
		for node in content.find_children("*", "Button", true, false):
			var candidate := node as Button
			if candidate != null and title in candidate.text: candidate.hide()

func _product_row(parent: Node, item: String, station_id: int, installed: bool, reason: String, selection := false) -> HBoxContainer:
	var spec: Dictionary = game.shop.ITEMS.get(item, {})
	var access = _feature_access()
	var state: Dictionary = {"visible":true,"enabled":true}
	if access != null and not spec.is_empty():
		state = access.item_access(item, spec, {
			"host_required":true,
			"is_host":not game.session.is_guest(),
			"already_owned":installed,
			"pending_delivery":not _item_parcel(item, station_id).is_empty(),
		})
	var final_reason := reason
	if bool(state.get("visible", true)) and not bool(state.get("enabled", true)) and final_reason.is_empty() and access != null:
		final_reason = access.reason_text(state)
	var row: HBoxContainer = super(parent, item, station_id, installed, final_reason, selection)
	if not bool(state.get("visible", true)):
		var box := row.get_parent()
		var card := box.get_parent() if box != null else null
		if card is Control: card.hide()
	return row

func _clear_current_content() -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()

func _decorate_development() -> void:
	var access = _feature_access()
	if access == null: return
	var stars_state: Dictionary = access.access("stars")
	if not bool(stars_state.introduced):
		_clear_current_content()
		var card := _section_card(content, Color("304943"))
		label(card, "ПЕРВАЯ ОЦЕНКА КАФЕ", 21)
		label(card, "Сначала обслужи первого гостя. После этого станет понятно, что именно оценивают и как получить первую звезду.", 16)
		label(card, "Ближайший шаг: принять первого гостя и выполнить его заказ.", 15)
		return
	var links := _section_card(content, Color("294647"))
	label(links, "РАЗВИТИЕ СИСТЕМ", 13)
	if _feature_visible("clone_lab"): button(links, "Лаборатория →", navigate.bind("laboratory"))
	if _feature_visible("rest_basics"): button(links, "Отдых сотрудников →", navigate.bind("lounge"))
	var teaser := _nearest_teaser()
	if not teaser.is_empty(): label(links, "СКОРО · " + teaser, 14)

func _nearest_teaser() -> String:
	for entry in [["staff_roster","Сотрудники"],["video_training","Обучение"],["kitchen_pair","Парная кухня"],["kitchen_grill","Бургерная кухня"],["kitchen_solyanka","Кухня «Солянка»"]]:
		if not _feature_visible(str(entry[0])): return str(entry[1])
	return ""

func _decorate_staff() -> void:
	var card := _section_card(content, Color("294647"))
	label(card, "РАЗВИТИЕ СОТРУДНИКОВ", 13)
	if _feature_visible("clone_lab"): button(card, "Лаборатория и рост →", navigate.bind("laboratory"))
	if _feature_visible("rest_basics"): button(card, "Отдых и восстановление →", navigate.bind("lounge"))

func _overview_metric(parent: Node,title: String,value: String) -> void:
	var box:=_section_card(parent,Color("253f41"))
	var panel:=box.get_parent() as Control
	if panel!=null:
		panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		panel.size_flags_stretch_ratio=1.0
	label(box,title,13)
	var amount:=label(box,value,24)
	amount.add_theme_color_override("font_color",OverviewStyle.GOLD)

func _shift_state_label(shift: String) -> String:
	return "завершена" if shift=="night" else "заканчивается" if shift=="closing" else "подготовка" if shift=="morning" else "идёт"

func _parcel_item(parcel: Dictionary) -> String:
	var items: Variant=parcel.get("items",[])
	if items is Array and not items.is_empty(): return str(items[0])
	return str(parcel.get("item",""))

func _parcel_name(parcel: Dictionary) -> String:
	var item:=_parcel_item(parcel)
	if item.is_empty(): return "Посылка"
	var spec: Variant=game.shop.ITEMS.get(item,{})
	return str(spec.get("name",item)) if spec is Dictionary else item

func _parcel_line(parcel: Dictionary) -> String:
	var station_id:=int(parcel.get("station",0))
	var target: String=" · стол %d"%station_id if station_id>0 else ""
	return "%s%s · %s"%[_parcel_name(parcel),target,_parcel_status(parcel)]

func _open_delivery(parcel: Dictionary) -> void:
	var station_id:=int(parcel.get("station",0))
	if station_id>0: shop_station_id=station_id
	var item:=_parcel_item(parcel)
	var spec: Variant=game.shop.ITEMS.get(item,{})
	var kind: String=str(spec.get("kind","")) if spec is Dictionary else ""
	var category: String="tables" if kind=="station" else "lab" if kind=="lab_upgrade" else "lounge" if kind=="lounge" else "rooms" if kind in ["expansion","lab_expansion","lounge_expansion"] else "equipment"
	open_shop(category)

func _open_overview_problem(problem: Dictionary) -> void:
	var reason:=str(problem.get("reason",""))
	var stations: Array=problem.get("stations",[]) if problem.get("stations",[]) is Array else []
	stats_focus=problem.duplicate(true)
	if reason=="equipment":
		if not stations.is_empty(): shop_station_id=int(stations[0])
		open_shop("equipment")
	elif reason=="workers":
		open_problem_page("laboratory")
	elif reason=="no_station":
		open_shop("tables")
	elif reason in ["busy","unlearned","training","menu_off","wait"] and not stations.is_empty():
		open_problem_group(stations)
	else:
		navigate("stats")

func overview_page(_host: bool) -> void:
	var service=game.service
	var p=service.progress
	var current: Dictionary=service.current_shift_summary()
	var summary:=_section_card(content,Color("304943"))
	label(summary,"СМЕНА %d · %s"%[int(current.get("day",p.day)),_shift_state_label(str(p.shift))],14)
	var ledger:=label(summary,"День %d · %d денег · ★ %d/5"%[p.day,p.cash,p.stars],16)
	ledger.add_theme_color_override("font_color",OverviewStyle.MINT)
	var metrics:=HBoxContainer.new()
	metrics.add_theme_constant_override("separation",8)
	summary.add_child(metrics)
	_overview_metric(metrics,"ВЫРУЧКА",str(int(current.get("revenue",0))))
	_overview_metric(metrics,"ОБСЛУЖЕНО",str(int(current.get("served",0))))
	_overview_metric(metrics,"УШЛИ",str(int(current.get("missed",0))))
	var previous: Dictionary=service.previous_shift_summary()
	if not previous.is_empty() and int(previous.get("day",0))!=p.day:
		label(summary,"Предыдущая смена · выручка %d · обслужено %d · ушли %d"%[int(previous.get("revenue",0)),int(previous.get("served",0)),int(previous.get("missed",0))],13)

	var production: Dictionary=service.production_overview()
	if not production.is_empty():
		var production_card:=_section_card(content,Color("294647"))
		label(production_card,"ПРОИЗВОДСТВО",13)
		label(production_card,"Клонов: %d · столов с командой: %d/%d · сейчас работают: %d"%[int(production.clones),int(production.assigned_stations),int(production.production_stations),int(production.working_stations)],15)

	if not p.deliveries.is_empty():
		var deliveries:=_section_card(content,Color("4b4235"))
		label(deliveries,"ДОСТАВКИ · %d"%p.deliveries.size(),14)
		var visible_count:=mini(3,p.deliveries.size())
		for index in range(visible_count): label(deliveries,_parcel_line(p.deliveries[index]),16)
		if p.deliveries.size()>visible_count: label(deliveries,"Ещё %d посылок"%(p.deliveries.size()-visible_count),13)
		button(deliveries,"Открыть доставку →",func():_open_delivery(p.deliveries[0]))

	var problem: Dictionary=service.overview_problem()
	if not problem.is_empty():
		var card:=_section_card(content,Color("4b3535"))
		label(card,"ТРЕБУЕТ ВНИМАНИЯ",13)
		var targets: Array[String]=[]
		var order_id:=int(problem.get("order_id",0))
		if order_id>0: targets.append("Заказ #%d"%order_id)
		var stations: Array=problem.get("stations",[]) if problem.get("stations",[]) is Array else []
		if not stations.is_empty(): targets.append(("Стол " if stations.size()==1 else "Столы ")+", ".join(stations.map(func(id):return str(int(id)))))
		var dish:=str(problem.get("dish",""))
		if targets.is_empty() and not dish.is_empty(): targets.append(str(OverviewDefinition.DISHES.get(dish,dish)))
		if not targets.is_empty(): label(card," · ".join(targets),18)
		label(card,str(problem.get("label","Проблема обслуживания")),16)
		label(card,str(problem.get("suggestion","")),14)
		button(card,"Перейти к исправлению →",func():_open_overview_problem(problem))

	visit_card()
	var analytics_card := _section_card(content, Color("253f41"))
	label(analytics_card, "АНАЛИТИКА", 13)
	label(analytics_card, "Причины потерь и история смен остаются частью управления кафе.", 14)
	button(analytics_card, "Открыть аналитику →", navigate.bind("stats"))
