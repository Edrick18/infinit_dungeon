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

## Log-Zeile für einen aktiven Schrein-Segen (nach dem UI-Aufbau ausgegeben).
var _blessing_note := ""

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
	theme = UiTheme.get_theme()
	_build_layout()

	# Party kommt aus dem GameState (dort ggf. in der Werkstatt umgebaut).
	var party: Array[Combatant] = GameState.party
	var foes: Array[Combatant]
	if not GameState.pending_battle.is_empty():
		_dungeon_context = GameState.pending_battle
		GameState.pending_battle = {}
		foes = _dungeon_context["enemies"]
		# Attrition im Dungeon: Statuseffekte weg, aber Wunden bleiben.
		for member in party:
			member.reset_for_battle(false)
		# Schrein-Segen (Dungeon-Event): wirkt genau auf den nächsten Kampf.
		if GameState.current_run.has("blessing"):
			var blessing: StringName = GameState.current_run["blessing"]
			GameState.current_run.erase("blessing")
			var tier: int = GameState.current_run["card"].tier
			for member in party:
				if not member.is_alive():
					continue
				if blessing == &"segen_kraft":
					member.add_status(Enums.Status.ATK_UP, 3, 25)
				elif blessing == &"segen_schutz":
					member.add_status(Enums.Status.DEF_UP, 3, 4 + tier)
			_blessing_note = "Der Schrein-Segen liegt auf der Party (%s, 3 Runden)!" \
				% ("Angriff +25%" if blessing == &"segen_kraft" else "Rüstung +%d" % (4 + tier))
	else:
		for member in party:
			member.reset_for_battle(true)
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
	battle.combatant_added.connect(_on_combatant_added)
	battle.combatant_removed.connect(_on_combatant_removed)
	battle.start(party, foes)

	for enemy in foes:
		_enemy_row.add_child(_make_enemy_panel(enemy))
	for member in party:
		_party_row.add_child(_make_party_panel(member))

	_refresh_all()
	if not _blessing_note.is_empty():
		_on_log(_blessing_note)
	_advance()


# --- Kampfablauf ------------------------------------------------------------

func _advance() -> void:
	while not battle.is_over:
		# Zugbeginn verarbeitet DoT-Ticks/Regeneration — die Zahlen sollen
		# genauso sichtbar aufsteigen wie Treffer.
		var tick_snapshot := _snapshot_hp()
		var actor := battle.next_turn()
		_animate_hp_changes(tick_snapshot)
		if actor == null:
			return
		_refresh_all()
		if actor.is_player and not actor.is_summon:
			_show_actions(actor)
			return
		# Gegner UND Beschwörungen handeln automatisch.
		await get_tree().create_timer(ENEMY_TURN_DELAY).timeout
		var before := _snapshot_hp()
		_pulse_sprite(actor)
		battle.ai_take_turn(actor)
		_animate_hp_changes(before)
		_refresh_all()


func _execute_action(skill: Skill, target: Combatant) -> void:
	_clear_actions()
	_set_enemy_buttons_enabled(false)
	var before := _snapshot_hp()
	_pulse_sprite(_active)
	if skill == null:
		battle.basic_attack(_active, target)
	else:
		battle.use_skill(_active, skill, target)
	_animate_hp_changes(before)
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

	var defend := Button.new()
	defend.text = "Verteidigen"
	defend.pressed.connect(func() -> void:
		_clear_actions()
		battle.defend(_active)
		_refresh_all()
		_advance())
	_action_box.add_child(defend)

	if not GameState.consumables.is_empty():
		var item_button := Button.new()
		item_button.text = "Item"
		item_button.pressed.connect(_show_item_menu)
		_action_box.add_child(item_button)

	# Nur die Skills in den freigeschalteten Slots (+1 alle 5 Level).
	for skill: Skill in actor.skills.slice(0, actor.skill_slots()):
		if not skill.is_valid():
			continue  # unfertige Werkstatt-Skills tauchen im Kampf nicht auf
		var cost: int = skill.get_mp_cost(actor)
		var button := Button.new()
		button.text = "%s (%d MP)" % [skill.display_name, cost]
		button.disabled = actor.mp < cost
		button.tooltip_text = _skill_tooltip(skill, cost)
		button.pressed.connect(_on_skill_pressed.bind(skill))
		_action_box.add_child(button)


