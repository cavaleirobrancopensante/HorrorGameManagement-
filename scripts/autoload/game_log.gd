extends Node
## The test log: what happened in the game, marked good or bad, with the
## computer's side of it — slow frames (lag, and the stutter it causes in the
## music), lighting changes and engine errors — so a play session can be read
## back afterwards. Open it with F3 or from the pause menu. Each session is
## also written to user://logs/, and the last few are kept.

## Kinds of entry, with the colour each is shown in.
const KINDS := {
	"good": "#8fd18a",
	"bad": "#ef7a7a",
	"info": "#d8cfbf",
	"perf": "#f0c060",
	"light": "#9fb8f0",
	"error": "#e070e0",
}
## A frame this slow (seconds) is a hitch you can feel; past SEVERE, the music
## stutters too, on the web where sound is mixed between frames.
const HITCH := 0.06
const SEVERE := 0.12
## How often a summary of the frame rate is written.
const SUMMARY_EVERY := 30.0
const KEEP_FILES := 5
const MAX_ENTRIES := 2000

signal added(entry: Dictionary)

var entries: Array[Dictionary] = []
## The in-game clock, set by the game while it runs.
var clock := ""
## Shows the frame rate in a corner of the screen.
var show_fps := false

var _start_usec := 0
var _last_frame_usec := 0
var _marks: Array = []
var _file: FileAccess
var _flush_wait := 0.0
var _summary_wait := SUMMARY_EVERY
var _frames := 0
var _frame_time_sum := 0.0
var _worst_frame := 0.0
var _hitches := 0
var _severe := 0
var _loaded_frames := 0
## The usual frame time lately, in seconds.
var _typical := 1.0 / 60.0
var _pending: Array = []
var _mutex := Mutex.new()
var _fps_label: Label
var _catcher: _Catcher


## Hears every engine error and warning, from any thread.
class _Catcher extends Logger:
	var owner_log: Node

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		var what := rationale if not rationale.is_empty() else code
		var kind := "warning" if error_type == Logger.ERROR_TYPE_WARNING else "error"
		owner_log.call_deferred("_queue_engine", "%s: %s (%s:%d %s)" % [kind.capitalize(), what, file.get_file(), line, function])

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start_usec = Time.get_ticks_usec()
	_last_frame_usec = _start_usec
	_open_file()
	_catcher = _Catcher.new()
	_catcher.owner_log = self
	OS.add_logger(_catcher)
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_fps_label = Label.new()
	_fps_label.position = Vector2(8, 4)
	_fps_label.add_theme_color_override("font_color", Color("#f0c060"))
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 6)
	_fps_label.add_theme_font_size_override("font_size", 20)
	_fps_label.visible = false
	layer.add_child(_fps_label)
	var where := "web" if OS.has_feature("web") else OS.get_name()
	add("info", "Session started: version %s on %s, %s, screen %s." % [
		ProjectSettings.get_setting("application/config/version", "?"), where,
		RenderingServer.get_video_adapter_name(), str(DisplayServer.window_get_size())])


func _exit_tree() -> void:
	if _catcher != null:
		OS.remove_logger(_catcher)
	_flush()


# Writing to the log ------------------------------------------------------------

## Adds an entry. kind is one of KINDS. The same text twice within a second
## (an event and the toast that reports it) is written once.
func add(kind: String, text: String) -> void:
	if text.strip_edges().is_empty():
		return
	var now := _seconds()
	for i in range(entries.size() - 1, maxi(entries.size() - 6, -1), -1):
		if entries[i]["text"] == text and now - float(entries[i]["at"]) < 1.0:
			return
	var entry := {"at": now, "clock": clock, "kind": kind if KINDS.has(kind) else "info", "text": text}
	entries.append(entry)
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()
	if _file != null:
		_file.store_line(line_for(entry))
	added.emit(entry)


func good(text: String) -> void:
	add("good", text)


func bad(text: String) -> void:
	add("bad", text)


## Notes what the game is busy doing, without showing it in the log: if the
## next frame is slow, the hitch entry names what came just before it.
func mark(what: String) -> void:
	_marks.append([_seconds(), what])
	if _marks.size() > 12:
		_marks.pop_front()


## Records a lighting change, shown under Lighting.
func light(text: String) -> void:
	add("light", text)
	mark(text)


func line_for(entry: Dictionary) -> String:
	var at := float(entry["at"])
	var stamp := "%02d:%02d" % [int(at) / 60, int(at) % 60]
	var game_time: String = entry["clock"]
	return "[%s%s] %s: %s" % [stamp, "" if game_time.is_empty() else " | " + game_time, String(entry["kind"]).to_upper(), entry["text"]]


## The whole session as text, for copying or saving.
func as_text() -> String:
	var lines := PackedStringArray()
	for entry in entries:
		lines.append(line_for(entry))
	return "\n".join(lines)


