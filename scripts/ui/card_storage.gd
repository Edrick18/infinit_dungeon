extends Control
## Kartenlager: gesammelte Dungeon-Karten ansehen, betreten, löschen,
## Lager gegen Gold erweitern. Der Einstiegspunkt in jeden Dungeon-Run.
## Favoriten (★) stehen oben und sind vor dem Löschen geschützt; das Archiv
## bewahrt besondere Farm-Karten (Boss, Gegner, Affixe) außerhalb des Lagers auf.
## Ganz oben steht immer der Streifzug: keine gespeicherte Karte, sondern bei
## jedem Betreten eine neue Zufallskarte auf dem Party-Durchschnitt — so kann
## man sich mit leerem Lager nie aussperren.

const MAIN_SCENE := "res://scenes/main.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/dungeon_scene.tscn"

var _gold_label: Label
var _capacity_label: Label
var _expand_button: Button
var _card_list: VBoxContainer
## Karte, für die „Betreten“ bei laufendem Dungeon schon einmal angeklickt wurde.
var _betreten_karte: DungeonCard = null
## Karte, für die „Löschen“ schon einmal gedrückt wurde (zweiter Klick löscht),
## und ihr Knopf (wird zurückgesetzt, wenn eine andere Karte fragt).
var _loeschen_karte: DungeonCard = null
var _loeschen_knopf: Button = null
var _ansicht := &"lager"  ## &"lager" oder &"archiv"
var _tab_lager: Button
var _tab_archiv: Button
var _studio: PortraitStudio  ## rendert die Biom-Miniaturen der Karten
## Streifzug-Zeile (über der Liste, nur in der Lager-Ansicht) und ob
## „Betreten“ dort bei laufendem Dungeon schon einmal angeklickt wurde.
var _streifzug_box: VBoxContainer
var _betreten_streifzug := false
## Einstiegs-Ebene des Knopfs, der zuletzt nachgefragt hat (0 oder Fortschritt).
var _betreten_ebene := 0
## „Alle löschen“: erster Klick fragt nur nach (wie das Einzel-Löschen).
var _alle_loeschen: Button
var _alle_loeschen_gefragt := false


func _ready() -> void:
	theme = UiTheme.get_theme()
	_studio = PortraitStudio.new()
	add_child(_studio)
	Music.play(&"menu")
	_build_layout()
	_refresh()
	UiTheme.focus_first_button(self)


## ab_ebene: 0 = Ebene 1, sonst der gesicherte Fortschritt der Karte.
func _on_enter(card: DungeonCard, ab_ebene := 0) -> void:
	if Net.is_guest():
		# Co-op-Gast: eigene Karten sind waehrend der Session gesperrt.
		Sfx.play(&"fehler")
		return
	# Ein laufender Dungeon geht beim Betreten einer Karte verloren — erst der
	# zweite Klick (auf denselben Knopf) bestätigt.
	if not GameState.current_run.is_empty() and (_betreten_karte != card or _betreten_ebene != ab_ebene):
		_betreten_karte = card
		_betreten_ebene = ab_ebene
		_betreten_streifzug = false
		_refresh()
		return
	GameState.start_run(card, ab_ebene)
	get_tree().change_scene_to_file(DUNGEON_SCENE)


## Streifzug: würfelt erst beim Betreten — jede Runde eine neue Karte. Ein
## laufender Dungeon geht dabei verloren, deshalb wie oben zwei Klicks.
func _on_streifzug() -> void:
	if Net.is_guest():
		Sfx.play(&"fehler")
		return
	if not GameState.current_run.is_empty() and not _betreten_streifzug:
		_betreten_karte = null
		_betreten_streifzug = true
		_refresh()
		_streifzug_fokus()
		return
	_betreten_streifzug = false
	GameState.start_run(CardFactory.make_streifzug_card(GameState.average_party_level()))
	get_tree().change_scene_to_file(DUNGEON_SCENE)


func _streifzug_fokus() -> void:
	# Nach _refresh hängt die alte Zeile noch (queue_free) — die neue nehmen.
	for zeile in _streifzug_box.get_children():
		if zeile.is_queued_for_deletion():
			continue
		var knopf := UiTheme._find_first_button(zeile)
		if knopf != null:
			knopf.grab_focus.call_deferred()
		return


