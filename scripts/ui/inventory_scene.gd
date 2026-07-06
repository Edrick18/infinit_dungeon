extends Control
## Ausrüstung & Inventar: links die 9 Ausrüstungs-Slots des gewählten
## Charakters, rechts das geteilte Party-Inventar mit Ausrüsten/Verkaufen.

const MAIN_SCENE := "res://scenes/main.tscn"

const SLOT_NAMES := {
	Enums.EquipSlot.WEAPON: "Waffe",
	Enums.EquipSlot.OFF_HAND: "Nebenhand",
	Enums.EquipSlot.HELMET: "Helm",
	Enums.EquipSlot.ARMOR: "Rüstung",  # SLOT_NAMES bleiben deutsch; EN via _slot_name()
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
	theme = UiTheme.get_theme()
	_build_layout()
	_selected = GameState.party[0]
	_refresh()
	UiTheme.focus_first_button(self)


## Zurück dorthin, wo das Inventar geöffnet wurde (Dungeon oder Menü).
func _go_back() -> void:
	var target := GameState.ui_return_scene
	GameState.ui_return_scene = ""
	if target.is_empty():
		target = MAIN_SCENE
	get_tree().change_scene_to_file(target)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed \
			and (event.keycode == KEY_ESCAPE or event.is_action_pressed(&"open_inventory")):
		_go_back()


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
	add_child(UiTheme.make_background())

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
	title.text = Loc.pick("Ausrüstung & Inventar", "Equipment & inventory")
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_gold_label = Label.new()
	head.add_child(_gold_label)
	var back := Button.new()
	back.text = Loc.pick("Zurück [I/Esc]", "Back [I/Esc]")
	back.pressed.connect(_go_back)
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

	# Waffenset-Umschalter: Haupt-/Nebenhand existieren doppelt (Set A/B),
	# im Kampf frei wechselbar — hier wird das zweite Set bestückt.
	var set_row := HBoxContainer.new()
	set_row.add_theme_constant_override("separation", 8)
	_equip_list.add_child(set_row)
	var set_label := Label.new()
	set_label.text = Loc.pick("Waffenset: %s", "Weapon set: %s") \
		% ("A" if _selected.active_weapon_set == 0 else "B")
	set_label.add_theme_font_size_override("font_size", 15)
	set_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_row.add_child(set_label)
	var set_swap := Button.new()
	var other_weapon: ItemInstance = _selected.weapon_set_b.get(Enums.EquipSlot.WEAPON)
	set_swap.text = Loc.pick("Wechseln » %s", "Swap » %s") \
		% (other_weapon.get_display_name() if other_weapon != null else Loc.pick("(leer)", "(empty)"))
	set_swap.tooltip_text = Loc.pick(
		"Tauscht Haupt- und Nebenhand gegen das andere Set.\nZum Bestücken: wechseln, dann Waffen anlegen.\nIm Kampf ist der Wechsel eine freie Aktion.",
		"Swaps main and off hand with the other set.\nTo fill it: swap, then equip weapons.\nSwapping in battle is a free action.")
	set_swap.pressed.connect(func() -> void:
		_selected.swap_weapon_set()
		GameState.save_game()
		Sfx.play(&"bestaetigen")
		_refresh())
	set_row.add_child(set_swap)

	for slot in SLOT_NAMES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_equip_list.add_child(row)
		var slot_label := Label.new()
		slot_label.text = _slot_name(slot) + ":"
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
			off.text = Loc.pick("Ablegen", "Unequip")
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
		materials_header.text = Loc.pick("Materialien", "Materials")
		materials_header.add_theme_font_size_override("font_size", 16)
		_inventory_list.add_child(materials_header)
		for id in GameState.materials:
			var row := Label.new()
			row.text = "  %s ×%d" % [MaterialLibrary.display_name(id),
				GameState.material_count(id)]
			row.add_theme_font_size_override("font_size", 12)
			_inventory_list.add_child(row)
	_build_field_skill_section()

	if not GameState.consumables.is_empty():
		var consumables_header := Label.new()
		consumables_header.text = Loc.pick("Verbrauchsgegenstände", "Consumables")
		consumables_header.add_theme_font_size_override("font_size", 16)
		_inventory_list.add_child(consumables_header)
		for id in GameState.consumables:
			var def := ConsumableLibrary.get_def(id)
			if def == null:
				continue
			_inventory_list.add_child(_make_consumable_row(def))
		var items_header := Label.new()
		items_header.text = Loc.pick("Ausrüstung", "Equipment")
		items_header.add_theme_font_size_override("font_size", 16)
		_inventory_list.add_child(items_header)
	if GameState.inventory.is_empty():
		var empty := Label.new()
		empty.text = Loc.pick("Inventar ist leer — Beute gibt es in den Dungeons.", "Inventory is empty — loot awaits in the dungeons.")
		empty.modulate = Color(1, 1, 1, 0.5)
		_inventory_list.add_child(empty)
	else:
		# Aufgeräumt: nach Slot gruppiert, beste Rarität zuerst.
		GameState.inventory.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
			if a.base.slot != b.base.slot:
				return a.base.slot < b.base.slot
			return a.rarity > b.rarity)
		var commons := 0
		for item in GameState.inventory:
			if item.rarity == Enums.Rarity.COMMON:
				commons += 1
		if commons > 0:
			var sell_commons := Button.new()
			sell_commons.text = Loc.pick("Alle Gewöhnlichen verkaufen (%d Stück)", "Sell all commons (%d items)") % commons
			sell_commons.pressed.connect(_on_sell_commons)
			_inventory_list.add_child(sell_commons)
	for item in GameState.inventory:
		_inventory_list.add_child(_make_item_row(item))


