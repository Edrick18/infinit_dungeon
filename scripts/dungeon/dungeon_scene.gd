extends Node2D
## Begehbarer Dungeon: Top-Down-Ansicht, WASD/Pfeiltasten zum Laufen.
## Gegner sind sichtbar — Berührung startet den Rundenkampf, danach geht es
## an derselben Stelle weiter (das Layout kommt deterministisch aus dem
## Karten-Seed, der Fortschritt liegt im GameState.current_run).

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"

const SPEED := 170.0
const PLAYER_HALF := 11.0
const CONTACT_DIST := 26.0

const COLOR_FLOOR := Color("2e2e44")
const COLOR_WALL := Color("14141f")
const COLOR_PLAYER := Color("e0e0f0")
const COLOR_ENEMY := Color("d05050")
const COLOR_BOSS := Color("9040c0")
const COLOR_CHEST := Color("d0a840")

var map: DungeonMap
var card: DungeonCard
var player_pos := Vector2.ZERO

## Lebende Gegner/ungeöffnete Truhen: {"id", "pos": Vector2, ("gold")}
var _enemies: Array[Dictionary] = []
var _chests: Array[Dictionary] = []
var _boss_alive := true
var _entering_battle := false

var _camera: Camera2D
var _hud_label: Label
var _msg_label: Label
var _hud_layer: CanvasLayer


func _ready() -> void:
	if GameState.current_run.is_empty():
		# Szene direkt gestartet (F6): Testkarte anlegen.
		GameState.start_run(CardFactory.make_starter_card())

	card = GameState.current_run["card"]
	map = DungeonGenerator.generate(card)

	var saved: Vector2 = GameState.current_run["player_pos"]
	player_pos = saved if saved != Vector2.ZERO else DungeonMap.cell_center_px(map.spawn)

	for enemy in map.enemies:
		if enemy["id"] in GameState.current_run["defeated"]:
			continue
		_enemies.append({"id": enemy["id"], "pos": DungeonMap.cell_center_px(enemy["cell"])})
	for chest in map.chests:
		if chest["id"] in GameState.current_run["opened"]:
			continue
		_chests.append({"id": chest["id"], "gold": chest["gold"],
			"pos": DungeonMap.cell_center_px(chest["cell"])})
	_boss_alive = not GameState.current_run["boss_defeated"]

	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_build_hud()

	if not _boss_alive:
		_show_completion()


func _process(delta: float) -> void:
	if _entering_battle:
		return
	_move_player(delta)
	_check_contacts()
	_camera.position = player_pos
	_hud_label.text = "%s (Stufe %d)   Gold: %d   Gegner: %d   [1] Heiltrank ×%d  [2] Manatrank ×%d  [Esc] Verlassen" \
		% [card.display_name, card.tier, GameState.gold,
			_enemies.size() + (1 if _boss_alive else 0),
			GameState.consumable_count(&"heiltrank"), GameState.consumable_count(&"manatrank")]
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_ESCAPE:
			GameState.current_run["player_pos"] = player_pos
			get_tree().change_scene_to_file(MAIN_SCENE)
		KEY_1:
			_quick_use(&"heiltrank")
		KEY_2:
			_quick_use(&"manatrank")


## Schnellnutzung außerhalb des Kampfs: Heiltrank aufs am schwersten
## verwundete, Manatrank aufs MP-ärmste lebende Party-Mitglied.
func _quick_use(id: StringName) -> void:
	if GameState.consumable_count(id) <= 0:
		_show_message("Kein %s mehr übrig." % ConsumableLibrary.get_def(id).display_name)
		return
	var def := ConsumableLibrary.get_def(id)
	var target: Combatant = null
	var worst := 1.0
	for member in GameState.party:
		if not member.is_alive():
			continue
		var ratio: float
		if def.effect == Enums.ConsumableEffect.HEAL_HP:
			ratio = float(member.hp) / member.max_hp
		else:
			ratio = float(member.mp) / maxi(1, member.max_mp)
		if ratio < worst:
			worst = ratio
			target = member
	if target == null or worst >= 1.0:
		_show_message("Niemand braucht gerade einen %s." % def.display_name)
		return
	GameState.consume(id)
	if def.effect == Enums.ConsumableEffect.HEAL_HP:
		target.heal(def.potency)
		_show_message("%s: %s heilt %d HP." % [def.display_name, target.display_name, def.potency])
	else:
		target.mp = mini(target.max_mp, target.mp + def.potency)
		_show_message("%s: %s erhält %d MP." % [def.display_name, target.display_name, def.potency])


# --- Bewegung -----------------------------------------------------------------

