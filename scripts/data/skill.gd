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


## Anteil des Skalierungs-Stats, der in die MP-Kosten von Schadensbausteinen
## fließt: Skills werden mit den Stats stärker UND teurer — dadurch bleiben
## MP-Kosten auf jedem Level relevant (kein Level-Cap!).
const STAT_COST_SCALE := 0.25


## MP-Kosten: Summe aller Baustein-Kosten, skaliert mit dem Kostenfaktor
## des Trägers, reduziert durch COST_REDUCTION-Modifikatoren.
## Mit user berechnen sich Schadensbausteine dynamisch: Basis + 25% des
## Attributwerts, mit dem sie skalieren.
func get_mp_cost(user: Combatant = null) -> int:
	var carrier := get_carrier()
	if carrier == null:
		return 0
	var base := 0.0
	for block in blocks:
		if block == carrier:
			continue
		base += block.mp_cost
		if user != null and block is DamageBlock:
			base += user.stat(block.scaling_stat) * block.scaling_per_point * STAT_COST_SCALE
	var cost := base * carrier.cost_multiplier + carrier.mp_cost
	for mod in get_modifier_blocks():
		if mod.modifier == Enums.SkillModifier.COST_REDUCTION:
			cost *= 1.0 - mod.magnitude / 100.0
	return maxi(1, roundi(cost))


## Bausteine sind kanonische, geteilte Objekte aus der BlockLibrary (jeder
## mit eindeutiger ID) — für den Spielstand reicht es, ihre IDs zu speichern.
func to_dict() -> Dictionary:
	var block_ids: Array = []
	for block in blocks:
		block_ids.append(String(block.id))
	return {"name": display_name, "block_ids": block_ids}


static func from_dict(data: Dictionary) -> Skill:
	var skill := Skill.new()
	skill.display_name = data.get("name", "")
	for id_str in data.get("block_ids", []):
		var block := BlockLibrary.get_block(StringName(id_str))
		if block != null:
			skill.blocks.append(block)
	return skill
