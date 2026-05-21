extends Control
## HIIT MVP playable loop: recover and play cards, then push to recharge.
##
## This deliberately avoids a concurrent HP race. Card decisions happen during
## a recovery/player phase; physical intensity happens during a short enemy
## interval where the player tries to hit a W/kg target.

enum Phase { PLAYER_TURN, ENEMY_INTERVAL }

const RIDER_WEIGHT_KG := 75.0
const TARGET_WKG := 3.3
const RECOVERY_CEILING_WKG := 2.0
const INTERVAL_DURATION_S := 10.0
const PLAYER_MAX_HP := 20
const ENEMY_MAX_HP := 30
const STRIKE_COST := 1
const STRIKE_DAMAGE := 6
const ENEMY_ATTACK_DAMAGE := 5

var _phase := Phase.PLAYER_TURN
var _player_hp := PLAYER_MAX_HP
var _enemy_hp := ENEMY_MAX_HP
var _energy := 1
var _current_power := 0
var _current_cadence := 0
var _current_hr := 0
var _peak_interval_wkg := 0.0
var _interval_time_left := INTERVAL_DURATION_S
var _combat_over := false

@onready var status_label: Label = %StatusLabel
@onready var device_label: Label = %DeviceLabel
@onready var telemetry_label: Label = %TelemetryLabel
@onready var phase_label: Label = %PhaseLabel
@onready var enemy_label: Label = %EnemyLabel
@onready var player_label: Label = %PlayerLabel
@onready var energy_label: Label = %EnergyLabel
@onready var target_label: Label = %TargetLabel
@onready var timer_label: Label = %TimerLabel
@onready var log_label: Label = %LogLabel
@onready var strike_button: Button = %StrikeButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var reset_button: Button = %ResetButton


func _ready() -> void:
	EffortBridge.connection_state_changed.connect(_on_connection_changed)
	EffortBridge.device_connected.connect(_on_device_connected)
	EffortBridge.power_changed.connect(_on_power_changed)
	EffortBridge.cadence_changed.connect(_on_cadence_changed)
	EffortBridge.heart_rate_changed.connect(_on_heart_rate_changed)
	strike_button.pressed.connect(_play_strike)
	end_turn_button.pressed.connect(_start_enemy_interval)
	reset_button.pressed.connect(_reset_combat)
	_render()
	print("[hiit_mvp] ready; player turn is recovery, enemy turn is power target")


func _process(delta: float) -> void:
	if _combat_over or _phase != Phase.ENEMY_INTERVAL:
		return
	_peak_interval_wkg = max(_peak_interval_wkg, _current_wkg())
	_interval_time_left = max(0.0, _interval_time_left - delta)
	if _interval_time_left <= 0.0:
		_resolve_enemy_interval()
	else:
		_render_timer_only()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_play_strike()
		elif event.keycode == KEY_ENTER:
			_start_enemy_interval()
		elif event.keycode == KEY_R:
			_reset_combat()


func _play_strike() -> void:
	if _combat_over or _phase != Phase.PLAYER_TURN:
		return
	if _energy < STRIKE_COST:
		log_label.text = "Not enough energy."
		return
	_energy -= STRIKE_COST
	_enemy_hp = max(0, _enemy_hp - STRIKE_DAMAGE)
	log_label.text = "Strike dealt %d damage." % STRIKE_DAMAGE
	print("[hiit_mvp] strike enemy_hp=", _enemy_hp, " energy=", _energy)
	if _enemy_hp == 0:
		_combat_over = true
		log_label.text = "Enemy defeated."
		print("[hiit_mvp] victory")
	_render()


func _start_enemy_interval() -> void:
	if _combat_over or _phase != Phase.PLAYER_TURN:
		return
	_phase = Phase.ENEMY_INTERVAL
	_peak_interval_wkg = _current_wkg()
	_interval_time_left = INTERVAL_DURATION_S
	log_label.text = "Power interval started."
	print("[hiit_mvp] interval_start target_wkg=", TARGET_WKG)
	_render()


