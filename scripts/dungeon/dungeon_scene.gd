extends Node2D
## Begehbarer Dungeon: Top-Down-Ansicht, WASD/Pfeiltasten zum Laufen.
## Gegner sind sichtbar — Berührung startet den Rundenkampf, danach geht es
## an derselben Stelle weiter (das Layout kommt deterministisch aus dem
## Karten-Seed, der Fortschritt liegt im GameState.current_run).

const BATTLE_SCENE := "res://scenes/battle/battle_scene.tscn"
const COOP_BATTLE_SCENE := "res://scenes/battle/coop_battle_scene.tscn"
const MAIN_SCENE := "res://scenes/main.tscn"
const INVENTORY_SCENE := "res://scenes/inventory/inventory_scene.tscn"
const WORKSHOP_SCENE := "res://scenes/workshop/skill_workshop.tscn"
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
## Verfolgung: Gegner geben auf, wenn der Spieler weiter als Wahrnehmung ×
## AUFGEBEN_FAKTOR weg ist oder nach Sichtverlust die letzte bekannte
## Position abgesucht ist (SUCH_DAUER). Hysterese: anspringen erst wieder,
## wenn der Spieler in die normale Wahrnehmungsreichweite kommt.
const AUFGEBEN_FAKTOR := 1.6
const SUCH_DAUER := 1.2
## Kurventrägheit: Gegner drehen höchstens DREH_TEMPO (rad/s) und werden in
## Kurven langsamer (bis KURVEN_TEMPO_MIN) — so kann man sie um Säulen und
## Ecken herum abhängen ("Looping"), auf Geraden bleiben sie gefährlich.
const DREH_TEMPO := 2.6
const KURVEN_TEMPO_MIN := 0.45
## Jäger (Agilität ab JAEGER_AB_AGILITAET) sind auf Geraden SCHNELLER als
## der Spieler — wegrennen reicht nicht, man muss sie per Looping/Ecken
## abhängen. Brocken darunter bleiben gemütlich (alte Formel).
const JAEGER_AB_AGILITAET := 7
const JAEGER_TEMPO_PRO_AGI := 0.04  ## Anteil von SPEED je Agilität über 6
const JAEGER_TEMPO_MAX := 1.25      ## Deckel: max. 125 % Spielertempo
## Wie lange "!" (entdeckt) und "?" (aufgegeben) über dem Gegner stehen.
const MARKER_DAUER := 0.9
## Wie viele Kartenstufen die Party dem Dungeon-Level voraus sein muss,
## damit SKITTISH/TERRITORIAL-Gegner die Flucht ergreifen.
const FLEE_LEVEL_THRESHOLD := 3

## Überlegenheit (DQ): Party so viele Level über den Gegnern » alle fliehen,
## Berühren = Sofortsieg mit halber XP und halbem Gold, ohne Items.
const UEBERLEGEN_AB := 8
const SOFORTSIEG_ANTEIL := 0.5

## Umherwandern, solange kein Sichtkontakt besteht — macht den Dungeon
## lebendig statt starrer Wächter-Statuen.
const WANDER_LEASH := 90.0
const WANDER_INTERVAL_MIN := 1.5
const WANDER_INTERVAL_MAX := 3.5
const WANDER_SPEED := 30.0


const DECO_DENSITY := 0.03  ## Anteil der Bodenzellen mit Dekoration

## Gegner-/Truhen-IDs sind pro Ebene eindeutig: floor * FLOOR_ID_OFFSET + id.
const FLOOR_ID_OFFSET := 1000

var map: DungeonMap
var card: DungeonCard
var floor_index := 0
var player_pos := Vector2.ZERO
## Blickrichtung des Helden auf der Karte (letzte Laufrichtung) — für Hinterhalte.
var _blick := Vector2(0, 1)

## Lebende Gegner/ungeöffnete Truhen: {"id", "pos": Vector2, ("gold")}
var _enemies: Array[Dictionary] = []
## Dynamische Gegner: Höchstzahl gleichzeitig, Würfel und Zeit bis zum Nachrücken.
var _gegner_max := 0
var _nachschub_rng := RandomNumberGenerator.new()
var _nachschub_timer := 0.0
var _chests: Array[Dictionary] = []
## Unbenutzte Dungeon-Events: {"id", "pos": Vector2, "type": EventType}
var _events: Array[Dictionary] = []
## Opferstein in Reichweite (leer = keiner) — [E] löst ihn aus.
var _sacrifice_nearby: Dictionary = {}
var _boss_alive := true
## Ebenen-Ziel Tresor: {} = keiner (oder schon geöffnet), sonst {"pos": Vector2}.
var _tresor: Dictionary = {}
var _tresor_nah := false
var _entering_battle := false

