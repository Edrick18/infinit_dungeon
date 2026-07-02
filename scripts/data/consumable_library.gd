class_name ConsumableLibrary
extends RefCounted
## Katalog aller Verbrauchsgegenstände + gewichteter Drop-Roll.

static var _defs: Dictionary = {}


static func get_def(id: StringName) -> ConsumableDef:
	_ensure_built()
	return _defs.get(id)


static func all_defs() -> Array[ConsumableDef]:
	_ensure_built()
	var result: Array[ConsumableDef] = []
	for id in _defs:
		result.append(_defs[id])
	return result


## Gewichteter Zufalls-Drop, begrenzt auf die Kartenstufe.
static func roll(tier: int, rng: RandomNumberGenerator) -> ConsumableDef:
	var eligible: Array[ConsumableDef] = []
	var total_weight := 0
	for def in all_defs():
		if def.min_tier <= tier:
			eligible.append(def)
			total_weight += def.drop_weight
	if eligible.is_empty():
		return null
	var pick := rng.randi_range(1, total_weight)
	for def in eligible:
		pick -= def.drop_weight
		if pick <= 0:
			return def
	return eligible[0]


static func _ensure_built() -> void:
	if not _defs.is_empty():
		return
	_def(&"heiltrank", "Heiltrank", "Stellt 30 HP wieder her.",
		Enums.ConsumableEffect.HEAL_HP, 30, 1, 5)
	_def(&"grosser_heiltrank", "Großer Heiltrank", "Stellt 80 HP wieder her.",
		Enums.ConsumableEffect.HEAL_HP, 80, 3, 2)
	_def(&"manatrank", "Manatrank", "Stellt 20 MP wieder her.",
		Enums.ConsumableEffect.RESTORE_MP, 20, 1, 4)
	_def(&"grosser_manatrank", "Großer Manatrank", "Stellt 50 MP wieder her.",
		Enums.ConsumableEffect.RESTORE_MP, 50, 3, 2)
	_def(&"gegenmittel", "Gegenmittel", "Entfernt Brand, Gift, Betäubung und andere Leiden.",
		Enums.ConsumableEffect.CURE_AILMENTS, 0, 1, 3)
	_def(&"belebungselixier", "Belebungselixier", "Belebt einen Gefallenen mit 50% HP.",
		Enums.ConsumableEffect.REVIVE, 50, 2, 1)


static func _def(id: StringName, name: String, description: String,
		effect: Enums.ConsumableEffect, potency: int, min_tier: int, weight: int) -> void:
	var def := ConsumableDef.new()
	def.id = id
	def.display_name = name
	def.description = description
	def.effect = effect
	def.potency = potency
	def.min_tier = min_tier
	def.drop_weight = weight
	_defs[id] = def
