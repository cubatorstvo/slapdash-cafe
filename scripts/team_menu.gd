extends CanvasLayer
signal start_requested(mode: String, ids: Array, peer_id: int)
signal network_requested(action: String, address: String, port: int, player_name: String)
signal steam_requested(action: String)
signal closed
var panel: PanelContainer
var net_panel: PanelContainer
var mode: OptionButton
var employees: Array = []
var peers: OptionButton
var description: Label
var net_status: Label
var address: LineEdit
var player_name: LineEdit
var port: SpinBox

func _ready() -> void:
	layer = 15
	panel = _panel(620, 520)
	var box := _column(panel)
	_label(box, "СТОЛ II · СТЕЙК С МАКАРОНАМИ", 24)
	_label(box, "Одна кухня, две роли, общие солонка и лопатка.")
	mode = OptionButton.new()
	box.add_child(mode)
	mode.add_item("По ролям — сначала первый дубль, затем второй")
	mode.add_item("Вместе — с участником онлайн-сессии")
	for i in range(2):
		_label(box, "Сотрудник для роли %d" % (i + 1))
		var selector := OptionButton.new()
		box.add_child(selector)
		employees.append(selector)
	_label(box, "Напарник для режима «Вместе» (сессия — F2)")
	peers = OptionButton.new()
	box.add_child(peers)
	description = _label(box, "В каждой роли можно делать любую часть блюда.\nEnter завершает дубль. Backspace перезаписывает текущую роль.\nКлоны наблюдают; сохранённая бригада работает на стойке 4.")
	_button(box, "Начать показ", _start)
	_button(box, "Закрыть", close)
	panel.hide()
	net_panel = _panel(620, 650)
	box = _column(net_panel)
	_label(box, "ИГРАТЬ С ДРУЗЬЯМИ", 23)
	_button(box, "Пригласить друга через Steam", func(): steam_requested.emit("invite"))
	_button(box, "Создать Steam-кафе", func(): steam_requested.emit("host"))
	_label(box, "Shift+Tab → друзья → пригласить в игру", 17)
	_label(box, "Прямое подключение по IP (для локальной проверки)", 15)
	player_name = LineEdit.new()
	player_name.text = "Повар"
	player_name.placeholder_text = "Имя игрока"
	box.add_child(player_name)
	address = LineEdit.new()
	address.text = "127.0.0.1"
	address.placeholder_text = "IP хоста"
	box.add_child(address)
	port = SpinBox.new()
	port.min_value = 1024
	port.max_value = 65535
	port.value = 27666
	box.add_child(port)
	_button(box, "Создать сессию", func(): network_requested.emit("host", address.text, int(port.value), player_name.text))
	_button(box, "Подключиться", func(): network_requested.emit("join", address.text, int(port.value), player_name.text))
	_button(box, "Отключиться", func(): network_requested.emit("leave", "", 0, ""))
	net_status = _label(box, "Steam: проверяю подключение…")
	net_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	net_status.custom_minimum_size = Vector2(540, 62)
	_button(box, "Вернуться в кафе", close)
	net_panel.hide()

func _panel(width: float, height: float) -> PanelContainer:
	var result := PanelContainer.new()
	add_child(result)
	result.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	result.offset_left = -width / 2
	result.offset_right = width / 2
	result.offset_top = -height / 2
	result.offset_bottom = height / 2
	var style := StyleBoxFlat.new()
	style.bg_color = Color("203b43")
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	result.add_theme_stylebox_override("panel", style)
	return result

func _column(parent: Control) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	parent.add_child(box)
	return box

func _label(parent: Control, value: String, size := 17) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _button(parent: Control, value: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = value
	button.pressed.connect(callback)
	parent.add_child(button)

func show_training(clones: Array, members: Dictionary, own_id := 1) -> void:
	for role in range(2):
		employees[role].clear()
		for clone in clones: employees[role].add_item(clone.name, clone.id)
		if clones.size() > role: employees[role].select(role)
	peers.clear()
	for id in members:
		if int(id) != own_id: peers.add_item(str(members[id]), int(id))
	if peers.item_count == 0: peers.add_item("Нет подключённых игроков", -1)
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _start() -> void:
	if employees[0].item_count < 2:
		description.text = "Нужны два сотрудника. Создай второго в клономате."
		return
	var ids := [employees[0].get_selected_id(), employees[1].get_selected_id()]
	if ids[0] == ids[1]:
		description.text = "Выбери двух разных сотрудников."
		return
	if mode.selected == 1 and peers.get_selected_id() < 1:
		description.text = "Сначала подключи напарника через F2. Затем выбери его в списке."
		return
	start_requested.emit("roles" if mode.selected == 0 else "together", ids, peers.get_selected_id())

func close() -> void:
	panel.hide()
	net_panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()

func opened() -> bool: return panel.visible or net_panel.visible
