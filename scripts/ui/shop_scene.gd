extends Control
## Händler & Alchemist: einfache Tränke kaufen (Gold), alle Tränke aus
## Materialien craften. Ein Kur-Trank pro Statuseffekt; das Allheilmittel
## wird aus allen fünf Kur-Tränken zusammen gebraut.

const MAIN_SCENE := "res://scenes/main.tscn"

var _gold_label: Label
var _materials_label: Label
var _buy_list: VBoxContainer
var _craft_list: VBoxContainer


func _ready() -> void:
	_build_layout()
	_refresh()


func _on_buy(def: ConsumableDef) -> void:
	if GameState.buy(def):
		_refresh()


func _on_craft(def: ConsumableDef) -> void:
	if GameState.craft(def):
		_refresh()


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1a1a2e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for margin in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		root.add_theme_constant_override(margin, 16)
	add_child(root)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	root.add_child(main)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	main.add_child(head)
	var title := Label.new()
	title.text = "Händler & Alchemist"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_gold_label = Label.new()
	head.add_child(_gold_label)
	var back := Button.new()
	back.text = "Zurück zum Menü"
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(MAIN_SCENE))
	head.add_child(back)

	_materials_label = Label.new()
	_materials_label.modulate = Color(1, 1, 1, 0.7)
	main.add_child(_materials_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	main.add_child(body)

	var buy_scroll := ScrollContainer.new()
	buy_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(buy_scroll)
	var buy_box := VBoxContainer.new()
	buy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buy_scroll.add_child(buy_box)
	var buy_header := Label.new()
	buy_header.text = "Kaufen"
	buy_header.add_theme_font_size_override("font_size", 18)
	buy_box.add_child(buy_header)
	_buy_list = VBoxContainer.new()
	_buy_list.add_theme_constant_override("separation", 4)
	buy_box.add_child(_buy_list)

	var craft_scroll := ScrollContainer.new()
	craft_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	craft_scroll.size_flags_stretch_ratio = 1.5
	body.add_child(craft_scroll)
	var craft_box := VBoxContainer.new()
	craft_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_scroll.add_child(craft_box)
	var craft_header := Label.new()
	craft_header.text = "Alchemie (Craften)"
	craft_header.add_theme_font_size_override("font_size", 18)
	craft_box.add_child(craft_header)
	_craft_list = VBoxContainer.new()
	_craft_list.add_theme_constant_override("separation", 4)
	craft_box.add_child(_craft_list)


func _refresh() -> void:
	_gold_label.text = "Gold: %d   " % GameState.gold

	var material_parts: Array[String] = []
	for id in MaterialLibrary.MATERIALS:
		material_parts.append("%s ×%d" % [MaterialLibrary.display_name(id),
			GameState.material_count(id)])
	_materials_label.text = "Materialien:  " + "   ".join(material_parts)

	for child in _buy_list.get_children():
		child.queue_free()
	for def in ConsumableLibrary.buyable_defs():
		_buy_list.add_child(_make_buy_row(def))

	for child in _craft_list.get_children():
		child.queue_free()
	for def in ConsumableLibrary.craftable_defs():
		_craft_list.add_child(_make_craft_row(def))


func _make_buy_row(def: ConsumableDef) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var info := Label.new()
	info.text = "%s (×%d)" % [def.display_name, GameState.consumable_count(def.id)]
	info.tooltip_text = def.description
	info.mouse_filter = Control.MOUSE_FILTER_PASS
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var buy := Button.new()
	buy.text = "Kaufen (%d G)" % def.price
	buy.disabled = GameState.gold < def.price
	buy.pressed.connect(_on_buy.bind(def))
	row.add_child(buy)
	return panel


func _make_craft_row(def: ConsumableDef) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = "%s (×%d)" % [def.display_name, GameState.consumable_count(def.id)]
	name_label.tooltip_text = def.description
	name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	info.add_child(name_label)
	var recipe_label := Label.new()
	recipe_label.text = "Rezept: " + _recipe_text(def)
	recipe_label.add_theme_font_size_override("font_size", 11)
	recipe_label.modulate = Color(1, 1, 1, 0.6)
	info.add_child(recipe_label)

	var craft := Button.new()
	craft.text = "Craften"
	craft.disabled = not GameState.can_craft(def)
	craft.pressed.connect(_on_craft.bind(def))
	row.add_child(craft)
	return panel


static func _recipe_text(def: ConsumableDef) -> String:
	var parts: Array[String] = []
	for id in def.craft_materials:
		parts.append("%d× %s" % [def.craft_materials[id], MaterialLibrary.display_name(id)])
	for id in def.craft_consumables:
		parts.append("%d× %s" % [def.craft_consumables[id],
			ConsumableLibrary.get_def(id).display_name])
	return " + ".join(parts)
