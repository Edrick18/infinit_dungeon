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
		await _test_slot_leiste(gs, level)
	await _test_bibliothek_reiter(gs)
	await _test_klotz_kette(gs)
	await _test_training(gs)
	failures += waechter.fehler_melden()
	_ende()


func _ende() -> void:
	if failures == 0:
		print("SELFTEST OK — alle Werkstatt-Layout-Tests bestanden")
		quit(0)
	else:
		print("SELFTEST FEHLGESCHLAGEN — %d Fehler" % failures)
		quit(1)


func _taste_e() -> InputEventAction:
	var taste := InputEventAction.new()
	taste.action = &"ui_accept"
	taste.pressed = true
	return taste


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
	szene._kategorie_waehlen(szene.ALLE)  # Raster-Prüfungen über alle Kategorien
	await _bilder(3)
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
		# Tastatur (WASD + E): Klotz fokussieren, E setzt ihn; E auf dem Sockel leert.
		_check(quelle.focus_mode == Control.FOCUS_ALL, "freie Klötze sind per Tastatur fokussierbar")
		quelle.grab_focus()
		await _bilder(1)
		quelle._gui_input(_taste_e())
		_check(held_skill.blocks.size() == 1 and held_skill.blocks[0] == quelle.block, "E setzt den fokussierten Klotz")
		var sockel_e = szene._editors[0]["sockets"][0]
		_check(sockel_e.focus_mode == Control.FOCUS_ALL, "Sockel sind per Tastatur fokussierbar")
		sockel_e.grab_focus()
		await _bilder(1)
		_check(szene._aktiv_index == 0, "Fokus auf einem Sockel macht seinen Skill zum Ziel")
		sockel_e._gui_input(_taste_e())
		_check(held_skill.blocks.is_empty(), "E auf dem Sockel leert ihn")
		if szene._editors.size() > 1:
			szene._editors[1]["sockets"][0].grab_focus()
			await _bilder(1)
			_check(szene._aktiv_index == 1, "Fokus auf Slot 2 macht Slot 2 zum Ziel")
			szene._aktiv_index = 0
			szene._refresh_editors()
	await _bilder(2)
	# Bei 720p mindestens drei Reihen Klötze ganz im Bild.
	var sicht: Rect2 = unten.get_global_rect()
	var reihen := {}
	for k in szene._library_list.find_children("*", "PanelContainer", true, false):
		if "block" in k:
			var r: Rect2 = (k as Control).get_global_rect()
			if r.position.y >= sicht.position.y and r.end.y <= sicht.end.y:
				reihen[int(r.position.y)] = true
	_check(reihen.size() >= 3, "mindestens drei Reihen Klötze im Bild (%d)" % reihen.size())

	# Fokus: W vom Reiter landet bei den Skills, S von den Skills bei den Reitern.
	var hoch: Control = szene._tab_bausteine.find_valid_focus_neighbor(SIDE_TOP)
	_check(hoch != null and oben.is_ancestor_of(hoch), "W vom Reiter erreicht die Skills (%s)" % [hoch])
	# Knöpfe eines Skills » S » seine Sockel (Tastatur-Ziel); unterste Reihe » S » Bibliothek.
	var letzter: Dictionary = szene._editors.back()
	var knoepfe: Array = (letzter["panel"] as Control).find_children("*", "BaseButton", true, false)
	var zu_sockel: Control = null
	for knopf in knoepfe:
		if (knopf as Control).is_visible_in_tree():
			zu_sockel = (knopf as Control).find_valid_focus_neighbor(SIDE_BOTTOM)
			break
	_check(zu_sockel != null and zu_sockel in letzter["sockets"], "S von den Skill-Knöpfen erreicht die Sockel (%s)" % [zu_sockel])
	var runter: Control = (letzter["sockets"][0] as Control).find_valid_focus_neighbor(SIDE_BOTTOM)
	_check(runter != null and not oben.is_ancestor_of(runter), "S von den Sockeln des letzten Skills erreicht die Bibliothek (%s)" % [runter])

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