func _move_player(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if dir == Vector2.ZERO:
		return
	var motion := dir.normalized() * SPEED * delta
	# Achsen getrennt bewegen, damit man an Wänden entlanggleitet.
	var next_x := player_pos + Vector2(motion.x, 0)
	if _fits(next_x):
		player_pos = next_x
	var next_y := player_pos + Vector2(0, motion.y)
	if _fits(next_y):
		player_pos = next_y


func _fits(center: Vector2) -> bool:
	for offset in [Vector2(-PLAYER_HALF, -PLAYER_HALF), Vector2(PLAYER_HALF, -PLAYER_HALF),
			Vector2(-PLAYER_HALF, PLAYER_HALF), Vector2(PLAYER_HALF, PLAYER_HALF)]:
		if not map.is_walkable_px(center + offset):
			return false
	return true


# --- Interaktion ----------------------------------------------------------------

func _check_contacts() -> void:
	for chest in _chests.duplicate():
		if player_pos.distance_to(chest["pos"]) < CONTACT_DIST:
			GameState.gold += chest["gold"]
			GameState.current_run["opened"].append(chest["id"])
			_chests.erase(chest)
			var message := "Truhe geöffnet: +%d Gold!" % chest["gold"]
			# Truhen enthalten oft zusätzlich einen Trank (Attrition-Ausgleich).
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			if rng.randf() < 0.4:
				var def := ConsumableLibrary.roll(card.tier, rng)
				if def != null:
					GameState.add_consumable(def.id)
					message += "  +1 %s!" % def.display_name
			_show_message(message)
	for enemy in _enemies:
		if player_pos.distance_to(enemy["pos"]) < CONTACT_DIST:
			_start_battle(enemy["id"], false)
			return
	if _boss_alive and player_pos.distance_to(DungeonMap.cell_center_px(map.boss_cell)) < CONTACT_DIST + 8:
		_start_battle(-1, true)


func _start_battle(enemy_id: int, is_boss: bool) -> void:
	if _entering_battle:
		return
	_entering_battle = true
	GameState.current_run["player_pos"] = player_pos
	# Encounter deterministisch aus Karten-Seed + Gegner-ID: dieselbe Karte
	# liefert beim Farmen immer dieselben Gruppen.
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + (enemy_id + 2) * 7919
	var foes := EnemyFactory.make_encounter(card, rng, is_boss)
	GameState.pending_battle = {"enemy_id": enemy_id, "is_boss": is_boss, "enemies": foes}
	get_tree().change_scene_to_file(BATTLE_SCENE)


# --- Abschluss --------------------------------------------------------------------

func _show_completion() -> void:
	_entering_battle = true  # Steuerung einfrieren
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_layer.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)

	var label := Label.new()
	label.text = "Dungeon abgeschlossen!"
	label.add_theme_font_size_override("font_size", 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	var reward: DungeonCard = GameState.current_run.get("reward")
	if reward != null:
		var note := Label.new()
		note.text = "Belohnung: %s (Stufe %d)" % [reward.display_name, reward.tier]
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(note)
		if not GameState.current_run.get("reward_added", true):
			var lost := Label.new()
			lost.text = "Kartenlager voll — die Karte ist verloren!"
			lost.modulate = Color(1.0, 0.5, 0.4)
			lost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(lost)

	var back := Button.new()
	back.text = "Zurück zum Hub"
	back.pressed.connect(func() -> void:
		GameState.clear_run()
		get_tree().change_scene_to_file(MAIN_SCENE))
	box.add_child(back)


# --- Darstellung -------------------------------------------------------------------

func _draw() -> void:
	var tile := DungeonMap.TILE_SIZE
	draw_rect(Rect2(0, 0, map.width * tile, map.height * tile), COLOR_WALL)
	for cell in map.floor_cells():
		draw_rect(Rect2(cell.x * tile, cell.y * tile, tile, tile), COLOR_FLOOR)

	for chest in _chests:
		draw_rect(Rect2(chest["pos"] - Vector2(10, 8), Vector2(20, 16)), COLOR_CHEST)
	for enemy in _enemies:
		draw_circle(enemy["pos"], 11, COLOR_ENEMY)
	if _boss_alive:
		draw_circle(DungeonMap.cell_center_px(map.boss_cell), 17, COLOR_BOSS)

	draw_rect(Rect2(player_pos - Vector2(PLAYER_HALF, PLAYER_HALF),
		Vector2(PLAYER_HALF * 2, PLAYER_HALF * 2)), COLOR_PLAYER)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)
	_hud_label = Label.new()
	_hud_label.position = Vector2(12, 8)
	_hud_layer.add_child(_hud_label)
	_msg_label = Label.new()
	_msg_label.position = Vector2(12, 34)
	_msg_label.modulate = Color(1.0, 0.9, 0.5)
	_hud_layer.add_child(_msg_label)


func _show_message(text: String) -> void:
	_msg_label.text = text
	var timer := get_tree().create_timer(2.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_msg_label) and _msg_label.text == text:
			_msg_label.text = "")
