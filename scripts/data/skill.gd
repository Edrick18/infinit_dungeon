class_name Skill
extends Resource
## Ein vom Spieler zusammengebauter Skill: genau ein Träger-Baustein plus
## beliebige Schadens-, Effekt- und Modifikator-Bausteine.
## Wird im Sockel-UI (Drag&Drop) zusammengesteckt und in einen der
## Skill-Slots des Charakters gelegt (+1 Slot alle 5 Level, kein Cap).

@export var display_name: String = "Neuer Skill"
@export var blocks: Array[SkillBlock] = []


func get_carrier() -> CarrierBlock:
	for block in blocks:
		if block is CarrierBlock:
			return block
	return null


func get_damage_blocks() -> Array[DamageBlock]:
	var result: Array[DamageBlock] = []
	for block in blocks:
		if block is DamageBlock:
			result.append(block)
	return result


func get_effect_blocks() -> Array[EffectBlock]:
	var result: Array[EffectBlock] = []
	for block in blocks:
		if block is EffectBlock:
			result.append(block)
	return result


func get_modifier_blocks() -> Array[ModifierBlock]:
	var result: Array[ModifierBlock] = []
	for block in blocks:
		if block is ModifierBlock:
			result.append(block)
	return result


## Ein Skill ist gültig, wenn er genau einen Träger hat und mindestens
## einen Baustein, der etwas bewirkt (Schaden oder Effekt).
func is_valid() -> bool:
	var carriers := 0
	for block in blocks:
		if block is CarrierBlock:
			carriers += 1
	if carriers != 1:
		return false
	return not get_damage_blocks().is_empty() or not get_effect_blocks().is_empty()


## MP-Kosten: Summe aller Baustein-Kosten, skaliert mit dem Kostenfaktor
## des Trägers, reduziert durch COST_REDUCTION-Modifikatoren.
func get_mp_cost() -> int:
	var carrier := get_carrier()
	if carrier == null:
		return 0
	var base := 0
	for block in blocks:
		if block != carrier:
			base += block.mp_cost
	var cost := base * carrier.cost_multiplier + carrier.mp_cost
	for mod in get_modifier_blocks():
		if mod.modifier == Enums.SkillModifier.COST_REDUCTION:
			cost *= 1.0 - mod.magnitude / 100.0
	return maxi(1, roundi(cost))
