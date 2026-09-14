extends CanvasLayer
## Shared cafe ledger, accessed from the physical cafe computer.
const Lounge = preload("res://scripts/lounge_progression.gd")
const P = preload("res://scripts/cafe_progression.gd")
const Style = preload("res://scripts/cafe_theme.gd")
const Definition = preload("res://scripts/station_definition.gd")
var game: Node3D
var panel: PanelContainer
var content: VBoxContainer
var scroll: ScrollContainer
var heading: Label
var status: Label
var timer: Label
var tab := "overview"
var stamp := ""
var selections := {}
var confirm_reset := false

func _ready() -> void:
	layer = 17
	panel = PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 100
	panel.offset_right = -100
	panel.offset_top = 112
	panel.offset_bottom = -40
	panel.theme = Style.make()
	panel.add_theme_stylebox_override("panel", Style.box(Color("203b3c"), 20, 22))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	heading = label(top, "МОЁ КАФЕ", 26)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(top, "Вернуться · Esc", close)
	status = label(column, "", 18)
	timer = label(column, "", 19)
	timer.add_theme_color_override("font_color", Style.GOLD)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for entry in [["overview", "Кафе"], ["stations", "Интернет-магазин"], ["lounge", "Комната отдыха"], ["deliveries", "Доставки"], ["star", "Звёзды"]]:
		var key: String = entry[0]
		button(tabs, entry[1], func(): tab = key; stamp = ""; rebuild())
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	panel.hide()

func label(parent: Node, text: String, size := 17) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_theme_font_size_override("font_size", size)
	parent.add_child(node)
	return node

func button(parent: Node, text: String, callback: Callable, enabled := true) -> Button:
	var node := Button.new()
	node.text = text
	node.custom_minimum_size.y = 44
	node.disabled = not enabled
	node.pressed.connect(func():
		if is_instance_valid(game.feedback): game.feedback.play_ui("click")
		callback.call())
	parent.add_child(node)
	return node

func opened() -> bool: return panel.visible
func open(page := "overview") -> void:
	tab = page
	game.menu.close()
	game.cookbook.close()
	game.session.suspend_input()
	confirm_reset = false
	panel.show()
	stamp = ""
	rebuild()
	game.sync_mouse_mode()

func close() -> void:
	panel.hide()
	game.sync_mouse_mode()

func send(action: Dictionary, dismiss := false) -> void:
	if dismiss: close()
	game.session.request_action(action)
	stamp = ""

func _process(_delta: float) -> void:
	if game == null or not is_instance_valid(game.service) or not opened(): return
	var progress = game.service.progress
	status.text = "Деньги: %d    Популярность: %d    Звёзды: %d / 5    Гости: %s" % [progress.cash, progress.popularity, progress.stars, "приходят" if game.service.open_for_business else "приём закрыт"]
	timer.text = "%s · %d:%02d" % ["Личный показ" if progress.phase == "showcase" else "Банкет", ceili(progress.remaining) / 60, ceili(progress.remaining) % 60] if progress.phase in ["showcase", "service"] else ""
	var next := "%s:%d:%d:%s:%s" % [tab, progress.revision, game.service.served, str(game.service.open_for_business), str(game.service.any_training())]
	if stamp != next:
		stamp = next
		rebuild()