## QoL: der Stapel grauer Items geht mit einem Klick zu Gold.
func _on_sell_commons() -> void:
	var earned := 0
	for item in GameState.inventory.duplicate():
		if item.rarity == Enums.Rarity.COMMON:
			earned += LootGenerator.sell_price(item)
			GameState.inventory.erase(item)
	GameState.gold += earned
	_refresh()


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

	# Direkter Vergleich mit dem ausgerüsteten Item des gewählten Helden.
	var compare_text := _compare_with_equipped(item)
	if not compare_text.is_empty():
		var compare := Label.new()
		compare.text = compare_text
		compare.add_theme_font_size_override("font_size", 11)
		compare.modulate = Color(0.65, 0.9, 1.0)
		info.add_child(compare)

	var equip_button := Button.new()
	equip_button.text = Loc.pick("Ausrüsten", "Equip")
	equip_button.pressed.connect(_on_equip.bind(item))
	row.add_child(equip_button)

	var sell_button := Button.new()
	sell_button.text = Loc.pick("Verkaufen (%d G)", "Sell (%d G)") % LootGenerator.sell_price(item)
	sell_button.pressed.connect(_on_sell.bind(item))
	row.add_child(sell_button)
	return panel


## Vergleich mit dem Item, das der gewählte Held im selben Slot trägt:
## "vs. Flammendes Schwert: +4 Schaden · −2 AGI".
func _compare_with_equipped(item: ItemInstance) -> String:
	if _selected == null:
		return ""
	var slot := item.base.slot
	var equipped: ItemInstance = _selected.equipment.get(slot)
	if equipped == null and slot == Enums.EquipSlot.RING_1:
		equipped = _selected.equipment.get(Enums.EquipSlot.RING_2)
	if equipped == null or equipped == item:
		return ""
	var parts: Array[String] = []
	_add_delta(parts, item.get_total_damage() - equipped.get_total_damage(), "Schaden")
	_add_delta(parts, item.get_total_spell_damage() - equipped.get_total_spell_damage(),
		"Zauberkraft")
	_add_delta(parts, item.get_total_armor() - equipped.get_total_armor(), "Rüstung")
	var mine := item.get_total_stat_bonus()
	var theirs := equipped.get_total_stat_bonus()
	for stat in StatBlock.STAT_NAMES:
		_add_delta(parts, mine.get(stat) - theirs.get(stat), _stat_short(stat))
	_add_delta(parts, item.get_mp_cost_reduction() - equipped.get_mp_cost_reduction(),
		"MP-Ersparnis")
	if parts.is_empty():
		return "vs. %s (%s): gleichwertig" % [equipped.get_display_name(),
			_selected.display_name]
	return "vs. %s (%s): %s" % [equipped.get_display_name(), _selected.display_name,
		" · ".join(parts)]


static func _add_delta(parts: Array[String], value: int, label: String) -> void:
	if value != 0:
		parts.append("%+d %s" % [value, label])


