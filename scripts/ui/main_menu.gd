extends Control
## Hauptmenü-Platzhalter: führt vorerst nur in den Testkampf.

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const WORKSHOP_SCENE := "res://scenes/workshop/skill_workshop.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/dungeon_scene.tscn"
const INVENTORY_SCENE := "res://scenes/inventory/inventory_scene.tscn"
const CARDS_SCENE := "res://scenes/hub/card_storage.tscn"
const SHOP_SCENE := "res://scenes/hub/shop_scene.tscn"


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

	var subtitle := Label.new()
	subtitle.text = "Prototyp"
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
