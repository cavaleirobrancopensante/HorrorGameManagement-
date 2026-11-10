extends Node
## Music, ambience and short sounds. Music cross-fades between two players; the
## ambience (the trailer's hum) runs underneath on its own player.

signal music_finished

## Pieces composed by tools/music/compose.py; see docs/music.md.
const MUSIC := {
	"menu": "res://assets/music/menu.ogg",
	"night_shift": "res://assets/music/night_shift.ogg",
	"overcast": "res://assets/music/overcast.ogg",
	"outside": "res://assets/music/outside.ogg",
	"sunday": "res://assets/music/sunday.ogg",
	"requiem": "res://assets/music/requiem.ogg",
}
const TITLES := {
	"menu": "Give Us This Day", "night_shift": "Night Shift", "overcast": "Overcast",
	"outside": "Something Outside", "sunday": "Sunday", "requiem": "Requiem",
}
const AMBIENCE := {"hum": "res://assets/audio/room_hum.ogg"}
const EFFECTS := ["click", "bell", "step", "door", "beep", "drone", "buzz", "water", "can", "till", "tempt"]
const FILES := {"click": "ui_click"}
const POOL_SIZE := 6
const MUSIC_DB := -4.0
const AMBIENCE_DB := -14.0
const FADE := 2.5

var current_music := ""
var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var _current_ambience := ""
var _effects := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _tweens := {}


func _ready() -> void:
	_a = _music_player()
	_b = _music_player()
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "SFX"
	_stream_on_web(_ambience)
	add_child(_ambience)
	for id: String in EFFECTS:
		_effects[id] = load("res://assets/audio/%s.ogg" % FILES.get(id, id))
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)


## On the web, long files stream through the engine instead of being decoded
## whole into browser memory, which phones run out of.
func _stream_on_web(player: AudioStreamPlayer) -> void:
	if OS.has_feature("web"):
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM


func _music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = "Music"
	player.volume_db = -80.0
	_stream_on_web(player)
	player.finished.connect(_on_finished.bind(player))
	add_child(player)
	return player


## Cross-fades to a piece. Looping pieces repeat; the others end and emit music_finished.
func play_music(id: String, loop := false) -> void:
	if id == current_music and _a.playing:
		return
	current_music = id
	var stream: AudioStreamOggVorbis = (load(MUSIC[id]) as AudioStreamOggVorbis).duplicate()
	stream.loop = loop
	var old := _a
	_a = _b
	_b = old
	_a.stream = stream
	_a.volume_db = -40.0
	_a.play()
	_fade(_a, MUSIC_DB)
	_fade(_b, -80.0, true)


## Fades the music out, leaving only the ambience.
func stop_music() -> void:
	current_music = ""
	_fade(_a, -80.0, true)
	_fade(_b, -80.0, true)


func is_music_playing() -> bool:
	return current_music != "" and _a.playing


func _fade(player: AudioStreamPlayer, to_db: float, stop_after := false) -> void:
	if _tweens.has(player) and (_tweens[player] as Tween).is_valid():
		(_tweens[player] as Tween).kill()
	var tween := create_tween()
	_tweens[player] = tween
	tween.tween_property(player, "volume_db", to_db, FADE).set_trans(Tween.TRANS_SINE)
	if stop_after:
		tween.tween_callback(func() -> void:
			if player != _a or current_music == "":
				player.stop()
		)


func _on_finished(player: AudioStreamPlayer) -> void:
	if player == _a and current_music != "":
		current_music = ""
		music_finished.emit()


func play_ambience(id: String) -> void:
	if id == _current_ambience and _ambience.playing:
		return
	_current_ambience = id
	var stream: AudioStreamOggVorbis = (load(AMBIENCE[id]) as AudioStreamOggVorbis).duplicate()
	stream.loop = true
	_ambience.stream = stream
	_ambience.volume_db = AMBIENCE_DB
	_ambience.play()


func stop_ambience() -> void:
	_current_ambience = ""
	_ambience.stop()


func play(id: String, pitch_jitter := 0.0, volume_db := 0.0) -> void:
	var player := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	player.stream = _effects[id]
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	player.volume_db = volume_db
	player.play()


func click() -> void:
	play("click")


func bell() -> void:
	play("bell")
