extends Control

enum ChartMode { RIDE_VIEW, POWER, HEART_RATE, CADENCE }

const WORKOUT_HIIT_ENCOUNTER := 0
const WORKOUT_RAMP_POWER_TEST := 1
const WORKOUT_ERG_STEP_TEST := 2
const DEFAULT_TOTAL_WORKOUT_S := 20.0 * 60.0
const PLOT_PAD_LEFT := 42.0
const PLOT_PAD_RIGHT := 12.0
const PLOT_PAD_TOP := 16.0
const PLOT_PAD_BOTTOM := 24.0

@export var mode: ChartMode = ChartMode.RIDE_VIEW

var _samples: Array[Dictionary] = []
var _workout_kind := WORKOUT_HIIT_ENCOUNTER
var _total_workout_s := DEFAULT_TOTAL_WORKOUT_S
var _max_hr := 180
var _weight_kg := 75.0
var _hr_zone_bounds: Array[int] = [90, 108, 126, 144, 162]
var _recovery_target_power_w := 140.0
var _interval_target_power_w := 300.0
var _recovery_duration_s := 120.0
var _warmup_duration_s := 600.0
var _warmup_start_power_w := 100.0
var _warmup_end_power_w := 175.0
var _recovery_target_hr_bpm := 126.0
var _interval_target_hr_bpm := 144.0
var _warmup_start_hr_bpm := 108.0
var _warmup_end_hr_bpm := 126.0
var _recovery_target_cadence_rpm := 80.0
var _interval_target_cadence_rpm := 100.0
var _warmup_target_cadence_rpm := 85.0
var _ramp_start_power_w := 125.0
var _ramp_peak_power_w := 300.0
var _ramp_start_cadence_rpm := 80.0
var _ramp_peak_cadence_rpm := 100.0
var _erg_step_start_power_w := 125.0
var _erg_step_peak_power_w := 375.0
var _erg_step_watts := 40.0
var _erg_step_duration_s := 15.0
var _erg_step_cadence_rpm := 90.0


func configure(
	workout_kind: int,
	total_workout_s: float,
	weight_kg: float,
	max_hr: int,
	hr_zone_bounds: Array[int],
	recovery_target_power_w: float,
	interval_target_power_w: float,
	recovery_duration_s: float,
	warmup_duration_s: float,
	warmup_start_power_w: float,
	warmup_end_power_w: float,
	recovery_target_hr_bpm: float,
	interval_target_hr_bpm: float,
	warmup_start_hr_bpm: float,
	warmup_end_hr_bpm: float,
	recovery_target_cadence_rpm: float,
	interval_target_cadence_rpm: float,
	warmup_target_cadence_rpm: float,
	ramp_start_power_w: float,
	ramp_peak_power_w: float,
	ramp_start_cadence_rpm: float,
	ramp_peak_cadence_rpm: float,
	erg_step_start_power_w: float,
	erg_step_peak_power_w: float,
	erg_step_watts: float,
	erg_step_duration_s: float,
	erg_step_cadence_rpm: float
) -> void:
	_workout_kind = workout_kind
	_total_workout_s = max(300.0, total_workout_s)
	_weight_kg = weight_kg
	_max_hr = max_hr
	_hr_zone_bounds = hr_zone_bounds.duplicate()
	_recovery_target_power_w = recovery_target_power_w
	_interval_target_power_w = interval_target_power_w
	_recovery_duration_s = recovery_duration_s
	_warmup_duration_s = warmup_duration_s
	_warmup_start_power_w = warmup_start_power_w
	_warmup_end_power_w = warmup_end_power_w
	_recovery_target_hr_bpm = recovery_target_hr_bpm
	_interval_target_hr_bpm = interval_target_hr_bpm
	_warmup_start_hr_bpm = warmup_start_hr_bpm
	_warmup_end_hr_bpm = warmup_end_hr_bpm
	_recovery_target_cadence_rpm = recovery_target_cadence_rpm
	_interval_target_cadence_rpm = interval_target_cadence_rpm
	_warmup_target_cadence_rpm = warmup_target_cadence_rpm
	_ramp_start_power_w = ramp_start_power_w
	_ramp_peak_power_w = ramp_peak_power_w
	_ramp_start_cadence_rpm = ramp_start_cadence_rpm
	_ramp_peak_cadence_rpm = ramp_peak_cadence_rpm
	_erg_step_start_power_w = erg_step_start_power_w
	_erg_step_peak_power_w = erg_step_peak_power_w
	_erg_step_watts = erg_step_watts
	_erg_step_duration_s = erg_step_duration_s
	_erg_step_cadence_rpm = erg_step_cadence_rpm
	queue_redraw()


func clear() -> void:
	_samples.clear()
	queue_redraw()


