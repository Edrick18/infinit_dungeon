class_name BlockLibrary
extends RefCounted
## Katalog aller craftbaren Skill-Bausteine mit Freischaltbedingungen.
## Basis-Bausteine kommen über Charakter-Level, spezielle über Forschung (Gold).
## Vorerst im Code definiert; später können die Bausteine als .tres-Dateien
## in data/ liegen und hier nur noch geladen werden.

static var _blocks: Dictionary = {}


static func all_blocks() -> Array[SkillBlock]:
	_ensure_built()
	var result: Array[SkillBlock] = []
	for id in _blocks:
		result.append(_blocks[id])
	return result


static func get_block(id: StringName) -> SkillBlock:
	_ensure_built()
	return _blocks.get(id)


## Freischalt-Check als reine Funktion (testbar ohne Autoload):
## LEVEL-Bausteine ab Charakter-Level, RESEARCH-Bausteine wenn erforscht.
static func is_unlocked(block: SkillBlock, char_level: int, researched: Array) -> bool:
	if block.unlock_kind == Enums.UnlockKind.LEVEL:
		return char_level >= block.unlock_level
	return block.id in researched


static func _ensure_built() -> void:
	if not _blocks.is_empty():
		return
	var list: Array[SkillBlock] = []

	# --- Schaden: physisch (mit Schadensart Stich/Schnitt/Stumpf) -----------
	var schnitt := _dmg(&"dmg_schnitt", "Schnitt", Enums.DamageAxis.PHYSICAL,
		6, &"strength", 1.0, 2, 1)
	schnitt.physical_subtype = Enums.PhysicalSubtype.SLASH
	list.append(schnitt)
	var stich := _dmg(&"dmg_stich", "Stich", Enums.DamageAxis.PHYSICAL,
		6, &"strength", 1.0, 2, 1)
	stich.physical_subtype = Enums.PhysicalSubtype.PIERCE
	list.append(stich)
	var wucht := _dmg(&"dmg_wucht", "Wuchtschlag", Enums.DamageAxis.PHYSICAL,
		10, &"strength", 1.5, 4, 4)
	wucht.physical_subtype = Enums.PhysicalSubtype.BLUNT
	list.append(wucht)

	# --- Schaden: magisch (raw) --------------------------------------------
	list.append(_dmg(&"dmg_arkan", "Arkanschlag", Enums.DamageAxis.MAGICAL,
		8, &"intelligence", 1.0, 3, 1))
	list.append(_dmg(&"dmg_feuerstoss", "Feuerstoß", Enums.DamageAxis.MAGICAL,
		12, &"intelligence", 1.2, 5, 3))
	var holy := _dmg(&"dmg_heilig", "Heiliges Licht", Enums.DamageAxis.MAGICAL,
		16, &"intelligence", 1.4, 7, 1)
	_research(holy, 120)
	list.append(holy)

	# --- Schaden: elementar (DoT) ------------------------------------------
	var burn := _dmg(&"dmg_brand", "Brand", Enums.DamageAxis.ELEMENTAL,
		9, &"intelligence", 0.5, 3, 2)
	burn.element = Enums.Element.FIRE
	burn.dot_turns = 3
	list.append(burn)
	var poison := _dmg(&"dmg_gift", "Gift", Enums.DamageAxis.ELEMENTAL,
		12, &"spirit", 1.0, 4, 3)
	poison.element = Enums.Element.POISON
	poison.dot_turns = 4
	list.append(poison)

	# --- Träger -------------------------------------------------------------
	list.append(_carrier(&"car_melee", "Nahkampf", Enums.Carrier.MELEE, 1.0, 1.2, 1))
	list.append(_carrier(&"car_projectile", "Projektil", Enums.Carrier.PROJECTILE, 1.0, 1.0, 1))
	list.append(_carrier(&"car_self", "Selbst", Enums.Carrier.SELF, 0.8, 1.0, 2))
	list.append(_carrier(&"car_aoe", "Fläche", Enums.Carrier.AOE, 1.6, 0.7, 3))
	list.append(_carrier(&"car_aura", "Aura", Enums.Carrier.AURA, 1.0, 1.0, 4))

	# --- Effekte: Debuffs/Angriff ---------------------------------------------
	list.append(_effect(&"eff_weaken", "Schwächen", Enums.Status.WEAKEN, 80, 2, 25, 3, 2))
	list.append(_effect(&"eff_slow", "Verlangsamen", Enums.Status.SLOW, 80, 2, 30, 3, 3))
	var stun := _effect(&"eff_stun", "Betäuben", Enums.Status.STUN, 60, 1, 0, 6, 1)
	_research(stun, 80)
	list.append(stun)
	var lifesteal := _effect(&"eff_lifesteal", "Lebensraub", Enums.Status.LIFESTEAL, 100, 0, 30, 5, 1)
	_research(lifesteal, 100)
	list.append(lifesteal)

	# --- Effekte: Support (Team schützen und buffen) ---------------------------
	list.append(_effect(&"eff_regen", "Regeneration", Enums.Status.REGEN, 100, 3, 8, 6, 4))
	list.append(_effect(&"eff_def_up", "Wappnen", Enums.Status.DEF_UP, 100, 3, 5, 4, 2))
	list.append(_effect(&"eff_atk_up", "Stärken", Enums.Status.ATK_UP, 100, 3, 25, 5, 4))
	list.append(_effect(&"eff_mana_regen", "Mana-Fluss", Enums.Status.MANA_REGEN, 100, 3, 6, 5, 6))
	var shield := _effect(&"eff_shield", "Schild", Enums.Status.SHIELD, 100, 3, 10, 4, 1)
	_research(shield, 60)
	list.append(shield)
	var cleanse := _effect(&"eff_cleanse", "Reinigen", Enums.Status.CLEANSE, 100, 0, 0, 5, 1)
	_research(cleanse, 70)
	list.append(cleanse)
	var protect := _effect(&"eff_protect", "Schutzwall", Enums.Status.PROTECT, 100, 2, 0, 6, 1)
	_research(protect, 90)
	list.append(protect)

	# --- Modifikatoren -------------------------------------------------------
	list.append(_mod(&"mod_power", "Verstärken", Enums.SkillModifier.POWER_AMP, 30, 4, 5))
	list.append(_mod(&"mod_cost", "Effizienz", Enums.SkillModifier.COST_REDUCTION, 25, 0, 6))
	var multi := _mod(&"mod_multi", "Mehrfachtreffer", Enums.SkillModifier.MULTI_HIT, 1, 6, 1)
	_research(multi, 150)
	list.append(multi)

	for block in list:
		assert(not _blocks.has(block.id), "Doppelte Baustein-ID: %s" % block.id)
		_blocks[block.id] = block


