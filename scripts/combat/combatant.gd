class_name Combatant
extends RefCounted
## Ein Kampfteilnehmer zur Laufzeit (Spieler-Charakter oder Gegner).
## Leitet HP/MP linear aus dem StatBlock ab und verwaltet Statuseffekte.

const HP_BASE := 20
const HP_PER_VIT := 8
const MP_BASE := 10
const MP_PER_SPI := 5

## Frei verteilbare Statuspunkte pro Level-Up. Es gibt KEIN Level-Cap —
## alle Helden starten identisch (5 auf jedem Wert), die Rolle entsteht
## rein aus Punkteverteilung, Skill-Bauklötzen und Ausrüstung.
const POINTS_PER_LEVEL := 5

var display_name := ""
var stats: StatBlock
var is_player := false
var sprite: Texture2D = null  ## Pixel-Art-Darstellung (Kampf & ggf. Dungeon)
var level := 1  ## Bestimmt u.a. Skill-Slots (1 + Level/5) und Baustein-Freischaltung
var xp := 0
var stat_points := 0  ## Noch nicht verteilte Statuspunkte

var max_hp := 1
var hp := 1
var max_mp := 0
var mp := 0

## Flache Schadensreduktion: armor gegen physisch, magic_resist gegen magisch.
## Elementarschaden (DoT) ignoriert beides — das ist die Nische dieser Achse.
## Das ist der "natürliche" Grundwert; Ausrüstung kommt obendrauf.
var armor := 0
var magic_resist := 0

## Loot-Multiplikator (Elite-/Boss-Gegner droppen mehr), nur für Gegner relevant.
var loot_mult := 1.0

## Untot-Tag: Heiliger Schaden macht Bonusschaden gegen Untote.
var is_undead := false

## Beschwörung: temporärer Verbündeter — kämpft eigenständig, läuft nach
## einigen Zügen ab, gibt weder XP noch Beute und zählt nicht für Sieg/
## Niederlage. Pro Beschwörer existiert nur eine Beschwörung gleichzeitig.
var is_summon := false
var summoner: Combatant = null
var summon_turns_left := 0

## Innewohnende Waffenwerte für Gegner (sie tragen keine Items). Bei Spielern 0 —
## dort kommen die Werte aus der Ausrüstung (weapon_damage()/spell_damage()).
var innate_weapon_damage := 0
var innate_spell_damage := 0
var innate_weapon_subtypes: Array[Enums.PhysicalSubtype] = [Enums.PhysicalSubtype.BLUNT]

var skills: Array[Skill] = []

## Ausrüstung: Enums.EquipSlot → ItemInstance. Boni fließen über stat(),
## total_armor() etc. in den Kampf ein.
var equipment: Dictionary = {}

## Aktive Statuseffekte: {"status": Enums.Status, "turns": int, "potency": int}
var statuses: Array[Dictionary] = []


static func create(p_name: String, p_stats: StatBlock, p_is_player: bool) -> Combatant:
	var c := Combatant.new()
	c.display_name = p_name
	c.stats = p_stats
	c.is_player = p_is_player
	c.max_hp = HP_BASE + p_stats.vitality * HP_PER_VIT
	c.hp = c.max_hp
	c.max_mp = MP_BASE + p_stats.spirit * MP_PER_SPI
	c.mp = c.max_mp
	return c


func is_alive() -> bool:
	return hp > 0


## Effektiver Attributwert: Basis + Summe aller Ausrüstungs-Boni.
func stat(stat_name: StringName) -> int:
	var total: int = stats.get(stat_name)
	for slot in equipment:
		var item: ItemInstance = equipment[slot]
		total += item.get_total_stat_bonus().get(stat_name)
	return total


