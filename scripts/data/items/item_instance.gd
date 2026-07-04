class_name ItemInstance
extends Resource
## Ein konkret gedropptes/generiertes Item: Basis-Item + zufällige Affixe.
## Das ist, was im Inventar liegt und ausgerüstet wird.

@export var base: ItemBase
@export var affixes: Array[Affix] = []
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON
@export var item_level: int = 1  ## Kartenstufe, auf der das Item gedroppt ist


## "Flammendes Kurzschwert des Sturms" — Prefix + Basisname + Suffix.
func get_display_name() -> String:
	var prefix := ""
	var suffix := ""
	for affix in affixes:
		if affix.is_prefix and prefix.is_empty():
			prefix = affix.name_part + " "
		elif not affix.is_prefix and suffix.is_empty():
			suffix = " " + affix.name_part
	return prefix + base.display_name + suffix


## Kampfwerte wachsen mit dem Item-Level (= Kartenstufe des Drops):
## Da es kein Level-/Karten-Cap gibt, muss auch Gear endlos skalieren —
## ein Tier-12-Kurzschwert schlägt ein Tier-1-Kurzschwert deutlich.
const LEVEL_SCALE := 0.10


func get_total_damage() -> int:
	var total := base.base_damage
	for affix in affixes:
		total += affix.bonus_damage
	return roundi(total * (1.0 + LEVEL_SCALE * (item_level - 1)))


func get_total_armor() -> int:
	var total := base.base_armor
	for affix in affixes:
		total += affix.bonus_armor
	return roundi(total * (1.0 + LEVEL_SCALE * (item_level - 1)))


## Summe aller Attribut-Boni (Basis-Item + Affixe).
func get_total_stat_bonus() -> StatBlock:
	var total := StatBlock.new()
	if base.stat_bonus != null:
		total.add(base.stat_bonus)
	for affix in affixes:
		if affix.stat_bonus != null:
			total.add(affix.stat_bonus)
	return total


## Basis-Item und Affixe sind kanonische, geteilte Objekte aus der
## ItemLibrary — für den Spielstand reicht es, ihre IDs zu speichern.
func to_dict() -> Dictionary:
	var affix_ids: Array = []
	for affix in affixes:
		affix_ids.append(String(affix.id))
	return {
		"base_id": String(base.id),
		"affix_ids": affix_ids,
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
	for id_str in data.get("affix_ids", []):
		var affix := ItemLibrary.get_affix(StringName(id_str))
		if affix != null:
			item.affixes.append(affix)
	item.rarity = int(data.get("rarity", Enums.Rarity.COMMON))
	item.item_level = int(data.get("item_level", 1))
	return item
