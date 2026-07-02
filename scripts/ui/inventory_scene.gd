extends Control
## Ausrüstung & Inventar: links die 9 Ausrüstungs-Slots des gewählten
## Charakters, rechts das geteilte Party-Inventar mit Ausrüsten/Verkaufen.

const MAIN_SCENE := "res://scenes/main.tscn"

const SLOT_NAMES := {
	Enums.EquipSlot.WEAPON: "Waffe",
	Enums.EquipSlot.OFF_HAND: "Nebenhand",
	Enums.EquipSlot.HELMET: "Helm",
	Enums.EquipSlot.ARMOR: "Rüstung",
	Enums.EquipSlot.GLOVES: "Handschuhe",
	Enums.EquipSlot.BOOTS: "Stiefel",
	Enums.EquipSlot.RING_1: "Ring 1",
	Enums.EquipSlot.RING_2: "Ring 2",
	Enums.EquipSlot.AMULET: "Amulett",
}

var _selected: Combatant = null

var _gold_label: Label
var _char_bar: HBoxContainer
var _equip_list: VBoxContainer
var _stats_label: Label
var _stats_box: VBoxContainer
var _inventory_list: VBoxContainer


func _ready() -> void:
	_build_layout()
	_selected = GameState.party[0]
	_refresh()


# --- Aktionen -------------------------------------------------------------------

func _on_equip(item: ItemInstance) -> void:
	GameState.inventory.erase(item)
	# Kann mehrere Items verdrängen (z.B. Zweihänder ersetzt Waffe + Schild).
	for replaced in _selected.equip(item):
		GameState.inventory.append(replaced)
	_refresh()


func _on_unequip(slot: Enums.EquipSlot) -> void:
	var item := _selected.unequip(slot)
	if item != null:
		GameState.inventory.append(item)
	_refresh()


func _on_sell(item: ItemInstance) -> void:
	GameState.inventory.erase(item)
	GameState.gold += LootGenerator.sell_price(item)
	_refresh()


# --- UI -------------------------------------------------------------------------

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
	main.add_child(head)
	var title := Label.new()
	title.text = "Ausrüstung & Inventar"
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

	_char_bar = HBoxContainer.new()
	_char_bar.add_theme_constant_override("separation", 8)
	main.add_child(_char_bar)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	main.add_child(body)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	body.add_child(left)
	_equip_list = VBoxContainer.new()
	_equip_list.add_theme_constant_override("separation", 4)
	left.add_child(_equip_list)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.modulate = Color(1, 1, 1, 0.7)
	left.add_child(_stats_label)
	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 2)
	left.add_child(_stats_box)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 1.4
	body.add_child(scroll)
	_inventory_list = VBoxContainer.new()
	_inventory_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_inventory_list)


func _refresh() -> void:
	_gold_label.text = "Gold: %d   " % GameState.gold

	for child in _char_bar.get_children():
		child.queue_free()
	for member in GameState.party:
		var button := Button.new()
		button.text = "%s (Lv. %d)" % [member.display_name, member.level]
		button.disabled = member == _selected
		button.pressed.connect(func() -> void:
			_selected = member
			_refresh())
		_char_bar.add_child(button)

	for child in _equip_list.get_children():
		child.queue_free()
	for slot in SLOT_NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_equip_list.add_child(row)
		var slot_label := Label.new()
		slot_label.text = SLOT_NAMES[slot] + ":"
		slot_label.custom_minimum_size = Vector2(100, 0)
		slot_label.modulate = Color(1, 1, 1, 0.6)
		row.add_child(slot_label)
		if _selected.equipment.has(slot):
			var item: ItemInstance = _selected.equipment[slot]
			var name_label := Label.new()
			name_label.text = item.get_display_name()
			name_label.modulate = LootGenerator.RARITY_COLORS[item.rarity]
			name_label.tooltip_text = _item_summary(item)
			name_label.mouse_filter = Control.MOUSE_FILTER_PASS
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			var off := Button.new()
			off.text = "Ablegen"
			off.pressed.connect(_on_unequip.bind(slot))
			row.add_child(off)
		else:
			var empty := Label.new()
			empty.text = "—"
			empty.modulate = Color(1, 1, 1, 0.3)
			row.add_child(empty)

	_stats_label.text = _char_summary(_selected)
	_rebuild_stat_allocation()

	for child in _inventory_list.get_children():
		child.queue_free()
	if not GameState.materials.is_empty():
		var materials_header := Label.new()
		materials_header.text = "Materialien"
		materials_header.add_theme_font_size_override("font_size", 16)
		_inventory_list.add_child(materials_header)
		for id in GameState.materials:
			var row := Label.new()
			row.text = "  %s ×%d" % [MaterialLibrary.display_name(id),
				GameState.material_count(id)]
			row.add_theme_font_size_override("font_size", 12)
			_inventory_list.add_child(row)
	if not GameState.consumables.is_empty():
		var consumables_header := Label.new()
		consumables_header.text = "Verbrauchsgegenstände"
		consumables_header.add_theme_font_size_override("font_size", 16)
		_inventory_list.add_child(consumables_header)
		for id in GameState.consumables:
			var def := ConsumableLibrary.get_def(id)
			if def == null:
				continue
			var row := Label.new()
			row.text = "  %s ×%d  —  %s" % [def.display_name,
				GameState.consumable_count(id), def.description]
			row.add_theme_font_size_override("font_size", 12)
			_inventory_list.add_child(row)
		var items_header := Label.new()
		items_header.text = "Ausrüstung"
		items_header.add_theme_font_size_override("font_size", 16)
		_inventory_list.add_child(items_header)
	if GameState.inventory.is_empty():
		var empty := Label.new()
		empty.text = "Inventar ist leer — Beute gibt es in den Dungeons."
		empty.modulate = Color(1, 1, 1, 0.5)
		_inventory_list.add_child(empty)
	for item in GameState.inventory:
		_inventory_list.add_child(_make_item_row(item))


