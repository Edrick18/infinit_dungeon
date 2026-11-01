extends SceneTree
## Headless-Selbsttest für geteilte Oberflächen-Bausteine: Minimap zeichnet
## nur bei Änderung neu (TECH-5), Skill-Knopf und Punkte-Knopf kommen für
## Host und Co-op-Gast aus KampfUi (TECH-7), Ergebnis-/Abschlussfenster aus
## der Bildschirm-Vorlage (UI-Layout-Pass). Grafik-Paket 5: Holz-/Messing-
## Theme aus EINER Farbquelle (Stil3D.PAL), eigene Fokus-Rolle, nahtlose
## 9-Slice-Texturen, neue Icons (Tränke, Materialien, Biome, Körper-Quelle),
## gedrosselte Menü-Kulisse mit Filmic.
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
	_test_holz_theme()
	_test_icons()
	_test_kulisse()
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
	_check(minimap._gelesen == dungeon._explored_cells.size(), "Kartenbild liest nur neue Zellen (Stand gemerkt)")
	# Neue Quelle (andere Dictionary-Referenz, z. B. Co-op-Stand): von vorn lesen.
	var kopie: Dictionary = dungeon._explored_cells.duplicate()
	kopie[boden[42]] = true
	dungeon._explored_cells = kopie
	await _bild(minimap)
	_check(minimap._gemalt.has(boden[42]) and minimap._gelesen == kopie.size(),
		"neue Erkundungs-Quelle: neu gelesen, neue Zelle gemalt")
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


