extends SceneTree
## Headless-Selbsttest Layout-Pass 2026-11 (Lutz: „da verschwinden Sachen
## vom Bildschirm, z. B. bei den Drops nach einem Kampf“): die betroffenen
## Fenster unter Stress-Daten — jedes bedienbare Element liegt im Bild oder
## steckt in einer Scroll-Liste, die selbst im Bild liegt.
##  • Taschen voll mit 40 wartenden Teilen (lange Namen): Knöpfe im Bild.
##  • Kampf mit 8 Gegnern (lange Namen), allen Tränken, allen Skill-Slots:
##    Gegnerreihe, Befehlsspalte, Log und Party-Karten im Bild.
##  • Kampfbühne: breite 3D-Figuren (Golem, Troll, Riesenwuchs, Boss mit
##    Begleitern) ab 7 Gegnern ganz im Bild und kaum überlappend; bei 1–6
##    Gegnern unverändert (keine Höchstbreite, Faktor 1).
##  • Sieg mit 8-facher Beute, Aufstiegen, langen Bank-Namen: Fenster im Bild,
##    Punkte-Knöpfe UNTER der Liste (W vom ersten Knopf erreicht die Liste).
##  • Inventar mit 24-Zeichen-Namen; Dungeon-Meldung neben der Minimap.
##  • Scroll-Listen aller Hub-Bildschirme folgen dem Tastatur-Fokus.
##  • Item-Icons (Icon-Pass 2): Beute-Zeilen im Sieg-Fenster, wartende Teile
##    bei „Taschen voll“, Händler-Ausrüstung, Schmiede „Kann werden“ und die
##    Item-Karte haben ihr Icon, und keins ragt aus Zeile oder Bild.
##  • Fenstermodus: Auflösung passt samt Rahmen in den nutzbaren Bereich.
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/layout_selftest.gd
##
## Szenen und UI-Skripte hängen an Autoloads: erst nach dem ersten Bild per
## load() laden. Speichern ist gesperrt (Wegwerf-Slot 98), alles im Speicher.

var failures := 0
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	await process_frame
	var gs: Node = root.get_node_or_null(^"GameState")
	_check(gs != null, "GameState-Autoload vorhanden")
	if gs == null:
		_ende()
		return
	gs.slot_gesperrt = true
	SaveManager.active_slot = 98
	_rng.seed = 4711
	for hinweis in ["dungeon", "kampf", "menu", "werkstatt", "inventar", "schmiede", "haendler", "taverne"]:
		gs.first_time(hinweis)
	var waechter := FehlerWaechter.anmelden()
	_test_fenster_rechteck()
	_stress(gs)
	await _test_taschen_voll(gs)
	await _test_kampf_und_sieg(gs)
	await _test_inventar()
	await _test_meldung()
	await _test_kampf_figuren(gs)
	await _test_follow_focus()
	await _test_haendler_schmiede_icons()
	failures += waechter.fehler_melden()
	_ende()


func _ende() -> void:
	if failures == 0:
		print("SELFTEST OK — alle Layout-Tests bestanden")
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


## Bedienbare Elemente und Texte außerhalb des Bildes (Elemente in einer
## Scroll-Liste zählen, wenn die Liste selbst im Bild liegt).
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


## Icons in Text-Zeilen (UiHolz.icon_im_text): [Anzahl mit Textur, Fehler].
## Jedes Icon liegt in seinem Label und — samt Label bzw. dessen Scroll-
## Liste — im Bild.
func _zeilen_icons(wurzel: Node) -> Array:
	var bild := root.get_visible_rect().grow(1.0)
	var mit := 0
	var fehler: Array[String] = []
	for knoten in wurzel.find_children("*", "TextureRect", true, false):
		var icon := knoten as TextureRect
		var label := icon.get_parent() as Label
		if label == null or not icon.is_visible_in_tree():
			continue
		if icon.texture != null:
			mit += 1
		if not label.get_global_rect().grow(1.0).encloses(icon.get_global_rect()):
			fehler.append("Icon ragt aus '%s'" % label.text.left(30))
		var scroll := _scroll_vorfahr(label)
		var r := scroll.get_global_rect() if scroll != null else icon.get_global_rect()
		if not bild.encloses(r):
			fehler.append("Icon außerhalb: '%s' %s" % [label.text.left(30), r])
	return [mit, fehler]


