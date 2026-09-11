extends Node
## Test-only handshake. Same node path on every process so RPCs meet.
var received := {}

func send(stage_id: String) -> void:
	_store(multiplayer.get_unique_id(), stage_id)
	_receive.rpc(stage_id)

@rpc("any_peer", "call_remote", "reliable")
func _receive(stage_id: String) -> void:
	_store(multiplayer.get_remote_sender_id(), stage_id)

func _store(peer: int, stage_id: String) -> void:
	if peer <= 0 or stage_id.is_empty(): return
	if not received.has(stage_id): received[stage_id] = {}
	if received[stage_id].has(peer): return
	received[stage_id][peer] = true
	print("ACK: %s from %d" % [stage_id, peer])

func has_from(stage_id: String, peer: int) -> bool:
	return received.get(stage_id, {}).has(peer)

func dump() -> String:
	return str(received)
