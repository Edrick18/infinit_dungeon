class_name Smith
extends RefCounted
## Schmiede-Logik (Lutz 2026-10-14): Man wählt nur, WAS FÜR EINE ART Gegenstand
## (Kategorie-Reiter), aus welcher WERKSTOFF-STUFE und auf welchem ITEM-LEVEL
## geschmiedet wird — welche Basis, welche Rarität und welche Affixe
## herauskommen, ist Zufall.
## - Höheres Level = mehr Gold (eine Stufe niedriger schmieden spart Gold).
## - Edlere Werkstoffe erlauben höhere Level und erhöhen die CHANCE auf
##   bessere Rarität, garantieren sie aber nicht.
## - Eine Rune (seltener Boss-Drop) garantiert eine Mindest-Rarität.
## Dazu: Affixe eines Items neu würfeln (Material-/Gold-Sink fürs Endgame).

## Pro Werkstoff-Stufe über 1: so wahrscheinlich steigt die Rarität um eins.
const RARITAET_BONUS_JE_STUFE := 0.3
## So weit über das höchste Helden-Level hinaus darf man schmieden.
const LEVEL_UEBER_PARTY := 3

## Reiter der Schmiede: Basis-Pool + Rezept (Material-Arten × Anzahl).
const KATEGORIEN := [
	{"id": &"nahkampf", "name": "Nahkampf", "name_en": "Melee",
		"bases": [&"schwert", &"zweihandschwert", &"dolch", &"axt", &"zweihandaxt",
			&"knueppel", &"kriegshammer"],
		"rezept": {&"erz": 3, &"leder": 1}},
	{"id": &"fernkampf", "name": "Fernkampf", "name_en": "Ranged",
		"bases": [&"bogen", &"armbrust"],
		"rezept": {&"leder": 2, &"erz": 1}},
	{"id": &"staebe", "name": "Stäbe", "name_en": "Staves",
		"bases": [&"offensivstab", &"heiligstab"],
		"rezept": {&"kristall": 2, &"leder": 1}},
	{"id": &"nebenhand", "name": "Nebenhand", "name_en": "Off-hand",
		"bases": [&"schild", &"turmschild", &"zauberbuch", &"kristallfokus",
			&"relikt", &"heiligkreuz", &"koecher"],
		"rezept": {&"erz": 1, &"leder": 1, &"kristall": 1}},
	{"id": &"ruestung", "name": "Rüstung", "name_en": "Armor",
		"bases": [&"ruestung_leicht", &"ruestung_mittel", &"ruestung_schwer",
			&"robe_schaden", &"robe_heil", &"robe_kampf",
			&"helm_leicht", &"helm_schwer", &"handschuhe_leicht", &"handschuhe_schwer",
			&"stiefel_leicht", &"stiefel_schwer"],
		"rezept": {&"leder": 2, &"erz": 2}},
	{"id": &"schmuck", "name": "Schmuck", "name_en": "Jewelry",
		"bases": [&"ring", &"amulett"],
		"rezept": {&"kristall": 2, &"erz": 1}},
]


static func kategorie(id: StringName) -> Dictionary:
	for k in KATEGORIEN:
		if k["id"] == id:
			return k
	return {}


static func kategorie_name(k: Dictionary) -> String:
	return Loc.pick(k["name"], k["name_en"])


## Höchstes schmiedbares Level: Grenze der Werkstoff-Stufe und höchstes
## Helden-Level + LEVEL_UEBER_PARTY.
static func max_level(stufe: int, party_max_level: int) -> int:
	var grenze: int = MaterialLibrary.STUFE_MAX_LEVEL[clampi(stufe, 1, 5) - 1]
	var party := party_max_level + LEVEL_UEBER_PARTY
	return party if grenze <= 0 else mini(grenze, party)


## Basen der Kategorie, die auf diesem Level schon existieren.
static func moegliche_basen(kategorie_id: StringName, level: int) -> Array[ItemBase]:
	var result: Array[ItemBase] = []
	for base_id in kategorie(kategorie_id).get("bases", []):
		var base := ItemLibrary.get_base(base_id)
		if base != null and base.min_tier <= level:
			result.append(base)
	return result