func _scroll_vorfahr(c: Node) -> ScrollContainer:
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return p
		p = p.get_parent()
	return null


## Die n Gegenstände mit den längsten Namen aus vielen Würfen.
func _lange_items(n: int, stufe: int) -> Array[ItemInstance]:
	var alle: Array[ItemInstance] = []
	for i in maxi(1500, n * 4):
		alle.append(LootGenerator.roll_item_with_rarity(stufe, Enums.Rarity.LEGENDARY, _rng))
	alle.sort_custom(func(a: ItemInstance, b: ItemInstance) -> bool:
		return a.get_display_name().length() > b.get_display_name().length())
	return alle.slice(0, n)


## 4 Party- und 6 Bank-Helden mit 24 Zeichen langen Namen, alle Tränke.
func _stress(gs: Node) -> void:
	gs.party.clear()
	gs.reserve.clear()
	var kits: Array = load("res://scripts/data/hero_library.gd").STARTER_LOADOUTS.keys()
	for i in 10:
		gs.recruit("Friederike Sonnenwald X%d" % i, kits[i % kits.size()])
	for def in load("res://scripts/data/consumable_library.gd").all_defs():
		gs.add_consumable(def.id, 99)


func _test_fenster_rechteck() -> void:
	print("Fenstermodus: Auflösung passt samt Rahmen in den nutzbaren Bereich:")
	var settings = load("res://autoload/settings.gd")
	var nutzbar := Rect2i(0, 74, 1920, 1032)  # 1080p-Monitor mit Taskleiste
	var rahmen := Vector2i(16, 39)
	for aufl: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440)]:
		var r: Rect2i = settings.fenster_rechteck(aufl, nutzbar, rahmen)
		var ganz := Rect2i(r.position, r.size + rahmen)
		_check(nutzbar.encloses(ganz), "%s: ganzes Fenster im nutzbaren Bereich (%s)" % [aufl, ganz])
		_check(absf(float(r.size.x) / r.size.y - float(aufl.x) / aufl.y) < 0.01,
			"%s: Seitenverhältnis bleibt (%s)" % [aufl, r.size])
	var klein: Rect2i = settings.fenster_rechteck(Vector2i(1280, 720), nutzbar, rahmen)
	_check(klein.size == Vector2i(1280, 720), "passt die Auflösung, bleibt sie unverändert")


func _test_taschen_voll(gs: Node) -> void:
	print("Taschen voll: 40 wartende Teile mit langen Namen:")
	var inventar_vorher: Array = gs.inventory.duplicate()
	while gs.inventory.size() < gs.TASCHEN_LIMIT:
		gs.inventory.append(LootGenerator.roll_item_with_rarity(30, Enums.Rarity.COMMON, _rng))
	gs.beute_warteliste.clear()
	gs.beute_warteliste.append_array(_lange_items(40, 99))
	var szene := Control.new()
	szene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(szene)
	var taschen = load("res://scripts/ui/taschen_voll.gd")
	var layer: CanvasLayer = taschen.pruefen(szene, Callable())
	await _bilder(5)
	_check(layer != null, "Fenster erscheint")
	if layer != null:
		var raus := _ausserhalb(layer)
		_check(raus.is_empty(), "alle Zeilen und Knöpfe im Bild %s" % [raus])
		var listen := layer.find_children("*", "ScrollContainer", true, false)
		_check(listen.size() == 1 and listen[0].laeuft_ueber() and listen[0].focus_mode == Control.FOCUS_ALL,
			"Item-Zeilen in einer Scroll-Liste, per Tastatur erreichbar")
		var fokus := root.gui_get_focus_owner()
		_check(fokus is Button and not listen.is_empty() and fokus.find_valid_focus_neighbor(SIDE_TOP) == listen[0],
			"W vom ersten Knopf führt in die Liste")
		var icons := _zeilen_icons(layer)
		_check(int(icons[0]) == taschen.MAX_ZEILEN and (icons[1] as Array).is_empty(),
			"jede genannte Item-Zeile mit Icon, keins ragt heraus (%d) %s" % [icons[0], icons[1]])
		taschen._schliessen(layer)
	szene.queue_free()
	gs.beute_warteliste.clear()
	gs.inventory = inventar_vorher
	await _bilder(2)


