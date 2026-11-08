extends SceneTree
## Headless-Selbsttest Skill-Werkstatt-Anordnung (Feedback: „man craftet von
## rechts in das mittlere hinein“): oben die Skills (Ziel), darunter über die
## volle Breite die Bibliothek (Quelle) mit Reitern Bausteine/Rezeptbuch.
##  • Bibliothek liegt UNTER den Skills und ist (fast) so breit wie sie.
##  • Klötze und Buch-Einträge stehen als Raster (mehrere Spalten).
##  • 1280×720: nichts ragt aus dem Bild, auch mit vielen Slots, langen
##    Namen und vollem Rezeptbuch; ein ganzer Skill passt in den oberen Teil.
##  • Klick, Drag&Drop (unten » oben) und Fokus-Wege (W/S zwischen Skills und
##    Reitern) funktionieren weiter.
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/werkstatt_layout_selftest.gd
##
## Szenen hängen an Autoloads: erst nach dem ersten Bild per load() laden.
## Speichern ist gesperrt (Wegwerf-Slot 99), alles im Speicher.

var failures := 0


func _initialize() -> void:
	# Prüfbild fest 1280×720 (das Spiel selbst füllt breitere Fenster per „expand“).
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	await process_frame
	var gs: Node = root.get_node_or_null(^"GameState")
	_check(gs != null, "GameState-Autoload vorhanden")
	if gs == null:
		_ende()
		return
	gs.slot_gesperrt = true
	SaveManager.active_slot = 99
	gs.first_time("werkstatt")
	var waechter := FehlerWaechter.anmelden()
	_check(root.get_visible_rect().size == Vector2(1280, 720),
		"Prüfbild 1280×720 (%s)" % root.get_visible_rect().size)
	gs.party.clear()
	gs.reserve.clear()
	var kits: Array = load("res://scripts/data/hero_library.gd").STARTER_LOADOUTS.keys()
	gs.recruit("Friederike Sonnenwald-Übermut", kits[0])
	for level in [1, 60]:
		await _test_anordnung(gs, level)
	failures += waechter.fehler_melden()
	_ende()


func _ende() -> void:
	if failures == 0:
		print("SELFTEST OK — alle Werkstatt-Layout-Tests bestanden")
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


