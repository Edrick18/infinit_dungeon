extends Control
## Kampfszene: klassische JRPG-Ansicht — Gegner oben, Party unten,
## Aktionsmenü rechts, Kampflog in der Mitte. Die UI wird komplett
## im Code aufgebaut (Platzhalter-Optik bis Pixel-Art-Assets existieren).

const MAIN_SCENE := "res://scenes/main.tscn"
const DUNGEON_SCENE := "res://scenes/dungeon/dungeon_scene.tscn"
const ENEMY_TURN_DELAY := 0.6

var battle := Battle.new()

## Gesetzt, wenn der Kampf aus dem Dungeon kam (statt aus dem Menü-Testkampf).
var _dungeon_context: Dictionary = {}

var _active: Combatant = null
var _pending_skill: Skill = null  # null = Basisangriff
var _selecting_target := false

## Combatant → {"root", "hp", "mp" (nur Party), "status"}
var _panels := {}
## Combatant → Button (nur Gegner, für die Zielauswahl)
var _enemy_buttons := {}

var _info_label: Label
var _enemy_row: HBoxContainer
var _party_row: HBoxContainer
var _action_box: VBoxContainer
var _log_label: RichTextLabel


func _ready() -> void:
	_build_layout()

	# Party kommt aus dem GameState (dort ggf. in der Werkstatt umgebaut).
	var party: Array[Combatant] = GameState.party
	for member in party:
		member.reset_for_battle()
	var foes: Array[Combatant]
	if not GameState.pending_battle.is_empty():
		_dungeon_context = GameState.pending_battle
		GameState.pending_battle = {}
		foes = _dungeon_context["enemies"]
	else:
		# Menü-Testkampf: zufällige Baukasten-Gruppe auf Stufe 1.
		var card := DungeonCard.new()
		card.seed = randi()
		card.tier = 1
		card.biome = Enums.Biome.FOREST
		var rng := RandomNumberGenerator.new()
		rng.seed = card.seed
		foes = EnemyFactory.make_encounter(card, rng)
	battle.log_line.connect(_on_log)
	battle.battle_ended.connect(_on_battle_ended)
	battle.start(party, foes)

	for enemy in foes:
		_enemy_row.add_child(_make_enemy_panel(enemy))
	for member in party:
		_party_row.add_child(_make_party_panel(member))

	_refresh_all()
	_advance()


# --- Kampfablauf ------------------------------------------------------------

func _advance() -> void:
	while not battle.is_over:
		var actor := battle.next_turn()
		if actor == null:
			return
		_refresh_all()
		if actor.is_player:
			_show_actions(actor)
			return
		await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
		battle.ai_take_turn(actor)
		_refresh_all()


func _execute_action(skill: Skill, target: Combatant) -> void:
	_clear_actions()
	_set_enemy_buttons_enabled(false)
	if skill == null:
		battle.basic_attack(_active, target)
	else:
		battle.use_skill(_active, skill, target)
	_refresh_all()
	_advance()


# --- Aktionsmenü ------------------------------------------------------------

func _show_actions(actor: Combatant) -> void:
	_active = actor
	_clear_actions()

	var head := Label.new()
	head.text = "%s ist am Zug" % actor.display_name
	_action_box.add_child(head)

	var attack := Button.new()
	attack.text = "Angriff"
	attack.pressed.connect(_begin_target_selection.bind(null))
	_action_box.add_child(attack)

	for skill in actor.skills:
		if not skill.is_valid():
			continue  # unfertige Werkstatt-Skills tauchen im Kampf nicht auf
		var button := Button.new()
		button.text = "%s (%d MP)" % [skill.display_name, skill.get_mp_cost()]
		button.disabled = actor.mp < skill.get_mp_cost()
		button.pressed.connect(_on_skill_pressed.bind(skill))
		_action_box.add_child(button)


func _on_skill_pressed(skill: Skill) -> void:
	var carrier := skill.get_carrier()
	if carrier.carrier == Enums.Carrier.MELEE or carrier.carrier == Enums.Carrier.PROJECTILE:
		_begin_target_selection(skill)
	else:
		_execute_action(skill, null)


