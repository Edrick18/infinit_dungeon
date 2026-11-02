extends SceneTree
## Headless-Selbsttest für Kartenfabrik und Kartenlager:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/hub_selftest.gd

var failures := 0


func _init() -> void:
	_test_card_factory()
	_test_reward_tiers()
	_test_storage()
	_test_merchant_orders()
	_test_bestiarium_auftraege()
	_test_archiv_und_truhen()
	if failures == 0:
		print("SELFTEST OK — alle Hub-/Kartensystem-Tests bestanden")
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


func _test_card_factory() -> void:
	print("Kartenfabrik:")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var all_ok := true
	var biomes := {}
	for i in 50:
		var card := CardFactory.make_card(3, rng)
		biomes[card.biome] = true
		if card.display_name.is_empty() or card.tier != 3 or card.modifier_ids.is_empty():
			all_ok = false
		for id in card.modifier_ids:
			var modifier := EnemyLibrary.get_modifier(id)
			if modifier == null or modifier.min_tier > 3:
				all_ok = false
	_check(all_ok, "50 Karten: Name, Stufe und gültige Modifikatoren (min_tier ok)")
	_check(biomes.size() == 2, "Stufe 3: genau zwei Biome freigeschaltet (Wald + Höhle)")

	var starter := CardFactory.make_starter_card()
	_check(starter.tier == 1 and starter.biome == Enums.Biome.FOREST,
		"Startkarte: Stufe 1, Wald")


func _test_reward_tiers() -> void:
	print("Belohnungskarte (Gewichtung −2..+5):")
	var base := DungeonCard.new()
	base.tier = 5
	var in_range := true
	var varied := {}
	var tier_sum := 0
	for i in 100:
		var reward := CardFactory.make_reward(base)
		varied[reward.tier] = true
		tier_sum += reward.tier
		if reward.tier < 3 or reward.tier > 10:
			in_range = false
	_check(in_range, "100 Belohnungen: immer im Bereich Stufe 3-10 (5 −2..+5)")
	_check(varied.size() >= 4, "Stufen streuen (%d verschiedene)" % varied.size())
	# Erwartungswert +1,5: über 100 Würfe geht es im Schnitt klar bergauf.
	_check(tier_sum > 100 * 5, "Gewichtung zieht nach oben (Ø %.1f statt 5,0)"
		% (tier_sum / 100.0))

	var low := DungeonCard.new()
	low.tier = 1
	var min_ok := true
	for i in 50:
		if CardFactory.make_reward(low).tier < 1:
			min_ok = false
	_check(min_ok, "Stufe fällt nie unter 1")


func _test_storage() -> void:
	print("Kartenlager:")
	# GameState außerhalb des Baums instanziieren (ohne _ready/Startkarten).
	var state: Node = load("res://autoload/game_state.gd").new()
	state.card_capacity = 3

	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var cards: Array[DungeonCard] = []
	for i in 4:
		cards.append(CardFactory.make_card(1, rng))

	_check(state.add_card(cards[0]) and state.add_card(cards[1]) and state.add_card(cards[2]),
		"3 Karten passen ins Lager (Kapazität 3)")
	_check(not state.add_card(cards[3]), "4. Karte wird abgelehnt — Lager voll")

	state.delete_card(cards[1])
	_check(state.cards.size() == 2 and state.add_card(cards[3]),
		"nach Löschen ist wieder Platz")

	state.gold = 90
	_check(not state.can_expand_storage(), "Erweiterung mit 90 G nicht leistbar (kostet 100)")
	state.gold = 150
	var cost_before: int = state.storage_expansion_cost()
	_check(state.expand_storage(), "Erweiterung klappt mit genug Gold")
	_check(state.card_capacity == 8, "Kapazität 3 » 8 (+5 Slots)")
	_check(state.gold == 150 - cost_before, "Gold wurde abgezogen")
	_check(state.storage_expansion_cost() > cost_before, "nächste Erweiterung wird teurer")
	state.free()