func _test_anordnung(gs: Node, level: int) -> void:
	var held: Combatant = gs.party[0]
	held.level = level
	held.peak_level = level
	print("Werkstatt, Held Level %d (%d Slots):" % [level, held.skill_slots()])
	var szene = load("res://scenes/workshop/skill_workshop.tscn").instantiate()
	root.add_child(szene)
	await _bilder(4)
	var oben := szene._editor_list.get_parent() as ScrollContainer
	var unten := szene._library_list.get_parent() as ScrollContainer
	var r_oben := oben.get_global_rect()
	var r_unten := unten.get_global_rect()
	_check(r_unten.position.y >= r_oben.end.y - 1.0, "Bibliothek liegt unter den Skills (%s / %s)" % [r_oben, r_unten])
	_check(szene._tab_bausteine.get_global_rect().position.y >= r_oben.end.y - 1.0,
		"Reiter Bausteine/Rezeptbuch unter den Skills")
	_check(r_unten.size.x >= r_oben.size.x * 0.95, "Bibliothek über die volle Breite (%d / %d)" % [r_unten.size.x, r_oben.size.x])
	var erster: Control = szene._editors[0]["panel"]
	_check(oben.size.y >= erster.size.y, "ein ganzer Skill passt oben hinein (%d ≥ %d)" % [oben.size.y, erster.size.y])
	_check(unten.size.y >= 100.0, "Bibliothek mit sichtbarer Höhe (%d)" % unten.size.y)
	_check(szene._library_list.size.x <= unten.size.x + 1.0, "Bibliothek ohne Überbreite (%d / %d)" % [
		szene._library_list.size.x, unten.size.x])

	# Raster: Klötze in Spalten nebeneinander.
	var karten: Array = szene._library_list.find_children("*", "PanelContainer", true, false)
	var raster: Array = szene._library_list.find_children("*", "GridContainer", false, false)
	_check(raster.size() == 5 and (raster[0] as GridContainer).columns == szene.BIB_SPALTEN,
		"Klötze als Raster je Kategorie (%d Raster, %d Spalten)" % [raster.size(), szene.BIB_SPALTEN])
	var zeilen_y := {}
	for k in karten:
		zeilen_y[int((k as Control).global_position.y)] = true
	_check(karten.size() > zeilen_y.size(), "mehrere Klötze je Zeile (%d Karten, %d Zeilen)" % [karten.size(), zeilen_y.size()])
	var raus := _ausserhalb(szene)
	_check(raus.is_empty(), "Bausteine: alles im Bild %s" % [raus.slice(0, 4)])

	# Klick und Drag&Drop von unten nach oben.
	var held_skill: Skill = held.skills[0]
	held_skill.blocks.clear()
	szene._aktiv_index = 0
	szene._rebuild_editors()
	await _bilder(2)
	var quelle: Control = null
	for k in karten:
		if "locked" in k and not k.locked and k.block is SourceBlock:
			quelle = k
			break
	_check(quelle != null, "freier Quell-Klotz in der Bibliothek")
	if quelle != null:
		quelle._gui_input(_maus_los())
		_check(held_skill.blocks.size() == 1 and held_skill.blocks[0] == quelle.block, "Klick setzt den Klotz in den oberen Skill")
		held_skill.blocks.clear()
		szene._rebuild_editors()
		await _bilder(2)
		var daten: Variant = {"block": quelle.block}  # was _get_drag_data liefert (ohne echtes Ziehen)
		var sockel = szene._editors[0]["sockets"][0]
		_check(daten is Dictionary and sockel._can_drop_data(Vector2.ZERO, daten), "Ziehen: Sockel oben nimmt den Klotz an")
		if daten is Dictionary:
			sockel._drop_data(Vector2.ZERO, daten)
		_check(held_skill.blocks.size() == 1, "Ablegen setzt den Klotz in den Sockel")
		held_skill.blocks.clear()
		szene._rebuild_editors()
	await _bilder(2)

	# Fokus: W vom Reiter landet bei den Skills, S von den Skills bei den Reitern.
	var hoch: Control = szene._tab_bausteine.find_valid_focus_neighbor(SIDE_TOP)
	_check(hoch != null and oben.is_ancestor_of(hoch), "W vom Reiter erreicht die Skills (%s)" % [hoch])
	var letzte: Array = szene._editors.back()["panel"].find_children("*", "BaseButton", true, false)
	var runter: Control = null
	for knopf in letzte:
		if (knopf as Control).is_visible_in_tree():
			runter = (knopf as Control).find_valid_focus_neighbor(SIDE_BOTTOM)
			break
	_check(runter != null and not oben.is_ancestor_of(runter), "S vom letzten Skill erreicht die Bibliothek (%s)" % [runter])

	# Rezeptbuch voll: Einträge als Raster, alles im Bild.
	for vorlage in szene._vorlagen_fuer_helden():
		WerkstattLogik.ins_buch(held, vorlage)
	szene._rechts_zeigen(&"buch")
	await _bilder(4)
	var buch: Array = szene._library_list.find_children("*", "GridContainer", false, false)
	_check(buch.size() == 1 and (buch[0] as GridContainer).columns == szene.BUCH_SPALTEN
		and (buch[0] as GridContainer).get_child_count() == held.rezeptbuch.size(),
		"Rezeptbuch als Raster (%d Einträge)" % held.rezeptbuch.size())
	_check(szene._library_list.size.x <= unten.size.x + 1.0, "Rezeptbuch ohne Überbreite")
	raus = _ausserhalb(szene)
	_check(raus.is_empty(), "Rezeptbuch: alles im Bild %s" % [raus.slice(0, 4)])
	held.rezeptbuch.clear()
	szene._geaendert = false  # nie den Spielstand anfassen
	szene.queue_free()
	await _bilder(2)


func _maus_los() -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	return e


## Bedienbare Elemente und Texte außerhalb des Bildes (Elemente in einer
## Scroll-Liste zählen, wenn die Liste selbst im Bild liegt) — wie layout_selftest.
func _ausserhalb(wurzel: Node) -> Array[String]:
	var bild := root.get_visible_rect().grow(1.0)
	var fehler: Array[String] = []
	for knoten in wurzel.find_children("*", "Control", true, false):
		var c := knoten as Control
		if not (c is BaseButton or c is Label or c is LineEdit) or not c.is_visible_in_tree():
			continue
		if c.size.x < 2.0 or c.size.y < 2.0:
			continue
		var scroll := _scroll_vorfahr(c)
		var r := scroll.get_global_rect() if scroll != null else c.get_global_rect()
		if not bild.encloses(r):
			var text := ""
			if c is Button:
				text = (c as Button).text
			elif c is Label:
				text = (c as Label).text
			fehler.append("%s '%s' %s" % [c.get_class(), text.left(30), r])
	return fehler


func _scroll_vorfahr(c: Node) -> ScrollContainer:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null
