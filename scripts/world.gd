class_name World
extends RefCounted

## Simulacao da partida: fisica, canos, pontuacao, power-ups e colisao.
## Porte direto de neonflap/world.py — mesmos numeros, mesmo resultado.

const READY := 0
const PLAYING := 1
const DYING := 2
const DEAD := 3

const POWERUP_KINDS := ["shield", "slowmo", "magnet"]
const MAX_PARTICLES := 260


class Pipe extends RefCounted:
	var x: float
	var gap_y: float
	var gap_h: float
	var scored := false

	func _init(px: float, pgy: float, pgh: float) -> void:
		x = px
		gap_y = pgy
		gap_h = pgh

	func gap_top() -> float:
		return gap_y - gap_h * 0.5

	func gap_bottom() -> float:
		return gap_y + gap_h * 0.5


class Item extends RefCounted:
	var x: float
	var base_y: float
	var y: float
	var kind: String
	var t := 0.0
	var taken := false

	func _init(px: float, py: float, k: String) -> void:
		x = px
		base_y = py
		y = py
		kind = k


var bg: Background
var sfx: Sfx
var rng := RandomNumberGenerator.new()

var pipes: Array = []
var items: Array = []
var particles: Array = []

var state := READY
var score := 0
var elapsed := 0.0
var death_timer := 0.0
var shake := 0.0
var flash := 0.0

var bird_y := Cfg.LOGICAL_H * 0.42
var bird_vel := 0.0
var bird_rot := 0.0
var bird_anim := 0.0
var flaps := 0

var skin: Dictionary = Cfg.SKINS[0]

var shield := false
var slowmo := 0.0
var magnet := 0.0
var invuln := 0.0
var powerups_taken := 0

var last_gap_y := Cfg.floor_y() * 0.5


func _init(background: Background, audio: Sfx) -> void:
	bg = background
	sfx = audio
	rng.randomize()


# ------------------------------------------------------------------ ciclo
func reset(skin_id: String) -> void:
	skin = Cfg.skin_by_id(skin_id)
	pipes.clear()
	items.clear()
	particles.clear()

	state = READY
	score = 0
	elapsed = 0.0
	death_timer = 0.0
	shake = 0.0
	flash = 0.0

	bird_y = Cfg.LOGICAL_H * 0.42
	bird_vel = 0.0
	bird_rot = 0.0
	bird_anim = 0.0
	flaps = 0

	shield = false
	slowmo = 0.0
	magnet = 0.0
	invuln = 0.0
	powerups_taken = 0

	last_gap_y = Cfg.floor_y() * 0.5
	bg.set_phase(0)
	bg.blend = 1.0

	var x := Cfg.LOGICAL_W + 120.0
	for i in 3:
		_spawn_pipe(x)
		x += spacing()


# ------------------------------------------------------------- dificuldade
func ramp() -> float:
	var step: int = mini(Cfg.RAMP_STEPS, int(score / Cfg.RAMP_EVERY))
	return float(step) / float(Cfg.RAMP_STEPS)


func speed() -> float:
	return Cfg.SPEED_START + (Cfg.SPEED_MAX - Cfg.SPEED_START) * ramp()


func gap() -> float:
	return Cfg.GAP_START + (Cfg.GAP_MIN - Cfg.GAP_START) * ramp()


func spacing() -> float:
	return Cfg.PIPE_SPACING_START + (Cfg.PIPE_SPACING_MIN - Cfg.PIPE_SPACING_START) * ramp()


func time_scale() -> float:
	return Cfg.SLOWMO_FACTOR if slowmo > 0.0 else 1.0


# ------------------------------------------------------------------ spawn
func _spawn_pipe(x: float) -> void:
	var gap_h := gap()
	var floor_y := Cfg.floor_y()
	var lo := Cfg.CEILING_MARGIN + gap_h * 0.5 + Cfg.GAP_MARGIN * 0.4
	var hi := floor_y - gap_h * 0.5 - Cfg.GAP_MARGIN * 0.4

	# Limita o salto vertical entre canos: sem isso o jogo sorteia
	# sequencias fisicamente impossiveis.
	var max_delta := 150.0 + 60.0 * (1.0 - ramp())
	lo = maxf(lo, last_gap_y - max_delta)
	hi = minf(hi, last_gap_y + max_delta)
	if hi < lo:
		var tmp := lo
		lo = hi
		hi = tmp

	var gy := rng.randf_range(lo, hi)
	last_gap_y = gy
	pipes.append(Pipe.new(x, gy, gap_h))

	if score >= Cfg.POWERUP_MIN_SCORE and rng.randf() < Cfg.POWERUP_CHANCE and items.is_empty():
		var kind: String = POWERUP_KINDS[rng.randi_range(0, POWERUP_KINDS.size() - 1)]
		items.append(Item.new(x + Cfg.PIPE_W * 0.5, gy, kind))


