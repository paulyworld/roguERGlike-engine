extends Control
## HIIT MVP playable loop: recover and play cards, then push to recharge.
##
## This deliberately avoids a concurrent HP race. Card decisions happen during
## a timed recovery/player phase; physical intensity happens during a short
## enemy interval where the player tries to hit a W/kg target.

enum Phase { SETUP, WARMUP, PLAYER_TURN, ENEMY_INTERVAL }

const DEFAULT_AGE := 40
const DEFAULT_WEIGHT_KG := 75.0
const DEFAULT_FTP_W := 250
const DEFAULT_WARMUP_MIN := 10
const WARMUP_START_POWER_PCT_FTP := 0.40
const WARMUP_END_POWER_PCT_FTP := 0.70
const WARMUP_CADENCE_RPM := 85
const RECOVERY_POWER_PCT_FTP := 0.55
const INTERVAL_POWER_PCT_FTP := 1.20
const RECOVERY_CADENCE_RPM := 80
const INTERVAL_CADENCE_RPM := 100
const PLAYER_TURN_DURATION_S := 60.0
const INTERVAL_DURATION_S := 30.0
const PLAYER_MAX_HP := 20
const ENEMY_MAX_HP := 30
const POWER_STRIKE_COST := 2
const POWER_STRIKE_DAMAGE := 7
const POWER_STRIKE_BONUS_DAMAGE := 6
const CADENCE_GUARD_COST := 1
const CADENCE_GUARD_BLOCK := 5
const CADENCE_GUARD_BONUS_BLOCK := 4
const ENEMY_ATTACK_DAMAGE := 8
const CHART_SAMPLE_PERIOD_S := 0.5

var _phase := Phase.SETUP
var _player_hp := PLAYER_MAX_HP
var _enemy_hp := ENEMY_MAX_HP
var _energy := 0
var _next_turn_energy := 3
var _pending_block := 0
var _current_power := 0
var _current_cadence := 0
var _current_hr := 0
var _rider_weight_kg := DEFAULT_WEIGHT_KG
var _ftp_w := DEFAULT_FTP_W
var _max_hr := 220 - DEFAULT_AGE
var _peak_interval_wkg := 0.0
var _last_interval_peak_wkg := 0.0
var _last_interval_power_accuracy := 0.0
var _turn_cadence_accuracy := 0.0
var _turn_cadence_samples := 0
var _warmup_duration_s := float(DEFAULT_WARMUP_MIN * 60)
var _warmup_time_left := float(DEFAULT_WARMUP_MIN * 60)
var _player_time_left := PLAYER_TURN_DURATION_S
var _interval_time_left := INTERVAL_DURATION_S
var _session_time_s := 0.0
var _chart_sample_time_s := 0.0
var _combat_over := false

@onready var status_label: Label = %StatusLabel
@onready var device_label: Label = %DeviceLabel
@onready var telemetry_label: Label = %TelemetryLabel
@onready var power_big_label: Label = %PowerBigLabel
@onready var wkg_big_label: Label = %WkgBigLabel
@onready var hr_big_label: Label = %HRBigLabel
@onready var cadence_big_label: Label = %CadenceBigLabel
@onready var power_meter_label: Label = %PowerMeterLabel
@onready var hr_meter_label: Label = %HRMeterLabel
@onready var cadence_meter_label: Label = %CadenceMeterLabel
@onready var power_meter: ProgressBar = %PowerMeter
@onready var hr_meter: ProgressBar = %HRMeter
@onready var cadence_meter: ProgressBar = %CadenceMeter
@onready var phase_label: Label = %PhaseLabel
@onready var enemy_label: Label = %EnemyLabel
@onready var player_label: Label = %PlayerLabel
@onready var energy_label: Label = %EnergyLabel
@onready var block_label: Label = %BlockLabel
@onready var accuracy_label: Label = %AccuracyLabel
@onready var target_label: Label = %TargetLabel
@onready var reward_label: Label = %RewardLabel
@onready var timer_label: Label = %TimerLabel
@onready var log_label: Label = %LogLabel
@onready var charts: Array[Control] = [
	%RideChart,
	%PowerChart,
	%HRChart,
	%CadenceChart,
]
@onready var weight_spin: SpinBox = %WeightSpin
@onready var ftp_spin: SpinBox = %FTPSpin
@onready var warmup_spin: SpinBox = %WarmupSpin
@onready var age_spin: SpinBox = %AgeSpin
@onready var max_hr_spin: SpinBox = %MaxHRSpin
@onready var z1_spin: SpinBox = %Z1Spin
@onready var z2_spin: SpinBox = %Z2Spin
@onready var z3_spin: SpinBox = %Z3Spin
@onready var z4_spin: SpinBox = %Z4Spin
@onready var z5_spin: SpinBox = %Z5Spin
@onready var formula_button: Button = %FormulaButton
@onready var start_button: Button = %StartButton
@onready var strike_button: Button = %StrikeButton
@onready var guard_button: Button = %GuardButton
@onready var end_turn_button: Button = %EndTurnButton
@onready var reset_button: Button = %ResetButton


