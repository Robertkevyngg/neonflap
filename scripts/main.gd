extends Node2D

## Cola tudo: telas, entrada (toque/mouse/teclado) e o loop de desenho.
## Todo o jogo e desenhado em modo imediato dentro de _draw(), igual a
## versao PC — o bloom do WorldEnvironment cuida do brilho neon.

const MENU := 0
const PLAY := 1
const GAMEOVER := 2
const SKINS := 3
const STATS := 4

const MENU_ITEMS := [
	{"label": "JOGAR", "to": PLAY},
	{"label": "SKINS", "to": SKINS},
	{"label": "ESTATÍSTICAS", "to": STATS},
	{"label": "SAIR", "to": -1},
]

var save: SaveData
var sfx: Sfx
var bg: Background
var world: World

var screen := MENU
var t := 0.0
var fade := 0.0
var menu_index := 0
var skin_index := 0
var paused := false

# Resultado da ultima partida, congelado para a tela de fim de jogo.
var last_score := 0
var last_seconds := 0.0
var last_record := false
var last_unlock := ""
var last_best := 0


func _ready() -> void:
	randomize()
	_setup_environment()

	save = SaveData.new()
	sfx = Sfx.new()
	sfx.name = "Sfx"
	add_child(sfx)
	sfx.muted = bool(save.get_value("muted"))
	sfx.music_on = bool(save.get_value("music_on"))

	bg = Background.new()
	world = World.new(bg, sfx)
	world.reset(str(save.get_value("selected_skin")))

	skin_index = _skin_index_of(str(save.get_value("selected_skin")))
	sfx.start_music()
	_go(MENU)


## Bloom: e ele que transforma as cores em HDR num brilho de neon.
func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.95
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.4)

	var we := WorldEnvironment.new()
	we.name = "Env"
	we.environment = env
	add_child(we)


func _skin_index_of(sid: String) -> int:
	for i in Cfg.SKINS.size():
		if str(Cfg.SKINS[i]["id"]) == sid:
			return i
	return 0


# ------------------------------------------------------------------ telas
func _go(to: int) -> void:
	screen = to
	t = 0.0
	fade = 1.0
	paused = false

	if to == MENU:
		menu_index = 0
		world.reset(str(save.get_value("selected_skin")))
		sfx.duck_music(1.0)
		sfx.start_music()
	elif to == PLAY:
		world.reset(str(save.get_value("selected_skin")))
		sfx.duck_music(1.0)
		sfx.start_music()
	elif to == GAMEOVER:
		var prev_best := save.best()
		last_score = world.score
		last_seconds = world.elapsed
		last_record = save.record_run(world.score, world.elapsed, world.flaps,
				world.powerups_taken)
		last_best = save.best()
		last_unlock = save.unlocked_between(prev_best, last_best)
		sfx.duck_music(0.45)
	elif to == SKINS:
		skin_index = _skin_index_of(str(save.get_value("selected_skin")))


# ------------------------------------------------------------------ entrada
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed:
			_on_tap((event as InputEventScreenTouch).position)
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_on_tap(mb.position)
		return

	if event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		_on_key((event as InputEventKey).keycode)


