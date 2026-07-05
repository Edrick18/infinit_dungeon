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
	var bg := ColorRect.new()
	bg.color = Color("1a1a2e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	center.add_child(box)

	var title := Label.new()
	title.text = "Infinit Dungeon"
	title.add_theme_font_size_override("font_size", 52)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

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
	if not GameState.current_run.is_empty() and not GameState.coop_guest_run:
		_menu_button(box, Loc.pick("Dungeon fortsetzen", "Resume dungeon"), DUNGEON_SCENE)
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
	corner.offset_top = 12
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

	# Autosave: jeder Aufenthalt im Hub sichert den aktuellen Fortschritt.
	GameState.save_game()
	UiTheme.focus_first_button(self)


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

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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

	var portrait_select := OptionButton.new()
	portrait_select.custom_minimum_size = Vector2(340, 44)
	for index in SpriteLib.HERO_PORTRAITS.size():
		var tile: int = SpriteLib.HERO_PORTRAITS[index]
		portrait_select.add_icon_item(SpriteLib.tile(tile),
			Loc.pick("Porträt %d", "Portrait %d") % (index + 1))
		portrait_select.set_item_metadata(index, tile)
	portrait_select.item_selected.connect(func(index: int) -> void:
		portrait.texture = SpriteLib.tile(portrait_select.get_item_metadata(index)))
	portrait_select.select(0)
	portrait.texture = SpriteLib.tile(portrait_select.get_item_metadata(0))
	box.add_child(portrait_select)

	var kit_select := OptionButton.new()
	kit_select.custom_minimum_size = Vector2(340, 44)
	for kit_id in HeroLibrary.STARTER_KITS:
		var kit: Dictionary = HeroLibrary.STARTER_KITS[kit_id]
		kit_select.add_item("%s — %s" % [kit["name"], kit["desc"]])
		kit_select.set_item_metadata(kit_select.item_count - 1, kit_id)
	kit_select.select(0)
	box.add_child(kit_select)

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
