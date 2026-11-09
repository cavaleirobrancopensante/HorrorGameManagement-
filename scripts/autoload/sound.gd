extends Node
## Music loops and short sounds.

const MUSIC := {
	"menu": "res://assets/audio/menu_drone.ogg",
	"hum": "res://assets/audio/room_hum.ogg",
}
const EFFECTS := ["click", "bell", "step", "door", "beep", "drone", "buzz", "water", "can"]
const FILES := {"click": "ui_click"}
const POOL_SIZE := 6

var _music: AudioStreamPlayer
var _current_music := ""
var _effects := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	for id: String in EFFECTS:
		_effects[id] = load("res://assets/audio/%s.ogg" % FILES.get(id, id))
	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_pool.append(player)


func play_music(id: String) -> void:
	if id == _current_music:
		return
	_current_music = id
	var stream: AudioStreamOggVorbis = load(MUSIC[id])
	stream.loop = true
	_music.stream = stream
	_music.volume_db = -6.0 if id == "hum" else 0.0
	_music.play()


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
