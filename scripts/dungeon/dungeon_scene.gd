extends Node2D
## Begehbarer Dungeon: Top-Down-Ansicht, WASD/Pfeiltasten zum Laufen.
## Gegner sind sichtbar — Berührung startet den Rundenkampf, danach geht es
## an derselben Stelle weiter (das Layout kommt deterministisch aus dem
## Karten-Seed, der Fortschritt liegt im GameState.current_run).

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"
const INVENTORY_SCENE := "res://scenes/inventory/inventory_scene.tscn"
const DUNGEON_SCENE_PATH := "res://scenes/dungeon/dungeon_scene.tscn"

const SPEED := 170.0
const PLAYER_HALF := 11.0
const CONTACT_DIST := 26.0

const COLOR_FLOOR := Color("2e2e44")
const COLOR_WALL := Color("14141f")
const COLOR_PLAYER := Color("e0e0f0")
const COLOR_ENEMY := Color("d05050")
const COLOR_BOSS := Color("9040c0")
const COLOR_CHEST := Color("d0a840")
const COLOR_STAIRS := Color("50c8d0")

## Gegner-/Truhen-IDs sind pro Ebene eindeutig: floor * FLOOR_ID_OFFSET + id.
const FLOOR_ID_OFFSET := 1000

var map: DungeonMap
var card: DungeonCard
var floor_index := 0
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

var _wall_cells: Array[Vector2i] = []

# Pixel-Art (null-sicher: ohne Texturen greifen die Farbformen)
var _tex_floor: Texture2D
var _tex_wall: Texture2D
var _tex_chest: Texture2D
var _tex_stairs: Texture2D
var _tex_enemy: Texture2D
var _tex_player: Texture2D


