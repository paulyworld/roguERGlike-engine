extends Control
## test_main — visualizes the live sidecar event stream.
##
## Subscribes to every signal on the EffortBridge autoload, updates on-screen
## labels, and mirrors each event to stdout so headless runs can be diffed.
## Proves the WebSocket contract works end-to-end against the sidecar's mock
## mode without any game logic in the way.

@onready var status_label: Label = %StatusLabel
@onready var power_label: Label = %PowerLabel
@onready var cadence_label: Label = %CadenceLabel
@onready var heart_rate_label: Label = %HeartRateLabel
@onready var device_label: Label = %DeviceLabel
@onready var derived_label: Label = %DerivedLabel


func _ready() -> void:
	EffortBridge.connection_state_changed.connect(_on_connection_changed)
	EffortBridge.device_connected.connect(_on_device_connected)
	EffortBridge.device_disconnected.connect(_on_device_disconnected)
	EffortBridge.device_capabilities_changed.connect(_on_device_capabilities_changed)
	EffortBridge.power_changed.connect(_on_power_changed)
	EffortBridge.cadence_changed.connect(_on_cadence_changed)
	EffortBridge.heart_rate_changed.connect(_on_heart_rate_changed)
	EffortBridge.effort_surge_started.connect(_on_surge_started)
	EffortBridge.effort_surge_ended.connect(_on_surge_ended)
	EffortBridge.hr_zone_changed.connect(_on_hr_zone_changed)
	EffortBridge.effort_pulse.connect(_on_effort_pulse)
	EffortBridge.control_acquired.connect(_on_control_acquired)
	EffortBridge.control_released.connect(_on_control_released)
	EffortBridge.target_power_set.connect(_on_target_power_set)
	EffortBridge.cadence_bailout_engaged.connect(_on_cadence_bailout_engaged)
	EffortBridge.cadence_bailout_disengaged.connect(_on_cadence_bailout_disengaged)
	print("[test_main] ready; waiting for sidecar on ", "ws://localhost:8421")


func _on_connection_changed(connected: bool) -> void:
	status_label.text = "Sidecar: " + ("CONNECTED" if connected else "disconnected")
	print("[test_main] connection_state_changed connected=", connected)


func _on_device_connected(kind: String, name: String) -> void:
	device_label.text = "Device: %s (%s)" % [name, kind]
	print("[test_main] device_connected kind=", kind, " name=", name)


func _on_power_changed(watts: int) -> void:
	power_label.text = "Power: %d W" % watts
	print("[test_main] power_changed watts=", watts)


func _on_cadence_changed(rpm: int) -> void:
	cadence_label.text = "Cadence: %d rpm" % rpm
	print("[test_main] cadence_changed rpm=", rpm)


func _on_heart_rate_changed(bpm: int) -> void:
	heart_rate_label.text = "HR: %d bpm" % bpm
	print("[test_main] heart_rate_changed bpm=", bpm)


func _on_surge_started(peak_watts: int, baseline_watts: int) -> void:
	derived_label.text = "SURGE peak=%d base=%d" % [peak_watts, baseline_watts]
	print("[test_main] effort_surge_started peak=", peak_watts, " base=", baseline_watts)


func _on_surge_ended() -> void:
	derived_label.text = "(no surge)"
	print("[test_main] effort_surge_ended")


func _on_hr_zone_changed(from_zone: int, to_zone: int) -> void:
	print("[test_main] hr_zone_changed from=", from_zone, " to=", to_zone)


func _on_effort_pulse(np_5s: int, watts_per_kg: float) -> void:
	print("[test_main] effort_pulse np_5s=", np_5s, " w/kg=", watts_per_kg)


func _on_device_disconnected(kind: String, name: String) -> void:
	device_label.text = "Device: (none)"
	print("[test_main] device_disconnected kind=", kind, " name=", name)


func _on_device_capabilities_changed(
	kind: String, name: String, target_power: bool, indoor_bike_simulation: bool
) -> void:
	print(
		"[test_main] device_capabilities kind=", kind,
		" name=", name,
		" target_power=", target_power,
		" indoor_bike_simulation=", indoor_bike_simulation,
	)


func _on_control_acquired(kind: String, name: String) -> void:
	derived_label.text = "Control: ACQUIRED (%s)" % name
	print("[test_main] control_acquired kind=", kind, " name=", name)


func _on_control_released(kind: String, name: String, reason: String) -> void:
	derived_label.text = "Control: released (%s)" % reason
	print("[test_main] control_released kind=", kind, " name=", name, " reason=", reason)


func _on_target_power_set(watts: int, accepted: bool, reason: String) -> void:
	if accepted:
		derived_label.text = "Target: %d W" % watts
	print(
		"[test_main] target_power_set watts=", watts,
		" accepted=", accepted,
		" reason=", reason,
	)


func _on_cadence_bailout_engaged(
	kind: String,
	name: String,
	pre_pause_target_watts: int,
	bailout_after_s: float,
) -> void:
	derived_label.text = "PAUSED (was %d W)" % pre_pause_target_watts
	print(
		"[test_main] cadence_bailout_engaged kind=", kind,
		" name=", name,
		" pre_pause_target_watts=", pre_pause_target_watts,
		" bailout_after_s=", bailout_after_s,
	)


func _on_cadence_bailout_disengaged(
	kind: String,
	name: String,
	restored_to_watts: int,
	ramped_over_s: float,
) -> void:
	derived_label.text = "Target: %d W (resumed)" % restored_to_watts
	print(
		"[test_main] cadence_bailout_disengaged kind=", kind,
		" name=", name,
		" restored_to_watts=", restored_to_watts,
		" ramped_over_s=", ramped_over_s,
	)
