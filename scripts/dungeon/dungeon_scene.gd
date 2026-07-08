extends Node2D
## Begehbarer Dungeon: Top-Down-Ansicht, WASD/Pfeiltasten zum Laufen.
## Gegner sind sichtbar — Berührung startet den Rundenkampf, danach geht es
## an derselben Stelle weiter (das Layout kommt deterministisch aus dem
## Karten-Seed, der Fortschritt liegt im GameState.current_run).

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const COOP_BATTLE_SCENE := "res://scenes/battle/coop_battle_scene.tscn"
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

## Biom-Stile: eigener Wandtile, Farbstimmung und Dekorations-Tiles pro Biom —
## Wald, Höhle, Ruinen und Krypta sehen spürbar unterschiedlich aus.
const BIOME_STYLES := {
	Enums.Biome.FOREST: {
		"wall": 57, "floor_tint": Color(0.88, 1.0, 0.82), "wall_tint": Color(0.85, 1.0, 0.88),
		"deco": [76, 66],   # Zaun, Sack
	},
	Enums.Biome.CAVE: {
		"wall": 57, "floor_tint": Color(0.68, 0.74, 0.9), "wall_tint": Color(0.6, 0.66, 0.85),
		"deco": [56, 102],  # Erdloch, Felsbrocken
	},
	Enums.Biome.RUINS: {
		"wall": 36, "floor_tint": Color(0.85, 0.85, 0.82), "wall_tint": Color(0.95, 0.95, 0.92),
		"deco": [74, 73],   # Amboss, Hocker
	},
	Enums.Biome.CRYPT: {
		"wall": 57, "floor_tint": Color(0.72, 0.62, 0.82), "wall_tint": Color(0.62, 0.52, 0.75),
		"deco": [56, 62],   # Grube, Kratzspuren
	},
}
const DECO_DENSITY := 0.03  ## Anteil der Bodenzellen mit Dekoration

## Gegner-/Truhen-IDs sind pro Ebene eindeutig: floor * FLOOR_ID_OFFSET + id.
const FLOOR_ID_OFFSET := 1000

var map: DungeonMap
var card: DungeonCard
var floor_index := 0
var player_pos := Vector2.ZERO

## Lebende Gegner/ungeöffnete Truhen: {"id", "pos": Vector2, ("gold")}
var _enemies: Array[Dictionary] = []
var _chests: Array[Dictionary] = []
## Unbenutzte Dungeon-Events: {"id", "pos": Vector2, "type": EventType}
var _events: Array[Dictionary] = []
## Opferstein in Reichweite (leer = keiner) — [E] löst ihn aus.
var _sacrifice_nearby: Dictionary = {}
var _boss_alive := true
var _entering_battle := false

var _camera: Camera2D
var _hud_label: Label
var _party_label: Label
var _msg_label: Label
var _hud_layer: CanvasLayer
var _minimap: Minimap

## Fog of War: aktuell sichtbare Zellen (Vector2i » true), neu pro Frame.
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
var _tex_shrine: Texture2D
var _tex_sacrifice: Texture2D
var _tex_risk_chest: Texture2D

## Event-Optik: Textur-Tint + Fallback-Farbe je Event-Typ.
const EVENT_TINTS := {
	DungeonGenerator.EventType.SHRINE_HEAL: Color(0.7, 1.0, 0.7),
	DungeonGenerator.EventType.SHRINE_MANA: Color(0.6, 0.8, 1.0),
	DungeonGenerator.EventType.SHRINE_POWER: Color(1.0, 0.7, 0.5),
	DungeonGenerator.EventType.SHRINE_WARD: Color(1.0, 0.95, 0.6),
	DungeonGenerator.EventType.SACRIFICE: Color(1.0, 0.6, 0.6),
	DungeonGenerator.EventType.RISK_CHEST: Color.WHITE,
}

# Biom-Stimmung + Dekorationen (rein visuell, deterministisch aus dem Seed)
var _floor_tint := Color.WHITE
var _wall_tint := Color.WHITE
var _decorations: Array[Dictionary] = []  ## {"cell": Vector2i, "tex": Texture2D}
var _remote_sprites: Dictionary = {}  ## Co-op: Helden-Name » Texture2D
var _remote_display: Dictionary = {}  ## Co-op: Helden-Name » angezeigte Position (geglättet)


