extends Control
## Hauptmenü: Spiel-Loop als Holztafel-Spalte links, rechts daneben frei das
## Lagerfeuer-Diorama mit der eigenen Party über dem Sternen-Nebel
## (MenueKulisse, seitlich versetzt). Meta-Knöpfe oben rechts, Slot und
## Version unten links — Ränder wie die Bildschirm-Vorlage (Bildschirm.RAND),
## aber ohne Kopfzeile, denn hier gibt es kein Zurück.

## Breite der Knopfspalte; die Kulisse rückt um KULISSE_VERSATZ nach rechts.
const SPALTE_BREITE := 470
const KULISSE_VERSATZ := -1.75

const WORKSHOP_SCENE := "res://scenes/workshop/skill_workshop.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/dungeon_scene.tscn"
const INVENTORY_SCENE := "res://scenes/inventory/inventory_scene.tscn"
const CARDS_SCENE := "res://scenes/hub/card_storage.tscn"
const TAVERN_SCENE := "res://scenes/hub/tavern.tscn"
const LEXICON_SCENE := "res://scenes/hub/lexicon.tscn"
const OPTIONS_SCENE := "res://scenes/hub/options.tscn"
const COOP_SCENE := "res://scenes/hub/coop.tscn"
const SAVES_SCENE := "res://scenes/hub/saves.tscn"


func _ready() -> void:
	theme = UiTheme.get_theme()
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

	# Frischer Start: erst den ersten Helden erstellen (Startwaffe wählen!),
	# der Rest der Party wird später kostenlos in der Taverne angeheuert.
	if GameState.party.is_empty():
		_build_hero_creation(box)
		_lade_hinweis_zeigen()
		return

	var subtitle := Label.new()
	var total_level := 0
	for member in GameState.party:
		total_level += member.level
	var helden_wort := Loc.pick("Held" if GameState.party.size() == 1 else "Helden",
		"hero" if GameState.party.size() == 1 else "heroes")
	subtitle.text = Loc.pick("Gold: %d   ·   Party: %d %s, Ø Level %.0f   ·   Karten: %d/%d   ·   Mini-Medaillen: %d",
		"Gold: %d   ·   Party: %d %s, avg. level %.0f   ·   Maps: %d/%d   ·   Mini medals: %d") % [
		GameState.gold, GameState.party.size(), helden_wort,
		float(total_level) / maxi(1, GameState.party.size()),
		GameState.cards.size(), GameState.card_capacity, GameState.medals]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 13)
	subtitle.add_theme_color_override("font_color", Color(UiTheme.TEXT, 0.72))
	box.add_child(subtitle)

	# Cleane Mitte: nur der Spiel-Loop. Alles Meta (Co-op, Speichern,
	# Optionen) sitzt in der Ecke oben rechts; Sprache wohnt in den Optionen;
	# Taverne/Händler/Schmiede sind EINE Stadt mit Tabs.
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
	_menu_button(box, GameState.stadt_text(GameState.abholbar_anzahl()), TAVERN_SCENE)
	_menu_button(box, Loc.pick("Skill-Werkstatt", "Skill workshop"), WORKSHOP_SCENE)
	_menu_button(box, Loc.pick("Ausrüstung & Inventar", "Equipment & inventory"),
		INVENTORY_SCENE)
	_menu_button(box, Loc.pick("Lexikon", "Encyclopedia"), LEXICON_SCENE)

	# Ecken-Leiste oben rechts (nach der Mitte eingehängt, damit die
	# Tastatur-Navigation zuerst im Spiel-Loop landet).
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

	var coop_button := _corner_button(Loc.pick("Co-op", "Co-op"))
	coop_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(COOP_SCENE))
	corner.add_child(coop_button)

	var saves_button := _corner_button(Loc.pick("Spielstände", "Save games"))
	saves_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(SAVES_SCENE))
	corner.add_child(saves_button)

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

	var options_button := _corner_button(Loc.pick("Optionen", "Options"))
	options_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(OPTIONS_SCENE))
	corner.add_child(options_button)

	# Spiel beenden: speichert vorher (Co-op-Verbindung wird sauber getrennt).
	var quit_button := _corner_button(Loc.pick("Beenden", "Quit"))
	quit_button.pressed.connect(func() -> void:
		GameState.save_game()
		if Net.is_online():
			Net.stop()
		get_tree().quit())
	corner.add_child(quit_button)

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

	# Autosave: jeder Aufenthalt im Hub sichert den aktuellen Fortschritt.
	GameState.save_game()
	UiTheme.focus_first_button(self)

	# Onboarding: der Spiel-Loop in einem Absatz (einmal pro Spielstand).
	if GameState.first_time("menu"):
		UiTheme.show_hint(self, Loc.pick("Willkommen in Infinit Dungeon!",
			"Welcome to Infinit Dungeon!"), Loc.pick(
			"Dein Loop: Im KARTENLAGER eine Dungeon-Karte öffnen, drinnen kämpfen und looten, den Boss auf der Boss-Ebene hinter den normalen Ebenen besiegen — die Belohnungskarte führt immer tiefer.\n\nZwischendurch: In der STADT einkaufen und schmieden, in der SKILL-WERKSTATT eigene Skills aus Bausteinen bauen, unter AUSRÜSTUNG Beute anlegen und Statuspunkte verteilen.",
			"Your loop: open a dungeon map in MAP STORAGE, fight and loot inside, defeat the boss on the boss floor behind the regular floors — the reward map takes you ever deeper.\n\nIn between: shop and forge in TOWN, build your own skills from blocks in the SKILL WORKSHOP, equip loot and spend stat points under EQUIPMENT."))
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