func _on_key(code: int) -> void:
	# Atalhos globais.
	if code == KEY_M:
		save.set_value("muted", sfx.toggle_mute())
		save.save_file()
		return
	if code == KEY_N:
		save.set_value("music_on", sfx.toggle_music())
		save.save_file()
		return

	match screen:
		MENU:
			if code == KEY_DOWN or code == KEY_S:
				menu_index = wrapi(menu_index + 1, 0, MENU_ITEMS.size())
				sfx.play("ui")
			elif code == KEY_UP or code == KEY_W:
				menu_index = wrapi(menu_index - 1, 0, MENU_ITEMS.size())
				sfx.play("ui")
			elif code == KEY_ENTER or code == KEY_SPACE or code == KEY_KP_ENTER:
				_activate_menu()
			elif code == KEY_ESCAPE:
				get_tree().quit()
		PLAY:
			if code == KEY_ESCAPE or code == KEY_P:
				if world.state == World.DYING or world.state == World.DEAD:
					_go(MENU)
				else:
					paused = not paused
					sfx.play("ui")
			elif code == KEY_SPACE or code == KEY_UP or code == KEY_W:
				if paused:
					paused = false
				else:
					world.flap()
		GAMEOVER:
			if code == KEY_ESCAPE:
				_go(MENU)
			else:
				_go(PLAY)
		SKINS:
			if code == KEY_ESCAPE or code == KEY_BACKSPACE:
				_go(MENU)
			elif code == KEY_RIGHT or code == KEY_D:
				skin_index = wrapi(skin_index + 1, 0, Cfg.SKINS.size())
				sfx.play("ui")
			elif code == KEY_LEFT or code == KEY_A:
				skin_index = wrapi(skin_index - 1, 0, Cfg.SKINS.size())
				sfx.play("ui")
			elif code == KEY_DOWN or code == KEY_S:
				skin_index = wrapi(skin_index + 2, 0, Cfg.SKINS.size())
				sfx.play("ui")
			elif code == KEY_UP or code == KEY_W:
				skin_index = wrapi(skin_index - 2, 0, Cfg.SKINS.size())
				sfx.play("ui")
			elif code == KEY_ENTER or code == KEY_SPACE or code == KEY_KP_ENTER:
				_pick_skin()
		STATS:
			_go(MENU)


func _activate_menu() -> void:
	sfx.play("ui")
	var to := int(MENU_ITEMS[menu_index]["to"])
	if to < 0:
		get_tree().quit()
	else:
		_go(to)


func _pick_skin() -> void:
	var s: Dictionary = Cfg.SKINS[skin_index]
	if save.best() >= int(s["req"]):
		save.set_value("selected_skin", str(s["id"]))
		save.save_file()
		world.skin = s
		sfx.play("powerup")
	else:
		sfx.play("hit", 0.4)


## Toque na tela. Cada tela decide o que fazer com a posicao.
func _on_tap(pos: Vector2) -> void:
	match screen:
		MENU:
			# Toque num item do menu seleciona; em qualquer outro lugar, joga.
			for i in MENU_ITEMS.size():
				var r := _menu_item_rect(i)
				if r.has_point(pos):
					menu_index = i
					_activate_menu()
					return
			_go(PLAY)
		PLAY:
			if paused:
				paused = false
			else:
				world.flap()
		GAMEOVER:
			# Evita reiniciar sem querer no toque que matou o jogador.
			if t > 0.4:
				if _back_rect().has_point(pos):
					_go(MENU)
				else:
					_go(PLAY)
		SKINS:
			for i in Cfg.SKINS.size():
				if _skin_card_rect(i).has_point(pos):
					skin_index = i
					_pick_skin()
					return
			if _back_rect().has_point(pos):
				_go(MENU)
		STATS:
			_go(MENU)


func _back_rect() -> Rect2:
	return Rect2(Cfg.LOGICAL_W * 0.5 - 90, Cfg.LOGICAL_H - 92, 180, 60)


func _menu_item_rect(i: int) -> Rect2:
	return Rect2(60, 566 + float(i) * 52.0 - 24.0, Cfg.LOGICAL_W - 120, 48)


func _skin_card_rect(i: int) -> Rect2:
	var card_w := 196.0
	var card_h := 150.0
	var gap := 18.0
	var start_x := (Cfg.LOGICAL_W - (card_w * 2.0 + gap)) * 0.5
	var col := i % 2
	var row := int(i / 2)
	return Rect2(start_x + float(col) * (card_w + gap),
			160.0 + float(row) * (card_h + gap), card_w, card_h)