# ------------------------------------------------------------------ input
func flap() -> void:
	if state == READY:
		state = PLAYING
	if state != PLAYING:
		return
	bird_vel = Cfg.FLAP_IMPULSE
	bird_anim = 0.0
	flaps += 1
	sfx.play("flap")
	emit(Vector2(Cfg.BIRD_X - 16, bird_y + 6), skin["b"], 7, 170.0, 0.32, 3.0,
			0.0, PI * 0.72, 1.0)


# ------------------------------------------------------------- particulas
func emit(pos: Vector2, color: Color, count: int, spd: float, life: float,
		radius: float, gravity: float = 0.0, direction: float = 0.0,
		spread: float = TAU) -> void:
	var room := MAX_PARTICLES - particles.size()
	var n: int = mini(count, maxi(0, room))
	for i in n:
		var angle := direction + rng.randf_range(-spread * 0.5, spread * 0.5)
		var v := spd * rng.randf_range(0.35, 1.0)
		var ttl := life * rng.randf_range(0.6, 1.25)
		particles.append([
			pos,
			Vector2(cos(angle), sin(angle)) * v,
			ttl, ttl,
			radius * rng.randf_range(0.6, 1.3),
			color,
			gravity,
		])


func _update_particles(dt: float, drift: float) -> void:
	var alive: Array = []
	for p in particles:
		p[2] -= dt
		if p[2] <= 0.0:
			continue
		var vel: Vector2 = p[1]
		vel.y += p[6] * dt
		p[1] = vel
		p[0] = (p[0] as Vector2) + Vector2(vel.x - drift, vel.y) * dt
		alive.append(p)
	particles = alive


# ------------------------------------------------------------------ update
func update(dt: float) -> void:
	var raw_dt := dt
	var sdt := dt * time_scale()

	flash = maxf(0.0, flash - raw_dt * 3.0)
	shake = maxf(0.0, shake - raw_dt * 2.4)

	if state == READY:
		bird_anim += raw_dt * 9.0
		bird_y += sin(bird_anim * 0.55) * 22.0 * raw_dt
		bird_rot = deg_to_rad(sin(bird_anim * 0.55) * 6.0)
		bg.update(raw_dt, Cfg.SPEED_START * 0.5)
		_update_particles(raw_dt, 0.0)
		return

	if state == DYING or state == DEAD:
		death_timer += raw_dt
		_update_particles(raw_dt, 0.0)
		if state == DYING:
			bird_vel = minf(Cfg.MAX_FALL_SPEED, bird_vel + Cfg.GRAVITY * raw_dt)
			bird_y += bird_vel * raw_dt
			bird_rot = minf(deg_to_rad(96.0), bird_rot + deg_to_rad(300.0) * raw_dt)
			var fl := Cfg.floor_y() - Cfg.BIRD_RADIUS
			if bird_y >= fl:
				bird_y = fl
				state = DEAD
				shake = maxf(shake, 0.5)
				emit(Vector2(Cfg.BIRD_X, fl), skin["a"], 18, 220.0, 0.6, 3.5,
						520.0, -PI * 0.5, PI)
		return

	# ---------------------------------------------------------- jogando
	elapsed += raw_dt
	slowmo = maxf(0.0, slowmo - raw_dt)
	magnet = maxf(0.0, magnet - raw_dt)
	invuln = maxf(0.0, invuln - raw_dt)

	var spd := speed()

	bird_vel = minf(Cfg.MAX_FALL_SPEED, bird_vel + Cfg.GRAVITY * sdt)
	bird_y += bird_vel * sdt
	if bird_vel < 0.0:
		bird_rot += (deg_to_rad(Cfg.TILT_UP) - bird_rot) * minf(1.0, sdt * 14.0)
	else:
		bird_rot = minf(deg_to_rad(Cfg.TILT_DOWN),
				bird_rot + deg_to_rad(Cfg.TILT_SPEED) * sdt * (bird_vel / 700.0))
	bird_anim += sdt * (16.0 if bird_vel < 0.0 else 7.0)

	if int(bird_anim * 3.0) % 2 == 0:
		emit(Vector2(Cfg.BIRD_X - 20, bird_y), skin["a"], 1, 40.0, 0.42, 2.6,
				0.0, PI, 0.8)

	bg.update(sdt, spd)
	_update_particles(sdt, spd * 0.35)

	# Teto: nao mata, so trava.
	if bird_y < Cfg.BIRD_RADIUS + 4.0:
		bird_y = Cfg.BIRD_RADIUS + 4.0
		bird_vel = maxf(0.0, bird_vel)

	for p in pipes:
		p.x -= spd * sdt
	for it in items:
		it.x -= spd * sdt
		it.t += sdt
		it.y = it.base_y + sin(it.t * 3.0) * 9.0
		if magnet > 0.0:
			_attract(it, sdt)

	# Reciclagem e spawn.
	var kept: Array = []
	for p in pipes:
		if p.x + Cfg.PIPE_W >= -40.0:
			kept.append(p)
	pipes = kept

	var kept_items: Array = []
	for it in items:
		if it.x >= -40.0 and not it.taken:
			kept_items.append(it)
	items = kept_items

	if pipes.is_empty():
		_spawn_pipe(Cfg.LOGICAL_W + 60.0)
	elif pipes[pipes.size() - 1].x < Cfg.LOGICAL_W - spacing():
		_spawn_pipe(pipes[pipes.size() - 1].x + spacing())

	_check_score()
	_check_items()
	_check_collisions()