## Kleine, dezente Buttons für die Ecken-Leiste (Meta-Funktionen).
func _corner_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 34)
	return button


## Erster Spielstart: einen Helden wählen + Starter-Kit (= Startwaffe & Skill).
func _build_hero_creation(box: VBoxContainer) -> void:
	var intro := Label.new()
	intro.text = Loc.pick("Erstelle deinen ersten Helden.\nWeitere Gefährten warten kostenlos in der Taverne.",
		"Create your first hero.\nMore companions await for free at the tavern.")
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_color_override("font_color", Color(UiTheme.TEXT, 0.78))
	box.add_child(intro)

	box.add_theme_constant_override("separation", 10)  # Erstellung ist höher als das Menü
	var portrait := FigurenVorschau.new(Vector2i(130, 150))
	var portrait_center := CenterContainer.new()
	portrait_center.add_child(portrait)
	box.add_child(portrait_center)

	# Freier Name (Vorschlag vorbelegt) + wählbares Porträt.
	var name_edit := LineEdit.new()
	name_edit.custom_minimum_size = Vector2(340, 44)
	name_edit.text = HeroLibrary.HERO_NAMES[0]
	name_edit.max_length = 24
	name_edit.placeholder_text = Loc.pick("Name des Helden", "Hero name")
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_edit)

	var studio := PortraitStudio.new()
	add_child(studio)
	var portrait_select := FigurenBau.farb_auswahl(studio)
	portrait_select.custom_minimum_size = Vector2(340, 44)
	portrait_select.select(0)
	box.add_child(portrait_select)

	# Startwaffe wählen (keine Klasse!) — mit den echten Waffenwerten.
	var kit_select := OptionButton.new()
	kit_select.custom_minimum_size = Vector2(340, 44)
	for loadout_id in HeroLibrary.STARTER_LOADOUTS:
		kit_select.add_item(HeroLibrary.loadout_label(loadout_id))
		kit_select.set_item_metadata(kit_select.item_count - 1, loadout_id)
	kit_select.select(0)
	box.add_child(kit_select)
	var vorschau_zeigen := func(_index := 0) -> void:
		portrait.zeige(FigurenBau.starter_held(
			portrait_select.get_item_metadata(portrait_select.selected),
			kit_select.get_item_metadata(kit_select.selected)))
	portrait_select.item_selected.connect(vorschau_zeigen)
	kit_select.item_selected.connect(vorschau_zeigen)
	vorschau_zeigen.call()

	var stats_label := Label.new()
	stats_label.custom_minimum_size = Vector2(340, 0)
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.add_theme_color_override("font_color", Stil3D.farbe("stern"))
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.text = HeroLibrary.loadout_description(kit_select.get_item_metadata(0))
	kit_select.item_selected.connect(func(index: int) -> void:
		stats_label.text = HeroLibrary.loadout_description(
			kit_select.get_item_metadata(index)))
	box.add_child(stats_label)

	var start_button := Button.new()
	start_button.text = Loc.pick("Abenteuer beginnen", "Begin the adventure")
	start_button.custom_minimum_size = Vector2(340, 52)
	start_button.pressed.connect(func() -> void:
		var kit_id: StringName = kit_select.get_item_metadata(kit_select.selected)
		var tile: int = portrait_select.get_item_metadata(portrait_select.selected)
		if GameState.recruit(name_edit.text, kit_id, tile):
			GameState.save_game()
			get_tree().reload_current_scene()
		else:
			name_edit.placeholder_text = Loc.pick("Bitte einen Namen eingeben!",
				"Please enter a name!")
			name_edit.grab_focus())
	box.add_child(start_button)
	UiTheme.focus_first_button(self)

