extends SceneTree
## Headless-Selbsttest für Paket „Bedienung und Inventar“: Taschenlimit mit
## Warteliste (auch speichern/laden), „Gewöhnliche verkaufen“, das Taschen-
## voll-Fenster, Inventar per Tastatur (Fokus, E wählt/legt an, Auswahl ohne
## Neuaufbau, Seiten), zweiter Klick beim Verkaufen und Karten-Löschen, das
## Notiz-Fenster (Strg+Enter), die Belohnungs-Knöpfe und die gekürzte
## Knopfliste der KI-Brücke.
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/inventar_selftest.gd
##
## Szenen greifen auf Autoloads zu: sie werden erst nach dem ersten Bild per
## load() geladen. Speichern ist gesperrt (GameState.slot_gesperrt), der
## Datei-Rundweg nutzt einen eigenen Testpfad.

const TEST_PFAD := "user://selftest_inventar.json"

var failures := 0


func _initialize() -> void:
	await process_frame
	var waechter := FehlerWaechter.anmelden()
	_test_limit_und_warteliste()
	_test_warteliste_speichern()
	_test_gewoehnliche()
	var gs: Node = root.get_node_or_null(^"GameState")
	_check(gs != null, "GameState-Autoload vorhanden")
	if gs != null:
		# Nie den echten Spielstand schreiben: Speichern sperren, Wegwerf-Slot.
		gs.slot_gesperrt = true
		SaveManager.active_slot = 98
		await _test_taschen_fenster(gs)
		await _test_inventar_szene(gs)
		await _test_gast_helden_gesperrt(gs)
		await _test_wunschkarte_lager_voll(gs)
		await _test_fokus_nach_kauf(gs)
		await _test_kartenlager(gs)
		_test_belohnungs_knoepfe()
		await _test_ki_knopfliste()
		_test_ki_nur_quelltext(gs)
	failures += waechter.fehler_melden()
	if failures == 0:
		print("SELFTEST OK — alle Inventar-/Bedienungs-Tests bestanden")
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


func _item(rarity: Enums.Rarity, seed_wert: int) -> ItemInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_wert
	return LootGenerator.roll_item_with_rarity(5, rarity, rng)


func _fuellen(state: Node, anzahl: int, rarity := Enums.Rarity.MAGIC) -> void:
	var liste: Array[ItemInstance] = []
	for i in anzahl:
		liste.append(_item(rarity, 1000 + i))
	state.inventory = liste


# --- Reine Logik (eigene GameState-Instanz) --------------------------------------

func _test_limit_und_warteliste() -> void:
	print("Taschenlimit und Warteliste:")
	var state: Node = load("res://autoload/game_state.gd").new()
	var limit: int = state.TASCHEN_LIMIT
	_check(limit == 300, "Limit ist 300 Teile")
	_fuellen(state, limit - 1)
	_check(state.item_aufnehmen(_item(Enums.Rarity.RARE, 1)), "letzter freier Platz nimmt auf")
	_check(state.inventory.size() == limit and state.taschen_frei() == 0, "Taschen jetzt voll")
	var a := _item(Enums.Rarity.EPIC, 2)
	var b := _item(Enums.Rarity.RARE, 3)
	_check(not state.item_aufnehmen(a) and not state.item_aufnehmen(b), "volle Taschen: neue Beute wartet")
	_check(state.inventory.size() == limit and state.beute_warteliste.size() == 2, "Warteliste hält beide")
	# Angelegte Ausrüstung zählt nicht: ein angelegtes Teil macht Platz.
	state.inventory.pop_back()
	_check(state.warteliste_nachruecken() == 1 and state.inventory.has(a), "ein Platz frei: der erste Wartende rückt nach")
	_check(state.beute_warteliste.size() == 1 and state.beute_warteliste[0] == b, "Reihenfolge der Warteliste bleibt")
	# Neues stellt sich hinten an, auch wenn gerade Platz frei wird.
	state.inventory.pop_back()
	var c := _item(Enums.Rarity.MAGIC, 4)
	_check(not state.item_aufnehmen(c) and state.inventory.has(b), "Platz geht zuerst an den Wartenden")
	_check(state.beute_warteliste.size() == 1 and state.beute_warteliste[0] == c, "das neue Teil wartet hinten")
	_check(state.warteliste_verwerfen() == 1 and state.beute_warteliste.is_empty(), "Liegen lassen: Warteliste leer")
	# Alte Stände über dem Limit behalten alles, nehmen aber nichts Neues.
	_fuellen(state, limit + 10)
	_check(not state.item_aufnehmen(_item(Enums.Rarity.MAGIC, 5)), "über dem Limit: keine neue Beute")
	_check(state.inventory.size() == limit + 10, "über dem Limit: nichts geht verloren")
	_check(state.warteliste_nachruecken() == 0, "über dem Limit: nichts rückt nach")
	state.reset_to_new_game()
	_check(state.beute_warteliste.is_empty() and state.inventory.is_empty(), "Neues Spiel leert Taschen und Warteliste")
	state.free()