## Slot-Leiste (alle Skills auf einen Blick) und Kachel „nächster Sockel“.
func _test_slot_leiste(gs: Node, level: int) -> void:
	var held: Combatant = gs.party[0]
	print("Slot-Leiste und nächster Sockel, Level %d:" % level)
	var szene = load("res://scenes/workshop/skill_workshop.tscn").instantiate()
	root.add_child(szene)
	await _bilder(4)
	var knoepfe: Array = szene._slot_knoepfe
	_check(knoepfe.size() == held.skill_slots(), "ein Knopf je Slot (%d / %d)" % [knoepfe.size(), held.skill_slots()])
	var ziel_index := mini(2, knoepfe.size() - 1)
	(knoepfe[ziel_index] as Button).pressed.emit()
	await _bilder(3)
	_check(szene._aktiv_index == ziel_index, "Klick auf Slot %d macht ihn zum Ziel" % (ziel_index + 1))
	var panel: Control = szene._editors[ziel_index]["panel"]
	var sicht: Rect2 = (szene._editor_scroll as Control).get_global_rect().grow(1.0)
	_check(sicht.encloses(panel.get_global_rect()), "der gewählte Slot steht ganz im Bild (%s in %s, scroll %d)" % [panel.get_global_rect(), sicht, (szene._editor_scroll as ScrollContainer).scroll_vertical])
	_check((knoepfe[0] as Button).tooltip_text.begins_with("Slot 1"), "Tooltip nennt Slot und Skill")
	var kachel: Array = (szene._editors[0]["panel"] as Control).find_children("*", "PanelContainer", true, false) \
		.filter(func(k: Node) -> bool: return k.has_meta(&"naechster_sockel"))
	var naechster := CharacterDef.next_socket_level(level)
	if naechster > 0:
		_check(kachel.size() == 1 and int(kachel[0].get_meta(&"naechster_sockel")) == naechster,
			"Kachel „nächster Sockel ab Level %d“ hinter den Sockeln" % naechster)
	else:
		_check(kachel.is_empty(), "alle Sockel frei: keine Kachel mehr")
	szene._aktiv_index = 0
	szene._geaendert = false
	szene.queue_free()
	await _bilder(2)


## Bibliothek: ein Reiter je Kategorie (kurze Listen), Suche über alle Klötze,
## der gewählte Reiter gilt beim nächsten Öffnen.
func _test_bibliothek_reiter(gs: Node) -> void:
	print("Bibliothek: Kategorie-Reiter und Suche:")
	var skript: GDScript = load("res://scripts/ui/skill_workshop.gd")
	skript.letzte_kategorie = 0
	var szene = load("res://scenes/workshop/skill_workshop.tscn").instantiate()
	root.add_child(szene)
	await _bilder(4)
	_check(szene._kat_tabs.size() == 5, "fünf Kategorie-Reiter (%d)" % szene._kat_tabs.size())
	_check(_bib_raster(szene) == 1 and _bib_karten(szene).all(func(k: Node) -> bool: return k.block is SourceBlock),
		"Start: nur der Reiter Quelle (ein Raster, nur Quellen)")
	szene._kat_tabs[2].pressed.emit()
	await _bilder(3)
	var karten := _bib_karten(szene)
	_check(not karten.is_empty() and karten.all(func(k: Node) -> bool: return k.block is ElementBlock),
		"Reiter Element zeigt nur Elemente (%d)" % karten.size())
	_check(skript.letzte_kategorie == 2, "gewählter Reiter wird gemerkt")
	var raus := _ausserhalb(szene)
	_check(raus.is_empty(), "Reiterzeile mit Suche: alles im Bild %s" % [raus.slice(0, 4)])
	# Suche über alle Kategorien, auch wenn ein anderer Reiter gewählt ist.
	var effekt: SkillBlock = null
	for block in BlockLibrary.all_blocks():
		if block is EffectBlock and gs.is_block_unlocked(block, szene._selected.level, szene._selected):
			effekt = block
			break
	_check(effekt != null, "freier Effekt-Klotz zum Suchen")
	if effekt != null:
		szene._suche.text = effekt.display_name.to_upper()
		szene._suche.text_changed.emit(szene._suche.text)
		await _bilder(3)
		karten = _bib_karten(szene)
		_check(karten.any(func(k: Node) -> bool: return k.block == effekt)
			and karten.all(func(k: Node) -> bool: return szene._passt_zur_suche(k.block, effekt.display_name.to_lower())),
			"Suche „%s“ findet den Effekt trotz Reiter Element (%d Treffer)" % [effekt.display_name, karten.size()])
	szene._suche.text = "zzzqqq"
	szene._suche.text_changed.emit(szene._suche.text)
	await _bilder(3)
	_check(_bib_karten(szene).is_empty() and szene._library_list.get_child_count() == 1,
		"Suche ohne Treffer: nur ein Hinweis")
	szene._suche.text = ""
	szene._suche.text_changed.emit("")
	await _bilder(3)
	_check(_bib_raster(szene) == 1, "leere Suche: wieder nur der Reiter")
	_check(szene._suche.focus_mode == Control.FOCUS_CLICK, "Suchfeld fängt die WASD-Navigation nicht ein")
	szene._geaendert = false
	szene.queue_free()
	await _bilder(2)
	# Nächstes Öffnen: derselbe Reiter.
	var wieder = load("res://scenes/workshop/skill_workshop.tscn").instantiate()
	root.add_child(wieder)
	await _bilder(4)
	_check(wieder._kategorie == 2 and _bib_karten(wieder).all(func(k: Node) -> bool: return k.block is ElementBlock),
		"beim nächsten Öffnen wieder Reiter Element")
	skript.letzte_kategorie = 0
	wieder._geaendert = false
	wieder.queue_free()
	await _bilder(2)


