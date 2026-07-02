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


func total_armor() -> int:
	var total := armor
	for slot in equipment:
		total += equipment[slot].get_total_armor()
	return total


func total_magic_resist() -> int:
	return magic_resist


## Waffenschaden (fließt in den Basisangriff ein).
func weapon_damage() -> int:
	var total := 0
	for slot in [Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND]:
		if equipment.has(slot):
			total += equipment[slot].get_total_damage()
	return total


## HP/MP neu ableiten (nach Ausrüstungswechsel oder Level-Up).
func recompute_derived() -> void:
	max_hp = HP_BASE + stat(&"vitality") * HP_PER_VIT
	max_mp = MP_BASE + stat(&"spirit") * MP_PER_SPI
	hp = mini(hp, max_hp)
	mp = mini(mp, max_mp)


## Rüstet ein Item aus. Ringe wandern automatisch in den freien Ring-Slot.
## Gibt das ersetzte Item zurück (oder null).
func equip(item: ItemInstance) -> ItemInstance:
	var slot := item.base.slot
	if slot == Enums.EquipSlot.RING_1 and equipment.has(Enums.EquipSlot.RING_1) \
			and not equipment.has(Enums.EquipSlot.RING_2):
		slot = Enums.EquipSlot.RING_2
	var old: ItemInstance = equipment.get(slot)
	equipment[slot] = item
	recompute_derived()
	return old


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
func add_status(status: Enums.Status, turns: int, potency: int) -> void:
	var existing := get_status(status)
	if existing.is_empty():
		statuses.append({"status": status, "turns": turns, "potency": potency})
	else:
		existing["turns"] = maxi(existing["turns"], turns)
		existing["potency"] = maxi(existing["potency"], potency)
