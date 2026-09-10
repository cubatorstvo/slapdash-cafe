extends Node
## Steam owns lobby membership and invitations; Session owns the shared cafe.
const APP_ID := 480
const GAME_KEY := "slapdash-cafe"
const PROTOCOL := "slapdash-cafe-stations-6"
const MAX_PLAYERS := 4
var game: Node3D
var api: Object
var available := false
var lobby_id := 0
var lobby_host := 0
var requested_lobby := 0
var creating := false
var deadline := 0
var invite_after_create := false
var overlay_open := false
var status := "Steam не запущен. Можно играть одному или подключиться по IP."

func setup(root_game: Node3D, backend: Object = null) -> void:
	game = root_game
	if backend != null: api = backend
	elif Engine.has_singleton("Steam"): api = Engine.get_singleton("Steam")
	if api == null or DisplayServer.get_name() == "headless" and backend == null:
		game.menu.net_status.text = status
		return
	if backend == null:
		# Startup initialization happens before the renderer, allowing the overlay to hook it.
		if not api.isSteamRunning():
			game.menu.net_status.text = status
			return
		var initialized: Dictionary = api.steamInitEx(APP_ID, false)
		if int(initialized.get("status", -1)) != 0:
			_set_status("Steam: " + str(initialized.get("verbal", "не удалось инициализировать Steamworks")))
			return
	available = true
	api.lobby_created.connect(_created)
	api.lobby_joined.connect(_joined)
	api.join_requested.connect(_invite)
	api.join_game_requested.connect(_rich_invite)
	api.lobby_chat_update.connect(_membership)
	api.overlay_toggled.connect(_overlay)
	api.initRelayNetworkAccess()
	game.menu.player_name.text = api.getPersonaName()
	var launch := parse_lobby(" ".join(OS.get_cmdline_args()) + " " + " ".join(OS.get_cmdline_user_args()) + " " + api.getLaunchCommandLine())
	if launch > 0: join_lobby.call_deferred(launch)
	else: create_lobby.call_deferred()

func _process(_delta: float) -> void:
	if not available: return
	api.run_callbacks()
	if deadline > 0 and Time.get_ticks_msec() > deadline:
		leave_lobby()
		game.session.leave("Steam: время подключения истекло. Повтори приглашение.")

static func parse_lobby(command: String) -> int:
	var parts := command.split(" ", false)
	for i in range(parts.size() - 1):
		if parts[i] == "+connect_lobby" and parts[i + 1].is_valid_int():
			var value := int(parts[i + 1])
			if value > 0: return value
	return 0

func create_lobby() -> void:
	if not available:
		_set_status(status)
		return
	if creating or lobby_id > 0: return
	if game.service.any_training():
		_set_status("Сначала заверши или отмени текущий показ.")
		return
	if game.session.online(): game.session.leave("")
	creating = true
	deadline = Time.get_ticks_msec() + 20000
	_set_status("Steam: создаю кафе для друзей…")
	api.createLobby(1, MAX_PLAYERS) # k_ELobbyTypeFriendsOnly

func invite_friends() -> void:
	if not available:
		_set_status("Запусти Steam и перезапусти игру для приглашений и оверлея.")
		return
	if lobby_id == 0:
		invite_after_create = true
		create_lobby()
		return
	api.activateGameOverlayInviteDialog(lobby_id)

func join_lobby(id: int) -> void:
	if not available or id <= 0 or id == lobby_id or id == requested_lobby: return
	game.session.leave("")
	requested_lobby = id
	deadline = Time.get_ticks_msec() + 20000
	_set_status("Steam: подключаюсь к кафе друга…")
	api.joinLobby(id)

func _created(result: int, id: int) -> void:
	if not creating:
		if result == 1: api.leaveLobby(id)
		return
	creating = false
	deadline = 0
	if result != 1:
		_set_status("Steam: не удалось создать лобби (код %d)." % result)
		return
	lobby_id = id
	lobby_host = api.getSteamID()
	api.setLobbyData(id, "game", GAME_KEY)
	api.setLobbyData(id, "protocol", PROTOCOL)
	api.setLobbyData(id, "host", str(lobby_host))
	api.setLobbyData(id, "name", api.getPersonaName() + " · Slapdash Cafe")
	api.setLobbyJoinable(id, true)
	if not _start_peer(false): return
	_presence()
	_set_status("Steam: кафе открыто для друзей · Shift+Tab → пригласить.")
	if invite_after_create:
		invite_after_create = false
		invite_friends()

