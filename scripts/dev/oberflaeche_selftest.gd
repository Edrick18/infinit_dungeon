extends SceneTree
## Headless-Selbsttest für geteilte Oberflächen-Bausteine: Minimap zeichnet
## nur bei Änderung neu (TECH-5), Skill-Knopf und Punkte-Knopf kommen für
## Host und Co-op-Gast aus KampfUi (TECH-7), Ergebnis-/Abschlussfenster aus
## der Bildschirm-Vorlage (UI-Layout-Pass).
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/oberflaeche_selftest.gd
##
## Minimap, KampfUi, Bildschirm und UiTheme hängen (über andere Skripte) an
## Autoloads: Sie werden erst nach dem ersten Bild per load() geladen, sonst
## kompiliert dieser Test im -s-Modus nicht. Speichern ist gesperrt.

var failures := 0


## Ersatz für die Dungeon-Szene: genau die Felder, die die Minimap liest.
class FakeDungeon:
	extends Node2D
	var map: DungeonMap
	var player_pos := Vector2.ZERO
	var _explored_cells: Dictionary = {}
	var _visible_cells: Dictionary = {}
	var _chests: Array = []
	var _events: Array = []
	var _enemies: Array = []
	var _tresor: Dictionary = {}
	var _boss_alive := false

	func _pos_to_cell(pos: Vector2) -> Vector2i:
		return Vector2i(floori(pos.x / DungeonMap.TILE_SIZE), floori(pos.y / DungeonMap.TILE_SIZE))


func _initialize() -> void:
	await process_frame
	var gs: Node = root.get_node_or_null(^"GameState")
	_check(gs != null, "GameState-Autoload vorhanden")
	if gs == null:
		_ende()
		return
	# Nie den echten Spielstand schreiben: Speichern sperren, Wegwerf-Slot.
	gs.slot_gesperrt = true
	SaveManager.active_slot = 98
	var waechter := FehlerWaechter.anmelden()
	await _test_minimap()
	await _test_dungeon_szene(gs)
	await _test_kampf_knoepfe()
	await _test_fenster()
	failures += waechter.fehler_melden()
	_ende()