## Kampfbühne mit vielen breiten Gegnern: die 3D-Figuren (Körper-Umriss ins
## Bild projiziert, KampfBuehne3D.bild_umriss) liegen im Viewport, Nachbarn
## überlappen höchstens geringfügig, jede Figur steht über ihrem Panel, der
## Boss bleibt die größte Figur (Fläche). Unter KampfUi.FIGUR_BREITE_AB Gegnern greift
## nichts (Positionen und Skalen wie vor dem Pass).
func _test_kampf_figuren(gs: Node) -> void:
	print("Kampfbühne: breite Figuren bei vielen Gegnern:")
	var kampf_ui = load("res://scripts/ui/kampf_ui.gd")
	var ab: int = kampf_ui.FIGUR_BREITE_AB
	var faelle: Array = [
		["8 Riesen-Golems", [[&"golem", 8, 1.3, false]]],
		["8 gemischt breit (Riesen)", [[&"golem", 2, 1.3, false], [&"troll", 2, 1.3, false],
			[&"baer", 2, 1.3, false], [&"schattenbestie", 2, 1.3, false]]],
		["Boss + 7 Golems", [[&"schleimgott", 1, 1.0, true], [&"golem", 7, 1.0, false]]],
		["7 Riesen-Golems", [[&"golem", 7, 1.3, false]]],
	]
	for n in range(1, ab):
		faelle.append(["%d Riesen-Golems" % n, [[&"golem", n, 1.3, false]]])
	for fall in faelle:
		var feinde: Array[Combatant] = []
		for teil in fall[1]:
			for i in int(teil[1]):
				var f: Combatant = EnemyFactory.build(EnemyLibrary.get_archetype(teil[0]), 3, _rng)
				f.sprite_scale *= float(teil[2])
				f.is_boss = bool(teil[3])
				feinde.append(f)
		gs.start_run(load("res://scripts/dungeon/card_factory.gd").make_card(20, _rng))
		gs.pending_battle = {"enemy_id": -1, "is_boss": false, "enemies": feinde, "ueberraschung": 0}
		var szene = load("res://scenes/battle/battle_scene.tscn").instantiate()
		root.add_child(szene)
		await _bilder(12)
		if bool(fall[1][0][3]):
			# Boss-Auftritt abwarten (Letterbox, Beben): danach steht die Bühne.
			await create_timer(4.0).timeout
		var buehne = szene._buehne
		var rechtecke: Array[Rect2] = []
		var unter_panel := true
		var faktoren := true
		var mit_meta := false
		for f in feinde:
			var r: Rect2 = buehne.bild_umriss(f)
			rechtecke.append(r)
			var panel: Control = szene._enemy_buttons[f]
			var fuss_x: float = buehne._kamera.unproject_position((buehne._eintraege[f]["fig"] as Node3D).global_position).x
			var pr := panel.get_global_rect()
			unter_panel = unter_panel and fuss_x > pr.position.x and fuss_x < pr.end.x
			var platz: Control = panel.get_meta(&"figur_platz")
			mit_meta = mit_meta or platz.has_meta(&"max_breite")
			faktoren = faktoren and is_equal_approx(float(buehne._eintraege[f]["breite_faktor"]), 1.0)
		var name: String = fall[0]
		if feinde.size() < ab:
			_check(not mit_meta and faktoren, "%s: unverändert (keine Höchstbreite, Faktor 1)" % name)
		else:
			var bild := root.get_visible_rect().grow(1.0)
			var raus := 0
			for r in rechtecke:
				if not bild.encloses(r):
					raus += 1
			var ueber := 0.0
			for i in rechtecke.size() - 1:
				var a := rechtecke[i]
				var b := rechtecke[i + 1]
				ueber = maxf(ueber, (a.end.x - b.position.x) / minf(a.size.x, b.size.x))
			_check(raus == 0, "%s: alle Figuren ganz im Bild (%d ragen hinaus)" % [name, raus])
			_check(ueber <= 0.06, "%s: Nachbarn überlappen höchstens geringfügig (%.0f %%)" % [name, ueber * 100.0])
			_check(not faktoren, "%s: Höchstbreite greift" % name)
		_check(unter_panel, "%s: jede Figur steht über ihrem Panel" % name)
		if bool(fall[1][0][3]):
			# Fläche statt Höhe: der Schleimgott ist flach und breit.
			var boss_a := rechtecke[0].get_area()
			var groesste := 0.0
			for i in range(1, rechtecke.size()):
				groesste = maxf(groesste, rechtecke[i].get_area())
			_check(boss_a > groesste * 1.15, "%s: Boss bleibt die größte Figur (Fläche %.0f vs. %.0f px²)"
				% [name, boss_a, groesste])
		szene.queue_free()
		await _bilder(2)


