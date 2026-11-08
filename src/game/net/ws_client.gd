class_name HimoyuWSClient
extends Node

signal snapshot_received(snapshot: Dictionary)
signal connection_changed(connected: bool, detail: String)

const RECONNECT_INTERVAL_MS := 2000

var url := "ws://127.0.0.1:8000/ws"

var _socket: WebSocketPeer = null
var _connected := false
var _next_reconnect_at := 0
var _last_state := WebSocketPeer.STATE_CLOSED


func _ready() -> void:
	_open()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()

	if _socket == null:
		if now >= _next_reconnect_at:
			_open()
		return

	_socket.poll()
	var ready_state := _socket.get_ready_state()

	if ready_state == WebSocketPeer.STATE_CONNECTING:
		if _last_state != ready_state:
			connection_changed.emit(false, "正在连接 %s" % url)
	elif ready_state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			connection_changed.emit(true, "已连接 %s" % url)
		while _socket.get_available_packet_count() > 0:
			var packet := _socket.get_packet()
			_handle_packet(packet.get_string_from_utf8())
	elif ready_state == WebSocketPeer.STATE_CLOSED:
		if _connected or _last_state != ready_state:
			_connected = false
			connection_changed.emit(false, "连接已断开，2 秒后重连")
			_next_reconnect_at = now + RECONNECT_INTERVAL_MS
		if now >= _next_reconnect_at:
			_socket = null
			_last_state = ready_state
			_open()
			return

	_last_state = ready_state


func _open() -> void:
	_socket = WebSocketPeer.new()
	var err := _socket.connect_to_url(url)
	if err != OK:
		_socket = null
		_connected = false
		_next_reconnect_at = Time.get_ticks_msec() + RECONNECT_INTERVAL_MS
		connection_changed.emit(false, "连接失败：%s" % error_string(err))


func _handle_packet(text: String) -> void:
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return
	var message: Dictionary = data
	if str(message.get("type", "")) == "snapshot":
		snapshot_received.emit(message)