# ------------------------------------------------------------------ loop
func _process(delta: float) -> void:
	var dt: float = minf(0.05, delta)
	t += dt
	if fade > 0.0:
		fade = maxf(0.0, fade - dt * 3.4)

	match screen:
		MENU:
			bg.update(dt, Cfg.SPEED_START * 0.55)
			world.bird_anim += dt * 6.0
		PLAY:
			if not paused:
				world.update(dt)
				if world.state == World.DEAD and world.death_timer > 0.55:
					_go(GAMEOVER)
		GAMEOVER:
			world._update_particles(dt, 0.0)
		SKINS, STATS:
			bg.update(dt, Cfg.SPEED_START * 0.35)

	position = world.shake_offset() if screen == PLAY else Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	match screen:
		MENU:
			_draw_menu()
		PLAY:
			_draw_play()
		GAMEOVER:
			_draw_gameover()
		SKINS:
			_draw_skins()
		STATS:
			_draw_stats()

	if fade > 0.0:
		draw_rect(Rect2(-40, -40, Cfg.LOGICAL_W + 80, Cfg.LOGICAL_H + 80),
				Color(0, 0, 0, fade), true)


func _veil(alpha: float) -> void:
	draw_rect(Rect2(0, 0, Cfg.LOGICAL_W, Cfg.LOGICAL_H),
			Color(0.024, 0.012, 0.071, alpha), true)


# --------------------------------------------------------------- tela menu
func _draw_menu() -> void:
	bg.draw_sky(self)
	bg.draw_ground(self)
	_veil(0.57)

	var wing := sin(world.bird_anim * 0.9)
	var float_y := 360.0 + sin(t * 1.6) * 12.0
	Art.craft(self, Vector2(Cfg.LOGICAL_W * 0.5, float_y),
			deg_to_rad(sin(t * 1.6) * 8.0), 1.5,
			world.skin["a"], world.skin["b"], wing)

	Art.title(self, "NEONFLAP", Vector2(Cfg.LOGICAL_W * 0.5, 190), 84, Cfg.CYAN)
	Art.text_at(self, "S Y N T H W A V E   F L A P",
			Vector2(Cfg.LOGICAL_W * 0.5, 244), 22, Cfg.hdr(Cfg.MAGENTA, 1.3))

	Art.text_at(self, "RECORDE", Vector2(Cfg.LOGICAL_W * 0.5, 452), 20, Cfg.DIM)
	Art.number(self, "%02d" % save.best(), Vector2(Cfg.LOGICAL_W * 0.5, 492),
			34.0, Cfg.CYAN)

	for i in MENU_ITEMS.size():
		var y := 566.0 + float(i) * 52.0
		var label := str(MENU_ITEMS[i]["label"])
		if i == menu_index:
			var pulse := 0.55 + 0.45 * sin(t * 6.0)
			Art.text_at(self, "> " + label + " <", Vector2(Cfg.LOGICAL_W * 0.5, y),
					34, Cfg.hdr(Cfg.CYAN, 1.0 + pulse), true)
		else:
			Art.text_at(self, label, Vector2(Cfg.LOGICAL_W * 0.5, y), 29, Cfg.DIM)

	var som := "OFF" if sfx.muted else "ON"
	Art.text_at(self, "TOQUE PARA JOGAR", Vector2(Cfg.LOGICAL_W * 0.5, Cfg.LOGICAL_H - 66),
			19, Cfg.DIM)
	Art.text_at(self, "M SOM: " + som, Vector2(Cfg.LOGICAL_W * 0.5, Cfg.LOGICAL_H - 42),
			17, Cfg.DIM)


# --------------------------------------------------------------- tela jogo
func _draw_play() -> void:
	world.draw_world(self)
	world.draw_hud(self)

	if world.state == World.READY:
		var pulse := 0.45 + 0.55 * sin(t * 4.0)
		Art.text_at(self, "TOQUE PARA COMEÇAR", Vector2(Cfg.LOGICAL_W * 0.5, 300),
				33, Cfg.hdr(Cfg.WHITE, 0.8 + pulse), true)
		Art.text_at(self, "FASE  " + bg.phase_name(),
				Vector2(Cfg.LOGICAL_W * 0.5, Cfg.floor_y() - 60), 21,
				Cfg.hdr(bg.pipe_color(), 1.2))

	if paused:
		_veil(0.75)
		Art.text_at(self, "PAUSA", Vector2(Cfg.LOGICAL_W * 0.5, 380), 66,
				Cfg.CYAN, true)
		Art.text_at(self, "TOQUE PARA CONTINUAR", Vector2(Cfg.LOGICAL_W * 0.5, 440),
				21, Cfg.DIM)


