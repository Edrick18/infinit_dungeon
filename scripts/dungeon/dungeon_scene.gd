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
const ENEMY_HALF := 10.0
const CONTACT_DIST := 26.0
const VIEW_MARGIN_CELLS := 3

## Wahrnehmungsreichweite in Pixeln je Temperament — außerhalb dessen
## ignoriert ein Gegner den Spieler komplett.
const AWARENESS_RANGE := {
	Enums.Temperament.AGGRESSIVE: 260.0,
	Enums.Temperament.TERRITORIAL: 150.0,
	Enums.Temperament.SKITTISH: 220.0,
}
## Wie viele Kartenstufen die Party dem Dungeon-Level voraus sein muss,
## damit SKITTISH/TERRITORIAL-Gegner die Flucht ergreifen.
const FLEE_LEVEL_THRESHOLD := 3

## Umherwandern, solange kein Sichtkontakt besteht — macht den Dungeon
## lebendig statt starrer Wächter-Statuen.
const WANDER_LEASH := 90.0
const WANDER_INTERVAL_MIN := 1.5
const WANDER_INTERVAL_MAX := 3.5
const WANDER_SPEED := 30.0

## Fog of War: wie weit der Spieler sieht (in Tiles). Sichtlinie wird
## zusätzlich per Bresenham geprüft — Wände blockieren sie vollständig.
const VISIBILITY_RADIUS_CELLS := 9

const COLOR_FLOOR := Color("2e2e44")
const COLOR_WALL := Color("14141f")
const COLOR_PLAYER := Color("e0e0f0")
const COLOR_ENEMY := Color("d05050")
const COLOR_BOSS := Color("9040c0")
const COLOR_CHEST := Color("d0a840")
const COLOR_STAIRS := Color("50c8d0")
const DIM_TINT := Color(0.4, 0.4, 0.5)

## Sand-Bodentile-Varianten (Kenney-Set) für Abwechslung statt Tapeten-Optik.
const FLOOR_TILE_VARIANTS: Array[int] = [48, 49, 50, 51, 52]

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

## Fog of War: aktuell sichtbare Zellen (Vector2i → true), neu pro Frame.
var _visible_cells: Dictionary = {}
## Jemals gesehene Zellen dieser Ebene — dieselbe Dictionary-Referenz wie in
## GameState.current_run["explored_by_floor"][floor_index], damit sie einen
## Szenenwechsel (z.B. Kampf) übersteht statt jedes Mal leer zu starten.
var _explored_cells: Dictionary = {}

# Pixel-Art (null-sicher: ohne Texturen greifen die Farbformen)
var _tex_floor_variants: Array[Texture2D] = []
var _tex_wall: Texture2D
var _tex_chest: Texture2D
var _tex_stairs: Texture2D
var _tex_enemy: Texture2D  ## Fallback, falls ein Archetyp keine Textur hat
var _tex_boss: Texture2D
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
		var archetype := _archetype_for_enemy(enemy["id"])
		var start_pos := DungeonMap.cell_center_px(enemy["cell"])
		_enemies.append({
			"id": enemy["id"],
			"pos": start_pos,
			"home": start_pos,
			"wander_target": start_pos,
			"wander_timer": randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX),
			"archetype": archetype,
			"sprite": SpriteLib.enemy(archetype.id) if archetype != null else null,
		})
	for chest in map.chests:
		if _floor_id(chest["id"]) in GameState.current_run["opened"]:
			continue
		_chests.append({"id": chest["id"], "gold": chest["gold"],
			"pos": DungeonMap.cell_center_px(chest["cell"])})
	_boss_alive = map.has_boss and not GameState.current_run["boss_defeated"]

	# Fog-of-War-Fortschritt kommt aus dem GameState (dieselbe Dictionary-
	# Referenz!) — so bleibt er nach einem Kampf erhalten. Neu ist er nur
	# bei einer frischen Ebene (neue Karte hier) oder einem neuen Run
	# (GameState.start_run() baut current_run komplett neu auf).
	if not GameState.current_run.has("explored_by_floor"):
		GameState.current_run["explored_by_floor"] = {}
	var explored_by_floor: Dictionary = GameState.current_run["explored_by_floor"]
	if not explored_by_floor.has(floor_index):
		explored_by_floor[floor_index] = {}
	_explored_cells = explored_by_floor[floor_index]

	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # scharfe Pixel-Art
	for variant in FLOOR_TILE_VARIANTS:
		_tex_floor_variants.append(SpriteLib.tile(variant))
	_tex_wall = SpriteLib.tile(SpriteLib.TILE_WALL)
	_tex_chest = SpriteLib.tile(SpriteLib.TILE_CHEST)
	_tex_stairs = SpriteLib.tile(SpriteLib.TILE_STAIRS)
	_tex_enemy = SpriteLib.tile(SpriteLib.TILE_ENEMY_MARKER)
	_tex_boss = _boss_sprite_texture()
	_tex_player = GameState.party[0].sprite

	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_build_hud()
	_update_visibility()

	# Autosave: jedes Betreten/Fortsetzen des Dungeons sichert Fortschritt
	# (Gold/Materialien aus Truhen, besiegte Gegner, Fog of War, Position).
	GameState.current_run["player_pos"] = player_pos
	GameState.save_game()

	if not _boss_alive:
		_show_completion()


