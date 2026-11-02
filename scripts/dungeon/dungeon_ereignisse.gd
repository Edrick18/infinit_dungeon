class_name DungeonEreignisse
extends RefCounted
## Seltene Dungeon-Ereignisse (2026-11-02), zusätzlich zu Schreinen,
## Opfersteinen und Risiko-Truhen — beide per [E]:
##  • Gefangener Held: Wächter (eine Gruppe der Ebene) bewachen ihn. Nach dem
##    Sieg über sie wird er befreit und wartet auf der Taverne-Bank — ein
##    prozedural erzeugter Held (Name, Startwerte, Ausrüstung nach Kartenstufe).
##  • Fahrender Händler: tauscht Materialien gegen andere Materialien oder
##    Tränke; Angebote nach Biom und Kartenstufe, jedes einmal.
## Platzierung, Held und Angebote folgen dem Karten-Seed (eigener Würfel je
## Ebene, bestehende Karten behalten Layout und alte Ereignisse). Nur im
## eigenen Spielstand, nicht im Koop (DungeonScene blendet sie dort aus).
## Reine Klasse: headless testbar (dungeon_selftest).

const HAENDLER_AB_STUFE := 3
const HAENDLER_CHANCE := 0.18     ## je normaler Ebene
const GEFANGENER_AB_STUFE := 5
const GEFANGENER_CHANCE := 0.06   ## je normaler Ebene
const MIN_ABSTAND := 8            ## Wegfelder vom Spawn
## Junk-IDs der Wächterkämpfe (wie Mimics 900000): der Sieg hakt sie in
## run["defeated"] ab, ohne mit echten Gegnern zu kollidieren.
const WAECHTER_ID := 800000


