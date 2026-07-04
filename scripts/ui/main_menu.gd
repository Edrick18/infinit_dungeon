extends Control
## Hauptmenü-Platzhalter: führt vorerst nur in den Testkampf.

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const WORKSHOP_SCENE := "res://scenes/workshop/skill_workshop.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/dungeon_scene.tscn"
const INVENTORY_SCENE := "res://scenes/inventory/inventory_scene.tscn"
const CARDS_SCENE := "res://scenes/hub/card_storage.tscn"
const SHOP_SCENE := "res://scenes/hub/shop_scene.tscn"
const TAVERN_SCENE := "res://scenes/hub/tavern.tscn"
const SMITH_SCENE := "res://scenes/hub/smith.tscn"


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
	subtitle.text = "Gold: %d   ·   Party: %d Helden, Ø Level %.0f   ·   Karten: %d/%d" % [
		GameState.gold, GameState.party.size(),
		float(total_level) / maxi(1, GameState.party.size()),
		GameState.cards.size(), GameState.card_capacity]
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.6)
	box.add_child(subtitle)

	if not GameState.current_run.is_empty():
		var resume_button := Button.new()
		resume_button.text = "Dungeon fortsetzen"
		resume_button.custom_minimum_size = Vector2(260, 48)
		resume_button.pressed.connect(func() -> void:
			get_tree().change_scene_to_file(DUNGEON_SCENE))
		box.add_child(resume_button)

	var cards_button := Button.new()
	cards_button.text = "Kartenlager (%d/%d)" % [GameState.cards.size(), GameState.card_capacity]
	cards_button.custom_minimum_size = Vector2(260, 48)
	cards_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(CARDS_SCENE))
	box.add_child(cards_button)

	var tavern_button := Button.new()
	tavern_button.text = "Taverne (Party: %d/%d)" % [GameState.party.size(),
		HeroLibrary.MAX_PARTY_SIZE]
	tavern_button.custom_minimum_size = Vector2(260, 48)
	tavern_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(TAVERN_SCENE))
	box.add_child(tavern_button)

	var battle_button := Button.new()
	battle_button.text = "Testkampf starten"
	battle_button.custom_minimum_size = Vector2(260, 48)
	battle_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(BATTLE_SCENE))
	box.add_child(battle_button)

	var workshop_button := Button.new()
	workshop_button.text = "Skill-Werkstatt"
	workshop_button.custom_minimum_size = Vector2(260, 48)
	workshop_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(WORKSHOP_SCENE))
	box.add_child(workshop_button)

	var inventory_button := Button.new()
	inventory_button.text = "Ausrüstung & Inventar"
	inventory_button.custom_minimum_size = Vector2(260, 48)
	inventory_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(INVENTORY_SCENE))
	box.add_child(inventory_button)

	var shop_button := Button.new()
	shop_button.text = "Händler & Alchemist"
	shop_button.custom_minimum_size = Vector2(260, 48)
	shop_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(SHOP_SCENE))
	box.add_child(shop_button)

	var smith_button := Button.new()
	smith_button.text = "Schmiede"
	smith_button.custom_minimum_size = Vector2(260, 48)
	smith_button.pressed.connect(func() -> void:
		get_tree().change_scene_to_file(SMITH_SCENE))
	box.add_child(smith_button)

	var save_label := Label.new()
	save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	save_label.modulate = Color(0.55, 1.0, 0.55)
	box.add_child(save_label)
	var save_button := Button.new()
	save_button.text = "Speichern"
	save_button.custom_minimum_size = Vector2(260, 48)
	save_button.pressed.connect(func() -> void:
		var ok := GameState.save_game()
		save_label.text = "Gespeichert!" if ok else "Speichern fehlgeschlagen."
		save_label.modulate = Color(0.55, 1.0, 0.55) if ok else Color(1.0, 0.5, 0.4))
	box.add_child(save_button)

	# Autosave: jeder Aufenthalt im Hub sichert den aktuellen Fortschritt.
	GameState.save_game()


## Erster Spielstart: einen Helden wählen + Starter-Kit (= Startwaffe & Skill).
func _build_hero_creation(box: VBoxContainer) -> void:
	var intro := Label.new()
	intro.text = "Erstelle deinen ersten Helden.\nWeitere Gefährten warten kostenlos in der Taverne."
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

	var hero_select := OptionButton.new()
	hero_select.custom_minimum_size = Vector2(340, 44)
	for hero_name in HeroLibrary.HERO_NAMES:
		hero_select.add_item(hero_name)
	hero_select.item_selected.connect(func(index: int) -> void:
		portrait.texture = SpriteLib.hero(HeroLibrary.HERO_NAMES[index]))
	hero_select.select(0)
	portrait.texture = SpriteLib.hero(HeroLibrary.HERO_NAMES[0])
	box.add_child(hero_select)

	var kit_select := OptionButton.new()
	kit_select.custom_minimum_size = Vector2(340, 44)
	for kit_id in HeroLibrary.STARTER_KITS:
		var kit: Dictionary = HeroLibrary.STARTER_KITS[kit_id]
		kit_select.add_item("%s — %s" % [kit["name"], kit["desc"]])
		kit_select.set_item_metadata(kit_select.item_count - 1, kit_id)
	kit_select.select(0)
	box.add_child(kit_select)

	var start_button := Button.new()
	start_button.text = "Abenteuer beginnen"
	start_button.custom_minimum_size = Vector2(340, 52)
	start_button.pressed.connect(func() -> void:
		var hero_name: String = HeroLibrary.HERO_NAMES[hero_select.selected]
		var kit_id: StringName = kit_select.get_item_metadata(kit_select.selected)
		if GameState.recruit(hero_name, kit_id):
			GameState.save_game()
			get_tree().reload_current_scene())
	box.add_child(start_button)