func _process(delta: float) -> void:
	if _entering_battle:
		return
	_move_player(delta)
	_move_enemies(delta)
	_update_visibility()
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


## Gegner laufen auf den Spieler zu oder fliehen, sobald sie ihn per
## Sichtlinie erkennen (Wände blockieren das komplett — kein Anschleichen
## mehr durch Wände hindurch); sonst wandern sie ziellos in der Nähe ihres
## Spawnpunkts umher, statt stur stehen zu bleiben.
func _move_enemies(delta: float) -> void:
	var avg_level := _average_party_level()
	var level_diff := card.tier - avg_level  # positiv: Dungeon ist der Party voraus
	var player_cell := _pos_to_cell(player_pos)
	for enemy in _enemies:
		var archetype: EnemyArchetype = enemy.get("archetype")
		if archetype == null:
			continue
		var enemy_pos: Vector2 = enemy["pos"]
		var to_player := player_pos - enemy_pos
		var distance := to_player.length()
		var awareness: float = AWARENESS_RANGE.get(archetype.temperament, 200.0)

		var aware := distance <= awareness \
			and map.has_line_of_sight(_pos_to_cell(enemy_pos), player_cell)
		if not aware:
			_wander(enemy, delta)
			continue

		var should_flee := false
		match archetype.temperament:
			Enums.Temperament.SKITTISH, Enums.Temperament.TERRITORIAL:
				should_flee = level_diff < -FLEE_LEVEL_THRESHOLD
			Enums.Temperament.AGGRESSIVE:
				should_flee = false

		var direction := to_player.normalized()
		if should_flee:
			direction = -direction
		var speed := 40.0 + archetype.base_stats.agility * 6.0
		if should_flee:
			speed *= 1.25  # Flucht ist etwas schneller als Verfolgung.

		var next_pos: Vector2 = enemy_pos + direction * speed * delta
		if _enemy_fits(next_pos):
			enemy["pos"] = next_pos


## Ziellos in der Nähe des Spawnpunkts umherlaufen, solange der Spieler
## außer Sicht ist — wechselt alle paar Sekunden das Ziel.
func _wander(enemy: Dictionary, delta: float) -> void:
	enemy["wander_timer"] = enemy.get("wander_timer", 0.0) - delta
	if enemy["wander_timer"] <= 0.0:
		enemy["wander_timer"] = randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX)
		var home: Vector2 = enemy["home"]
		for attempt in 6:
			var candidate := home + Vector2(
				randf_range(-WANDER_LEASH, WANDER_LEASH),
				randf_range(-WANDER_LEASH, WANDER_LEASH))
			if _enemy_fits(candidate):
				enemy["wander_target"] = candidate
				break
	var target: Vector2 = enemy.get("wander_target", enemy["home"])
	var enemy_pos: Vector2 = enemy["pos"]
	var to_target := target - enemy_pos
	if to_target.length() < 4.0:
		return
	var next_pos := enemy_pos + to_target.normalized() * WANDER_SPEED * delta
	if _enemy_fits(next_pos):
		enemy["pos"] = next_pos


func _pos_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / DungeonMap.TILE_SIZE), floori(pos.y / DungeonMap.TILE_SIZE))


func _enemy_fits(center: Vector2) -> bool:
	for offset in [Vector2(-ENEMY_HALF, -ENEMY_HALF), Vector2(ENEMY_HALF, -ENEMY_HALF),
			Vector2(-ENEMY_HALF, ENEMY_HALF), Vector2(ENEMY_HALF, ENEMY_HALF)]:
		if not map.is_walkable_px(center + offset):
			return false
	return true


func _average_party_level() -> float:
	if GameState.party.is_empty():
		return 1.0
	var total := 0
	for member in GameState.party:
		total += member.level
	return float(total) / GameState.party.size()


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


## Deterministisch aus derselben Seed-Formel wie _start_battle() — welcher
## Archetyp für diesen Gegner-Marker steht, fürs Sprite und Temperament.
func _archetype_for_enemy(local_id: int) -> EnemyArchetype:
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 31337 + (local_id + 2) * 7919
	var pool := EnemyLibrary.archetypes_for_biome(card.biome, false)
	if pool.is_empty():
		return null
	return pool[rng.randi_range(0, pool.size() - 1)]


