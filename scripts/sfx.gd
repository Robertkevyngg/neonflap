class_name Sfx
extends Node

## Efeitos e trilha. Os .ogg foram gerados pelo sintetizador da versao PC
## (tools/bake_audio.py), entao o som e exatamente o mesmo — mas aqui ja
## vem pronto, sem custo de inicializacao no celular.

const DIR := "res://assets/audio/"
const NAMES := ["flap", "score", "hit", "powerup", "shield", "ui"]

const SFX_DB := -7.0
const MUSIC_DB := -15.0

var _players := {}
var _music: AudioStreamPlayer
var muted := false
var music_on := true


func _ready() -> void:
	for n in NAMES:
		var p := AudioStreamPlayer.new()
		p.stream = load(DIR + str(n) + ".ogg")
		p.volume_db = SFX_DB
		p.bus = "Master"
		add_child(p)
		_players[str(n)] = p

	_music = AudioStreamPlayer.new()
	var stream: AudioStream = load(DIR + "music.ogg")
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_music.stream = stream
	_music.volume_db = MUSIC_DB
	_music.bus = "Master"
	add_child(_music)


func play(key: String, volume_scale: float = 1.0) -> void:
	if muted:
		return
	if not _players.has(key):
		return
	var p: AudioStreamPlayer = _players[key]
	p.volume_db = SFX_DB + linear_to_db(clampf(volume_scale, 0.05, 1.0))
	p.play()


func start_music() -> void:
	if muted or not music_on or _music == null:
		return
	if not _music.playing:
		_music.play()


func stop_music() -> void:
	if _music != null:
		_music.stop()


func duck_music(factor: float) -> void:
	if _music != null:
		_music.volume_db = MUSIC_DB + linear_to_db(clampf(factor, 0.05, 1.0))


func toggle_mute() -> bool:
	muted = not muted
	if muted:
		stop_music()
	else:
		start_music()
	return muted


func toggle_music() -> bool:
	music_on = not music_on
	if music_on:
		start_music()
	else:
		stop_music()
	return music_on
