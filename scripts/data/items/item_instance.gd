class_name ItemInstance
extends Resource
## Ein konkret gedropptes/generiertes Item: Basis-Item + zufällige Affixe.
## Das ist, was im Inventar liegt und ausgerüstet wird.

@export var base: ItemBase
@export var affixes: Array[Affix] = []
## Pro Affix gewürfelte Qualität (1,0–1,6): derselbe Affix fällt mal schwach,
## mal stark aus — "+3 Schaden" wird so zu "+3 bis +5". Parallel zu affixes.
@export var affix_rolls: Array[float] = []
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var item_level: int = 1  ## Kartenstufe, auf der das Item gedroppt ist


## Qualitäts-Roll eines Affixes (1,0 wenn keiner gespeichert — alte Saves).
func affix_roll(index: int) -> float:
	return affix_rolls[index] if index < affix_rolls.size() else 1.0


## Effektiver Wert eines Affix-Grundwerts nach dem Qualitäts-Roll.
func affix_value(index: int, base_value: int) -> int:
	if base_value == 0:
		return 0
	return roundi(base_value * affix_roll(index))


## Genus der Basis-Items (fehlt = Neutrum): Präfixe sind in der Neutrum-Form
## hinterlegt („Flammendes“) und werden ohne Artikel stark dekliniert —
## „Flammender Heiligstab“, „Grausame Panzerstiefel“, „Robuste Axt“.
const GENUS := {
	&"dolch": "m", &"knueppel": "m", &"kriegshammer": "m", &"bogen": "m",
	&"offensivstab": "m", &"heiligstab": "m", &"schild": "m", &"turmschild": "m",
	&"kristallfokus": "m", &"koecher": "m", &"helm_leicht": "m", &"helm_schwer": "m",
	&"axt": "f", &"zweihandaxt": "f", &"armbrust": "f", &"ruestung_leicht": "f",
	&"ruestung_mittel": "f", &"ruestung_schwer": "f", &"robe_schaden": "f",
	&"robe_heil": "f", &"robe_kampf": "f",
	&"handschuhe_leicht": "pl", &"handschuhe_schwer": "pl",
	&"stiefel_leicht": "pl", &"stiefel_schwer": "pl",
}
const ENDUNG := {"m": "er", "f": "e", "n": "es", "pl": "e"}


## Präfix passend zum Genus des Basis-Items (nur Deutsch).
static func praefix_fuer(name_part: String, basis: ItemBase) -> String:
	if Loc.language != "de" or not name_part.ends_with("es"):
		return name_part
	var genus: String = GENUS.get(basis.id, "n")
	return name_part.left(name_part.length() - 2) + ENDUNG[genus]


## "Flammendes Kurzschwert des Sturms" — Prefix + Basisname + Suffix.
func get_display_name() -> String:
	var prefix := ""
	var suffix := ""
	for affix in affixes:
		if affix.is_prefix and prefix.is_empty():
			prefix = praefix_fuer(affix.name_part, base) + " "
		elif not affix.is_prefix and suffix.is_empty():
			suffix = " " + affix.name_part
	var basis_name := base.display_name
	# Zweites Adjektiv klein: „Flinke schwere Rüstung“, „Robuster leichter Helm“.
	if not prefix.is_empty() and Loc.language == "de" and basis_name.contains(" "):
		basis_name = basis_name.left(1).to_lower() + basis_name.substr(1)
	return prefix + basis_name + suffix


## Kampfwerte wachsen mit dem Item-Level (= Kartenstufe des Drops):
## Da es kein Level-/Karten-Cap gibt, muss auch Gear endlos skalieren —
## ein Tier-12-Schwert schlägt ein Tier-1-Schwert deutlich. Seit dem
## Ein-Basis-Katalog trägt allein diese Skalierung das Gear-Wachstum.
const LEVEL_SCALE := 0.13


func _level_mult() -> float:
	# Linear (Feinschliff zwischen Nachbarstufen) × exponentiell (Scaling:
	# dieselbe Kurve wie Gegner und Gold — die Welt wächst im Gleichschritt).
	return (1.0 + LEVEL_SCALE * (item_level - 1)) * Scaling.factor(item_level)