func _test_warteliste_speichern() -> void:
	print("Warteliste übersteht Speichern/Laden (eigener Testpfad):")
	var state: Node = load("res://autoload/game_state.gd").new()
	_fuellen(state, state.TASCHEN_LIMIT)
	var wartend := _item(Enums.Rarity.LEGENDARY, 7)
	state.item_aufnehmen(wartend)
	var daten: Dictionary = state.to_save_dict()
	_check((daten["beute_warteliste"] as Array).size() == 1, "Warteliste steht im Spielstand")
	var neu: Node = load("res://autoload/game_state.gd").new()
	neu.apply_save_dict(JSON.parse_string(JSON.stringify(daten)))
	_check(neu.beute_warteliste.size() == 1 and neu.inventory.size() == state.TASCHEN_LIMIT,
		"Rundweg (JSON): Taschen und Warteliste")
	_check(neu.beute_warteliste[0].get_display_name() == wartend.get_display_name()
		and neu.beute_warteliste[0].rarity == wartend.rarity, "wartender Gegenstand unverändert")
	# Echte Datei-I/O auf dem Testpfad.
	SaveManager.delete_save(TEST_PFAD)
	_check(state.save_game(TEST_PFAD), "Speichern auf den Testpfad")
	var geladen: Node = load("res://autoload/game_state.gd").new()
	_check(geladen.load_game(TEST_PFAD) and geladen.beute_warteliste.size() == 1, "Laden vom Testpfad: Warteliste da")
	SaveManager.delete_save(TEST_PFAD)
	# Alte Spielstände ohne Feld: leere Warteliste.
	daten.erase("beute_warteliste")
	geladen.apply_save_dict(daten)
	_check(geladen.beute_warteliste.is_empty(), "alter Spielstand ohne Warteliste lädt leer")
	state.free()
	neu.free()
	geladen.free()


func _test_gewoehnliche() -> void:
	print("Gewöhnliche verkaufen:")
	var state: Node = load("res://autoload/game_state.gd").new()
	var liste: Array[ItemInstance] = []
	var erwartet := 0
	for i in 5:
		var grau := _item(Enums.Rarity.COMMON, 100 + i)
		erwartet += LootGenerator.sell_price(grau)
		liste.append(grau)
	liste.append(_item(Enums.Rarity.EPIC, 200))
	state.inventory = liste
	state.gold = 10
	var wert: Dictionary = state.gewoehnliche_wert()
	_check(int(wert["anzahl"]) == 5 and int(wert["gold"]) == erwartet, "Vorschau: Anzahl und Goldsumme")
	_check(state.inventory.size() == 6, "Vorschau verkauft nichts")
	var ergebnis: Dictionary = state.gewoehnliche_verkaufen()
	_check(int(ergebnis["anzahl"]) == 5 and state.gold == 10 + erwartet, "Verkauf: Gold gutgeschrieben")
	_check(state.inventory.size() == 1 and state.inventory[0].rarity == Enums.Rarity.EPIC, "nur Gewöhnliche verkauft")
	state.free()


# --- Szenen (mit Autoloads) -----------------------------------------------------

func _knopf_mit(wurzel: Node, anfang: Array) -> Button:
	for knoten in wurzel.find_children("*", "Button", true, false):
		var knopf := knoten as Button
		if knopf.is_queued_for_deletion() or not knopf.is_visible_in_tree():
			continue
		for text in anfang:
			if knopf.text.begins_with(text):
				return knopf
	return null


