extends Control
## Kartenlager: gesammelte Dungeon-Karten ansehen, betreten, löschen,
## Lager gegen Gold erweitern. Der Einstiegspunkt in jeden Dungeon-Run.
## Favoriten (★) stehen oben und sind vor dem Löschen geschützt; das Archiv
## bewahrt besondere Farm-Karten (Boss, Gegner, Affixe) außerhalb des Lagers auf.

const MAIN_SCENE := "res://scenes/main.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/dungeon_scene.tscn"

var _gold_label: Label
var _capacity_label: Label
var _expand_button: Button
var _card_list: VBoxContainer
## Karte, für die „Betreten“ bei laufendem Dungeon schon einmal angeklickt wurde.
var _betreten_karte: DungeonCard = null
var _ansicht := &"lager"  ## &"lager" oder &"archiv"
var _tab_lager: Button
var _tab_archiv: Button


func _ready() -> void:
	theme = UiTheme.get_theme()
	Music.play(&"menu")
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


func _on_enter(card: DungeonCard) -> void:
	if Net.is_guest():
		# Co-op-Gast: eigene Karten sind waehrend der Session gesperrt.
		Sfx.play(&"fehler")
		return
	# Ein laufender Dungeon geht beim Betreten einer Karte verloren — erst der
	# zweite Klick bestätigt.
	if not GameState.current_run.is_empty() and _betreten_karte != card:
		_betreten_karte = card
		_refresh()
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
	var b := Bildschirm.bauen(self, Loc.pick("Kartenlager", "Map storage"), &"lager",
		func() -> void: get_tree().change_scene_to_file(MAIN_SCENE), Loc.pick("Menü", "Menu"))
	_gold_label = b.info("")
	_capacity_label = b.info("", UiTheme.TEXT)
	_expand_button = Button.new()
	_expand_button.pressed.connect(_on_expand)
	b.kopf_info.add_child(_expand_button)
	b.setze_untertitel(Loc.pick("Nach jedem Abschluss gibt es eine neue Karte auf Stufe −2 bis +5. Karten sind wiederholbar — gleiche Karte, gleiches Layout, gleiche Elite-Typen.",
		"Every completion grants a new map at tier −2 to +5. Maps are repeatable — same map, same layout, same elite types."))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	b.inhalt.add_child(tabs)
	_tab_lager = Button.new()
	_tab_lager.pressed.connect(func() -> void:
		_ansicht = &"lager"
		_refresh())
	tabs.add_child(_tab_lager)
	_tab_archiv = Button.new()
	_tab_archiv.tooltip_text = Loc.pick("Besondere Karten aufbewahren, ohne Lagerplatz zu belegen — betreten geht auch von hier.",
		"Keep special maps without using storage slots — you can enter them from here too.")
	_tab_archiv.pressed.connect(func() -> void:
		_ansicht = &"archiv"
		_refresh())
	tabs.add_child(_tab_archiv)
	var teile := Bildschirm.scroll_liste(6)
	b.inhalt.add_child(teile[0])
	_card_list = teile[1]