func add_sample(time_s: float, power: int, cadence: int, hr: int, phase: int) -> void:
	_samples.append({
		"time": time_s,
		"power": power,
		"cadence": cadence,
		"hr": hr,
		"phase": phase,
	})
	while not _samples.is_empty() and float(_samples[0]["time"]) < time_s - _total_workout_s:
		_samples.pop_front()
	queue_redraw()


func _draw() -> void:
	var plot := _plot_rect()
	draw_rect(plot, Color(0.07, 0.07, 0.075, 1.0), true)
	draw_rect(plot, Color(0.32, 0.32, 0.34, 1.0), false, 1.0)
	_draw_workout_blocks(plot)
	_draw_grid(plot)

	match mode:
		ChartMode.RIDE_VIEW:
			_draw_ride_view(plot)
		ChartMode.POWER:
			_draw_metric_chart(plot, "power", Color(0.95, 0.35, 0.22), _power_max())
			_draw_phase_targets(plot, _recovery_target_power_w, _interval_target_power_w, _warmup_start_power_w, _warmup_end_power_w, _power_max(), Color(1.0, 0.72, 0.22))
			_draw_title(plot, "Power / Target Power")
		ChartMode.HEART_RATE:
			var hr_max := float(max(_max_hr, 120))
			_draw_hr_zones(plot, hr_max)
			_draw_metric_chart(plot, "hr", Color(0.95, 0.2, 0.55), hr_max)
			_draw_phase_targets(plot, _recovery_target_hr_bpm, _interval_target_hr_bpm, _warmup_start_hr_bpm, _warmup_end_hr_bpm, hr_max, Color(1.0, 0.45, 0.8))
			_draw_title(plot, "Heart Rate / Target HR")
		ChartMode.CADENCE:
			_draw_metric_chart(plot, "cadence", Color(0.25, 0.72, 1.0), 150.0)
			_draw_phase_targets(plot, _recovery_target_cadence_rpm, _interval_target_cadence_rpm, _warmup_target_cadence_rpm, _warmup_target_cadence_rpm, 150.0, Color(0.35, 0.9, 1.0))
			_draw_title(plot, "Cadence / Target Cadence")

	_draw_footer(plot)


func _plot_rect() -> Rect2:
	return Rect2(
		PLOT_PAD_LEFT,
		PLOT_PAD_TOP,
		max(1.0, size.x - PLOT_PAD_LEFT - PLOT_PAD_RIGHT),
		max(1.0, size.y - PLOT_PAD_TOP - PLOT_PAD_BOTTOM)
	)


func _time_min() -> float:
	return 0.0


func _time_max() -> float:
	return _total_workout_s


func _elapsed_time() -> float:
	if _samples.is_empty():
		return 0.0
	return clamp(float(_samples[-1]["time"]), 0.0, _total_workout_s)


func _x_for_time(plot: Rect2, time_s: float) -> float:
	return plot.position.x + clamp(time_s / _total_workout_s, 0.0, 1.0) * plot.size.x


func _y_for_value(plot: Rect2, value: float, max_value: float) -> float:
	return plot.position.y + plot.size.y - clamp(value / max_value, 0.0, 1.0) * plot.size.y


func _power_max() -> float:
	var max_power: float = max(max(max(max(_recovery_target_power_w, _interval_target_power_w), _ramp_peak_power_w), _erg_step_peak_power_w) * 1.35, 400.0)
	for sample in _samples:
		max_power = max(max_power, float(sample["power"]) * 1.1)
	return max_power


func _draw_grid(plot: Rect2) -> void:
	for i in range(1, 4):
		var y := plot.position.y + plot.size.y * float(i) / 4.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.16, 0.16, 0.17), 1.0)
	for i in range(1, 5):
		var x := plot.position.x + plot.size.x * float(i) / 5.0
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color(0.16, 0.16, 0.17), 1.0)