func _ready() -> void:
	EffortBridge.connection_state_changed.connect(_on_connection_changed)
	EffortBridge.device_connected.connect(_on_device_connected)
	EffortBridge.power_changed.connect(_on_power_changed)
	EffortBridge.cadence_changed.connect(_on_cadence_changed)
	EffortBridge.heart_rate_changed.connect(_on_heart_rate_changed)
	start_button.pressed.connect(_start_workout)
	strike_button.pressed.connect(_play_power_strike)
	guard_button.pressed.connect(_play_cadence_guard)
	end_turn_button.pressed.connect(_start_enemy_interval)
	reset_button.pressed.connect(_reset_combat)
	formula_button.pressed.connect(_apply_common_hr_formula)
	_connect_settings_inputs()
	_apply_common_hr_formula()
	_render()
	print("[hiit_mvp] ready; setup, warmup, timed recovery, power interval, charting enabled")


func _process(delta: float) -> void:
	if _combat_over or _phase == Phase.SETUP:
		return
	_session_time_s += delta
	_chart_sample_time_s += delta
	if _chart_sample_time_s >= CHART_SAMPLE_PERIOD_S:
		_chart_sample_time_s = 0.0
		_add_chart_sample()

	if _phase == Phase.WARMUP:
		_warmup_time_left = max(0.0, _warmup_time_left - delta)
		if _warmup_time_left <= 0.0:
			_begin_player_turn()
		else:
			_render_timer_only()
		return

	if _phase == Phase.PLAYER_TURN:
		_sample_turn_cadence_accuracy()
		_player_time_left = max(0.0, _player_time_left - delta)
		if _player_time_left <= 0.0:
			_start_enemy_interval()
		else:
			_render_timer_only()
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
			_play_power_strike()
		elif event.keycode == KEY_ENTER:
			if _phase == Phase.SETUP or _combat_over:
				_start_workout()
			else:
				_start_enemy_interval()
		elif event.keycode == KEY_R:
			_reset_combat()


func _connect_settings_inputs() -> void:
	for spin in [weight_spin, ftp_spin, warmup_spin, max_hr_spin, z1_spin, z2_spin, z3_spin, z4_spin, z5_spin]:
		spin.value_changed.connect(_on_settings_changed)


func _apply_common_hr_formula() -> void:
	_max_hr = 220 - int(age_spin.value)
	max_hr_spin.value = _max_hr
	z1_spin.value = roundi(_max_hr * 0.50)
	z2_spin.value = roundi(_max_hr * 0.60)
	z3_spin.value = roundi(_max_hr * 0.70)
	z4_spin.value = roundi(_max_hr * 0.80)
	z5_spin.value = roundi(_max_hr * 0.90)
	_on_settings_changed(0.0)


func _on_settings_changed(_value: float) -> void:
	_rider_weight_kg = max(1.0, float(weight_spin.value))
	_ftp_w = max(1, int(ftp_spin.value))
	_warmup_duration_s = max(60.0, float(warmup_spin.value) * 60.0)
	if _phase == Phase.SETUP:
		_warmup_time_left = _warmup_duration_s
	_max_hr = max(80, int(max_hr_spin.value))
	_configure_chart()
	_render()


func _play_power_strike() -> void:
	if _combat_over or _phase != Phase.PLAYER_TURN:
		return
	if _energy < POWER_STRIKE_COST:
		log_label.text = "Not enough energy."
		return
	_energy -= POWER_STRIKE_COST
	var damage := POWER_STRIKE_DAMAGE
	if _last_interval_power_accuracy >= 1.0:
		damage += POWER_STRIKE_BONUS_DAMAGE
	_enemy_hp = max(0, _enemy_hp - damage)
	log_label.text = "Power Strike dealt %d damage." % damage
	print("[hiit_mvp] power_strike enemy_hp=", _enemy_hp, " energy=", _energy)
	if _enemy_hp == 0:
		_combat_over = true
		log_label.text = "Enemy defeated."
		print("[hiit_mvp] victory")
	_render()