# --- Baustein-Fabriken -------------------------------------------------------

static func _dmg(id: StringName, name: String, axis: Enums.DamageAxis, base_amount: int,
		stat: StringName, per_point: float, mp_cost: int, unlock_level: int) -> DamageBlock:
	var block := DamageBlock.new()
	block.id = id
	block.display_name = name
	block.axis = axis
	block.base_amount = base_amount
	block.scaling_stat = stat
	block.scaling_per_point = per_point
	block.mp_cost = mp_cost
	block.unlock_level = unlock_level
	return block


static func _carrier(id: StringName, name: String, kind: Enums.Carrier,
		cost_mult: float, power_mult: float, unlock_level: int) -> CarrierBlock:
	var block := CarrierBlock.new()
	block.id = id
	block.display_name = name
	block.carrier = kind
	block.cost_multiplier = cost_mult
	block.power_multiplier = power_mult
	block.unlock_level = unlock_level
	return block


static func _effect(id: StringName, name: String, status: Enums.Status, chance: int,
		turns: int, potency: int, mp_cost: int, unlock_level: int) -> EffectBlock:
	var block := EffectBlock.new()
	block.id = id
	block.display_name = name
	block.status = status
	block.chance_percent = chance
	block.duration_turns = turns
	block.potency = potency
	block.mp_cost = mp_cost
	block.unlock_level = unlock_level
	return block


static func _mod(id: StringName, name: String, kind: Enums.SkillModifier,
		magnitude: int, mp_cost: int, unlock_level: int) -> ModifierBlock:
	var block := ModifierBlock.new()
	block.id = id
	block.display_name = name
	block.modifier = kind
	block.magnitude = magnitude
	block.mp_cost = mp_cost
	block.unlock_level = unlock_level
	return block


static func _research(block: SkillBlock, gold_cost: int) -> void:
	block.unlock_kind = Enums.UnlockKind.RESEARCH
	block.research_cost_gold = gold_cost