## How many entries of each kind there are.
func counts() -> Dictionary:
	var out := {}
	for kind: String in KINDS:
		out[kind] = 0
	for entry in entries:
		out[entry["kind"]] += 1
	return out


## Gives the player the log: a download on the web, the clipboard elsewhere.
## Returns a line saying where it went.
func export_log() -> String:
	var text := as_text()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), "daily_bread_log.txt", "text/plain")
		return "Downloaded as daily_bread_log.txt."
	DisplayServer.clipboard_set(text)
	_flush()
	return "Copied. Also saved in %s" % ProjectSettings.globalize_path(_path)


var _seen_errors := {}


func _queue_engine(text: String) -> void:
	# Our own messages about the log file would loop; everything else counts.
	if text.contains("game_log.gd"):
		return
	# An error repeated every frame is written the first three times, then
	# once every hundred with a count.
	var times: int = _seen_errors.get(text, 0) + 1
	_seen_errors[text] = times
	if times <= 3:
		add("error", text)
	elif times % 100 == 0:
		add("error", "%s (repeated %d times)" % [text, times])


# The frame watch ----------------------------------------------------------------

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var frame := (now - _last_frame_usec) / 1000000.0
	_last_frame_usec = now
	# The first frames after a scene loads are always slow; they are noted,
	# not counted as hitches.
	# A hitch is a frame much slower than the ones around it: a phone that is
	# simply slow all the time shows in the summaries, not as hundreds of
	# hitches.
	if _loaded_frames > 0:
		_loaded_frames -= 1
	elif frame > maxf(HITCH, _typical * 2.5):
		_hitches += 1
		var severe := frame > SEVERE
		if severe:
			_severe += 1
		add("perf", "Slow frame: %d ms%s.%s" % [roundi(frame * 1000.0), " (lag; the music may stutter)" if severe else "", _recent_marks()])
	_typical = lerpf(_typical, minf(frame, 0.25), 0.05)
	_frames += 1
	_frame_time_sum += frame
	_worst_frame = maxf(_worst_frame, frame)
	_summary_wait -= frame
	if _summary_wait <= 0.0:
		_summarise()
	_flush_wait -= frame
	if _flush_wait <= 0.0:
		_flush_wait = 2.0
		_flush()
	if show_fps:
		_fps_label.visible = true
		_fps_label.text = "%d fps  %d ms worst  %d draw calls" % [Engine.get_frames_per_second(), roundi(_worst_frame * 1000.0), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
	elif _fps_label.visible:
		_fps_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F3:
		get_viewport().set_input_as_handled()
		var scene := get_tree().current_scene
		var open := get_tree().get_nodes_in_group("modal").filter(func(n: Node) -> bool: return n is LogPanel)
		if not open.is_empty():
			open[-1].go_back()
		elif scene != null and scene.has_method("open_log"):
			scene.open_log()
		elif scene != null:
			LogPanel.open(scene)


## A new screen is loading: its first few frames are allowed to be slow.
func loading(what: String) -> void:
	_loaded_frames = 5
	mark("loading " + what)


func _summarise() -> void:
	if _frames == 0:
		return
	var average := _frames / maxf(_frame_time_sum, 0.001)
	var kind := "perf"
	var verdict := "smooth"
	if average < 25.0 or _severe > 2:
		verdict = "laggy"
		kind = "bad"
	elif average < 45.0 or _hitches > 3:
		verdict = "a little uneven"
	add(kind, "Last %ds: %s. %d fps on average, worst frame %d ms, %d slow frames (%d bad). %d draw calls, %d objects drawn, %d MB video memory." % [
		roundi(SUMMARY_EVERY), verdict, roundi(average), roundi(_worst_frame * 1000.0), _hitches, _severe,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		roundi(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0)])
	_summary_wait = SUMMARY_EVERY
	_frames = 0
	_frame_time_sum = 0.0
	_worst_frame = 0.0
	_hitches = 0
	_severe = 0


func _recent_marks() -> String:
	var now := _seconds()
	var recent := PackedStringArray()
	for item: Array in _marks:
		if now - float(item[0]) < 1.5:
			recent.append(item[1])
	_marks.clear()
	return "" if recent.is_empty() else " Just before: " + ", ".join(recent) + "."


# Files ----------------------------------------------------------------------------

var _path := ""


func _open_file() -> void:
	DirAccess.make_dir_recursive_absolute("user://logs")
	var files := Array(DirAccess.get_files_at("user://logs"))
	files.sort()
	while files.size() >= KEEP_FILES:
		DirAccess.remove_absolute("user://logs/" + str(files.pop_front()))
	_path = "user://logs/%s.log" % Time.get_datetime_string_from_system().replace(":", "-")
	_file = FileAccess.open(_path, FileAccess.WRITE)


func _flush() -> void:
	if _file != null:
		_file.flush()


func _seconds() -> float:
	return (Time.get_ticks_usec() - _start_usec) / 1000000.0
