extends "res://scripts/cafe_office_core.gd"
const OverviewStyle = preload("res://scripts/cafe_theme.gd")
const OverviewDefinition = preload("res://scripts/station_definition.gd")
const UiMode = preload("res://scripts/cafe_ui_mode.gd")
var overview_live_stamp := ""

func open(page := "overview") -> void:
	super(page)
	UiMode.apply(game,UiMode.OFFICE)

func close() -> void:
	super()
	UiMode.apply(game,UiMode.GAMEPLAY)

func _process(delta: float) -> void:
	if game!=null and is_instance_valid(game.get("service")) and opened():
		var service=game.service
		var current: Dictionary=service.current_shift_summary()
		var problem: Dictionary=service.overview_problem()
		var production: Dictionary=service.production_overview()
		var live: String="%d:%d:%d:%d:%d:%d:%d"%[int(current.get("day",0)),int(current.get("served",0)),int(current.get("missed",0)),int(current.get("revenue",0)),service.progress.deliveries.size(),int(problem.get("id",0)),int(production.get("working_stations",0))]
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