# ------------------------------------------------------------ tela fim jogo
func _draw_gameover() -> void:
	world.draw_world(self)
	_veil(0.68)

	var r := Rect2(Cfg.LOGICAL_W * 0.5 - 186, 210, 372, 380)
	Art.panel(self, r, Cfg.MAGENTA)

	Art.text_at(self, "FIM DE JOGO", Vector2(r.position.x + r.size.x * 0.5, r.position.y + 46),
			40, Cfg.MAGENTA, true)
	Art.number(self, "%02d" % last_score,
			Vector2(r.position.x + r.size.x * 0.5, r.position.y + 132), 76.0, Cfg.WHITE)
	Art.text_at(self, "PONTOS", Vector2(r.position.x + r.size.x * 0.5, r.position.y + 190),
			19, Cfg.DIM)

	if last_record:
		var pulse := 0.45 + 0.55 * sin(t * 7.0)
		Art.text_at(self, "NOVO RECORDE!",
				Vector2(r.position.x + r.size.x * 0.5, r.position.y + 226), 30,
				Cfg.hdr(Cfg.AMBER, 0.8 + pulse), true)
	else:
		Art.text_at(self, "RECORDE  %d" % last_best,
				Vector2(r.position.x + r.size.x * 0.5, r.position.y + 226), 26, Cfg.WHITE)

	Art.text_at(self, "TEMPO %0.1fs   ·   FASE %s" % [last_seconds, bg.phase_name()],
			Vector2(r.position.x + r.size.x * 0.5, r.position.y + 268), 19, Cfg.DIM)

	if last_unlock != "":
		Art.text_at(self, "SKIN LIBERADA: " + last_unlock,
				Vector2(r.position.x + r.size.x * 0.5, r.position.y + 302), 23,
				Cfg.hdr(Cfg.LIME, 1.2), true)

	var p2 := 0.4 + 0.6 * sin(t * 5.0)
	Art.text_at(self, "TOQUE PARA JOGAR DE NOVO",
			Vector2(r.position.x + r.size.x * 0.5, r.position.y + r.size.y - 42), 25,
			Cfg.hdr(Cfg.CYAN, 0.7 + p2), true)

	Art.panel(self, _back_rect(), Cfg.DIM, 0.55)
	Art.text_at(self, "MENU", _back_rect().get_center(), 24, Cfg.WHITE)


# -------------------------------------------------------------- tela skins
func _draw_skins() -> void:
	bg.draw_sky(self)
	bg.draw_ground(self)
	_veil(0.65)

	Art.title(self, "SKINS", Vector2(Cfg.LOGICAL_W * 0.5, 88), 56, Cfg.CYAN)

	var best := save.best()
	var selected := str(save.get_value("selected_skin"))

	for i in Cfg.SKINS.size():
		var s: Dictionary = Cfg.SKINS[i]
		var rect := _skin_card_rect(i)
		var req := int(s["req"])
		var unlocked := best >= req
		var primary: Color = s["a"]

		Art.panel(self, rect, primary if unlocked else Cfg.DIM, 0.84 if unlocked else 0.6)
		if i == skin_index:
			Art.neon_rect(self, rect.grow(5.0), Cfg.WHITE, 2.0)

		var craft_pos := Vector2(rect.position.x + rect.size.x * 0.5, rect.position.y + 56)
		if unlocked:
			Art.craft(self, craft_pos, 0.0, 1.15, primary, s["b"], 0.6)
		else:
			Art.craft(self, craft_pos, 0.0, 1.15, Cfg.DIM, Cfg.DIM, 0.6)

		var cx := rect.position.x + rect.size.x * 0.5
		Art.text_at(self, str(s["name"]), Vector2(cx, rect.position.y + rect.size.y - 48),
				25, primary if unlocked else Cfg.DIM, unlocked)
		if not unlocked:
			Art.text_at(self, "RECORDE %d" % req,
					Vector2(cx, rect.position.y + rect.size.y - 22), 19, Cfg.DIM)
		elif str(s["id"]) == selected:
			Art.text_at(self, "EM USO", Vector2(cx, rect.position.y + rect.size.y - 22),
					19, Cfg.hdr(Cfg.LIME, 1.2))
		else:
			Art.text_at(self, "LIBERADA", Vector2(cx, rect.position.y + rect.size.y - 22),
					19, Cfg.DIM)

	var nxt := save.next_unlock()
	if not nxt.is_empty():
		Art.text_at(self, "PRÓXIMA: %s AOS %d PONTOS" % [str(nxt["name"]), int(nxt["req"])],
				Vector2(Cfg.LOGICAL_W * 0.5, Cfg.LOGICAL_H - 118), 20, Cfg.AMBER)

	Art.panel(self, _back_rect(), Cfg.DIM, 0.55)
	Art.text_at(self, "VOLTAR", _back_rect().get_center(), 24, Cfg.WHITE)