func _play_cadence_guard() -> void:
	if _combat_over or _phase != Phase.PLAYER_TURN:
		return
	if _energy < CADENCE_GUARD_COST:
		log_label.text = "Not enough energy."
		return
	_energy -= CADENCE_GUARD_COST
	var block := CADENCE_GUARD_BLOCK
	if _turn_cadence_accuracy >= 0.9:
		block += CADENCE_GUARD_BONUS_BLOCK
	_pending_block += block
	log_label.text = "Cadence Guard added %d block." % block
	print("[hiit_mvp] cadence_guard block=", block, " pending_block=", _pending_block, " energy=", _energy)
	_render()


func _start_workout() -> void:
	_on_settings_changed(0.0)
	_player_hp = PLAYER_MAX_HP
	_enemy_hp = ENEMY_MAX_HP
	_energy = 0
	_next_turn_energy = 3
	_pending_block = 0
	_peak_interval_wkg = 0.0
	_last_interval_peak_wkg = 0.0
	_last_interval_power_accuracy = 0.0
	_reset_turn_cadence_tracking()
	_warmup_time_left = _warmup_duration_s
	_player_time_left = PLAYER_TURN_DURATION_S
	_interval_time_left = INTERVAL_DURATION_S
	_session_time_s = 0.0
	_chart_sample_time_s = 0.0
	_combat_over = false
	_phase = Phase.WARMUP
	for chart in charts:
		chart.call("clear")
	log_label.text = "Warmup started. Ramp smoothly before the first card turn."
	_add_chart_sample()
	_render()


func _start_enemy_interval() -> void:
	if _combat_over or _phase != Phase.PLAYER_TURN:
		return
	var expired_energy := _energy
	_energy = 0
	_phase = Phase.ENEMY_INTERVAL
	_peak_interval_wkg = _current_wkg()
	_interval_time_left = INTERVAL_DURATION_S
	log_label.text = "Power interval started. %d unspent energy expired." % expired_energy
	print("[hiit_mvp] interval_start target_wkg=", _interval_target_wkg())
	_add_chart_sample()
	_render()


func _begin_player_turn() -> void:
	_phase = Phase.PLAYER_TURN
	_energy = _next_turn_energy
	_reset_turn_cadence_tracking()
	_player_time_left = PLAYER_TURN_DURATION_S
	_interval_time_left = INTERVAL_DURATION_S
	log_label.text = "Recovery/card phase started. Spend this turn's energy before it expires."
	_add_chart_sample()
	_render()


func _resolve_enemy_interval() -> void:
	var energy_gain := _interval_energy_gain(_peak_interval_wkg)
	_next_turn_energy = energy_gain
	_last_interval_peak_wkg = _peak_interval_wkg
	_last_interval_power_accuracy = _interval_power_accuracy(_peak_interval_wkg)
	var incoming := ENEMY_ATTACK_DAMAGE
	var damage_taken: int = max(0, incoming - _pending_block)
	_player_hp = max(0, _player_hp - damage_taken)
	log_label.text = "Enemy attacked for %d. Blocked %d. Took %d. Next turn energy: %d." % [
		incoming,
		min(_pending_block, incoming),
		damage_taken,
		_next_turn_energy,
	]
	print("[hiit_mvp] interval_resolve peak_wkg=", _peak_interval_wkg, " damage_taken=", damage_taken, " next_energy=", _next_turn_energy)
	_pending_block = 0
	if _player_hp == 0:
		_combat_over = true
		log_label.text += " Player defeated."
		print("[hiit_mvp] defeat")
	_add_chart_sample()
	_begin_player_turn()


