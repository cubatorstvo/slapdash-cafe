extends CanvasLayer
## Shared cafe ledger, accessed from the office board or M.
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
	button(top, "Вернуться · M / Esc", close)
	status = label(column, "", 18)
	timer = label(column, "", 19)
	timer.add_theme_color_override("font_color", Style.GOLD)
	var tabs := HBoxContainer.new()
	column.add_child(tabs)
	for entry in [["overview", "Кафе и гости"], ["stations", "Кухня"], ["decor", "Украшения"], ["star", "Первая звезда"]]:
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
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var service = game.service
	var progress = service.progress
	var host: bool = not game.session.is_guest()
	if not host: label(content, "Общие покупки и проверку подтверждает хозяин кафе. Обучать бригады можно вместе.", 15)
	match tab:
		"overview":
			label(content, progress.objective(service.stations, service.served, service.open_for_business), 23)
			button(content, "Закрыть приём гостей" if service.open_for_business else "Открыть кафе", func(): send({"action": "business"}), host and not progress.busy())
			label(content, "Посетитель примерно каждые %.0f с. Уже принятые заказы выполняются и после закрытия." % progress.arrival_interval())
			label(content, "СПРОС С МОМЕНТА ОТКРЫТИЯ", 19)
			for dish in progress.available_dishes():
				var counts: Dictionary = progress.demand.get(dish, {})
				var known := 0
				for station in service.stations:
					if station.recipes.has(dish): known += 1
				label(content, "%s · умеют %d бригад\nПодано: %d    Ушли без блюда: %d    Все заняты: %d" % [Definition.DISHES[dish], known, counts.get("served", 0), counts.get("untrained", 0), counts.get("busy", 0)])
			label(content, "Гости выбирают из открытых блюд, даже если кухня ещё не обучена. Необслуженный гость не снижает популярность.", 15)
			button(content, "Сохранить кафе", func(): send({"action": "save"}), host)
			if confirm_reset:
				label(content, "Начать заново? Покупки и обучение этого прохождения будут сброшены.")
				button(content, "Да, открыть новое кафе", func(): send({"action": "new_cafe"}, true), host and not progress.busy() and not service.any_training())
			else: button(content, "Новое прохождение…", func(): confirm_reset = true; rebuild(), host and not progress.busy() and not service.any_training())
		"stations":
			label(content, "Каждая станция приходит со своей бригадой. Покажи ей каждое блюдо лично.", 19)
			var can_buy: bool = host and not progress.busy()
			button(content, "Новая тяп-ляп стойка + повар · 120", func(): send({"action": "buy", "kind": "counter"}), can_buy and progress.cash >= P.COUNTER_PRICE and service.stations.filter(func(s): return s.type_id == "counter").size() < (3 if progress.expanded else 2))
			for station in service.stations:
				var id: int = station.station_id
				label(content, "СТАНЦИЯ %d · %s" % [id, Definition.TYPES[station.type_id].title], 20)
				for dish in station.dishes():
					var record: Dictionary = station.recipes.get(dish, {})
					label(content, Definition.DISHES[dish] + (" · %s · %.1f с" % [record.get("quality", {}).get("grade", "?"), record.get("duration", 0)] if not record.is_empty() else " · ждёт первого показа"))
				if station.type_id == "counter":
					if "sauce_ramp" in station.upgrades: label(content, "✓ Соусный жёлоб установлен · для нового способа запиши новый показ", 15)
					else:
						button(content, "Соусный жёлоб сбоку · 75", func(): send({"action": "buy", "kind": "upgrade", "station": id}), can_buy and progress.cash >= P.UPGRADE_PRICE and station.state == "idle")
						label(content, "Наклонный жёлоб с соусом и площадкой внизу. Ещё один способ приготовить сосиску. Старый показ сохраняется.", 15)
			label(content, "ПОСЛЕ ПЕРВОЙ ЗВЕЗДЫ", 20)
			button(content, "Расширить зал · 180" if not progress.expanded else "✓ Зал расширен", func(): send({"action": "buy", "kind": "expansion"}), can_buy and progress.stars > 0 and not progress.expanded and progress.cash >= P.EXPANSION_PRICE)
			label(content, "Открывает место для третьей стойки и отдельной кухни на двоих.", 15)
			button(content, "Мясо и макароны + два повара · 250", func(): send({"action": "buy", "kind": "kitchen"}), can_buy and progress.expanded and service.by_id(4) == null and progress.cash >= P.KITCHEN_PRICE)
		"decor":
			label(content, "Больше уюта — больше гостей", 23)
			label(content, "Украшения навсегда повышают популярность. При 30 можно претендовать на первую звезду.")
			for id in P.DECOR:
				var key: String = id
				var item: Dictionary = P.DECOR[id]
				button(content, ("✓ " if id in progress.decorations else "") + "%s · %d · +%d популярности" % [item.name, item.price, item.popularity], func(): send({"action": "buy", "kind": "decor", "item": key}), host and not progress.busy() and not id in progress.decorations and progress.cash >= item.price)
				label(content, item.description, 15)
		"star":
			label(content, "ПЕРВАЯ ЗВЕЗДА · ПРИЁМ ИНСПЕКТОРА", 23)
			if not progress.result.is_empty(): label(content, progress.result, 20)
			for requirement in progress.star_requirements(service.stations, service.served): label(content, ("✓ " if requirement.done else "○ ") + requirement.text)
			label(content, "1. Личный показ: картофель на B или лучше за 2 минуты. Инспектор ждёт у станции №1. Рабочий рецепт остаётся прежним.\n2. Бригады: девять заказов — по три каждого блюда. За 4 минуты обслужить минимум восемь, из них шесть — на B или лучше.\nДелегация ждёт свободную обученную станцию. Кафе временно принимает только её заказы.")
			var estimate := 0.0
			for dish in P.DISHES:
				var times: Array = []
				for station in service.stations:
					if station.recipes.has(dish): times.append(float(station.recipes[dish].duration))
				if not times.is_empty(): estimate += float(times.min()) * 3.0
			label(content, "Объём готовки по самым быстрым записям: %.0f с. Бригады работают параллельно; подход гостей тоже занимает время." % estimate, 15)
			label(content, "Награда: звезда, 200 денег, доступ к расширению и кухне на двоих. Повторная попытка бесплатна.")
			button(content, "Пригласить инспектора", func(): send({"action": "banquet"}, true), host and progress.can_attempt(service.stations, service.served) and not service.any_training())
			if progress.busy(): button(content, "Прервать проверку и подготовиться ещё", func(): send({"action": "cancel_banquet"}, true), host)
	scroll.set_deferred("scroll_vertical", offset)
