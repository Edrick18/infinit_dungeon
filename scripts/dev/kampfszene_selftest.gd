extends SceneTree
## Headless-Selbsttest für Kampfszene und 3D-Kampfbühne. Spieltest 11:
## ~62 000 Fehler in kampf_buehne_3d.gd — verlässt ein Gegner den Kampf
## mitten drin (Metallschleim entwischt, Dieb flieht, Beschwörung endet),
## muss seine Figur abgemeldet werden, und _process darf an einem schon
## freigegebenen Platzhalter nicht abbrechen. Dazu die strenge Zielprüfung
## für Pläne von außen (Koop-Gast, KI-Brücke).
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/kampfszene_selftest.gd
##
## Bühne und Kampfszene greifen auf Autoloads zu: Sie werden erst nach dem
## ersten Bild per load() geladen (vorher kompilieren sie im -s-Modus nicht).
## Speichern ist während des Tests gesperrt (GameState.slot_gesperrt).

var failures := 0


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
	await _test_buehne_direkt()
	await _test_kampfszene(gs)
	failures += waechter.fehler_melden()
	_ende()


func _ende() -> void:
	if failures == 0:
		print("SELFTEST OK — alle Kampfszenen-Tests bestanden")
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


## Bühne allein: Platzhalter A wird freigegeben, OHNE abzumelden.
func _test_buehne_direkt() -> void:
	print("Kampfbühne: freigegebener Platzhalter bricht _process nicht ab:")
	var buehne = load("res://scripts/stil3d/kampf_buehne_3d.gd").new()  # untypisiert: Skript erst zur Laufzeit
	root.add_child(buehne)
	buehne.aufbauen()
	# Vorwärmen: Effekt-Lichter und Boss-Spot leuchten kurz unmerklich (ein
	# Licht mit Energie 0 zählt beim Zeichnen nicht — sonst neue Shader-
	# Variante beim ersten Treffer), danach sind sie wieder aus.
	var pool: Array = buehne.effekte._lichter
	_check(pool.size() == KampfHalle.LICHT_BUDGET["effekte"] and pool.all(func(l: OmniLight3D) -> bool:
		return l.light_energy > 0.0), "Vorwärmen: Effekt-Lichter zählen beim Kampfstart")
	_check((buehne._halle["boss_spot"] as SpotLight3D).light_energy > 0.0, "Vorwärmen: Boss-Spot zählt beim Kampfstart")
	var ui := Control.new()
	ui.size = Vector2(1280, 720)
	root.add_child(ui)
	var plaetze: Array[Control] = []
	for i in 3:
		var platz := Control.new()
		platz.position = Vector2(300 + i * 250, 300)
		platz.size = Vector2(100, 100)
		ui.add_child(platz)
		plaetze.append(platz)
	# Treffer-Blitz: ein Material je Figur (nicht pro Treffer neu), Kontur-
	# Hüllen blitzen nicht mit, Overlays kommen danach zurück.
	var truhe := FigurenBau.truhe()
	buehne.anmelden(&"t", plaetze[2], truhe, func() -> bool: return true)
	var teile: Array = buehne._eintraege[&"t"]["teile"]
	_check(teile.size() == 1 and not Stil3D.ist_kontur((teile[0] as MeshInstance3D).material_override),
		"Blitz-Teile ohne Kontur-Hülle (%d)" % teile.size())
	buehne.blitz(&"t", false)
	var mat1: Variant = buehne._eintraege[&"t"]["blitz_mat"]
	buehne.blitz(&"t", true)
	_check(mat1 != null and mat1 == buehne._eintraege[&"t"]["blitz_mat"], "Blitz-Material wird wiederverwendet")
	_check((teile[0] as MeshInstance3D).material_overlay == mat1, "Blitz liegt als Overlay auf dem Körper")
	await _bilder(40)
	_check((teile[0] as MeshInstance3D).material_overlay == null, "nach dem Blitz ist das Overlay wieder weg")
	# Hit-Stop friert die Figur kurz ein, Squash staucht sie danach.
	buehne.trefferstopp(&"t")
	_check(float(buehne._eintraege[&"t"]["stopp"]) > 0.0, "Hit-Stop gesetzt")
	buehne.rueckstoss(&"t")
	_check(float(buehne._eintraege[&"t"]["quetsch"]) == 0.0, "Rückstoß startet den Squash")
	await create_timer(0.6).timeout
	# Konstante über die Skript-Tabelle: KampfEffekte direkt zu nennen, ließe
	# diesen Test im -s-Modus nicht kompilieren (Autoloads, s. oben).
	var reichweite: float = buehne.effekte.get_script().get_script_constant_map()["LICHT_REICHWEITE"]
	_check(pool.all(func(l: OmniLight3D) -> bool:
		return l.light_energy == 0.0 and is_equal_approx(l.omni_range, reichweite)),
		"nach dem Vorwärmen sind die Effekt-Lichter aus (normale Reichweite)")
	_check((buehne._halle["boss_spot"] as SpotLight3D).light_energy == 0.0, "nach dem Vorwärmen ist der Boss-Spot aus")
	# Hit-Stop nur bei echtem Krit/Volltreffer — „Schwachstelle“ kommt auch
	# als art krit, ist aber keiner.
	buehne._eintraege[&"t"]["stopp"] = 0.0
	var ort := {"welt": KampfHalle.MITTE, "schluessel": &"t"}
	buehne.effekte._einschlag({"art": &"krit", "schwach": true}, ort)
	_check(float(buehne._eintraege[&"t"]["stopp"]) == 0.0, "Schwachstelle löst keinen Hit-Stop aus")
	buehne.effekte._einschlag({"art": &"krit", "voll": true}, ort)
	_check(float(buehne._eintraege[&"t"]["stopp"]) > 0.0, "Volltreffer löst Hit-Stop aus")
	buehne.abmelden(&"t")
	buehne.anmelden(&"a", plaetze[0], Node3D.new(), func() -> bool: return true)
	buehne.anmelden(&"b", plaetze[1], Node3D.new(), func() -> bool: return true)
	plaetze[0].free()  # wie das queue_free des Panels ohne abmelden
	buehne._process(0.016)
	_check(not buehne.hat(&"a"), "Eintrag mit freigegebenem Platzhalter wird abgemeldet")
	var fig_b: Node3D = buehne._eintraege[&"b"]["fig"]
	_check(fig_b.visible, "spätere Figur wird weiter positioniert und gezeigt")
	# Danach angemeldete Figur erscheint ebenfalls (vorher blieb sie unsichtbar).
	buehne.anmelden(&"c", plaetze[2], Node3D.new(), func() -> bool: return true)
	buehne._process(0.016)
	var fig_c: Node3D = buehne._eintraege[&"c"]["fig"]
	_check(fig_c.visible, "neu angemeldete Figur wird sichtbar")
	# Auch eine schon freigegebene Figur darf abmelden() nicht stören.
	fig_b.free()
	buehne._process(0.016)
	_check(not buehne.hat(&"b"), "Eintrag mit freigegebener Figur wird abgemeldet")
	buehne.queue_free()
	ui.queue_free()
	await _bilder(2)