## Tooltip: woraus der Skill gebaut ist — direkt im Kampf nachschlagbar.
static func _skill_tooltip(skill: Skill, cost: int) -> String:
	var parts: Array[String] = []
	for block in skill.blocks:
		if not block.display_name.is_empty():
			parts.append(block.display_name)
	return "Bausteine: %s\nKosten: %d MP" % [" + ".join(parts), cost]


## Item-Menü: Trank wählen → Party-Mitglied als Ziel wählen → Zug verbraucht.
func _show_item_menu() -> void:
	_clear_actions()
	var head := Label.new()
	head.text = "Item wählen"
	_action_box.add_child(head)
	for id in GameState.consumables:
		var def := ConsumableLibrary.get_def(id)
		if def == null:
			continue
		var button := Button.new()
		button.text = "%s (×%d)" % [def.display_name, GameState.consumable_count(id)]
		button.tooltip_text = def.description
		button.pressed.connect(_show_item_targets.bind(def))
		_action_box.add_child(button)
	var back := Button.new()
	back.text = "Zurück"
	back.pressed.connect(func() -> void: _show_actions(_active))
	_action_box.add_child(back)


func _show_item_targets(def: ConsumableDef) -> void:
	_clear_actions()
	var head := Label.new()
	head.text = "%s auf wen?" % def.display_name
	_action_box.add_child(head)
	var needs_dead := def.effect == Enums.ConsumableEffect.REVIVE
	for member in battle.players:
		if member.is_alive() == needs_dead:
			continue
		var button := Button.new()
		button.text = "%s (%d/%d HP)" % [member.display_name, member.hp, member.max_hp]
		button.pressed.connect(_use_item_on.bind(def, member))
		_action_box.add_child(button)
	var back := Button.new()
	back.text = "Zurück"
	back.pressed.connect(_show_item_menu)
	_action_box.add_child(back)


func _use_item_on(def: ConsumableDef, target: Combatant) -> void:
	_clear_actions()
	var before := _snapshot_hp()
	if battle.use_consumable(_active, def, target):
		GameState.consume(def.id)
		_animate_hp_changes(before)
		_refresh_all()
		_advance()
	else:
		_show_actions(_active)


func _on_skill_pressed(skill: Skill) -> void:
	match skill.get_form():
		Enums.SkillForm.SINGLE:
			_begin_target_selection(skill)   # ein Gegner
		Enums.SkillForm.ALLY:
			_begin_ally_selection(skill)     # ein Verbündeter
		_:
			_execute_action(skill, null)     # Fläche/Aura/Selbst: kein Ziel nötig


