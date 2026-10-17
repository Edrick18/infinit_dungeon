class_name MaterialLibrary
extends RefCounted
## Crafting-Materialien: droppen von Gegnern und aus Truhen und werden beim
## Alchemisten (Kräuter/Salze » Tränke) bzw. in der Schmiede (Erz, Leder,
## Kristall » Ausrüstung) verbraucht.
##
## Schmiede-Werkstoffe gibt es in 5 STUFEN: je höher die Kartenstufe, desto
## edler das Erz/Leder/der Kristall, das dort droppt. Höhere Stufen schmieden
## höhere Item-Level und erhöhen die CHANCE auf bessere Rarität. Runen
## (seltener Boss-Drop) garantieren beim Schmieden eine Mindest-Rarität.

## id » {name, name_en, art, stufe, weight (Drop-Gewicht innerhalb der Art)}
## art: kraut | erz | leder | kristall | rune
const MATERIALS := {
	# Alchemie (Händler kauft/verkauft, Tränke brauen)
	&"heilkraut": {"name": "Heilkraut", "name_en": "Healing Herb", "art": &"kraut", "stufe": 1, "weight": 4},
	&"manabluete": {"name": "Manablüte", "name_en": "Mana Blossom", "art": &"kraut", "stufe": 1, "weight": 3},
	&"reinigungssalz": {"name": "Reinigungssalz", "name_en": "Purifying Salt", "art": &"kraut", "stufe": 1, "weight": 3},
	# Schmiede — Erz
	&"eisenerz": {"name": "Eisenerz", "name_en": "Iron Ore", "art": &"erz", "stufe": 1},
	&"stahlerz": {"name": "Stahlerz", "name_en": "Steel Ore", "art": &"erz", "stufe": 2},
	&"mithrilerz": {"name": "Mithrilerz", "name_en": "Mithril Ore", "art": &"erz", "stufe": 3},
	&"adamanterz": {"name": "Adamanterz", "name_en": "Adamant Ore", "art": &"erz", "stufe": 4},
	&"sternenmetall": {"name": "Sternenmetall", "name_en": "Star Metal", "art": &"erz", "stufe": 5},
	# Schmiede — Leder
	&"lederreste": {"name": "Lederreste", "name_en": "Leather Scraps", "art": &"leder", "stufe": 1},
	&"feines_leder": {"name": "Feines Leder", "name_en": "Fine Leather", "art": &"leder", "stufe": 2},
	&"wyvernleder": {"name": "Wyvernleder", "name_en": "Wyvern Leather", "art": &"leder", "stufe": 3},
	&"drachenleder": {"name": "Drachenleder", "name_en": "Dragon Leather", "art": &"leder", "stufe": 4},
	&"urzeitleder": {"name": "Urzeitleder", "name_en": "Primeval Leather", "art": &"leder", "stufe": 5},
	# Schmiede — Kristall
	&"kristallstaub": {"name": "Kristallstaub", "name_en": "Crystal Dust", "art": &"kristall", "stufe": 1},
	&"mondkristall": {"name": "Mondkristall", "name_en": "Moon Crystal", "art": &"kristall", "stufe": 2},
	&"sternkristall": {"name": "Sternkristall", "name_en": "Star Crystal", "art": &"kristall", "stufe": 3},
	&"seelenkristall": {"name": "Seelenkristall", "name_en": "Soul Crystal", "art": &"kristall", "stufe": 4},
	&"aetherkristall": {"name": "Ätherkristall", "name_en": "Aether Crystal", "art": &"kristall", "stufe": 5},
	# Runen — seltener Boss-Drop, garantieren beim Schmieden eine Mindest-Rarität
	&"rune_selten": {"name": "Rune der Seltenheit", "name_en": "Rune of Rarity", "art": &"rune", "stufe": 1},
	&"rune_episch": {"name": "Rune der Pracht", "name_en": "Rune of Splendor", "art": &"rune", "stufe": 2},
	&"rune_legendaer": {"name": "Rune der Legenden", "name_en": "Rune of Legends", "art": &"rune", "stufe": 3},
	&"rune_regel": {"name": "Rune der Regelbrecher", "name_en": "Rule-breaker Rune", "art": &"rune", "stufe": 4},
}

## Ab dieser KARTENSTUFE droppt die Werkstoff-Stufe 1..5.
const STUFE_AB_KARTE: Array[int] = [1, 8, 18, 32, 50]
## Höchstes Item-Level, das eine Werkstoff-Stufe schmieden kann (0 = offen).
const STUFE_MAX_LEVEL: Array[int] = [12, 26, 42, 62, 0]
const STUFEN_NAMEN := [["Eisen", "Iron"], ["Stahl", "Steel"], ["Mithril", "Mithril"],
	["Adamant", "Adamant"], ["Sternen", "Star"]]
