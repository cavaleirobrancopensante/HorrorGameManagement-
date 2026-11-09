extends Node
## Player settings, stored in user://settings.cfg.

const PATH := "user://settings.cfg"
const CHANNELS := {"master": "Master", "music": "Music", "sfx": "SFX"}

var volumes := {"master": 0.8, "music": 0.7, "sfx": 0.8}


func _ready() -> void:
	for bus: String in CHANNELS.values():
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	var file := ConfigFile.new()
	if file.load(PATH) == OK:
		for channel: String in volumes:
			volumes[channel] = clampf(float(file.get_value("audio", channel, volumes[channel])), 0.0, 1.0)
	for channel: String in volumes:
		_apply(channel)


func set_volume(channel: String, value: float) -> void:
	volumes[channel] = clampf(value, 0.0, 1.0)
	_apply(channel)


func save() -> void:
	var file := ConfigFile.new()
	for channel: String in volumes:
		file.set_value("audio", channel, volumes[channel])
	file.save(PATH)


func _apply(channel: String) -> void:
	var index := AudioServer.get_bus_index(CHANNELS[channel])
	var value: float = volumes[channel]
	AudioServer.set_bus_mute(index, value <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.001)))
