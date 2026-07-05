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


## Element-Baustein zu einem Element (für Element-Rider auf Waffen und
## Element-Gegner — geteilte Signatur-Logik statt Duplikaten).
static func element_block(element: Enums.Element) -> ElementBlock:
	_ensure_built()
	for id in _blocks:
		var block: SkillBlock = _blocks[id]
		if block is ElementBlock and block.element == element:
			return block
	return null


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

	# --- Quellen (Waffennutzung / Zauber): Schaden kommt aus der Waffe -------
	list.append(_source(&"src_weapon", "Waffennutzung", Enums.SkillSource.WEAPON, 1.0, 1.0, 2, 1))
	list.append(_source(&"src_spell", "Zauber", Enums.SkillSource.SPELL, 1.0, 1.0, 3, 1))

	# --- Elemente (nur mit Zauber sinnvoll) ---------------------------------
	# Feuer: viele Stacks, halbieren sich pro Tick (Burst).
	list.append(_element(&"elem_fire", "Feuer", Enums.Element.FIRE, 3, 1.0, 2, 2))
	# Gift: weniger Stacks, aber permanent bis zur Heilung.
	list.append(_element(&"elem_poison", "Gift", Enums.Element.POISON, 4, 0.5, 3, 3))
	# Eis: Einfrieren (zerschmetterbar) oder Verlangsamen.
	list.append(_element(&"elem_ice", "Eis", Enums.Element.ICE, 0, 1.0, 3, 4))
	# Blitz: Kette auf ein weiteres Ziel + Betäubungs-Chance.
	list.append(_element(&"elem_lightning", "Blitz", Enums.Element.LIGHTNING, 0, 1.0, 4, 6))
	# Heilig: Bonus gegen Untote; heilt Verbündete (Form Verbündeter/Aura/Selbst).
	var holy := _element(&"elem_holy", "Heilig", Enums.Element.HOLY, 0, 1.0, 4, 1)
	_research(holy, 120)
	list.append(holy)
	# Dunkel: Lebensraub + Fluch.
	var dark := _element(&"elem_dark", "Dunkel", Enums.Element.DARK, 0, 1.0, 4, 1)
	_research(dark, 140)
	list.append(dark)

	# --- Formen (nur bei Zauber; ohne = Einzelziel) -------------------------
	list.append(_form(&"form_aoe", "Fläche", Enums.SkillForm.AOE, 1.6, 0.7, 3))
	list.append(_form(&"form_ally", "Verbündeter", Enums.SkillForm.ALLY, 1.0, 1.0, 2))
	list.append(_form(&"form_aura", "Aura", Enums.SkillForm.AURA, 1.4, 0.7, 4))
	list.append(_form(&"form_self", "Selbst", Enums.SkillForm.SELF, 0.8, 1.0, 2))
	var summon_form := _form(&"form_summon", "Beschwörung", Enums.SkillForm.SUMMON, 2.0, 1.0, 1)
	_research(summon_form, 160)
	list.append(summon_form)

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
	var revive := _effect(&"eff_revive", "Wiederbeleben", Enums.Status.REVIVE, 100, 0, 40, 12, 1)
	_research(revive, 150)
	list.append(revive)

	# --- Modifikatoren -------------------------------------------------------
	list.append(_mod(&"mod_power", "Verstärken", Enums.SkillModifier.POWER_AMP, 30, 4, 5))
	list.append(_mod(&"mod_cost", "Effizienz", Enums.SkillModifier.COST_REDUCTION, 25, 0, 6))
	list.append(_mod(&"mod_spread", "Splitter", Enums.SkillModifier.SPREAD, 30, 4, 7))
	list.append(_mod(&"mod_overload", "Überladung", Enums.SkillModifier.OVERLOAD, 40, 0, 8))
	var multi := _mod(&"mod_multi", "Mehrfachtreffer", Enums.SkillModifier.MULTI_HIT, 1, 6, 1)
	_research(multi, 150)
	list.append(multi)
	var pierce := _mod(&"mod_pierce", "Durchdringung", Enums.SkillModifier.PIERCE_ARMOR, 50, 3, 1)
	_research(pierce, 100)
	list.append(pierce)
	var execute := _mod(&"mod_execute", "Hinrichtung", Enums.SkillModifier.EXECUTE, 50, 3, 1)
	_research(execute, 120)
	list.append(execute)
	var chain := _mod(&"mod_chain", "Kettenreaktion", Enums.SkillModifier.CHAIN_ON_KILL, 2, 5, 1)
	_research(chain, 130)
	list.append(chain)

	# --- Waffentechniken (DQ-Stil) --------------------------------------------
	# Nur mit Waffennutzung UND passender Waffengattung nutzbar — dafür
	# stärker/billiger als die generischen Bausteine. Die geführte Waffe
	# bestimmt das Arsenal, wie die Waffentalente in Dragon Quest.
	list.append(_tech(_mod(&"tech_falkenschlag", "Falkenschlag",
		Enums.SkillModifier.MULTI_HIT, 1, 4, 3), [&"schwert"]))
	var klingentanz := _tech(_mod(&"tech_klingentanz", "Klingentanz",
		Enums.SkillModifier.MULTI_HIT, 2, 8, 1), [&"dolch"])
	_research(klingentanz, 220)
	list.append(klingentanz)
	list.append(_tech(_mod(&"tech_meucheln", "Meucheln",
		Enums.SkillModifier.EXECUTE, 80, 5, 6), [&"dolch"]))
	list.append(_tech(_mod(&"tech_holzfaeller", "Holzfällerschlag",
		Enums.SkillModifier.POWER_AMP, 50, 5, 4), [&"axt"]))
	list.append(_tech(_mod(&"tech_ruestungsbrecher", "Rüstungsbrecher",
		Enums.SkillModifier.PIERCE_ARMOR, 70, 5, 5), [&"stumpf"]))
	var schaedelklopfer := _tech(_effect(&"tech_schaedelklopfer", "Schädelklopfer",
		Enums.Status.STUN, 50, 1, 0, 4, 1), [&"stumpf"])
	_research(schaedelklopfer, 200)
	list.append(schaedelklopfer)
	list.append(_tech(_mod(&"tech_doppelschuss", "Doppelschuss",
		Enums.SkillModifier.MULTI_HIT, 1, 5, 4), [&"bogen"]))
	list.append(_tech(_mod(&"tech_durchschuss", "Durchschuss",
		Enums.SkillModifier.PIERCE_ARMOR, 80, 6, 5), [&"armbrust"]))
	list.append(_tech(_effect(&"tech_kniesehne", "Kniesehnenschlag",
		Enums.Status.SLOW, 70, 2, 35, 4, 5), [&"schwert", &"dolch"]))

	for block in list:
		assert(not _blocks.has(block.id), "Doppelte Baustein-ID: %s" % block.id)
		_blocks[block.id] = block


