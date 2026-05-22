extends Node
## EffortBridge — subscribes to the sidecar WebSocket and emits typed signals.
##
## This is the only place in the engine that talks to the sidecar. Everything
## else listens to these signals. Swapping the transport (WS → native BLE on
## mobile, → Web Bluetooth in browser) only requires changing this file.
##
## Event names are device-agnostic. The same signal fires whether the source
## is a bike trainer, rowing erg, or treadmill — the game doesn't care.

signal power_changed(watts: int)
signal heart_rate_changed(bpm: int)
signal cadence_changed(rpm: int)         # bike-specific
signal stroke_rate_changed(spm: int)     # rower-specific
signal effort_surge_started(peak_watts: int, baseline_watts: int)
signal effort_surge_ended()
signal hr_zone_changed(from_zone: int, to_zone: int)
signal effort_pulse(np_5s: int, watts_per_kg: float)
signal device_connected(kind: String, name: String)
signal connection_state_changed(connected: bool)

const DEFAULT_SIDECAR_URL := "ws://localhost:8421"
const SIDECAR_URL_ENV := "ROGUERGLIKE_SIDECAR_URL"

var _socket: WebSocketPeer
var _connected := false


func _ready() -> void:
	_socket = WebSocketPeer.new()
	_connect()


func _connect() -> void:
	var sidecar_url := OS.get_environment(SIDECAR_URL_ENV)
	if sidecar_url.is_empty():
		sidecar_url = DEFAULT_SIDECAR_URL
	var err := _socket.connect_to_url(sidecar_url)
	if err != OK:
		push_warning("Sidecar connection failed: %s" % err)


func _process(_delta: float) -> void:
	_socket.poll()
	var state := _socket.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not _connected:
			_connected = true
			connection_state_changed.emit(true)
		while _socket.get_available_packet_count() > 0:
			_handle_packet(_socket.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		if _connected:
			_connected = false
			connection_state_changed.emit(false)


func _handle_packet(text: String) -> void:
	var json := JSON.new()
	if json.parse(text) != OK:
		return
	var event = json.data
	if typeof(event) != TYPE_DICTIONARY:
		return

	match event.get("type", ""):
		"power":
			power_changed.emit(int(event.data.watts))
		"heart_rate":
			heart_rate_changed.emit(int(event.data.bpm))
		"cadence":
			cadence_changed.emit(int(event.data.rpm))
		"stroke_rate":
			stroke_rate_changed.emit(int(event.data.spm))
		"effort_surge_started":
			effort_surge_started.emit(int(event.data.peak_watts), int(event.data.baseline_watts))
		"effort_surge_ended":
			effort_surge_ended.emit()
		"hr_zone_changed":
			hr_zone_changed.emit(int(event.data.from), int(event.data.to))
		"effort_pulse":
			effort_pulse.emit(int(event.data.np_5s), float(event.data.watts_per_kg))
		"device_connected":
			device_connected.emit(str(event.data.kind), str(event.data.name))
