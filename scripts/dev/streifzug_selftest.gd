extends SceneTree
## Headless-Selbsttest Kartenlager „nie aussperren“: die feste Streifzug-Zeile
## (würfelt beim Betreten eine Karte auf dem Party-Durchschnitt, wird nie
## gespeichert, belegt keinen Lagerplatz) und „Alle löschen“ (Favoriten und
## Archiv bleiben, zweiter Klick löscht).
##   godot\Godot_v4.7-stable_win64_console.exe --headless --path . -s scripts/dev/streifzug_selftest.gd
##
## Speichern ist gesperrt (GameState.slot_gesperrt), Wegwerf-Slot 99.

var failures := 0


func _initialize() -> void:
	await process_frame
	var waechter := FehlerWaechter.anmelden()
	_test_fabrik()
	var gs: Node = root.get_node_or_null(^"GameState")
	_check(gs != null, "GameState-Autoload vorhanden")
	if gs != null:
		gs.slot_gesperrt = true
		SaveManager.active_slot = 99
		_test_alle_loeschen(gs)
		_test_speichern(gs)
		await _test_szene(gs)
	failures += waechter.fehler_melden()
	if failures == 0:
		print("SELFTEST OK — alle Streifzug-/Kartenlager-Tests bestanden")
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


func _knopf_mit(wurzel: Node, anfang: Array) -> Button:
	for knoten in wurzel.find_children("*", "Button", true, false):
		var knopf := knoten as Button
		if knopf.is_queued_for_deletion() or not knopf.is_visible_in_tree():
			continue
		for text in anfang:
			if knopf.text.begins_with(text):
				return knopf
	return null


func _karte(favorit := false) -> DungeonCard:
	var karte := CardFactory.make_starter_card()
	karte.favorit = favorit
	return karte


func _test_fabrik() -> void:
	print("Streifzug-Karte (CardFactory):")
	var seeds := {}
	var stufen_ok := true
	for i in 20:
		var karte := CardFactory.make_streifzug_card(9)
		seeds[karte.seed] = true
		if karte.tier != 9 or karte.floor_count != 3 or karte.name_teile.size() != 3:
			stufen_ok = false
	_check(stufen_ok, "Stufe = Party-Level (9), Ebenen und Name wie jede Zufallskarte")
	_check(seeds.size() >= 19, "jedes Betreten würfelt neu (%d verschiedene Seeds aus 20)" % seeds.size())
	_check(CardFactory.make_streifzug_card(0).tier == 1, "Stufe mindestens 1")


func _test_alle_loeschen(gs: Node) -> void:
	print("GameState.delete_all_cards:")
	var fav := _karte(true)
	var archiv_karte := _karte()
	var karten: Array[DungeonCard] = [_karte(), fav, _karte(), _karte()]
	gs.cards = karten
	var archiv: Array[DungeonCard] = [archiv_karte]
	gs.card_archive = archiv
	var anzahl: int = gs.delete_all_cards()
	_check(anzahl == 3, "drei Karten gelöscht")
	_check(gs.cards.size() == 1 and gs.cards[0] == fav, "Favorit bleibt im Lager")
	_check(gs.card_archive.size() == 1 and gs.card_archive[0] == archiv_karte, "Archiv bleibt unberührt")
	_check(gs.delete_all_cards() == 0 and gs.cards.size() == 1, "nur Favoriten: nichts zu löschen")


func _test_speichern(gs: Node) -> void:
	print("Spielstand: Streifzug wird nicht gespeichert:")
	var karten: Array[DungeonCard] = [_karte()]
	gs.cards = karten
	gs.card_archive.clear()
	gs.current_run = {}
	var daten: Dictionary = gs.to_save_dict()
	_check((daten.get("cards", []) as Array).size() == 1, "nur die echte Lagerkarte im Spielstand")
	# Alter Spielstand (ohne jedes neue Feld) lädt unverändert.
	gs.apply_save_dict(daten.duplicate(true))
	_check(gs.cards.size() == 1, "Laden unverändert")
	# Laufender Streifzug: die gewürfelte Karte steckt nur im Run.
	var streifzug := CardFactory.make_streifzug_card(gs.average_party_level())
	gs.start_run(streifzug)
	daten = gs.to_save_dict()
	_check((daten.get("cards", []) as Array).size() == 1, "laufender Streifzug belegt keinen Lagerplatz")
	gs.apply_save_dict(daten.duplicate(true))
	_check(not gs.current_run.is_empty() and (gs.current_run["card"] as DungeonCard).seed == streifzug.seed,
		"laufender Streifzug übersteht Speichern/Laden")
	gs.current_run = {}