## Zielauswahl auf einen Verbündeten (Form „Verbündeter") — Buttons im Aktionsmenü.
func _begin_ally_selection(skill: Skill) -> void:
	_clear_actions()
	var head := Label.new()
	head.text = "Verbündeten wählen …"
	_action_box.add_child(head)
	for member in battle.players:
		if not member.is_alive():
			continue
		var button := Button.new()
		button.text = "%s (%d/%d HP)" % [member.display_name, member.hp, member.max_hp]
		button.pressed.connect(_execute_action.bind(skill, member))
		_action_box.add_child(button)
	var cancel := Button.new()
	cancel.text = "Zurück"
	cancel.pressed.connect(func() -> void: _show_actions(_active))
	_action_box.add_child(cancel)


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

	# Beute und XP gibt es nur für Dungeon-Kämpfe (der Menü-Testkampf wäre
	# sonst eine kostenlose Farm).
	if victory and not _dungeon_context.is_empty():
		var run_affixes: Array[StringName] = GameState.current_run["card"].card_affix_ids
		# XP an die ganze Party (auch Gefallene — kein Feel-Bad).
		# Beschwörungen geben weder XP noch Beute.
		var real_foes: Array[Combatant] = []
		for foe in battle.enemies:
			if not foe.is_summon:
				real_foes.append(foe)
		var xp_total := 0
		for foe in real_foes:
			xp_total += 8 + foe.level * 4
		if _dungeon_context["is_boss"]:
			xp_total *= 3
		if &"uralt" in run_affixes:
			xp_total = roundi(xp_total * 1.25)
		var xp_label := Label.new()
		xp_label.text = "+%d XP" % xp_total
		xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(xp_label)
		for member in GameState.party:
			var gained := member.gain_xp(xp_total)
			if gained > 0:
				var level_label := Label.new()
				level_label.text = "%s erreicht Level %d! (+%d Statuspunkte)" \
					% [member.display_name, member.level, gained * Combatant.POINTS_PER_LEVEL]
				if member.level % 5 == 0:
					level_label.text += "  (+1 Skill-Slot)"
				level_label.modulate = Color(0.55, 1.0, 0.55)
				level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				box.add_child(level_label)

		# Verschnaufen: Gefallene stehen wieder auf, alle regenerieren 25%.
		for member in GameState.party:
			member.hp = maxi(member.hp, 1)
			member.heal(roundi(member.max_hp * 0.25))
			member.mp = mini(member.max_mp, member.mp + roundi(member.max_mp * 0.25))
		var rest_label := Label.new()
		rest_label.text = "Die Party verschnauft (+25% HP/MP)."
		rest_label.modulate = Color(1, 1, 1, 0.6)
		rest_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(rest_label)

		var tier: int = GameState.current_run["card"].tier
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var loot := LootGenerator.roll_battle_loot(
			real_foes, tier, _dungeon_context["is_boss"], rng)
		if &"reich" in run_affixes:
			loot["gold"] = roundi(loot["gold"] * 1.6)
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
		for material_id in loot["materials"]:
			GameState.add_material(material_id)
			var material_label := Label.new()
			material_label.text = "+1 %s" % MaterialLibrary.display_name(material_id)
			material_label.modulate = Color(0.6, 0.95, 0.7)
			material_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(material_label)

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
	var sprite := _make_sprite(enemy, 64)
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
	_panels[enemy] = {"root": button, "hp": hp_bar, "status": status_label, "sprite": sprite}
	return button


func _make_party_panel(member: Combatant) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	box.add_child(name_row)
	var sprite := _make_sprite(member, 28)
	name_row.add_child(sprite)
	var name_label := Label.new()
	name_label.text = member.display_name
	name_row.add_child(name_label)

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

	_panels[member] = {"root": panel, "hp": hp_bar, "mp": mp_bar,
		"status": status_label, "sprite": sprite}
	return panel


func _refresh_all() -> void:
	var preview := battle.get_turn_preview()
	if preview.is_empty():
		_info_label.text = "Runde %d" % battle.round_number
	else:
		_info_label.text = "Runde %d   ·   Als Nächstes: %s" \
			% [battle.round_number, " → ".join(preview)]
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


## Beschwörung erscheint mitten im Kampf → Panel dynamisch anlegen.
func _on_combatant_added(combatant: Combatant) -> void:
	if combatant.is_player:
		_party_row.add_child(_make_party_panel(combatant))
	else:
		_enemy_row.add_child(_make_enemy_panel(combatant))
	_refresh_all()


func _on_combatant_removed(combatant: Combatant) -> void:
	if _panels.has(combatant):
		_panels[combatant]["root"].queue_free()
		_panels.erase(combatant)
	_enemy_buttons.erase(combatant)


