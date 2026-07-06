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

	# =========================================================================
	# START-BAUSTEINE: bewusst minimal — nur das Fundament, um überhaupt
	# Skills bauen zu können. ALLES Weitere wird im Waffen-Training der
	# passenden Gattung freigeschaltet. Wichtig: Die Bäume schalten
	# ZUTATEN frei, keine fertigen Skills — gebaut wird in der Werkstatt.
	# U = universelle Zutat (freigeschaltet = in JEDEM Skill nutzbar),
	# G = gattungsgebunden (nur mit passender geführter Waffe einsetzbar).
	# =========================================================================
	list.append(_form(&"form_ally", "Verbündeter", Enums.SkillForm.ALLY, 1.0, 1.0, 1))
	list.append(_form(&"form_self", "Selbst", Enums.SkillForm.SELF, 0.8, 1.0, 1))
	list.append(_effect(&"eff_weaken", "Schwächen", Enums.Status.WEAKEN, 80, 2, 25, 3, 2))

	# ==================== SCHWERT (Ritter: Führung & Konter) ==================
	list.append(_train(_mod(&"mod_power", "Verstärken",
		Enums.SkillModifier.POWER_AMP, 30, 4, 1), &"schwert", 4))  # U
	list.append(_train(_effect(&"eff_atk_up", "Stärken",
		Enums.Status.ATK_UP, 100, 3, 25, 5, 1), &"schwert", 10))  # U
	list.append(_tech(_effect(&"tech_konter", "Konter-Haltung",
		Enums.Status.COUNTER, 100, 2, 60, 5, 1), &"schwert", 18))  # G, NEU
	list.append(_train(_mod(&"mod_vs_undead", "Untotenschreck",
		Enums.SkillModifier.VS_UNDEAD, 75, 4, 1), &"schwert", 28))  # U
	list.append(_tech(_mod(&"tech_sw_multi2", "Mehrfachtreffer II",
		Enums.SkillModifier.MULTI_HIT, 2, 8, 1), &"schwert", 60))  # G
	list.append(_tech(_mod(&"tech_sw_power2", "Verstärken II",
		Enums.SkillModifier.POWER_AMP, 80, 8, 1), &"schwert", 100))  # G

	# ==================== DOLCH (Assassine: Gift & Tempo) =====================
	list.append(_train(_element(&"elem_poison", "Gift",
		Enums.Element.POISON, 4, 0.5, 3, 1), &"dolch", 4))  # U
	list.append(_train(_mod(&"mod_multi", "Mehrfachtreffer",
		Enums.SkillModifier.MULTI_HIT, 1, 6, 1), &"dolch", 10))  # U
	list.append(_tech(_effect(&"tech_erstschlag", "Erstschlag",
		Enums.Status.FIRST_STRIKE, 100, 1, 0, 3, 1), &"dolch", 18))  # G, NEU
	list.append(_tech(_effect(&"tech_blutung", "Blutung",
		Enums.Status.BLEED, 100, -1, 30, 5, 1), &"dolch", 28))  # G, NEU
	list.append(_train(_element(&"elem_dark", "Dunkel",
		Enums.Element.DARK, 0, 1.0, 4, 1), &"dolch", 60))  # U
	list.append(_tech(_mod(&"tech_do_execute2", "Hinrichtung II",
		Enums.SkillModifier.EXECUTE, 150, 7, 1), &"dolch", 100))  # G

	# ==================== AXT (Berserker: Wut & Wucht) ========================
	list.append(_train(_mod(&"mod_execute", "Hinrichtung",
		Enums.SkillModifier.EXECUTE, 50, 3, 1), &"axt", 4))  # U
	list.append(_train(_mod(&"mod_spread", "Splitter",
		Enums.SkillModifier.SPREAD, 30, 4, 1), &"axt", 10))  # U
	list.append(_train(_effect(&"eff_lifesteal", "Lebensraub",
		Enums.Status.LIFESTEAL, 100, 0, 30, 5, 1), &"axt", 18))  # U
	list.append(_train(_mod(&"mod_overload", "Überladung",
		Enums.SkillModifier.OVERLOAD, 40, 0, 1), &"axt", 28))  # U
	list.append(_tech(_mod(&"tech_ax_power2", "Verstärken II",
		Enums.SkillModifier.POWER_AMP, 80, 7, 1), &"axt", 60))  # G
	list.append(_tech(_mod(&"tech_ax_overload2", "Überladung II",
		Enums.SkillModifier.OVERLOAD, 120, 0, 1), &"axt", 100))  # G

	# ==================== KNÜPPEL/HAMMER (Brecher: Kontrolle) =================
	list.append(_train(_effect(&"eff_stun", "Betäuben",
		Enums.Status.STUN, 60, 1, 0, 6, 1), &"stumpf", 4))  # U
	list.append(_tech(_effect(&"tech_ruestungsriss", "Rüstungsriss",
		Enums.Status.ARMOR_BREAK, 100, 2, 40, 5, 1), &"stumpf", 10))  # G, NEU
	list.append(_train(_effect(&"eff_slow", "Verlangsamen",
		Enums.Status.SLOW, 80, 2, 30, 3, 1), &"stumpf", 18))  # U
	list.append(_tech(_effect(&"tech_st_stun2", "Betäuben II",
		Enums.Status.STUN, 75, 1, 0, 7, 1), &"stumpf", 60))  # G
	list.append(_tech(_effect(&"tech_st_riss2", "Rüstungsriss II",
		Enums.Status.ARMOR_BREAK, 100, 3, 60, 7, 1), &"stumpf", 100))  # G

	# ==================== BOGEN (Jäger: Markieren & Salven) ===================
	list.append(_tech(_effect(&"tech_markieren", "Markieren",
		Enums.Status.MARKED, 100, 2, 25, 4, 1), &"bogen", 4))  # G, NEU
	list.append(_train(_element(&"elem_ice", "Eis",
		Enums.Element.ICE, 0, 1.0, 3, 1), &"bogen", 10))  # U
	list.append(_tech(_mod(&"tech_bo_multi2", "Mehrfachtreffer II",
		Enums.SkillModifier.MULTI_HIT, 2, 8, 1), &"bogen", 60))  # G
	list.append(_tech(_mod(&"tech_bo_multi3", "Mehrfachtreffer III",
		Enums.SkillModifier.MULTI_HIT, 3, 12, 1), &"bogen", 100))  # G

	# ==================== ARMBRUST (Belagerer: Durchschlag) ===================
	list.append(_train(_mod(&"mod_pierce", "Durchdringung",
		Enums.SkillModifier.PIERCE_ARMOR, 50, 3, 1), &"armbrust", 4))  # U
	list.append(_train(_element(&"elem_lightning", "Blitz",
		Enums.Element.LIGHTNING, 0, 1.0, 4, 1), &"armbrust", 10))  # U
	list.append(_tech(_mod(&"tech_ar_pierce2", "Durchdringung II",
		Enums.SkillModifier.PIERCE_ARMOR, 80, 6, 1), &"armbrust", 18))  # G
	list.append(_tech(_effect(&"tech_ar_slow2", "Verlangsamen II",
		Enums.Status.SLOW, 100, 2, 45, 6, 1), &"armbrust", 60))  # G
	list.append(_tech(_mod(&"tech_ar_pierce3", "Durchdringung III",
		Enums.SkillModifier.PIERCE_ARMOR, 100, 8, 1), &"armbrust", 100))  # G

	# =============== OFFENSIVSTAB (Schadensmagie-Schule) =====================
	list.append(_train(_element(&"elem_fire", "Feuer",
		Enums.Element.FIRE, 3, 1.0, 2, 1), &"offensivstab", 4))  # U
	list.append(_train(_form(&"form_aoe", "Fläche",
		Enums.SkillForm.AOE, 1.6, 0.7, 1), &"offensivstab", 14))  # U
	list.append(_train(_mod(&"mod_cost", "Effizienz",
		Enums.SkillModifier.COST_REDUCTION, 25, 0, 1), &"offensivstab", 28))  # U
	list.append(_train(_form(&"form_summon", "Beschwörung",
		Enums.SkillForm.SUMMON, 2.0, 1.0, 1), &"offensivstab", 40))  # U
	list.append(_tech(_mod(&"tech_echo", "Echo",
		Enums.SkillModifier.ECHO, 50, 6, 1), &"offensivstab", 60))  # G, NEU
	list.append(_train(_mod(&"mod_chain", "Kettenreaktion",
		Enums.SkillModifier.CHAIN_ON_KILL, 2, 5, 1), &"offensivstab", 75))  # U
	list.append(_tech(_mod(&"tech_os_power2", "Verstärken II",
		Enums.SkillModifier.POWER_AMP, 80, 8, 1), &"offensivstab", 100))  # G

	# =============== HEILIGSTAB (Heilmagie-Schule) ===========================
	list.append(_train(_element(&"elem_holy", "Heilig",
		Enums.Element.HOLY, 0, 1.0, 4, 1), &"heiligstab", 4))  # U
	list.append(_train(_form(&"form_aura", "Aura",
		Enums.SkillForm.AURA, 1.4, 0.7, 1), &"heiligstab", 14))  # U
	list.append(_train(_effect(&"eff_regen", "Regeneration",
		Enums.Status.REGEN, 100, 3, 8, 6, 1), &"heiligstab", 28))  # U
	list.append(_train(_effect(&"eff_cleanse", "Reinigen",
		Enums.Status.CLEANSE, 100, 0, 0, 5, 1), &"heiligstab", 40))  # U
	list.append(_tech(_mod(&"tech_ueberheilung", "Überheilung",
		Enums.SkillModifier.OVERHEAL_SHIELD, 100, 4, 1), &"heiligstab", 60))  # G, NEU
	list.append(_train(_effect(&"eff_mana_regen", "Mana-Fluss",
		Enums.Status.MANA_REGEN, 100, 3, 6, 5, 1), &"heiligstab", 75))  # U
	list.append(_train(_effect(&"eff_revive", "Wiederbeleben",
		Enums.Status.REVIVE, 100, 0, 40, 12, 1), &"heiligstab", 100))  # U

	# ==================== SCHILD (Bollwerk: Schutz & Dornen) ==================
	list.append(_train(_effect(&"eff_def_up", "Wappnen",
		Enums.Status.DEF_UP, 100, 3, 5, 4, 1), &"schild", 4))  # U
	list.append(_train(_effect(&"eff_shield", "Schild",
		Enums.Status.SHIELD, 100, 3, 10, 4, 1), &"schild", 10))  # U
	list.append(_tech(_effect(&"eff_protect", "Schutzwall",
		Enums.Status.PROTECT, 100, 2, 0, 6, 1), &"schild", 18))  # G
	list.append(_tech(_effect(&"tech_vergeltung", "Vergeltung",
		Enums.Status.THORNS, 100, 2, 30, 5, 1), &"schild", 28))  # G, NEU
	list.append(_tech(_effect(&"tech_sh_stun2", "Betäuben II",
		Enums.Status.STUN, 60, 1, 0, 5, 1), &"schild", 60))  # G
	list.append(_tech(_effect(&"tech_sh_shield2", "Schild II",
		Enums.Status.SHIELD, 100, 4, 60, 10, 1), &"schild", 100))  # G

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