func _test_kampf_und_sieg(gs: Node) -> void:
	print("Kampf mit 8 Gegnern, allen Tränken und allen Skill-Slots:")
	var card: DungeonCard = load("res://scripts/dungeon/card_factory.gd").make_card(60, _rng)
	gs.start_run(card)
	for held: Combatant in gs.party:
		held.xp = held.xp_to_next() - 1  # Aufstieg nach dem Sieg
		var vorlage: Skill = held.skills[0]
		for stufe in 60:
			held.gain_xp(held.xp_to_next())  # Level 60+: alle Skill-Slots
		while held.skills.size() < held.skill_slots():
			var neu := Skill.new()
			neu.display_name = "Sehr langer Skillname Nummer %d" % held.skills.size()
			neu.blocks = vorlage.blocks.duplicate()
			held.skills.append(neu)
	var feinde: Array[Combatant] = []
	for id in [&"wolf", &"baer", &"troll", &"skelett", &"golem", &"mimic", &"spinne", &"golem"]:
		var f: Combatant = EnemyFactory.build(EnemyLibrary.get_archetype(id), 3, _rng)
		f.display_name = "Kartenhüter: " + f.display_name
		f.loot_mult *= 8.0
		feinde.append(f)
	gs.pending_battle = {"enemy_id": -1, "is_boss": false, "enemies": feinde, "ueberraschung": 0}
	var szene = load("res://scenes/battle/battle_scene.tscn").instantiate()
	root.add_child(szene)
	await _bilder(8)
	var raus := _ausserhalb(szene)
	_check(raus.is_empty(), "Befehlsmenü, Gegnerreihe und Party-Karten im Bild %s" % [raus.slice(0, 4)])
	szene._show_item_menu()
	await _bilder(4)
	raus = _ausserhalb(szene)
	_check(raus.is_empty(), "Item-Menü mit allen Tränken: im Bild oder in der Liste %s" % [raus.slice(0, 4)])
	var spalte: ScrollContainer = _scroll_vorfahr(szene._action_box)
	var kampf_ui = load("res://scripts/ui/kampf_ui.gd")
	_check(spalte != null and spalte.laeuft_ueber() and spalte.size.y <= kampf_ui.AKTIONEN_MAX_HOEHE + 0.5,
		"Befehlsspalte scrollt und bleibt höchstens %d px hoch" % int(kampf_ui.AKTIONEN_MAX_HOEHE))
	szene._show_skill_menu()
	await _bilder(4)
	raus = _ausserhalb(szene)
	_check(raus.is_empty(), "Skill-Menü mit allen Slots: im Bild oder in der Liste %s" % [raus.slice(0, 4)])
	var breit := 0.0
	for knopf in szene._action_box.get_children():
		breit = maxf(breit, (knopf as Control).size.x)
	_check(breit <= kampf_ui.AKTIONEN_MAX_BREITE + 0.5, "lange Skillnamen verbreitern die Spalte nicht (%d px)" % int(breit))

	print("Sieg mit 8-facher Beute, Aufstiegen und langen Bank-Namen:")
	var battle = szene.battle
	for f: Combatant in battle.enemies:
		f.hp = 0
	battle.is_over = true
	battle.battle_ended.emit(true)
	await _bilder(10)
	var fenster: CenterContainer = null
	for kind in szene.get_children():
		if kind is CenterContainer:
			fenster = kind
	_check(fenster != null, "Ergebnisfenster offen")
	if fenster != null:
		raus = _ausserhalb(fenster)
		_check(raus.is_empty(), "Seite 1: Beute und „Weiter“ im Bild %s" % [raus.slice(0, 4)])
		# Beute-Icons: Gold + jedes Item + jedes Material (Texturen kommen im
		# nächsten Bild, verteilt) — alle gesetzt, keins ragt heraus.
		var icons := _zeilen_icons(fenster)
		_check(int(icons[0]) >= 10 and (icons[1] as Array).is_empty(),
			"Beute-Zeilen mit Icon (%d), keins ragt heraus %s" % [icons[0], icons[1]])
		var gold_icon := false
		for l in fenster.find_children("*", "Label", true, false):
			if (l as Label).text.ends_with(" Gold") and (l as Label).get_child_count() > 0:
				gold_icon = ((l as Label).get_child(0) as TextureRect).texture != null
		_check(gold_icon, "Gold-Zeile hat das Gold-Icon")
		var weiter: Button = null
		for b in fenster.find_children("*", "Button", true, false):
			if (b as Button).is_visible_in_tree() and (b as Button).text == Loc.pick("Weiter »", "Next »"):
				weiter = b
		_check(weiter != null, "Level-Seite folgt")
		if weiter != null:
			weiter.pressed.emit()
			await _bilder(6)
			raus = _ausserhalb(fenster)
			_check(raus.is_empty(), "Level-Seite: Bank-Zeile umbrochen, Fenster im Bild %s" % [raus.slice(0, 4)])
			var tafel := fenster.get_child(0) as Control
			_check(root.get_visible_rect().encloses(tafel.get_global_rect()), "Fenster ragt nicht aus dem Bild (%s)" % tafel.get_global_rect())
			# Abnahme: die lange Bank-Zeile bricht auf die Breite der übrigen
			# Zeilen um, statt das Fenster auf fast die ganze Bildbreite zu ziehen.
			_check(tafel.size.x < 1000.0, "Bank-Zeile zieht das Fenster nicht auf volle Breite (%d px)" % int(tafel.size.x))
			var punkte: Array[Node] = get_nodes_in_group(&"punkte_knopf")
			var draussen: bool = not punkte.is_empty()
			for knopf in punkte:
				if _scroll_vorfahr(knopf) != null:
					draussen = false
			_check(draussen, "Punkte-Knöpfe stehen unter der Liste, nicht darin (%d)" % punkte.size())
	szene.queue_free()
	gs.clear_run()
	await _bilder(3)