func _ignore_mouse_recursive(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control:
			_ignore_mouse_recursive(child)


## Pixel-Art-Sprite des Kämpfers; Fallback: farbiges Rechteck.
static func _make_sprite(combatant: Combatant, size: int) -> Control:
	var node: Control
	if combatant.sprite != null:
		var rect := TextureRect.new()
		rect.texture = combatant.sprite
		rect.custom_minimum_size = Vector2(size, size)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node = rect
	else:
		var fallback := ColorRect.new()
		fallback.custom_minimum_size = Vector2(size, size)
		fallback.color = _placeholder_color(combatant.display_name)
		node = fallback
	# Pivot mittig, damit Puls-/Wackel-Animationen nicht aus der Ecke wachsen.
	node.pivot_offset = Vector2(size, size) * 0.5
	return node


static func _placeholder_color(name: String) -> Color:
	return Color.from_hsv(float(absi(hash(name)) % 360) / 360.0, 0.55, 0.85)


# --- Kampf-Animationen -----------------------------------------------------------
# Rein visuell auf Basis eines HP-Vorher/Nachher-Vergleichs — Battle bleibt
# UI-frei. Tweens auf "scale"/"rotation" statt "position", weil Container
# (CenterContainer/HBoxContainer) die Position kontrollierter Kinder sonst
# beim nächsten Sortierdurchlauf zurücksetzen würden.

func _snapshot_hp() -> Dictionary:
	var snap := {}
	for combatant in _panels:
		snap[combatant] = combatant.hp
	return snap


func _animate_hp_changes(before: Dictionary) -> void:
	for combatant in _panels:
		if not before.has(combatant):
			continue
		var diff: int = combatant.hp - before[combatant]
		if diff == 0:
			continue
		_spawn_floating_number(combatant, diff)
		_flash_sprite(combatant, diff > 0)
		if diff < 0:
			_shake_sprite(combatant)


## Kurzer Skalierungs-Puls, wenn ein Kämpfer eine Aktion ausführt.
func _pulse_sprite(combatant: Combatant) -> void:
	if not _panels.has(combatant):
		return
	var sprite: Control = _panels[combatant]["sprite"]
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.25, 1.25), 0.08)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.14)


## Kurzes Wackeln (Rotation statt Position — containersicher) bei Treffern.
func _shake_sprite(combatant: Combatant) -> void:
	if not _panels.has(combatant):
		return
	var sprite: Control = _panels[combatant]["sprite"]
	var tween := create_tween()
	tween.tween_property(sprite, "rotation", deg_to_rad(10), 0.04)
	tween.tween_property(sprite, "rotation", deg_to_rad(-10), 0.05)
	tween.tween_property(sprite, "rotation", 0.0, 0.05)


## Rot-/Grünblitz als kurzlebiges Overlay über dem Sprite.
func _flash_sprite(combatant: Combatant, is_heal: bool) -> void:
	if not _panels.has(combatant):
		return
	var sprite: Control = _panels[combatant]["sprite"]
	var overlay := ColorRect.new()
	overlay.color = Color(0.55, 1.0, 0.6, 0.55) if is_heal else Color(1.0, 0.3, 0.3, 0.55)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	sprite.add_child(overlay)
	var tween := create_tween()
	tween.tween_property(overlay, "modulate:a", 0.0, 0.3)
	tween.tween_callback(overlay.queue_free)


## Aufsteigende Schadens-/Heilzahl über dem betroffenen Kämpfer.
func _spawn_floating_number(combatant: Combatant, diff: int) -> void:
	if not _panels.has(combatant):
		return
	var sprite: Control = _panels[combatant]["sprite"]
	var label := Label.new()
	label.text = ("+%d" % diff) if diff > 0 else str(diff)
	label.add_theme_font_size_override("font_size", 20)
	label.modulate = Color(0.55, 1.0, 0.6) if diff > 0 else Color(1.0, 0.45, 0.45)
	add_child(label)
	var start := sprite.get_global_rect().position + Vector2(sprite.size.x * 0.5 - 10, -6)
	label.global_position = start
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "global_position", start + Vector2(0, -34), 0.7)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.chain().tween_callback(label.queue_free)