func _ready() -> void:
	Music.play(&"dungeon")
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
			"sprite": SpriteLib.enemy_mini(archetype.id) if archetype != null else null,
		})
	for chest in map.chests:
		if _floor_id(chest["id"]) in GameState.current_run["opened"]:
			continue
		_chests.append({"id": chest["id"], "gold": chest["gold"],
			"rarity": chest.get("rarity", Enums.Rarity.COMMON),
			"pos": DungeonMap.cell_center_px(chest["cell"])})
	# Ältere Spielstände kennen die Event-Liste noch nicht.
	if not GameState.current_run.has("events_used"):
		GameState.current_run["events_used"] = []
	for event in map.events:
		if _floor_id(event["id"]) in GameState.current_run["events_used"]:
			continue
		_events.append({"id": event["id"], "type": event["type"],
			"pos": DungeonMap.cell_center_px(event["cell"])})
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

	# Co-op: Gäste bekommen Welt-Updates des Hosts live eingespielt; der
	# Host schickt seinen Stand (frisch nach Kämpfen/Truhen) an alle Gäste.
	if GameState.coop_guest_run:
		Net.run_updated.connect(_apply_remote_run_state)
		Net.coop_battle_started.connect(_on_coop_battle_started)
		Net.coop_battle_ended.connect(_on_coop_battle_ended)
	elif Net.role == Net.Role.HOST:
		Net.notify_run_update()
		# Gäste dürfen Kämpfe anfordern (Gegner-Berührung in ihrer Ansicht).
		Net.message_received.connect(_on_net_message)

	# Onboarding: Steuerung + Ziel beim allerersten Dungeon-Besuch.
	if not GameState.coop_guest_run and GameState.first_time("dungeon"):
		UiTheme.show_hint(self, Loc.pick("Dein erster Dungeon", "Your first dungeon"),
			Loc.pick("Laufen mit WASD oder den Pfeiltasten. Gegner berühren startet den Kampf, Truhen sammelst du im Vorbeigehen ein.\n\nDie Treppe führt eine Ebene tiefer — der BOSS wartet ganz unten. Fallen gibt es nicht, und die Karte bleibt dir auch bei einer Niederlage erhalten.",
			"Move with WASD or the arrow keys. Touching an enemy starts a battle; chests are collected as you walk by.\n\nThe stairs lead one floor down — the BOSS waits at the very bottom. There are no traps, and you keep the map even if you're defeated."))

	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # scharfe Pixel-Art
	var style: Dictionary = BIOME_STYLES.get(card.biome, BIOME_STYLES[Enums.Biome.FOREST])
	_floor_tint = style["floor_tint"]
	_wall_tint = style["wall_tint"]
	_tex_floor_variants = SpriteLib.floor_variants()
	_tex_wall = SpriteLib.wall(style["wall"])
	_tex_chest = SpriteLib.tile(SpriteLib.TILE_CHEST)
	_tex_stairs = SpriteLib.tile(SpriteLib.TILE_STAIRS)
	_tex_shrine = SpriteLib.tile(SpriteLib.TILE_SHRINE)
	_tex_sacrifice = SpriteLib.tile(SpriteLib.TILE_SACRIFICE)
	_tex_risk_chest = SpriteLib.tile(SpriteLib.TILE_RISK_CHEST)
	_tex_enemy = SpriteLib.tile(SpriteLib.TILE_ENEMY_MARKER)
	_tex_boss = _boss_sprite_texture()
	_tex_player = Net.my_hero_sprite() if GameState.coop_guest_run \
		else GameState.party[0].sprite
	_generate_decorations(style["deco"])

	_camera = Camera2D.new()
	add_child(_camera)
	_camera.make_current()
	_build_hud()
	_update_visibility()

	# Autosave: jedes Betreten/Fortsetzen des Dungeons sichert Fortschritt
	# (Gold/Materialien aus Truhen, besiegte Gegner, Fog of War, Position).
	GameState.current_run["player_pos"] = player_pos
	GameState.save_game()

	# Abgeschlossen ist der Dungeon erst, wenn der Boss der UNTERSTEN Ebene
	# fiel — auf höheren Ebenen gibt es keinen Boss, dort ist _boss_alive
	# immer false (Bug: Mehr-Ebenen-Karten meldeten sofort „abgeschlossen“).
	if map.has_boss and not _boss_alive:
		_show_completion()