func _begin_target_selection(skill: Skill) -> void:
	_pending_skill = skill
	_selecting_target = true
	_clear_actions()

	var hint := Label.new()
	hint.text = "Ziel wählen …"
	_action_box.add_child(hint)

	var cancel := Button.new()
	cancel.text = "Zurück"
	cancel.pressed.connect(func() -> void:
		_selecting_target = false
		_set_enemy_buttons_enabled(false)
		_show_actions(_active))
	_action_box.add_child(cancel)

	_set_enemy_buttons_enabled(true)


func _on_enemy_clicked(enemy: Combatant) -> void:
	if not _selecting_target or not enemy.is_alive():
		return
	_selecting_target = false
	_execute_action(_pending_skill, enemy)


func _set_enemy_buttons_enabled(enabled: bool) -> void:
	for enemy in _enemy_buttons:
		var button: Button = _enemy_buttons[enemy]
		button.disabled = not (enabled and enemy.is_alive())


func _clear_actions() -> void:
	for child in _action_box.get_children():
		child.queue_free()


# --- Kampfende --------------------------------------------------------------

func _on_battle_ended(victory: bool) -> void:
	_clear_actions()
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var label := Label.new()
	label.text = "Sieg!" if victory else "Niederlage …"
	label.add_theme_font_size_override("font_size", 36)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	# Beute gibt es nur für Dungeon-Kämpfe (der Menü-Testkampf wäre sonst
	# eine kostenlose Farm).
	if victory and not _dungeon_context.is_empty():
		var tier: int = GameState.current_run["card"].tier
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var loot := LootGenerator.roll_battle_loot(
			battle.enemies, tier, _dungeon_context["is_boss"], rng)
		GameState.gold += loot["gold"]
		var gold_label := Label.new()
		gold_label.text = "+%d Gold" % loot["gold"]
		gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(gold_label)
		for item in loot["items"]:
			GameState.inventory.append(item)
			var item_label := Label.new()
			item_label.text = "%s (%s)" % [item.get_display_name(),
				LootGenerator.RARITY_NAMES[item.rarity]]
			item_label.modulate = LootGenerator.RARITY_COLORS[item.rarity]
			item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(item_label)

	var back := Button.new()
	if _dungeon_context.is_empty():
		back.text = "Zurück zum Menü"
		back.pressed.connect(func() -> void:
			get_tree().change_scene_to_file(MAIN_SCENE))
	elif victory:
		# Gegner im Run als besiegt markieren, dann zurück in den Dungeon.
		if _dungeon_context["is_boss"]:
			GameState.current_run["boss_defeated"] = true
			# Abschluss: Zähler hoch, Belohnungskarte ±3 Stufen würfeln.
			var run_card: DungeonCard = GameState.current_run["card"]
			run_card.times_completed += 1
			var reward := CardFactory.make_reward(run_card)
			GameState.current_run["reward"] = reward
			GameState.current_run["reward_added"] = GameState.add_card(reward)
		else:
			GameState.current_run["defeated"].append(_dungeon_context["enemy_id"])
		back.text = "Weiter"
		back.pressed.connect(func() -> void:
			get_tree().change_scene_to_file(DUNGEON_SCENE))
	else:
		# Wipe: zurück zum Hub, die Karte bleibt erhalten (siehe Design) —
		# nur der laufende Besuch (besiegte Gegner etc.) geht verloren.
		back.text = "Zurück zum Hub"
		back.pressed.connect(func() -> void:
			GameState.clear_run()
			get_tree().change_scene_to_file(MAIN_SCENE))
	box.add_child(back)


# --- UI-Aufbau --------------------------------------------------------------

