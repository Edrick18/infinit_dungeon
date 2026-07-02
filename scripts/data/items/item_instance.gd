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
const LEVEL_SCALE := 0.06


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
