extends Control

const MAX_WINDOW_S := 300.0
const PLOT_PAD_LEFT := 42.0
const PLOT_PAD_RIGHT := 12.0
const PLOT_PAD_TOP := 18.0
const PLOT_PAD_BOTTOM := 28.0

var _samples: Array[Dictionary] = []
var _max_hr := 180
var _weight_kg := 75.0
var _hr_zone_bounds: Array[int] = [90, 108, 126, 144, 162]
var _recovery_target_power_w := 140.0
var _interval_target_power_w := 300.0
var _recovery_target_hr_bpm := 126.0
var _interval_target_hr_bpm := 144.0
var _recovery_target_cadence_rpm := 80.0
var _interval_target_cadence_rpm := 100.0


func configure(
	weight_kg: float,
	max_hr: int,
	hr_zone_bounds: Array[int],
	recovery_target_power_w: float,
	interval_target_power_w: float,
	recovery_target_hr_bpm: float,
	interval_target_hr_bpm: float,
	recovery_target_cadence_rpm: float,
	interval_target_cadence_rpm: float
) -> void:
	_weight_kg = weight_kg
	_max_hr = max_hr
	_hr_zone_bounds = hr_zone_bounds.duplicate()
	_recovery_target_power_w = recovery_target_power_w
	_interval_target_power_w = interval_target_power_w
	_recovery_target_hr_bpm = recovery_target_hr_bpm
	_interval_target_hr_bpm = interval_target_hr_bpm
	_recovery_target_cadence_rpm = recovery_target_cadence_rpm
	_interval_target_cadence_rpm = interval_target_cadence_rpm
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
	var cutoff := time_s - MAX_WINDOW_S
	while not _samples.is_empty() and float(_samples[0]["time"]) < cutoff:
		_samples.pop_front()
	queue_redraw()


func _draw() -> void:
	var plot := _plot_rect()
	draw_rect(plot, Color(0.08, 0.08, 0.08, 1.0), true)
	draw_rect(plot, Color(0.35, 0.35, 0.35, 1.0), false, 1.0)
	if _samples.size() < 2:
		_draw_legend(plot)
		return

	_draw_phase_bands(plot)
	_draw_grid(plot)
	_draw_targets(plot)
	_draw_series(plot, "power", Color(0.95, 0.35, 0.22), _power_max())
	_draw_series(plot, "cadence", Color(0.25, 0.72, 1.0), 150.0)
	_draw_series(plot, "hr", Color(0.95, 0.2, 0.55), float(max(_max_hr, 120)))
	_draw_legend(plot)


func _plot_rect() -> Rect2:
	return Rect2(
		PLOT_PAD_LEFT,
		PLOT_PAD_TOP,
		max(1.0, size.x - PLOT_PAD_LEFT - PLOT_PAD_RIGHT),
		max(1.0, size.y - PLOT_PAD_TOP - PLOT_PAD_BOTTOM)
	)


func _time_min() -> float:
	return float(_samples[0]["time"])


func _time_max() -> float:
	return max(_time_min() + 1.0, float(_samples[-1]["time"]))


func _x_for_time(plot: Rect2, time_s: float) -> float:
	return plot.position.x + ((time_s - _time_min()) / (_time_max() - _time_min())) * plot.size.x


func _y_for_value(plot: Rect2, value: float, max_value: float) -> float:
	return plot.position.y + plot.size.y - clamp(value / max_value, 0.0, 1.0) * plot.size.y


func _power_max() -> float:
	var max_power: float = max(max(_recovery_target_power_w, _interval_target_power_w) * 1.35, 400.0)
	for sample in _samples:
		max_power = max(max_power, float(sample["power"]) * 1.1)
	return max_power


func _draw_grid(plot: Rect2) -> void:
	for i in range(1, 4):
		var y := plot.position.y + plot.size.y * float(i) / 4.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.18, 0.18, 0.18), 1.0)
	for i in range(1, 5):
		var x := plot.position.x + plot.size.x * float(i) / 5.0
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color(0.18, 0.18, 0.18), 1.0)


func _draw_phase_bands(plot: Rect2) -> void:
	var last_phase := int(_samples[0]["phase"])
	var start_time: float = _time_min()
	for sample in _samples:
		var phase := int(sample["phase"])
		if phase != last_phase:
			_draw_phase_band(plot, start_time, float(sample["time"]), last_phase)
			start_time = float(sample["time"])
			last_phase = phase
	_draw_phase_band(plot, start_time, _time_max(), last_phase)