func _test_inventar() -> void:
	print("Inventar: 4 Helden mit 24 Zeichen langen Namen:")
	var szene = load("res://scenes/inventory/inventory_scene.tscn").instantiate()
	root.add_child(szene)
	await _bilder(6)
	var raus := _ausserhalb(szene)
	_check(raus.is_empty(), "Kopfzeile, Reiter, Raster und Knöpfe im Bild %s" % [raus.slice(0, 4)])
	szene.queue_free()
	await _bilder(2)


func _test_meldung() -> void:
	print("Dungeon-Meldung: lange Truhen-Meldung bleibt neben der Minimap:")
	var hud = load("res://scripts/ui/dungeon_hud.gd").new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(hud)
	await _bilder(1)
	hud.meldung_zeigen("Legendäre Truhe: +123456 Gold!  Flammende leichte Handschuhe der Schattenabwehr!"
		+ "  (Taschen voll, wartet)  +1 Mini-Medaille!  +2 Seelenkristall!")
	await _bilder(3)
	var tafel: Control = hud._meldung_tafel
	var minimap_breite: float = load("res://scripts/ui/minimap.gd").MAX_GROESSE + 12.0
	var frei := root.get_visible_rect().size.x - minimap_breite
	_check(tafel.get_global_rect().end.x <= frei and tafel.get_global_rect().position.x >= minimap_breite,
		"Tafel endet vor der Minimap (%s)" % tafel.get_global_rect())
	hud.meldung_zeigen("+12 Gold")
	await _bilder(2)
	_check((hud._meldung as Label).autowrap_mode == TextServer.AUTOWRAP_OFF and tafel.size.x < 300.0,
		"kurze Meldung bleibt einzeilig und schmal")
	hud.queue_free()
	await _bilder(1)


