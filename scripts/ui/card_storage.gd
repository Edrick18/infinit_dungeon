extends Control
## Kartenlager: gesammelte Dungeon-Karten ansehen, betreten, löschen,
## Lager gegen Gold erweitern. Der Einstiegspunkt in jeden Dungeon-Run.

const MAIN_SCENE := "res://scenes/main.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/dungeon_scene.tscn"

var _gold_label: Label
var _capacity_label: Label
var _expand_button: Button
var _card_list: VBoxContainer


func _ready() -> void:
	theme = UiTheme.get_theme()
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


func _on_enter(card: DungeonCard) -> void:
	if Net.is_guest():
		# Co-op-Gast: eigene Karten sind waehrend der Session gesperrt.
		Sfx.play(&"fehler")
		return
	GameState.start_run(card)
	get_tree().change_scene_to_file(DUNGEON_SCENE)


func _on_delete(card: DungeonCard) -> void:
	GameState.delete_card(card)
	_refresh()


func _on_expand() -> void:
	if GameState.expand_storage():
		Sfx.play(&"bestaetigen")
		_refresh()


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
	head.add_theme_constant_override("separation", 12)
	main.add_child(head)
	var title := Label.new()
	title.text = Loc.pick("Kartenlager", "Map storage")
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_gold_label = Label.new()
	head.add_child(_gold_label)
	_capacity_label = Label.new()
	head.add_child(_capacity_label)
	_expand_button = Button.new()
	_expand_button.pressed.connect(_on_expand)
	head.add_child(_expand_button)
	var back := Button.new()
	back.text = Loc.pick("Zurück zum Menü", "Back to menu")
	back.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(MAIN_SCENE))
	head.add_child(back)

	var hint := Label.new()
	hint.text = Loc.pick("Nach jedem Abschluss gibt es eine neue Karte auf Stufe ±3. Karten sind wiederholbar — gleiche Karte, gleiches Layout, gleiche Elite-Typen.",
		"Every completion grants a new map at tier ±3. Maps are repeatable — same map, same layout, same elite types.")
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	main.add_child(hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(scroll)
	_card_list = VBoxContainer.new()
	_card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_card_list)


func _refresh() -> void:
	_gold_label.text = "Gold: %d" % GameState.gold
	_capacity_label.text = Loc.pick("Karten: %d/%d", "Maps: %d/%d") % [GameState.cards.size(), GameState.card_capacity]
	_expand_button.text = Loc.pick("Lager erweitern +5 (%d G)", "Expand storage +5 (%d G)") % GameState.storage_expansion_cost()
	_expand_button.disabled = not GameState.can_expand_storage()

	for child in _card_list.get_children():
		child.queue_free()
	if GameState.cards.is_empty():
		var empty := Label.new()
		empty.text = Loc.pick("Keine Karten — schließe Dungeons ab, um neue zu erhalten.", "No maps — complete dungeons to earn new ones.")
		empty.modulate = Color(1, 1, 1, 0.5)
		_card_list.add_child(empty)
	for card in GameState.cards:
		_card_list.add_child(_make_card_row(card))


