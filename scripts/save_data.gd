class_name SaveData
extends RefCounted

## Recordes, estatisticas e opcoes em user://save.json.
## No Android isso cai no diretorio privado do app, entao sobrevive a
## reinstalacoes por cima e nao pede permissao nenhuma.

const PATH := "user://save.json"

const DEFAULTS := {
	"version": 1,
	"best_score": 0,
	"best_run_seconds": 0.0,
	"total_runs": 0,
	"total_score": 0,
	"total_flaps": 0,
	"total_seconds": 0.0,
	"powerups_collected": 0,
	"recent": [],
	"selected_skin": "drifter",
	"muted": false,
	"music_on": true,
}

var data := {}


func _init() -> void:
	data = DEFAULTS.duplicate(true)
	load_file()


func load_file() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()

	var parsed: Variant = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		# Save corrompido: recomeca do zero em vez de quebrar o jogo.
		data = DEFAULTS.duplicate(true)
		return
	for key in DEFAULTS.keys():
		if parsed.has(key):
			data[key] = parsed[key]


func save_file() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()


# ------------------------------------------------------------------ acesso
func get_value(key: String) -> Variant:
	return data.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	data[key] = value


func best() -> int:
	return int(data.get("best_score", 0))


func average() -> float:
	var runs := int(data.get("total_runs", 0))
	if runs == 0:
		return 0.0
	return float(data.get("total_score", 0)) / float(runs)


# ------------------------------------------------------------------ partidas
## Registra a partida e devolve true se bateu o recorde.
func record_run(score: int, seconds: float, flaps: int, powerups: int) -> bool:
	data["total_runs"] = int(data.get("total_runs", 0)) + 1
	data["total_score"] = int(data.get("total_score", 0)) + score
	data["total_flaps"] = int(data.get("total_flaps", 0)) + flaps
	data["total_seconds"] = float(data.get("total_seconds", 0.0)) + seconds
	data["powerups_collected"] = int(data.get("powerups_collected", 0)) + powerups

	var recent: Array = []
	if typeof(data.get("recent")) == TYPE_ARRAY:
		recent = (data["recent"] as Array).duplicate()
	recent.insert(0, score)
	while recent.size() > 10:
		recent.remove_at(recent.size() - 1)
	data["recent"] = recent

	if seconds > float(data.get("best_run_seconds", 0.0)):
		data["best_run_seconds"] = snappedf(seconds, 0.01)

	var is_record := score > best()
	if is_record:
		data["best_score"] = score

	save_file()
	return is_record


# ------------------------------------------------------------------ skins
func is_unlocked(sid: String) -> bool:
	var skin := Cfg.skin_by_id(sid)
	return best() >= int(skin["req"])


## Proxima skin a liberar, ou dicionario vazio se ja liberou todas.
func next_unlock() -> Dictionary:
	var b := best()
	for s in Cfg.SKINS:
		if b < int(s["req"]):
			return s
	return {}


## Skins liberadas exatamente nesta partida (prev_best -> best).
func unlocked_between(prev_best: int, new_best: int) -> String:
	var found := ""
	for s in Cfg.SKINS:
		var req := int(s["req"])
		if req > 0 and prev_best < req and req <= new_best:
			found = str(s["name"])
	return found