func _make_item_row(item: ItemInstance) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = "%s  (%s, Stufe %d)" % [item.get_display_name(),
		LootGenerator.RARITY_NAMES[item.rarity], item.item_level]
	name_label.modulate = LootGenerator.RARITY_COLORS[item.rarity]
	info.add_child(name_label)
	var summary := Label.new()
	summary.text = _item_summary(item)
	summary.add_theme_font_size_override("font_size", 11)
	summary.modulate = Color(1, 1, 1, 0.6)
	info.add_child(summary)

	var equip_button := Button.new()
	equip_button.text = "Ausrüsten"
	equip_button.pressed.connect(_on_equip.bind(item))
	row.add_child(equip_button)

	var sell_button := Button.new()
	sell_button.text = "Verkaufen (%d G)" % LootGenerator.sell_price(item)
	sell_button.pressed.connect(_on_sell.bind(item))
	row.add_child(sell_button)
	return panel


static func _item_summary(item: ItemInstance) -> String:
	var parts: Array[String] = []
	parts.append(SLOT_NAMES[item.base.slot])
	if item.base.two_handed:
		parts.append("Zweihändig")
	if item.get_total_damage() > 0:
		var subtype_names: Array[String] = []
		for subtype in item.base.weapon_subtypes:
			subtype_names.append(Enums.physical_subtype_name(subtype))
		if subtype_names.is_empty():
			parts.append("+%d Schaden" % item.get_total_damage())
		else:
			parts.append("+%d Schaden (%s)" % [item.get_total_damage(),
				"/".join(subtype_names)])
	if item.get_total_armor() > 0:
		var class_name_text := Enums.armor_class_name(item.base.armor_class)
		if class_name_text.is_empty():
			parts.append("+%d Rüstung" % item.get_total_armor())
		else:
			parts.append("+%d Rüstung (%s)" % [item.get_total_armor(), class_name_text])
	var bonus := item.get_total_stat_bonus()
	for stat in StatBlock.STAT_NAMES:
		var value: int = bonus.get(stat)
		if value != 0:
			parts.append("%+d %s" % [value, _stat_short(stat)])
	return "  ·  ".join(parts)


## Statuspunkte verteilen: pro Attribut eine Zeile mit [+]-Button,
## solange unverteilte Punkte da sind.
func _rebuild_stat_allocation() -> void:
	for child in _stats_box.get_children():
		child.queue_free()
	var points_label := Label.new()
	points_label.text = "Freie Statuspunkte: %d" % _selected.stat_points
	points_label.add_theme_font_size_override("font_size", 13)
	if _selected.stat_points > 0:
		points_label.modulate = Color(0.55, 1.0, 0.55)
	else:
		points_label.modulate = Color(1, 1, 1, 0.5)
	_stats_box.add_child(points_label)
	if _selected.stat_points <= 0:
		return
	for stat in StatBlock.STAT_NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_stats_box.add_child(row)
		var stat_label := Label.new()
		stat_label.text = "%s: %d (Basis %d)" % [_stat_short(stat),
			_selected.stat(stat), _selected.stats.get(stat)]
		stat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_label.add_theme_font_size_override("font_size", 12)
		row.add_child(stat_label)
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(32, 0)
		plus.pressed.connect(func() -> void:
			_selected.spend_stat_point(stat)
			_refresh())
		row.add_child(plus)


static func _char_summary(member: Combatant) -> String:
	return "Level %d (%d/%d XP)  ·  HP %d/%d  ·  MP %d/%d  ·  Rüstung %d  ·  Waffenschaden +%d\nSTR %d  INT %d  VIT %d  SPI %d  AGI %d  LCK %d" % [
		member.level, member.xp, member.xp_to_next(),
		member.hp, member.max_hp, member.mp, member.max_mp,
		member.total_armor(), member.weapon_damage(),
		member.stat(&"strength"), member.stat(&"intelligence"), member.stat(&"vitality"),
		member.stat(&"spirit"), member.stat(&"agility"), member.stat(&"luck"),
	]


static func _stat_short(stat: StringName) -> String:
	match stat:
		&"strength": return "STR"
		&"intelligence": return "INT"
		&"vitality": return "VIT"
		&"spirit": return "SPI"
		&"agility": return "AGI"
		&"luck": return "LCK"
	return str(stat)