func _make_card_row(card: DungeonCard) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = Loc.pick("%s  —  Stufe %d, %s, %d Ebene%s", "%s  —  tier %d, %s, %d floor%s") % [card.display_name, card.tier,
		CardFactory.biome_name(card.biome), card.floor_count,
		"" if card.floor_count == 1 else Loc.pick("n", "s")]
	name_label.modulate = LootGenerator.RARITY_COLORS[card.card_rarity]
	if card.card_rarity != Enums.Rarity.COMMON:
		name_label.text = "[%s] %s" % [LootGenerator.RARITY_NAMES[card.card_rarity],
			name_label.text]
		name_label.tooltip_text = Loc.pick(
			"Seltene Karte: Gegner +%d Stufen, Beute ×%.2f, XP ×%.2f",
			"Rare map: enemies +%d tiers, loot ×%.2f, XP ×%.2f") % [
			card.rarity_level_bonus(), card.rarity_loot_mult(), card.rarity_xp_mult()]
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	if card.legendary:
		name_label.text = Loc.pick("[LEGENDÄR] ", "[LEGENDARY] ") + name_label.text
	info.add_child(name_label)

	var detail := Label.new()
	var modifier_names: Array[String] = []
	for id in card.modifier_ids:
		var modifier := EnemyLibrary.get_modifier(id)
		if modifier != null:
			modifier_names.append(modifier.display_name)
	var detail_parts: Array[String] = []
	if not modifier_names.is_empty():
		detail_parts.append(Loc.pick("Eliten: ", "Elites: ") + ", ".join(modifier_names))
	if card.times_completed > 0:
		detail_parts.append(Loc.pick("%d× abgeschlossen", "completed %d×") % card.times_completed)
	detail.text = "  ·  ".join(detail_parts) if not detail_parts.is_empty() else Loc.pick("Noch unerkundet", "Unexplored")
	detail.add_theme_font_size_override("font_size", 11)
	detail.modulate = Color(1, 1, 1, 0.6)
	info.add_child(detail)

	# Karten-Vorschau (alles deterministisch): welche Gegnertypen, welche
	# Boss-Kandidaten und welche Themen-Materialien hier warten.
	var preview := Label.new()
	preview.text = _card_preview(card)
	preview.add_theme_font_size_override("font_size", 11)
	preview.modulate = Color(0.7, 0.85, 1.0, 0.85)
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(preview)

	# Legendäre Karte: der Legacy-Boss levelt mit jedem Abschluss.
	if card.legendary:
		var legend := Label.new()
		legend.text = Loc.pick("LEGENDÄR — Boss-Stufe %d (+2 pro Abschluss, mehr Beute & XP)",
			"LEGENDARY — boss tier %d (+2 per completion, more loot & XP)") \
			% (card.tier + card.legacy_boss_bonus())
		legend.add_theme_font_size_override("font_size", 11)
		legend.modulate = Color(1.0, 0.61, 0.25)
		info.add_child(legend)

	# Karten-Affixe: das Risiko/Belohnungs-Profil dieser Karte (gold hervorgehoben).
	if not card.card_affix_ids.is_empty():
		var affix_label := Label.new()
		var affix_parts: Array[String] = []
		for id in card.card_affix_ids:
			affix_parts.append("%s (%s)" % [CardFactory.card_affix_name(id),
				CardFactory.card_affix_desc(id)])
		affix_label.text = "  ·  ".join(affix_parts)
		affix_label.add_theme_font_size_override("font_size", 11)
		affix_label.modulate = Color(1.0, 0.85, 0.4)
		info.add_child(affix_label)

	var enter := Button.new()
	enter.text = Loc.pick("Betreten", "Enter")
	enter.pressed.connect(_on_enter.bind(card))
	row.add_child(enter)

	var delete := Button.new()
	delete.text = Loc.pick("Löschen", "Delete")
	delete.pressed.connect(_on_delete.bind(card))
	row.add_child(delete)
	return panel


## Vorschau: Gegnertypen, Boss-Kandidaten und Themen-Materialien der Karte —
## komplett deterministisch aus den Karten-Daten ableitbar.
func _card_preview(card: DungeonCard) -> String:
	var max_tier := card.tier + card.floor_count - 1  # tiefste Ebene
	var enemy_names: Array[String] = []
	var materials := {}
	for archetype in EnemyLibrary.archetypes_for_biome(card.biome, false, max_tier):
		if enemy_names.size() < 5:
			enemy_names.append(archetype.display_name)
		var themed: StringName = LootGenerator.ARCHETYPE_MATERIALS.get(archetype.id, &"")
		if themed != &"":
			materials[MaterialLibrary.display_name(themed)] = true
	var boss_names: Array[String] = []
	for archetype in EnemyLibrary.archetypes_for_biome(card.biome, true,
			max_tier + card.legacy_boss_bonus()):
		boss_names.append(archetype.display_name)
	if boss_names.is_empty():
		# Wie der Boss-Fallback der Factory: der am frühesten freigeschaltete.
		var all_bosses := EnemyLibrary.archetypes_for_biome(card.biome, true)
		var min_unlock := 9999
		for archetype in all_bosses:
			min_unlock = mini(min_unlock, archetype.unlock_tier)
		for archetype in all_bosses:
			if archetype.unlock_tier == min_unlock:
				boss_names.append(archetype.display_name)
	var material_names: Array[String] = []
	for name in materials:
		material_names.append(name)
	return Loc.pick("Gegner: %s   ·   Boss: %s   ·   Materialien: %s",
		"Enemies: %s   ·   Boss: %s   ·   Materials: %s") % [
		", ".join(enemy_names), " / ".join(boss_names),
		", ".join(material_names) if not material_names.is_empty() else "—"]