## Wirksamkeit der Rüstungstypen gegen die physischen Schadensarten.
const ARMOR_CLASS_MULT := {
	Enums.ArmorClass.NONE: {
		Enums.PhysicalSubtype.SLASH: 1.0,
		Enums.PhysicalSubtype.PIERCE: 1.0,
		Enums.PhysicalSubtype.BLUNT: 1.0,
	},
	Enums.ArmorClass.LEATHER: {
		Enums.PhysicalSubtype.SLASH: 1.0,
		Enums.PhysicalSubtype.PIERCE: 1.0,
		Enums.PhysicalSubtype.BLUNT: 1.0,
	},
	Enums.ArmorClass.CHAIN: {
		Enums.PhysicalSubtype.SLASH: 1.5,
		Enums.PhysicalSubtype.PIERCE: 0.75,
		Enums.PhysicalSubtype.BLUNT: 0.75,
	},
	Enums.ArmorClass.PLATE: {
		Enums.PhysicalSubtype.SLASH: 1.5,
		Enums.PhysicalSubtype.PIERCE: 1.25,
		Enums.PhysicalSubtype.BLUNT: 0.5,
	},
}


## Neutraler Gesamt-Rüstungswert (für Anzeigen).
func total_armor() -> int:
	var total := armor
	for slot in equipment:
		total += equipment[slot].get_total_armor()
	return total


## Effektive Rüstung gegen eine physische Schadensart: natürliche Rüstung
## wirkt neutral, jedes Rüstungsteil nach seinem Rüstungstyp, dazu DEF_UP-Buffs.
func armor_against(subtype: Enums.PhysicalSubtype) -> int:
	var total := float(armor)
	for slot in equipment:
		var item: ItemInstance = equipment[slot]
		total += item.get_total_armor() * ARMOR_CLASS_MULT[item.base.armor_class][subtype]
	var def_up := get_status(Enums.Status.DEF_UP)
	if not def_up.is_empty():
		total += def_up["potency"]
	return roundi(total)


## Schadensprofil der geführten Waffe; Gegner nutzen ihr innewohnendes Profil,
## unbewaffnete Spieler = Faust = Stumpf.
func weapon_subtypes() -> Array[Enums.PhysicalSubtype]:
	if equipment.has(Enums.EquipSlot.WEAPON):
		var weapon: ItemInstance = equipment[Enums.EquipSlot.WEAPON]
		if not weapon.base.weapon_subtypes.is_empty():
			return weapon.base.weapon_subtypes
	return innate_weapon_subtypes


func total_magic_resist() -> int:
	return magic_resist


## Physischer Waffenschaden (Waffennutzung). Spieler: aus der Ausrüstung;
## Gegner (ohne Items): innewohnender Wert.
func weapon_damage() -> int:
	var total := 0
	for slot in [Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND]:
		if equipment.has(slot):
			total += equipment[slot].get_total_damage()
	if total == 0:
		total = innate_weapon_damage
	return total


## Zauberschaden (Zauber-Quelle). Spieler: aus Stäben/Ausrüstung; Gegner: innewohnend.
func spell_damage() -> int:
	var total := 0
	for slot in [Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND]:
		if equipment.has(slot):
			total += equipment[slot].get_total_spell_damage()
	if total == 0:
		total = innate_spell_damage
	return total


## Element-Rider der geführten Waffe(n): Element → Zusatzschaden, der bei
## jedem Waffennutzungs-Treffer zusätzlich zuschlägt (aus Element-Affixen).
func element_riders() -> Dictionary:
	var riders := {}
	for slot in [Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND]:
		if equipment.has(slot):
			var item: ItemInstance = equipment[slot]
			for element in item.get_element_riders():
				riders[element] = riders.get(element, 0) + item.get_element_riders()[element]
	return riders


## Flache Resistenz gegen ein Element, gesammelt über die GESAMTE Ausrüstung —
## das Gegenmittel zu den Element-Gegnern hoher Kartenstufen.
func element_resist(element: Enums.Element) -> int:
	var total := 0
	for slot in equipment:
		var item: ItemInstance = equipment[slot]
		total += item.get_element_resist(element)
	return total