## Alle Lagerkarten außer Favoriten löschen — erst der zweite Klick löscht.
## Das Archiv bleibt unberührt.
func _on_alle_loeschen() -> void:
	if not _alle_loeschen_gefragt:
		_loeschen_zuruecksetzen()
		_alle_loeschen_gefragt = true
		_alle_loeschen.text = Loc.pick("Wirklich %s löschen?", "Really delete %s?") \
			% Loc.anzahl(_loeschbare_karten(), "Karte", "Karten", "map", "maps")
		return
	_alle_loeschen_gefragt = false
	_betreten_karte = null
	GameState.delete_all_cards()
	GameState.save_game()
	Sfx.play(&"bestaetigen")
	_refresh()
	# Der Knopf ist jetzt gesperrt: Fokus auf den Streifzug.
	_streifzug_fokus()


func _loeschbare_karten() -> int:
	var anzahl := 0
	for card in GameState.cards:
		if not card.favorit:
			anzahl += 1
	return anzahl


func _alle_loeschen_zuruecksetzen() -> void:
	_alle_loeschen_gefragt = false
	if _alle_loeschen != null:
		_alle_loeschen.text = Loc.pick("Alle löschen", "Delete all")


## Endgültig — erst der zweite Klick löscht. Der erste ändert nur den
## Knopftext (kein Neuaufbau: der Tastatur-Fokus bleibt auf dem Knopf).
func _on_delete(card: DungeonCard, knopf: Button) -> void:
	if _loeschen_karte != card:
		_loeschen_zuruecksetzen()
		_alle_loeschen_zuruecksetzen()
		_loeschen_karte = card
		_loeschen_knopf = knopf
		knopf.text = Loc.pick("Wirklich löschen?", "Really delete?")
		return
	_betreten_karte = null
	_loeschen_karte = null
	_loeschen_knopf = null
	var zeile := 0
	for i in _card_list.get_child_count():
		if _card_list.get_child(i).get_meta(&"karte", null) == card:
			zeile = i
	GameState.delete_card(card)
	GameState.save_game()
	Sfx.play(&"bestaetigen")
	_refresh()
	_fokus_auf_zeile(zeile)


func _loeschen_zuruecksetzen() -> void:
	if _loeschen_knopf != null and is_instance_valid(_loeschen_knopf):
		_loeschen_knopf.text = Loc.pick("Löschen", "Delete")
	_loeschen_karte = null
	_loeschen_knopf = null


## Nach dem Löschen: Fokus auf die Zeile, die jetzt an derselben Stelle steht.
func _fokus_auf_zeile(index: int) -> void:
	var zeilen: Array[Node] = []
	for kind in _card_list.get_children():
		if not kind.is_queued_for_deletion() and kind.has_meta(&"karte"):
			zeilen.append(kind)
	if zeilen.is_empty():
		UiTheme.focus_first_button(self)
		return
	var ziel := UiTheme._find_first_button(zeilen[clampi(index, 0, zeilen.size() - 1)])
	if ziel != null:
		ziel.grab_focus.call_deferred()


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
		_betreten_karte = null
		_betreten_streifzug = false
		_refresh())
	tabs.add_child(_tab_lager)
	_tab_archiv = Button.new()
	_tab_archiv.tooltip_text = Loc.pick("Besondere Karten aufbewahren, ohne Lagerplatz zu belegen — betreten geht auch von hier.",
		"Keep special maps without using storage slots — you can enter them from here too.")
	_tab_archiv.pressed.connect(func() -> void:
		_ansicht = &"archiv"
		_betreten_karte = null
		_betreten_streifzug = false
		_refresh())
	tabs.add_child(_tab_archiv)
	var luecke := Control.new()
	luecke.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(luecke)
	_alle_loeschen = Button.new()
	UiTheme.gefahr(_alle_loeschen)
	_alle_loeschen.tooltip_text = Loc.pick("Löscht alle Karten im Lager außer Favoriten (★). Das Archiv bleibt.",
		"Deletes every map in storage except favorites (★). The archive stays.")
	_alle_loeschen.pressed.connect(_on_alle_loeschen)
	tabs.add_child(_alle_loeschen)
	_streifzug_box = VBoxContainer.new()
	b.inhalt.add_child(_streifzug_box)
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

	_loeschen_karte = null
	_loeschen_knopf = null
	_alle_loeschen_zuruecksetzen()
	_alle_loeschen.visible = _ansicht == &"lager"
	_alle_loeschen.disabled = _loeschbare_karten() == 0
	for child in _streifzug_box.get_children():
		child.queue_free()
	_streifzug_box.visible = _ansicht == &"lager"
	if _ansicht == &"lager":
		_streifzug_box.add_child(_make_streifzug_row())
	for child in _card_list.get_children():
		child.queue_free()
	var liste: Array[DungeonCard] = GameState.cards if _ansicht == &"lager" else GameState.card_archive
	if liste.is_empty():
		var empty := Label.new()
		empty.text = Loc.pick("Keine Karten im Lager — schließe Dungeons ab, um neue zu erhalten.", "No maps in storage — complete dungeons to earn new ones.") if _ansicht == &"lager" \
			else Loc.pick("Das Archiv ist leer — „Archivieren“ legt eine Karte hier ab.", "The archive is empty — \"Archive\" puts a map here.")
		empty.modulate = UiTheme.BLASS
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