## Kosten: Gold wächst mit dem Item-Level (Welt-Kurve), Materialien nach
## Rezept in der gewählten Werkstoff-Stufe.
static func kosten(kategorie_id: StringName, stufe: int, level: int) -> Dictionary:
	var materials := {}
	var rezept: Dictionary = kategorie(kategorie_id).get("rezept", {})
	for art in rezept:
		materials[MaterialLibrary.werkstoff(art, stufe)] = rezept[art]
	return {"gold": roundi((25 + level * 10) * Scaling.factor(level)), "materials": materials}


## Schmiedet einen zufälligen Gegenstand der Kategorie. `rune` (oder &"")
## garantiert eine Mindest-Rarität. Kosten zieht der Aufrufer ab.
static func schmieden(kategorie_id: StringName, stufe: int, level: int,
		rune: StringName, rng: RandomNumberGenerator) -> ItemInstance:
	var basen := moegliche_basen(kategorie_id, level)
	if basen.is_empty():
		return null
	var item := ItemInstance.new()
	item.base = basen[rng.randi_range(0, basen.size() - 1)]
	item.item_level = level
	item.rarity = roll_raritaet(stufe, rune, rng)
	LootGenerator.apply_random_affixes(item, rng)
	if rune == &"rune_regel":
		LootGenerator.regelbruch_hinzufuegen(item, rng)
	return item


## Rarität: normaler Wurf, mindestens Magisch (keine grauen Schmiedestücke),
## je Werkstoff-Stufe über 1 eine Chance auf eine Stufe mehr, Rune als Boden.
static func roll_raritaet(stufe: int, rune: StringName, rng: RandomNumberGenerator) -> Enums.Rarity:
	var r := int(LootGenerator.roll_rarity(rng))
	r = maxi(r, int(Enums.Rarity.MAGIC))
	for i in clampi(stufe, 1, 5) - 1:
		if rng.randf() < RARITAET_BONUS_JE_STUFE:
			r += 1
	if MaterialLibrary.RUNEN_RARITAET.has(rune):
		r = maxi(r, int(MaterialLibrary.RUNEN_RARITAET[rune]))
	return mini(r, int(Enums.Rarity.LEGENDARY)) as Enums.Rarity


## Ungefähre Chancen je Rarität (für die Anzeige) — ausgewürfelt mit festem
## Seed, damit die Zahlen nicht flackern.
static func raritaets_chancen(stufe: int, rune: StringName) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var zaehler := {}
	const WUERFE := 4000
	for i in WUERFE:
		var r := roll_raritaet(stufe, rune, rng)
		zaehler[r] = int(zaehler.get(r, 0)) + 1
	var result := {}
	for r in zaehler:
		result[r] = float(zaehler[r]) / WUERFE
	return result


## Werkstoff-Stufe, die zu einem Item-Level passt (fürs Neuwürfeln).
static func stufe_fuer_level(level: int) -> int:
	for i in MaterialLibrary.STUFE_MAX_LEVEL.size():
		var grenze: int = MaterialLibrary.STUFE_MAX_LEVEL[i]
		if grenze <= 0 or level <= grenze:
			return i + 1
	return 5


## Kosten fürs Neuwürfeln: Gold nach Item-Level + ein Kristall passender Stufe.
static func reroll_cost(item: ItemInstance) -> Dictionary:
	return {
		"gold": roundi((15 + item.item_level * 5) * Scaling.factor(item.item_level)),
		"materials": {MaterialLibrary.werkstoff(&"kristall", stufe_fuer_level(item.item_level)): 1},
	}


## Würfelt die Affixe eines Items neu — Basis, Level und Rarity bleiben.
## Auch die Qualitäts-Rolls werden neu gewürfelt (der eigentliche Jackpot).
static func reroll(item: ItemInstance, rng: RandomNumberGenerator) -> void:
	var empty: Array[Affix] = []
	var empty_rolls: Array[float] = []
	item.affixes = empty
	item.affix_rolls = empty_rolls
	LootGenerator.apply_random_affixes(item, rng)