func _ready() -> void:
	if GameState.current_run.is_empty():
		# Szene direkt gestartet (F6): Testkarte anlegen.
		GameState.start_run(CardFactory.make_starter_card())

	card = GameState.current_run["card"]
	floor_index = GameState.current_run.get("floor", 0)
	map = DungeonGenerator.generate(card, floor_index)

	var saved: Vector2 = GameState.current_run["player_pos"]
	player_pos = saved if saved != Vector2.ZERO else DungeonMap.cell_center_px(map.spawn)

	for enemy in map.enemies:
		if _floor_id(enemy["id"]) in GameState.current_run["defeated"]:
			continue
		_enemies.append({"id": enemy["id"], "pos": DungeonMap.cell_center_px(enemy["cell"])})
	for chest in map.chests:
		if _floor_id(chest["id"]) in GameState.current_run["opened"]:
			continue
		_chests.append({"id": chest["id"], "gold": chest["gold"],
			"pos": DungeonMap.cell_center_px(chest["cell"])})
	_boss_alive = map.has_boss and not GameState.current_run["boss_defeated"]

	_wall_cells = _wall_cells_near_floor()
	_tex_floor = SpriteLib.tile(SpriteLib.TILE_FLOOR)
	_tex_wall = SpriteLib.tile(SpriteLib.TILE_WALL)
	_tex_chest = SpriteLib.tile(SpriteLib.TILE_CHEST)
	_tex_stairs = SpriteLib.tile(SpriteLib.TILE_STAIRS)
	_tex_enemy = SpriteLib.tile(SpriteLib.TILE_ENEMY_MARKER)
	_tex_player = GameState.party[0].sprite

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
	_hud_label.text = "%s (Stufe %d)   Ebene %d/%d   Gold: %d   Gegner: %d   [1] Heiltrank ×%d  [2] Manatrank ×%d  [I] Inventar  [Esc] Verlassen" \
		% [card.display_name, card.tier, floor_index + 1, card.floor_count, GameState.gold,
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
		KEY_I:
			# Inventar mitten im Dungeon öffnen — zurück geht es an dieselbe Stelle.
			GameState.current_run["player_pos"] = player_pos
			GameState.ui_return_scene = DUNGEON_SCENE_PATH
			get_tree().change_scene_to_file(INVENTORY_SCENE)
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
			GameState.current_run["opened"].append(_floor_id(chest["id"]))
			_chests.erase(chest)
			var message := "Truhe geöffnet: +%d Gold!" % chest["gold"]
			# Truhen enthalten oft zusätzlich Crafting-Materialien.
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			if rng.randf() < 0.5:
				var material := MaterialLibrary.roll(rng)
				var amount := rng.randi_range(1, 2)
				GameState.add_material(material, amount)
				message += "  +%d %s!" % [amount, MaterialLibrary.display_name(material)]
			_show_message(message)
	for enemy in _enemies:
		if player_pos.distance_to(enemy["pos"]) < CONTACT_DIST:
			_start_battle(enemy["id"], false)
			return
	if _boss_alive and player_pos.distance_to(DungeonMap.cell_center_px(map.boss_cell)) < CONTACT_DIST + 8:
		_start_battle(-1, true)
		return
	# Treppe: eine Ebene tiefer (Boss wartet ganz unten).
	if map.stairs_cell.x >= 0 \
			and player_pos.distance_to(DungeonMap.cell_center_px(map.stairs_cell)) < CONTACT_DIST:
		GameState.current_run["floor"] = floor_index + 1
		GameState.current_run["player_pos"] = Vector2.ZERO
		get_tree().reload_current_scene()


func _start_battle(enemy_id: int, is_boss: bool) -> void:
	if _entering_battle:
		return
	_entering_battle = true
	GameState.current_run["player_pos"] = player_pos
	# Encounter deterministisch aus Karten-Seed + Ebene + Gegner-ID: dieselbe
	# Karte liefert beim Farmen immer dieselben Gruppen.
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 31337 + (enemy_id + 2) * 7919
	var foes := EnemyFactory.make_encounter(card, rng, is_boss)
	GameState.pending_battle = {
		"enemy_id": _floor_id(enemy_id) if enemy_id >= 0 else -1,
		"is_boss": is_boss, "enemies": foes,
	}
	get_tree().change_scene_to_file(BATTLE_SCENE)


## Ebenen-eindeutige ID für die Fortschrittslisten im GameState.
func _floor_id(local_id: int) -> int:
	return floor_index * FLOOR_ID_OFFSET + local_id


# --- Abschluss --------------------------------------------------------------------

func _show_completion() -> void:
	_entering_battle = true  # Steuerung einfrieren
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = UiTheme.get_theme()
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
		var rect := Rect2(cell.x * tile, cell.y * tile, tile, tile)
		if _tex_floor != null:
			draw_texture_rect(_tex_floor, rect, false)
		else:
			draw_rect(rect, COLOR_FLOOR)
	# Wände nur dort zeichnen, wo sie an Boden grenzen (sonst bleibt es dunkel).
	if _tex_wall != null:
		for cell in _wall_cells:
			draw_texture_rect(_tex_wall, Rect2(cell.x * tile, cell.y * tile, tile, tile), false)

	for chest in _chests:
		_draw_entity(_tex_chest, chest["pos"], 26, COLOR_CHEST)
	for enemy in _enemies:
		_draw_entity(_tex_enemy, enemy["pos"], 28, COLOR_ENEMY)
	if _boss_alive:
		_draw_entity(_tex_enemy, DungeonMap.cell_center_px(map.boss_cell), 44, COLOR_BOSS)
	if map.stairs_cell.x >= 0:
		_draw_entity(_tex_stairs, DungeonMap.cell_center_px(map.stairs_cell), 30, COLOR_STAIRS)

	_draw_entity(_tex_player, player_pos, 28, COLOR_PLAYER)


func _draw_entity(texture: Texture2D, center: Vector2, size: float, fallback: Color) -> void:
	var rect := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	if texture != null:
		draw_texture_rect(texture, rect, false)
	else:
		draw_rect(rect, fallback)


## Wandzellen, die mindestens eine Bodenzelle als Nachbarn haben (inkl. diagonal).
func _wall_cells_near_floor() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var seen := {}
	for cell in map.floor_cells():
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var neighbor := cell + Vector2i(dx, dy)
				if not map.is_floor(neighbor) and map.in_bounds(neighbor) \
						and not seen.has(neighbor):
					seen[neighbor] = true
					result.append(neighbor)
	return result


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)
	var hud_root := Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.theme = UiTheme.get_theme()
	_hud_layer.add_child(hud_root)
	_hud_label = Label.new()
	_hud_label.position = Vector2(12, 8)
	hud_root.add_child(_hud_label)
	_msg_label = Label.new()
	_msg_label.position = Vector2(12, 34)
	_msg_label.modulate = Color(1.0, 0.9, 0.5)
	hud_root.add_child(_msg_label)


func _show_message(text: String) -> void:
	_msg_label.text = text
	var timer := get_tree().create_timer(2.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_msg_label) and _msg_label.text == text:
			_msg_label.text = "")