## Feste Streifzug-Zeile: kein Stern, keine Notiz, nicht archivier- oder
## löschbar — nur Betreten. Stufe = aktueller Party-Durchschnitt.
func _make_streifzug_row() -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = Loc.pick("Streifzug  —  Stufe %d (Party-Durchschnitt), Ort zufällig",
		"Foray  —  tier %d (party average), random location") % GameState.average_party_level()
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(name_label)
	var detail := Label.new()
	detail.text = Loc.pick("Jedes Betreten würfelt eine neue Karte. Belegt keinen Lagerplatz, kann nicht gelöscht werden.",
		"Every entry rolls a new map. Uses no storage slot, can't be deleted.")
	detail.add_theme_font_size_override("font_size", 11)
	detail.modulate = UiTheme.BLASS
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail)
	var enter := Button.new()
	enter.text = Loc.pick("Betreten", "Enter")
	if _betreten_streifzug and not GameState.current_run.is_empty():
		enter.text = Loc.pick("Laufenden Dungeon verwerfen?", "Discard the current dungeon?")
	enter.pressed.connect(_on_streifzug)
	row.add_child(enter)
	return panel


func _make_card_row(card: DungeonCard) -> Control:
	var panel := PanelContainer.new()
	panel.set_meta(&"karte", card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)
	# Biom-Miniatur (Dungeon-Kulisse im Kleinen) — der Ort auf einen Blick.
	row.add_child(UiHolz.icon(VorratIcons.biom(_studio, card.biome), 60))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_label := Label.new()
	# Kopf wie in der Belohnungswahl: „[LEGACY] [Episch] Name“ (CardFactory.karten_kopf).
	name_label.text = Loc.pick("%s  —  Stufe %d, %s", "%s  —  tier %d, %s") % [
		CardFactory.karten_kopf(card), card.tier, CardFactory.biome_name(card.biome)]
	name_label.modulate = LootGenerator.RARITY_COLORS[card.card_rarity]
	if card.card_rarity != Enums.Rarity.COMMON:
		var seltenheit := LootGenerator.rarity_name(card.card_rarity)
		name_label.tooltip_text = Loc.pick(
			"%s-Karte: Gegner +%s, Beute ×%s, XP ×%s, bessere Truhen",
			"%s map: enemies +%s, loot ×%s, XP ×%s, better chests") % [
			seltenheit, Loc.anzahl(card.rarity_level_bonus(), "Stufe", "Stufen", "tier", "tiers"),
			Loc.zahl(card.rarity_loot_mult(), 2), Loc.zahl(card.rarity_xp_mult(), 2)]
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
	var name_zeile := HBoxContainer.new()
	name_zeile.add_theme_constant_override("separation", 8)
	info.add_child(name_zeile)
	# Darf umbrechen: mit Biom-Bild und Notiz-Chip wird die Zeile sonst
	# breiter als der Bildschirm (Knöpfe rechts fielen heraus).
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		detail_parts.append(Loc.pick("%d Bosse besiegt", "%d bosses defeated") % card.times_completed)
	if card.fortschritt_ebene > 0:
		detail_parts.append(Loc.pick("Fortschritt: Ebene %d", "Progress: floor %d") % (card.fortschritt_ebene + 1))
	detail.text = "  ·  ".join(detail_parts) if not detail_parts.is_empty() else Loc.pick("Noch unerkundet", "Unexplored")
	detail.add_theme_font_size_override("font_size", 11)
	detail.modulate = UiTheme.BLASS
	info.add_child(detail)

	# Karten-Vorschau (alles deterministisch): welche Gegnertypen, welche
	# Boss-Kandidaten und welche Themen-Materialien hier warten.
	var preview := Label.new()
	preview.text = _card_preview(card)
	preview.add_theme_font_size_override("font_size", 11)
	preview.modulate = Color(UiTheme.INFO, 0.85)
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(preview)

	# Legendäre Karte: der Legacy-Boss levelt mit jedem Abschluss.
	if card.legendary:
		var legend := Label.new()
		# Echtes Boss-Level: Kartenstufe + tiefste Ebene + Karten-Rarität +
		# Legacy (Spieltest 2026-10-23: „Boss-Stufe 19“, der Boss war Lv25).
		legend.text = Loc.pick("LEGENDÄR — erster Boss Lv %d (+2 pro besiegtem Boss, mehr Beute & XP)",
			"LEGENDARY — first boss Lv %d (+2 per boss defeated, more loot & XP)") \
			% CardFactory.legacy_boss_level(card)
		legend.add_theme_font_size_override("font_size", 11)
		legend.modulate = LootGenerator.RARITY_COLORS[Enums.Rarity.LEGENDARY]
		info.add_child(legend)

	# Karten-Affixe: das Risiko/Belohnungs-Profil dieser Karte (gold hervorgehoben).
	if not card.card_affix_ids.is_empty():
		var affix_label := Label.new()
		affix_label.text = "  ·  ".join(CardFactory.affix_texte(card))
		affix_label.add_theme_font_size_override("font_size", 11)
		affix_label.modulate = UiTheme.BELOHNUNG
		info.add_child(affix_label)
	if card.sonderregel != &"":
		var regel_label := Label.new()
		regel_label.text = Sonderregeln.zeile(card)
		regel_label.add_theme_font_size_override("font_size", 11)
		regel_label.modulate = UiTheme.INFO
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
		_betreten_karte = null
		card.favorit = not card.favorit
		GameState.save_game()
		_refresh())
	row.add_child(stern)

	var notiz := Button.new()
	notiz.text = Loc.pick("Notiz", "Note")
	notiz.tooltip_text = Loc.pick("Eigene Notiz zu dieser Karte (erscheint beim Drüberfahren)",
		"Your own note for this map (shown on hover)")
	notiz.pressed.connect(func() -> void:
		_loeschen_zuruecksetzen()
		_notiz_bearbeiten(card))
	row.add_child(notiz)

	# Einstieg: Ebene 1 oder (mit Fortschritt) direkt nach dem tiefsten Boss.
	var einstiege := VBoxContainer.new()
	einstiege.alignment = BoxContainer.ALIGNMENT_CENTER
	einstiege.add_theme_constant_override("separation", 4)
	row.add_child(einstiege)
	var ebenen := [0]
	if card.fortschritt_ebene > 0:
		ebenen.append(card.fortschritt_ebene)
	for ab in ebenen:
		var enter := Button.new()
		enter.text = Loc.pick("Betreten", "Enter") if ab == 0 \
			else Loc.pick("Ab Ebene %d", "From floor %d") % (ab + 1)
		if _betreten_karte == card and _betreten_ebene == ab and not GameState.current_run.is_empty():
			enter.text = Loc.pick("Laufenden Dungeon verwerfen?", "Discard the current dungeon?")
		enter.pressed.connect(_on_enter.bind(card, ab))
		einstiege.add_child(enter)

	var verschieben := Button.new()
	if _ansicht == &"lager":
		verschieben.text = Loc.pick("Archivieren", "Archive")
		verschieben.disabled = GameState.card_archive.size() >= GameState.ARCHIV_PLAETZE
		verschieben.tooltip_text = Loc.pick("Ins Archiv (gibt den Lagerplatz frei)", "To the archive (frees the storage slot)")
		verschieben.pressed.connect(func() -> void:
			_betreten_karte = null
			if GameState.archive_card(card):
				GameState.save_game()
			_refresh())
	else:
		verschieben.text = Loc.pick("Ins Lager", "To storage")
		verschieben.disabled = GameState.cards.size() >= GameState.card_capacity
		verschieben.pressed.connect(func() -> void:
			_betreten_karte = null
			if GameState.unarchive_card(card):
				GameState.save_game()
			_refresh())
	row.add_child(verschieben)

	var delete := Button.new()
	delete.text = Loc.pick("Löschen", "Delete")
	# Gefahr-Knopf: Schrift in Warnrot — nicht mit „Betreten“ zu verwechseln.
	UiTheme.gefahr(delete)
	delete.disabled = card.favorit
	if card.favorit:
		delete.tooltip_text = Loc.pick("Favoriten zuerst entsternen", "Unstar favorites first")
	delete.pressed.connect(func() -> void: _on_delete(card, delete))
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
	dunkel.color = Color(UiTheme.KERBE, 0.6)
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
	# Tastatur bleibt im Fenster; jeder Schließweg gibt die Sperre frei.
	var sperre := {"freigeben": Callable()}
	var zu := func() -> void:
		if (sperre["freigeben"] as Callable).is_valid():
			(sperre["freigeben"] as Callable).call()
		sperre["freigeben"] = Callable()
		ebene.queue_free()
	var schliessen := func(neu: String) -> void:
		card.notiz = neu.strip_edges()
		GameState.save_game()
		zu.call()
		_refresh()
	var loeschen := Button.new()
	loeschen.text = Loc.pick("Notiz löschen", "Delete note")
	loeschen.disabled = card.notiz.is_empty()
	loeschen.pressed.connect(func() -> void: schliessen.call(""))
	knoepfe.add_child(loeschen)
	var abbrechen := Button.new()
	abbrechen.text = Loc.pick("Abbrechen (Esc)", "Cancel (Esc)")
	abbrechen.pressed.connect(zu)
	knoepfe.add_child(abbrechen)
	var speichern := Button.new()
	speichern.text = Loc.pick("Speichern (Strg+Enter)", "Save (Ctrl+Enter)")
	speichern.pressed.connect(func() -> void: schliessen.call(feld.text))
	knoepfe.add_child(speichern)
	# Im Textfeld landen E, WASD und Enter als Text: Strg+Enter speichert,
	# Tab springt zu „Speichern“ (statt einzurücken).
	feld.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventKey and event.pressed):
			return
		var taste := event as InputEventKey
		if taste.ctrl_pressed and taste.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			feld.accept_event()
			schliessen.call(feld.text)
		elif taste.keycode == KEY_TAB and not taste.ctrl_pressed:
			feld.accept_event()
			(abbrechen if taste.shift_pressed else speichern).grab_focus())
	# Esc schließt nur das Notiz-Fenster (nicht das Kartenlager).
	var esc := Bildschirm.EscWaechter.new()
	esc.aktion = zu
	ebene.add_child(esc)
	sperre["freigeben"] = UiTheme.fokus_einsperren(mitte)
	feld.grab_focus.call_deferred()


## Vorschau: Gegnertypen, Boss-Kandidaten und Themen-Materialien der Karte —
## komplett deterministisch aus den Karten-Daten ableitbar.
func _card_preview(card: DungeonCard) -> String:
	# Bis zur Gegnerstufe des gesicherten Fortschritts (mindestens Abschnitt 1).
	var max_tier := DungeonGenerator.gegner_stufe(card, card.fortschritt_ebene) - card.rarity_level_bonus()
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