## Klotz-Kette (Formen-Pass): feste Reihenfolge, Klick schiebt an die richtige
## Stelle, Ziehen an die falsche wird abgewiesen, Kerben je Quellen-Typ,
## Bibliothek zeigt „passt jetzt“, alte Reihenfolge = Fehler (Reparieren sortiert).
func _test_klotz_kette(gs: Node) -> void:
	print("Klotz-Kette und Formen:")
	var held: Combatant = gs.party[0]
	var b := func(id: StringName) -> SkillBlock: return BlockLibrary.get_block(id)
	var spell: SkillBlock = b.call(&"src_spell")
	var fire: SkillBlock = b.call(&"elem_fire")
	var aoe: SkillBlock = b.call(&"form_aoe")
	_check(Skill.rang(spell) == 0 and Skill.rang(aoe) == 1 and Skill.rang(fire) == 2,
		"Ränge: Quelle 0, Form 1, Element 2")
	var falsch := Skill.new()
	falsch.blocks = [spell, fire, aoe]
	_check(not KlotzKette.werkstatt_fehler(falsch, held).is_empty(),
		"alte Reihenfolge ist in der Werkstatt ein Fehler (%s)" % KlotzKette.werkstatt_fehler(falsch, held))
	_check(falsch.fehler(held).is_empty(), "im Kampf bleibt ein Skill in alter Reihenfolge einsetzbar")
	var sortiert := Skill.sortiert(falsch.blocks)
	_check(sortiert[0] == spell and sortiert[1] == aoe and sortiert[2] == fire, "sortiert: Quelle, Form, Element")
	# Einfügen an der richtigen Stelle.
	var kette := Skill.new()
	kette.blocks = [spell, fire]
	_check(KlotzKette.einfuege_index(kette, aoe) == 1, "Form gehört zwischen Quelle und Element")
	_check(KlotzKette.passt_einfuegen(Skill.new(), 0, fire, held) != "", "ohne Quelle passt zuerst nur eine Quelle")
	_check(KlotzKette.passt_einfuegen(Skill.new(), 0, spell, held) == "", "Quelle passt in einen leeren Skill")
	# Kerben: an welchen Quellen ein Klotz geht.
	_check(KlotzKette.quelle_typen(spell) == [&"zauber"], "Zauber trägt die runde Nase")
	_check(KlotzKette.quelle_typen(aoe).size() == 3, "„Alle Gegner“ passt an jede Quelle")
	var selbst: SkillBlock = b.call(&"form_self")
	var selbst_typen := KlotzKette.quelle_typen(selbst)
	_check(not &"waffe" in selbst_typen and &"zauber" in selbst_typen and &"koerper" in selbst_typen,
		"„Selbst“: Zauber oder Körper, nicht Waffe (%s)" % [selbst_typen])
	var beschwoeren: SkillBlock = b.call(&"form_summon")
	if beschwoeren != null:
		_check(KlotzKette.quelle_typen(beschwoeren) == [&"zauber"], "Beschwören nur mit Zauber")
	var provozieren: SkillBlock = b.call(&"eff_provozieren")
	if provozieren != null:
		_check(KlotzKette.quelle_typen(provozieren) == [&"koerper"], "Provozieren nur mit Körper")
	var form := KlotzKette.umriss(Vector2(98, 92), [&"zauber", &"koerper"], [&"zauber"])
	_check(form.size() > 8, "Umriss mit zwei Kerben und Nase (%d Punkte)" % form.size())

	# In der Werkstatt: Klick schiebt, Ziehen an die falsche Stelle wird abgewiesen.
	held.level = 10
	held.peak_level = 10
	var szene = load("res://scenes/workshop/skill_workshop.tscn").instantiate()
	root.add_child(szene)
	await _bilder(4)
	var skill: Skill = held.skills[0]
	skill.blocks = [spell, fire] as Array[SkillBlock]
	szene._aktiv_index = 0
	szene._rebuild_editors()
	await _bilder(2)
	szene.klotz_hinzufuegen(aoe)
	_check(skill.blocks.size() == 3 and skill.blocks[1] == aoe, "Klick: Form rückt vor das Element")
	skill.blocks = [spell, fire] as Array[SkillBlock]
	szene._rebuild_editors()
	await _bilder(2)
	var sockel = szene._editors[0]["sockets"][2]
	_check(not sockel._can_drop_data(Vector2.ZERO, {"block": aoe}), "Ziehen: Form hinter das Element wird abgewiesen")
	_check(sockel.gestrichelt and sockel.links == [&"zauber"], "nächster Platz zeigt die Kerbe der Kette")
	_check(szene._editors[0]["sockets"][0].links.is_empty(), "Quelle ist das Startstück (glatte Kante)")
	# Bibliothek: passt jetzt / passt nicht.
	szene._kategorie_waehlen(szene.ALLE)
	await _bilder(3)
	var hell := 0
	var grau := 0
	for k in _bib_karten(szene):
		if k.locked:
			continue
		if k.passt_jetzt:
			hell += 1
		else:
			grau += 1
	_check(hell > 0 and grau > 0, "Bibliothek markiert passende und unpassende Klötze (%d / %d)" % [hell, grau])
	var gift: SkillBlock = b.call(&"elem_poison")
	for k in _bib_karten(szene):
		if k.block == gift and not k.locked:
			_check(not k.passt_jetzt and "✕" in k.tooltip_text, "zweites Element: grau mit Grund im Tooltip")
	# Alte Reihenfolge: Fehler, Reparieren sortiert ohne Verlust.
	skill.blocks = [spell, fire, aoe] as Array[SkillBlock]
	szene._rebuild_editors()
	await _bilder(2)
	_check(szene._editors[0]["reparieren"].visible, "alte Reihenfolge: Reparieren wird angeboten")
	szene._reparieren(skill)
	await _bilder(2)
	_check(skill.blocks.size() == 3 and KlotzKette.werkstatt_fehler(skill, held).is_empty(),
		"Reparieren sortiert, alle drei Klötze bleiben")
	# Vorlagen in Kettenfolge (Heilung: Zauber, Verbündeter, Heilig).
	var namen := []
	for v in szene._vorlagen_fuer_helden():
		namen.append(v.name_key)
		_check(v.reihenfolge_fehler().is_empty(), "Vorlage %s in Kettenfolge" % v.display_name)
	skill.blocks.clear()
	szene._geaendert = false
	szene.queue_free()
	await _bilder(2)