func _build_layout() -> void:
	var bg := ColorRect.new()
	bg.color = Color("1a1a2e")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 16)
	root.add_theme_constant_override("margin_top", 12)
	root.add_theme_constant_override("margin_right", 16)
	root.add_theme_constant_override("margin_bottom", 12)
	add_child(root)

	var main := VBoxContainer.new()
	main.add_theme_constant_override("separation", 10)
	root.add_child(main)

	_info_label = Label.new()
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_child(_info_label)

	var enemy_center := CenterContainer.new()
	enemy_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(enemy_center)
	_enemy_row = HBoxContainer.new()
	_enemy_row.add_theme_constant_override("separation", 32)
	enemy_center.add_child(_enemy_row)

	_log_label = RichTextLabel.new()
	_log_label.custom_minimum_size = Vector2(0, 130)
	_log_label.scroll_following = true
	main.add_child(_log_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	main.add_child(bottom)

	_party_row = HBoxContainer.new()
	_party_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_party_row.add_theme_constant_override("separation", 12)
	bottom.add_child(_party_row)

	_action_box = VBoxContainer.new()
	_action_box.custom_minimum_size = Vector2(240, 0)
	_action_box.add_theme_constant_override("separation", 6)
	bottom.add_child(_action_box)


func _make_enemy_panel(enemy: Combatant) -> Control:
	var button := Button.new()
	button.flat = true
	button.disabled = true
	button.custom_minimum_size = Vector2(130, 150)
	button.pressed.connect(_on_enemy_clicked.bind(enemy))
	_enemy_buttons[enemy] = button

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override("separation", 4)
	_ignore_mouse_recursive(box)
	button.add_child(box)

	var sprite_center := CenterContainer.new()
	box.add_child(sprite_center)
	var sprite := ColorRect.new()
	sprite.custom_minimum_size = Vector2(64, 64)
	sprite.color = _placeholder_color(enemy.display_name)
	sprite_center.add_child(sprite)

	var name_label := Label.new()
	name_label.text = enemy.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)

	var hp_bar := ProgressBar.new()
	hp_bar.max_value = enemy.max_hp
	hp_bar.value = enemy.hp
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0, 10)
	box.add_child(hp_bar)

	var status_label := Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 11)
	box.add_child(status_label)

	_ignore_mouse_recursive(box)
	_panels[enemy] = {"root": button, "hp": hp_bar, "status": status_label}
	return button


func _make_party_panel(member: Combatant) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var name_label := Label.new()
	name_label.text = member.display_name
	box.add_child(name_label)

	var hp_bar := ProgressBar.new()
	hp_bar.max_value = member.max_hp
	hp_bar.value = member.hp
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(0, 12)
	box.add_child(hp_bar)

	var mp_bar := ProgressBar.new()
	mp_bar.max_value = member.max_mp
	mp_bar.value = member.mp
	mp_bar.show_percentage = false
	mp_bar.custom_minimum_size = Vector2(0, 8)
	mp_bar.modulate = Color(0.5, 0.7, 1.0)
	box.add_child(mp_bar)

	var status_label := Label.new()
	status_label.add_theme_font_size_override("font_size", 11)
	box.add_child(status_label)

	_panels[member] = {"root": panel, "hp": hp_bar, "mp": mp_bar, "status": status_label}
	return panel


func _refresh_all() -> void:
	_info_label.text = "Runde %d" % battle.round_number
	for combatant in _panels:
		var panel: Dictionary = _panels[combatant]
		panel["hp"].value = combatant.hp
		if panel.has("mp"):
			panel["mp"].value = combatant.mp
		var names: Array[String] = []
		for entry in combatant.statuses:
			names.append(Battle.status_display_name(entry["status"]))
		panel["status"].text = ", ".join(names)
		panel["root"].modulate = Color(1, 1, 1) if combatant.is_alive() \
			else Color(1, 1, 1, 0.3)


func _on_log(text: String) -> void:
	_log_label.append_text(text + "\n")


func _ignore_mouse_recursive(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_ignore_mouse_recursive(child)


static func _placeholder_color(name: String) -> Color:
	return Color.from_hsv(float(absi(hash(name)) % 360) / 360.0, 0.55, 0.85)