static func _item_summary(item: ItemInstance) -> String:
	var parts: Array[String] = []
	parts.append(SLOT_NAMES[item.base.slot])
	if item.base.ranged:
		parts.append("Fernkampf (Köcher in der Nebenhand erlaubt)")
	elif item.base.two_handed:
		parts.append("Zweihändig")
	if item.base.light:
		parts.append("Leicht (auch in der Nebenhand führbar)")
	if item.base.quiver:
		parts.append("Köcher (Bonus nur mit Bogen/Armbrust)")
	if item.get_total_damage() > 0:
		var subtype_names: Array[String] = []
		for subtype in item.base.weapon_subtypes:
			subtype_names.append(Enums.physical_subtype_name(subtype))
		if subtype_names.is_empty():
			parts.append("+%d Schaden" % item.get_total_damage())
		else:
			parts.append("+%d Schaden (%s)" % [item.get_total_damage(),
				"/".join(subtype_names)])
	if item.base.hit_count > 1:
		parts.append("%d Treffer pro Angriff" % item.base.hit_count)
	if item.base.armor_pierce > 0.0:
		parts.append("ignoriert %d%% Rüstung" % roundi(item.base.armor_pierce * 100))
	if item.get_total_spell_damage() > 0:
		parts.append("+%d Zauberkraft" % item.get_total_spell_damage())
	var riders := item.get_element_riders()
	for element in riders:
		var rider_block := BlockLibrary.element_block(element)
		if rider_block != null:
			parts.append("+%d %s-Schaden" % [riders[element], rider_block.display_name])
	for i in item.affixes.size():
		var affix: Affix = item.affixes[i]
		if affix.element_resist > 0:
			var resist := roundi(item.affix_value(i, affix.element_resist)
				* (1.0 + ItemInstance.LEVEL_SCALE * (item.item_level - 1)))
			if affix.element == Enums.Element.NONE:
				parts.append("+%d Resistenz (alle Elemente)" % resist)
			else:
				var resist_block := BlockLibrary.element_block(affix.element)
				if resist_block != null:
					parts.append("+%d %s-Resistenz" % [resist, resist_block.display_name])
	if item.get_mp_cost_reduction() > 0:
		parts.append("-%d MP-Kosten" % item.get_mp_cost_reduction())
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
	points_label.text = Loc.pick("Freie Statuspunkte: %d", "Free stat points: %d") % _selected.stat_points
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


## Slot-Name in der aktuellen Sprache.
func _slot_name(slot: Enums.EquipSlot) -> String:
	var en := {
		Enums.EquipSlot.WEAPON: "Weapon", Enums.EquipSlot.OFF_HAND: "Off-hand",
		Enums.EquipSlot.HELMET: "Helmet", Enums.EquipSlot.ARMOR: "Armor",
		Enums.EquipSlot.GLOVES: "Gloves", Enums.EquipSlot.BOOTS: "Boots",
		Enums.EquipSlot.RING_1: "Ring 1", Enums.EquipSlot.RING_2: "Ring 2",
		Enums.EquipSlot.AMULET: "Amulet",
	}
	return Loc.pick(SLOT_NAMES[slot], en[slot])


# --- Tränke & Feldzauber (außerhalb des Kampfs) ---------------------------------

## Trank-Zeile: Benutzen wirkt auf den links ausgewählten Helden.
func _make_consumable_row(def: ConsumableDef) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var info := Label.new()
	info.text = "%s ×%d  —  %s" % [def.display_name,
		GameState.consumable_count(def.id), def.description]
	info.add_theme_font_size_override("font_size", 12)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var use := Button.new()
	use.text = Loc.pick("Benutzen (%s)", "Use (%s)") % _selected.display_name
	var needs_dead := def.effect == Enums.ConsumableEffect.REVIVE
	use.disabled = _selected.is_alive() == needs_dead
	use.pressed.connect(_use_consumable.bind(def))
	row.add_child(use)
	return panel