## Fog of War: welche Zellen der Spieler gerade sieht (Radius + Sichtlinie
## per Bresenham — eine Wand dazwischen blockiert komplett). Bereits
## gesehene Zellen bleiben als "erkundet" (abgedunkelt) im Gedächtnis.
func _update_visibility() -> void:
	_visible_cells.clear()
	var player_cell := _pos_to_cell(player_pos)
	for dy in range(-VISIBILITY_RADIUS_CELLS, VISIBILITY_RADIUS_CELLS + 1):
		for dx in range(-VISIBILITY_RADIUS_CELLS, VISIBILITY_RADIUS_CELLS + 1):
			if dx * dx + dy * dy > VISIBILITY_RADIUS_CELLS * VISIBILITY_RADIUS_CELLS:
				continue
			var cell := player_cell + Vector2i(dx, dy)
			if not map.in_bounds(cell):
				continue
			if map.has_line_of_sight(player_cell, cell):
				_visible_cells[cell] = true
				_explored_cells[cell] = true


func _boss_sprite_texture() -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 31337 + (-1 + 2) * 7919
	var pool := EnemyLibrary.archetypes_for_biome(card.biome, true)
	if pool.is_empty():
		return null
	var archetype: EnemyArchetype = pool[rng.randi_range(0, pool.size() - 1)]
	return SpriteLib.enemy(archetype.id)


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
	var view := _visible_cell_range()
	# Jede JEMALS gesehene Zelle bekommt eine Textur (Boden oder Wand) —
	# aktuell sichtbare Zellen hell, erkundete-aber-nicht-sichtbare abgedunkelt
	# (Fog of War), nie gesehene Zellen bleiben komplett leer.
	for y in range(view[1], view[3]):
		for x in range(view[0], view[2]):
			var cell := Vector2i(x, y)
			if not _explored_cells.has(cell):
				continue
			var tint := Color.WHITE if _visible_cells.has(cell) else DIM_TINT
			var rect := Rect2(x * tile, y * tile, tile, tile)
			if map.is_floor(cell):
				var floor_tex := _floor_texture_for(cell)
				if floor_tex != null:
					draw_texture_rect(floor_tex, rect, false, tint)
				else:
					draw_rect(rect, COLOR_FLOOR * tint)
			else:
				if _tex_wall != null:
					draw_texture_rect(_tex_wall, rect, false, tint)
				else:
					draw_rect(rect, COLOR_WALL * tint)

	# Entities nur zeichnen, wenn ihre Zelle GERADE sichtbar ist — Wände
	# verdecken sie also vollständig, kein Durchgucken mehr.
	for chest in _chests:
		if _visible_cells.has(_pos_to_cell(chest["pos"])):
			_draw_entity(_tex_chest, chest["pos"], 26, COLOR_CHEST)
	for enemy in _enemies:
		if _visible_cells.has(_pos_to_cell(enemy["pos"])):
			var enemy_tex: Texture2D = enemy.get("sprite")
			_draw_entity(enemy_tex if enemy_tex != null else _tex_enemy,
				enemy["pos"], 28, COLOR_ENEMY)
	if _boss_alive and _visible_cells.has(map.boss_cell):
		_draw_entity(_tex_boss if _tex_boss != null else _tex_enemy,
			DungeonMap.cell_center_px(map.boss_cell), 44, COLOR_BOSS)
	if map.stairs_cell.x >= 0 and _visible_cells.has(map.stairs_cell):
		_draw_entity(_tex_stairs, DungeonMap.cell_center_px(map.stairs_cell), 30, COLOR_STAIRS)

	_draw_entity(_tex_player, player_pos, 28, COLOR_PLAYER)


func _draw_entity(texture: Texture2D, center: Vector2, size: float, fallback: Color) -> void:
	var rect := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	if texture != null:
		draw_texture_rect(texture, rect, false)
	else:
		draw_rect(rect, fallback)


## Deterministische Bodentile-Variante pro Zelle (kein Flackern), gegen den
## "Tapeten"-Effekt eines einzelnen, immer gleichen Bodentiles.
func _floor_texture_for(cell: Vector2i) -> Texture2D:
	if _tex_floor_variants.is_empty():
		return null
	var h := (cell.x * 92821) ^ (cell.y * 68917)
	return _tex_floor_variants[absi(h) % _tex_floor_variants.size()]


## Sichtbarer Zellbereich um die Kamera (mit Rand), auf die Kartengrenzen
## begrenzt — [x0, y0, x1, y1) als Halboffen-Intervall für range().
func _visible_cell_range() -> Array[int]:
	var tile := DungeonMap.TILE_SIZE
	var half := get_viewport_rect().size * 0.5
	var top_left := _camera.position - half
	var bottom_right := _camera.position + half
	var x0 := floori(top_left.x / tile) - VIEW_MARGIN_CELLS
	var y0 := floori(top_left.y / tile) - VIEW_MARGIN_CELLS
	var x1 := ceili(bottom_right.x / tile) + VIEW_MARGIN_CELLS
	var y1 := ceili(bottom_right.y / tile) + VIEW_MARGIN_CELLS
	return [maxi(0, x0), maxi(0, y0), mini(map.width, x1), mini(map.height, y1)]


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
