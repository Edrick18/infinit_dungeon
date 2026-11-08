extends SceneTree
## Headless-Selbsttest Ausrüstungsfenster (Spieltest v0.2.0):
##  • FigurenVorschau dreht sich nicht mehr von selbst (Grundpose
##    PortraitStudio.DREHUNG_GRAD), sondern per Maus-Ziehen links/rechts und
##    mit gehaltenem Komma/Punkt — nicht, solange ein Textfeld den Fokus hat.
##  • Inventar: Heldenleiste oben, darunter die Reiter — Ausrüstung und Werte
##    in der Tafel des gewählten Helden (mit seinem Namen), Tränke und
##    Materialien in der Tafel „Gruppe“. Mit 4 Helden mit langen Namen
##    (deutsch und englisch, 1280×720) liegt alles im Bild; W/S wechselt
##    zwischen Heldenleiste und Reitern.
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/ausruestung_ansicht_selftest.gd
##
## Szenen und UI-Skripte hängen an Autoloads: erst nach dem ersten Bild per
## load() laden. Speichern ist gesperrt (Wegwerf-Slot 99), alles im Speicher.

const NAMEN := ["Wilhelmina-Kunigunde Abc", "Maximilian von Eschenba", "Bartholomäus Grünwaldt",
	"Konstantinopel-Reisende"]

var failures := 0


func _initialize() -> void:
	await process_frame
	var gs: Node = root.get_node_or_null(^"GameState")
	_check(gs != null, "GameState-Autoload vorhanden")
	if gs == null:
		_ende()
		return
	gs.slot_gesperrt = true
	SaveManager.active_slot = 99
	root.size = Vector2i(1280, 720)
	for hinweis in ["dungeon", "kampf", "menu", "werkstatt", "inventar", "schmiede", "haendler", "taverne"]:
		gs.first_time(hinweis)
	var waechter := FehlerWaechter.anmelden()
	await _test_vorschau()
	_party(gs)
	for sprache in ["de", "en"]:
		await _test_inventar(gs, sprache)
	gs.language = "de"
	failures += waechter.fehler_melden()
	_ende()


func _ende() -> void:
	if failures == 0:
		print("SELFTEST OK — Ausrüstungsfenster und Figuren-Vorschau")
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