var _welt: DungeonWelt3D  ## 3D-Darstellung (reine Anzeige, siehe STIL-3D.md)
var _hud: DungeonHud
var _hud_layer: CanvasLayer
var _minimap: Minimap

## Zellen im aktuellen Bildausschnitt (Vector2i » true), neu pro Frame.
var _visible_cells: Dictionary = {}
## Jemals im Bild gewesene Zellen dieser Ebene (Minimap) — dieselbe
## Dictionary-Referenz wie in
## GameState.current_run["explored_by_floor"][floor_index], damit sie einen
## Szenenwechsel (z.B. Kampf) übersteht statt jedes Mal leer zu starten.
var _explored_cells: Dictionary = {}

# Dekorationen (rein visuell, deterministisch aus dem Seed)
var _decorations: Array[Dictionary] = []  ## {"cell": Vector2i, "art": String}
var _remote_display: Dictionary = {}  ## Co-op: Helden-Name » angezeigte Position (geglättet)


func _ready() -> void:
	if GameState.current_run.is_empty():
		# Szene direkt gestartet (F6): Testkarte anlegen.
		GameState.start_run(CardFactory.make_starter_card())
	Music.play(Music.biom_track(GameState.current_run["card"].biome))

	card = GameState.current_run["card"]
	floor_index = GameState.current_run.get("floor", 0)
	map = DungeonGenerator.generate(card, floor_index)

	var saved: Vector2 = GameState.current_run["player_pos"]
	player_pos = saved if saved != Vector2.ZERO else DungeonMap.cell_center_px(map.spawn)

	if not GameState.current_run.has("tresore"):
		GameState.current_run["tresore"] = []
	if map.tresor_cell.x >= 0 and floor_index not in GameState.current_run["tresore"]:
		_tresor = {"pos": DungeonMap.cell_center_px(map.tresor_cell)}
	# Gegner-Bestand der Ebene (dynamisch: kommen und gehen, siehe GegnerNachschub).
	_gegner_max = map.enemies.size()
	_nachschub_rng.randomize()
	_nachschub_timer = GegnerNachschub.nachschub_zeit(_nachschub_rng)
	for eintrag in GegnerNachschub.bestand(GameState.current_run, map, floor_index, FLOOR_ID_OFFSET):
		_gegner_hinzufuegen(int(eintrag[0]), Vector2i(int(eintrag[1]), int(eintrag[2])))
	for chest in map.chests:
		if _floor_id(chest["id"]) in GameState.current_run["opened"]:
			continue
		_chests.append({"id": chest["id"], "gold": chest["gold"],
			"rarity": chest.get("rarity", Enums.Rarity.COMMON),
			"mimic": chest.get("mimic", false),
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
			Loc.pick("Laufen mit WASD oder den Pfeiltasten, Mausrad zoomt. Gegner berühren startet den Kampf, Truhen sammelst du im Vorbeigehen ein.\n\nGegner sehen nur nach vorn: Erwischst du einen von HINTEN, bekommt deine Party eine freie Runde (Erstschlag). Erwischt dich ein Verfolger von hinten, schlägt er zuerst zu (Hinterhalt).\n\nDie Treppe führt eine Ebene tiefer — der BOSS wartet ganz unten. Fallen gibt es nicht, und die Karte bleibt dir auch bei einer Niederlage erhalten.",
			"Move with WASD or the arrow keys, mouse wheel zooms. Touching an enemy starts a battle; chests are collected as you walk by.\n\nEnemies only look ahead: catch one from BEHIND and your party gets a free round (preemptive strike). If a pursuer catches you from behind, it strikes first (ambush).\n\nThe stairs lead one floor down — the BOSS waits at the very bottom. There are no traps, and you keep the map even if you're defeated."))

	var style := DungeonWelt3D.biom_stil(card.biome)
	_generate_decorations(style["deco"])
	_welt = DungeonWelt3D.new()
	add_child(_welt)
	_welt.aufbauen(map, style["floor_tint"], style["wall_tint"], _decorations, player_pos)
	_build_hud()
	_update_visibility()
	_ebenen_hinweis()

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
	if not GameState.coop_guest_run:
		_gegner_nachschub(delta)
	_update_visibility()
	_check_contacts()
	if _entering_battle:
		return  # Szenenwechsel läuft — Welt nicht mehr anfassen
	_welt.aktualisieren(delta, self)
	var depth_note := "" if floor_index == 0 \
		else Loc.pick("  (Gegner +%d)", "  (enemies +%d)") % floor_index
	_hud.aktualisieren(card.display_name, {
		"stufe": Loc.pick("Stufe %d", "Tier %d") % card.tier,
		"ebene": Loc.pick("Ebene %d/%d", "Floor %d/%d") % [floor_index + 1, card.floor_count] + depth_note,
		"gegner": Loc.pick("Gegner %d", "Enemies %d") % (_enemies.size() + (1 if _boss_alive else 0)),
		"gold": "Gold %d" % GameState.gold,
		"regel": Sonderregeln.name_von(card),
		"tresor": "" if _tresor.is_empty() else (Loc.pick("Tresor: Schlüssel da", "Vault: key found")
			if hat_schluessel() else Loc.pick("Tresor: Schlüssel fehlt", "Vault: key missing")),
	}, GameState.party)
	if _minimap != null:
		_minimap.queue_redraw()


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
	elif event.is_action_pressed(&"open_workshop") and not GameState.coop_guest_run:
		# Skills umbauen geht überall außer im Kampf — auch mitten im Dungeon.
		GameState.current_run["player_pos"] = player_pos
		GameState.ui_return_scene = DUNGEON_SCENE_PATH
		get_tree().change_scene_to_file(WORKSHOP_SCENE)
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
	# 45°-Kamera: "W" heißt "nach oben im Bild", nicht "Karten-Norden".
	dir = _welt.bildschirm_zu_karte(dir)
	_blick = dir.normalized()
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


## Gegner sehen den Spieler nur per Sichtlinie (Wände blockieren komplett)
## und nur in Wahrnehmungsreichweite. Einmal entdeckt, jagen sie ihn —
## verlieren sie den Sichtkontakt (Spieler biegt um die Ecke), suchen sie
## kurz die letzte bekannte Stelle ab und geben dann auf; ebenso, wenn der
## Spieler zu weit weg ist. Kurven kosten Tempo (siehe DREH_TEMPO).
func _move_enemies(delta: float) -> void:
	var avg_level := _average_party_level()
	var level_diff := card.tier - avg_level  # positiv: Dungeon ist der Party voraus
	var player_cell := _pos_to_cell(player_pos)
	var ueberlegen := _ueberlegen()
	for enemy in _enemies:
		enemy["marker_zeit"] = maxf(0.0, enemy.get("marker_zeit", 0.0) - delta)
		var archetype: EnemyArchetype = enemy.get("archetype")
		if archetype == null:
			continue
		var enemy_pos: Vector2 = enemy["pos"]
		var distance := enemy_pos.distance_to(player_pos)
		var awareness: float = AWARENESS_RANGE.get(archetype.temperament, 200.0)
		var sieht := distance <= awareness * AUFGEBEN_FAKTOR \
			and map.has_line_of_sight(_pos_to_cell(enemy_pos), player_cell)
		var jagd: bool = enemy.get("jagd", false)

		if not jagd:
			if sieht and distance <= awareness and _bemerkt(enemy, enemy_pos, distance):
				enemy["jagd"] = true
				enemy["such_zeit"] = SUCH_DAUER
				_setze_marker(enemy, "!")
			else:
				_wander(enemy, delta)
				continue
		elif distance > awareness * AUFGEBEN_FAKTOR:
			_aufgeben(enemy)
			_wander(enemy, delta)
			continue

		var ziel := player_pos
		if sieht:
			enemy["zuletzt_gesehen"] = player_pos
			enemy["such_zeit"] = SUCH_DAUER
		else:
			# Kein Sichtkontakt mehr: zur letzten bekannten Stelle, dann aufgeben.
			ziel = enemy.get("zuletzt_gesehen", player_pos)
			enemy["such_zeit"] = enemy.get("such_zeit", SUCH_DAUER) - delta
			if enemy["such_zeit"] <= 0.0 or enemy_pos.distance_to(ziel) < 6.0:
				_aufgeben(enemy)
				_wander(enemy, delta)
				continue

		var should_flee := false
		match archetype.temperament:
			Enums.Temperament.SKITTISH, Enums.Temperament.TERRITORIAL:
				should_flee = level_diff < -FLEE_LEVEL_THRESHOLD
			Enums.Temperament.AGGRESSIVE:
				should_flee = false
		if ueberlegen:
			should_flee = true  # vor einer weit stärkeren Party flieht jeder

		var wunsch := (ziel - enemy_pos).normalized()
		if should_flee:
			wunsch = -wunsch
		var speed := _jagd_tempo(archetype)
		if should_flee:
			speed *= 1.25  # Flucht ist etwas schneller als Verfolgung.
		_steuern(enemy, wunsch, speed, delta)


## Höchsttempo auf Geraden: Jäger leicht über Spielertempo, Brocken langsam.
static func _jagd_tempo(archetype: EnemyArchetype) -> float:
	var agi := archetype.base_stats.agility
	if agi >= JAEGER_AB_AGILITAET:
		return SPEED * minf(JAEGER_TEMPO_MAX, 1.0 + (agi - 6) * JAEGER_TEMPO_PRO_AGI)
	return 40.0 + agi * 6.0


## Kurventräge Bewegung: der Kurs dreht nur begrenzt schnell zur Wunsch-
## richtung, und je schärfer die Kurve, desto langsamer (Looping-Prinzip).
func _steuern(enemy: Dictionary, wunsch: Vector2, speed: float, delta: float) -> void:
	if wunsch == Vector2.ZERO:
		return
	var kurs: Vector2 = enemy.get("kurs", wunsch)
	var winkel := kurs.angle_to(wunsch)
	var max_dreh := DREH_TEMPO * delta
	kurs = kurs.rotated(clampf(winkel, -max_dreh, max_dreh)).normalized()
	enemy["kurs"] = kurs
	var gerade := clampf(kurs.dot(wunsch), 0.0, 1.0)
	var tempo := speed * lerpf(KURVEN_TEMPO_MIN, 1.0, gerade * gerade)
	_enemy_schritt(enemy, kurs * tempo * delta)


## Schritt mit Wand-Gleiten: geht der volle Schritt nicht, wenigstens
## entlang einer Achse — sonst kleben Gegner in Kurven an Ecken fest.
func _enemy_schritt(enemy: Dictionary, schritt: Vector2) -> void:
	var pos: Vector2 = enemy["pos"]
	for versuch in [schritt, Vector2(schritt.x, 0.0), Vector2(0.0, schritt.y)]:
		if versuch != Vector2.ZERO and _enemy_fits(pos + versuch):
			enemy["pos"] = pos + versuch
			return


func _aufgeben(enemy: Dictionary) -> void:
	enemy["jagd"] = false
	enemy["wander_target"] = enemy["home"]  # trottet zurück zu seinem Revier
	enemy["wander_timer"] = randf_range(WANDER_INTERVAL_MAX, WANDER_INTERVAL_MAX * 1.5)
	_setze_marker(enemy, "?")


func _setze_marker(enemy: Dictionary, zeichen: String) -> void:
	enemy["marker"] = zeichen
	enemy["marker_zeit"] = MARKER_DAUER


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
	# Kurs mitführen, damit der Übergang ins Jagen nicht ruckt.
	enemy["kurs"] = to_target.normalized()
	_enemy_schritt(enemy, to_target.normalized() * WANDER_SPEED * delta)


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
	# Truhen, Tresor und Events sind PRO SPIELER (DQ9-Grotten): jeder nutzt
	# sie selbst und bekommt eigene Beute (_lokale_kontakte). Kämpfe fordern
	# Gäste beim Host an (_check_guest_contacts).
	if _lokale_kontakte():
		return
	if GameState.coop_guest_run:
		_check_guest_contacts()
		return
	for enemy in _enemies:
		# Flucht-Schonfrist: der Gegner, vor dem wir gerade geflohen sind,
		# schnappt erst wieder zu, wenn die Party auf Abstand war.
		if _floor_id(enemy["id"]) == GameState.flee_grace_enemy:
			if player_pos.distance_to(enemy["pos"]) > CONTACT_DIST * 2.5:
				GameState.flee_grace_enemy = -1
			continue
		if player_pos.distance_to(enemy["pos"]) < CONTACT_DIST:
			if _ueberlegen():
				_sofortsieg(enemy)
			else:
				_start_battle(enemy["id"], false, _ueberraschung_fuer(enemy))
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


## Truhen, Tresor, Schreine, Risiko-Truhen, Opferstein — für Host UND Gäste,
## jeder mit eigener Beute. true = ein Mimic-Kampf beginnt (Host).
func _lokale_kontakte() -> bool:
	for chest in _chests.duplicate():
		if player_pos.distance_to(chest["pos"]) < CONTACT_DIST:
			if chest.get("mimic", false):
				GameState.current_run["opened"].append(_floor_id(chest["id"]))
				_chests.erase(chest)
				_start_mimic_battle({"id": MIMIC_TRUHEN_ID + int(chest["id"])})
				if _entering_battle:
					return true
				continue
			_open_chest(chest)
	var am_tresor := not _tresor.is_empty() and player_pos.distance_to(_tresor["pos"]) < CONTACT_DIST
	if am_tresor and not _tresor_nah:
		if hat_schluessel():
			_tresor_oeffnen()
		else:
			_show_message(Loc.pick("Der Tresor ist verschlossen. Ein Gegner dieser Ebene trägt den Schlüssel.",
				"The vault is locked. An enemy on this floor carries the key."))
	_tresor_nah = am_tresor
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
					return true
			_:
				_use_shrine(event)
	if not near_sacrifice.is_empty() and _sacrifice_nearby.is_empty():
		_show_message(Loc.pick("Ein Opferstein … [%s]: Jeder Held opfert 15%% Max-HP für Schätze.",
			"A sacrifice stone … [%s]: every hero sacrifices 15%% max HP for treasure.")
			% Settings.key_name(&"interact"))
	_sacrifice_nearby = near_sacrifice
	return false


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
		GameState.medaille()
		message += Loc.pick("  +1 Mini-Medaille!", "  +1 mini medal!")
	# Truhen enthalten oft zusätzlich Crafting-Materialien.
	if rng.randf() < 0.5:
		var material := MaterialLibrary.roll(rng, card.tier)
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
	if _entering_battle or int(data.get("floor", -99)) != floor_index:
		return
	if type == "guest_mimic":
		# Die Risiko-/Schatzfieber-Truhe des Gastes war ein Mimic — gekämpft
		# wird beim Host (die eigene Truhe des Hosts bleibt unberührt).
		_start_mimic_battle({"id": int(data.get("id", 0))})
		return
	if type != "guest_contact":
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
	# Dynamische Gegner: Bestand des Hosts übernehmen (Neue rein, Gegangene raus).
	var bestand := _gegner_bestand()
	var ids := {}
	for eintrag in bestand:
		ids[int(eintrag[0])] = eintrag
	for enemy in _enemies.duplicate():
		if not ids.has(int(enemy["id"])):
			_enemies.erase(enemy)
		else:
			ids.erase(int(enemy["id"]))
	for id in ids:
		_gegner_hinzufuegen(id, Vector2i(int(ids[id][1]), int(ids[id][2])))
	for chest in _chests.duplicate():
		if _floor_id(chest["id"]) in GameState.current_run["opened"]:
			_chests.erase(chest)
	_boss_alive = map.has_boss and not GameState.current_run["boss_defeated"]


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
	if GameState.coop_guest_run:
		var arten := {DungeonGenerator.EventType.SHRINE_HEAL: "heilung",
			DungeonGenerator.EventType.SHRINE_MANA: "mana", DungeonGenerator.EventType.SHRINE_POWER: "kraft",
			DungeonGenerator.EventType.SHRINE_WARD: "schutz"}
		Net.send_to_host("guest_event", {"art": arten.get(event["type"], "")})
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
	GameState.add_material(MaterialLibrary.roll(rng, card.tier), 2)
	GameState.medaille()  # Risiko belohnt: garantierte Mini-Medaille
	GameState.save_game()
	Sfx.play(&"seltener_fund" if item.rarity >= Enums.Rarity.EPIC else &"truhe")
	_show_message("Risiko-Truhe: +%d Gold, %s (%s) und Materialien!"
		% [gold, item.get_display_name(), LootGenerator.RARITY_NAMES[item.rarity]])


func _start_mimic_battle(event: Dictionary) -> void:
	if _entering_battle:
		return
	if GameState.coop_guest_run:
		Sfx.play(&"mimic")
		_show_message(Loc.pick("Die Truhe lebt — ein Mimic! Der Host zieht euch hinein …",
			"The chest is alive — a mimic! The host pulls you in …"))
		Net.send_to_host("guest_mimic", {"id": event["id"], "floor": floor_index})
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
		"ueberraschung": Battle.HINTERHALT,  # die Truhe schnappt zu
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
	if GameState.coop_guest_run:
		Net.send_to_host("guest_event", {"art": "opfer"})
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var gold := 40 + card.tier * 12 + rng.randi_range(0, 25)
	GameState.gold += gold
	GameState.add_material(MaterialLibrary.roll(rng, card.tier), 2)
	GameState.add_material(MaterialLibrary.roll(rng, card.tier), 1)
	GameState.save_game()
	Sfx.play(&"opferstein")
	_show_message("Der Opferstein nimmt euer Blut: +%d Gold und Materialien." % gold)


func _start_battle(enemy_id: int, is_boss: bool,
		ueberraschung := Battle.KEINE_UEBERRASCHUNG) -> void:
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
		"is_boss": is_boss, "enemies": foes, "ueberraschung": ueberraschung,
	}
	get_tree().change_scene_to_file(BATTLE_SCENE)