func _test_follow_focus() -> void:
	print("Scroll-Listen folgen dem Tastatur-Fokus (WASD erreicht alles):")
	for pfad in ["res://scenes/hub/shop_scene.tscn", "res://scenes/hub/card_storage.tscn",
			"res://scenes/hub/tavern.tscn", "res://scenes/hub/lexicon.tscn",
			"res://scenes/workshop/training.tscn", "res://scenes/workshop/skill_workshop.tscn",
			"res://scenes/inventory/inventory_scene.tscn"]:
		var szene: Node = load(pfad).instantiate()
		root.add_child(szene)
		await _bilder(3)
		var ohne: Array[String] = []
		var listen := szene.find_children("*", "ScrollContainer", true, false)
		for sc in listen:
			if (sc as Control).get_window() != root:
				continue  # Listen in Aufklapp-Menüs (PopupMenu) scrollen selbst
			if not (sc as ScrollContainer).follow_focus:
				ohne.append(str(sc.get_path()).get_file())
		_check(not listen.is_empty() and ohne.is_empty(), "%s: %d Listen, alle folgen dem Fokus %s" % [
			pfad.get_file(), listen.size(), ohne])
		szene.queue_free()
		await _bilder(2)


func _test_haendler_schmiede_icons() -> void:
	print("Icons bei Händler (Ausrüstung, gekaufte Karte) und Schmiede („Kann werden“, Ergebnis):")
	var shop: Node = load("res://scenes/hub/shop_scene.tscn").instantiate()
	root.add_child(shop)
	await _bilder(3)
	var mit_icon := 0
	for k in Smith.KATEGORIEN:
		for b in shop.find_children("*", "Button", true, false):
			if (b as Button).text.begins_with(Smith.kategorie_name(k) + "
") and (b as Button).icon != null:
				mit_icon += 1
	_check(mit_icon == Smith.KATEGORIEN.size(), "Ausrüstungs-Knöpfe mit Icon (%d/%d)" % [mit_icon, Smith.KATEGORIEN.size()])
	shop._gekauft = LootGenerator.roll_item_with_rarity(20, Enums.Rarity.EPIC, _rng)
	shop._refresh()
	await _bilder(3)
	_check(_karten_icon(shop), "gekaufte Item-Karte zeigt das Icon im Kopf")
	shop.queue_free()
	await _bilder(2)
	var schmiede: Node = load("res://scenes/hub/smith.tscn").instantiate()
	root.add_child(schmiede)
	for kategorie in [&"ruestung", &"nebenhand"]:
		schmiede._kategorie = kategorie
		schmiede._level = 60
		schmiede._refresh()
		await _bilder(3)
		var icons := _zeilen_icons(schmiede)
		var soll: int = Smith.moegliche_basen(kategorie, schmiede._level).size()
		_check(int(icons[0]) == soll and (icons[1] as Array).is_empty(),
			"Schmiede %s: jede mögliche Basis mit Icon (%d/%d), keins ragt heraus %s" % [kategorie, icons[0], soll, icons[1]])
	schmiede._ergebnis = LootGenerator.roll_item_with_rarity(20, Enums.Rarity.RARE, _rng)
	schmiede._ergebnis_text = "Probe"
	schmiede._refresh()
	await _bilder(3)
	_check(_karten_icon(schmiede), "Schmiede-Ergebnis: Item-Karte mit Icon")
	var raus := _ausserhalb(schmiede)
	_check(raus.is_empty(), "Schmiede mit Icons: alles im Bild %s" % [raus.slice(0, 4)])
	schmiede.queue_free()
	await _bilder(2)


## Eine Item-Karte (Rand in Raritätsfarbe) mit Icon im Kopf?
func _karten_icon(szene: Node) -> bool:
	for k in szene.find_children("*", "PanelContainer", true, false):
		var zeile := (k as PanelContainer).get_child(0).get_child(0) if (k as PanelContainer).get_child_count() > 0 			and (k as PanelContainer).get_child(0).get_child_count() > 0 else null
		if zeile is HBoxContainer and zeile.get_child(0) is TextureRect 				and (zeile.get_child(0) as TextureRect).texture != null:
			return true
	return false