## Abstand zweier Farben im RGB-Raum (0..~1.7).
func _farbabstand(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _test_holz_theme() -> void:
	print("Grafik-Paket 5: Holz-/Messing-Theme, Farbquelle, Fokus-Rolle:")
	var ui_theme = load("res://scripts/ui/ui_theme.gd")
	var holz = load("res://scripts/ui/ui_holz.gd")
	var bildschirm = load("res://scripts/ui/bildschirm.gd")
	var kampf_ui = load("res://scripts/ui/kampf_ui.gd")
	var loot = load("res://scripts/loot/loot_generator.gd")
	# Eine Farbquelle: die Rollenfarben des Themes SIND PAL-Einträge.
	_check(ui_theme.GOLD == Stil3D.PAL["gold"] and ui_theme.FOKUS == Stil3D.PAL["fokus"]
		and ui_theme.TEXT == Stil3D.PAL["ui_text"] and ui_theme.ACCENT == Stil3D.PAL["warnrot"]
		and ui_theme.MESSING == Stil3D.PAL["messing"], "UiTheme-Farben kommen aus Stil3D.PAL")
	_check(kampf_ui.HP_GUT == Stil3D.PAL["hp_gut"] and kampf_ui.MP_FARBE == Stil3D.PAL["mana"]
		and kampf_ui.HP_KRITISCH == Stil3D.PAL["warnrot"], "Kampf-Balken nutzen PAL-Farben")
	var theme: Theme = ui_theme.get_theme()
	var knopf: StyleBox = theme.get_stylebox("normal", "Button")
	_check(knopf is StyleBoxTexture and knopf == holz.box("knopf"), "Knöpfe = Holz-StyleBoxTexture (gecacht, geteilt)")
	_check(theme.get_stylebox("panel", "PanelContainer") is StyleBoxTexture
		and theme.get_stylebox("panel", "TooltipPanel") == holz.box("pergament"), "Tafeln aus Holz, Tooltips aus Pergament")
	var arten := ["normal", "hover", "pressed", "disabled"]
	var verschieden := true
	for i in arten.size():
		for j in range(i + 1, arten.size()):
			if theme.get_stylebox(arten[i], "Button") == theme.get_stylebox(arten[j], "Button"):
				verschieden = false
	_check(verschieden, "Knopfzustände normal/hover/gedrückt/gesperrt sehen verschieden aus")
	# Fokus = eigene Rolle: kräftiger Ring ohne Außenrand (sonst in Listen
	# abgeschnitten), farblich weit weg von Gold/Messing und jeder Seltenheit.
	var fokus := theme.get_stylebox("focus", "Button") as StyleBoxFlat
	_check(fokus != null and fokus.border_color == ui_theme.FOKUS and fokus.border_width_left >= 3
		and not fokus.draw_center and is_zero_approx(fokus.expand_margin_left),
		"Fokusrahmen: 3-px-Ring in FOKUS, innen liegend")
	var nah := false
	var vergleich: Array = [ui_theme.GOLD, ui_theme.MESSING, Stil3D.PAL["messing_hell"]]
	vergleich.append_array(loot.RARITY_COLORS.values())
	for farbe in vergleich:
		if _farbabstand(ui_theme.FOKUS, farbe) < 0.3:
			nah = true
	_check(not nah, "Fokusfarbe unterscheidet sich von Gold, Messing und allen Seltenheiten")
	_check(ui_theme.fokus_rahmen() == fokus, "Kachel-Fokusrahmen = Knopf-Fokusrahmen")
	for typ in ["OptionButton", "LineEdit", "TextEdit", "CheckButton", "HSlider"]:
		_check(theme.get_stylebox("focus", typ) == fokus, "%s: gleicher Fokusrahmen" % typ)
	# Texturen: einmal erzeugt, 9-Slice-Rand passt, Mitte kachelt nahtlos.
	for art in holz.ARTEN:
		var d: Dictionary = holz.ARTEN[art]
		var bild: Image = holz.bild(art)
		var box: StyleBoxTexture = holz.box(art)
		var rand := float(d["rand"]) + float(d.get("schein", 0))
		_check(bild.get_width() == d["w"] and bild.get_height() == d["h"] and holz.bild(art) == bild
			and is_equal_approx(box.texture_margin_left, rand) and box.texture.get_width() == d["w"],
			"%s: Bild %dx%d, gecacht, 9-Slice-Rand %d" % [art, d["w"], d["h"], int(rand)])
	var tafel: Image = holz.bild("tafel")
	var r: int = holz.ARTEN["tafel"]["rand"]
	var naht := 0.0
	for y in range(r, tafel.get_height() - r):
		naht = maxf(naht, _farbabstand(tafel.get_pixel(r, y), tafel.get_pixel(tafel.get_width() - r, y)))
	_check(naht < 0.02, "Holzmaserung der Tafel ist periodisch (Mitte kachelt ohne Naht)")
	_check(holz.box("knopf").axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT,
		"Mitte wird gekachelt, nicht gestreckt")
	# Tafeln: Zeilen darin werden Fächer; Fenster und Held am Zug.
	var t: PanelContainer = bildschirm.tafel(Label.new(), 24)
	_check(t.theme == ui_theme.innen_theme() and t.get_theme_stylebox("panel") is StyleBoxTexture
		and is_equal_approx(t.get_theme_stylebox("panel").get_content_margin(SIDE_LEFT), 24.0)
		and ui_theme.innen_theme().get_stylebox("panel", "PanelContainer") == holz.box("fach"),
		"Bildschirm.tafel: Holztafel, Zeilen darin = Fächer")
	t.free()
	var karte := PanelContainer.new()
	kampf_ui.aktiv_setzen(karte, true)
	var aktiv := karte.get_theme_stylebox("panel")
	kampf_ui.aktiv_setzen(karte, false)
	_check(aktiv == holz.box("tafel_aktiv") and holz.box("tafel_aktiv").expand_margin_left > 0.0
		and not karte.has_theme_stylebox_override("panel"), "Held am Zug: Goldtafel mit Schein, danach zurück")
	karte.free()
	var knopf_aktiv := Button.new()
	ui_theme.als_aktiv(knopf_aktiv, true)
	_check(knopf_aktiv.disabled and knopf_aktiv.get_theme_stylebox("disabled") == holz.box("knopf_aktiv"),
		"Gewählter Reiter: gesperrt, aber Gold-Holz statt ergraut")
	knopf_aktiv.free()
	var chip: PanelContainer = holz.level_chip(23)
	_check((chip.get_child(0) as Label).text == "23", "Item-Level als eigener Chip")
	chip.free()
	var glanz_a: Texture2D = holz.glanz(loot.RARITY_COLORS[Enums.Rarity.EPIC])
	_check(glanz_a == holz.glanz(loot.RARITY_COLORS[Enums.Rarity.EPIC])
		and glanz_a != holz.glanz(loot.RARITY_COLORS[Enums.Rarity.RARE]), "Seltenheits-Schein je Farbe gecacht")


func _test_icons() -> void:
	print("Grafik-Paket 5: neue Icons (Tränke, Materialien, Biome, Körper-Quelle):")
	var vorrat = load("res://scripts/stil3d/vorrat_icons.gd")
	var klotz = load("res://scripts/stil3d/klotz_icons.gd")
	var alle_ok := true
	for def in ConsumableLibrary.all_defs():
		var n: Node3D = vorrat.trank_bauen(def.id)
		if n.find_children("*", "MeshInstance3D", true, false).is_empty():
			alle_ok = false
		n.free()
	_check(alle_ok, "jeder Trank/Verbrauchsgegenstand hat ein Icon (%d)" % ConsumableLibrary.all_defs().size())
	alle_ok = true
	for id in MaterialLibrary.MATERIALS:
		var n: Node3D = vorrat.material_bauen(id)
		if n.find_children("*", "MeshInstance3D", true, false).is_empty():
			alle_ok = false
		n.free()
	_check(alle_ok, "jedes Material hat ein Icon (%d)" % MaterialLibrary.MATERIALS.size())
	var flaechen: Array = []
	for biom in [Enums.Biome.FOREST, Enums.Biome.CAVE, Enums.Biome.RUINS, Enums.Biome.CRYPT]:
		var n: Node3D = vorrat.biom_bauen(biom)
		var mis := n.find_children("*", "MeshInstance3D", true, false)
		_check(not mis.is_empty() and n.has_meta("icon_blick"), "Biom %d: Miniatur gebaut, Blick von schräg oben" % biom)
		if not mis.is_empty():
			flaechen.append((mis[0] as MeshInstance3D).mesh.get_faces().size())
		n.free()
	var verschieden := flaechen.size() == 4
	for i in flaechen.size():
		for j in range(i + 1, flaechen.size()):
			if flaechen[i] == flaechen[j]:
				verschieden = false
	_check(verschieden, "die vier Biom-Miniaturen unterscheiden sich")
	var zauber: Node3D = klotz.bauen(BlockLibrary.get_block(&"src_spell"))
	var koerper: Node3D = klotz.bauen(BlockLibrary.get_block(&"src_koerper"))
	_check(koerper.get_child_count() != zauber.get_child_count(), "Körper-Quelle hat ein eigenes Icon (nicht die Zauber-Kugel)")
	koerper.free()
	zauber.free()


func _test_kulisse() -> void:
	print("Grafik-Paket 5: Menü-Kulisse gedrosselt, Filmic wie Dungeon/Kampf:")
	_check(not Stil3D.bild_faellig(0.02, 30.0) and Stil3D.bild_faellig(0.034, 30.0)
		and Stil3D.bild_faellig(0.07, 15.0) and not Stil3D.bild_faellig(0.05, 15.0), "bild_faellig: Takt nach Bildrate")
	var kulisse_skript = load("res://scripts/stil3d/menue_kulisse.gd")
	for ruhig in [false, true]:
		var k: Control = kulisse_skript.new(&"lager", ruhig)
		var envs := k.find_children("*", "WorldEnvironment", true, false)
		var vp: SubViewport = k.find_children("*", "SubViewport", true, false)[0]
		var behaelter: SubViewportContainer = vp.get_parent()
		_check(not envs.is_empty() and (envs[0] as WorldEnvironment).environment.tonemap_mode == Environment.TONE_MAPPER_FILMIC,
			"Kulisse (ruhig=%s): Filmic wie Dungeon/Kampf" % ruhig)
		_check(k._rate == (kulisse_skript.BILDRATE_RUHIG if ruhig else kulisse_skript.BILDRATE)
			and behaelter.stretch_shrink == (2 if ruhig else 1), "Kulisse (ruhig=%s): Bildrate und Auflösung gedrosselt" % ruhig)
		k.free()
	var studio_licht := Node.new()
	PortraitStudio.licht_aufbauen(studio_licht)
	var env: Environment = (studio_licht.get_child(0) as WorldEnvironment).environment
	_check(env.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "Porträts/Vorschau: dieselbe Filmic-Umgebung")
	studio_licht.free()
	var rand := PortraitStudio.randlicht()
	_check(rand.light_energy > 1.0 and rand.light_color == Stil3D.farbe("stern"), "Icons: kühles Randlicht")
	rand.free()
