extends Node
## Music loop and interface sounds.

var _music: AudioStreamPlayer
var _click: AudioStreamPlayer
var _bell: AudioStreamPlayer


func _ready() -> void:
	var drone: AudioStreamOggVorbis = load("res://assets/audio/menu_drone.ogg")
	drone.loop = true
	_music = _make_player(drone, "Music")
	_click = _make_player(load("res://assets/audio/ui_click.ogg"), "SFX")
	_bell = _make_player(load("res://assets/audio/bell.ogg"), "SFX")
	_music.play.call_deferred()


func click() -> void:
	_click.play()


func bell() -> void:
	_bell.play()


func _make_player(stream: AudioStream, bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = bus
	add_child(player)
	return player
