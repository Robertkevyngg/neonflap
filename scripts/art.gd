class_name Art
extends RefCounted

## Desenho procedural. Mesma logica da versao PC, mas o halo neon nao e
## mais um borrao calculado na CPU: cada traco e desenhado duas vezes
## (um largo e translucido, um fino e em HDR) e o bloom do Godot faz o
## resto na GPU. Se o bloom estiver desligado o jogo ainda fica legivel.


static func font() -> Font:
	return ThemeDB.fallback_font


# ------------------------------------------------------------------ tracos
static func neon_line(ci: CanvasItem, a: Vector2, b: Vector2, color: Color,
		width: float = 3.0) -> void:
	ci.draw_line(a, b, Cfg.with_alpha(color, 0.20), width * 3.0, true)
	ci.draw_line(a, b, Cfg.hdr(color), width, true)


static func neon_poly(ci: CanvasItem, pts: PackedVector2Array, color: Color,
		width: float = 3.0, closed: bool = true) -> void:
	var line := PackedVector2Array(pts)
	if closed and line.size() > 1:
		line.append(line[0])
	ci.draw_polyline(line, Cfg.with_alpha(color, 0.20), width * 3.0, true)
	ci.draw_polyline(line, Cfg.hdr(color), width, true)


static func neon_rect(ci: CanvasItem, r: Rect2, color: Color,
		width: float = 3.0) -> void:
	var pts := PackedVector2Array([
		r.position,
		r.position + Vector2(r.size.x, 0),
		r.position + r.size,
		r.position + Vector2(0, r.size.y),
	])
	neon_poly(ci, pts, color, width, true)


static func panel(ci: CanvasItem, r: Rect2, color: Color, alpha: float = 0.86) -> void:
	ci.draw_rect(r, Cfg.with_alpha(Cfg.INK, alpha), true)
	neon_rect(ci, r, color, 2.0)


# ------------------------------------------------------------------ texto
static func text_size(s: String, size: int) -> Vector2:
	return font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)