func _process(delta: float) -> void:
	if _entering_battle:
		return
	# Co-op-Gast: Session weg oder Host hat die Karte geschlossen » sauber
	# zurück ins eigene Menü (der Run gehörte nie diesem Spielstand).
	if GameState.coop_guest_run and (not Net.is_online() or Net.coop_run_closed):
		GameState.coop_guest_run = false
		GameState.current_run = {}
		Net.coop_run_closed = false
		get_tree().change_scene_to_file(MAIN_SCENE)
		return
	if Net.is_online():
		Net.update_presence(player_pos, floor_index)
		_smooth_remote_players(delta)
	_move_player(delta)
	_move_enemies(delta)
	_update_visibility()
	_check_contacts()
	_camera.position = player_pos
	var depth_note := "" if floor_index == 0 \
		else Loc.pick(" (Gegner +%d)", " (enemies +%d)") % floor_index
	_hud_label.text = Loc.pick(
		"%s (Stufe %d)   Ebene %d/%d%s   Gold: %d   Gegner: %d   [%s] Inventar & Tränke  [Esc] Verlassen",
		"%s (tier %d)   Floor %d/%d%s   Gold: %d   Enemies: %d   [%s] Inventory & potions  [Esc] Leave") \
		% [card.display_name, card.tier, floor_index + 1, card.floor_count, depth_note, GameState.gold,
			_enemies.size() + (1 if _boss_alive else 0),
			Settings.key_name(&"open_inventory")]
	var party_parts: Array[String] = []
	for member in GameState.party:
		if member.is_alive():
			party_parts.append("%s %d/%d" % [member.display_name, member.hp, member.max_hp])
		else:
			party_parts.append("%s †" % member.display_name)
	_party_label.text = "Party:  " + "   ".join(party_parts)
	if _minimap != null:
		_minimap.queue_redraw()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_ESCAPE:
		if GameState.coop_guest_run:
			# Gast verlässt die Karte des Hosts — der Run wird verworfen.
			Net.leave_map()
		else:
			GameState.current_run["player_pos"] = player_pos
		get_tree().change_scene_to_file(MAIN_SCENE)
	elif event.is_action_pressed(&"open_inventory"):
		# Inventar mitten im Dungeon öffnen — zurück geht es an dieselbe Stelle.
		# Tränke und Feldzauber (Heilung/Kuren) werden DORT benutzt.
		GameState.current_run["player_pos"] = player_pos
		GameState.ui_return_scene = DUNGEON_SCENE_PATH
		get_tree().change_scene_to_file(INVENTORY_SCENE)
	elif event.is_action_pressed(&"interact"):
		if not _sacrifice_nearby.is_empty():
			_do_sacrifice(_sacrifice_nearby)


# --- Bewegung -----------------------------------------------------------------