func _test_taschen_fenster(gs: Node) -> void:
	print("Taschen-voll-Fenster:")
	var taschen_voll = load("res://scripts/ui/taschen_voll.gd")  # untypisiert: nutzt Autoloads
	_fuellen(gs, gs.TASCHEN_LIMIT - 3)
	for i in 3:
		gs.inventory.append(_item(Enums.Rarity.COMMON, 300 + i))
	var wartend: Array[ItemInstance] = []
	for i in 4:
		var item := _item(Enums.Rarity.RARE, 400 + i)
		wartend.append(item)
		gs.item_aufnehmen(item)
	_check(gs.beute_warteliste.size() == 4, "vier Gegenstände warten")
	var buehne := Control.new()
	root.add_child(buehne)
	var aufgeraeumt := [false]
	var fenster: CanvasLayer = taschen_voll.pruefen(buehne, func() -> void: aufgeraeumt[0] = true)
	await _bilder(2)
	_check(fenster != null, "Fenster erscheint, wenn Beute wartet")
	var texte := ""
	for label in fenster.find_children("*", "Label", true, false):
		texte += (label as Label).text + "\n"
	_check(texte.contains("%d/%d" % [gs.TASCHEN_LIMIT, gs.TASCHEN_LIMIT]), "zeigt den Taschen-Stand N/300")
	_check(texte.contains(wartend[0].get_display_name()) and texte.contains("Lv %d" % wartend[0].item_level),
		"zeigt Name und Stufe der wartenden Gegenstände")
	var fokus := root.get_viewport().gui_get_focus_owner()
	_check(fokus != null and fenster.is_ancestor_of(fokus), "Fokus liegt im Fenster")
	var verkaufen := _knopf_mit(fenster, ["Gewöhnliche verkaufen (3 Teile", "Sell commons (3 items"])
	_check(verkaufen != null, "Knopf nennt die Anzahl der Gewöhnlichen")
	if verkaufen != null:
		verkaufen.pressed.emit()
		_check(gs.beute_warteliste.size() == 4 and int(gs.gewoehnliche_wert()["anzahl"]) == 3
			and verkaufen.text.begins_with(Loc.pick("Wirklich", "Really")), "Verkaufen: erster Klick fragt nur nach")
		verkaufen.pressed.emit()
		await _bilder(2)
		_check(gs.beute_warteliste.size() == 1 and gs.inventory.size() == gs.TASCHEN_LIMIT,
			"nach dem Verkauf rücken 3 Wartende nach, einer wartet weiter")
	_check(taschen_voll.pruefen(buehne, Callable()) == fenster, "zweiter Aufruf befüllt dasselbe Fenster neu")
	var aufraeumen := _knopf_mit(fenster, ["Inventar aufräumen", "Tidy up inventory"])
	_check(aufraeumen != null, "Knopf „Inventar aufräumen“")
	if aufraeumen != null:
		aufraeumen.pressed.emit()
		await _bilder(2)
		_check(aufgeraeumt[0] and gs.beute_warteliste.size() == 1, "Aufräumen: Inventar öffnen, Warteliste bleibt")
	fenster = taschen_voll.pruefen(buehne, Callable())
	await _bilder(2)
	var liegen := _knopf_mit(fenster, ["Liegen lassen", "Leave behind"])
	var liegen_da := liegen != null  # nach dem Schließen ist der Knopf freigegeben
	if liegen_da:
		liegen.pressed.emit()
		_check(gs.beute_warteliste.size() == 1 and liegen.text.begins_with(Loc.pick("Wirklich", "Really")),
			"Liegen lassen: erster Klick fragt nur nach")
		liegen.pressed.emit()
		await _bilder(2)
	_check(liegen_da and gs.beute_warteliste.is_empty(), "Liegen lassen: die Wartenden verfallen")
	_check(taschen_voll.pruefen(buehne, Callable()) == null, "ohne Warteliste kein Fenster")
	# Platz frei geworden (z. B. im Inventar angelegt): erst nachrücken —
	# passt alles, kommt kein Fenster.
	var spaeter := _item(Enums.Rarity.RARE, 450)
	gs.item_aufnehmen(spaeter)
	gs.inventory.pop_back()
	_check(taschen_voll.pruefen(buehne, Callable()) == null and gs.inventory.has(spaeter)
		and gs.beute_warteliste.is_empty(), "Platz frei: Wartendes rückt nach, kein Fenster")
	# Offenes Fenster, dann passt alles: es wird neu befüllt statt verloren.
	gs.item_aufnehmen(_item(Enums.Rarity.RARE, 451))
	fenster = taschen_voll.pruefen(buehne, Callable())
	await _bilder(1)
	gs.inventory.pop_back()
	_check(taschen_voll.pruefen(buehne, Callable()) == fenster and gs.beute_warteliste.is_empty(),
		"offenes Fenster bleibt erreichbar, auch wenn nichts mehr wartet")
	await _bilder(2)
	var ok_knopf := _knopf_mit(fenster, ["OK"])
	_check(ok_knopf != null, "dann nur noch „OK“")
	if ok_knopf != null:
		ok_knopf.pressed.emit()
	buehne.queue_free()
	await _bilder(2)