## Sichtfeld/Rücken-Geometrie: siehe Anschleichen (headless getestet).
func _bemerkt(enemy: Dictionary, enemy_pos: Vector2, distance: float) -> bool:
	return Anschleichen.bemerkt(player_pos, enemy, enemy_pos, distance)


func _ueberraschung_fuer(enemy: Dictionary) -> int:
	return Anschleichen.ueberraschung(player_pos, _blick, enemy)


## Ist die Party den Gegnern dieser Ebene weit überlegen (DQ: schwache
## Monster fliehen)? Gegnerstufe = Karte + Ebene + Raritäts-Bonus.
func _ueberlegen() -> bool:
	var gegner_stufe := card.tier + floor_index + card.rarity_level_bonus()
	return _average_party_level() - gegner_stufe >= UEBERLEGEN_AB


## Sofortsieg über eine weit unterlegene Gruppe: kein Kampf, halbe XP und
## halbes Gold, keine Items — spart beim Farmen Zeit, lohnt aber nicht mehr.
func _sofortsieg(enemy: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 31337 + (enemy["id"] + 2) * 7919
	var foes := EnemyFactory.make_encounter(card, rng, false, floor_index)
	var xp_basis := LootGenerator.xp_fuer(foes, false, card.card_affix_ids)
	var loot_rng := RandomNumberGenerator.new()
	loot_rng.randomize()
	var gold := roundi(LootGenerator.roll_battle_loot(foes, card.tier, false, loot_rng)["gold"]
		* SOFORTSIEG_ANTEIL * (1.6 if &"reich" in card.card_affix_ids else 1.0))
	GameState.gold += gold
	GameState.note_kills(foes.size())
	for foe in foes:
		GameState.record_kill(foe.archetype_id)
	# XP wie nach einem Kampf: eigene Helden + Gäste auf dieser Ebene.
	var gaeste: Array = Net.guests_on_floor(floor_index) if Net.role == Net.Role.HOST else []
	var aufstiege: Array[String] = []
	# Geteilt wie nach einem Kampf: auf alle Helden dieser Ebene.
	var dabei: Array[Combatant] = []
	for member in GameState.party:
		if member.has_meta(&"guest_peer") and int(member.get_meta(&"guest_peer")) not in gaeste:
			continue
		dabei.append(member)
	# Nachzügler-Bonus wie nach einem Kampf (vor allen Level-Ups berechnet).
	var xp_je_held := LootGenerator.xp_fuer_helden(foes, false, card.card_affix_ids, dabei)
	var gast_xp := {}
	for member in dabei:
		if member.has_meta(&"guest_peer"):
			gast_xp[int(member.get_meta(&"guest_peer"))] = roundi(xp_je_held[member] * SOFORTSIEG_ANTEIL)
	var xp_gesamt := 0
	for member in dabei:
		var vorher := member.level
		var peak_vorher := member.peak_level
		var xp := roundi(int(xp_je_held[member]) * SOFORTSIEG_ANTEIL)
		if not member.has_meta(&"guest_peer"):
			xp_gesamt += xp
		if member.gain_xp(xp) > 0:
			aufstiege.append("%s Lv %d" % [member.display_name, member.level])
			var neu := BlockLibrary.aufstieg_text(vorher, member.level, member.rebirths, peak_vorher)
			if not neu.is_empty():
				aufstiege[-1] += " (%s)" % neu
	aufstiege.append_array(GameState.bank_mittraining(roundi(xp_basis * SOFORTSIEG_ANTEIL)))
	for peer_id in gaeste:
		Net.award_guest(peer_id, {"xp": int(gast_xp.get(peer_id, 1)), "gold": gold,
			"materials": {}, "items": []})
	# Kartenhüter geben ihre Schatzkarte auch kampflos her.
	var schatz_text := ""
	for foe in foes:
		if foe.get_meta(&"schatzkarte", false):
			var schatz := CardFactory.make_schatzkarte(card.tier)
			schatz_text += Loc.pick("  Schatzkarte: %s (Stufe %d)%s", "  Treasure map: %s (tier %d)%s") % [
				schatz.display_name, schatz.tier,
				"" if GameState.add_card(schatz) else Loc.pick(" — Lager voll!", " — storage full!")]
	GameState.current_run["defeated"].append(_floor_id(enemy["id"]))
	_enemies.erase(enemy)
	GameState.save_game()
	Sfx.play(&"level_up" if not aufstiege.is_empty() else &"bestaetigen")
	var text := Loc.pick("Die Gegner geben auf: +%d XP, +%d Gold.", "The enemies give up: +%d XP, +%d gold.") \
		% [xp_gesamt, gold] + schatz_text
	if not aufstiege.is_empty():
		text += Loc.pick("  Aufstieg: %s — Punkte im Inventar (%s), Klötze in der Werkstatt (%s)",
			"  Level up: %s — points in the inventory (%s), blocks in the workshop (%s)") \
			% [", ".join(aufstiege), Settings.key_name(&"open_inventory"), Settings.key_name(&"open_workshop")]
	_show_message(text)


# --- Dynamische Gegner -----------------------------------------------------------

func _gegner_hinzufuegen(id: int, cell: Vector2i) -> void:
	var start_pos := DungeonMap.cell_center_px(cell)
	_enemies.append({
		"id": id,
		"pos": start_pos,
		"home": start_pos,
		"wander_target": start_pos,
		"wander_timer": randf_range(WANDER_INTERVAL_MIN, WANDER_INTERVAL_MAX),
		"archetype": _archetype_for_enemy(id),
		"leben": GegnerNachschub.lebenszeit(_nachschub_rng),
		"schluessel": id == map.schluessel_id and not _tresor.is_empty(),
	})


func _gegner_bestand() -> Array:
	return GegnerNachschub.bestand(GameState.current_run, map, floor_index, FLOOR_ID_OFFSET)


## Gegner gehen nach ihrer Lebenszeit (nie, solange sie jagen oder man sie
## sieht); freie Plätze füllt nach kurzer Zeit ein Neuer, weit weg vom Helden.
func _gegner_nachschub(delta: float) -> void:
	if _entering_battle:
		return
	var geaendert := false
	var bereich := _visible_cell_range()
	for enemy in _enemies.duplicate():
		if enemy.get("jagd", false) or enemy.get("schluessel", false):
			continue
		enemy["leben"] = enemy.get("leben", GegnerNachschub.LEBENSZEIT_MAX) - delta
		var zelle := _pos_to_cell(enemy["pos"])
		var sichtbar := zelle.x >= bereich[0] and zelle.x < bereich[2] \
			and zelle.y >= bereich[1] and zelle.y < bereich[3]
		if enemy["leben"] <= 0.0 and not sichtbar:
			_enemies.erase(enemy)
			_aus_bestand(int(enemy["id"]))
			geaendert = true
	if _enemies.size() >= _gegner_max:
		_nachschub_timer = GegnerNachschub.nachschub_zeit(_nachschub_rng)
	else:
		_nachschub_timer -= delta
		if _nachschub_timer <= 0.0:
			_nachschub_timer = GegnerNachschub.nachschub_zeit(_nachschub_rng)
			var bestand := _gegner_bestand()
			var belegt: Array = []
			for eintrag in bestand:
				belegt.append(Vector2i(int(eintrag[1]), int(eintrag[2])))
			var cell := GegnerNachschub.spawn_zelle(map, _nachschub_rng, _pos_to_cell(player_pos), belegt)
			var id := GegnerNachschub.neue_id(bestand, GameState.current_run["defeated"], floor_index,
				map.enemies.size(), FLOOR_ID_OFFSET)
			if cell.x >= 0 and id >= 0:
				bestand.append([id, cell.x, cell.y])
				_gegner_hinzufuegen(id, cell)
				geaendert = true
	if geaendert:
		_notify_coop_state()


func _aus_bestand(id: int) -> void:
	var bestand := _gegner_bestand()
	for eintrag in bestand.duplicate():
		if int(eintrag[0]) == id:
			bestand.erase(eintrag)


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


## KEIN Fog of War (Lutz' Designentscheidung): alles, was auf dem Bildschirm
## ist, ist sichtbar — keine Überraschungen. "Erkundet" heißt nur noch
## "war schon mal auf dem Bildschirm" und füttert die Minimap.
## (Die Sichtlinie gilt weiter — aber nur für GEGNER, siehe _move_enemies.)
func _update_visibility() -> void:
	_visible_cells.clear()
	var view := _visible_cell_range()
	for y in range(view[1], view[3]):
		for x in range(view[0], view[2]):
			var cell := Vector2i(x, y)
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
		_decorations.append({"cell": cell,
			"art": String(deco_tiles[rng.randi_range(0, deco_tiles.size() - 1)])})


## Der eigene Held (Farbwahl + Ausrüstung bestimmen seine 3D-Figur).
func held_kaempfer() -> Combatant:
	if GameState.coop_guest_run:
		return Net.my_local_hero()
	return GameState.party[0] if not GameState.party.is_empty() else null


## Welcher Boss unten wartet (deterministisch wie make_encounter) — für die Figur.
func _boss_archetyp_id() -> StringName:
	var rng := RandomNumberGenerator.new()
	rng.seed = card.seed + floor_index * 31337 + (-1 + 2) * 7919
	var pool := EnemyLibrary.archetypes_for_biome(card.biome, true,
		card.tier + floor_index)
	if pool.is_empty():
		pool = EnemyLibrary.archetypes_for_biome(card.biome, true)
	if pool.is_empty():
		return &""
	var archetype: EnemyArchetype = pool[rng.randi_range(0, pool.size() - 1)]
	return archetype.id


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


# --- Darstellung: siehe DungeonWelt3D ---------------------------------------

## Sichtbarer Zellbereich um die Kamera (mit Rand), auf die Kartengrenzen
## begrenzt — [x0, y0, x1, y1) als Halboffen-Intervall für range().
func _visible_cell_range() -> Array[int]:
	return _welt.sichtbarer_bereich(VIEW_MARGIN_CELLS)


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	add_child(_hud_layer)
	var hud_root := Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.theme = UiTheme.get_theme()
	_hud_layer.add_child(hud_root)
	# Titel + Chips, Party-Karten, Tasten, Meldungen (DungeonHud).
	_hud = DungeonHud.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_root.add_child(_hud)

	# Minimap oben rechts: erkundete Zellen, Spieler, Treppe/Boss, Truhen.
	_minimap = Minimap.new()
	_minimap.dungeon = self
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var minimap_groesse: Vector2 = Minimap.masse(map)["groesse"]
	_minimap.offset_left = -(minimap_groesse.x + 12)
	_minimap.offset_right = -12
	_minimap.offset_top = 12
	_minimap.offset_bottom = 12 + minimap_groesse.y
	hud_root.add_child(_minimap)


func _show_message(text: String) -> void:
	_hud.meldung_zeigen(text)
	var timer := get_tree().create_timer(2.5)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(_hud) and _hud.meldung() == text:
			_hud.meldung_zeigen(""))