func _test_merchant_orders() -> void:
	print("Händler-Aufträge:")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# Generierung: alle drei Auftragstypen kommen vor, Texte sind vollständig.
	var types := {}
	var texts_ok := true
	for i in 200:
		var order := MerchantOrders.make_order(5, rng)
		types[order["type"]] = true
		if MerchantOrders.describe(order) == "?" or MerchantOrders.reward_text(order) == "?":
			texts_ok = false
	_check(types.size() >= 6, "die Auftragsarten kommen vor (%d: %s)" % [types.size(), types.keys()])
	_check(texts_ok, "jeder Auftrag hat Beschreibung und Belohnungstext")

	var state: Node = load("res://autoload/game_state.gd").new()
	state.ensure_orders()
	_check(state.merchant_orders.size() == MerchantOrders.ORDER_SLOTS,
		"ensure_orders füllt auf %d Slots" % MerchantOrders.ORDER_SLOTS)

	# Lieferauftrag: erst unerfüllt, mit Material erfüllbar, Abgabe zieht ein.
	var deliver := {"type": "deliver", "material": &"heilkraut", "count": 3,
		"reward": {"kind": "gold", "gold": 80}}
	state.merchant_orders = [deliver] as Array[Dictionary]
	_check(not MerchantOrders.is_complete(deliver, state), "Lieferauftrag: ohne Material unerfüllt")
	state.add_material(&"heilkraut", 3)
	_check(MerchantOrders.is_complete(deliver, state), "Lieferauftrag: mit Material erfüllt")
	var gold_before: int = state.gold
	_check(state.claim_order(deliver), "Abgeben klappt")
	_check(state.gold == gold_before + 80, "Gold-Belohnung wird gutgeschrieben")
	_check(state.material_count(&"heilkraut") == 0, "gelieferte Materialien werden eingezogen")
	_check(state.merchant_orders.size() == MerchantOrders.ORDER_SLOTS,
		"nach der Abgabe rückt ein neuer Auftrag nach")

	# Jagdauftrag: Kills zählen mit, dann abgeben.
	var hunt := {"type": "hunt", "count": 5, "progress": 0,
		"reward": {"kind": "materials", "materials": {&"eisenerz": 2}}}
	state.merchant_orders = [hunt] as Array[Dictionary]
	state.note_kills(3)
	_check(int(hunt["progress"]) == 3, "note_kills zählt Kills auf Jagdaufträge")
	_check(not MerchantOrders.is_complete(hunt, state), "3/5: noch nicht fertig")
	state.note_kills(4)
	_check(int(hunt["progress"]) == 5, "Fortschritt ist bei der Zielzahl gedeckelt")
	_check(state.claim_order(hunt), "Jagdauftrag abgeben")
	_check(state.material_count(&"eisenerz") == 2, "Material-Belohnung kommt an")

	# Abschlussauftrag: nur die passende Karte erfüllt ihn.
	var clear := {"type": "clear", "biome": int(Enums.Biome.CAVE), "min_tier": 4,
		"count": 1, "progress": 0, "reward": {"kind": "card", "biome": int(Enums.Biome.CRYPT)}}
	state.merchant_orders = [clear] as Array[Dictionary]
	var wrong_card := DungeonCard.new()
	wrong_card.biome = Enums.Biome.FOREST
	wrong_card.tier = 9
	state.note_card_cleared(wrong_card)
	var low_card := DungeonCard.new()
	low_card.biome = Enums.Biome.CAVE
	low_card.tier = 3
	state.note_card_cleared(low_card)
	_check(int(clear["progress"]) == 0, "falsches Biom / zu niedrige Stufe zählen nicht")
	var right_card := DungeonCard.new()
	right_card.biome = Enums.Biome.CAVE
	right_card.tier = 4
	state.note_card_cleared(right_card)
	_check(int(clear["progress"]) == 1, "passende Karte erfüllt den Abschlussauftrag")
	var cards_before: int = state.cards.size()
	_check(state.claim_order(clear), "Wunsch-Karten-Auftrag abgeben")
	_check(state.cards.size() == cards_before + 1, "Wunsch-Karte landet im Lager")
	var wish: DungeonCard = state.cards[state.cards.size() - 1]
	_check(wish.biome == Enums.Biome.CRYPT, "Wunsch-Karte hat das versprochene Biom")

	# Serialisierung: Rundweg erhält Beschreibung und Fortschritt.
	var order := MerchantOrders.make_order(8, rng)
	var restored := MerchantOrders.from_dict(MerchantOrders.to_dict(order))
	_check(MerchantOrders.describe(restored) == MerchantOrders.describe(order)
		and MerchantOrders.reward_text(restored) == MerchantOrders.reward_text(order),
		"Auftrag übersteht den Serialisierungs-Rundweg")
	state.free()