func rebuild() -> void:
	var offset := scroll.scroll_vertical
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	var service = game.service
	var progress = service.progress
	var host: bool = not game.session.is_guest()
	if not host: label(content,"Покупки подтверждает хозяин кафе. Коробки можно распаковывать вместе.",15)
	match tab:
		"overview":
			label(content,progress.objective(service.stations,service.served,service.open_for_business),22)
			button(content,"Закончить смену" if service.open_for_business else "Открыть кафе",func():send({"action":"business"},true),host and not progress.busy() and progress.shift in ["morning","open"])
			label(content,"Личная стойка — твои заказы. Купленное оборудование приедет ко входу: забери коробку и установи на отмеченное место.")
			label(content,"Свободных клонов: %d. Создание в лаборатории — 60.\nЛаборатория: закажи колбу, питание и стабилизатор. Установи на верстаке в лаборатории. Клоны откроются после первой звезды."%progress.free_clones)
			label(content,"Ночью посетителей нет. Все игроки ложатся в общую Шеф-кровать, чтобы начать новый день. Доставки и обустройство доступны днём тоже.")
			button(content,"Сохранить кафе",func():send({"action":"save"}),host)
			button(content,"Папка плейтеста",func():OS.shell_open(ProjectSettings.globalize_path(game.telemetry.folder)))
			label(content,"Отметки для плейтеста: F8 — скучно, F9 — непонятно, F10 — прикольно. События пишутся локально.",15)
			if confirm_reset:
				button(content,"Подтвердить новое прохождение",func():send({"action":"new_cafe"},true),host and not service.any_training() and not progress.busy())
			else: button(content,"Новое прохождение…",func():confirm_reset=true;rebuild())
		"stations", "decor", "night":
			label(content,"ТЯП-ЛЯП МАРКЕТ · доставка в коробках",23)
			label(content,"Цена указана за комплект. Выбери станцию; коробка покажет её место установки. Продукты на станции возобновляются на каждый заказ.",15)
			for station in service.stations:
				label(content,"ТВОЯ СТОЙКА" if station.manual_station else "СТАНЦИЯ %d" % station.station_id,20)
				var catalog: Array = ["sauce","plates","cup","pan","jug","sauce_ramp"] if station.type_id == "counter" else ["meat_kit","pasta_kit"]
				if progress.stars<1:
					for item in catalog: shop_button(item,station.station_id,item in station.equipment or item in station.upgrades)
				else: bundle_controls(station,catalog)
			label(content,"РАСШИРЕНИЕ КУХНИ",20)
			shop_button("counter",0,service.by_id(2)!=null and service.by_id(3)!=null)
			button(content,"Расширение зала · 180",func():send({"action":"buy","kind":"expansion"}),host and progress.stars>=2 and not progress.expanded and progress.cash>=180)
			shop_button("kitchen",0,service.by_id(4)!=null)
			label(content,"ЛАБОРАТОРИЯ",20)
			for i in range(3): shop_button("lab_%d"%i,0,i<progress.lab_stage)
			for item in ["lab_power","lab_power_2","lab_valve","lab_damper"]: shop_button(item,0,item in progress.lab_upgrades)
			label(content,"ОБУСТРОЙСТВО",20)
			for item in ["sign","plants","lights"]: shop_button(item,0,item in progress.decorations or (item=="lights" and progress.garland_owned))
		"lounge":
			lounge_page()
		"deliveries":
			label(content,"ДОСТАВКИ",23)
			if progress.deliveries.is_empty(): label(content,"Все коробки разобраны.")
			for parcel in progress.deliveries:
				var state := "В пути" if parcel.remaining>0 else "Несёт игрок" if parcel.owner>0 else "У входа / поставлена на пол"
				label(content,game.shop.ITEMS[parcel.item].name+" · "+state+(" · станция %d"%parcel.station if parcel.station>0 else ""))
		"star":
			label(content,"ПЕРВАЯ ЗВЕЗДА · дегустация" if progress.stars==0 else "ВТОРАЯ ЗВЕЗДА · банкет",23)
			if not progress.result.is_empty(): label(content,progress.result)
			if progress.stars>=2: label(content,"Две звезды получены. Доступны расширение и парная кухня.")
			else:
				for requirement in progress.star_requirements(service.stations,service.served): label(content,("✓ " if requirement.done else "○ ")+requirement.text)
				label(content,"Один дегустатор, три стандартных блюда B или лучше. Ошибку можно повторить бесплатно. Перед проверкой установи сковороду, соус, бокал и кувшин." if progress.stars==0 else "Девять гостей за четыре минуты: трое требуют личного заказа шефа. Нужно 8 подач и 6 оценок B или выше.")
				button(content,"Пригласить дегустатора" if progress.stars==0 else "Пригласить делегацию",func():send({"action":"banquet"},true),host and progress.can_attempt(service.stations,service.served) and not service.any_training())
			if progress.busy(): button(content,"Прервать проверку",func():send({"action":"cancel_banquet"}),host)
	scroll.scroll_vertical = offset