# --- Besondere Dungeons: Sonderregel-Hinweis, Tresor ---------------------------

## Truhen-Mimics (Schatzfieber) bekommen eigene IDs neben den Risiko-Truhen.
const MIMIC_TRUHEN_ID := 500


func hat_schluessel() -> bool:
	return map.schluessel_id >= 0 \
		and _floor_id(map.schluessel_id) in GameState.current_run["defeated"]


## Beim Betreten einer Ebene: Sonderregel (erste Ebene) und Tresor nennen.
func _ebenen_hinweis() -> void:
	var zeilen: Array[String] = []
	if card.sonderregel != &"" and floor_index == 0:
		zeilen.append("%s: %s" % [Sonderregeln.name_von(card), Sonderregeln.text_von(card)])
	if not _tresor.is_empty() and not hat_schluessel():
		zeilen.append(Loc.pick("Auf dieser Ebene steht ein Tresor. Ein Gegner trägt den Schlüssel.",
			"There is a vault on this floor. An enemy carries the key."))
	if not zeilen.is_empty():
		_show_message("\n".join(zeilen))


## Tresor: garantiert episch (20 % legendär), viel Gold, eine Mini-Medaille.
const TRESOR_LEGENDAER := 0.2
const TRESOR_GOLD := 5


func _tresor_oeffnen() -> void:
	GameState.current_run["tresore"].append(floor_index)
	_tresor = {}
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rarity := Enums.Rarity.LEGENDARY if rng.randf() < TRESOR_LEGENDAER else Enums.Rarity.EPIC
	var item := LootGenerator.roll_item_with_rarity(card.tier + floor_index, rarity, rng)
	GameState.inventory.append(item)
	var gold := (20 + card.tier * 10 + rng.randi_range(0, 15)) * TRESOR_GOLD
	GameState.gold += gold
	GameState.medaille()
	GameState.save_game()
	Sfx.play(&"seltener_fund")
	_show_message(Loc.pick("Tresor geöffnet: %s (%s), +%d Gold, +1 Mini-Medaille!",
		"Vault opened: %s (%s), +%d gold, +1 mini medal!")
		% [item.get_display_name(), LootGenerator.RARITY_NAMES[item.rarity], gold])
	_notify_coop_state()
