class_name Cfg
extends RefCounted

## Todos os numeros do jogo. Os valores sao identicos aos da versao PC
## (neonflap/config.py), entao o "feel" e exatamente o mesmo.

# ------------------------------------------------------------------ tela
const GAME_TITLE := "NEONFLAP"
const GAME_VERSION := "1.0.0"

const LOGICAL_W := 480.0
const LOGICAL_H := 854.0

# ------------------------------------------------------------------ fisica
const GRAVITY := 2300.0
const FLAP_IMPULSE := -640.0
const MAX_FALL_SPEED := 980.0
const BIRD_X := 140.0
const BIRD_RADIUS := 15.0
const TILT_UP := -28.0
const TILT_DOWN := 78.0
const TILT_SPEED := 380.0

# ------------------------------------------------------------------ canos
const PIPE_W := 78.0
const PIPE_CAP_H := 26.0
const PIPE_SPACING_START := 260.0
const PIPE_SPACING_MIN := 205.0
const GAP_START := 208.0
const GAP_MIN := 138.0
const SPEED_START := 205.0
const SPEED_MAX := 380.0
const GROUND_H := 96.0
const CEILING_MARGIN := 70.0
const GAP_MARGIN := 60.0

const RAMP_EVERY := 5
const RAMP_STEPS := 14

# ------------------------------------------------------------------ itens
const POWERUP_MIN_SCORE := 6
const POWERUP_CHANCE := 0.17
const POWERUP_RADIUS := 15.0
const SLOWMO_DURATION := 4.5
const SLOWMO_FACTOR := 0.55
const MAGNET_DURATION := 6.0
const MAGNET_RANGE := 190.0

# ------------------------------------------------------------------ cores
const BG_TOP := Color(0.031, 0.016, 0.094)
const BG_BOTTOM := Color(0.118, 0.039, 0.188)
const CYAN := Color(0.0, 0.941, 1.0)
const MAGENTA := Color(1.0, 0.176, 0.627)
const PURPLE := Color(0.588, 0.275, 1.0)
const LIME := Color(0.549, 1.0, 0.353)
const AMBER := Color(1.0, 0.745, 0.235)
const WHITE := Color(0.922, 0.961, 1.0)
const DIM := Color(0.471, 0.510, 0.647)
const DANGER := Color(1.0, 0.275, 0.353)
const INK := Color(0.031, 0.020, 0.086)

## Multiplicador aplicado as cores "acesas". Acima de 1.0 o pixel passa
## do limiar de HDR e o bloom do Godot transforma em brilho neon.
const NEON := 2.4
const NEON_SOFT := 1.5

const PHASE_EVERY := 12

## Cada fase: nome, cor do horizonte/sol, cor dos canos, cor do grid.
const PHASES := [
	{"name": "MIDNIGHT", "sun": Color(0.227, 0.071, 0.361), "pipe": CYAN, "grid": Color(0.353, 0.157, 0.588)},
	{"name": "SUNSET", "sun": Color(0.471, 0.094, 0.306), "pipe": MAGENTA, "grid": Color(0.667, 0.157, 0.431)},
	{"name": "TOXIC", "sun": Color(0.071, 0.306, 0.235), "pipe": LIME, "grid": Color(0.157, 0.588, 0.431)},
	{"name": "SOLAR", "sun": Color(0.431, 0.243, 0.047), "pipe": AMBER, "grid": Color(0.667, 0.431, 0.118)},
	{"name": "VOID", "sun": Color(0.157, 0.047, 0.275), "pipe": PURPLE, "grid": Color(0.431, 0.235, 0.745)},
]

## Skins: id, nome, cor primaria, cor secundaria, recorde necessario.
const SKINS := [
	{"id": "drifter", "name": "DRIFTER", "a": CYAN, "b": Color(1, 1, 1), "req": 0},
	{"id": "ember", "name": "EMBER", "a": MAGENTA, "b": Color(1.0, 0.824, 0.471), "req": 10},
	{"id": "viper", "name": "VIPER", "a": LIME, "b": Color(0.0, 1.0, 0.784), "req": 25},
	{"id": "solar", "name": "SOLAR", "a": AMBER, "b": Color(1.0, 0.353, 0.157), "req": 45},
	{"id": "wraith", "name": "WRAITH", "a": PURPLE, "b": Color(1.0, 0.471, 1.0), "req": 70},
	{"id": "ghost", "name": "GHOST", "a": Color(0.941, 0.980, 1.0), "b": Color(0.471, 0.784, 1.0), "req": 100},
]


## Aplica ganho HDR mantendo o alpha.
static func hdr(c: Color, k: float = NEON) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


static func skin_by_id(sid: String) -> Dictionary:
	for s in SKINS:
		if s["id"] == sid:
			return s
	return SKINS[0]


static func floor_y() -> float:
	return LOGICAL_H - GROUND_H