func _test_archiv_und_truhen() -> void:
	print("Archiv, Favoriten & Truhen seltener Karten:")
	var state: Node = load("res://autoload/game_state.gd").new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var karte := CardFactory.make_card(5, rng)
	state.cards = [karte] as Array[DungeonCard]
	_check(state.archive_card(karte) and state.cards.is_empty() and state.card_archive.size() == 1,
		"Archivieren: Karte verlässt das Lager und liegt im Archiv")
	_check(state.unarchive_card(karte) and state.cards.size() == 1 and state.card_archive.is_empty(),
		"zurück ins Lager")
	karte.favorit = true
	var kopie := DungeonCard.from_dict(karte.to_dict())
	_check(kopie.favorit, "Favorit übersteht den Speicher-Rundweg")
	karte.notiz = "Hexenmeisterin als Boss"
	_check(DungeonCard.from_dict(karte.to_dict()).notiz == "Hexenmeisterin als Boss",
		"Karten-Notiz übersteht den Speicher-Rundweg")
	var schmuck := ItemLibrary.make_item(&"ring", 1)
	var schmuck_hoch := ItemLibrary.make_item(&"ring", 20)
	_check(schmuck.get_total_stat_bonus().luck > 0 and schmuck_hoch.get_total_stat_bonus().luck
		> schmuck.get_total_stat_bonus().luck, "Ringe haben Grund-Attribute, die mit dem Level wachsen")
	_check(ItemLibrary.make_item(&"amulett", 1).get_total_stat_bonus().spirit > 0, "Amulette auch")
	state.free()

	# Seltene Karten: im Schnitt deutlich bessere Truhen (gleiche Seeds).
	var summe_normal := 0
	var summe_legendaer := 0
	for i in 40:
		var r := RandomNumberGenerator.new()
		r.seed = 100 + i
		var normal := CardFactory.make_card(6, r)
		normal.card_rarity = Enums.Rarity.COMMON
		var selten := DungeonCard.from_dict(normal.to_dict())
		selten.card_rarity = Enums.Rarity.LEGENDARY
		for truhe in DungeonGenerator.generate(normal).chests:
			summe_normal += int(truhe["rarity"])
		for truhe in DungeonGenerator.generate(selten).chests:
			summe_legendaer += int(truhe["rarity"])
	_check(summe_legendaer > summe_normal * 1.3,
		"legendäre Karten haben bessere Truhen (%d vs %d)" % [summe_legendaer, summe_normal])


func _gegner(archetype: StringName, name := "") -> Combatant:
	var c := Combatant.create(name if not name.is_empty() else String(archetype), StatBlock.new(), false)
	c.archetype_id = archetype
	c.hp = 0
	return c