func _taste(code: Key, gedrueckt: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.keycode = code
	ev.pressed = gedrueckt
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


func _test_vorschau() -> void:
	print("Figuren-Vorschau: ruhig, Drehen nur auf Wunsch:")
	var vorschau := FigurenVorschau.new(Vector2i(150, 170))
	root.add_child(vorschau)
	vorschau.zeige(FigurenBau.starter_held(SpriteLib.HERO_PORTRAITS[0], HeroLibrary.STARTER_LOADOUTS.keys()[0]))
	await _bilder(20)
	_check(is_equal_approx(vorschau.drehung_grad(), PortraitStudio.DREHUNG_GRAD),
		"keine Selbstdrehung: steht nach 20 Bildern in der Grundpose (%.1f°)" % vorschau.drehung_grad())
	_check(vorschau.mouse_filter == Control.MOUSE_FILTER_STOP and not vorschau.tooltip_text.is_empty(),
		"nimmt die Maus an und erklärt sich im Tooltip")

	# Maus: drücken, 40 px nach rechts ziehen, loslassen; danach dreht Bewegung nicht mehr.
	var druck := InputEventMouseButton.new()
	druck.button_index = MOUSE_BUTTON_LEFT
	druck.pressed = true
	vorschau._gui_input(druck)
	var zug := InputEventMouseMotion.new()
	zug.relative = Vector2(40, 0)
	vorschau._gui_input(zug)
	var nach_rechts := vorschau.drehung_grad()
	_check(nach_rechts > PortraitStudio.DREHUNG_GRAD + 10.0, "Ziehen nach rechts dreht (%.1f°)" % nach_rechts)
	zug.relative = Vector2(-80, 0)
	vorschau._gui_input(zug)
	_check(vorschau.drehung_grad() < nach_rechts - 20.0, "Ziehen nach links dreht zurück (%.1f°)" % vorschau.drehung_grad())
	druck.pressed = false
	vorschau._gui_input(druck)
	var losgelassen := vorschau.drehung_grad()
	vorschau._gui_input(zug)
	_check(is_equal_approx(vorschau.drehung_grad(), losgelassen), "ohne gedrückte Taste dreht Mausbewegung nicht")

	# Tastatur: Punkt halten dreht nach rechts, Komma nach links.
	var vorher := vorschau.drehung_grad()
	_taste(FigurenVorschau.TASTE_RECHTS, true)
	await _bilder(10)
	_taste(FigurenVorschau.TASTE_RECHTS, false)
	var mit_punkt := vorschau.drehung_grad()
	_check(mit_punkt > vorher + 1.0, "Punkt gehalten dreht (%.1f° » %.1f°)" % [vorher, mit_punkt])
	_taste(FigurenVorschau.TASTE_LINKS, true)
	await _bilder(10)
	_taste(FigurenVorschau.TASTE_LINKS, false)
	_check(vorschau.drehung_grad() < mit_punkt - 1.0, "Komma gehalten dreht zurück (%.1f°)" % vorschau.drehung_grad())
	await _bilder(5)
	var still := vorschau.drehung_grad()
	await _bilder(5)
	_check(is_equal_approx(vorschau.drehung_grad(), still), "losgelassen bleibt die Figur stehen")

	# Textfeld mit Fokus (Heldenname): Komma tippt, dreht aber nicht.
	var feld := LineEdit.new()
	root.add_child(feld)
	feld.grab_focus()
	await _bilder(1)
	_taste(FigurenVorschau.TASTE_LINKS, true)
	await _bilder(10)
	_taste(FigurenVorschau.TASTE_LINKS, false)
	_check(is_equal_approx(vorschau.drehung_grad(), still), "im Textfeld dreht Komma nicht")
	feld.queue_free()
	vorschau.queue_free()
	await _bilder(2)


## 4 Helden mit langen Namen, alle Tränke, ein paar Materialien.
func _party(gs: Node) -> void:
	gs.party.clear()
	gs.reserve.clear()
	var kits: Array = HeroLibrary.STARTER_LOADOUTS.keys()
	for i in NAMEN.size():
		gs.recruit(NAMEN[i], kits[i % kits.size()])
	for held: Combatant in gs.party:
		held.level = 60
	for def in ConsumableLibrary.all_defs():
		gs.add_consumable(def.id, 99)


func _test_inventar(gs: Node, sprache: String) -> void:
	gs.language = sprache
	print("Inventar (%s): Heldenleiste, Reiter des Helden, Gruppe:" % sprache)
	var szene = load("res://scenes/inventory/inventory_scene.tscn").instantiate()
	root.add_child(szene)
	await _bilder(6)
	var bild := root.get_visible_rect().grow(1.0)

	# Zuordnung: Ausrüstung/Werte in der Helden-Tafel, Tränke/Materialien in der Gruppen-Tafel.
	var held_tafel: Control = szene._held_titel.get_parent().get_parent()
	var ausruestung: Button = szene._tab_buttons[&"ausruestung"]
	var werte: Button = szene._tab_buttons[&"werte"]
	var traenke: Button = szene._tab_buttons[&"traenke"]
	var material: Button = szene._tab_buttons[&"material"]
	_check(held_tafel.is_ancestor_of(ausruestung) and held_tafel.is_ancestor_of(werte),
		"Ausrüstung und Werte stehen in der Tafel des Helden")
	_check(not held_tafel.is_ancestor_of(traenke) and not held_tafel.is_ancestor_of(material)
		and traenke.get_parent() == material.get_parent(), "Tränke und Materialien stehen gemeinsam in der Gruppen-Tafel")
	var gruppe_titel := traenke.get_parent().get_child(0) as Label
	_check(gruppe_titel != null and gruppe_titel.text.begins_with(Loc.pick("Gruppe", "Party")),
		"Gruppen-Tafel ist beschriftet (%s)" % (gruppe_titel.text if gruppe_titel else "-"))
	_check(szene._held_titel.text.begins_with(gs.party[0].display_name), "Helden-Tafel trägt den Namen des gewählten Helden")

	# Hierarchie: Heldenleiste über den Reitern, Reiter eingerückt; nichts ragt aus dem Bild.
	var leiste: Rect2 = szene._char_bar.get_global_rect()
	var reiter: Rect2 = held_tafel.get_global_rect().merge(traenke.get_parent().get_parent().get_global_rect())
	_check(leiste.end.y <= reiter.position.y, "Heldenleiste steht über den Reitern")
	_check(reiter.position.x > leiste.position.x + 8.0, "Reiter sind unter der Heldenleiste eingerückt")
	_check(bild.encloses(reiter), "Reiter-Zeile im Bild (%s)" % reiter)
	var raus := _ausserhalb(szene)
	_check(raus.is_empty(), "Heldenleiste, Reiter, Raster und Knöpfe im Bild %s" % [raus.slice(0, 4)])

	# Heldenwechsel: der Name der Tafel folgt.
	var zweiter: Button = szene._char_bar.get_child(1)
	zweiter.pressed.emit()
	await _bilder(3)
	_check(szene._held_titel.text.begins_with(gs.party[1].display_name), "nach dem Wechsel trägt die Tafel den neuen Namen")

	# WASD: S von einem Helden-Knopf landet auf einem Reiter, W von dort wieder in der Heldenleiste.
	var start: Button = szene._char_bar.get_child(0)
	start.grab_focus()
	await _bilder(1)
	var unten := start.find_valid_focus_neighbor(SIDE_BOTTOM)
	_check(unten != null and szene._tab_buttons.values().has(unten),
		"S von der Heldenleiste » Reiter (%s)" % [(unten as Button).text if unten is Button else unten])
	if unten != null:
		var oben := unten.find_valid_focus_neighbor(SIDE_TOP)
		_check(oben != null and szene._char_bar.is_ancestor_of(oben), "W vom Reiter » Heldenleiste")
	# Vom Inhalt (Filter-Knopf mitten im Bild) mit W auf einen Reiter, nicht über ihn hinweg.
	var filter: Button = szene._filter_knoepfe[Enums.EquipSlot.HELMET]
	var ueber := filter.find_valid_focus_neighbor(SIDE_TOP)
	_check(ueber != null and szene._tab_buttons.values().has(ueber),
		"W vom Inhalt » Reiter (%s)" % [(ueber as Button).text if ueber is Button else ueber])
	szene.queue_free()
	await _bilder(2)


## Bedienbare Elemente und Texte außerhalb des Bildes (Elemente in einer
## Scroll-Liste zählen, wenn die Liste selbst im Bild liegt).
func _ausserhalb(wurzel: Node) -> Array[String]:
	var bild := root.get_visible_rect().grow(1.0)
	var fehler: Array[String] = []
	for knoten in wurzel.find_children("*", "Control", true, false):
		var c := knoten as Control
		if not (c is BaseButton or c is Label) or not c.is_visible_in_tree():
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
