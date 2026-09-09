extends SceneTree
## Native API contract + simulated callbacks. Does not claim a live Steam test.
const Scene = preload("res://scenes/cafe.tscn")
const Lobby = preload("res://scripts/steam_lobby.gd")
class TestLobby extends "res://scripts/steam_lobby.gd":
	var starts: Array = []
	func _start_peer(joining: bool) -> bool:
		starts.append(joining)
		return true
class FakeSteam extends RefCounted:
	signal lobby_created(result: int, id: int)
	signal lobby_joined(id: int, permissions: int, locked: bool, response: int)
	signal join_requested(id: int, friend_id: int)
	signal join_game_requested(friend_id: int, command: String)
	signal lobby_chat_update(id: int, changed: int, by: int, state: int)
	signal overlay_toggled(active: bool, initiated: bool, app: int)
	var data := {}
	var requests: Array = []
	var left: Array = []
	var invites: Array = []
	var presence := {}
	var owner := 100
	var creates := 0
	func getSteamID() -> int: return 100
	func getPersonaName() -> String: return "Steam Cook"
	func getLaunchCommandLine() -> String: return ""
	func initRelayNetworkAccess() -> void: pass
	func run_callbacks() -> void: pass
	func createLobby(kind: int, limit: int) -> void:
		assert(kind == 1 and limit == 4)
		creates += 1
	func setLobbyData(id: int, key: String, value: String) -> void:
		if not data.has(id): data[id] = {}
		data[id][key] = value
	func getLobbyData(id: int, key: String) -> String: return data.get(id, {}).get(key, "")
	func setLobbyJoinable(_id: int, _value: bool) -> void: pass
	func getLobbyOwner(_id: int) -> int: return owner
	func getNumLobbyMembers(_id: int) -> int: return 2
	func setRichPresence(key: String, value: String) -> void: presence[key] = value
	func clearRichPresence() -> void: presence.clear()
	func joinLobby(id: int) -> void: requests.append(id)
	func leaveLobby(id: int) -> void: left.append(id)
	func activateGameOverlayInviteDialog(id: int) -> void: invites.append(id)
var failed := false
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		printerr("FAIL: ", message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	check(Engine.has_singleton("Steam"), "native Steam singleton loaded in stock Godot")
	var native := Engine.get_singleton("Steam")
	for method in ["steamInitEx", "createLobby", "joinLobby", "leaveLobby", "setLobbyData", "getLobbyData", "getLobbyOwner", "getSteamID", "getNumLobbyMembers", "getLobbyMemberByIndex", "getFriendPersonaName", "setRichPresence", "clearRichPresence", "run_callbacks", "initRelayNetworkAccess", "activateGameOverlayInviteDialog", "getLaunchCommandLine"]:
		check(native.has_method(method), "native method " + method)
	for event in ["lobby_created", "lobby_joined", "join_requested", "join_game_requested", "lobby_chat_update", "overlay_toggled"]:
		check(native.has_signal(event), "native signal " + event)
	var peer = ClassDB.instantiate("SteamMultiplayerPeer")
	check(peer is MultiplayerPeer, "Steam peer implements Godot multiplayer")
	for method in ["create_host", "create_client", "get_steam_id_for_peer_id", "set_server_relay", "set_no_nagle"]:
		check(peer.has_method(method), "native peer method " + method)
	peer = null
	check(FileAccess.get_file_as_string("res://steam_appid.txt").strip_edges() == "480", "Spacewar file")
	check(ProjectSettings.get_setting("steam/initialization/app_data/app_id") == 480, "early initialization uses same App ID")
	check(Lobby.parse_lobby("-- +connect_lobby 109775242563823456") == 109775242563823456, "64-bit launch lobby")
	check(Lobby.parse_lobby("+connect_lobby -2") == 0 and Lobby.parse_lobby("+connect_lobby huh") == 0, "invalid launch arguments")
	var game = Scene.instantiate()
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.steam.free()
	var lobby := TestLobby.new()
	game.steam = lobby
	game.add_child(lobby)
	var fake := FakeSteam.new()
	lobby.setup(game, fake)
	await process_frame
	check(fake.creates == 1, "automatic friends lobby")
	lobby.invite_friends()
	fake.lobby_created.emit(1, 10)
	fake.lobby_joined.emit(10, 0, false, 1)
	check(lobby.starts == [false], "create + enter callback starts host only once")
	check(fake.invites == [10] and fake.presence.connect == "+connect_lobby 10", "overlay invite and rich presence")
	check(fake.data[10].game == Lobby.GAME_KEY and fake.data[10].protocol == Lobby.PROTOCOL, "Spacewar lobbies isolated by game + protocol")
	fake.join_requested.emit(20, 200)
	fake.lobby_joined.emit(20, 0, false, 1)
	check(10 in fake.left and 20 in fake.left and lobby.starts.size() == 1, "reject unrelated Spacewar lobby")
	fake.data[30] = {"game": Lobby.GAME_KEY, "protocol": Lobby.PROTOCOL, "host": "200"}
	fake.owner = 200
	fake.join_game_requested.emit(200, "+connect_lobby 30")
	fake.lobby_joined.emit(30, 0, false, 1)
	check(lobby.starts == [false, true] and lobby.lobby_host == 200, "rich invite starts client to authenticated lobby owner")
	fake.overlay_toggled.emit(true, true, 480)
	check(game.input_blocked(), "overlay captures input")
	fake.overlay_toggled.emit(false, true, 480)
	check(not game.input_blocked(), "closing overlay restores input")
	fake.owner = 300
	fake.lobby_chat_update.emit(30, 200, 200, 2)
	check(lobby.lobby_id == 0 and fake.presence.is_empty(), "host departure clears lobby, no unintended host migration")
	lobby.join_lobby(40)
	lobby.deadline = Time.get_ticks_msec() - 1
	lobby._process(0)
	fake.lobby_joined.emit(40, 0, false, 1)
	check(lobby.lobby_id == 0 and 40 in fake.left, "timeout rejects late success callback")
	if not failed: print("PASS: native Steam API, invite lifecycle, lobby isolation, overlay and timeouts (simulated backend)")
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
