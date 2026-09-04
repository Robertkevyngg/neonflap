class_name Background
extends RefCounted

## Ceu, sol retro, duas camadas de skyline em parallax e o grid do chao.
## As silhuetas sao sorteadas uma vez com semente fixa, entao a cidade e
## sempre a mesma; o que muda por fase e so a cor.

const GRID_SPACING := 96.0
const SUN_R := 104.0

var _sky: GradientTexture2D
var _stars: Array = []          # [Vector2 pos, float raio, float brilho]
var _far: Array = []            # Rect2 dos predios distantes
var _near: Array = []
var _far_h := 150.0
var _near_h := 210.0

var scroll_far := 0.0
var scroll_near := 0.0
var scroll_grid := 0.0
var time := 0.0

var phase := 0
var prev_phase := 0
var blend := 1.0


func _init() -> void:
	_build_sky()
	_build_stars()
	_far = _build_skyline(11, _far_h, false)
	_near = _build_skyline(29, _near_h, true)


func _build_sky() -> void:
	var g := Gradient.new()
	g.set_color(0, Cfg.BG_TOP)
	g.set_color(1, Cfg.BG_BOTTOM)
	_sky = GradientTexture2D.new()
	_sky.gradient = g
	_sky.width = 8
	_sky.height = int(Cfg.LOGICAL_H)
	_sky.fill_from = Vector2(0, 0)
	_sky.fill_to = Vector2(0, 1)


func _build_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 110:
		_stars.append([
			Vector2(rng.randf() * Cfg.LOGICAL_W, rng.randf() * Cfg.LOGICAL_H * 0.55),
			1.0 if rng.randf() < 0.75 else 2.0,
			rng.randf_range(0.35, 1.0),
		])