func _attract(it: Item, dt: float) -> void:
	var dx := Cfg.BIRD_X - it.x
	var dy := bird_y - it.y
	var dist := sqrt(dx * dx + dy * dy)
	if dist > 0.0 and dist < Cfg.MAGNET_RANGE:
		var pull := (1.0 - dist / Cfg.MAGNET_RANGE) * 620.0
		it.x += dx / dist * pull * dt
		it.base_y += dy / dist * pull * dt


# ------------------------------------------------------------------ regras
func _check_score() -> void:
	for p in pipes:
		if not p.scored and p.x + Cfg.PIPE_W < Cfg.BIRD_X - Cfg.BIRD_RADIUS:
			p.scored = true
			score += 1
			sfx.play("score")
			emit(Vector2(Cfg.BIRD_X + 10, bird_y), bg.pipe_color(), 10, 170.0,
					0.4, 3.0)
			if score % Cfg.PHASE_EVERY == 0:
				bg.set_phase(int(score / Cfg.PHASE_EVERY))
				flash = 0.55


func _check_items() -> void:
	for it in items:
		if it.taken:
			continue
		var dx: float = it.x - Cfg.BIRD_X
		var dy: float = it.y - bird_y
		if sqrt(dx * dx + dy * dy) <= Cfg.BIRD_RADIUS + Cfg.POWERUP_RADIUS:
			it.taken = true
			powerups_taken += 1
			sfx.play("powerup")
			flash = maxf(flash, 0.35)
			emit(Vector2(it.x, it.y), Cfg.WHITE, 20, 230.0, 0.5, 3.2)
			if it.kind == "shield":
				shield = true
			elif it.kind == "slowmo":
				slowmo = Cfg.SLOWMO_DURATION
			else:
				magnet = Cfg.MAGNET_DURATION


static func circle_hits_rect(cx: float, cy: float, r: float, rect: Rect2) -> bool:
	var nx := clampf(cx, rect.position.x, rect.position.x + rect.size.x)
	var ny := clampf(cy, rect.position.y, rect.position.y + rect.size.y)
	var dx := cx - nx
	var dy := cy - ny
	return dx * dx + dy * dy <= r * r