func _joined(id: int, _permissions: int, _locked: bool, response: int) -> void:
	if id == lobby_id: return # createLobby also emits lobby_joined
	if id != requested_lobby:
		if response == 1: api.leaveLobby(id)
		return
	requested_lobby = 0
	deadline = 0
	if response != 1:
		_set_status("Steam: вход в лобби не удался (код %d)." % response)
		return
	if api.getLobbyData(id, "game") != GAME_KEY or api.getLobbyData(id, "protocol") != PROTOCOL:
		api.leaveLobby(id)
		_set_status("Это лобби другой игры или версии. Оба обновите Slapdash Cafe.")
		return
	lobby_host = int(api.getLobbyData(id, "host"))
	if lobby_host <= 0 or api.getLobbyOwner(id) != lobby_host or lobby_host == api.getSteamID():
		api.leaveLobby(id)
		_set_status("Хост уже вышел. Попроси новое приглашение.")
		return
	lobby_id = id
	if not _start_peer(true): return
	_presence()

func _start_peer(joining: bool) -> bool:
	var peer: MultiplayerPeer = ClassDB.instantiate("SteamMultiplayerPeer")
	peer.set("server_relay", true)
	peer.set("no_nagle", true)
	var result: int = peer.create_client(lobby_host, 0) if joining else peer.create_host(0)
	if result != OK:
		peer.close()
		leave_lobby()
		_set_status("Steam P2P: " + error_string(result))
		return false
	# Only the host is contacted. All game authority and relay remain on that host.
	game.session.attach_peer(peer, joining, api.getPersonaName(), "steam")
	return true

func accepts_peer(peer_id: int) -> bool:
	if lobby_id == 0: return false
	var peer: MultiplayerPeer = game.multiplayer.multiplayer_peer
	var steam_id: int = peer.get_steam_id_for_peer_id(peer_id)
	var count: int = api.getNumLobbyMembers(lobby_id)
	for i in range(count):
		if api.getLobbyMemberByIndex(lobby_id, i) == steam_id: return true
	return false

func peer_name(peer_id: int) -> String:
	var peer: MultiplayerPeer = game.multiplayer.multiplayer_peer
	return api.getFriendPersonaName(peer.get_steam_id_for_peer_id(peer_id))

func _invite(id: int, _friend: int) -> void: join_lobby(id)
func _rich_invite(_friend: int, command: String) -> void:
	var id := parse_lobby(command)
	if id > 0: join_lobby(id)

func _membership(id: int, _changed: int, _by: int, _state: int) -> void:
	if id != lobby_id: return
	if api.getLobbyOwner(id) != lobby_host:
		game.session.leave("Хост вышел из кафе. Можно создать свою сессию через F2.")
	else: _presence()

func _presence() -> void:
	api.setRichPresence("connect", "+connect_lobby %d" % lobby_id)
	api.setRichPresence("status", "Готовим тяп-ляп")
	api.setRichPresence("steam_player_group", str(lobby_id))
	api.setRichPresence("steam_player_group_size", str(api.getNumLobbyMembers(lobby_id)))

func leave_lobby() -> void:
	if not available: return
	creating = false
	deadline = 0
	requested_lobby = 0
	invite_after_create = false
	if lobby_id > 0: api.leaveLobby(lobby_id)
	lobby_id = 0
	lobby_host = 0
	api.clearRichPresence()

func _overlay(active: bool, _user_initiated: bool, _app_id: int) -> void:
	overlay_open = active
	game.sync_mouse_mode()
	if active: game.session.suspend_input()

func _set_status(value: String) -> void:
	status = value
	if game != null: game.session._status(value)

func _exit_tree() -> void:
	leave_lobby()