## Wahrscheinlichkeit pro Art, wie oft sie als Drop gezogen wird.
const ART_GEWICHT := {&"kraut": 10, &"erz": 3, &"leder": 2, &"kristall": 1}
## Rune » garantierte Mindest-Rarität.
const RUNEN_RARITAET := {
	&"rune_selten": Enums.Rarity.RARE,
	&"rune_episch": Enums.Rarity.EPIC,
	&"rune_legendaer": Enums.Rarity.LEGENDARY,
	&"rune_regel": Enums.Rarity.LEGENDARY,  # dazu garantiert ein Regelbrecher-Affix (Smith)
}
const RUNEN_CHANCE_BOSS := 0.25


static func display_name(id: StringName) -> String:
	if MATERIALS.has(id):
		return Loc.pick(MATERIALS[id]["name"], MATERIALS[id]["name_en"])
	return str(id)


static func art(id: StringName) -> StringName:
	return MATERIALS.get(id, {}).get("art", &"")


static func stufe(id: StringName) -> int:
	return int(MATERIALS.get(id, {}).get("stufe", 1))


static func stufen_name(s: int) -> String:
	var n: Array = STUFEN_NAMEN[clampi(s, 1, 5) - 1]
	return Loc.pick(n[0], n[1])


## Das Material einer Art in einer Stufe (erz, 3 » mithrilerz).
static func werkstoff(art_id: StringName, s: int) -> StringName:
	for id in MATERIALS:
		if MATERIALS[id]["art"] == art_id and int(MATERIALS[id]["stufe"]) == s:
			return id
	return &""


## Alle Materialien einer Art, nach Stufe sortiert.
static func ids_der_art(art_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for s in range(1, 6):
		for id in MATERIALS:
			if MATERIALS[id]["art"] == art_id and int(MATERIALS[id]["stufe"]) == s:
				result.append(id)
	return result


## Höchste Werkstoff-Stufe, die auf dieser Kartenstufe droppt.
static func stufe_fuer_karte(karten_stufe: int) -> int:
	var s := 1
	for i in STUFE_AB_KARTE.size():
		if karten_stufe >= STUFE_AB_KARTE[i]:
			s = i + 1
	return s


## Werkstoff-Stufe eines Drops: meist die der Karte, ab und zu eine
## darunter; Bosse liefern manchmal schon die nächste Stufe.
static func roll_stufe(karten_stufe: int, rng: RandomNumberGenerator, boss := false) -> int:
	var s := stufe_fuer_karte(karten_stufe)
	if s > 1 and rng.randf() < 0.25:
		s -= 1
	elif boss and s < 5 and rng.randf() < 0.2:
		s += 1
	return s


## Zufälliges Material (Kräuter oder Werkstoff passender Stufe).
static func roll(rng: RandomNumberGenerator, karten_stufe := 1, boss := false) -> StringName:
	var total := 0
	for a in ART_GEWICHT:
		total += ART_GEWICHT[a]
	var pick := rng.randi_range(1, total)
	for a in ART_GEWICHT:
		pick -= ART_GEWICHT[a]
		if pick <= 0:
			return roll_der_art(a, rng, karten_stufe, boss)
	return &"heilkraut"


## Material einer bestimmten Art (Themen-Drops: Skelett » Erz).
static func roll_der_art(art_id: StringName, rng: RandomNumberGenerator,
		karten_stufe := 1, boss := false) -> StringName:
	if art_id == &"kraut":
		var kraeuter := ids_der_art(&"kraut")
		var gesamt := 0
		for id in kraeuter:
			gesamt += int(MATERIALS[id]["weight"])
		var wurf := rng.randi_range(1, gesamt)
		for id in kraeuter:
			wurf -= int(MATERIALS[id]["weight"])
			if wurf <= 0:
				return id
		return kraeuter[0]
	return werkstoff(art_id, roll_stufe(karten_stufe, rng, boss))


## Boss-Rune (oder &"" — meistens gibt es keine): 70 % Seltenheit,
## 25 % Pracht, 5 % Legenden.
static func roll_rune(rng: RandomNumberGenerator) -> StringName:
	if rng.randf() >= RUNEN_CHANCE_BOSS:
		return &""
	var wurf := rng.randf()
	if wurf < 0.70:
		return &"rune_selten"
	if wurf < 0.93:
		return &"rune_episch"
	if wurf < 0.98:
		return &"rune_legendaer"
	return &"rune_regel"


## Materialien, die Aufträge verlangen und der Händler verkauft (Kräuter +
## Werkstoffe der Stufe 1) — edlere gibt es nur als Beute.
static func basis_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for id in MATERIALS:
		if MATERIALS[id]["art"] != &"rune" and int(MATERIALS[id]["stufe"]) == 1:
			result.append(id)
	return result