func _resolve_enemy_interval() -> void:
	var hit_target := _peak_interval_wkg >= TARGET_WKG
	if hit_target:
		_energy += 3
		log_label.text = "Target hit: +3 energy, enemy attack blocked."
		print("[hiit_mvp] interval_success peak_wkg=", _peak_interval_wkg, " energy=", _energy)
	else:
		_energy += 1
		_player_hp = max(0, _player_hp - ENEMY_ATTACK_DAMAGE)
		log_label.text = "Target missed: +1 energy, took %d damage." % ENEMY_ATTACK_DAMAGE
		print("[hiit_mvp] interval_miss peak_wkg=", _peak_interval_wkg, " player_hp=", _player_hp)
		if _player_hp == 0:
			_combat_over = true
			log_label.text += " Player defeated."
			print("[hiit_mvp] defeat")
	_phase = Phase.PLAYER_TURN
	_interval_time_left = INTERVAL_DURATION_S
	_render()


func _reset_combat() -> void:
	_phase = Phase.PLAYER_TURN
	_player_hp = PLAYER_MAX_HP
	_enemy_hp = ENEMY_MAX_HP
	_energy = 1
	_peak_interval_wkg = 0.0
	_interval_time_left = INTERVAL_DURATION_S
	_combat_over = false
	log_label.text = "New HIIT encounter."
	_render()


func _current_wkg() -> float:
	return float(_current_power) / RIDER_WEIGHT_KG


func _phase_name() -> String:
	if _phase == Phase.PLAYER_TURN:
		return "Recovery / Card Play"
	return "Power Interval"


func _recovery_state() -> String:
	if _current_wkg() <= RECOVERY_CEILING_WKG:
		return "in recovery"
	return "above recovery"


func _render() -> void:
	var wkg := _current_wkg()
	telemetry_label.text = "Power: %d W   W/kg: %.2f   Cadence: %d rpm   HR: %d bpm" % [
		_current_power,
		wkg,
		_current_cadence,
		_current_hr,
	]
	phase_label.text = "Phase: %s" % _phase_name()
	enemy_label.text = "Enemy HP: %d / %d" % [_enemy_hp, ENEMY_MAX_HP]
	player_label.text = "Player HP: %d / %d" % [_player_hp, PLAYER_MAX_HP]
	energy_label.text = "Energy: %d   Strike cost: %d" % [_energy, STRIKE_COST]
	if _phase == Phase.PLAYER_TURN:
		target_label.text = "Recovery: %.1f W/kg ceiling (%s)" % [RECOVERY_CEILING_WKG, _recovery_state()]
		timer_label.text = "Enemy interval: %.0fs at %.1f W/kg target" % [
			INTERVAL_DURATION_S,
			TARGET_WKG,
		]
	else:
		target_label.text = "Target: %.1f W/kg   Peak: %.2f W/kg" % [TARGET_WKG, _peak_interval_wkg]
		_render_timer_only()
	strike_button.disabled = _combat_over or _phase != Phase.PLAYER_TURN or _energy < STRIKE_COST
	end_turn_button.disabled = _combat_over or _phase != Phase.PLAYER_TURN


func _render_timer_only() -> void:
	timer_label.text = "Interval time left: %.1fs" % _interval_time_left


func _on_connection_changed(connected: bool) -> void:
	status_label.text = "Sidecar: " + ("CONNECTED" if connected else "disconnected")
	print("[hiit_mvp] connection_state_changed connected=", connected)


func _on_device_connected(kind: String, name: String) -> void:
	device_label.text = "Device: %s (%s)" % [name, kind]
	print("[hiit_mvp] device_connected kind=", kind, " name=", name)


func _on_power_changed(watts: int) -> void:
	_current_power = watts
	if _phase == Phase.ENEMY_INTERVAL:
		_peak_interval_wkg = max(_peak_interval_wkg, _current_wkg())
	_render()
	print("[hiit_mvp] power_changed watts=", watts, " wkg=", _current_wkg())


func _on_cadence_changed(rpm: int) -> void:
	_current_cadence = rpm
	_render()


func _on_heart_rate_changed(bpm: int) -> void:
	_current_hr = bpm
	_render()
