extends Control
## Hauptmenü-Platzhalter: führt vorerst nur in den Testkampf.

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
	add_child(UiTheme.make_background())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	# Titelzeile: zwei drehende 3D-Helden flankieren den goldenen Schriftzug.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 18)
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(title_row)
	title_row.add_child(_title_held(0, &"schwert_schild"))   # Ritter
	var title := Label.new()
	title.text = "Infinit Dungeon"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(title)
	title_row.add_child(_title_held(3, &"feuerstab"))   # Magierin
	# Sanfter Titel-Puls — lebendig, ohne aufdringlich zu sein.
	var pulse := create_tween().set_loops()
	pulse.tween_property(title, "modulate:a", 0.75, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(title, "modulate:a", 1.0, 1.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var divider := ColorRect.new()
	divider.color = Color(UiTheme.ACCENT.r, UiTheme.ACCENT.g, UiTheme.ACCENT.b, 0.55)
	divider.custom_minimum_size = Vector2(340, 2)
	var divider_center := CenterContainer.new()
	divider_center.add_child(divider)
	box.add_child(divider_center)

	# Frischer Start: erst den ersten Helden erstellen (Startwaffe wählen!),
	# der Rest der Party wird später kostenlos in der Taverne angeheuert.
	if GameState.party.is_empty():
		_build_hero_creation(box)
		return

	var subtitle := Label.new()
	var total_level := 0
	for member in GameState.party:
		total_level += member.level
	subtitle.text = Loc.pick("Gold: %d   ·   Party: %d Helden, Ø Level %.0f   ·   Karten: %d/%d",
		"Gold: %d   ·   Party: %d heroes, avg. level %.0f   ·   Maps: %d/%d") % [
		GameState.gold, GameState.party.size(),
		float(total_level) / maxi(1, GameState.party.size()),
		GameState.cards.size(), GameState.card_capacity]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.6)
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
		guest_note.modulate = Color(0.7, 0.85, 1.0)
		box.add_child(guest_note)
	if not GameState.current_run.is_empty() and not GameState.coop_guest_run \
			and not Net.is_guest():
		_menu_button(box, Loc.pick("Dungeon fortsetzen", "Resume dungeon"), DUNGEON_SCENE)
	if not Net.is_guest():
		_menu_button(box, Loc.pick("Kartenlager (%d/%d)", "Map storage (%d/%d)")
			% [GameState.cards.size(), GameState.card_capacity], CARDS_SCENE)
	_menu_button(box, Loc.pick("Stadt  —  Taverne · Händler · Schmiede",
		"Town  —  tavern · merchant · smithy"), TAVERN_SCENE)
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
	corner.offset_top = 12
	corner.offset_left = -16
	corner.offset_right = -16

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
		get_tree().create_timer(1.5).timeout.connect(func() -> void:
			if is_instance_valid(save_button):
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
		+ "   ·   v" + str(ProjectSettings.get_setting("application/config/version", "dev"))
	slot_label.add_theme_font_size_override("font_size", 11)
	slot_label.modulate = Color(1, 1, 1, 0.35)
	add_child(slot_label)
	slot_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	slot_label.offset_left = 12
	slot_label.offset_top = -26

	# Autosave: jeder Aufenthalt im Hub sichert den aktuellen Fortschritt.
	GameState.save_game()
	UiTheme.focus_first_button(self)

	# Onboarding: der Spiel-Loop in einem Absatz (einmal pro Spielstand).
	if GameState.first_time("menu"):
		UiTheme.show_hint(self, Loc.pick("Willkommen in Infinit Dungeon!",
			"Welcome to Infinit Dungeon!"), Loc.pick(
			"Dein Loop: Im KARTENLAGER eine Dungeon-Karte öffnen, drinnen kämpfen und looten, den Boss auf der untersten Ebene besiegen — die Belohnungskarte führt immer tiefer.\n\nZwischendurch: In der STADT einkaufen und schmieden, in der SKILL-WERKSTATT eigene Skills aus Bausteinen bauen, unter AUSRÜSTUNG Beute anlegen und Statuspunkte verteilen.",
			"Your loop: open a dungeon map in MAP STORAGE, fight and loot inside, defeat the boss on the lowest floor — the reward map takes you ever deeper.\n\nIn between: shop and forge in TOWN, build your own skills from blocks in the SKILL WORKSHOP, equip loot and spend stat points under EQUIPMENT."))


func _menu_button(box: VBoxContainer, label: String, scene_path: String) -> void:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(340, 48)
	button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(scene_path))
	box.add_child(button)


## Kleine, dezente Buttons für die Ecken-Leiste (Meta-Funktionen).
func _corner_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 34)
	button.modulate = Color(1, 1, 1, 0.8)
	return button


## Erster Spielstart: einen Helden wählen + Starter-Kit (= Startwaffe & Skill).
func _build_hero_creation(box: VBoxContainer) -> void:
	var intro := Label.new()
	intro.text = Loc.pick("Erstelle deinen ersten Helden.\nWeitere Gefährten warten kostenlos in der Taverne.",
		"Create your first hero.\nMore companions await for free at the tavern.")
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.modulate = Color(1, 1, 1, 0.7)
	box.add_child(intro)

	var portrait := FigurenVorschau.new(Vector2i(140, 170))
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
	stats_label.modulate = Color(0.75, 0.9, 1.0)
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


## Drehender 3D-Held als Titel-Schmuck (Farbe = Index der Farbwahl).
func _title_held(farb_index: int, loadout: StringName) -> Control:
	var vorschau := FigurenVorschau.new(Vector2i(90, 110))
	vorschau.zeige(FigurenBau.starter_held(SpriteLib.HERO_PORTRAITS[farb_index], loadout))
	return vorschau