func _reset_combat() -> void:
	_phase = Phase.SETUP
	_player_hp = PLAYER_MAX_HP
	_enemy_hp = ENEMY_MAX_HP
	_energy = 0
	_next_turn_energy = 3
	_pending_block = 0
	_peak_interval_wkg = 0.0
	_last_interval_peak_wkg = 0.0
	_last_interval_power_accuracy = 0.0
	_reset_turn_cadence_tracking()
	_warmup_time_left = _warmup_duration_s
	_player_time_left = PLAYER_TURN_DURATION_S
	_interval_time_left = INTERVAL_DURATION_S
	_session_time_s = 0.0
	_chart_sample_time_s = 0.0
	_combat_over = false
	for chart in charts:
		chart.call("clear")
	log_label.text = "Enter rider stats and press Start Workout."
	_render()


func _current_wkg() -> float:
	return float(_current_power) / _rider_weight_kg


func _target_margin_wkg(wkg: float) -> float:
	return wkg - _interval_target_wkg()


func _recovery_target_power_w() -> float:
	return float(_ftp_w) * RECOVERY_POWER_PCT_FTP


func _interval_target_power_w() -> float:
	return float(_ftp_w) * INTERVAL_POWER_PCT_FTP


func _warmup_start_power_w() -> float:
	return float(_ftp_w) * WARMUP_START_POWER_PCT_FTP


func _warmup_end_power_w() -> float:
	return float(_ftp_w) * WARMUP_END_POWER_PCT_FTP


func _warmup_target_power_w() -> float:
	var elapsed: float = _warmup_duration_s - _warmup_time_left
	var progress: float = clamp(elapsed / max(_warmup_duration_s, 1.0), 0.0, 1.0)
	return lerpf(_warmup_start_power_w(), _warmup_end_power_w(), progress)


func _recovery_target_wkg() -> float:
	return _recovery_target_power_w() / _rider_weight_kg


func _interval_target_wkg() -> float:
	return _interval_target_power_w() / _rider_weight_kg


func _recovery_target_hr() -> int:
	return int(z3_spin.value)


func _interval_target_hr() -> int:
	return int(z4_spin.value)


func _interval_energy_gain(peak_wkg: float) -> int:
	var accuracy := _interval_power_accuracy(peak_wkg)
	if accuracy >= 1.30:
		return 5
	if accuracy >= 1.15:
		return 4
	if accuracy >= 1.0:
		return 3
	return 1


func _interval_reward_text(peak_wkg: float) -> String:
	var accuracy := _interval_power_accuracy(peak_wkg)
	var energy_gain := _interval_energy_gain(peak_wkg)
	if accuracy >= 1.30:
		return "Projected reward: +%d energy, strong over-target block" % energy_gain
	if accuracy >= 1.15:
		return "Projected reward: +%d energy, clean over-target block" % energy_gain
	if accuracy >= 1.0:
		return "Projected reward: +%d energy, block" % energy_gain
	return "Projected reward: +%d energy, attack lands" % energy_gain


func _interval_power_accuracy(peak_wkg: float) -> float:
	return peak_wkg / max(_interval_target_wkg(), 0.01)


func _current_cadence_accuracy() -> float:
	if _current_cadence <= 0:
		return 0.0
	var diff: float = abs(float(_current_cadence - RECOVERY_CADENCE_RPM))
	return clamp(1.0 - diff / 30.0, 0.0, 1.0)


func _active_power_target() -> float:
	if _phase == Phase.SETUP:
		return _warmup_start_power_w()
	if _phase == Phase.WARMUP:
		return _warmup_target_power_w()
	if _phase == Phase.PLAYER_TURN:
		return _recovery_target_power_w()
	return _interval_target_power_w()


func _active_hr_target() -> float:
	if _phase == Phase.SETUP:
		return float(z2_spin.value)
	if _phase == Phase.WARMUP:
		var elapsed: float = _warmup_duration_s - _warmup_time_left
		var progress: float = clamp(elapsed / max(_warmup_duration_s, 1.0), 0.0, 1.0)
		return lerpf(float(z2_spin.value), float(z3_spin.value), progress)
	if _phase == Phase.PLAYER_TURN:
		return float(_recovery_target_hr())
	return float(_interval_target_hr())


func _active_cadence_target() -> float:
	if _phase == Phase.SETUP or _phase == Phase.WARMUP:
		return float(WARMUP_CADENCE_RPM)
	if _phase == Phase.PLAYER_TURN:
		return float(RECOVERY_CADENCE_RPM)
	return float(INTERVAL_CADENCE_RPM)


func _target_ratio(actual: float, target: float) -> float:
	return actual / max(target, 0.01)


