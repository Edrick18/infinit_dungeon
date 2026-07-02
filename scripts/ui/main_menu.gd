extends Control
## Hauptmenü-Platzhalter: führt vorerst nur in den Testkampf.

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const WORKSHOP_SCENE := "res://scenes/workshop/skill_workshop.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/dungeon_scene.tscn"


func _ready() -> void:
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

	var dungeon_button := Button.new()
	dungeon_button.custom_minimum_size = Vector2(260, 48)
	if GameState.current_run.is_empty():
		dungeon_button.text = "Dungeon betreten (Testkarte)"
		dungeon_button.pressed.connect(func() -> void:
			var card := DungeonCard.new()
			card.display_name = "Verwitterte Waldkarte"
			card.seed = randi()
			card.tier = 1
			card.biome = Enums.Biome.FOREST
			# Elite-/Boss-Modifikatoren werden bei Kartenerstellung fix gewürfelt.
			var mod_rng := RandomNumberGenerator.new()
			mod_rng.seed = card.seed
			card.modifier_ids = EnemyLibrary.roll_modifiers(card.tier, mod_rng)
			GameState.start_run(card)
			get_tree().change_scene_to_file(DUNGEON_SCENE))
	else:
		dungeon_button.text = "Dungeon fortsetzen"
		dungeon_button.pressed.connect(func() -> void:
			get_tree().change_scene_to_file(DUNGEON_SCENE))
	box.add_child(dungeon_button)

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
