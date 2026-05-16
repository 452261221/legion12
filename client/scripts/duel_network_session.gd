extends Node
class_name DuelNetworkSession

signal status_changed(text: String)
signal session_changed(active: bool, is_host: bool, local_player_id: int)
signal remote_peer_changed(peer_count: int)
signal remote_formal_deck_selection_received(sender_peer_id: int, payload: Dictionary)
signal opening_prompt_received(payload: Dictionary)
signal opening_response_received(sender_peer_id: int, payload: Dictionary)
signal start_duel_received(duel_path: String, game_options: Dictionary, duel_label: String, duel_seed: int)
signal host_command_requested(sender_peer_id: int, player_id: int, command_type: String, payload: Dictionary, command_index: int)
signal command_applied_received(player_id: int, command_type: String, payload: Dictionary, expected_hash: String, command_index: int)
signal command_failed_received(command_type: String, command_index: int, code: String, message: String)
signal resync_requested(sender_peer_id: int, reason: String, command_index: int)
signal resync_payload_received(payload: Dictionary)

const DEFAULT_PORT := 24567

var _is_host := false
var _local_player_id := 0
var _remote_peer_ids: Array[int] = []


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_session(port: int = DEFAULT_PORT) -> Dictionary:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 1)
	if err != OK:
		_emit_status("创建房间失败：%s" % _network_error_text(err))
		return {"ok": false, "error": err}
	multiplayer.multiplayer_peer = peer
	_is_host = true
	_local_player_id = 0
	_remote_peer_ids.clear()
	_emit_status("房主已开启，端口 %s，等待对手加入" % port)
	_emit_session_changed()
	return {"ok": true}


func join_session(address: String, port: int = DEFAULT_PORT) -> Dictionary:
	_close_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		_emit_status("加入房间失败：%s" % _network_error_text(err))
		return {"ok": false, "error": err}
	multiplayer.multiplayer_peer = peer
	_is_host = false
	_local_player_id = 1
	_remote_peer_ids.clear()
	_emit_status("正在连接 %s:%s" % [address, port])
	_emit_session_changed()
	return {"ok": true}


func disconnect_session() -> void:
	_close_peer()
	_emit_status("已断开联机，当前为本地模式")


func is_network_active() -> bool:
	return multiplayer.multiplayer_peer != null


func is_host_session() -> bool:
	return is_network_active() and _is_host


func get_local_player_id() -> int:
	return _local_player_id


func has_remote_peer() -> bool:
	return not _remote_peer_ids.is_empty()


func remote_peer_count() -> int:
	return _remote_peer_ids.size()


func get_host_join_addresses() -> Array[String]:
	var preferred: Array[String] = []
	var lan: Array[String] = []
	var others: Array[String] = []
	var seen := {}
	for raw_address in IP.get_local_addresses():
		var address := str(raw_address).strip_edges()
		if not _is_shareable_ipv4(address):
			continue
		if seen.has(address):
			continue
		seen[address] = true
		if _is_tailscale_ipv4(address):
			preferred.append(address)
		elif _is_private_ipv4(address):
			lan.append(address)
		else:
			others.append(address)
	var result: Array[String] = []
	result.append_array(preferred)
	result.append_array(lan)
	result.append_array(others)
	return result


func get_host_join_hint() -> String:
	var addresses := get_host_join_addresses()
	if addresses.is_empty():
		return "请让对方输入你的 Tailscale 或局域网 IPv4 地址。\n固定端口：%s" % DEFAULT_PORT
	var lines: Array[String] = ["对方在“加入房间”里输入以下任一 IP 即可："]
	for index in range(min(4, addresses.size())):
		lines.append(addresses[index])
	lines.append("固定端口：%s" % DEFAULT_PORT)
	return "\n".join(lines)


func broadcast_start_duel(duel_path: String, game_options: Dictionary, duel_label: String, duel_seed: int) -> void:
	if not is_host_session():
		return
	_rpc_start_duel.rpc(duel_path, game_options, duel_label, duel_seed)


func submit_formal_deck_selection(payload: Dictionary) -> void:
	if not is_network_active() or is_host_session():
		return
	_rpc_submit_formal_deck_selection.rpc_id(1, payload.duplicate(true))


func send_opening_prompt(payload: Dictionary) -> void:
	if not is_host_session():
		return
	_rpc_receive_opening_prompt.rpc(payload.duplicate(true))


func submit_opening_response(payload: Dictionary) -> void:
	if not is_network_active() or is_host_session():
		return
	_rpc_submit_opening_response.rpc_id(1, payload.duplicate(true))


func request_command(player_id: int, command_type: String, payload: Dictionary, command_index: int) -> void:
	if not is_network_active():
		return
	if is_host_session():
		emit_signal("host_command_requested", 1, player_id, command_type, payload.duplicate(true), command_index)
		return
	_rpc_submit_command.rpc_id(1, player_id, command_type, payload.duplicate(true), command_index)


func broadcast_applied_command(player_id: int, command_type: String, payload: Dictionary, expected_hash: String, command_index: int) -> void:
	if not is_host_session():
		return
	_rpc_apply_command.rpc(player_id, command_type, payload.duplicate(true), expected_hash, command_index)