func _accuracy_color(ratio: float) -> Color:
	if ratio >= 1.15:
		return Color(0.30, 0.65, 1.0)
	if ratio >= 1.0:
		return Color(0.25, 0.90, 0.35)
	if ratio >= 0.85:
		return Color(1.0, 0.78, 0.25)
	return Color(0.95, 0.25, 0.20)


func _apply_meter_style(bar: ProgressBar, ratio: float) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = _accuracy_color(ratio)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.13, 0.13, 0.14)
	background.corner_radius_top_left = 3
	background.corner_radius_top_right = 3
	background.corner_radius_bottom_left = 3
	background.corner_radius_bottom_right = 3
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", background)


func _render_meter(
	label: Label,
	bar: ProgressBar,
	name: String,
	actual: float,
	target: float,
	unit: String,
	as_int := true
) -> void:
	var ratio := _target_ratio(actual, target)
	var delta := actual - target
	bar.value = clamp(ratio * 100.0, 0.0, 130.0)
	_apply_meter_style(bar, ratio)
	if as_int:
		label.text = "%s  %.0f / %.0f %s  delta %+0.f" % [name, actual, target, unit, delta]
	else:
		label.text = "%s  %.2f / %.2f %s  delta %+.2f" % [name, actual, target, unit, delta]


func _render_target_meters() -> void:
	_render_meter(
		power_meter_label,
		power_meter,
		"Power",
		float(_current_power),
		_active_power_target(),
		"W"
	)
	_render_meter(
		hr_meter_label,
		hr_meter,
		"HR",
		float(_current_hr),
		_active_hr_target(),
		"bpm"
	)
	_render_meter(
		cadence_meter_label,
		cadence_meter,
		"Cadence",
		float(_current_cadence),
		_active_cadence_target(),
		"rpm"
	)


func _sample_turn_cadence_accuracy() -> void:
	_turn_cadence_accuracy += _current_cadence_accuracy()
	_turn_cadence_samples += 1


func _average_turn_cadence_accuracy() -> float:
	if _turn_cadence_samples <= 0:
		return 0.0
	return _turn_cadence_accuracy / float(_turn_cadence_samples)


func _reset_turn_cadence_tracking() -> void:
	_turn_cadence_accuracy = 0.0
	_turn_cadence_samples = 0


func _phase_name() -> String:
	if _phase == Phase.SETUP:
		return "Setup"
	if _phase == Phase.WARMUP:
		return "Warmup Ramp"
	if _phase == Phase.PLAYER_TURN:
		return "Recovery / Card Play"
	return "Power Interval"


func _recovery_state() -> String:
	var wkg_ok := _current_power <= _recovery_target_power_w()
	var hr_ok := _current_hr == 0 or _current_hr < _recovery_target_hr()
	if wkg_ok and hr_ok:
		return "in recovery"
	return "above recovery"


func _zone_bounds() -> Array[int]:
	return [
		int(z1_spin.value),
		int(z2_spin.value),
		int(z3_spin.value),
		int(z4_spin.value),
		int(z5_spin.value),
	]


func _configure_chart() -> void:
	for chart in charts:
		chart.call(
			"configure",
			_rider_weight_kg,
			_max_hr,
			_zone_bounds(),
			_recovery_target_power_w(),
			_interval_target_power_w(),
			_warmup_duration_s,
			_warmup_start_power_w(),
			_warmup_end_power_w(),
			float(_recovery_target_hr()),
			float(_interval_target_hr()),
			float(z2_spin.value),
			float(z3_spin.value),
			float(RECOVERY_CADENCE_RPM),
			float(INTERVAL_CADENCE_RPM),
			float(WARMUP_CADENCE_RPM)
		)


func _add_chart_sample() -> void:
	for chart in charts:
		chart.call("add_sample", _session_time_s, _current_power, _current_cadence, _current_hr, int(_phase))