func _use_consumable(def: ConsumableDef) -> void:
	var target := _selected
	match def.effect:
		Enums.ConsumableEffect.HEAL_HP:
			if not target.is_alive():
				return
			target.heal(def.heal_amount(target))
		Enums.ConsumableEffect.RESTORE_MP:
			if not target.is_alive():
				return
			target.mp = mini(target.max_mp, target.mp + def.mana_amount(target))
		Enums.ConsumableEffect.CURE_AILMENTS:
			if not target.is_alive():
				return
			for entry in target.statuses.duplicate():
				if entry["status"] in def.cures:
					target.statuses.erase(entry)
		Enums.ConsumableEffect.REVIVE:
			if target.is_alive():
				return
			target.hp = maxi(1, roundi(target.max_hp * def.potency / 100.0))
	GameState.consume(def.id)
	Sfx.play(&"trank")
	_refresh()


## Feldzauber: Heilung (Heilig), Kuren (Reinigung) und Wiederbelebung sind
## AUSSERHALB des Kampfs wirkbar (Prep vor Kämpfen) — Buffs bewusst nicht.
func _build_field_skill_section() -> void:
	var rows: Array[Control] = []
	for caster in GameState.party:
		if not caster.is_alive():
			continue
		for skill: Skill in caster.skills.slice(0, caster.skill_slots()):
			if not _is_field_skill(skill):
				continue
			rows.append(_make_field_skill_row(caster, skill))
	if rows.is_empty():
		return
	var header := Label.new()
	header.text = Loc.pick("Feldzauber (Heilung/Kuren — Ziel: %s)",
		"Field spells (healing/cures — target: %s)") % _selected.display_name
	header.add_theme_font_size_override("font_size", 16)
	_inventory_list.add_child(header)
	for row in rows:
		_inventory_list.add_child(row)


## Feld-tauglich: gültig, freundliche Form UND heilende/kurierende Wirkung.
func _is_field_skill(skill: Skill) -> bool:
	if not skill.is_valid():
		return false
	var form := skill.get_form()
	if form != Enums.SkillForm.ALLY and form != Enums.SkillForm.AURA 			and form != Enums.SkillForm.SELF:
		return false
	var element := skill.get_element()
	if element != null and element.element == Enums.Element.HOLY:
		return true
	for effect in skill.get_effect_blocks():
		if effect.status == Enums.Status.CLEANSE or effect.status == Enums.Status.REVIVE:
			return true
	return false


func _make_field_skill_row(caster: Combatant, skill: Skill) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var cost := skill.get_mp_cost(caster)
	var info := Label.new()
	info.text = "%s: %s (%d MP)  ·  %d/%d MP" % [caster.display_name,
		skill.display_name, cost, caster.mp, caster.max_mp]
	info.add_theme_font_size_override("font_size", 12)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var cast := Button.new()
	cast.text = Loc.pick("Wirken", "Cast")
	cast.disabled = caster.mp < cost
	cast.pressed.connect(_cast_field_skill.bind(caster, skill))
	row.add_child(cast)
	return panel


func _cast_field_skill(caster: Combatant, skill: Skill) -> void:
	var cost := skill.get_mp_cost(caster)
	if caster.mp < cost or not caster.is_alive():
		Sfx.play(&"fehler")
		return
	caster.mp -= cost
	var targets: Array[Combatant] = []
	match skill.get_form():
		Enums.SkillForm.ALLY:
			targets = [_selected]
		Enums.SkillForm.AURA:
			targets = GameState.party.duplicate()
		Enums.SkillForm.SELF:
			targets = [caster]
	var element := skill.get_element()
	for target in targets:
		# Heilig-Heilung: dieselbe Formel wie im Kampf (friendly Holy » Heilung).
		if element != null and element.element == Enums.Element.HOLY and target.is_alive():
			for source in skill.get_sources():
				if source.source == Enums.SkillSource.SPELL:
					var form_block := skill.get_form_block()
					var power := form_block.power_multiplier if form_block != null else 1.0
					target.heal(roundi((caster.spell_damage()
						+ caster.stat(&"intelligence") * source.scaling_per_point)
						* power * source.power_multiplier))
		for effect in skill.get_effect_blocks():
			if effect.status == Enums.Status.CLEANSE and target.is_alive():
				for entry in target.statuses.duplicate():
					if entry["status"] in Battle.CURABLE_STATUSES:
						target.statuses.erase(entry)
			elif effect.status == Enums.Status.REVIVE and not target.is_alive():
				target.hp = maxi(1, roundi(target.max_hp * effect.potency / 100.0))
	Sfx.play(&"heilung")
	_refresh()