func _move_player(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_action_pressed(&"move_left") or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_action_pressed(&"move_right") or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if Input.is_action_pressed(&"move_up") or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_action_pressed(&"move_down") or Input.is_key_pressed(KEY_DOWN):
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
	# Co-op-Gäste laufen frei mit, aber die Welt gehört dem Host: Truhen,
	# Events und Kämpfe löst (noch) nur er aus — Kampf-Beitritt kommt als
	# nächste Ausbaustufe. Die Treppe dürfen Gäste jederzeit nutzen.
	if GameState.coop_guest_run:
		_check_guest_contacts()
		return
	for chest in _chests.duplicate():
		if player_pos.distance_to(chest["pos"]) < CONTACT_DIST:
			_open_chest(chest)
	# Dungeon-Events: Schreine und Risiko-Truhen lösen bei Berührung aus,
	# der Opferstein verlangt eine bewusste Entscheidung ([E]).
	var near_sacrifice: Dictionary = {}
	for event in _events.duplicate():
		if player_pos.distance_to(event["pos"]) >= CONTACT_DIST:
			continue
		match event["type"]:
			DungeonGenerator.EventType.SACRIFICE:
				near_sacrifice = event
			DungeonGenerator.EventType.RISK_CHEST:
				_open_risk_chest(event)
				if _entering_battle:
					return
			_:
				_use_shrine(event)
	if not near_sacrifice.is_empty() and _sacrifice_nearby.is_empty():
		_show_message(Loc.pick("Ein Opferstein … [%s]: Jeder Held opfert 15%% Max-HP für Schätze.",
			"A sacrifice stone … [%s]: every hero sacrifices 15%% max HP for treasure.")
			% Settings.key_name(&"interact"))
	_sacrifice_nearby = near_sacrifice
	for enemy in _enemies:
		# Flucht-Schonfrist: der Gegner, vor dem wir gerade geflohen sind,
		# schnappt erst wieder zu, wenn die Party auf Abstand war.
		if _floor_id(enemy["id"]) == GameState.flee_grace_enemy:
			if player_pos.distance_to(enemy["pos"]) > CONTACT_DIST * 2.5:
				GameState.flee_grace_enemy = -1
			continue
		if player_pos.distance_to(enemy["pos"]) < CONTACT_DIST:
			_start_battle(enemy["id"], false)
			return
	if _boss_alive and player_pos.distance_to(DungeonMap.cell_center_px(map.boss_cell)) < CONTACT_DIST + 8:
		_start_battle(-1, true)
		return
	# Treppe: eine Ebene tiefer (Boss wartet ganz unten).
	if map.stairs_cell.x >= 0 \
			and player_pos.distance_to(DungeonMap.cell_center_px(map.stairs_cell)) < CONTACT_DIST:
		Sfx.play(&"treppe")
		GameState.current_run["floor"] = floor_index + 1
		GameState.current_run["player_pos"] = Vector2.ZERO
		get_tree().reload_current_scene()


# --- Co-op --------------------------------------------------------------------

var _guest_hint_ms := 0
## Drossel für Kampf-Anforderungen an den Host (kein Nachrichten-Spam).
var _contact_sent_ms := 0


## Truhe öffnen — für Host UND Gäste: Truhen sind PRO SPIELER (Spieltest-
## Wunsch: beide dürfen öffnen, ohne sie dem anderen wegzunehmen). Die
## Beute landet im eigenen Spielstand; "opened" ist nur noch lokal.
func _open_chest(chest: Dictionary) -> void:
	GameState.gold += chest["gold"]
	GameState.current_run["opened"].append(_floor_id(chest["id"]))
	_chests.erase(chest)
	var rarity: Enums.Rarity = chest["rarity"]
	var message := "%se Truhe: +%d Gold!" % [LootGenerator.RARITY_NAMES[rarity],
		chest["gold"]]
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	# Jede Truhe enthält genau EIN Item — die Truhen-Rarität bestimmt
	# dessen Rarität (nicht die Häufigkeit).
	var item := LootGenerator.roll_item_with_rarity(card.tier, rarity, rng)
	GameState.inventory.append(item)
	message += "  %s!" % item.get_display_name()
	# Selten liegt eine Mini-Medaille obendrauf (Händler-Tauschware).
	if rng.randf() < 0.12:
		GameState.medals += 1
		message += Loc.pick("  +1 Mini-Medaille!", "  +1 mini medal!")
	# Truhen enthalten oft zusätzlich Crafting-Materialien.
	if rng.randf() < 0.5:
		var material := MaterialLibrary.roll(rng)
		var amount := rng.randi_range(1, 2)
		GameState.add_material(material, amount)
		message += "  +%d %s!" % [amount, MaterialLibrary.display_name(material)]
	Sfx.play(&"gold")
	_show_message(message)


## Gast-Kontaktprüfung: Truhen öffnet der Gast selbst (eigene Beute),
## Gegner-/Boss-Berührung FORDERT den Kampf beim Host an (der zieht alle
## Mitspieler derselben Ebene hinein) — Spieltest: „Gäste sollen Kämpfe
## auslösen und Truhen öffnen können“.
func _check_guest_contacts() -> void:
	for chest in _chests.duplicate():
		if player_pos.distance_to(chest["pos"]) < CONTACT_DIST:
			_open_chest(chest)
	var now := Time.get_ticks_msec()
	if now - _contact_sent_ms > 1500:
		for enemy in _enemies:
			if player_pos.distance_to(enemy["pos"]) < CONTACT_DIST:
				_contact_sent_ms = now
				Net.send_to_host("guest_contact",
					{"enemy": enemy["id"], "floor": floor_index})
				_show_message(Loc.pick("Kampf angefordert — der Host zieht euch hinein …",
					"Battle requested — the host pulls you in …"))
				break
		if _boss_alive and player_pos.distance_to(
				DungeonMap.cell_center_px(map.boss_cell)) < CONTACT_DIST + 8:
			_contact_sent_ms = now
			Net.send_to_host("guest_contact", {"boss": true, "floor": floor_index})
	if map.stairs_cell.x >= 0 \
			and player_pos.distance_to(DungeonMap.cell_center_px(map.stairs_cell)) < CONTACT_DIST:
		Sfx.play(&"treppe")
		GameState.current_run["floor"] = floor_index + 1
		GameState.current_run["player_pos"] = Vector2.ZERO
		get_tree().reload_current_scene()


## Host: Ein Gast hat einen Gegner berührt — Kampf starten, wenn der Host
## auf DERSELBEN Ebene ist (Kämpfe ziehen nur Ebenen-Genossen hinein).
func _on_net_message(_peer_id: int, type: String, data: Dictionary) -> void:
	if type != "guest_contact" or _entering_battle:
		return
	if int(data.get("floor", -99)) != floor_index:
		return
	if bool(data.get("boss", false)):
		if _boss_alive:
			_start_battle(-1, true)
		return
	var enemy_id := int(data.get("enemy", -1))
	for enemy in _enemies:
		if int(enemy["id"]) == enemy_id:
			_start_battle(enemy_id, false)
			return


## Welt-Update vom Host: besiegte Gegner, geleerte Truhen und verbrauchte
## Events auch lokal ausblenden.
func _apply_remote_run_state() -> void:
	for enemy in _enemies.duplicate():
		if _floor_id(enemy["id"]) in GameState.current_run["defeated"]:
			_enemies.erase(enemy)
	for chest in _chests.duplicate():
		if _floor_id(chest["id"]) in GameState.current_run["opened"]:
			_chests.erase(chest)
	for event in _events.duplicate():
		if _floor_id(event["id"]) in GameState.current_run["events_used"]:
			_events.erase(event)
	_boss_alive = map.has_boss and not GameState.current_run["boss_defeated"]
	queue_redraw()


## Host-Seite: nach jeder Welt-Änderung den Stand an alle Gäste schicken.
func _notify_coop_state() -> void:
	if Net.role == Net.Role.HOST:
		Net.notify_run_update()


## Netz-Positionen kommen ~12×/s — die Anzeige gleitet mit Spieler-Tempo
## hinterher, damit Mitspieler flüssig laufen statt zu teleportieren.
func _smooth_remote_players(delta: float) -> void:
	for who in Net.remote_players:
		var target: Vector2 = Net.remote_players[who]["pos"]
		var current: Vector2 = _remote_display.get(who, target)
		if current.distance_to(target) > 120.0:
			current = target  # Ebenenwechsel/Teleport: nicht quer laufen
		else:
			current = current.move_toward(target, SPEED * 1.3 * delta)
		_remote_display[who] = current
	for who in _remote_display.keys():
		if not Net.remote_players.has(who):
			_remote_display.erase(who)


## Gast: Der Host hat einen Kampf begonnen — kämpft mein Held mit?
func _on_coop_battle_started(data: Dictionary) -> void:
	var host_name := String(data.get("host", "?"))
	var fighters: Array = data.get("fighters", [])
	if Net.my_hero_name() in fighters:
		# Mein Held kämpft mit » eigene Kampfansicht öffnen: Der Gast wählt
		# die Aktionen seines Helden selbst (Kommandophase beim Host).
		GameState.current_run["player_pos"] = player_pos
		GameState.coop_battle = data
		get_tree().change_scene_to_file(COOP_BATTLE_SCENE)
	else:
		_show_message(Loc.pick("%s kämpft auf einer anderen Ebene — du bist nicht dabei.",
			"%s is fighting on another floor — you are not part of it.") % host_name)


func _on_coop_battle_ended(data: Dictionary) -> void:
	if bool(data.get("victory", false)):
		_show_message(Loc.pick("Der Kampf ist gewonnen!", "The battle is won!"))
	elif bool(data.get("fled", false)):
		_show_message(Loc.pick("Die Party ist geflohen.", "The party fled."))
	else:
		_show_message(Loc.pick("Die Party wurde besiegt …", "The party was defeated …"))


# --- Dungeon-Events ---------------------------------------------------------------

## Event als verbraucht markieren (überlebt Kämpfe und Speichern/Laden).
func _consume_event(event: Dictionary) -> void:
	GameState.current_run["events_used"].append(_floor_id(event["id"]))
	_events.erase(event)
	_notify_coop_state()


func _use_shrine(event: Dictionary) -> void:
	_consume_event(event)
	match event["type"]:
		DungeonGenerator.EventType.SHRINE_HEAL:
			for member in GameState.party:
				if member.is_alive():
					member.heal(roundi(member.max_hp * 0.4))
			_show_message("Heilschrein: Die Party wird um 40% Max-HP geheilt!")
		DungeonGenerator.EventType.SHRINE_MANA:
			for member in GameState.party:
				if member.is_alive():
					member.mp = mini(member.max_mp, member.mp + roundi(member.max_mp * 0.4))
			_show_message("Manaschrein: Die Party erhält 40% Max-MP zurück!")
		DungeonGenerator.EventType.SHRINE_POWER:
			GameState.current_run["blessing"] = &"segen_kraft"
			_show_message("Kraftschrein: Der nächste Kampf beginnt mit Angriff +25% (3 Runden)!")
		DungeonGenerator.EventType.SHRINE_WARD:
			GameState.current_run["blessing"] = &"segen_schutz"
			_show_message("Schutzschrein: Der nächste Kampf beginnt mit erhöhter Rüstung (3 Runden)!")
	Sfx.play(&"schrein")
	GameState.save_game()


## Risiko-Truhe: dicke Beute — oder ein Mimic schnappt zu (50/50).
func _open_risk_chest(event: Dictionary) -> void:
	_consume_event(event)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() < 0.5:
		_start_mimic_battle(event)
		return
	var gold := roundi((30 + card.tier * 15 + rng.randi_range(0, 20)) * 2.0)
	GameState.gold += gold
	var item := LootGenerator.roll_item(card.tier, rng)
	GameState.inventory.append(item)
	GameState.add_material(MaterialLibrary.roll(rng), 2)
	GameState.medals += 1  # Risiko belohnt: garantierte Mini-Medaille
	GameState.save_game()
	Sfx.play(&"truhe")
	_show_message("Risiko-Truhe: +%d Gold, %s (%s) und Materialien!"
		% [gold, item.get_display_name(), LootGenerator.RARITY_NAMES[item.rarity]])


func _start_mimic_battle(event: Dictionary) -> void:
	if _entering_battle:
		return
	_entering_battle = true
	GameState.current_run["player_pos"] = player_pos
	Sfx.play(&"mimic")
	_show_message("Die Truhe lebt — ein Mimic!")
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 31337 + (event["id"] + 500) * 7919
	var mimic := EnemyFactory.build(EnemyLibrary.get_archetype(&"mimic"), card.tier + 1, rng)
	mimic.loot_mult = 2.5
	var foes: Array[Combatant] = [mimic]
	GameState.pending_battle = {
		# Junk-ID weit außerhalb der Gegner-IDs: der Sieg-Pfad hakt sie in
		# "defeated" ab, ohne je mit einem echten Gegner zu kollidieren.
		"enemy_id": 900000 + _floor_id(event["id"]),
		"is_boss": false, "enemies": foes,
	}
	get_tree().change_scene_to_file(BATTLE_SCENE)


## Opferstein: jeder lebende Held zahlt 15% Max-HP (überlebt garantiert),
## dafür gibt es Gold und Materialien — Risiko gegen Belohnung, keine Falle.
func _do_sacrifice(event: Dictionary) -> void:
	_consume_event(event)
	_sacrifice_nearby = {}
	for member in GameState.party:
		if member.is_alive():
			member.hp = maxi(1, member.hp - roundi(member.max_hp * 0.15))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var gold := 40 + card.tier * 12 + rng.randi_range(0, 25)
	GameState.gold += gold
	GameState.add_material(MaterialLibrary.roll(rng), 2)
	GameState.add_material(MaterialLibrary.roll(rng), 1)
	GameState.save_game()
	Sfx.play(&"opferstein")
	_show_message("Der Opferstein nimmt euer Blut: +%d Gold und Materialien." % gold)


func _start_battle(enemy_id: int, is_boss: bool) -> void:
	if _entering_battle:
		return
	_entering_battle = true
	GameState.current_run["player_pos"] = player_pos
	# Encounter deterministisch aus Karten-Seed + Ebene + Gegner-ID: dieselbe
	# Karte liefert beim Farmen immer dieselben Gruppen. Tiefere Ebenen
	# sind stärker (+1 Stufe pro Ebene — DQ9-Prinzip).
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 31337 + (enemy_id + 2) * 7919
	var foes := EnemyFactory.make_encounter(card, rng, is_boss, floor_index)
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
	# Pool-Stufe MUSS make_encounter entsprechen (inkl. Raritäts-Bonus),
	# sonst zeigen Marker und Kampf verschiedene Monster.
	var pool := EnemyLibrary.archetypes_for_biome(card.biome, false,
		card.tier + floor_index + card.rarity_level_bonus())
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


## Verstreut Dekorations-Tiles auf freien Bodenzellen — deterministisch aus
## dem Karten-Seed, rein visuell (keine Kollision, kein Gameplay).
func _generate_decorations(deco_tiles: Array) -> void:
	_decorations.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 4271
	var blocked := {}
	blocked[map.spawn] = true
	blocked[map.boss_cell] = true
	blocked[map.stairs_cell] = true
	for enemy in map.enemies:
		blocked[enemy["cell"]] = true
	for chest in map.chests:
		blocked[chest["cell"]] = true
	for event in map.events:
		blocked[event["cell"]] = true
	for cell in map.floor_cells():
		if blocked.has(cell) or rng.randf() > DECO_DENSITY:
			continue
		var tile_index: int = deco_tiles[rng.randi_range(0, deco_tiles.size() - 1)]
		var texture := SpriteLib.tile(tile_index)
		if texture != null:
			_decorations.append({"cell": cell, "tex": texture})


func _boss_sprite_texture() -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 31337 + (-1 + 2) * 7919
	var pool := EnemyLibrary.archetypes_for_biome(card.biome, true,
		card.tier + floor_index)
	if pool.is_empty():
		pool = EnemyLibrary.archetypes_for_biome(card.biome, true)
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
	label.text = Loc.pick("Dungeon abgeschlossen!", "Dungeon complete!")
	label.add_theme_font_size_override("font_size", 32)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)

	var reward: DungeonCard = GameState.current_run.get("reward")
	if reward != null:
		var note := Label.new()
		note.text = Loc.pick("Belohnung: %s (Stufe %d)", "Reward: %s (tier %d)") % [reward.display_name, reward.tier]
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(note)
		if not reward.card_affix_ids.is_empty():
			var affix_note := Label.new()
			var affix_parts: Array[String] = []
			for id in reward.card_affix_ids:
				affix_parts.append(CardFactory.card_affix_name(id))
			affix_note.text = "★ " + ", ".join(affix_parts)
			affix_note.modulate = Color(1.0, 0.85, 0.4)
			affix_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(affix_note)
		if not GameState.current_run.get("reward_added", true):
			var lost := Label.new()
			lost.text = Loc.pick("Kartenlager voll — die Karte ist verloren!", "Map storage full — the map is lost!")
			lost.modulate = Color(1.0, 0.5, 0.4)
			lost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			box.add_child(lost)

	var back := Button.new()
	back.text = Loc.pick("Zurück zum Hub", "Back to hub")
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
			var visible := _visible_cells.has(cell)
			var rect := Rect2(x * tile, y * tile, tile, tile)
			if map.is_floor(cell):
				var tint := _floor_tint if visible else _floor_tint * DIM_TINT
				var floor_tex := _floor_texture_for(cell)
				if floor_tex != null:
					draw_texture_rect(floor_tex, rect, false, tint)
				else:
					draw_rect(rect, COLOR_FLOOR * tint)
			else:
				var tint := _wall_tint if visible else _wall_tint * DIM_TINT
				if _tex_wall != null:
					draw_texture_rect(_tex_wall, rect, false, tint)
				else:
					draw_rect(rect, COLOR_WALL * tint)

	# Dekorationen (auf erkundeten Zellen, gedimmt außerhalb der Sicht).
	for deco in _decorations:
		var deco_cell: Vector2i = deco["cell"]
		if not _explored_cells.has(deco_cell):
			continue
		var deco_tint := Color.WHITE if _visible_cells.has(deco_cell) else DIM_TINT
		draw_texture_rect(deco["tex"],
			Rect2(deco_cell.x * tile, deco_cell.y * tile, tile, tile), false, deco_tint)

	# Entities nur zeichnen, wenn ihre Zelle GERADE sichtbar ist — Wände
	# verdecken sie also vollständig, kein Durchgucken mehr.
	for chest in _chests:
		if _visible_cells.has(_pos_to_cell(chest["pos"])):
			# Truhen-Tint verrät die Rarität des Inhalts schon von Weitem.
			var chest_tint: Color = LootGenerator.RARITY_COLORS.get(
				chest["rarity"], Color.WHITE)
			_draw_entity(_tex_chest, chest["pos"], 26, COLOR_CHEST, chest_tint)
	for event in _events:
		if _visible_cells.has(_pos_to_cell(event["pos"])):
			var event_type: DungeonGenerator.EventType = event["type"]
			var tint: Color = EVENT_TINTS.get(event_type, Color.WHITE)
			var tex := _tex_shrine
			match event_type:
				DungeonGenerator.EventType.SACRIFICE:
					tex = _tex_sacrifice
				DungeonGenerator.EventType.RISK_CHEST:
					tex = _tex_risk_chest
			_draw_entity(tex, event["pos"], 28, tint, tint)
	for enemy in _enemies:
		if _visible_cells.has(_pos_to_cell(enemy["pos"])):
			var enemy_tex: Texture2D = enemy.get("sprite")
			_draw_entity(enemy_tex if enemy_tex != null else _tex_enemy,
				enemy["pos"], 40, COLOR_ENEMY)
	if _boss_alive and _visible_cells.has(map.boss_cell):
		_draw_entity(_tex_boss if _tex_boss != null else _tex_enemy,
			DungeonMap.cell_center_px(map.boss_cell), 64, COLOR_BOSS)
	if map.stairs_cell.x >= 0 and _visible_cells.has(map.stairs_cell):
		_draw_entity(_tex_stairs, DungeonMap.cell_center_px(map.stairs_cell), 30, COLOR_STAIRS)

	# Co-op-Mitspieler auf derselben Ebene — bewusst auch durch den Fog
	# sichtbar (man soll den Partner ja finden können). Gezeichnet wird die
	# GEGLÄTTETE Position (Interpolation gegen das 12-Hz-Netz-Ruckeln).
	for who in Net.remote_players:
		var info: Dictionary = Net.remote_players[who]
		if int(info["floor"]) != floor_index:
			continue
		var mate_pos: Vector2 = _remote_display.get(who, info["pos"])
		if not _remote_sprites.has(who):
			var portrait := int(info.get("tile", -1))
			_remote_sprites[who] = SpriteLib.tile(portrait) if portrait >= 0 \
				else SpriteLib.hero(who)
		_draw_entity(_remote_sprites[who], mate_pos, 28, COLOR_PLAYER,
			Color(1, 1, 1, 0.9))
		draw_string(ThemeDB.fallback_font, mate_pos + Vector2(-40, -18), who,
			HORIZONTAL_ALIGNMENT_CENTER, 80, 10, Color(0.75, 0.9, 1.0, 0.9))

	_draw_entity(_tex_player, player_pos, 28, COLOR_PLAYER)