func send_command_failed(peer_id: int, command_type: String, command_index: int, code: String, message: String) -> void:
	if not is_host_session():
		return
	_rpc_command_failed.rpc_id(peer_id, command_type, command_index, code, message)


func request_resync(reason: String, command_index: int) -> void:
	if not is_network_active() or is_host_session():
		return
	_rpc_request_resync.rpc_id(1, reason, command_index)


func send_resync_payload(peer_id: int, payload: Dictionary) -> void:
	if not is_host_session():
		return
	_rpc_receive_resync_payload.rpc_id(peer_id, payload.duplicate(true))


@rpc("authority", "reliable")
func _rpc_start_duel(duel_path: String, game_options: Dictionary, duel_label: String, duel_seed: int) -> void:
	emit_signal("start_duel_received", duel_path, game_options.duplicate(true), duel_label, duel_seed)


@rpc("any_peer", "reliable")
func _rpc_submit_formal_deck_selection(payload: Dictionary) -> void:
	if not is_host_session():
		return
	var sender_peer_id := multiplayer.get_remote_sender_id()
	emit_signal("remote_formal_deck_selection_received", sender_peer_id, payload.duplicate(true))


@rpc("authority", "reliable")
func _rpc_receive_opening_prompt(payload: Dictionary) -> void:
	emit_signal("opening_prompt_received", payload.duplicate(true))


@rpc("any_peer", "reliable")
func _rpc_submit_opening_response(payload: Dictionary) -> void:
	if not is_host_session():
		return
	var sender_peer_id := multiplayer.get_remote_sender_id()
	emit_signal("opening_response_received", sender_peer_id, payload.duplicate(true))


@rpc("any_peer", "reliable")
func _rpc_submit_command(player_id: int, command_type: String, payload: Dictionary, command_index: int) -> void:
	if not is_host_session():
		return
	var sender_peer_id := multiplayer.get_remote_sender_id()
	emit_signal("host_command_requested", sender_peer_id, player_id, command_type, payload.duplicate(true), command_index)


@rpc("authority", "reliable")
func _rpc_apply_command(player_id: int, command_type: String, payload: Dictionary, expected_hash: String, command_index: int) -> void:
	emit_signal("command_applied_received", player_id, command_type, payload.duplicate(true), expected_hash, command_index)


@rpc("authority", "reliable")
func _rpc_command_failed(command_type: String, command_index: int, code: String, message: String) -> void:
	emit_signal("command_failed_received", command_type, command_index, code, message)


@rpc("any_peer", "reliable")
func _rpc_request_resync(reason: String, command_index: int) -> void:
	if not is_host_session():
		return
	var sender_peer_id := multiplayer.get_remote_sender_id()
	emit_signal("resync_requested", sender_peer_id, reason, command_index)


@rpc("authority", "reliable")
func _rpc_receive_resync_payload(payload: Dictionary) -> void:
	emit_signal("resync_payload_received", payload.duplicate(true))


func _on_peer_connected(peer_id: int) -> void:
	if not _remote_peer_ids.has(peer_id):
		_remote_peer_ids.append(peer_id)
	_emit_status("对手已连接（peer=%s）" % peer_id)
	emit_signal("remote_peer_changed", _remote_peer_ids.size())


func _on_peer_disconnected(peer_id: int) -> void:
	_remote_peer_ids.erase(peer_id)
	if is_network_active():
		_emit_status("对手已断开（peer=%s）" % peer_id)
	emit_signal("remote_peer_changed", _remote_peer_ids.size())


func _on_connected_to_server() -> void:
	_emit_status("已连接房主，等待开始对局")


func _on_connection_failed() -> void:
	_close_peer()
	_emit_status("连接失败，已回到本地模式")


func _on_server_disconnected() -> void:
	_close_peer()
	_emit_status("房主已断开，已回到本地模式")


func _close_peer() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_is_host = false
	_local_player_id = 0
	_remote_peer_ids.clear()
	_emit_session_changed()
	emit_signal("remote_peer_changed", 0)


func _emit_status(text: String) -> void:
	emit_signal("status_changed", text)


func _emit_session_changed() -> void:
	emit_signal("session_changed", is_network_active(), _is_host, _local_player_id)


func _network_error_text(err: int) -> String:
	if err == ERR_CANT_CREATE:
		return "无法创建网络监听/连接（ERR_CANT_CREATE=20，常见原因是 Android 网络权限未开启或端口被占用）"
	return str(err)


func _is_shareable_ipv4(address: String) -> bool:
	if address.contains(":"):
		return false
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	var octets: Array[int] = []
	for part in parts:
		if part.is_empty() or not part.is_valid_int():
			return false
		var value := part.to_int()
		if value < 0 or value > 255:
			return false
		octets.append(value)
	if octets[0] == 0 or octets[0] == 127:
		return false
	if octets[0] == 169 and octets[1] == 254:
		return false
	return true


func _is_private_ipv4(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	var first := parts[0].to_int()
	var second := parts[1].to_int()
	if first == 10:
		return true
	if first == 172 and second >= 16 and second <= 31:
		return true
	if first == 192 and second == 168:
		return true
	return false


func _is_tailscale_ipv4(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	var first := parts[0].to_int()
	var second := parts[1].to_int()
	return first == 100 and second >= 64 and second <= 127