func _test_szene(gs: Node) -> void:
	print("Kartenlager-Szene:")
	var leer: Array[DungeonCard] = []
	gs.cards = leer
	gs.card_archive.clear()
	gs.current_run = {}
	var szene = load("res://scenes/hub/card_storage.tscn").instantiate()
	root.add_child(szene)
	await _bilder(2)
	var betreten := _knopf_mit(szene._streifzug_box, ["Betreten", "Enter"])
	_check(betreten != null and not betreten.disabled, "leeres Lager: Streifzug lässt sich betreten")
	_check(szene._card_list.get_child_count() == 1 and szene._card_list.get_child(0) is Label,
		"Streifzug steht über der Liste, nicht darin")
	var stufe_text := str(gs.average_party_level())
	var zeilen_text := ""
	for label in szene._streifzug_box.find_children("*", "Label", true, false):
		zeilen_text += (label as Label).text
	_check(zeilen_text.contains(stufe_text), "Zeile nennt die Stufe (Party-Durchschnitt %s)" % stufe_text)
	_check(szene._alle_loeschen.disabled, "leeres Lager: „Alle löschen“ gesperrt")
	_check(_knopf_mit(szene._streifzug_box, ["Löschen", "Delete"]) == null
		and _knopf_mit(szene._streifzug_box, ["☆", "★"]) == null
		and _knopf_mit(szene._streifzug_box, ["Archivieren", "Archive"]) == null,
		"Streifzug: kein Löschen, kein Stern, kein Archivieren")

	# Alle löschen: zwei Klicks, Favorit und Archiv bleiben.
	var fav := _karte(true)
	var archiv_karte := _karte()
	var karten: Array[DungeonCard] = [_karte(), fav, _karte()]
	gs.cards = karten
	var archiv: Array[DungeonCard] = [archiv_karte]
	gs.card_archive = archiv
	szene._refresh()
	await _bilder(2)
	var alle: Button = szene._alle_loeschen
	_check(not alle.disabled and alle.focus_mode != Control.FOCUS_NONE, "„Alle löschen“ aktiv und per Tastatur erreichbar")
	alle.pressed.emit()
	_check(gs.cards.size() == 3 and alle.text.contains("2"), "erster Klick fragt nur nach (nennt 2 Karten)")
	alle.pressed.emit()
	await _bilder(3)
	_check(gs.cards.size() == 1 and gs.cards[0] == fav, "zweiter Klick löscht alles außer dem Favoriten")
	_check(gs.card_archive.size() == 1, "Archiv bleibt")
	_check(alle.disabled and alle.text == Loc.pick("Alle löschen", "Delete all"), "danach gesperrt und zurückgesetzt")
	var fokus := root.gui_get_focus_owner()
	_check(fokus != null and szene._streifzug_box.is_ancestor_of(fokus), "Fokus springt auf den Streifzug")

	# Rückfrage wird von einem Einzel-Löschen zurückgesetzt.
	var karten2: Array[DungeonCard] = [_karte(), _karte()]
	gs.cards = karten2
	szene._refresh()
	await _bilder(2)
	alle.pressed.emit()
	var einzel := _knopf_mit(szene._card_list, ["Löschen", "Delete"])
	einzel.pressed.emit()
	_check(alle.text == Loc.pick("Alle löschen", "Delete all") and gs.cards.size() == 2,
		"Einzel-Löschen nimmt die „Alle löschen“-Rückfrage zurück")

	# Laufender Dungeon: erst der zweite Klick würfelt (nur der erste wird geprüft).
	gs.current_run = {"card": _karte()}
	szene._refresh()
	await _bilder(2)
	betreten = _knopf_mit(szene._streifzug_box, ["Betreten", "Enter"])
	betreten.pressed.emit()
	await _bilder(2)
	_check(_knopf_mit(szene._streifzug_box, [Loc.pick("Laufenden Dungeon verwerfen?", "Discard the current dungeon?")]) != null,
		"laufender Dungeon: erster Klick fragt nach")
	fokus = root.gui_get_focus_owner()
	_check(fokus != null and szene._streifzug_box.is_ancestor_of(fokus), "Fokus bleibt auf dem Streifzug")
	gs.current_run = {}

	# Archiv-Ansicht: kein Streifzug, kein „Alle löschen“.
	szene._tab_archiv.pressed.emit()
	await _bilder(2)
	_check(not szene._streifzug_box.visible and not alle.visible, "Archiv: Streifzug und „Alle löschen“ ausgeblendet")
	szene.queue_free()
	await _bilder(1)