# --- Baustein-Fabriken -------------------------------------------------------

static func _source(id: StringName, name: String, source: Enums.SkillSource,
		per_point: float, power_mult: float, mp_cost: int, unlock_level: int) -> SourceBlock:
	var block := SourceBlock.new()
	block.id = id
	block.display_name = name
	block.source = source
	block.scaling_per_point = per_point
	block.power_multiplier = power_mult
	block.mp_cost = mp_cost
	block.unlock_level = unlock_level
	return block


static func _element(id: StringName, name: String, element: Enums.Element,
		dot_turns: int, status_scale: float, mp_cost: int, unlock_level: int) -> ElementBlock:
	var block := ElementBlock.new()
	block.id = id
	block.display_name = name
	block.element = element
	block.dot_turns = dot_turns
	block.status_scale = status_scale
	block.mp_cost = mp_cost
	block.unlock_level = unlock_level
	return block


static func _form(id: StringName, name: String, form: Enums.SkillForm,
		cost_mult: float, power_mult: float, unlock_level: int) -> FormBlock:
	var block := FormBlock.new()
	block.id = id
	block.display_name = name
	block.form = form
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


static func _tech(block: SkillBlock, families: Array[StringName]) -> SkillBlock:
	block.weapon_families = families
	return block


## Anzeigenamen der Waffengattungen (ItemBase.family) für Technik-Hinweise.
const FAMILY_NAMES := {
	&"schwert": ["Schwert", "Sword"], &"dolch": ["Dolch", "Dagger"],
	&"axt": ["Axt", "Axe"], &"stumpf": ["Knüppel/Hammer", "Club/hammer"],
	&"bogen": ["Bogen", "Bow"], &"armbrust": ["Armbrust", "Crossbow"],
	&"stab": ["Stab", "Staff"],
}


static func family_label(family: StringName) -> String:
	if FAMILY_NAMES.has(family):
		return Loc.pick(FAMILY_NAMES[family][0], FAMILY_NAMES[family][1])
	return String(family)


## "Nur mit: Schwert/Dolch" — für Werkstatt-Beschreibungen und Kampf-Tooltips.
static func families_label(families: Array[StringName]) -> String:
	var parts: Array[String] = []
	for family in families:
		parts.append(family_label(family))
	return "/".join(parts)