static func text_at(ci: CanvasItem, s: String, center: Vector2, size: int,
		color: Color, glow: bool = false) -> void:
	var f := font()
	var dim := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var pos := Vector2(center.x - dim.x * 0.5, center.y - dim.y * 0.5 + f.get_ascent(size))
	if glow:
		ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Cfg.hdr(color, Cfg.NEON_SOFT))
	else:
		ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_left(ci: CanvasItem, s: String, topleft: Vector2, size: int,
		color: Color) -> void:
	var f := font()
	ci.draw_string(f, topleft + Vector2(0, f.get_ascent(size)), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_right(ci: CanvasItem, s: String, topright: Vector2, size: int,
		color: Color) -> void:
	var f := font()
	var dim := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	ci.draw_string(f, topright + Vector2(-dim.x, f.get_ascent(size)), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Titulo com espacamento entre letras, encolhido para caber na largura.
static func title(ci: CanvasItem, s: String, center: Vector2, size: int,
		color: Color, spacing: float = 6.0, max_width: float = 448.0) -> void:
	var widths := PackedFloat32Array()
	var total := 0.0
	var cur := size
	while true:
		widths = PackedFloat32Array()
		total = 0.0
		for i in s.length():
			var w := text_size(s[i], cur).x
			widths.append(w)
			total += w
		total += spacing * float(s.length() - 1)
		if total <= max_width or cur <= 12:
			break
		cur = int(float(cur) * 0.94)

	var x := center.x - total * 0.5
	for i in s.length():
		text_at(ci, s[i], Vector2(x + widths[i] * 0.5, center.y), cur, color, true)
		x += widths[i] + spacing


# ------------------------------------------------------- digitos 7 segmentos
const SEGMENTS := {
	"0": "abcdef", "1": "bc", "2": "abged", "3": "abgcd", "4": "fgbc",
	"5": "afgcd", "6": "afgecd", "7": "abc", "8": "abcdefg", "9": "abcdfg",
	"-": "g", " ": "",
}


static func _segment_poly(seg: String, w: float, h: float, t: float) -> PackedVector2Array:
	var m := h * 0.5
	if seg == "a" or seg == "d" or seg == "g":
		var y := 0.0
		if seg == "g":
			y = m
		elif seg == "d":
			y = h
		return PackedVector2Array([
			Vector2(t * 0.6, y),
			Vector2(t * 1.2, y - t * 0.5),
			Vector2(w - t * 1.2, y - t * 0.5),
			Vector2(w - t * 0.6, y),
			Vector2(w - t * 1.2, y + t * 0.5),
			Vector2(t * 1.2, y + t * 0.5),
		])

	var x := w
	if seg == "f" or seg == "e":
		x = 0.0
	var y0 := m
	var y1 := h
	if seg == "f" or seg == "b":
		y0 = 0.0
		y1 = m
	return PackedVector2Array([
		Vector2(x, y0 + t * 0.6),
		Vector2(x + t * 0.5, y0 + t * 1.1),
		Vector2(x + t * 0.5, y1 - t * 1.1),
		Vector2(x, y1 - t * 0.6),
		Vector2(x - t * 0.5, y1 - t * 1.1),
		Vector2(x - t * 0.5, y0 + t * 1.1),
	])


static func digit_metrics(h: float) -> Dictionary:
	var w := h * 0.60
	var t := maxf(2.0, h * 0.10)
	return {"w": w, "t": t, "ink": w + t, "advance": w + t + h * 0.18}


## Desenha os digitos de `s` centrados em `center`, no estilo display de LED.
static func number(ci: CanvasItem, s: String, center: Vector2, h: float,
		color: Color) -> void:
	if s.is_empty():
		return
	var m := digit_metrics(h)
	var advance: float = m["advance"]
	var dw: float = m["w"]
	var dt: float = m["t"]
	var total := advance * float(s.length()) - h * 0.18
	var x := center.x - total * 0.5 - dt * 0.5
	var y := center.y - h * 0.5

	var lit := Cfg.hdr(color)
	var off := Cfg.with_alpha(color, 0.10)

	for i in s.length():
		var on: String = SEGMENTS.get(s[i], "")
		for seg in ["a", "b", "c", "d", "e", "f", "g"]:
			var pts := _segment_poly(seg, dw, h, dt)
			var moved := PackedVector2Array()
			for p in pts:
				moved.append(p + Vector2(x, y))
			if on.contains(seg):
				ci.draw_colored_polygon(moved, lit)
			else:
				ci.draw_colored_polygon(moved, off)
		x += advance


# ------------------------------------------------------------------ jogador
static func craft_points(w: float, h: float) -> PackedVector2Array:
	## Silhueta apontando para a direita, centrada na origem.
	var cx := w * 0.5
	var cy := h * 0.5
	return PackedVector2Array([
		Vector2(w * 0.98 - cx, 0.0),
		Vector2(w * 0.62 - cx, -h * 0.30),
		Vector2(w * 0.16 - cx, -h * 0.42),
		Vector2(w * 0.30 - cx, 0.0),
		Vector2(w * 0.16 - cx, h * 0.42),
		Vector2(w * 0.62 - cx, h * 0.30),
	])


## `wing` vai de -1 (asa baixa) a 1 (asa alta). `rot` em radianos.
static func craft(ci: CanvasItem, pos: Vector2, rot: float, scale: float,
		primary: Color, secondary: Color, wing: float) -> void:
	var w := 54.0
	var h := 40.0
	ci.draw_set_transform(pos, rot, Vector2(scale, scale))

	var body := craft_points(w, h)
	ci.draw_colored_polygon(body, Cfg.with_alpha(primary, 0.18))
	neon_poly(ci, body, primary, 3.0, true)

	neon_line(ci, Vector2(w * 0.36 - w * 0.5, 0), Vector2(w * 0.82 - w * 0.5, 0),
			secondary, 2.0)

	var reach := h * 0.66 * wing
	var wing_pts := PackedVector2Array([
		Vector2(w * 0.32 - w * 0.5, -h * 0.05),
		Vector2(w * 0.64 - w * 0.5, -h * 0.05),
		Vector2(w * 0.44 - w * 0.5, -h * 0.05 - reach),
	])
	ci.draw_colored_polygon(wing_pts, Cfg.with_alpha(secondary, 0.38))
	neon_poly(ci, wing_pts, secondary, 3.0, true)

	var cockpit := Vector2(w * 0.70 - w * 0.5, 0)
	ci.draw_circle(cockpit, 5.0, Cfg.hdr(secondary, Cfg.NEON_SOFT))
	ci.draw_circle(cockpit, 3.0, Cfg.hdr(Color(1, 1, 1), Cfg.NEON_SOFT))

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# -------------------------------------------------------------------- canos
static func pipe_column(ci: CanvasItem, x: float, from_y: float, to_y: float,
		color: Color, cap_on_top: bool) -> void:
	## Desenha um cano de `from_y` ate `to_y` com a cabeca na ponta virada
	## para a abertura.
	if to_y <= from_y:
		return
	var w := Cfg.PIPE_W
	var cap_h := Cfg.PIPE_CAP_H
	var cap_w := w + 16.0
	var inset := (cap_w - w) * 0.5

	var body := Rect2(x, from_y, w, to_y - from_y)
	ci.draw_rect(body, Cfg.with_alpha(Cfg.INK, 0.92), true)

	# Laterais acesas.
	neon_line(ci, Vector2(x + 1.5, from_y), Vector2(x + 1.5, to_y), color, 3.0)
	neon_line(ci, Vector2(x + w - 1.5, from_y), Vector2(x + w - 1.5, to_y), color, 3.0)
	ci.draw_line(Vector2(x + w * 0.30, from_y), Vector2(x + w * 0.30, to_y),
			Cfg.with_alpha(color, 0.30), 2.0, true)

	# Nervuras.
	var rib := Cfg.with_alpha(color, 0.16)
	var y := from_y + 16.0
	while y < to_y:
		ci.draw_line(Vector2(x + 6, y), Vector2(x + w - 6, y), rib, 2.0, true)
		y += 22.0

	# Cabeca.
	var cap_y := from_y if cap_on_top else to_y - cap_h
	var cap := Rect2(x - inset, cap_y, cap_w, cap_h)
	ci.draw_rect(cap, Cfg.with_alpha(Cfg.INK, 0.95), true)
	neon_rect(ci, cap, color, 3.0)
	var hl := cap_y + cap_h * 0.34
	ci.draw_line(Vector2(cap.position.x + 8, hl),
			Vector2(cap.position.x + cap_w - 8, hl),
			Cfg.hdr(Color(1, 1, 1), Cfg.NEON_SOFT), 2.0, true)


# ----------------------------------------------------------------- power-ups
static func powerup(ci: CanvasItem, pos: Vector2, kind: String, t: float) -> void:
	var r := Cfg.POWERUP_RADIUS
	var color := Cfg.CYAN
	if kind == "slowmo":
		color = Cfg.PURPLE
	elif kind == "magnet":
		color = Cfg.AMBER

	var pulse := 1.0 + 0.07 * sin(t * 4.5)
	ci.draw_set_transform(pos, 0.0, Vector2(pulse, pulse))

	var hexa := PackedVector2Array()
	for i in 6:
		var a := deg_to_rad(float(i) * 60.0)
		hexa.append(Vector2(cos(a), sin(a)) * r)
	ci.draw_colored_polygon(hexa, Cfg.with_alpha(color, 0.28))
	neon_poly(ci, hexa, color, 3.0, true)

	var ink := Color(1, 1, 1)
	if kind == "shield":
		var s := PackedVector2Array([
			Vector2(0, -r * 0.60),
			Vector2(r * 0.46, -r * 0.24),
			Vector2(r * 0.36, r * 0.46),
			Vector2(0, r * 0.62),
			Vector2(-r * 0.36, r * 0.46),
			Vector2(-r * 0.46, -r * 0.24),
		])
		neon_poly(ci, s, ink, 2.0, true)
	elif kind == "slowmo":
		ci.draw_arc(Vector2.ZERO, r * 0.56, 0.0, TAU, 20, Cfg.hdr(ink, Cfg.NEON_SOFT), 2.0, true)
		neon_line(ci, Vector2.ZERO, Vector2(0, -r * 0.40), ink, 2.0)
		neon_line(ci, Vector2.ZERO, Vector2(r * 0.30, 0), ink, 2.0)
	else:
		ci.draw_arc(Vector2(0, -r * 0.05), r * 0.55, PI, TAU, 16,
				Cfg.hdr(ink, Cfg.NEON_SOFT), 3.0, true)
		neon_line(ci, Vector2(-r * 0.55, -r * 0.05), Vector2(-r * 0.55, r * 0.55), ink, 3.0)
		neon_line(ci, Vector2(r * 0.55, -r * 0.05), Vector2(r * 0.55, r * 0.55), ink, 3.0)

	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