## Echte Kampfszene: drei Gegner verlassen den Kampf über alle Wege, die
## combatant_removed senden; die Szene muss sie von der Bühne abmelden.
func _test_kampfszene(gs: Node) -> void:
	print("Kampfszene: entfernte Gegner werden von der Bühne abgemeldet:")
	var party: Array[Combatant] = TestContent.make_party()
	gs.party = party
	gs.current_run = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var gegner: Array[Combatant] = []
	for i in 4:
		gegner.append(EnemyFactory.build(EnemyLibrary.get_archetype(&"wolf"), 3, rng))
	gs.pending_battle = {"enemy_id": -1, "is_boss": false, "enemies": gegner}
	var szene = load("res://scenes/battle/battle_scene.tscn").instantiate()
	root.add_child(szene)
	await _bilder(3)
	var battle: Battle = szene.battle
	var buehne = szene._buehne
	_check(buehne.hat(gegner[0]) and buehne.hat(gegner[3]), "alle Gegner stehen auf der Bühne")

	# 1) Metallschleim-Weg: entwischt sicher.
	gegner[0].flee_chance = 1.0
	_check(battle._try_flee(gegner[0]), "Gegner entwischt (_try_flee)")
	# 2) Taschendieb flieht mit dem Gold (Zufall: bis zu 500 Versuche).
	gegner[1].eigenheit = &"taschendieb"
	battle._diebe[gegner[1]] = 1
	var dieb_weg := false
	for i in 500:
		if battle._eigenheit_zug(gegner[1]):
			dieb_weg = true
			break
	_check(dieb_weg, "Dieb flieht (_eigenheit_zug)")
	# 3) Beschwörung endet.
	battle._remove_summon(gegner[2], "verpufft")
	await _bilder(4)
	for i in 3:
		_check(not buehne.hat(gegner[i]), "entfernter Gegner %d ist abgemeldet" % (i + 1))
	_check(buehne.hat(gegner[3]), "verbliebener Gegner bleibt auf der Bühne")

	# Nachrücker (wie der gestapelte Schleimkönig) muss sichtbar werden.
	var neu := EnemyFactory.build(EnemyLibrary.get_archetype(&"wolf"), 3, rng)
	battle.enemies.append(neu)
	battle.combatant_added.emit(neu)
	await _bilder(4)
	_check(buehne.hat(neu), "Nachrücker steht auf der Bühne")
	if buehne.hat(neu):
		var fig: Node3D = buehne._eintraege[neu]["fig"]
		_check(fig.visible, "Nachrücker ist sichtbar")

	print("Kampfszene: Pläne von außen werden streng geprüft:")
	var held: Combatant = battle.players[0]
	var held_id := int(szene._net_ids[held])
	var feind_id := int(szene._net_ids[gegner[3]])
	var plan: Dictionary = szene._plan_from_net(held, {"kind": "attack", "target": 99})
	_check(plan["kind"] == "defend" and String(plan.get("fehler", "")).contains("#99"),
		"Angriff auf unbekannte ID: Fehler statt stillem Ersatzziel")
	plan = szene._plan_from_net(held, {"kind": "attack", "target": held_id})
	_check(plan.has("fehler"), "Angriff auf den eigenen Helden wird abgelehnt")
	plan = szene._plan_from_net(held, {"kind": "attack", "target": feind_id})
	_check(plan["kind"] == "attack" and plan["target"] == gegner[3], "gültiger Angriff wird übernommen")
	var heilung := Skill.new()
	heilung.display_name = "Testheilung"
	heilung.blocks = [BlockLibrary.get_block(&"src_spell"), BlockLibrary.get_block(&"form_ally")]
	held.skills.insert(0, heilung)
	if heilung.is_valid(held):
		plan = szene._plan_from_net(held, {"kind": "skill", "skill": 0, "target": feind_id})
		_check(plan.has("fehler"), "Heil-Skill auf einen Gegner wird abgelehnt")
		plan = szene._plan_from_net(held, {"kind": "skill", "skill": 0, "target": held_id})
		_check(plan["kind"] == "skill" and plan["target"] == held, "Heil-Skill auf Verbündeten wird übernommen")
	else:
		_check(false, "Test-Heilskill ist gültig: " + heilung.fehler(held))
	held.skills.remove_at(0)

	print("Kampfszene: Ergebnisfenster aus der Bildschirm-Vorlage:")
	var bildschirm = load("res://scripts/ui/bildschirm.gd")
	szene._on_battle_ended(false)
	await _bilder(2)
	var fokus := root.gui_get_focus_owner()
	_check(fokus is Button and (fokus as Button).text == Loc.pick("Zurück zum Hub", "Back to hub"),
		"Niederlage: Fokus auf dem Zurück-Knopf")
	var fenster_da := false
	for tafel in szene.find_children("*", "PanelContainer", true, false):
		if (tafel as Control).custom_minimum_size.x == bildschirm.FENSTER_BREITE and tafel.get_parent() is CenterContainer:
			fenster_da = fenster_da or tafel.is_ancestor_of(fokus)
	_check(fenster_da, "Ergebnis sitzt in Bildschirm.fenster")
	szene.queue_free()
	gs.pending_battle = {}
	await _bilder(2)