func _refresh() -> void:
	_gold_label.text = "Gold: %d" % GameState.gold
	_capacity_label.text = Loc.pick("Karten: %d/%d", "Maps: %d/%d") % [GameState.cards.size(), GameState.card_capacity]
	_expand_button.text = Loc.pick("Lager erweitern +5 (%d G)", "Expand storage +5 (%d G)") % GameState.storage_expansion_cost()
	_expand_button.disabled = not GameState.can_expand_storage()

	_tab_lager.text = Loc.pick("Lager (%d/%d)", "Storage (%d/%d)") % [GameState.cards.size(), GameState.card_capacity]
	_tab_archiv.text = Loc.pick("Archiv (%d/%d)", "Archive (%d/%d)") % [GameState.card_archive.size(), GameState.ARCHIV_PLAETZE]
	UiTheme.als_aktiv(_tab_lager, _ansicht == &"lager")
	UiTheme.als_aktiv(_tab_archiv, _ansicht == &"archiv")

	for child in _card_list.get_children():
		child.queue_free()
	var liste: Array[DungeonCard] = GameState.cards if _ansicht == &"lager" else GameState.card_archive
	if liste.is_empty():
		var empty := Label.new()
		empty.text = Loc.pick("Keine Karten — schließe Dungeons ab, um neue zu erhalten.", "No maps — complete dungeons to earn new ones.") if _ansicht == &"lager" \
			else Loc.pick("Das Archiv ist leer — „Archivieren“ legt eine Karte hier ab.", "The archive is empty — \"Archive\" puts a map here.")
		empty.modulate = Color(1, 1, 1, 0.5)
		_card_list.add_child(empty)
	# Favoriten zuerst, sonst die gewohnte Reihenfolge.
	var sortiert: Array[DungeonCard] = []
	for card in liste:
		if card.favorit:
			sortiert.append(card)
	for card in liste:
		if not card.favorit:
			sortiert.append(card)
	for card in sortiert:
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
	name_label.text = Loc.pick("%s  —  Stufe %d, %s, %d Ebene%s + Boss-Ebene", "%s  —  tier %d, %s, %d floor%s + boss floor") % [card.display_name, card.tier,
		CardFactory.biome_name(card.biome), card.floor_count,
		"" if card.floor_count == 1 else Loc.pick("n", "s")]
	name_label.modulate = LootGenerator.RARITY_COLORS[card.card_rarity]
	if card.card_rarity != Enums.Rarity.COMMON:
		name_label.text = "[%s] %s" % [LootGenerator.RARITY_NAMES[card.card_rarity],
			name_label.text]
		name_label.tooltip_text = Loc.pick(
			"Seltene Karte: Gegner +%d Stufen, Beute ×%.2f, XP ×%.2f, bessere Truhen",
			"Rare map: enemies +%d tiers, loot ×%.2f, XP ×%.2f, better chests") % [
			card.rarity_level_bonus(), card.rarity_loot_mult(), card.rarity_xp_mult()]
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	if card.legendary:
		# Legacy-Boss-Karte (wächst mit jedem Abschluss) — nicht dasselbe wie
		# die Seltenheit „Legendär“ (Spieltest 2026-10-23: doppeltes Etikett).
		name_label.text = Loc.pick("[LEGACY] ", "[LEGACY] ") + name_label.text
	var name_zeile := HBoxContainer.new()
	name_zeile.add_theme_constant_override("separation", 8)
	info.add_child(name_zeile)
	name_zeile.add_child(name_label)
	# Notiz: Kennzeichen an der Karte, voller Text beim Drüberfahren.
	if not card.notiz.is_empty():
		name_zeile.add_child(_notiz_chip(card.notiz))
		panel.tooltip_text = Loc.pick("Notiz: %s", "Note: %s") % card.notiz
		if not name_label.tooltip_text.is_empty():
			name_label.tooltip_text += "\n\n" + panel.tooltip_text

	var detail := Label.new()
	var modifier_names: Array[String] = []
	for id in card.modifier_ids:
		var modifier := EnemyLibrary.get_modifier(id)
		if modifier != null:
			modifier_names.append(modifier.display_name)
	var detail_parts: Array[String] = []
	# Erste Karten haben keine Eliten (auch alte Karten mit Merkmalen).
	if not modifier_names.is_empty() and card.tier >= EnemyFactory.ELITE_AB_STUFE:
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
		# Echtes Boss-Level: Kartenstufe + tiefste Ebene + Karten-Rarität +
		# Legacy (Spieltest 2026-10-23: „Boss-Stufe 19“, der Boss war Lv25).
		legend.text = Loc.pick("LEGENDÄR — Boss Lv %d (+2 pro Abschluss, mehr Beute & XP)",
			"LEGENDARY — boss Lv %d (+2 per completion, more loot & XP)") \
			% (card.tier + card.floor_count - 1 + card.rarity_level_bonus() + card.legacy_boss_bonus())
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
	if card.sonderregel != &"":
		var regel_label := Label.new()
		regel_label.text = "%s: %s" % [Sonderregeln.name_von(card), Sonderregeln.text_von(card)]
		regel_label.add_theme_font_size_override("font_size", 11)
		regel_label.modulate = Color(0.6, 0.9, 1.0)
		regel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(regel_label)

	# Favorit-Stern: Favoriten stehen oben und sind vor dem Löschen geschützt.
	var stern := Button.new()
	stern.text = "★" if card.favorit else "☆"
	stern.custom_minimum_size = Vector2(44, 0)
	stern.tooltip_text = Loc.pick("Favorit: steht oben, kann nicht gelöscht werden", "Favorite: listed first, can't be deleted")
	if card.favorit:
		stern.add_theme_color_override("font_color", UiTheme.GOLD)
	stern.pressed.connect(func() -> void:
		card.favorit = not card.favorit
		GameState.save_game()
		_refresh())
	row.add_child(stern)

	var notiz := Button.new()
	notiz.text = Loc.pick("Notiz", "Note")
	notiz.tooltip_text = Loc.pick("Eigene Notiz zu dieser Karte (erscheint beim Drüberfahren)",
		"Your own note for this map (shown on hover)")
	notiz.pressed.connect(_notiz_bearbeiten.bind(card))
	row.add_child(notiz)

	var enter := Button.new()
	enter.text = Loc.pick("Betreten", "Enter")
	if _betreten_karte == card and not GameState.current_run.is_empty():
		enter.text = Loc.pick("Laufenden Dungeon verwerfen?", "Discard the current dungeon?")
	enter.pressed.connect(_on_enter.bind(card))
	row.add_child(enter)

	var verschieben := Button.new()
	if _ansicht == &"lager":
		verschieben.text = Loc.pick("Archivieren", "Archive")
		verschieben.disabled = GameState.card_archive.size() >= GameState.ARCHIV_PLAETZE
		verschieben.tooltip_text = Loc.pick("Ins Archiv (gibt den Lagerplatz frei)", "To the archive (frees the storage slot)")
		verschieben.pressed.connect(func() -> void:
			if GameState.archive_card(card):
				GameState.save_game()
			_refresh())
	else:
		verschieben.text = Loc.pick("Ins Lager", "To storage")
		verschieben.disabled = GameState.cards.size() >= GameState.card_capacity
		verschieben.pressed.connect(func() -> void:
			if GameState.unarchive_card(card):
				GameState.save_game()
			_refresh())
	row.add_child(verschieben)

	var delete := Button.new()
	delete.text = Loc.pick("Löschen", "Delete")
	delete.disabled = card.favorit
	if card.favorit:
		delete.tooltip_text = Loc.pick("Favoriten zuerst entsternen", "Unstar favorites first")
	delete.pressed.connect(_on_delete.bind(card))
	row.add_child(delete)
	return panel