func shop_button(item: String, station_id: int, installed := false) -> void:
	var p = game.service.progress
	var spec: Dictionary = game.shop.ITEMS[item]
	var waiting: bool = game.shop.pending(item,station_id)
	var gate: int = int(spec.get("star",0))
	var prerequisite: bool = spec.kind!="lab_upgrade" or (p.lab_stage>=3 and (item!="lab_power_2" or "lab_power" in p.lab_upgrades))
	var suffix := " · установлено" if installed else " · доставка заказана" if waiting else " · звезда %d"%gate if p.stars<gate else " · %d"%spec.price
	if not prerequisite: suffix=" · сначала лаборатория / усилитель"
	button(content,spec.name+suffix,func():send({"action":"buy","kind":"item","item":item,"station":station_id}),not game.session.is_guest() and not installed and not waiting and prerequisite and p.stars>=gate and p.cash>=spec.price and not p.busy())

func bundle_controls(station: Node3D, catalog: Array) -> void:
	var id: int=station.station_id
	if not selections.has(id): selections[id]=[]
	var total := 0
	for item in catalog:
		var spec: Dictionary=game.shop.ITEMS[item]
		var unavailable: bool=item in station.equipment or item in station.upgrades or game.shop.pending(item,id) or game.service.progress.stars<int(spec.get("star",0))
		if unavailable: selections[id].erase(item)
		var check := CheckBox.new(); content.add_child(check)
		check.text=spec.name+" · %d"%spec.price+(" · установлено / недоступно" if unavailable else "")
		check.disabled=unavailable or game.session.is_guest()
		check.button_pressed=item in selections[id]
		if check.button_pressed: total+=int(spec.price)
		check.toggled.connect(func(on):
			if on: selections[id].append(item)
			else: selections[id].erase(item)
			rebuild())
	button(content,"Заказать комплект · %d"%total,func():send({"action":"buy_bundle","station":id,"items":selections[id].duplicate()}),total>0 and game.service.progress.cash>=total and not game.service.progress.busy() and not game.session.is_guest())

func lounge_page() -> void:
	var p=game.service.progress
	var forecast:=Lounge.report(p,game.evening.workers().size())
	var host: bool=not game.session.is_guest()
	label(content,"КОМНАТА ОТДЫХА · "+str(Lounge.STAGES[p.lounge_tier].name),23)
	label(content,"Сегодня: +%d%% к темпу всех клонов. Завтра: +%d%%."%[roundi((p.rest_multiplier-1.0)*100),roundi(float(forecast.bonus)*100)],20)
	label(content,"Мест: %d · клонов: %d · уют: +%d%%. Бонус делится на всю команду, максимум +30%%. Если мест не хватает, общий бонус меньше."%[forecast.places,forecast.workers,roundi(float(forecast.comfort)*100)])
	label(content,"На ночь каждый выбирает одно развлечение. Кровать шефов общая; смешные места сна клонов на темп не влияют. Покупки начнут помогать со следующего утра.",15)
	if p.lounge_tier<2:
		var next: Dictionary=Lounge.STAGES[p.lounge_tier+1]
		var suffix: String=" · нужна звезда %d"%next.star if p.stars<int(next.star) else " · %d"%next.price
		button(content,"Расширить: "+str(next.name)+suffix,func():send({"action":"buy","kind":"lounge_expansion"}),host and p.stars>=int(next.star) and p.cash>=int(next.price) and not p.busy() and game.session.sleeping_peers.is_empty())
	label(content,"МЕБЕЛЬ И УЮТ · доставка в коробках",20)
	for id in Lounge.GOODS:
		var spec: Dictionary=game.shop.ITEMS["rest_"+id]
		lounge_button("rest_"+id,spec,id in p.lounge_items)
		if id in p.lounge_items and float(Lounge.GOODS[id].quality)>0:
			lounge_button("rest_upgrade_"+id,game.shop.ITEMS["rest_upgrade_"+id],id in p.lounge_upgrades)

func lounge_button(item: String, spec: Dictionary, installed: bool) -> void:
	var p=game.service.progress
	var error:=Lounge.item_error(p,spec)
	var waiting: bool=game.shop.pending(item,0)
	var suffix: String=" · установлено" if installed else " · в доставке" if waiting else " · "+error if not error.is_empty() else " · %d"%spec.price
	button(content,str(spec.name)+suffix,func():send({"action":"buy","kind":"item","item":item,"station":0}),not game.session.is_guest() and error.is_empty() and not waiting and p.cash>=int(spec.price) and not p.busy())