## Flache MP-Kosten-Reduktion aus Skill-Affixen der Ausrüstung.
func mp_cost_reduction() -> int:
	var total := 0
	for slot in equipment:
		var item: ItemInstance = equipment[slot]
		total += item.get_mp_cost_reduction()
	return total


## HP/MP neu ableiten (nach Ausrüstungswechsel oder Level-Up).
func recompute_derived() -> void:
	max_hp = HP_BASE + stat(&"vitality") * HP_PER_VIT
	max_mp = MP_BASE + stat(&"spirit") * MP_PER_SPI
	hp = mini(hp, max_hp)
	mp = mini(mp, max_mp)


## Rüstet ein Item aus. Ringe wandern automatisch in den freien Ring-Slot;
## Zweihänder verdrängen die Nebenhand (und umgekehrt).
## Gibt alle dabei abgelegten Items zurück.
func equip(item: ItemInstance) -> Array[ItemInstance]:
	var removed: Array[ItemInstance] = []
	var slot := item.base.slot
	if slot == Enums.EquipSlot.RING_1 and equipment.has(Enums.EquipSlot.RING_1) \
			and not equipment.has(Enums.EquipSlot.RING_2):
		slot = Enums.EquipSlot.RING_2
	# Zweihänder blockiert die Nebenhand …
	if slot == Enums.EquipSlot.WEAPON and item.base.two_handed \
			and equipment.has(Enums.EquipSlot.OFF_HAND):
		removed.append(equipment[Enums.EquipSlot.OFF_HAND])
		equipment.erase(Enums.EquipSlot.OFF_HAND)
	# … und Nebenhand anlegen verdrängt einen geführten Zweihänder.
	if slot == Enums.EquipSlot.OFF_HAND and equipment.has(Enums.EquipSlot.WEAPON) \
			and equipment[Enums.EquipSlot.WEAPON].base.two_handed:
		removed.append(equipment[Enums.EquipSlot.WEAPON])
		equipment.erase(Enums.EquipSlot.WEAPON)
	var old: ItemInstance = equipment.get(slot)
	if old != null:
		removed.append(old)
	equipment[slot] = item
	recompute_derived()
	return removed


func unequip(slot: Enums.EquipSlot) -> ItemInstance:
	var old: ItemInstance = equipment.get(slot)
	equipment.erase(slot)
	recompute_derived()
	return old


func skill_slots() -> int:
	return CharacterDef.skill_slots_for_level(level)


## Kampfvorbereitung: Statuseffekte weg; volle Heilung nur außerhalb von
## Dungeon-Runs (im Dungeon herrscht Attrition — Wunden bleiben).
func reset_for_battle(full_heal := true) -> void:
	statuses.clear()
	if full_heal:
		recompute_derived()
		hp = max_hp
		mp = max_mp


## XP-Schwelle für den nächsten Level-Up (leicht steigende Kurve).
func xp_to_next() -> int:
	return 25 + level * 15


## XP sammeln, ggf. mehrfach aufleveln (kein Cap). Jedes Level gibt
## POINTS_PER_LEVEL frei verteilbare Statuspunkte und heilt voll
## (klassisches JRPG-Gefühl). Gibt die Anzahl Level-Ups zurück.
func gain_xp(amount: int) -> int:
	if not is_player:
		return 0
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
		stat_points += POINTS_PER_LEVEL
	if gained > 0:
		recompute_derived()
		hp = max_hp
		mp = max_mp
	return gained


## Einen Statuspunkt in ein Attribut investieren.
func spend_stat_point(stat_name: StringName) -> bool:
	if stat_points <= 0 or stat_name not in StatBlock.STAT_NAMES:
		return false
	stat_points -= 1
	stats.set(stat_name, stats.get(stat_name) + 1)
	recompute_derived()
	return true


## Tempo für die Zugreihenfolge; SLOW reduziert prozentual.
func effective_speed() -> int:
	var speed := stat(&"agility")
	var slow := get_status(Enums.Status.SLOW)
	if not slow.is_empty():
		speed = roundi(speed * (1.0 - slow["potency"] / 100.0))
	return speed