func _draw_workout_blocks(plot: Rect2) -> void:
	if _workout_kind == WORKOUT_RAMP_POWER_TEST or _workout_kind == WORKOUT_ERG_STEP_TEST:
		var color := Color(0.08, 0.18, 0.30, 0.34) if _workout_kind == WORKOUT_RAMP_POWER_TEST else Color(0.25, 0.18, 0.05, 0.34)
		draw_rect(plot, color, true)
		if _workout_kind == WORKOUT_RAMP_POWER_TEST:
			var midpoint := _x_for_time(plot, _total_workout_s * 0.5)
			draw_line(Vector2(midpoint, plot.position.y), Vector2(midpoint, plot.end.y), Color(0.6, 0.6, 0.7, 0.45), 1.0)
		else:
			var t := 0.0
			while t < _total_workout_s:
				var x := _x_for_time(plot, t)
				draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color(0.9, 0.75, 0.2, 0.20), 1.0)
				t += _erg_step_duration_s
		return

	var warmup_end: float = min(_warmup_duration_s, _total_workout_s)
	if warmup_end > 0.0:
		draw_rect(
			Rect2(
				_x_for_time(plot, 0.0),
				plot.position.y,
				max(1.0, _x_for_time(plot, warmup_end) - _x_for_time(plot, 0.0)),
				plot.size.y
			),
			Color(0.08, 0.18, 0.30, 0.34),
			true
		)

	var t: float = warmup_end
	var phase := 1
	var first_power_block := true
	while t < _total_workout_s:
		var duration: float = _recovery_duration_s if phase == 0 else 30.0
		var end_t: float = min(t + duration, _total_workout_s)
		var x1: float = _x_for_time(plot, t)
		var x2: float = _x_for_time(plot, end_t)
		var color: Color = Color(0.10, 0.26, 0.13, 0.30) if phase == 0 else Color(0.37, 0.11, 0.07, 0.36)
		if phase == 1 and first_power_block:
			color = Color(0.22, 0.18, 0.05, 0.38)
			first_power_block = false
		draw_rect(Rect2(x1, plot.position.y, max(1.0, x2 - x1), plot.size.y), color, true)
		t = end_t
		phase = 1 - phase


func _draw_ride_view(plot: Rect2) -> void:
	var elapsed: float = _elapsed_time()
	var elapsed_x: float = _x_for_time(plot, elapsed)
	draw_rect(Rect2(plot.position.x, plot.position.y, elapsed_x - plot.position.x, plot.size.y), Color(0.25, 0.25, 0.25, 0.22), true)
	draw_line(Vector2(elapsed_x, plot.position.y), Vector2(elapsed_x, plot.end.y), Color(1.0, 1.0, 1.0, 0.9), 2.0)
	_draw_metric_chart(plot, "power", Color(0.95, 0.35, 0.22), _power_max(), true)
	_draw_metric_chart(plot, "hr", Color(0.95, 0.2, 0.55), float(max(_max_hr, 120)), true)
	_draw_metric_chart(plot, "cadence", Color(0.25, 0.72, 1.0), 150.0, true)
	_draw_title(plot, "Ride View / %s workout" % _format_seconds(_total_workout_s))


func _draw_metric_chart(
	plot: Rect2,
	key: String,
	color: Color,
	max_value: float,
	thinner := false
) -> void:
	if _samples.size() < 2:
		return
	var points := PackedVector2Array()
	for sample in _samples:
		points.append(Vector2(
			_x_for_time(plot, float(sample["time"])),
			_y_for_value(plot, float(sample[key]), max_value)
		))
	if points.size() >= 2:
		draw_polyline(points, color, 1.5 if thinner else 2.5)


func _draw_phase_targets(
	plot: Rect2,
	recovery_target: float,
	interval_target: float,
	warmup_start_target: float,
	warmup_end_target: float,
	max_value: float,
	color: Color
) -> void:
	if _workout_kind == WORKOUT_RAMP_POWER_TEST:
		_draw_ramp_target_curve(plot, max_value, color)
		return
	if _workout_kind == WORKOUT_ERG_STEP_TEST:
		_draw_erg_step_target_curve(plot, max_value, color)
		return

	var warmup_end: float = min(_warmup_duration_s, _total_workout_s)
	if warmup_end > 0.0:
		_draw_dotted_line(
			Vector2(_x_for_time(plot, 0.0), _y_for_value(plot, warmup_start_target, max_value)),
			Vector2(_x_for_time(plot, warmup_end), _y_for_value(plot, warmup_end_target, max_value)),
			color,
			2.0
		)

	var t: float = warmup_end
	var phase := 1
	while t < _total_workout_s:
		var duration: float = _recovery_duration_s if phase == 0 else 30.0
		var end_t: float = min(t + duration, _total_workout_s)
		var target: float = recovery_target if phase == 0 else interval_target
		var y: float = _y_for_value(plot, target, max_value)
		_draw_dotted_line(Vector2(_x_for_time(plot, t), y), Vector2(_x_for_time(plot, end_t), y), color, 2.0)
		t = end_t
		phase = 1 - phase


func _draw_ramp_target_curve(plot: Rect2, max_value: float, color: Color) -> void:
	var points := PackedVector2Array()
	var steps := 32
	for i in range(steps + 1):
		var t := _total_workout_s * float(i) / float(steps)
		points.append(Vector2(_x_for_time(plot, t), _y_for_value(plot, _ramp_target_for_mode(max_value, t), max_value)))
	if points.size() >= 2:
		draw_polyline(points, color, 2.0)