# --------------------------------------------------------- tela estatisticas
func _draw_stats() -> void:
	bg.draw_sky(self)
	bg.draw_ground(self)
	_veil(0.70)

	Art.title(self, "ESTATÍSTICAS", Vector2(Cfg.LOGICAL_W * 0.5, 86), 44, Cfg.CYAN, 3.0)

	var rows := [
		["RECORDE", "%d" % save.best()],
		["PARTIDAS", "%d" % int(save.get_value("total_runs"))],
		["MÉDIA", "%0.1f" % save.average()],
		["PONTOS TOTAIS", "%d" % int(save.get_value("total_score"))],
		["MELHOR TEMPO", "%0.1fs" % float(save.get_value("best_run_seconds"))],
		["TEMPO TOTAL", "%0.1f min" % (float(save.get_value("total_seconds")) / 60.0)],
		["PULOS", "%d" % int(save.get_value("total_flaps"))],
		["ITENS PEGOS", "%d" % int(save.get_value("powerups_collected"))],
	]

	var panel_rect := Rect2(Cfg.LOGICAL_W * 0.5 - 190, 140, 380, 306)
	Art.panel(self, panel_rect, Cfg.PURPLE)

	var y := panel_rect.position.y + 26.0
	for row in rows:
		Art.text_left(self, str(row[0]), Vector2(panel_rect.position.x + 26, y), 22, Cfg.DIM)
		Art.text_right(self, str(row[1]),
				Vector2(panel_rect.position.x + panel_rect.size.x - 26, y), 23, Cfg.WHITE)
		y += 35.0

	var chart := Rect2(Cfg.LOGICAL_W * 0.5 - 190, panel_rect.position.y + panel_rect.size.y + 22,
			380, 170)
	Art.panel(self, chart, Cfg.CYAN)
	Art.text_left(self, "ÚLTIMAS PARTIDAS", Vector2(chart.position.x + 22, chart.position.y + 14),
			20, Cfg.DIM)

	var recent: Array = []
	if typeof(save.get_value("recent")) == TYPE_ARRAY:
		recent = save.get_value("recent")

	if recent.is_empty():
		Art.text_at(self, "NENHUMA PARTIDA AINDA", chart.get_center(), 22, Cfg.DIM)
	else:
		var top := 1
		for v in recent:
			top = maxi(top, int(v))
		var step := (chart.size.x - 44.0) / 10.0
		var base_y := chart.position.y + chart.size.y - 26.0
		for i in recent.size():
			var value := int(recent[recent.size() - 1 - i])
			var h := (float(value) / float(top)) * 92.0
			var bar := Rect2(chart.position.x + 22 + float(i) * step, base_y - h, 24.0,
					maxf(3.0, h))
			draw_rect(bar, Cfg.with_alpha(Cfg.CYAN, 0.28), true)
			Art.neon_rect(self, bar, Cfg.CYAN, 2.0)
			Art.text_at(self, str(value), Vector2(bar.position.x + 12, base_y + 12), 18,
					Cfg.DIM)

	Art.panel(self, _back_rect(), Cfg.DIM, 0.55)
	Art.text_at(self, "VOLTAR", _back_rect().get_center(), 24, Cfg.WHITE)