## Universelle Trainings-Zutat: über den Baum freigeschaltet, danach in
## JEDEM Skill nutzbar (keine Gattungsbindung) — der Baukasten bleibt frei.
static func _train(block: SkillBlock, family: StringName, points: int) -> SkillBlock:
	block.unlock_kind = Enums.UnlockKind.TRAINING
	block.tree_family = family
	block.tree_points = points
	return block


## Waffentechnik: an EINE Gattung gebunden, freigeschaltet über investierte
## Trainings-Punkte (Schwelle `points`) in ebendieser Gattung.
static func _tech(block: SkillBlock, family: StringName, points: int) -> SkillBlock:
	block.weapon_families = [family]
	block.unlock_kind = Enums.UnlockKind.TRAINING
	block.tree_family = family
	block.tree_points = points
	return block


# --- Passiv-Boni der Trainings-Bäume ---------------------------------------
# Greifen automatisch, sobald die Schwelle erreicht ist UND die Gattung
# geführt wird (Schild über die Nebenhand). ALLE Boni sind PROZENTE:
# dmg (+% Waffenschaden), spell (+% Zauberkraft), crit (+% Kritchance),
# armor (+% Rüstung), mp (−% MP-Kosten).

const _PHYS_PASSIVES: Array = [
	{"points": 7, "kind": &"dmg", "magnitude": 10},
	{"points": 14, "kind": &"crit", "magnitude": 5},
	{"points": 22, "kind": &"dmg", "magnitude": 10},
	{"points": 35, "kind": &"crit", "magnitude": 5},
	{"points": 50, "kind": &"dmg", "magnitude": 15},
	{"points": 75, "kind": &"dmg", "magnitude": 15},
	{"points": 92, "kind": &"crit", "magnitude": 10},
]
const _STAB_PASSIVES: Array = [
	{"points": 7, "kind": &"spell", "magnitude": 10},
	{"points": 14, "kind": &"mp", "magnitude": 5},
	{"points": 22, "kind": &"spell", "magnitude": 10},
	{"points": 35, "kind": &"mp", "magnitude": 5},
	{"points": 50, "kind": &"spell", "magnitude": 15},
	{"points": 75, "kind": &"spell", "magnitude": 15},
	{"points": 92, "kind": &"mp", "magnitude": 10},
]
const _SCHILD_PASSIVES: Array = [
	{"points": 7, "kind": &"armor", "magnitude": 5},
	{"points": 14, "kind": &"armor", "magnitude": 5},
	{"points": 22, "kind": &"armor", "magnitude": 5},
	{"points": 35, "kind": &"armor", "magnitude": 5},
	{"points": 50, "kind": &"armor", "magnitude": 10},
	{"points": 75, "kind": &"armor", "magnitude": 10},
	{"points": 92, "kind": &"armor", "magnitude": 10},
]
const TREE_PASSIVES := {
	&"schwert": _PHYS_PASSIVES, &"dolch": _PHYS_PASSIVES,
	&"axt": _PHYS_PASSIVES, &"stumpf": _PHYS_PASSIVES,
	&"bogen": _PHYS_PASSIVES, &"armbrust": _PHYS_PASSIVES,
	&"offensivstab": _STAB_PASSIVES, &"heiligstab": _STAB_PASSIVES,
	&"schild": _SCHILD_PASSIVES,
}


static func passives_for(family: StringName) -> Array:
	return TREE_PASSIVES.get(family, [])


static func passive_label(passive: Dictionary) -> String:
	match passive["kind"]:
		&"dmg":
			return Loc.pick("+%d%% Waffenschaden", "+%d%% weapon damage") % passive["magnitude"]
		&"spell":
			return Loc.pick("+%d%% Zauberkraft", "+%d%% spell power") % passive["magnitude"]
		&"crit":
			return Loc.pick("+%d%% Kritchance", "+%d%% crit chance") % passive["magnitude"]
		&"armor":
			return Loc.pick("+%d%% Rüstung", "+%d%% armor") % passive["magnitude"]
		&"mp":
			return Loc.pick("−%d%% MP-Kosten", "−%d%% MP cost") % passive["magnitude"]
	return ""


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
	&"offensivstab": ["Offensivstab", "Offense staff"],
	&"heiligstab": ["Heiligstab", "Holy staff"],
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
