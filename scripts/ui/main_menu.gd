extends Control
## Altes Hub (scenes/main.tscn), seit Stufe b (2026-11-09) eine Weiche: die
## Stadt ist das Hub. Alle Wege „zurück ins Menü“ (Dungeon, Kampf,
## Kartenlager, Werkstatt, Co-op …) landen hier und werden weitergeleitet:
##   ohne Helden » Taverne (den ersten Helden erstellen),
##   Co-op-Gast » die bisherige Gast-Ansicht (Koop bleibt unverändert),
##   sonst » die begehbare Stadt.
## Die Gast-Ansicht: Holztafel-Spalte links, rechts das Lagerfeuer-Diorama,
## Meta-Knöpfe oben rechts, Slot und Version unten links.

## Breite der Knopfspalte; die Kulisse rückt um KULISSE_VERSATZ nach rechts.
const SPALTE_BREITE := 470
const KULISSE_VERSATZ := -1.75

const WORKSHOP_SCENE := "res://scenes/workshop/skill_workshop.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/dungeon_scene.tscn"
const INVENTORY_SCENE := "res://scenes/inventory/inventory_scene.tscn"
const CARDS_SCENE := "res://scenes/hub/card_storage.tscn"
const TAVERN_SCENE := "res://scenes/hub/tavern.tscn"
const LEXICON_SCENE := "res://scenes/hub/lexicon.tscn"
const TITLE_SCENE := "res://scenes/title.tscn"


## Wohin die Weiche führt ("" = hierbleiben: Gast-Ansicht).
static func weiche_ziel(party_leer: bool, gast: bool) -> String:
	if party_leer:
		return TAVERN_SCENE
	if gast:
		return ""
	return StadtSzene.STADT_SCENE


func _ready() -> void:
	theme = UiTheme.get_theme()
	var ziel := weiche_ziel(GameState.party.is_empty(), Net.is_guest())
	if not ziel.is_empty():
		get_tree().change_scene_to_file.call_deferred(ziel)
		return
	Music.play(&"menu")
	add_child(UiTheme.make_background(&"lager", false, KULISSE_VERSATZ))

	# Knopfspalte links, senkrecht mittig — das Diorama rechts bleibt frei.
	var spalte := CenterContainer.new()
	spalte.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	spalte.offset_left = Bildschirm.RAND * 2
	spalte.offset_right = Bildschirm.RAND * 2 + SPALTE_BREITE
	spalte.offset_top = Bildschirm.RAND
	spalte.offset_bottom = -Bildschirm.RAND
	add_child(spalte)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.custom_minimum_size = Vector2(SPALTE_BREITE - 2 * Bildschirm.RAND, 0)
	spalte.add_child(Bildschirm.tafel(box, Bildschirm.RAND))

	# Titel wie ins Holz geschnitten, darunter ein Messingfaden.
	var title := Bildschirm.fenster_titel("Infinit Dungeon")
	title.add_theme_font_size_override("font_size", 46)
	box.add_child(title)
	# Sanfter Titel-Puls — lebendig, ohne aufdringlich zu sein.
	var pulse := create_tween().set_loops()
	pulse.tween_property(title, "modulate:a", 0.8, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(title, "modulate:a", 1.0, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	box.add_child(HSeparator.new())

	var subtitle := Label.new()
	var total_level := 0
	for member in GameState.party:
		total_level += member.level
	var helden_wort := Loc.pick("Held" if GameState.party.size() == 1 else "Helden",
		"hero" if GameState.party.size() == 1 else "heroes")
	# Zwei feste Zeilen: frei umbrochen blieb ein „·“ am Zeilenende hängen
	# (Englisch: „Maps: 24/35 ·“ / „Mini medals: 7“).
	subtitle.text = Loc.pick("Gold: %d   ·   Party: %d %s, Ø Level %.0f\nKarten: %d/%d   ·   Mini-Medaillen: %d",
		"Gold: %d   ·   Party: %d %s, avg. level %.0f\nMaps: %d/%d   ·   Mini medals: %d") % [
		GameState.gold, GameState.party.size(), helden_wort,
		float(total_level) / maxi(1, GameState.party.size()),
		GameState.cards.size(), GameState.card_capacity, GameState.medals]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(UiTheme.TEXT, 0.72))
	box.add_child(subtitle)

	# Cleane Mitte: nur der Spiel-Loop. Speichern und der Weg zum
	# Titelbildschirm (Spielstände, Co-op, Optionen, Beenden) sitzen in der
	# Ecke oben rechts; Sprache wohnt in den Optionen;
	# Taverne/Händler/Schmiede liegen am begehbaren Stadtplatz.
	if Net.is_guest():
		# Co-op-Gast: Karten öffnet NUR der Host — der Gast bekommt beim
		# Öffnen automatisch das „Karte von X — joinen“-Angebot.
		var guest_note := Label.new()
		guest_note.text = Loc.pick("Co-op-Gast: Der Host öffnet die Karten —\ndu bekommst automatisch das Beitritts-Angebot.",
			"Co-op guest: the host opens the maps —\nyou automatically get the join offer.")
		guest_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		guest_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		guest_note.add_theme_color_override("font_color", UiTheme.FOKUS)
		box.add_child(guest_note)
	if not GameState.current_run.is_empty() and not GameState.coop_guest_run \
			and not Net.is_guest():
		_menu_button(box, Loc.pick("Dungeon fortsetzen", "Resume dungeon"), DUNGEON_SCENE)
	if not Net.is_guest():
		_menu_button(box, Loc.pick("Kartenlager (%d/%d)", "Map storage (%d/%d)")
			% [GameState.cards.size(), GameState.card_capacity], CARDS_SCENE)
	_menu_button(box, GameState.stadt_text(GameState.abholbar_anzahl()), StadtSzene.STADT_SCENE)
	_menu_button(box, Loc.pick("Skill-Werkstatt", "Skill workshop"), WORKSHOP_SCENE)
	_menu_button(box, Loc.pick("Ausrüstung & Inventar", "Equipment & inventory"),
		INVENTORY_SCENE)
	_menu_button(box, Loc.pick("Lexikon", "Encyclopedia"), LEXICON_SCENE)

	# Ecken-Leiste oben rechts (nach der Mitte eingehängt, damit die
	# Tastatur-Navigation zuerst im Spiel-Loop landet).
	_ecken_leiste(true)

	# Dezente Fußzeile: aktiver Spielstand-Slot + Version (unten links).
	var slot_label := Label.new()
	slot_label.text = Loc.pick("Spielstand-Slot %d", "Save slot %d") % SaveManager.active_slot \
		+ (Loc.pick(" (Datei nicht lesbar, Speichern gesperrt)",
			" (file unreadable, saving locked)") if GameState.slot_gesperrt else "") \
		+ "   ·   v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	slot_label.add_theme_font_size_override("font_size", 11)
	slot_label.add_theme_color_override("font_color", Color(UiTheme.TEXT, 0.5))
	slot_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)  # vor add_child
	slot_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	slot_label.offset_left = Bildschirm.RAND
	slot_label.offset_top = -Bildschirm.RAND
	slot_label.offset_bottom = -Bildschirm.RAND
	add_child(slot_label)

	# Autosave: jeder Aufenthalt im Hub sichert den aktuellen Fortschritt —
	# nur wenn sich etwas geändert hat (Start und Laden schreiben nichts).
	GameState.autosave()
	UiTheme.focus_first_button(self)

	_lade_hinweis_zeigen()