func _bib_karten(szene: Node) -> Array:
	return szene._library_list.find_children("*", "PanelContainer", true, false) \
		.filter(func(k: Node) -> bool: return "block" in k and not k.is_queued_for_deletion())


func _bib_raster(szene: Node) -> int:
	return szene._library_list.find_children("*", "GridContainer", false, false) \
		.filter(func(k: Node) -> bool: return not k.is_queued_for_deletion()).size()


## Waffen-Training: feste Aktionsleiste, Fortschritt, Auf-/Zuklappen, Fokus bleibt.
func _test_training(gs: Node) -> void:
	print("Waffen-Training:")
	var held: Combatant = gs.party[0]
	held.skill_points = 10
	var szene = load("res://scenes/workshop/training.tscn").instantiate()
	root.add_child(szene)
	await _bilder(4)
	var gefuehrt: StringName = &""
	var fremd: StringName = &""
	for family in szene.TREES:
		if held.wields_family(family) and gefuehrt == &"":
			gefuehrt = family
		elif not held.wields_family(family) and fremd == &"":
			fremd = family
	_check(gefuehrt != &"" and fremd != &"", "geführte und fremde Waffe gefunden (%s / %s)" % [gefuehrt, fremd])
	_check(szene._bestaetigen.disabled and szene._zuruecksetzen.disabled, "ohne Planung: Bestätigen/Zurücksetzen gesperrt")
	_check(szene.baum_offen(gefuehrt) and not szene.baum_offen(fremd), "geführte Waffe aufgeklappt, andere zu")
	var raus := _ausserhalb(szene)
	_check(raus.is_empty(), "Training: alles im Bild %s" % [raus.slice(0, 4)])
	var leiste_y: float = szene._bestaetigen.global_position.y

	var plus := _knopf_mit(szene, "plus1:" + String(gefuehrt))
	_check(plus != null, "+1 am geführten Baum")
	if plus != null:
		plus.grab_focus()
		await _bilder(1)
		plus.pressed.emit()
		await _bilder(3)
		_check(int(szene._pending.get(gefuehrt, 0)) == 1 and not szene._bestaetigen.disabled
			and "1" in szene._bestaetigen.text, "+1 plant einen Punkt, Bestätigen zeigt (1)")
		var fokus: Control = szene.get_viewport().gui_get_focus_owner()
		_check(fokus != null and fokus.has_meta(&"fokus_id") and fokus.get_meta(&"fokus_id") == "plus1:" + String(gefuehrt),
			"Fokus bleibt nach dem Neuaufbau auf +1 (%s)" % [fokus])
		_check(is_equal_approx(szene._bestaetigen.global_position.y, leiste_y), "Aktionsleiste springt nicht")
		var liste_y: float = (szene._tree_list.get_parent() as Control).global_position.y
		szene._verwerfen_ok("zurueck")  # erste Warnung (wie ein Klick auf Zurück)
		await _bilder(3)
		_check(not szene._verwerfen_warnung.is_empty(),
			"Warnung beim Verwerfen erscheint")
		_check(is_equal_approx((szene._tree_list.get_parent() as Control).global_position.y, liste_y)
			and szene._points_label.get_line_count() == 1,
			"Warnung ändert die Höhe der Leiste nicht, die Liste verrutscht nicht")
		szene._verwerfen_warnung = ""
		var vorher: int = held.invested(gefuehrt)
		szene._bestaetigen.pressed.emit()
		await _bilder(3)
		_check(held.invested(gefuehrt) == vorher + 1 and held.skill_points == 9 and szene._pending.is_empty(),
			"Bestätigen investiert (%d → %d)" % [vorher, held.invested(gefuehrt)])

	var klappe := _knopf_mit(szene, "klappe:" + String(fremd))
	_check(klappe != null, "Klappe am eingeklappten Baum")
	if klappe != null:
		klappe.pressed.emit()
		await _bilder(3)
		_check(szene.baum_offen(fremd), "Klappe öffnet die Stufen")

	held.weapon_invest[gefuehrt] = 100
	szene._refresh()
	await _bilder(3)
	var plus_voll := _knopf_mit(szene, "plus1:" + String(gefuehrt))
	_check(plus_voll != null and plus_voll.disabled, "Baum auf 100: +1 gesperrt")
	var meister := _knopf_mit(szene, "meister:" + String(gefuehrt))
	_check(meister != null or not gefuehrt in Combatant.MEISTERSCHAFTEN, "Meisterschaft wählbar, sobald ein Baum 100 hat")
	held.weapon_invest.erase(gefuehrt)
	held.skill_points = 0
	szene.queue_free()
	await _bilder(2)


func _knopf_mit(wurzel: Node, fokus_id: String) -> BaseButton:
	for k in wurzel.find_children("*", "BaseButton", true, false):
		if not k.is_queued_for_deletion() and k.has_meta(&"fokus_id") and k.get_meta(&"fokus_id") == fokus_id:
			return k
	return null


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
