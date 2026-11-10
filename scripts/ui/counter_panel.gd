class_name CounterPanel
extends Control
## The serving counter: orders along the top, grill, tray and stock along the
## bottom, and the 3D view of the hatch in between.

var game: TrailerGame
var stand: Stand
var _cards: Array = []
var _slot_buttons: Array[Button] = []
var _tray_label: Label
var _stock_buttons := {}


static func open(owner_game: TrailerGame) -> CounterPanel:
	var panel := CounterPanel.new()
	panel.game = owner_game
	panel.stand = owner_game.stand
	panel.add_to_group("modal")
	owner_game.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel._build()
	return panel


func go_back() -> void:
	remove_from_group("modal")
	queue_free()
	game.on_counter_closed()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiKit.apply_safe_area(margin, 12)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	# Orders, under the HUD and above the hatch.
	var top_gap := Control.new()
	top_gap.custom_minimum_size.y = 152
	top_gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top_gap)
	var orders := HBoxContainer.new()
	orders.alignment = BoxContainer.ALIGNMENT_CENTER
	orders.add_theme_constant_override("separation", 14)
	orders.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(orders)
	for i in Stand.SPOTS.size():
		var card := _order_card(i)
		orders.add_child(card["root"])
		_cards.append(card)

	var middle := Control.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(middle)

	# Grill, tray and stock.
	var bench := PanelContainer.new()
	column.add_child(bench)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 8)
	bench.add_child(rows)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	rows.add_child(line)
	line.add_child(UiKit.label("Grill", UiKit.SIZE_SMALL, UiKit.ASH))
	for i in StandRules.GRILL_SLOTS:
		var slot := UiKit.button("", stand.use_slot.bind(i), 150)
		_slot_buttons.append(slot)
		line.add_child(slot)
	var tray_box := PanelContainer.new()
	tray_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tray_box.add_theme_stylebox_override("panel", UiKit.flat_box(Color("#3a2f2a"), Color("#6d5a48"), 2, 12))
	line.add_child(tray_box)
	_tray_label = UiKit.label("", UiKit.SIZE_SMALL, UiKit.TALLOW)
	_tray_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tray_box.add_child(_tray_label)
	line.add_child(UiKit.button("Bin tray", stand.bin_tray, 120))

	var stock := HBoxContainer.new()
	stock.add_theme_constant_override("separation", 8)
	rows.add_child(stock)
	stock.add_child(UiKit.button("Leave", go_back, 110))
	for item: Array in [["sausages", "Sausage", stand.add_sausage], ["buns", "Bun", stand.add_bun], ["", "Ketchup", stand.add_sauce.bind("ketchup")], ["", "Mustard", stand.add_sauce.bind("mustard")], ["soda", "Can", stand.add_can]]:
		var button := UiKit.button(item[1], item[2])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stock.add_child(button)
		if not str(item[0]).is_empty():
			_stock_buttons[item[0]] = [button, item[1]]
		# Sauces in their own colours, so they are found at a glance.
		if item[1] == "Ketchup":
			UiKit.paint(button, Color("#7c2024"), Color("#b3262c"))
		elif item[1] == "Mustard":
			UiKit.paint(button, Color("#7a5c14"), Color("#d1a22a"))
	_refresh()


func _order_card(index: int) -> Dictionary:
	var root := PanelContainer.new()
	root.custom_minimum_size = Vector2(290, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	root.add_child(column)
	var text := UiKit.label("", UiKit.SIZE_SMALL, UiKit.TALLOW)
	text.custom_minimum_size.y = 56
	column.add_child(text)
	var bar_back := ColorRect.new()
	bar_back.color = UiKit.VESTMENT_LIGHT
	bar_back.custom_minimum_size.y = 8
	column.add_child(bar_back)
	var bar := ColorRect.new()
	bar.color = UiKit.LITURGICAL_GOLD
	bar_back.add_child(bar)
	var serve := UiKit.button("Serve", stand.serve.bind(index))
	column.add_child(serve)
	return {"root": root, "text": text, "bar_back": bar_back, "bar": bar, "serve": serve}


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	for i in _cards.size():
		var card: Dictionary = _cards[i]
		var customer: Customer = stand.spots[i]
		var waiting := customer != null and is_instance_valid(customer) and customer.at_hatch
		(card["root"] as Control).modulate.a = 1.0 if waiting else 0.35
		(card["serve"] as Button).disabled = not waiting
		if waiting:
			(card["text"] as Label).text = StandRules.order_text(customer.order)
			var left := customer.patience_left()
			var bar: ColorRect = card["bar"]
			bar.size = Vector2((card["bar_back"] as Control).size.x * left, 8)
			bar.color = UiKit.LITURGICAL_GOLD if left > 0.5 else (UiKit.SODIUM if left > 0.25 else Color("#ff4a55"))
		else:
			(card["text"] as Label).text = "On the way" if customer != null and is_instance_valid(customer) else "No one"
			(card["bar"] as ColorRect).size = Vector2.ZERO
	for i in _slot_buttons.size():
		var button := _slot_buttons[i]
		match stand.slot_state(i):
			"empty":
				button.text = "Empty"
				UiKit.paint(button, UiKit.COMPLINE, UiKit.VESTMENT_LIGHT)
			"raw":
				button.text = "Cooking %d%%" % roundi(stand.cook_progress(i) * 100.0)
				UiKit.paint(button, Color("#7a3a33"), Color("#a65a4a"))
			"ready":
				button.text = "Ready"
				UiKit.paint(button, Color("#8a5a24"), UiKit.SODIUM, 4)
			"burnt":
				button.text = "Burnt"
				UiKit.paint(button, Color("#141114"), Color("#4a3a3a"))
	_tray_label.text = StandRules.tray_text(stand.tray)
	for id: String in _stock_buttons:
		var entry: Array = _stock_buttons[id]
		(entry[0] as Button).text = "%s (%d)" % [entry[1], Survival.stock(game.save, id)]