func _render() -> void:
	var wkg := _current_wkg()
	telemetry_label.text = "Power: %d W   W/kg: %.2f   Cadence: %d rpm   HR: %d bpm" % [
		_current_power,
		wkg,
		_current_cadence,
		_current_hr,
	]
	power_big_label.text = "%d W" % _current_power
	wkg_big_label.text = "%.2f W/kg" % wkg
	hr_big_label.text = "%d bpm" % _current_hr
	cadence_big_label.text = "%d rpm" % _current_cadence
	_render_target_meters()
	phase_label.text = "Phase: %s" % _phase_name()
	enemy_label.text = "Enemy HP: %d / %d" % [_enemy_hp, ENEMY_MAX_HP]
	player_label.text = "Player HP: %d / %d" % [_player_hp, PLAYER_MAX_HP]
	energy_label.text = "Turn energy: %d   next: %d" % [_energy, _next_turn_energy]
	block_label.text = "Block queued: %d   enemy attack: %d" % [_pending_block, ENEMY_ATTACK_DAMAGE]
	accuracy_label.text = "Prev power accuracy: %d%%   cadence accuracy: %d%%" % [
		roundi(_last_interval_power_accuracy * 100.0),
		roundi(_average_turn_cadence_accuracy() * 100.0),
	]
	if _phase == Phase.SETUP:
		target_label.text = "Setup: enter weight, FTP, HR zones, and warmup length; Start Workout begins a %.0f-%.0f%% FTP ramp." % [
			WARMUP_START_POWER_PCT_FTP * 100.0,
			WARMUP_END_POWER_PCT_FTP * 100.0,
		]
		reward_label.text = "Warmup: %.0f min ramp from %.0f W to %.0f W, cadence %d rpm, HR rising from Z2 toward Z3." % [
			_warmup_duration_s / 60.0,
			_warmup_start_power_w(),
			_warmup_end_power_w(),
			WARMUP_CADENCE_RPM,
		]
	elif _phase == Phase.WARMUP:
		target_label.text = "Warmup ramp target: %.0f W (%.2f W/kg), HR %.0f, cadence %d rpm" % [
			_warmup_target_power_w(),
			_warmup_target_power_w() / _rider_weight_kg,
			_active_hr_target(),
			WARMUP_CADENCE_RPM,
		]
		reward_label.text = "Workout starts after warmup. Keep effort smooth; no cards during warmup."
	elif _phase == Phase.PLAYER_TURN:
		target_label.text = "Recovery targets: %.0f W (%.2f W/kg), HR <%d, cadence %d rpm (%s)" % [
			_recovery_target_power_w(),
			_recovery_target_wkg(),
			_recovery_target_hr(),
			RECOVERY_CADENCE_RPM,
			_recovery_state(),
		]
		reward_label.text = "Cards: Power Strike %dE (%d + %d if prior power hit); Cadence Guard %dE (%d + %d if cadence accurate)" % [
			POWER_STRIKE_COST,
			POWER_STRIKE_DAMAGE,
			POWER_STRIKE_BONUS_DAMAGE,
			CADENCE_GUARD_COST,
			CADENCE_GUARD_BLOCK,
			CADENCE_GUARD_BONUS_BLOCK,
		]
		target_label.text += " | Next interval: %.0f W (%.2f W/kg), HR %d+, cadence %d rpm" % [
			_interval_target_power_w(),
			_interval_target_wkg(),
			_interval_target_hr(),
			INTERVAL_CADENCE_RPM,
		]
	else:
		var margin := _target_margin_wkg(_peak_interval_wkg)
		target_label.text = "Interval targets: %.0f W (%.2f W/kg), HR %d+, cadence %d rpm" % [
			_interval_target_power_w(),
			_interval_target_wkg(),
			_interval_target_hr(),
			INTERVAL_CADENCE_RPM,
		]
		reward_label.text = "Peak: %.2f W/kg   Margin: %+.2f   %s" % [
			_peak_interval_wkg,
			margin,
			_interval_reward_text(_peak_interval_wkg),
		]
	_render_timer_only()
	start_button.disabled = _phase != Phase.SETUP and not _combat_over
	strike_button.disabled = _combat_over or _phase != Phase.PLAYER_TURN or _energy < POWER_STRIKE_COST
	guard_button.disabled = _combat_over or _phase != Phase.PLAYER_TURN or _energy < CADENCE_GUARD_COST
	end_turn_button.disabled = _combat_over or _phase != Phase.PLAYER_TURN


func _render_timer_only() -> void:
	if _phase == Phase.SETUP:
		timer_label.text = "Workout not started."
	elif _phase == Phase.WARMUP:
		timer_label.text = "Warmup time left: %.1fs" % _warmup_time_left
	elif _phase == Phase.PLAYER_TURN:
		timer_label.text = "Recovery/card timer: %.1fs" % _player_time_left
	else:
		timer_label.text = "Power interval time left: %.1fs" % _interval_time_left


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