func get_total_damage() -> int:
	var total := base.base_damage
	for i in affixes.size():
		total += affix_value(i, affixes[i].bonus_damage)
	return roundi(total * _level_mult())


## Zauberkraft skaliert genauso endlos wie Waffenschaden — sonst fallen
## Caster auf hohen Kartenstufen hinter Waffenträger zurück.
func get_total_spell_damage() -> int:
	var total := base.spell_damage
	for i in affixes.size():
		total += affix_value(i, affixes[i].bonus_spell_damage)
	if total == 0:
		return 0
	return roundi(total * _level_mult())


func get_total_armor() -> int:
	var total := base.base_armor
	for i in affixes.size():
		total += affix_value(i, affixes[i].bonus_armor)
	return roundi(total * _level_mult())


## Element-Rider dieser Waffe: Element » Zusatzschaden pro Waffennutzungs-Treffer.
func get_element_riders() -> Dictionary:
	var riders := {}
	for i in affixes.size():
		var affix := affixes[i]
		if affix.element_damage > 0 and affix.element != Enums.Element.NONE:
			riders[affix.element] = riders.get(affix.element, 0) \
				+ roundi(affix_value(i, affix.element_damage) * _level_mult())
	return riders


## Resistenz gegen ein Element in PROZENT (Affixe mit element == NONE zählen
## gegen alle Elemente) — bleibt auf jeder Stufe gleich viel wert.
func get_element_resist(element: Enums.Element) -> int:
	var total := 0
	for i in affixes.size():
		var affix := affixes[i]
		if affix.element_resist > 0 \
				and (affix.element == element or affix.element == Enums.Element.NONE):
			total += affix_value(i, affix.element_resist)
	return total


## MP-Kosten-Ersparnis in PROZENT.
func get_mp_cost_reduction() -> int:
	var total := 0
	for i in affixes.size():
		total += affix_value(i, affixes[i].mp_cost_reduction)
	return total


## Summe aller Attribut-Boni (Basis-Item + Affixe, Affixe mit Qualitäts-Roll).
func get_total_stat_bonus() -> StatBlock:
	var total := StatBlock.new()
	if base.stat_bonus != null:
		if base.stat_skaliert:
			var faktor := 1.0 + LEVEL_SCALE * (item_level - 1)
			for stat in StatBlock.STAT_NAMES:
				total.set(stat, total.get(stat) + roundi(base.stat_bonus.get(stat) * faktor))
		else:
			total.add(base.stat_bonus)
	for i in affixes.size():
		var bonus: StatBlock = affixes[i].stat_bonus
		if bonus != null:
			for stat in StatBlock.STAT_NAMES:
				total.set(stat, total.get(stat) + affix_value(i, bonus.get(stat)))
	return total


## Basis-Item und Affixe sind kanonische, geteilte Objekte aus der
## ItemLibrary — für den Spielstand reicht es, ihre IDs zu speichern.
func to_dict() -> Dictionary:
	var affix_ids: Array = []
	for affix in affixes:
		affix_ids.append(String(affix.id))
	var rolls: Array = []
	for i in affixes.size():
		rolls.append(affix_roll(i))
	return {
		"base_id": String(base.id),
		"affix_ids": affix_ids,
		"affix_rolls": rolls,
		"rarity": rarity,
		"item_level": item_level,
	}


## null, falls das Basis-Item nicht mehr existiert (z.B. Save von älterer Version).
static func from_dict(data: Dictionary) -> ItemInstance:
	var base := ItemLibrary.get_base(StringName(data.get("base_id", "")))
	if base == null:
		return null
	var item := ItemInstance.new()
	item.base = base
	var rolls: Array = data.get("affix_rolls", [])
	var index := 0
	for id_str in data.get("affix_ids", []):
		var affix := ItemLibrary.get_affix(StringName(id_str))
		if affix != null:
			item.affixes.append(affix)
			# Roll gehört zum Affix gleicher Position; alte Saves: Basiswert.
			item.affix_rolls.append(float(rolls[index]) if index < rolls.size() else 1.0)
		index += 1
	item.rarity = int(data.get("rarity", Enums.Rarity.COMMON))
	item.item_level = int(data.get("item_level", 1))
	return item
