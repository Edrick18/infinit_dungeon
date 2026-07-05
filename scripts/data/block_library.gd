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
static func is_unlocked(block: SkillBlock, char_level: int, researched: Array,
		hero: Combatant = null) -> bool:
	match block.unlock_kind:
		Enums.UnlockKind.LEVEL:
			return char_level >= block.unlock_level
		Enums.UnlockKind.TRAINING:
			# Altbestand: früher erforschte Bausteine (z.B. Schutzwall)
			# bleiben freigeschaltet, auch ohne Trainings-Punkte.
			if block.id in researched:
				return true
			return hero != null and hero.invested(block.tree_family) >= block.tree_points
		_:
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
	# Schutzwall wohnt jetzt im SCHILD-Baum (Training 18) — wer ihn früher
	# erforscht hat, behält ihn (is_unlocked prüft auch researched).
	var protect := _tech(_effect(&"eff_protect", "Schutzwall",
		Enums.Status.PROTECT, 100, 2, 0, 6, 1), &"schild", 18)
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

	# --- Waffentechniken: 8 Trainings-Bäume (DQ9-Waffentalente) ----------------
	# Freischaltung über investierte SKILLPUNKTE in der Gattung (Schwellen
	# 4/10/18/28); nutzbar nur mit passender geführter Waffe (Schild zählt
	# über die Nebenhand, Stab-Techniken verstärken Zauber). Dafür stärker/
	# billiger als die generischen Bausteine — die Waffe bestimmt das Arsenal.

	# Schwert: der Allrounder — Extraschlag, Kontrolle, Untotenschreck.
	list.append(_tech(_mod(&"tech_falkenschlag", "Falkenschlag",
		Enums.SkillModifier.MULTI_HIT, 1, 4, 1), &"schwert", 4))
	list.append(_tech(_effect(&"tech_kniesehne", "Kniesehnenschlag",
		Enums.Status.SLOW, 70, 2, 35, 4, 1), &"schwert", 10))
	list.append(_tech(_mod(&"tech_schwertmeister", "Schwertmeisterhieb",
		Enums.SkillModifier.POWER_AMP, 60, 6, 1), &"schwert", 18))
	list.append(_tech(_mod(&"tech_heiligenklinge", "Heiligenklinge",
		Enums.SkillModifier.VS_UNDEAD, 75, 5, 1), &"schwert", 28))

	# Dolch: Gift, Hinrichtung, viele schnelle Treffer.
	list.append(_tech(_effect(&"tech_giftklinge", "Giftklinge",
		Enums.Status.POISON_DOT, 100, -1, 4, 5, 1), &"dolch", 4))
	list.append(_tech(_mod(&"tech_meucheln", "Meucheln",
		Enums.SkillModifier.EXECUTE, 80, 5, 1), &"dolch", 10))
	list.append(_tech(_mod(&"tech_klingentanz", "Klingentanz",
		Enums.SkillModifier.MULTI_HIT, 2, 8, 1), &"dolch", 18))
	list.append(_tech(_mod(&"tech_schattenstich", "Schattenstich",
		Enums.SkillModifier.PIERCE_ARMOR, 60, 5, 1), &"dolch", 28))

	# Axt: rohe Wucht.
	list.append(_tech(_mod(&"tech_holzfaeller", "Holzfällerschlag",
		Enums.SkillModifier.POWER_AMP, 50, 5, 1), &"axt", 4))
	list.append(_tech(_mod(&"tech_rindenspalter", "Rindenspalter",
		Enums.SkillModifier.PIERCE_ARMOR, 50, 5, 1), &"axt", 10))
	list.append(_tech(_mod(&"tech_zerschmettern", "Zerschmettern",
		Enums.SkillModifier.EXECUTE, 70, 6, 1), &"axt", 18))
	list.append(_tech(_mod(&"tech_berserker", "Berserkerhieb",
		Enums.SkillModifier.OVERLOAD, 80, 0, 1), &"axt", 28))

	# Knüppel/Hammer: Rüstung knacken, betäuben, Untote malmen.
	list.append(_tech(_effect(&"tech_schaedelklopfer", "Schädelklopfer",
		Enums.Status.STUN, 50, 1, 0, 4, 1), &"stumpf", 4))
	list.append(_tech(_mod(&"tech_ruestungsbrecher", "Rüstungsbrecher",
		Enums.SkillModifier.PIERCE_ARMOR, 70, 5, 1), &"stumpf", 10))
	list.append(_tech(_effect(&"tech_erschuetterung", "Erschütterung",
		Enums.Status.WEAKEN, 80, 2, 30, 5, 1), &"stumpf", 18))
	list.append(_tech(_mod(&"tech_untotenmalmer", "Untotenmalmer",
		Enums.SkillModifier.VS_UNDEAD, 75, 5, 1), &"stumpf", 28))

	# Bogen: Pfeilhagel und präzise Schüsse.
	list.append(_tech(_mod(&"tech_doppelschuss", "Doppelschuss",
		Enums.SkillModifier.MULTI_HIT, 1, 5, 1), &"bogen", 4))
	list.append(_tech(_effect(&"tech_giftpfeil", "Giftpfeil",
		Enums.Status.POISON_DOT, 100, -1, 3, 5, 1), &"bogen", 10))
	list.append(_tech(_mod(&"tech_adlerauge", "Adlerauge",
		Enums.SkillModifier.EXECUTE, 70, 5, 1), &"bogen", 18))
	list.append(_tech(_mod(&"tech_pfeilsturm", "Pfeilsturm",
		Enums.SkillModifier.MULTI_HIT, 2, 9, 1), &"bogen", 28))

	# Armbrust: schwere, durchschlagende Bolzen.
	list.append(_tech(_mod(&"tech_durchschuss", "Durchschuss",
		Enums.SkillModifier.PIERCE_ARMOR, 80, 6, 1), &"armbrust", 4))
	list.append(_tech(_mod(&"tech_schwere_bolzen", "Schwere Bolzen",
		Enums.SkillModifier.POWER_AMP, 40, 5, 1), &"armbrust", 10))
	list.append(_tech(_mod(&"tech_praezisionsbolzen", "Präzisionsbolzen",
		Enums.SkillModifier.EXECUTE, 80, 6, 1), &"armbrust", 18))
	list.append(_tech(_mod(&"tech_ballistenschuss", "Ballistenschuss",
		Enums.SkillModifier.PIERCE_ARMOR, 100, 8, 1), &"armbrust", 28))

	# Stab: verstärkt ZAUBER (Techniken funktionieren auch mit Zauber-Quelle).
	list.append(_tech(_mod(&"tech_kanalisieren", "Kanalisieren",
		Enums.SkillModifier.COST_REDUCTION, 35, 0, 1), &"stab", 4))
	list.append(_tech(_mod(&"tech_fokus_strahl", "Fokussierter Strahl",
		Enums.SkillModifier.POWER_AMP, 40, 5, 1), &"stab", 10))
	list.append(_tech(_mod(&"tech_arkane_kette", "Arkane Kette",
		Enums.SkillModifier.CHAIN_ON_KILL, 3, 5, 1), &"stab", 18))
	list.append(_tech(_mod(&"tech_ueberkanalung", "Überkanalung",
		Enums.SkillModifier.OVERLOAD, 70, 0, 1), &"stab", 28))

	# Schild: Kontrolle & Schutz — Schutzwall gehört jetzt hierher.
	list.append(_tech(_effect(&"tech_schildstoss", "Schildstoß",
		Enums.Status.STUN, 40, 1, 0, 4, 1), &"schild", 4))
	list.append(_tech(_effect(&"tech_bollwerk", "Bollwerk",
		Enums.Status.DEF_UP, 100, 3, 8, 4, 1), &"schild", 10))
	list.append(_tech(_effect(&"tech_vergeltung", "Vergeltungsstoß",
		Enums.Status.WEAKEN, 70, 2, 25, 5, 1), &"schild", 28))

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


## Waffentechnik: an EINE Gattung gebunden, freigeschaltet über investierte
## Trainings-Punkte (Schwelle `points`) in ebendieser Gattung.
static func _tech(block: SkillBlock, family: StringName, points: int) -> SkillBlock:
	block.weapon_families = [family]
	block.unlock_kind = Enums.UnlockKind.TRAINING
	block.tree_family = family
	block.tree_points = points
	return block


## Alle Technik-Bausteine eines Trainings-Baums, nach Schwelle sortiert.
static func tree_blocks(family: StringName) -> Array[SkillBlock]:
	_ensure_built()
	var result: Array[SkillBlock] = []
	for id in _blocks:
		var block: SkillBlock = _blocks[id]
		if block.unlock_kind == Enums.UnlockKind.TRAINING and block.tree_family == family:
			result.append(block)
	result.sort_custom(func(a: SkillBlock, b: SkillBlock) -> bool:
		return a.tree_points < b.tree_points)
	return result


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