## Goldener Chip „Notiz: …“ (gekürzt) — so sieht man auf einen Blick,
## auf welchen Karten Notizen stehen.
static func _notiz_chip(text: String) -> Control:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(UiTheme.GOLD.r, UiTheme.GOLD.g, UiTheme.GOLD.b, 0.18)
	stil.border_color = UiTheme.GOLD
	stil.set_border_width_all(1)
	stil.set_corner_radius_all(5)
	stil.content_margin_left = 6
	stil.content_margin_right = 6
	chip.add_theme_stylebox_override("panel", stil)
	var label := Label.new()
	var kurz := text.replace("\n", " ")
	if kurz.length() > 40:
		kurz = kurz.left(38) + "…"
	label.text = Loc.pick("Notiz: %s", "Note: %s") % kurz
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", UiTheme.GOLD)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(label)
	return chip


## Notiz-Fenster: mehrzeilig bearbeiten, Speichern / Löschen / Abbrechen.
func _notiz_bearbeiten(card: DungeonCard) -> void:
	var ebene := CanvasLayer.new()
	ebene.layer = 85
	add_child(ebene)
	var dunkel := ColorRect.new()
	dunkel.color = Color(0, 0, 0, 0.6)
	dunkel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ebene.add_child(dunkel)
	var mitte := CenterContainer.new()
	mitte.theme = UiTheme.get_theme()
	mitte.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ebene.add_child(mitte)
	var panel := PanelContainer.new()
	mitte.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(Bildschirm.ueberschrift(Loc.pick("Notiz — %s", "Note — %s") % card.display_name))
	var feld := TextEdit.new()
	feld.text = card.notiz
	feld.placeholder_text = Loc.pick("z.B. „Hexenmeisterin als Boss — gut für Runen“",
		"e.g. \"Witch mistress boss — good for runes\"")
	feld.custom_minimum_size = Vector2(480, 140)
	feld.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(feld)
	var knoepfe := HBoxContainer.new()
	knoepfe.add_theme_constant_override("separation", 8)
	knoepfe.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(knoepfe)
	var schliessen := func(neu: String) -> void:
		card.notiz = neu.strip_edges()
		GameState.save_game()
		ebene.queue_free()
		_refresh()
	var loeschen := Button.new()
	loeschen.text = Loc.pick("Notiz löschen", "Delete note")
	loeschen.disabled = card.notiz.is_empty()
	loeschen.pressed.connect(func() -> void: schliessen.call(""))
	knoepfe.add_child(loeschen)
	var abbrechen := Button.new()
	abbrechen.text = Loc.pick("Abbrechen", "Cancel")
	abbrechen.pressed.connect(ebene.queue_free)
	knoepfe.add_child(abbrechen)
	var speichern := Button.new()
	speichern.text = Loc.pick("Speichern", "Save")
	speichern.pressed.connect(func() -> void: schliessen.call(feld.text))
	knoepfe.add_child(speichern)
	# Esc schließt nur das Notiz-Fenster (nicht das Kartenlager).
	var esc := Bildschirm.EscWaechter.new()
	esc.aktion = ebene.queue_free
	ebene.add_child(esc)
	feld.grab_focus.call_deferred()


## Vorschau: Gegnertypen, Boss-Kandidaten und Themen-Materialien der Karte —
## komplett deterministisch aus den Karten-Daten ableitbar.
func _card_preview(card: DungeonCard) -> String:
	var max_tier := card.tier + card.floor_count - 1  # tiefste Ebene
	var enemy_names: Array[String] = []
	var materials := {}
	for archetype in EnemyLibrary.archetypes_for_biome(card.biome, false, max_tier):
		# Alle Typen (früher nur die ersten 5 — Golem/Troll fehlten).
		enemy_names.append(archetype.display_name)
		var themed: StringName = LootGenerator.ARCHETYPE_MATERIALS.get(archetype.id, &"")
		if themed != &"" and themed != &"kraut":
			# Werkstoff in der Stufe, die auf dieser Karte droppt (Eisen … Sternen).
			var id := MaterialLibrary.werkstoff(themed, MaterialLibrary.stufe_fuer_karte(card.tier))
			materials[MaterialLibrary.display_name(id)] = true
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