func _draw_entity(texture: Texture2D, center: Vector2, size: float, fallback: Color,
		tint := Color.WHITE) -> void:
	var rect := Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size))
	if texture != null:
		draw_texture_rect(texture, rect, false, tint)
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
	# Halbtransparente Tafel hinter den HUD-Zeilen — lesbar auf jedem Biom.
	var hud_panel := PanelContainer.new()
	hud_panel.position = Vector2(6, 4)
	hud_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_style := StyleBoxFlat.new()
	hud_style.bg_color = Color(0.05, 0.05, 0.12, 0.72)
	hud_style.set_corner_radius_all(6)
	hud_style.content_margin_left = 10
	hud_style.content_margin_right = 10
	hud_style.content_margin_top = 5
	hud_style.content_margin_bottom = 5
	hud_panel.add_theme_stylebox_override("panel", hud_style)
	hud_root.add_child(hud_panel)
	var hud_box := VBoxContainer.new()
	hud_box.add_theme_constant_override("separation", 2)
	hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_panel.add_child(hud_box)
	_hud_label = Label.new()
	hud_box.add_child(_hud_label)
	_party_label = Label.new()
	_party_label.add_theme_font_size_override("font_size", 12)
	_party_label.modulate = Color(1, 1, 1, 0.85)
	hud_box.add_child(_party_label)
	_msg_label = Label.new()
	_msg_label.modulate = Color(1.0, 0.9, 0.5)
	hud_box.add_child(_msg_label)

	# Minimap oben rechts: erkundete Zellen, Spieler, Treppe/Boss, Truhen.
	_minimap = Minimap.new()
	_minimap.dungeon = self
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_minimap.offset_left = -(map.width * Minimap.CELL + 12)
	_minimap.offset_right = -12
	_minimap.offset_top = 12
	_minimap.offset_bottom = 12 + map.height * Minimap.CELL
	hud_root.add_child(_minimap)


func _show_message(text: String) -> void:
	_msg_label.text = text
	var timer := get_tree().create_timer(2.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_msg_label) and _msg_label.text == text:
			_msg_label.text = "")
