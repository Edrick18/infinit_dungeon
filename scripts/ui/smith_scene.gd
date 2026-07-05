extends Control
## Schmiede: Gear nach TYP craften (welche Basis, ist zufällig; Level streut
## um den Party-Schnitt) und Affixe vorhandener Items neu würfeln.

const MAIN_SCENE := "res://scenes/main.tscn"

var _craft_box: VBoxContainer
var _reroll_select: OptionButton
var _reroll_button: Button
var _result_label: Label
var _wallet_label: Label
var _msg_label: Label


func _ready() -> void:
	theme = UiTheme.get_theme()
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1a1a2e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 10)
	root.offset_left = 40
	root.offset_right = -40
	root.offset_top = 24
	root.offset_bottom = -24
	add_child(root)

	# Stadt-Tabs: Taverne · Händler · Schmiede sind ein Ort.
	root.add_child(UiTheme.town_tabs(&"schmiede"))

	var title := Label.new()
	title.text = Loc.pick("Schmiede", "Smithy")
	title.add_theme_font_size_override("font_size", 36)
	root.add_child(title)

	_wallet_label = Label.new()
	_wallet_label.modulate = Color(1, 1, 1, 0.7)
	root.add_child(_wallet_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	# Links: Craften nach Kategorie.
	var craft_panel := VBoxContainer.new()
	craft_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(craft_panel)
	var craft_title := Label.new()
	craft_title.text = Loc.pick(
		"Schmieden (Level zufällig um Party-Schnitt ±%d, Rarität & Affixe zufällig)",
		"Forge (level scatters around party average ±%d, rarity & affixes random)") \
		% Smith.LEVEL_DEVIATION
	craft_title.add_theme_font_size_override("font_size", 18)
	craft_panel.add_child(craft_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	craft_panel.add_child(scroll)
	_craft_box = VBoxContainer.new()
	_craft_box.add_theme_constant_override("separation", 6)
	_craft_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_craft_box)

	# Rechts: Affixe neu würfeln.
	var reroll_panel := VBoxContainer.new()
	reroll_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(reroll_panel)
	var reroll_title := Label.new()
	reroll_title.text = Loc.pick("Affixe neu würfeln (Basis & Rarität bleiben)", "Reroll affixes (base & rarity stay)")
	reroll_title.add_theme_font_size_override("font_size", 18)
	reroll_panel.add_child(reroll_title)
	_reroll_select = OptionButton.new()
	_reroll_select.custom_minimum_size = Vector2(320, 40)
	reroll_panel.add_child(_reroll_select)
	_reroll_button = Button.new()
	_reroll_button.pressed.connect(_on_reroll)
	reroll_panel.add_child(_reroll_button)
	_reroll_select.item_selected.connect(func(_index: int) -> void:
		_refresh_reroll_button())

	_result_label = Label.new()
	_result_label.add_theme_font_size_override("font_size", 18)
	root.add_child(_result_label)

	_msg_label = Label.new()
	_msg_label.modulate = Color(1.0, 0.9, 0.5)
	root.add_child(_msg_label)

	var back := Button.new()
	back.text = Loc.pick("Zurück zum Hub", "Back to hub")
	back.custom_minimum_size = Vector2(220, 44)
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(MAIN_SCENE))
	root.add_child(back)


func _refresh() -> void:
	var avg := GameState.average_party_level()
	_wallet_label.text = Loc.pick("Gold: %d   ·   Eisenerz: %d   ·   Lederreste: %d   ·   Kristallstaub: %d   ·   Ø Party-Level: %d",
		"Gold: %d   ·   Iron ore: %d   ·   Leather scraps: %d   ·   Crystal dust: %d   ·   Avg. party level: %d") % [
		GameState.gold, GameState.material_count(&"eisenerz"),
		GameState.material_count(&"lederreste"), GameState.material_count(&"kristallstaub"), avg]

	for child in _craft_box.get_children():
		child.queue_free()
	for section in Smith.SECTIONS:
		var header := Label.new()
		header.text = Loc.pick(section["name"], section.get("name_en", section["name"]))
		header.add_theme_font_size_override("font_size", 16)
		header.modulate = Color(1, 1, 1, 0.6)
		_craft_box.add_child(header)
		for base_id in section["bases"]:
			var base := ItemLibrary.get_base(base_id)
			var cost := Smith.craft_cost(base_id, avg)
			var button := Button.new()
			if Smith.can_craft(base_id, avg):
				button.text = "%s   (%s)" % [base.display_name, _cost_text(cost)]
				button.disabled = not GameState.can_pay(cost)
			else:
				button.text = Loc.pick("%s   (ab Party-Level %d)", "%s   (from party level %d)") % [base.display_name,
					base.min_tier - Smith.LEVEL_DEVIATION]
				button.disabled = true
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.pressed.connect(_on_craft.bind(base_id))
			_craft_box.add_child(button)

	_reroll_select.clear()
	for item in GameState.inventory:
		if item.rarity != Enums.Rarity.COMMON:
			_reroll_select.add_item("%s (Lv %d, %s)" % [item.get_display_name(),
				item.item_level, LootGenerator.RARITY_NAMES[item.rarity]])
			_reroll_select.set_item_metadata(_reroll_select.item_count - 1, item)
	_refresh_reroll_button()


func _refresh_reroll_button() -> void:
	if _reroll_select.item_count == 0:
		_reroll_button.text = Loc.pick("Neu würfeln (kein Item mit Affixen im Inventar)", "Reroll (no item with affixes in inventory)")
		_reroll_button.disabled = true
		return
	var item: ItemInstance = _reroll_select.get_item_metadata(
		maxi(0, _reroll_select.selected))
	var cost := Smith.reroll_cost(item)
	_reroll_button.text = Loc.pick("Neu würfeln   (%s)", "Reroll   (%s)") % _cost_text(cost)
	_reroll_button.disabled = not GameState.can_pay(cost)


func _on_craft(base_id: StringName) -> void:
	var avg := GameState.average_party_level()
	var cost := Smith.craft_cost(base_id, avg)
	if not GameState.pay(cost):
		Sfx.play(&"fehler")
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var item := Smith.craft(base_id, avg, rng)
	if item == null:
		Sfx.play(&"fehler")
		return
	GameState.inventory.append(item)
	GameState.save_game()
	Sfx.play(&"schmiede")
	_result_label.text = Loc.pick("Geschmiedet: %s  (Level %d, %s)", "Forged: %s  (level %d, %s)") % [item.get_display_name(),
		item.item_level, LootGenerator.RARITY_NAMES[item.rarity]]
	_result_label.modulate = LootGenerator.RARITY_COLORS[item.rarity]
	_msg_label.text = ""
	_refresh()


func _on_reroll() -> void:
	if _reroll_select.item_count == 0:
		return
	var item: ItemInstance = _reroll_select.get_item_metadata(
		maxi(0, _reroll_select.selected))
	var cost := Smith.reroll_cost(item)
	if not GameState.pay(cost):
		Sfx.play(&"fehler")
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	Smith.reroll(item, rng)
	GameState.save_game()
	Sfx.play(&"schmiede")
	_result_label.text = Loc.pick("Neu gewürfelt: %s", "Rerolled: %s") % item.get_display_name()
	_result_label.modulate = LootGenerator.RARITY_COLORS[item.rarity]
	_refresh()


static func _cost_text(cost: Dictionary) -> String:
	var parts: Array[String] = ["%d G" % cost.get("gold", 0)]
	var mats: Dictionary = cost.get("materials", {})
	for id in mats:
		parts.append("%d %s" % [mats[id], MaterialLibrary.display_name(id)])
	return ", ".join(parts)