func _test_inventar_szene(gs: Node) -> void:
	print("Inventar: Tastatur, Auswahl ohne Neuaufbau, Seiten, Rückfragen:")
	gs.party = TestContent.make_party()
	gs.beute_warteliste.clear()
	gs.current_run = {}
	gs.ui_return_scene = ""
	var liste: Array[ItemInstance] = []
	for i in 130:
		liste.append(_item(Enums.Rarity.MAGIC, 500 + i))
	var episch := _item(Enums.Rarity.EPIC, 900)
	liste.append(episch)
	var grau_summe := 0
	for i in 4:
		var grau := _item(Enums.Rarity.COMMON, 950 + i)
		grau_summe += LootGenerator.sell_price(grau)
		liste.append(grau)
	gs.inventory = liste
	gs.gold = 100
	var szene = load("res://scenes/inventory/inventory_scene.tscn").instantiate()
	root.add_child(szene)
	await _bilder(3)
	var kacheln: Dictionary = szene._bag_kacheln
	_check(kacheln.size() == szene.SEITE_GROESSE, "Seite 1 zeigt %d Kacheln (von 135)" % szene.SEITE_GROESSE)
	_check(szene._seiten_zeile.visible and szene._seite_label.text.contains("1/3"), "Seitenzeile: Seite 1/3")
	# Filterzahlen stimmen mit der Zählung von Hand.
	var waffen := 0
	for item in gs.inventory:
		if szene._passt(item, Enums.EquipSlot.WEAPON):
			waffen += 1
	var waffen_knopf: Button = szene._filter_knoepfe[Enums.EquipSlot.WEAPON]
	_check(waffen_knopf.text.ends_with("(%d)" % waffen), "Filterzahl Waffen in einem Durchlauf")

	# Zwei magische Kacheln (die epische steht vorn und wird später verkauft).
	var magische: Array[ItemInstance] = []
	for i in range(1, szene._raster.get_child_count()):
		for item in kacheln:
			if kacheln[item] == szene._raster.get_child(i) and item.rarity == Enums.Rarity.MAGIC:
				magische.append(item)
		if magische.size() >= 2:
			break
	var item_a: ItemInstance = magische[0]
	var erste: PanelContainer = kacheln[item_a]
	var zweite: PanelContainer = kacheln[magische[1]]
	_check(erste.focus_mode == Control.FOCUS_ALL, "Kacheln sind fokussierbar")
	szene._tastatur = true
	erste.grab_focus()
	await _bilder(1)
	var rahmen_sichtbar := false
	for panel in erste.find_children("*", "Panel", true, false):
		rahmen_sichtbar = rahmen_sichtbar or (panel as Panel).visible
	_check(rahmen_sichtbar, "Fokusrahmen sichtbar")
	_check(szene._popup != null and szene._popup_anker == erste, "Werte-Karte steht an der fokussierten Kachel")
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	erste.gui_input.emit(accept)
	await _bilder(1)
	_check(szene._auswahl == item_a, "E wählt aus")
	_check(szene._bag_kacheln.get(item_a) == erste and is_instance_valid(zweite) and zweite.get_parent() == szene._raster,
		"Auswahl ohne Neuaufbau: Kacheln bleiben dieselben")
	erste.gui_input.emit(accept)
	await _bilder(2)
	_check(item_a in szene._selected.equipment.values() and not gs.inventory.has(item_a), "zweites E legt an")
	var fokus := root.get_viewport().gui_get_focus_owner()
	_check(fokus != null and fokus.get_parent() == szene._raster, "Fokus rückt auf die nächste Taschen-Kachel")
	_check(is_instance_valid(zweite) and zweite.get_parent() == szene._raster, "andere Kacheln wiederverwendet")

	# Maus: Auswahl beim Loslassen, ebenfalls ohne Neuaufbau.
	var los := InputEventMouseButton.new()
	los.button_index = MOUSE_BUTTON_LEFT
	los.pressed = false
	zweite.gui_input.emit(los)
	await _bilder(1)
	_check(szene._auswahl == magische[1] and szene._bag_kacheln.get(magische[1]) == zweite,
		"Mausklick wählt aus, Kachel bleibt")
	# Messung (nur Ausgabe): Auswahl und Raster-Neuaufbau.
	var t0 := Time.get_ticks_usec()
	szene._auswahl_setzen(magische[0] if gs.inventory.has(magische[0]) else magische[1], false)
	var t1 := Time.get_ticks_usec()
	szene._raster_aufbauen()
	var t2 := Time.get_ticks_usec()
	print("  Messung: Auswahl %.1f ms, Raster-Auffrischung %.1f ms (%d Teile)" % [
		(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, gs.inventory.size()])

	# Seiten blättern.
	szene._seite_weiter.pressed.emit()
	await _bilder(1)
	_check(szene._seite == 1 and szene._seite_label.text.contains("2/3"), "Seite vor: 2/3")
	szene._seite_zurueck.pressed.emit()
	await _bilder(1)

	# Episch: erst der zweite Klick verkauft.
	szene._auswahl_setzen(episch, false)
	await _bilder(1)
	var verkaufen := _knopf_mit(szene._aktion_zeile, ["Verkaufen", "Sell ("])
	var gold_vorher: int = gs.gold
	if verkaufen != null:
		verkaufen.pressed.emit()
	_check(verkaufen != null and gs.inventory.has(episch) and verkaufen.text.begins_with(Loc.pick("Wirklich", "Really")),
		"Episch: erster Klick fragt nach")
	if verkaufen != null:
		verkaufen.pressed.emit()
		await _bilder(1)
	_check(not gs.inventory.has(episch) and gs.gold == gold_vorher + LootGenerator.sell_price(episch),
		"Episch: zweiter Klick verkauft")
	# Magisch: ein Klick reicht.
	var magisch: ItemInstance = null
	for item in szene._bag_kacheln:
		if item.rarity == Enums.Rarity.MAGIC:
			magisch = item
			break
	szene._auswahl_setzen(magisch, false)
	await _bilder(1)
	verkaufen = _knopf_mit(szene._aktion_zeile, ["Verkaufen", "Sell ("])
	if verkaufen != null:
		verkaufen.pressed.emit()
		await _bilder(1)
	_check(not gs.inventory.has(magisch), "Magisch: verkauft ohne Rückfrage")
	# Gewöhnliche: Knopf mit Anzahl und Summe, zweiter Klick. (Beim Anlegen
	# kam das gewöhnliche Startteil des Helden in die Taschen.)
	var wert: Dictionary = gs.gewoehnliche_wert()
	var grau_anzahl := int(wert["anzahl"])
	grau_summe = int(wert["gold"])
	var commons := _knopf_mit(szene._aktion_zeile, ["Gewöhnliche verkaufen", "Sell commons"])
	_check(grau_anzahl >= 4 and commons != null and commons.text.contains("(%d " % grau_anzahl)
		and commons.text.contains("+%d " % grau_summe),
		"„Gewöhnliche verkaufen“ nennt Anzahl und Goldsumme")
	gold_vorher = gs.gold
	if commons != null:
		commons.pressed.emit()
		_check(int(gs.gewoehnliche_wert()["anzahl"]) == grau_anzahl, "Gewöhnliche: erster Klick fragt nach")
		commons.pressed.emit()
		await _bilder(1)
	_check(int(gs.gewoehnliche_wert()["anzahl"]) == 0 and gs.gold == gold_vorher + grau_summe,
		"Gewöhnliche: zweiter Klick verkauft alle")
	_check(String(szene._meldung).contains("+%d" % grau_summe), "Rückmeldung nennt die Goldsumme")
	# Platz frei (etwa in einen leeren Slot angelegt): beim Auffrischen rückt
	# Wartendes nach und steht in Kopfzeile und Raster.
	var wartet := _item(Enums.Rarity.RARE, 990)
	gs.beute_warteliste.append(wartet)
	szene._auswahl = null
	szene._refresh()
	await _bilder(1)
	_check(gs.inventory.has(wartet) and gs.beute_warteliste.is_empty()
		and String(szene._meldung).contains("1"), "Auffrischen nimmt Wartendes auf")
	_check(szene._taschen_label.text.contains("%d/%d" % [gs.inventory.size(), gs.TASCHEN_LIMIT])
		and not szene._taschen_label.text.contains(Loc.pick("wartend", "waiting")), "Kopfzeile ohne Wartende")
	await _test_werte_planung(szene, gs)
	szene.queue_free()
	await _bilder(2)


## Spieltest 11, Funde 1 und 2: Hinweis nur einmal; jede Änderung der Planung
## macht den nächsten Wechsel (Held, Reiter, Zurück) wieder zur Rückfrage.
func _test_werte_planung(szene: Node, gs: Node) -> void:
	print("Werte-Seite: geplante Punkte und Wechsel:")
	var held: Combatant = gs.party[0]
	held.stat_points = 5
	szene._selected = held
	szene._tab = &"werte"
	szene._refresh()
	await _bilder(1)
	var alloc = szene._alloc  # untypisiert: StatAllocator braucht Autoloads
	var hinweis := Loc.pick("gehen verloren", "are lost")
	alloc._nudge(&"strength", 1)
	_check(not szene._wechsel_erlaubt(gs.party[1]), "1. Wechsel mit Planung: Rückfrage")
	_check(not szene._wechsel_erlaubt(gs.party[2]), "anderer Held: wieder Rückfrage")
	_check(not szene._wechsel_erlaubt(gs.party[1]), "und zurück: Rückfrage")
	_check(alloc._points_label.text.count(hinweis) == 1, "Hinweis steht genau einmal da")
	alloc._nudge(&"strength", 1)
	_check(alloc._points_label.text.count(hinweis) == 0, "Änderung der Planung nimmt den Hinweis weg")
	_check(not szene._wechsel_erlaubt(gs.party[1]), "nach der Änderung fragt derselbe Wechsel neu")
	_check(szene._wechsel_erlaubt(gs.party[1]), "zweiter gleicher Wechsel führt aus")
	_check(not szene._wechsel_erlaubt(&"ausruestung"), "Reiterwechsel mit Planung: Rückfrage")
	_check(not szene._wechsel_erlaubt(&"zurueck"), "Zurück mit Planung: Rückfrage")
	_check(szene._wechsel_erlaubt(&"zurueck"), "zweites Zurück führt aus")
	alloc._pending.clear()
	_check(szene._wechsel_erlaubt(&"ausruestung"), "ohne Planung: sofort")
	szene._tab = &"ausruestung"
	held.stat_points = 0


## Co-op: Gast-Helden (Meta guest_peer) sind Kopien beim Host — Inventar und
## Werkstatt bieten sie nicht an (sonst Item-Duplikat / Verlust beim Trennen).
func _test_gast_helden_gesperrt(gs: Node) -> void:
	print("Co-op: Gast-Helden im Inventar und in der Werkstatt gesperrt:")
	gs.party = TestContent.make_party()
	var gast: Combatant = gs.party.back()
	gast.set_meta(&"guest_peer", 1)
	# Auch an erster Stelle darf der Gast nie gewählt sein.
	gs.party.erase(gast)
	gs.party.push_front(gast)
	_check(not gs.eigene_helden().has(gast) and gs.eigene_helden().size() == gs.party.size() - 1,
		"eigene_helden ohne Gast")
	for pfad in ["res://scenes/inventory/inventory_scene.tscn", "res://scenes/workshop/skill_workshop.tscn"]:
		var szene: Node = load(pfad).instantiate()
		root.add_child(szene)
		await _bilder(3)
		var namen: Array[String] = []
		for knopf in szene._char_bar.get_children():
			if knopf is Button:
				namen.append((knopf as Button).text)
		var gast_da := namen.any(func(t: String) -> bool: return t.begins_with(gast.display_name + " "))
		_check(szene._selected != gast and not gast_da,
			"%s: Gast-Held weder gewählt noch in der Heldenleiste %s" % [pfad.get_file(), namen])
		if "_geaendert" in szene:
			szene._geaendert = false
		szene.queue_free()
		await _bilder(2)
	gast.remove_meta(&"guest_peer")


## Händler: Medaillen-Tausch „Wunsch-Karte“ bei vollem Kartenlager ist
## gesperrt — keine Medaillen weg, keine verfallene Karte.
func _test_wunschkarte_lager_voll(gs: Node) -> void:
	print("Händler: Wunsch-Karte bei vollem Kartenlager:")
	gs.party = TestContent.make_party()
	var karten_vorher: Array = gs.cards.duplicate()
	gs.cards.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	while gs.cards.size() < gs.card_capacity:
		gs.cards.append(CardFactory.make_card(1, rng))
	var medaillen_vorher: int = gs.medals
	gs.medals = 9
	var shop: Node = load("res://scenes/hub/shop_scene.tscn").instantiate()
	root.add_child(shop)
	await _bilder(3)
	var knopf: Button = null
	for b in shop.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(Loc.pick("5 Medaillen", "5 medals")):
			knopf = b
	_check(knopf != null and knopf.disabled, "Wunsch-Karte gesperrt, solange das Lager voll ist (%s)" % [knopf.text if knopf else "-"])
	if knopf != null:
		knopf.pressed.emit()  # auch erzwungen: nichts passiert
	_check(gs.medals == 9 and gs.cards.size() == gs.card_capacity, "keine Medaillen abgezogen")
	shop.queue_free()
	await _bilder(2)
	gs.medals = medaillen_vorher
	gs.cards.clear()
	gs.cards.append_array(karten_vorher)


## Händler: dreimal E auf „Kaufen“ kauft dreimal — der Fokus bleibt nach dem
## Neuaufbau der Liste auf dem Kauf-Knopf (vorher sprang er auf einen Reiter).
func _test_fokus_nach_kauf(gs: Node) -> void:
	print("Händler: Fokus bleibt nach dem Kauf:")
	gs.party = TestContent.make_party()
	var gold_vorher: int = gs.gold
	gs.gold = 100000
	var shop: Node = load("res://scenes/hub/shop_scene.tscn").instantiate()
	root.add_child(shop)
	await _bilder(3)
	var kaufen: Button = null
	for b in shop.find_children("*", "Button", true, false):
		var knopf := b as Button
		if knopf.is_visible_in_tree() and not knopf.disabled \
				and knopf.text.begins_with(Loc.pick("Kaufen (", "Buy (")):
			kaufen = knopf
			break
	_check(kaufen != null, "Kauf-Knopf gefunden")
	if kaufen != null:
		var text := kaufen.text
		kaufen.grab_focus()
		await _bilder(1)
		var gold_start: int = gs.gold
		for i in 3:
			var fokus := shop.get_viewport().gui_get_focus_owner() as Button
			if fokus == null:
				break
			fokus.pressed.emit()
			await _bilder(2)
		var jetzt := shop.get_viewport().gui_get_focus_owner() as Button
		_check(jetzt != null and jetzt.text == text, "Fokus wieder auf „%s“ (%s)" % [text, jetzt.text if jetzt else "-"])
		_check(gold_start - gs.gold > 0 and (gold_start - gs.gold) % 3 == 0,
			"dreimal E = dreimal gekauft (%d Gold)" % (gold_start - gs.gold))
	shop.queue_free()
	await _bilder(2)
	gs.gold = gold_vorher


func _test_kartenlager(gs: Node) -> void:
	print("Kartenlager: Löschen mit Rückfrage, Notiz per Tastatur:")
	var karte_a := CardFactory.make_starter_card()
	var karte_b := CardFactory.make_starter_card()
	var karten: Array[DungeonCard] = [karte_a, karte_b]
	gs.cards = karten
	gs.card_archive.clear()
	gs.current_run = {}
	var szene = load("res://scenes/hub/card_storage.tscn").instantiate()
	root.add_child(szene)
	await _bilder(2)
	var zeile: Control = szene._card_list.get_child(0)
	var loeschen := _knopf_mit(zeile, ["Löschen", "Delete"])
	_check(loeschen != null, "Löschen-Knopf da")
	if loeschen != null:
		loeschen.pressed.emit()
		_check(gs.cards.size() == 2 and loeschen.text == Loc.pick("Wirklich löschen?", "Really delete?"),
			"erster Klick fragt nur nach")
		loeschen.pressed.emit()
		await _bilder(2)
		_check(gs.cards.size() == 1, "zweiter Klick löscht")
	# Notiz-Fenster: Fokus gesperrt, Strg+Enter speichert.
	var karte: DungeonCard = gs.cards[0]
	szene._notiz_bearbeiten(karte)
	await _bilder(2)
	var feld: TextEdit = szene.find_children("*", "TextEdit", true, false)[0]
	var zeilen_knopf := _knopf_mit(szene._card_list, ["Betreten", "Enter"])
	_check(zeilen_knopf != null and zeilen_knopf.focus_mode == Control.FOCUS_NONE, "Fokus im Notiz-Fenster gesperrt")
	feld.text = "Runen-Farm"
	var taste := InputEventKey.new()
	taste.keycode = KEY_ENTER
	taste.ctrl_pressed = true
	taste.pressed = true
	feld.gui_input.emit(taste)
	await _bilder(2)
	_check(karte.notiz == "Runen-Farm", "Strg+Enter speichert die Notiz")
	zeilen_knopf = _knopf_mit(szene._card_list, ["Betreten", "Enter"])
	_check(zeilen_knopf != null and zeilen_knopf.focus_mode != Control.FOCUS_NONE, "Sperre nach dem Speichern frei")
	_check(szene.find_children("*", "TextEdit", true, false).is_empty(), "Notiz-Fenster geschlossen")
	szene.queue_free()
	await _bilder(2)


func _test_belohnungs_knoepfe() -> void:
	print("Belohnungskarte: alles auf dem Knopf:")
	var karte := CardFactory.make_starter_card()
	karte.card_rarity = Enums.Rarity.EPIC
	karte.legendary = true
	karte.card_affix_ids = [&"gefaehrlich"]
	var zeilen: Array[String] = load("res://scripts/ui/battle_scene.gd")._belohnung_zeilen(karte)
	var text := "\n".join(zeilen)
	_check(text.contains("[%s]" % LootGenerator.rarity_name(Enums.Rarity.EPIC)), "Seltenheit im Kopf")
	_check(text.contains("[LEGACY]") and text.contains("Lv %d" % CardFactory.legacy_boss_level(karte)), "Legacy und Boss-Lv")
	_check(text.contains(CardFactory.card_affix_desc(&"gefaehrlich")), "Affix mit Wirkung")
	var battle_skript = load("res://scripts/ui/battle_scene.gd")
	_check(battle_skript.lager_text(12, 25).ends_with("12/25"), "Kartenlager: nur die Zahl")
	_check(battle_skript.lager_text(25, 25) == Loc.pick("Kartenlager: 25/25 (voll)", "Map storage: 25/25 (full)"),
		"volles Lager sachlich vermerkt, ohne Warnung")
	# Zurück-Knopf im Inventar nennt das echte Ziel (Taschen-voll-Fenster in der Stadt).
	var inventar_skript = load("res://scripts/ui/inventory_scene.gd")
	_check(inventar_skript.ziel_name("res://scenes/hub/shop_scene.tscn") == Loc.pick("Händler", "Merchant")
		and inventar_skript.ziel_name("res://scenes/hub/smith.tscn") == Loc.pick("Schmiede", "Smithy")
		and inventar_skript.ziel_name("res://scenes/dungeon/dungeon_scene.tscn") == "Dungeon"
		and inventar_skript.ziel_name("") == Loc.pick("Stadt", "Town"), "Zurück-Ziel des Inventars (ohne Ziel: die Stadt)")


func _test_ki_knopfliste() -> void:
	print("KI-Brücke: Knopfliste begrenzt, Taschen-Kacheln zusammengefasst:")
	# Kein Autoload mehr: das Skript direkt laden (ohne --ki bleibt es still).
	var ki_skript: Script = load("res://autoload/ki_bruecke.gd")
	_check(ki_skript != null, "KI-Brücken-Skript ladbar")
	if ki_skript == null:
		return
	var ki: Node = ki_skript.new()
	root.add_child(ki)
	_check(not ki.aktiv, "ohne --ki bleibt die Brücke aus")
	var test := Control.new()
	root.add_child(test)
	for i in 80:
		var kachel := Control.new()
		kachel.set_meta(&"ki_text", "Tasche %d" % i)
		kachel.set_meta(&"ki_klick", func() -> void: pass)
		kachel.set_meta(&"ki_gruppe", "tasche")
		test.add_child(kachel)
	for i in 200:
		var knopf := Button.new()
		knopf.text = "Knopf %d" % i
		test.add_child(knopf)
	await _bilder(1)
	var liste: Array = ki._knoepfe_listen(null)
	var nummeriert := 0
	var taschen := 0
	var hinweise: Array[String] = []
	for eintrag in liste:
		if int(eintrag["nr"]) > 0:
			nummeriert += 1
			if String(eintrag["text"]).begins_with("Tasche"):
				taschen += 1
		else:
			hinweise.append(String(eintrag["text"]))
	_check(nummeriert == ki.KNOEPFE_MAX, "höchstens %d nummerierte Knöpfe" % ki.KNOEPFE_MAX)
	_check(taschen == ki.GRUPPE_MAX, "höchstens %d Taschen-Kacheln einzeln" % ki.GRUPPE_MAX)
	var ok_nummern := true
	for i in nummeriert:
		ok_nummern = ok_nummern and int(liste[i]["nr"]) == i + 1
	_check(ok_nummern, "Nummern bleiben durchgehend")
	_check(hinweise.size() == 2 and hinweise[0].begins_with("+20 ") and hinweise[1].begins_with("+%d " % (280 - 20 - ki.KNOEPFE_MAX)),
		"Rest als „+N weitere“ am Ende")
	test.queue_free()
	ki.queue_free()
	await _bilder(1)


## Release ohne KI (Lutz): kein Autoload, Skript im Export ausgeschlossen,
## eingehängt nur im Editor-Build mit Startschalter --ki.
func _test_ki_nur_quelltext(gs: Node) -> void:
	print("KI-Brücke: nur aus dem Quelltext mit --ki:")
	_check(not ProjectSettings.has_setting("autoload/KiBruecke"), "KiBruecke ist kein Autoload")
	_check(root.get_node_or_null(^"KiBruecke") == null, "ohne --ki kein /root/KiBruecke")
	var gs_skript: Script = gs.get_script()
	_check(gs_skript.ki_bruecke_gewuenscht(PackedStringArray(["--ki"]), true), "Editor-Build + --ki: Brücke an")
	_check(not gs_skript.ki_bruecke_gewuenscht(PackedStringArray(["--ki"]), false), "Release-Build + --ki: Brücke aus")
	_check(not gs_skript.ki_bruecke_gewuenscht(PackedStringArray(["--ki-echtzeit"]), true), "nur --ki zählt als Schalter")
	_check(not gs_skript.ki_bruecke_gewuenscht(PackedStringArray(), true), "ohne Schalter: Brücke aus")
	var presets := ConfigFile.new()
	_check(presets.load("res://export_presets.cfg") == OK, "Export-Presets lesbar")
	var filter := String(presets.get_value("preset.0", "exclude_filter", ""))
	_check("autoload/ki_bruecke.gd" in filter and "scripts/dev/*" in filter,
		"Export schließt KI-Brücke und Dev-Werkzeuge aus")