func _build_skyline(seed_value: int, height: float, near: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	var x := -20.0
	while x < Cfg.LOGICAL_W + 20.0:
		var bw := rng.randf_range(34.0, 78.0) if near else rng.randf_range(22.0, 54.0)
		var bh := rng.randf_range(height * 0.30, height * 0.95)
		out.append(Rect2(x, height - bh, bw, bh))
		x += bw + rng.randf_range(4.0, 16.0)
	return out


# ------------------------------------------------------------------ fases
func set_phase(index: int) -> void:
	var wrapped := index % Cfg.PHASES.size()
	if wrapped != phase:
		prev_phase = phase
		phase = wrapped
		blend = 0.0


func phase_name() -> String:
	return str(Cfg.PHASES[phase]["name"])


func pipe_color() -> Color:
	return _mix("pipe")


func grid_color() -> Color:
	return _mix("grid")


func sun_color() -> Color:
	return _mix("sun")


func _mix(key: String) -> Color:
	var a: Color = Cfg.PHASES[prev_phase][key]
	var b: Color = Cfg.PHASES[phase][key]
	return a.lerp(b, clampf(blend, 0.0, 1.0))


# ------------------------------------------------------------------ update
func update(dt: float, speed: float) -> void:
	time += dt
	scroll_far = fposmod(scroll_far + speed * 0.10 * dt, Cfg.LOGICAL_W)
	scroll_near = fposmod(scroll_near + speed * 0.28 * dt, Cfg.LOGICAL_W)
	scroll_grid = fposmod(scroll_grid + speed * 1.15 * dt, GRID_SPACING)
	if blend < 1.0:
		blend = minf(1.0, blend + dt / 1.2)


# ------------------------------------------------------------------ desenho
func draw_sky(ci: CanvasItem) -> void:
	ci.draw_texture_rect(_sky, Rect2(0, 0, Cfg.LOGICAL_W, Cfg.LOGICAL_H), false)

	for s in _stars:
		var pos: Vector2 = s[0]
		var r: float = s[1]
		var base: float = s[2]
		var tw := 0.65 + 0.35 * sin(time * 1.7 + pos.x * 0.05)
		var v := base * tw
		ci.draw_circle(pos, r, Color(v, v, minf(1.0, v + 0.12)))

	var horizon := Cfg.floor_y()
	_draw_sun(ci, horizon)
	_draw_layer(ci, _far, horizon - _far_h, scroll_far, 0.55, 0.05)
	_draw_layer(ci, _near, horizon - _near_h, scroll_near, 0.30, 0.02)


func _draw_sun(ci: CanvasItem, horizon: float) -> void:
	var base := sun_color()
	var top := Color(minf(1.0, base.r * 2.1 + 0.27), minf(1.0, base.g * 2.1 + 0.27),
			minf(1.0, base.b * 2.1 + 0.27))
	var bottom := Color(minf(1.0, base.r * 1.15 + 0.08), minf(1.0, base.g * 1.15 + 0.08),
			minf(1.0, base.b * 1.15 + 0.08))
	var center := Vector2(Cfg.LOGICAL_W * 0.5, horizon - 101.0)

	# O disco e desenhado em faixas horizontais: as de baixo ganham vaos
	# crescentes, que e a assinatura do sol synthwave.
	var y := -SUN_R
	var band := 4.0
	var gap := 0.0
	while y < SUN_R:
		var h := minf(band, SUN_R - y)
		var yy := y + h * 0.5
		var half := sqrt(maxf(0.0, SUN_R * SUN_R - yy * yy))
		if half > 1.0:
			var t := (y + SUN_R) / (SUN_R * 2.0)
			var col := top.lerp(bottom, t)
			ci.draw_rect(Rect2(center.x - half, center.y + y, half * 2.0, h),
					Cfg.hdr(col, 1.25), true)
		y += h + gap
		if y > 0.0:
			gap += 1.6
			band = 3.0


func _draw_layer(ci: CanvasItem, rects: Array, top_y: float, scroll: float,
		tint: float, floor_add: float) -> void:
	var base := sun_color()
	var col := Color(base.r * tint + floor_add, base.g * tint + floor_add,
			base.b * tint + floor_add)
	for pass_i in 2:
		var ox := -scroll + float(pass_i) * Cfg.LOGICAL_W
		for r in rects:
			var rect: Rect2 = r
			ci.draw_rect(Rect2(rect.position.x + ox, rect.position.y + top_y,
					rect.size.x, rect.size.y), col, true)


func draw_ground(ci: CanvasItem) -> void:
	var horizon := Cfg.floor_y()
	var grid := grid_color()
	ci.draw_rect(Rect2(0, horizon, Cfg.LOGICAL_W, Cfg.GROUND_H),
			Color(0.024, 0.012, 0.063), true)

	# Linhas horizontais com espacamento em perspectiva.
	var y := 0.0
	var i := 0
	while y < Cfg.GROUND_H:
		var t := y / Cfg.GROUND_H
		ci.draw_line(Vector2(0, horizon + y), Vector2(Cfg.LOGICAL_W, horizon + y),
				Cfg.with_alpha(grid, 0.15 + 0.55 * t), 2.0, false)
		i += 1
		y += 5.0 + float(i) * 2.4

	# Verticais convergindo para o ponto de fuga.
	var cx := Cfg.LOGICAL_W * 0.5
	for k in range(-8, 9):
		var x_near := cx + float(k) * GRID_SPACING - scroll_grid
		var x_far := cx + (x_near - cx) * 0.16
		ci.draw_line(Vector2(x_far, horizon), Vector2(x_near, Cfg.LOGICAL_H),
				Cfg.with_alpha(grid, 0.42), 1.0, true)

	# Borda neon do horizonte.
	var pc := pipe_color()
	ci.draw_rect(Rect2(0, horizon - 6, Cfg.LOGICAL_W, 5), Cfg.hdr(pc), true)
	ci.draw_rect(Rect2(0, horizon - 12, Cfg.LOGICAL_W, 17),
			Cfg.with_alpha(pc, 0.18), true)
