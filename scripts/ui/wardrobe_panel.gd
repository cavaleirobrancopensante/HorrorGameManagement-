class_name WardrobePanel
extends Control
## The wardrobe at home: change your top, trousers, shoes and apron. You see
## yourself in 3D as you choose; Done puts the clothes on, Cancel leaves them.

## What can be changed here: clothes, not the body.
const CLOTHES := ["top", "top_colour", "legs", "feet", "apron"]

var game: TrailerGame
var _character: PlayerCharacter
var _preview: LookPreview
var _refreshers: Array = []


static func open(owner_game: TrailerGame, character: PlayerCharacter) -> WardrobePanel:
	var panel := WardrobePanel.new()
	panel.game = owner_game
	panel._character = PlayerCharacter.from_dict(character.to_dict())
	panel.add_to_group("modal")
	owner_game.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel._build()
	panel._refresh()
	return panel


func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.93)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	UiKit.apply_safe_area(margin, 24)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	margin.add_child(columns)
	_preview = LookPreview.new()
	_preview.custom_minimum_size.x = 340
	UiKit.tip(_preview, Tips.CREATION["preview"])
	columns.add_child(_preview)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)
	right.add_child(UiKit.heading("Wardrobe", 52))
	right.add_child(UiKit.wrapped_label("Change into other clothes. You will see them in the mirror and on the cameras.", UiKit.SIZE_SMALL, UiKit.ASH))
	for id: String in CLOTHES:
		right.add_child(LookPreview.chooser(_character, id, _refresh, _refreshers))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(spacer)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	bar.add_child(UiKit.tip(UiKit.button("Cancel", go_back, 200), "Close the wardrobe and keep what you are wearing."))
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(filler)
	var done := UiKit.button("Put them on", _done, 260)
	UiKit.paint(done, Color("#65421f"), UiKit.SODIUM, 3)
	bar.add_child(UiKit.tip(done, "Change into these clothes."))
	right.add_child(bar)
	right.add_child(UiKit.help_line("Point at, or touch, anything to see what it does."))


func _refresh() -> void:
	for refresher: Callable in _refreshers:
		refresher.call()
	_preview.show_recipe(People.player(_character))


func _done() -> void:
	_close()
	game.on_wardrobe_closed(_character.appearance)


## Escape, the back button and Cancel: nothing changes.
func go_back() -> void:
	_close()
	game.on_wardrobe_closed({})


func _close() -> void:
	remove_from_group("modal")
	queue_free()