func _test_bestiarium_auftraege() -> void:
	print("Händler-Aufträge mit Bestiarium-Bezug:")
	var state: Node = load("res://autoload/game_state.gd").new()
	# Häufigkeit und Ziele aus erreichbaren Biomen.
	var arten := {}
	var ziele_ok := true
	for i in 1000:
		var rng := RandomNumberGenerator.new()
		rng.seed = 3000 + i
		var order := MerchantOrders.make_order(12, rng, state)
		arten[order["type"]] = int(arten.get(order["type"], 0)) + 1
		match order["type"]:
			"hunt_type":
				ziele_ok = ziele_ok and order["archetype"] in MerchantOrders.grundtypen_fuer(12)
			"eigenheit":
				ziele_ok = ziele_ok and order["eigenheit"] in MerchantOrders.eigenheiten_fuer(12, state)
			"boss":
				var boss := EnemyLibrary.get_archetype(order["archetype"])
				ziele_ok = ziele_ok and boss != null and boss.is_boss_capable
			"elite":
				ziele_ok = ziele_ok and EnemyLibrary.get_modifier(order["modifier"]) != null
	print("  Verteilung (1000 Aufträge, Party-Schnitt 12): %s" % arten)
	_check(arten.size() == 7, "alle 7 Auftragsarten kommen vor")
	_check(ziele_ok, "Ziele stammen aus erreichbaren Biomen, Eigenheiten bekannt oder dort vorkommend")
	var niedrig := {}
	for i in 300:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9000 + i
		niedrig[MerchantOrders.make_order(1, rng)["type"]] = true
	_check(not niedrig.has("elite") and not niedrig.has("boss"), "Party-Schnitt 1: keine Elite- oder Boss-Aufträge")
	var wald := MerchantOrders.grundtypen_fuer(2)
	var krypta_dabei := false
	for id in wald:
		var a := EnemyLibrary.get_archetype(id)
		krypta_dabei = krypta_dabei or (Enums.Biome.FOREST not in a.biomes)
	_check(not krypta_dabei and not wald.is_empty(), "Party-Schnitt 2: nur Grundtypen des Waldes (%s)" % [wald])
	# Bekannte Eigenheiten zählen mit, auch wenn der Grundtyp nicht im Biom-Pool liegt.
	state.eigenheit_wissen = ["nekromant"]
	_check(&"totenruf" in MerchantOrders.eigenheiten_fuer(2, state), "bekannte Eigenheit (Totenruf) ist wählbar")

	# Fortschritt: Grundtyp.
	var typ := {"type": "hunt_type", "archetype": &"wolf", "count": 3, "progress": 0,
		"reward": {"kind": "gold", "gold": 100}}
	state.merchant_orders = [typ] as Array[Dictionary]
	state.note_kampf_auftraege([_gegner(&"wolf"), _gegner(&"bandit"), _gegner(&"wolf")], false, null)
	_check(int(typ["progress"]) == 2 and not MerchantOrders.is_complete(typ, state), "Grundtyp: nur Wölfe zählen (2/3)")
	state.note_kampf_auftraege([_gegner(&"wolf"), _gegner(&"wolf")], false, null)
	_check(int(typ["progress"]) == 3 and MerchantOrders.is_complete(typ, state), "Grundtyp: gedeckelt und erfüllt")
	_check(MerchantOrders.describe(typ).contains("Wolf") and MerchantOrders.describe(typ).contains("3/3"),
		"Text: %s" % MerchantOrders.describe(typ))

	# Elite mit Merkmal: Name + Rang entscheiden.
	var gepanzert := EnemyLibrary.get_modifier(&"gepanzert").display_name
	var elite := {"type": "elite", "modifier": &"gepanzert", "count": 2, "progress": 0,
		"reward": {"kind": "gold", "gold": 100}}
	state.merchant_orders = [elite] as Array[Dictionary]
	var e1 := _gegner(&"wolf", "Wald-Wolf [%s]" % gepanzert)
	e1.set_meta(&"rang", "elite")
	var e2 := _gegner(&"bandit", "Champion: Bandit [Schnell, %s]" % gepanzert)
	e2.set_meta(&"rang", "champion")
	var e3 := _gegner(&"wolf", "Wald-Wolf [Schnell]")
	e3.set_meta(&"rang", "elite")
	var e4 := _gegner(&"wolf", "Gepanzerter Wolf")
	state.note_kampf_auftraege([e1, e3, e4], false, null)
	_check(int(elite["progress"]) == 1, "Elite: nur Elite mit dem Merkmal zählt (1/2)")
	state.note_kampf_auftraege([e2], false, null)
	_check(MerchantOrders.is_complete(elite, state), "Elite: auch Champions mit dem Merkmal zählen")
	# Echt erzeugter Elite-Gegner trägt das Merkmal im Namen.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 1
	var echt := EnemyFactory.build(EnemyLibrary.get_archetype(&"wolf"), 10, rng2,
		[EnemyLibrary.get_modifier(&"gepanzert")] as Array[EnemyModifier])
	echt.set_meta(&"rang", "elite")
	_check(MerchantOrders.traegt_merkmal(echt, &"gepanzert") and not MerchantOrders.traegt_merkmal(echt, &"schnell"),
		"echter Elite-Gegner: Merkmal erkannt (%s)" % echt.display_name)

	# Eigenheit auslösen.
	var eig := {"type": "eigenheit", "eigenheit": &"rudel", "count": 2, "progress": 0,
		"reward": {"kind": "gold", "gold": 100}}
	state.merchant_orders = [eig] as Array[Dictionary]
	state.note_eigenheit(&"netz")
	state.note_eigenheit(&"rudel")
	_check(int(eig["progress"]) == 1, "Eigenheit: nur die verlangte zählt")
	state.note_eigenheit(&"rudel")
	state.note_eigenheit(&"rudel")
	_check(int(eig["progress"]) == 2 and MerchantOrders.is_complete(eig, state), "Eigenheit: erfüllt und gedeckelt")

	# Boss eines Bioms ab Stufe N.
	var boss_auftrag := {"type": "boss", "biome": int(Enums.Biome.CAVE), "archetype": &"golem", "min_tier": 10,
		"count": 1, "progress": 0, "reward": {"kind": "gold", "gold": 300}}
	state.merchant_orders = [boss_auftrag] as Array[Dictionary]
	var golem := _gegner(&"golem", "Boss: Höhlen-Golem")
	golem.ist_bossgegner = true
	var karte := DungeonCard.new()
	karte.biome = Enums.Biome.CAVE
	karte.tier = 9
	state.note_kampf_auftraege([golem], true, karte)
	_check(int(boss_auftrag["progress"]) == 0, "Boss: zu niedrige Stufe zählt nicht")
	karte.tier = 12
	state.note_kampf_auftraege([_gegner(&"golem")], false, karte)
	_check(int(boss_auftrag["progress"]) == 0, "Boss: normaler Golem zählt nicht")
	var troll := _gegner(&"troll")
	troll.ist_bossgegner = true
	state.note_kampf_auftraege([troll], true, karte)
	_check(int(boss_auftrag["progress"]) == 0, "Boss: anderer Boss zählt nicht")
	state.note_kampf_auftraege([golem], true, karte)
	_check(MerchantOrders.is_complete(boss_auftrag, state), "Boss: passender Boss ab Stufe 10 erfüllt")
	var gold_vorher: int = state.gold
	_check(state.claim_order(boss_auftrag) and state.gold == gold_vorher + 300, "Boss-Auftrag abgeben")

	# Texte DE/EN und Speichern (neue Felder) + alte Spielstände.
	for order in [typ, elite, eig, boss_auftrag]:
		var zurueck := MerchantOrders.from_dict(JSON.parse_string(JSON.stringify(MerchantOrders.to_dict(order))))
		_check(MerchantOrders.describe(zurueck) == MerchantOrders.describe(order) and zurueck["type"] == order["type"],
			"Rundweg %s: %s" % [order["type"], MerchantOrders.describe(zurueck)])
	Loc.set_language("en")
	EnemyLibrary.reset_cache()
	var texte_en := [MerchantOrders.describe(typ), MerchantOrders.describe(elite), MerchantOrders.describe(eig),
		MerchantOrders.describe(boss_auftrag)]
	Loc.set_language("de")
	EnemyLibrary.reset_cache()
	_check(texte_en[0].begins_with("Defeat 3 enemies of the base type Wolf") and texte_en[1].contains("Armored")
		and texte_en[2].contains("Pack") and texte_en[3].contains("Golem") and texte_en[3].contains("biome Cave"),
		"Texte englisch: %s" % " | ".join(texte_en))
	var alt := {"type": "hunt", "count": 9, "progress": 4, "min_tier": 0, "biome": -1,
		"reward": {"kind": "gold", "gold": 77}}
	var alt_clear := {"type": "clear", "count": 1, "progress": 0, "min_tier": 6, "biome": 2,
		"reward": {"kind": "card", "biome": 1}}
	var geladen := MerchantOrders.from_dict(alt)
	var geladen_clear := MerchantOrders.from_dict(alt_clear)
	_check(geladen["type"] == "hunt" and int(geladen["progress"]) == 4 and geladen_clear["type"] == "clear"
		and int(geladen_clear["min_tier"]) == 6, "alte gespeicherte Aufträge laden unverändert")
	var kaputt := MerchantOrders.from_dict({"type": "hunt_type", "count": 4, "progress": 1,
		"reward": {"kind": "gold", "gold": 10}})
	_check(kaputt["type"] == "hunt" and MerchantOrders.describe(kaputt) != "?", "Auftrag ohne Ziel wird zum Jagd-Auftrag")
	var unbekannt := MerchantOrders.from_dict({"type": "zukunft", "count": 2, "reward": {"kind": "gold", "gold": 10}})
	_check(unbekannt["type"] == "hunt", "unbekannte Auftragsart lädt als Jagd-Auftrag")
	state.free()