## Nimmt Schaden, SHIELD absorbiert zuerst. Gibt den tatsächlich
## an den HP angekommenen Schaden zurück.
func take_damage(amount: int) -> int:
	var shield := get_status(Enums.Status.SHIELD)
	if not shield.is_empty():
		var absorbed: int = mini(amount, shield["potency"])
		shield["potency"] -= absorbed
		amount -= absorbed
		if shield["potency"] <= 0:
			statuses.erase(shield)
	hp = maxi(0, hp - amount)
	return amount


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)


func get_status(status: Enums.Status) -> Dictionary:
	for entry in statuses:
		if entry["status"] == status:
			return entry
	return {}


func has_status(status: Enums.Status) -> bool:
	return not get_status(status).is_empty()


## Gleicher Status stackt nicht: Dauer und Stärke werden auf das Maximum gesetzt.
## Nur für Spieler-Helden gedacht (Gegner werden bei jedem Kampf neu
## generiert und müssen nie gespeichert werden).
func to_dict() -> Dictionary:
	var equip_list: Array = []
	for slot in equipment:
		equip_list.append({"slot": int(slot), "item": equipment[slot].to_dict()})
	var skills_list: Array = []
	for skill in skills:
		skills_list.append(skill.to_dict())
	return {
		"name": display_name,
		"stats": stats.to_dict(),
		"level": level,
		"xp": xp,
		"stat_points": stat_points,
		"hp": hp,
		"mp": mp,
		"armor": armor,
		"magic_resist": magic_resist,
		"equipment": equip_list,
		"skills": skills_list,
	}


static func from_dict(data: Dictionary) -> Combatant:
	var stats := StatBlock.from_dict(data.get("stats", {}))
	var combatant := Combatant.create(data.get("name", "Held"), stats, true)
	combatant.level = int(data.get("level", 1))
	combatant.xp = int(data.get("xp", 0))
	combatant.stat_points = int(data.get("stat_points", 0))
	combatant.armor = int(data.get("armor", 0))
	combatant.magic_resist = int(data.get("magic_resist", 0))
	for entry in data.get("equipment", []):
		var item := ItemInstance.from_dict(entry.get("item", {}))
		if item != null:
			combatant.equipment[int(entry.get("slot", 0))] = item
	# recompute_derived() braucht die Ausrüstung, um Max-HP/MP korrekt zu
	# berechnen — danach erst die gespeicherten (ggf. verwundeten) Werte setzen.
	combatant.recompute_derived()
	combatant.hp = int(data.get("hp", combatant.max_hp))
	combatant.mp = int(data.get("mp", combatant.max_mp))
	var loaded_skills: Array[Skill] = []
	for skill_data in data.get("skills", []):
		loaded_skills.append(Skill.from_dict(skill_data))
	combatant.skills = loaded_skills
	combatant.sprite = SpriteLib.hero(combatant.display_name)
	return combatant


## Stack-basierte Statuseffekte (Phase 3): potency = Stacks, die sich bei
## jedem Treffer AUFADDIEREN. turns = -1 (kein Zeitablauf) — Brand klingt
## über Halbierung pro Tick ab, Gift bleibt bis zur Heilung bestehen.
const STACKING_STATUSES: Array[Enums.Status] = [
	Enums.Status.BURN, Enums.Status.POISON_DOT,
]


func add_status(status: Enums.Status, turns: int, potency: int) -> void:
	var existing := get_status(status)
	if status in STACKING_STATUSES:
		if existing.is_empty():
			statuses.append({"status": status, "turns": -1, "potency": potency})
		else:
			existing["potency"] += potency  # Stacks addieren sich
		return
	if existing.is_empty():
		statuses.append({"status": status, "turns": turns, "potency": potency})
	else:
		existing["turns"] = maxi(existing["turns"], turns)
		existing["potency"] = maxi(existing["potency"], potency)