## Ereignisse auf einer normalen Ebene ergänzen (DungeonGenerator.generate).
static func platzieren(map: DungeonMap, card: DungeonCard, floor_index: int, dist: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([card.seed, floor_index, "sonderereignis"])
	var arten: Array = []
	if card.tier >= HAENDLER_AB_STUFE and rng.randf() < HAENDLER_CHANCE:
		arten.append(DungeonGenerator.EventType.HAENDLER)
	if card.tier >= GEFANGENER_AB_STUFE and rng.randf() < GEFANGENER_CHANCE:
		arten.append(DungeonGenerator.EventType.GEFANGENER)
	if arten.is_empty():
		return
	var used: Array[Vector2i] = [map.boss_cell, map.stairs_cell, map.spawn, map.tresor_cell]
	var next_id := 0
	for liste in [map.enemies, map.chests, map.events]:
		for eintrag in liste:
			used.append(eintrag["cell"])
	for event in map.events:
		next_id = maxi(next_id, int(event["id"]) + 1)
	var zellen := DungeonGenerator._shuffled_floor(map, rng)
	for art in arten:
		for cell in zellen:
			if dist.has(cell) and dist[cell] >= MIN_ABSTAND and cell not in used:
				used.append(cell)
				map.events.append({"id": next_id, "cell": cell, "type": art})
				next_id += 1
				break


static func ist_sonderereignis(typ: int) -> bool:
	return typ == DungeonGenerator.EventType.HAENDLER or typ == DungeonGenerator.EventType.GEFANGENER


# --- Gefangener Held ------------------------------------------------------------

const SILBEN_A: Array[String] = ["Al", "Bra", "Cor", "Da", "El", "Fen", "Gar", "Hal", "Is", "Jor",
	"Ka", "Lor", "Mar", "Ner", "Os", "Per", "Ra", "Sel", "Tor", "Ul", "Ves", "Wil", "Yr", "Zan"]
const SILBEN_B: Array[String] = ["", "a", "e", "i", "o", "ra", "li", "ne", "vo", "da"]
const SILBEN_C: Array[String] = ["n", "r", "s", "th", "ra", "na", "dric", "mir", "wen", "bert", "old", "ia",
	"rik", "lin", "dis"]
## Startwerte je Loadout: Gewichte für die Statuspunkte (STR, INT, VIT, SPI, AGI, LCK).
const GEWICHTE := {
	&"schwert_schild": [4, 0, 4, 1, 2, 1], &"dolche": [3, 0, 2, 0, 4, 2], &"axt": [5, 0, 3, 0, 2, 1],
	&"knueppel": [4, 0, 4, 1, 1, 1], &"bogen": [3, 0, 2, 0, 4, 2], &"feuerstab": [0, 5, 2, 2, 1, 1],
	&"giftstab": [0, 5, 2, 2, 1, 1], &"heiligstab": [0, 2, 2, 5, 1, 1],
}
## Rüstung je Loadout: Basis-IDs für Brust, Kopf, Füße.
const RUESTUNG := {
	&"feuerstab": [&"robe_schaden", &"helm_leicht", &"stiefel_leicht"],
	&"giftstab": [&"robe_schaden", &"helm_leicht", &"stiefel_leicht"],
	&"heiligstab": [&"robe_heil", &"helm_leicht", &"stiefel_leicht"],
	&"dolche": [&"ruestung_leicht", &"helm_leicht", &"stiefel_leicht"],
	&"bogen": [&"ruestung_leicht", &"helm_leicht", &"stiefel_leicht"],
}
const RUESTUNG_STANDARD := [&"ruestung_mittel", &"helm_schwer", &"stiefel_schwer"]


static func gefangenen_rng(card: DungeonCard, floor_index: int, event_id: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([card.seed, floor_index, event_id, "gefangener"])
	return rng


## Prozeduraler Name, eindeutig gegenüber `vergeben`.
static func held_name(rng: RandomNumberGenerator, vergeben: Array) -> String:
	for versuch in 30:
		var name: String = SILBEN_A[rng.randi_range(0, SILBEN_A.size() - 1)] \
			+ SILBEN_B[rng.randi_range(0, SILBEN_B.size() - 1)] \
			+ SILBEN_C[rng.randi_range(0, SILBEN_C.size() - 1)]
		if name not in vergeben and name.length() >= 3:
			return name
	var basis := "Gefangener" if Loc.language == "de" else "Prisoner"
	var n := 2
	while "%s %d" % [basis, n] in vergeben:
		n += 1
	return "%s %d" % [basis, n]


## Der gefangene Held einer Karte/Ebene: Level = ziel_level, Statuspunkte
## nach Loadout verteilt, Waffen und Rüstung auf diesem Item-Level
## (Magisch bis Episch). Deterministisch je Karte, Ebene und Ereignis.
static func held_erzeugen(card: DungeonCard, floor_index: int, event_id: int, ziel_level: int,
		vergeben: Array) -> Combatant:
	var rng := gefangenen_rng(card, floor_index, event_id)
	var loadouts: Array = HeroLibrary.STARTER_LOADOUTS.keys()
	var loadout: StringName = loadouts[rng.randi_range(0, loadouts.size() - 1)]
	var held := HeroLibrary.create_hero(held_name(rng, vergeben), loadout)
	held.set_meta(&"gefangen_loadout", loadout)  # nur für die Meldung, nicht gespeichert
	var ziel := maxi(1, ziel_level)
	var schutz := 0
	while held.level < ziel and schutz < 1000:
		held.gain_xp(maxi(1, Combatant.xp_bedarf(held.level) - held.xp))
		schutz += 1
	# Startwerte: Statuspunkte nach Gewicht des Loadouts.
	var gewichte: Array = GEWICHTE.get(loadout, [1, 1, 1, 1, 1, 1])
	var summe := 0
	for g in gewichte:
		summe += int(g)
	while held.stat_points > 0:
		var wurf := rng.randi_range(1, summe)
		for i in gewichte.size():
			wurf -= int(gewichte[i])
			if wurf <= 0:
				held.spend_stat_point(StatBlock.STAT_NAMES[i])
				break
	# Ausrüstung nach Kartenstufe (Waffen des Loadouts, dazu Rüstung).
	var item_level := maxi(1, mini(card.tier, ziel))
	var teile: Array = []
	var kit: Dictionary = HeroLibrary.STARTER_LOADOUTS[loadout]
	teile.append(kit["weapon"])
	if kit.has("offhand"):
		teile.append(kit["offhand"])
	teile.append_array(RUESTUNG.get(loadout, RUESTUNG_STANDARD))
	# Start-Ausrüstung ablegen (sonst landet der zweite Dolch nicht in der Nebenhand).
	held.unequip(Enums.EquipSlot.OFF_HAND)
	held.unequip(Enums.EquipSlot.WEAPON)
	for base_id in teile:
		var item := ItemLibrary.make_item(base_id, item_level)
		if item == null:
			continue
		var r := rng.randf()
		item.rarity = Enums.Rarity.EPIC if r < 0.1 else (Enums.Rarity.RARE if r < 0.4 else Enums.Rarity.MAGIC)
		LootGenerator.apply_random_affixes(item, rng)
		held.equip(item)
	held.reset_for_battle(true)
	return held


static func loadout_von(held: Combatant) -> StringName:
	return StringName(held.get_meta(&"gefangen_loadout", &"schwert_schild"))


# --- Fahrender Händler ---------------------------------------------------------------

## Werkstoff-Arten, die der Händler je Biom bevorzugt anbietet.
const BIOM_ARTEN := {
	Enums.Biome.FOREST: [&"leder", &"kraut"], Enums.Biome.CAVE: [&"erz", &"kristall"],
	Enums.Biome.RUINS: [&"erz", &"leder"], Enums.Biome.CRYPT: [&"kristall", &"kraut"],
	Enums.Biome.INFERNAL: [&"erz", &"kristall"],
}
const WERKSTOFFE: Array[StringName] = [&"erz", &"leder", &"kristall"]


static func _material(art: StringName, stufe: int, rng: RandomNumberGenerator) -> StringName:
	if art == &"kraut":
		return MaterialLibrary.roll_der_art(&"kraut", rng)
	return MaterialLibrary.werkstoff(art, clampi(stufe, 1, 5))


## Angebote eines Händlers: [{"gibt": [id, n], "nimmt": [[id, n], …], "trank": bool}].
## gibt = was die Party bekommt, nimmt = was sie bezahlt.
static func angebote(card: DungeonCard, floor_index: int, event_id: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([card.seed, floor_index, event_id, "haendler"])
	var stufe := MaterialLibrary.stufe_fuer_karte(card.tier)
	var biom_arten: Array = BIOM_ARTEN.get(card.biome, WERKSTOFFE)
	var liste: Array = []
	# 1) Tausch: fremder Werkstoff gegen den des Bioms (3 gegen 2).
	var ziel_art: StringName = biom_arten[0] if biom_arten[0] != &"kraut" else WERKSTOFFE[rng.randi_range(0, 2)]
	var andere: Array = WERKSTOFFE.duplicate()
	andere.erase(ziel_art)
	var zahl_art: StringName = andere[rng.randi_range(0, andere.size() - 1)]
	liste.append({"gibt": [_material(ziel_art, stufe, rng), 2],
		"nimmt": [[_material(zahl_art, stufe, rng), 3]], "trank": false})
	# 2) Veredeln: 4 der Stufe darunter gegen 1 der Kartenstufe (ab Stufe 2),
	#    sonst ein zweiter Tausch mit der anderen Biom-Art.
	var art2: StringName = biom_arten[1] if biom_arten[1] != &"kraut" else WERKSTOFFE[rng.randi_range(0, 2)]
	if stufe >= 2:
		liste.append({"gibt": [_material(art2, stufe, rng), 1],
			"nimmt": [[_material(art2, stufe - 1, rng), 4]], "trank": false})
	else:
		var andere2: Array = WERKSTOFFE.duplicate()
		andere2.erase(art2)
		liste.append({"gibt": [_material(art2, stufe, rng), 2],
			"nimmt": [[_material(andere2[rng.randi_range(0, andere2.size() - 1)], stufe, rng), 3]], "trank": false})
	# 3) Trank gegen Kräuter (+ Werkstoff auf hohen Stufen).
	var traenke := [[&"heiltrank", &"heilkraut"], [&"manatrank", &"manabluete"]]
	if card.tier >= 15:
		traenke = [[&"grosser_heiltrank", &"heilkraut"], [&"grosser_manatrank", &"manabluete"]]
	var wahl: Array = traenke[rng.randi_range(0, traenke.size() - 1)]
	var preis: Array = [[wahl[1], 3]]
	if card.tier >= 15:
		preis.append([_material(WERKSTOFFE[rng.randi_range(0, 2)], stufe, rng), 1])
	liste.append({"gibt": [wahl[0], rng.randi_range(1, 2)], "nimmt": preis, "trank": true})
	# 4) Selten: Belebungselixier (Kartenstufe 10+, 40 %).
	if card.tier >= 10 and rng.randf() < 0.4:
		liste.append({"gibt": [&"belebungselixier", 1],
			"nimmt": [[&"heilkraut", 3], [&"reinigungssalz", 2], [_material(&"kristall", stufe, rng), 1]],
			"trank": true})
	return liste


## Name eines Angebot-Teils (Material oder Trank) in der aktuellen Sprache.
static func teil_name(id: StringName) -> String:
	if MaterialLibrary.MATERIALS.has(id):
		return MaterialLibrary.display_name(id)
	var def := ConsumableLibrary.get_def(id)
	return def.display_name if def != null else String(id)


## „2× Feines Leder für 3× Stahlerz“.
static func angebot_text(angebot: Dictionary) -> String:
	var preis: Array[String] = []
	for teil in angebot["nimmt"]:
		preis.append("%d× %s" % [int(teil[1]), teil_name(teil[0])])
	return Loc.pick("%d× %s für %s", "%d× %s for %s") % [int(angebot["gibt"][1]),
		teil_name(angebot["gibt"][0]), ", ".join(preis)]


## Kann state (GameState) das Angebot bezahlen?
static func bezahlbar(angebot: Dictionary, state: Node) -> bool:
	for teil in angebot["nimmt"]:
		if state.material_count(teil[0]) < int(teil[1]):
			return false
	return true


## Tausch ausführen: zieht den Preis ab, gibt Material oder Trank. false = zu wenig.
static func tauschen(angebot: Dictionary, state: Node) -> bool:
	if not bezahlbar(angebot, state):
		return false
	var preis := {}
	for teil in angebot["nimmt"]:
		preis[teil[0]] = int(preis.get(teil[0], 0)) + int(teil[1])
	if not state.pay({"materials": preis}):
		return false
	var gibt: StringName = angebot["gibt"][0]
	for i in int(angebot["gibt"][1]):
		if bool(angebot["trank"]):
			state.add_consumable(gibt)
	if not bool(angebot["trank"]):
		state.add_material(gibt, int(angebot["gibt"][1]))
	return true