func _ende() -> void:
	if failures == 0:
		print("SELFTEST OK — alle Oberflächen-Tests bestanden")
		quit(0)
	else:
		print("SELFTEST FEHLGESCHLAGEN — %d Fehler" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		printerr("  FEHLER: " + label)


func _bilder(anzahl: int) -> void:
	for i in anzahl:
		await process_frame


## Ein Bild wie in der Dungeon-Szene: aktualisieren() und warten.
func _bild(minimap: Control) -> void:
	minimap.aktualisieren()
	await process_frame


func _test_minimap() -> void:
	print("Minimap: Boden und Marker nur bei Änderung neu gezeichnet:")
	var card := DungeonCard.new()
	card.seed = 4242
	card.tier = 20
	var dungeon := FakeDungeon.new()
	dungeon.map = DungeonGenerator.generate(card)
	root.add_child(dungeon)
	var boden: Array[Vector2i] = []
	for y in dungeon.map.height:
		for x in dungeon.map.width:
			if dungeon.map.is_floor(Vector2i(x, y)):
				boden.append(Vector2i(x, y))
	for i in 40:
		dungeon._explored_cells[boden[i]] = true
		dungeon._visible_cells[boden[i]] = true
	dungeon.player_pos = DungeonMap.cell_center_px(boden[0])
	dungeon._enemies = [{"pos": DungeonMap.cell_center_px(boden[5])},
		{"pos": DungeonMap.cell_center_px(boden[200])}]

	var minimap_skript = load("res://scripts/ui/minimap.gd")
	var minimap = minimap_skript.new()
	minimap.dungeon = dungeon
	minimap.size = minimap_skript.masse(dungeon.map)["groesse"]
	root.add_child(minimap)
	await _bild(minimap)
	await _bild(minimap)
	_check(minimap.boden_gezeichnet == 1 and minimap.marker_gezeichnet == 1, "erstes Bild zeichnet beide Ebenen")

	for i in 10:
		await _bild(minimap)
	_check(minimap.boden_gezeichnet == 1 and minimap.marker_gezeichnet == 1,
		"10 Bilder ohne Änderung: kein Neuzeichnen")

	# Held läuft innerhalb seiner Zelle: nichts neu.
	dungeon.player_pos += Vector2(1, 1)
	await _bild(minimap)
	await _bild(minimap)
	_check(minimap.marker_gezeichnet == 1, "Bewegung in derselben Zelle: Marker bleiben")
	# Held wechselt die Zelle: nur die Marker.
	dungeon.player_pos = DungeonMap.cell_center_px(boden[1])
	await _bild(minimap)
	await _bild(minimap)
	_check(minimap.marker_gezeichnet == 2 and minimap.boden_gezeichnet == 1, "neue Spielerzelle: nur Marker neu")
	# Sichtbarer Gegner wechselt die Zelle: Marker neu.
	dungeon._enemies[0]["pos"] = DungeonMap.cell_center_px(boden[6])
	await _bild(minimap)
	await _bild(minimap)
	_check(minimap.marker_gezeichnet == 3 and minimap.boden_gezeichnet == 1, "sichtbarer Gegner zieht weiter: Marker neu")
	# Unsichtbarer Gegner läuft: die Minimap zeigt ihn nicht, also nichts neu.
	dungeon._enemies[1]["pos"] = DungeonMap.cell_center_px(boden[201])
	await _bild(minimap)
	await _bild(minimap)
	_check(minimap.marker_gezeichnet == 3, "unsichtbarer Gegner: kein Neuzeichnen")
	# Neue Zelle erkundet: Boden und Marker (Marker erscheinen erst erkundet).
	dungeon._explored_cells[boden[41]] = true
	await _bild(minimap)
	await _bild(minimap)
	_check(minimap.boden_gezeichnet == 2 and minimap.marker_gezeichnet == 4, "neu erkundet: Boden und Marker neu")
	# Truhe geöffnet (fällt aus der Liste): Marker neu.
	dungeon._chests = [{"pos": DungeonMap.cell_center_px(boden[3]), "rarity": 0}]
	await _bild(minimap)
	dungeon._chests = []
	await _bild(minimap)
	await _bild(minimap)
	_check(minimap.marker_gezeichnet == 6, "Truhe dazu und weg: Marker je einmal neu")
	# Kartenbild: nur erkundeter Boden ist gemalt (dazugemalt, nie alles neu).
	var erkundeter_boden := 0
	for zelle in dungeon._explored_cells:
		if dungeon.map.is_floor(zelle):
			erkundeter_boden += 1
	_check(minimap._gemalt.size() == erkundeter_boden, "Kartenbild enthält genau den erkundeten Boden")
	var masse: Dictionary = minimap_skript.masse(dungeon.map)
	_check(masse["groesse"].x <= minimap_skript.MAX_GROESSE and masse["karte"].x > masse["groesse"].x,
		"große Karte: festes Fenster, Ausschnitt folgt dem Spieler")
	# Pfeil zeigt in Laufrichtung (letzter Zellschritt).
	var start: Vector2i = boden[1]
	for r in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		if dungeon.map.is_floor(start + r):
			dungeon.player_pos = DungeonMap.cell_center_px(start + r)
			await _bild(minimap)
			_check(minimap._richtung == r, "Spieler-Pfeil zeigt in Laufrichtung %s" % r)
			break
	minimap.queue_free()
	dungeon.queue_free()
	await _bilder(1)


## Echte Dungeon-Szene: steht der Held, bleiben Sichtfeld, Boden der
## Minimap und Boss-Figur unverändert (TECH-5). Gegner werden vorher
## entfernt, damit kein Kampf (Szenenwechsel) dazwischenkommt.
func _test_dungeon_szene(gs: Node) -> void:
	print("Dungeon-Szene: stehender Held zeichnet und schreibt nichts neu:")
	var card := DungeonCard.new()
	card.seed = 777
	card.tier = 8
	card.floor_count = 2
	gs.first_time("dungeon")  # Onboarding-Hinweis nicht ins Bild
	var run_vorher: Dictionary = gs.current_run
	gs.start_run(card)
	var szene: Node = load("res://scenes/dungeon/dungeon_scene.tscn").instantiate()
	root.add_child(szene)
	szene._enemies.clear()
	szene._gegner_max = 0  # kein Nachschub
	await _bilder(3)
	var minimap = szene._minimap
	_check(minimap != null and minimap.boden_gezeichnet >= 1 and minimap.marker_gezeichnet >= 1,
		"Minimap hat beide Ebenen gezeichnet")
	var bereich: Array[int] = szene._sicht_bereich.duplicate()
	var sichtbar: int = szene._visible_cells.size()
	_check(bereich.size() == 4 and sichtbar > 0 and szene._explored_cells.size() >= sichtbar,
		"Sichtfeld geschrieben und erkundet")
	var boden_vorher: int = minimap.boden_gezeichnet if minimap != null else -1
	var marker_vorher: int = minimap.marker_gezeichnet if minimap != null else -1
	await _bilder(10)
	_check(szene._sicht_bereich == bereich and szene._visible_cells.size() == sichtbar,
		"10 Bilder stehen: Sichtfeld unverändert")
	if minimap != null:
		_check(minimap.boden_gezeichnet == boden_vorher and minimap.marker_gezeichnet == marker_vorher,
			"10 Bilder stehen: Minimap zeichnet nicht neu")
	var fabrik = load("res://scripts/combat/enemy_factory.gd")
	var boss_id: StringName = szene._boss_archetyp_id()
	_check(boss_id != &"" and szene._boss_archetyp_id() == boss_id
		and boss_id == fabrik.boss_figur_id(card, szene.floor_index),
		"Boss-Figur einmal gewürfelt, gleich der Kampf-Formel")
	szene.queue_free()
	await _bilder(2)  # erst weg, dann den Lauf zurücksetzen
	gs.current_run = run_vorher


func _test_kampf_knoepfe() -> void:
	print("KampfUi: Skill-Knopf und Punkte-Knopf für Host und Gast:")
	var kampf_ui = load("res://scripts/ui/kampf_ui.gd")
	var party: Array[Combatant] = TestContent.make_party()
	var held: Combatant = party[0]
	var skill: Skill = null
	for s: Skill in held.skills:
		if s.fehler(held).is_empty() and s.usable_with_weapon(held):
			skill = s
			break
	_check(skill != null, "Testheld hat einen gültigen Skill")
	if skill != null:
		var cost := skill.get_mp_cost(held)
		var knopf: Button = kampf_ui.skill_knopf(skill, held, cost)
		_check(not knopf.disabled and knopf.text.contains("%d MP" % cost), "genug MP: Knopf frei, Kosten im Text")
		_check(knopf.tooltip_text == kampf_ui.skill_tooltip(skill, cost) and not knopf.tooltip_text.is_empty(),
			"Tooltip mit Bausteinen und Kosten")
		var knapp: Button = kampf_ui.skill_knopf(skill, held, cost - 1)
		_check(knapp.disabled, "zu wenig MP: Knopf gesperrt")
		knopf.free()
		knapp.free()
	# Ungültig: Waffenangriff auf Verbündete (Werkstatt-Regel, Skill.fehler).
	var ungueltig := Skill.new()
	ungueltig.display_name = "Falsch"
	ungueltig.blocks = [BlockLibrary.get_block(&"src_weapon"), BlockLibrary.get_block(&"form_ally")]
	var grund := ungueltig.fehler(held)
	var kaputt: Button = kampf_ui.skill_knopf(ungueltig, held, 999)
	_check(not grund.is_empty() and kaputt.disabled and kaputt.tooltip_text == grund, "ungültiger Skill: gesperrt, Grund als Tooltip")
	kaputt.free()
	# Beide Kampfszenen nutzen die geteilten Bausteine (keine Kopien mehr).
	for pfad in ["res://scripts/ui/battle_scene.gd", "res://scripts/ui/coop_battle_scene.gd"]:
		var quelle := FileAccess.get_file_as_string(pfad)
		_check(quelle.contains("KampfUi.skill_knopf(") and quelle.contains("KampfUi.punkte_knopf(")
			and not quelle.contains("func _make_alloc_button"), "%s nutzt KampfUi" % pfad.get_file())

	held.stat_points = 3
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	panel.add_child(box)
	root.add_child(panel)
	var punkte: Button = kampf_ui.punkte_knopf(panel, box, held, false)
	box.add_child(punkte)
	_check(punkte.text == kampf_ui.punkte_text(held) and punkte.text.contains("3"), "Punkte-Knopf nennt freie Punkte")
	_check(punkte.is_in_group(&"punkte_knopf") and punkte.get_meta(&"held") == held, "KI-Brücke findet den Knopf")
	punkte.pressed.emit()
	await _bilder(1)
	_check(not box.visible and panel.get_child_count() == 2, "Verteilung klappt auf, Übersicht weicht")
	var allocs := panel.find_children("*", "StatAllocator", true, false)
	_check(allocs.size() == 1 and not allocs[0].speichern, "speichern = false wird durchgereicht")
	var fertig: Button = null
	for b in panel.find_children("*", "Button", true, false):
		if (b as Button).text == Loc.pick("« Fertig", "« Done"):
			fertig = b
	_check(fertig != null, "Fertig-Knopf vorhanden")
	if fertig != null:
		fertig.pressed.emit()
		await _bilder(1)
		_check(box.visible, "Fertig führt zur Übersicht zurück")
	panel.queue_free()
	await _bilder(1)


func _test_fenster() -> void:
	print("Bildschirm-Vorlage: Ergebnis- und Abschlussfenster:")
	var bildschirm = load("res://scripts/ui/bildschirm.gd")
	var szene := Control.new()
	szene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(szene)
	var fenster: Dictionary = bildschirm.fenster(szene)
	var mitte: CenterContainer = fenster["mitte"]
	var tafel: PanelContainer = fenster["tafel"]
	_check(mitte.get_parent() == szene and tafel.get_parent() == mitte, "Mitte in der Szene, Tafel in der Mitte")
	_check(mitte.anchor_right == 1.0 and mitte.anchor_bottom == 1.0, "Fenster füllt den Bildschirm (zentriert)")
	var stil := tafel.get_theme_stylebox("panel")
	_check(stil != null and is_equal_approx(stil.get_content_margin(SIDE_LEFT), bildschirm.RAND)
		and is_equal_approx(stil.get_content_margin(SIDE_BOTTOM), bildschirm.RAND), "Innenrand = Rand der Vorlage")
	_check(tafel.custom_minimum_size.x == bildschirm.FENSTER_BREITE, "feste Mindestbreite")
	var titel: Label = bildschirm.fenster_titel("Sieg!")
	_check(titel.get_theme_font_size("font_size") == bildschirm.FENSTER_TITEL_GROESSE
		and titel.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Fenstertitel groß und mittig")
	titel.free()
	# Tastatur: der erste Knopf im Fenster bekommt den Fokus.
	var box := VBoxContainer.new()
	tafel.add_child(box)
	var knopf := Button.new()
	knopf.text = "Weiter"
	box.add_child(knopf)
	await _bilder(1)
	var ui_theme = load("res://scripts/ui/ui_theme.gd")
	var alt_fokus := root.gui_get_focus_owner()
	if alt_fokus != null:
		alt_fokus.release_focus()
	var freigeben: Callable = ui_theme.fokus_einsperren(mitte)
	ui_theme.focus_first_button(box)
	await _bilder(1)  # grab_focus läuft deferred
	_check(knopf.has_focus(), "Fokus liegt im Fenster")
	freigeben.call()
	szene.queue_free()
	await _bilder(1)