func _draw_phase_band(plot: Rect2, start_time: float, end_time: float, phase: int) -> void:
	var x1: float = _x_for_time(plot, start_time)
	var x2: float = _x_for_time(plot, end_time)
	var color: Color = Color(0.1, 0.28, 0.14, 0.28) if phase == 0 else Color(0.36, 0.13, 0.08, 0.32)
	draw_rect(Rect2(x1, plot.position.y, max(1.0, x2 - x1), plot.size.y), color, true)


func _draw_targets(plot: Rect2) -> void:
	var last_phase := int(_samples[0]["phase"])
	var start_time: float = _time_min()
	for sample in _samples:
		var phase := int(sample["phase"])
		if phase != last_phase:
			_draw_target_segment(plot, start_time, float(sample["time"]), last_phase)
			start_time = float(sample["time"])
			last_phase = phase
	_draw_target_segment(plot, start_time, _time_max(), last_phase)


func _draw_target_segment(plot: Rect2, start_time: float, end_time: float, phase: int) -> void:
	var x1: float = _x_for_time(plot, start_time)
	var x2: float = _x_for_time(plot, end_time)
	var power_max: float = _power_max()
	var power_target: float = _recovery_target_power_w if phase == 0 else _interval_target_power_w
	var power_y: float = _y_for_value(plot, power_target, power_max)
	_draw_dotted_line(
		Vector2(x1, power_y),
		Vector2(x2, power_y),
		Color(1.0, 0.72, 0.22),
		2.0
	)

	var hr_max: float = float(max(_max_hr, 120))
	for bound in _hr_zone_bounds:
		var y: float = _y_for_value(plot, float(bound), hr_max)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(0.75, 0.25, 0.75, 0.35), 1.0)
	var hr_target: float = _recovery_target_hr_bpm if phase == 0 else _interval_target_hr_bpm
	var hr_y: float = _y_for_value(plot, hr_target, hr_max)
	_draw_dotted_line(
		Vector2(x1, hr_y),
		Vector2(x2, hr_y),
		Color(1.0, 0.45, 0.8),
		2.0
	)

	var cadence_target: float = _recovery_target_cadence_rpm if phase == 0 else _interval_target_cadence_rpm
	var cadence_y: float = _y_for_value(plot, cadence_target, 150.0)
	_draw_dotted_line(
		Vector2(x1, cadence_y),
		Vector2(x2, cadence_y),
		Color(0.35, 0.9, 1.0),
		2.0
	)


func _draw_dotted_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var delta := to - from
	var length: float = delta.length()
	if length <= 0.0:
		return
	var direction: Vector2 = delta / length
	var dash_len := 8.0
	var gap_len := 5.0
	var distance := 0.0
	while distance < length:
		var segment_end: float = min(distance + dash_len, length)
		draw_line(
			from + direction * distance,
			from + direction * segment_end,
			color,
			width
		)
		distance += dash_len + gap_len


func _draw_series(plot: Rect2, key: String, color: Color, max_value: float) -> void:
	var points := PackedVector2Array()
	for sample in _samples:
		points.append(Vector2(
			_x_for_time(plot, float(sample["time"])),
			_y_for_value(plot, float(sample[key]), max_value)
		))
	if points.size() >= 2:
		draw_polyline(points, color, 2.0)


func _draw_legend(plot: Rect2) -> void:
	var font := get_theme_default_font()
	var font_size := 12
	var x := plot.position.x + 6.0
	var y := plot.position.y + 14.0
	font.draw_string(get_canvas_item(), Vector2(x, y), "Power", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.95, 0.35, 0.22))
	font.draw_string(get_canvas_item(), Vector2(x + 56.0, y), "Cadence", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.25, 0.72, 1.0))
	font.draw_string(get_canvas_item(), Vector2(x + 126.0, y), "HR", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(0.95, 0.2, 0.55))
	font.draw_string(get_canvas_item(), Vector2(x + 168.0, y), "dotted phase targets", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(1.0, 0.75, 0.25))

	var elapsed := _time_max() - _time_min() if _samples.size() >= 2 else 0.0
	font.draw_string(
		get_canvas_item(),
		Vector2(plot.position.x, plot.end.y + 18.0),
		"Elapsed chart window: %.0fs; distance axis pending sidecar distance events" % elapsed,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		font_size,
		Color(0.72, 0.72, 0.72)
	)