func _draw_erg_step_target_curve(plot: Rect2, max_value: float, color: Color) -> void:
	var t := 0.0
	while t < _total_workout_s:
		var end_t: float = min(t + _erg_step_duration_s, _total_workout_s)
		var target := _erg_step_target_for_mode(max_value, t)
		var y := _y_for_value(plot, target, max_value)
		draw_line(Vector2(_x_for_time(plot, t), y), Vector2(_x_for_time(plot, end_t), y), color, 2.0)
		if end_t < _total_workout_s:
			var next_y := _y_for_value(plot, _erg_step_target_for_mode(max_value, end_t), max_value)
			var x := _x_for_time(plot, end_t)
			draw_line(Vector2(x, y), Vector2(x, next_y), color, 1.0)
		t = end_t


func _ramp_target_for_mode(max_value: float, time_s: float) -> float:
	if is_equal_approx(max_value, 150.0):
		return _ramp_curve_value(_ramp_start_cadence_rpm, _ramp_peak_cadence_rpm, time_s)
	if max_value <= float(max(_max_hr, 120)):
		return _ramp_curve_value(_warmup_start_hr_bpm, _interval_target_hr_bpm, time_s)
	return _ramp_curve_value(_ramp_start_power_w, _ramp_peak_power_w, time_s)


func _erg_step_target_for_mode(max_value: float, time_s: float) -> float:
	if is_equal_approx(max_value, 150.0):
		return _erg_step_cadence_rpm
	if max_value <= float(max(_max_hr, 120)):
		var ratio := inverse_lerp(_erg_step_start_power_w, _erg_step_peak_power_w, _erg_step_target_power_at(time_s))
		return lerpf(_warmup_start_hr_bpm, float(_hr_zone_bounds[min(4, _hr_zone_bounds.size() - 1)]), clamp(ratio, 0.0, 1.0))
	return _erg_step_target_power_at(time_s)


func _erg_step_target_power_at(time_s: float) -> float:
	var step_count: int = max(1, int(ceil((_erg_step_peak_power_w - _erg_step_start_power_w) / _erg_step_watts)))
	var cycle_steps := step_count * 2
	var step_index := int(floor(time_s / _erg_step_duration_s)) % cycle_steps
	var offset_steps := step_index if step_index <= step_count else cycle_steps - step_index
	return min(_erg_step_peak_power_w, _erg_step_start_power_w + float(offset_steps) * _erg_step_watts)


func _ramp_curve_value(start_value: float, peak_value: float, time_s: float) -> float:
	var progress: float = clamp(time_s / max(_total_workout_s, 1.0), 0.0, 1.0)
	if progress <= 0.5:
		return lerpf(start_value, peak_value, progress * 2.0)
	return lerpf(peak_value, start_value, (progress - 0.5) * 2.0)


func _draw_hr_zones(plot: Rect2, hr_max: float) -> void:
	for bound in _hr_zone_bounds:
		var y := _y_for_value(plot, float(bound), hr_max)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.75, 0.25, 0.75, 0.30), 1.0)


func _draw_dotted_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var delta := to - from
	var length: float = delta.length()
	if length <= 0.0:
		return
	var direction: Vector2 = delta / length
	var dash_len := 8.0
	var gap_len := 5.0
	var distance: float = 0.0
	while distance < length:
		var segment_end: float = min(distance + dash_len, length)
		draw_line(from + direction * distance, from + direction * segment_end, color, width)
		distance += dash_len + gap_len


func _draw_title(plot: Rect2, text: String) -> void:
	var font := get_theme_default_font()
	font.draw_string(
		get_canvas_item(),
		Vector2(plot.position.x + 6.0, plot.position.y + 14.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		12,
		Color(0.88, 0.88, 0.88)
	)


func _draw_footer(plot: Rect2) -> void:
	var font := get_theme_default_font()
	var text := "Timeline: %s; " % _format_seconds(_total_workout_s)
	if _workout_kind == WORKOUT_RAMP_POWER_TEST:
		text += "blue ramp test, target rises to midpoint then falls; distance pending sidecar events"
	elif _workout_kind == WORKOUT_ERG_STEP_TEST:
		text += "gold ERG step test, 40 W target steps every 15s; distance pending sidecar events"
	else:
		text += "blue warmup, yellow first power-up, green recovery/card play, red power interval"
	font.draw_string(
		get_canvas_item(),
		Vector2(plot.position.x, plot.end.y + 18.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		12,
		Color(0.72, 0.72, 0.72)
	)


func _format_seconds(time_s: float) -> String:
	var total_seconds: int = max(0, roundi(time_s))
	return "%d:%02d" % [int(total_seconds / 60), total_seconds % 60]
