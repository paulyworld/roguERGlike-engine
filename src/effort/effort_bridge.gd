extends Node
## EffortBridge — subscribes to the sidecar WebSocket and emits typed signals.
##
## This is the only place in the engine that talks to the sidecar. Everything
## else listens to these signals. Swapping the transport (WS → native BLE on
## mobile, → Web Bluetooth in browser) only requires changing this file.
##
## Event names are device-agnostic. The same signal fires whether the source
## is a bike trainer, rowing erg, or treadmill — the game doesn't care.
##
## Inbound events (sidecar → engine) fan out as signals. Outbound commands
## (engine → sidecar, e.g. set_target_power) are sent via the methods near
## the bottom of this file. The sidecar must have been launched with
## --allow-trainer-control for commands to have effect; otherwise it logs
## them and drops.

signal power_changed(watts: int)
signal heart_rate_changed(bpm: int)
signal cadence_changed(rpm: int)         # bike-specific
signal stroke_rate_changed(spm: int)     # rower-specific
signal effort_surge_started(peak_watts: int, baseline_watts: int)
signal effort_surge_ended()
signal hr_zone_changed(from_zone: int, to_zone: int)
signal effort_pulse(np_5s: int, watts_per_kg: float)
signal device_connected(kind: String, name: String)
signal device_disconnected(kind: String, name: String)
signal device_capabilities_changed(
	kind: String,
	name: String,
	target_power: bool,
	indoor_bike_simulation: bool,
)
signal control_acquired(kind: String, name: String)
signal control_released(kind: String, name: String, reason: String)
signal target_power_set(watts: int, accepted: bool, reason: String)
signal connection_state_changed(connected: bool)

const DEFAULT_SIDECAR_URL := "ws://localhost:8421"
const SIDECAR_URL_ENV := "ROGUERGLIKE_SIDECAR_URL"

# Whether the currently-attached bike trainer advertises Set Target Power on
# its FTMS Feature characteristic. Game UI should gate ERG features on this
# being true. Set by the most recent `device_capabilities` event; reset to
# false on `device_disconnected`.
var supports_target_power: bool = false

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
			supports_target_power = false
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
		"device_disconnected":
			supports_target_power = false
			device_disconnected.emit(str(event.data.kind), str(event.data.name))
		"device_capabilities":
			supports_target_power = bool(event.data.get("target_power", false))
			device_capabilities_changed.emit(
				str(event.data.kind),
				str(event.data.name),
				bool(event.data.get("target_power", false)),
				bool(event.data.get("indoor_bike_simulation", false)),
			)
		"control_acquired":
			control_acquired.emit(str(event.data.kind), str(event.data.name))
		"control_released":
			control_released.emit(
				str(event.data.kind),
				str(event.data.name),
				str(event.data.get("reason", "")),
			)
		"target_power_set":
			target_power_set.emit(
				int(event.data.watts),
				bool(event.data.accepted),
				str(event.data.get("reason", "")),
			)


# --- outbound commands (engine → sidecar) -------------------------------
#
# These are only meaningful when the sidecar was launched with
# --allow-trainer-control. Without that flag the sidecar logs the command
# and drops it. Use `supports_target_power` (set from device_capabilities)
# to gate ERG UI client-side; the sidecar's safety clamps still apply on
# whatever wattage you pass.


func _send_command(payload: Dictionary) -> void:
	if _socket == null:
		return
	if _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		push_warning("EffortBridge: WS not open; dropping command %s" % payload.get("type", "?"))
		return
	_socket.send_text(JSON.stringify(payload))


## Request the sidecar set the trainer's ERG target wattage. The sidecar
## clamps to its configured `[--min-target-power, --max-target-power]`
## bounds; the actual value applied is reported back via `target_power_set`.
func set_target_power(watts: int) -> void:
	_send_command({"type": "set_target_power", "watts": watts})


## Re-acquire control of a connected bike trainer (sidecar issues
## Request Control + Start). Called automatically at sidecar startup when
## --allow-trainer-control is set; useful here for re-acquiring after a
## prior `stop` or `release_control`.
func start() -> void:
	_send_command({"type": "start"})


## Pause/stop the workout. The sidecar issues FTMS Stop on the trainer and
## marks the control client as no longer controlling; subsequent
## `set_target_power` calls are rejected (with reason "not controlling")
## until a `start` re-acquires.
func stop() -> void:
	_send_command({"type": "stop"})


## Stop the workout AND explicitly release Control Point ownership. Same
## wire effect as `stop`, but the engine is signaling end-of-session
## rather than a temporary pause.
func release_control() -> void:
	_send_command({"type": "release_control"})