func _check_collisions() -> void:
	var floor_y := Cfg.floor_y()
	if bird_y + Cfg.BIRD_RADIUS >= floor_y:
		bird_y = floor_y - Cfg.BIRD_RADIUS
		_die(true)
		return

	if invuln > 0.0:
		return

	for p in pipes:
		if p.x > Cfg.BIRD_X + Cfg.BIRD_RADIUS:
			continue
		if p.x + Cfg.PIPE_W < Cfg.BIRD_X - Cfg.BIRD_RADIUS:
			continue
		var top := Rect2(p.x, 0.0, Cfg.PIPE_W, p.gap_top())
		var bottom := Rect2(p.x, p.gap_bottom(), Cfg.PIPE_W,
				Cfg.LOGICAL_H - p.gap_bottom())
		if circle_hits_rect(Cfg.BIRD_X, bird_y, Cfg.BIRD_RADIUS, top) \
				or circle_hits_rect(Cfg.BIRD_X, bird_y, Cfg.BIRD_RADIUS, bottom):
			if shield:
				_break_shield()
			else:
				_die(false)
			return


func _break_shield() -> void:
	shield = false
	invuln = 1.1
	shake = maxf(shake, 0.45)
	flash = maxf(flash, 0.5)
	sfx.play("shield")
	emit(Vector2(Cfg.BIRD_X, bird_y), Cfg.CYAN, 26, 280.0, 0.55, 3.4)


func _die(on_ground: bool) -> void:
	if state == DYING or state == DEAD:
		return
	sfx.play("hit")
	shake = 0.7
	flash = 0.7
	emit(Vector2(Cfg.BIRD_X, bird_y), Cfg.DANGER, 26, 300.0, 0.6, 3.6, 420.0)
	bird_vel = 0.0 if on_ground else -220.0
	state = DEAD if on_ground else DYING
	if on_ground:
		death_timer = 0.0


# ------------------------------------------------------------------ desenho
func shake_offset() -> Vector2:
	if shake <= 0.0:
		return Vector2.ZERO
	var power := shake * 12.0
	return Vector2(rng.randf_range(-power, power), rng.randf_range(-power, power))


func draw_world(ci: CanvasItem) -> void:
	bg.draw_sky(ci)

	var color := bg.pipe_color()
	for p in pipes:
		Art.pipe_column(ci, p.x, 0.0, p.gap_top(), color, false)
		Art.pipe_column(ci, p.x, p.gap_bottom(), Cfg.LOGICAL_H, color, true)

	for it in items:
		Art.powerup(ci, Vector2(it.x, it.y), it.kind, it.t)

	_draw_particles(ci)

	var blink := invuln > 0.0 and int(invuln * 12.0) % 2 == 0
	if not blink:
		var wing := sin(bird_anim)
		Art.craft(ci, Vector2(Cfg.BIRD_X, bird_y), bird_rot, 1.0,
				skin["a"], skin["b"], wing)
		if shield:
			var rr := Cfg.BIRD_RADIUS + 12.0
			ci.draw_arc(Vector2(Cfg.BIRD_X, bird_y), rr, 0.0, TAU, 28,
					Cfg.hdr(Cfg.CYAN), 3.0, true)

	bg.draw_ground(ci)

	if flash > 0.0:
		ci.draw_rect(Rect2(0, 0, Cfg.LOGICAL_W, Cfg.LOGICAL_H),
				Color(1, 1, 1, flash * 0.35), true)


func _draw_particles(ci: CanvasItem) -> void:
	for p in particles:
		var life: float = p[2]
		var life_max: float = p[3]
		var t := clampf(life / life_max, 0.0, 1.0)
		var r: float = maxf(1.0, (p[4] as float) * (0.35 + 0.65 * t))
		var c: Color = p[5]
		ci.draw_circle(p[0] as Vector2, r, Cfg.hdr(Cfg.with_alpha(c, t * t), 1.8))


func draw_hud(ci: CanvasItem) -> void:
	if state == READY:
		return
	Art.number(ci, str(score), Vector2(Cfg.LOGICAL_W * 0.5, 92), 76.0, Cfg.WHITE)

	var x := 16.0
	var y := Cfg.floor_y() - 44.0
	if shield:
		Art.text_left(ci, "ESCUDO", Vector2(x, y), 22, Cfg.hdr(Cfg.CYAN, 1.2))
		x += 92.0
	if slowmo > 0.0:
		Art.text_left(ci, "SLOW %0.1f" % slowmo, Vector2(x, y), 22,
				Cfg.hdr(Cfg.PURPLE, 1.2))
		x += 118.0
	if magnet > 0.0:
		Art.text_left(ci, "ÍMÃ %0.1f" % magnet, Vector2(x, y), 22,
				Cfg.hdr(Cfg.AMBER, 1.2))
