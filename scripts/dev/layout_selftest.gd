extends SceneTree
## Headless-Selbsttest Layout-Pass 2026-11 (Lutz: „da verschwinden Sachen
## vom Bildschirm, z. B. bei den Drops nach einem Kampf“): die betroffenen
## Fenster unter Stress-Daten — jedes bedienbare Element liegt im Bild oder
## steckt in einer Scroll-Liste, die selbst im Bild liegt.
##  • Taschen voll mit 40 wartenden Teilen (lange Namen): Knöpfe im Bild.
##  • Kampf mit 8 Gegnern (lange Namen), allen Tränken, allen Skill-Slots:
##    Gegnerreihe, Befehlsspalte, Log und Party-Karten im Bild.
##  • Sieg mit 8-facher Beute, Aufstiegen, langen Bank-Namen: Fenster im Bild,
##    Punkte-Knöpfe UNTER der Liste (W vom ersten Knopf erreicht die Liste).
##  • Inventar mit 24-Zeichen-Namen; Dungeon-Meldung neben der Minimap.
##  • Scroll-Listen aller Hub-Bildschirme folgen dem Tastatur-Fokus.
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
	await _test_follow_focus()
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
		taschen._schliessen(layer)
	szene.queue_free()
	gs.beute_warteliste.clear()
	gs.inventory = inventar_vorher
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