## Meldung vom Laden (Sicherung geladen / Datei unlesbar), einmal anzeigen.
func _lade_hinweis_zeigen() -> void:
	var text := GameState.lade_hinweis_text()
	if text.is_empty():
		return
	GameState.lade_hinweis = {}
	UiTheme.show_hint(self, Loc.pick("Spielstand", "Save game"), text)


func _menu_button(box: VBoxContainer, label: String, scene_path: String) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(340, 50)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(scene_path))
	box.add_child(button)


## Ecken-Leiste oben rechts: zurück zum Titelbildschirm (dort Spielstände,
## Co-op, Optionen, Beenden) und — mit fertiger Party — Speichern.
func _ecken_leiste(mit_speichern: bool) -> void:
	var corner := HBoxContainer.new()
	corner.add_theme_constant_override("separation", 6)
	add_child(corner)
	corner.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# BEIDE horizontalen Offsets auf denselben Punkt setzen — die Leiste
	# wächst dann von der rechten Kante nach links (sonst rutscht sie
	# durch die negative Breite an den linken Rand).
	corner.offset_top = Bildschirm.RAND
	corner.offset_left = -Bildschirm.RAND
	corner.offset_right = -Bildschirm.RAND

	if mit_speichern:
		var save_button := _corner_button(Loc.pick("Speichern", "Save"))
		save_button.pressed.connect(func() -> void:
			var ok := GameState.save_game()
			save_button.text = Loc.pick("Gespeichert!", "Saved!") if ok \
				else Loc.pick("Fehler!", "Failed!")
			# Tween am Knopf statt SceneTree-Timer: stirbt mit dem Knopf, wenn
			# die Szene vorher wechselt („Lambda capture … was freed“).
			var zurueck := save_button.create_tween()
			zurueck.tween_interval(1.5)
			zurueck.tween_callback(func() -> void:
				save_button.text = Loc.pick("Speichern", "Save")))
		corner.add_child(save_button)

	var title_button := _corner_button(Loc.pick("Hauptmenü", "Main menu"))
	title_button.pressed.connect(func() -> void:
		GameState.ui_return_scene = ""
		get_tree().change_scene_to_file(TITLE_SCENE))
	corner.add_child(title_button)


## Kleine, dezente Buttons für die Ecken-Leiste (Meta-Funktionen).
func _corner_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 34)
	return button
