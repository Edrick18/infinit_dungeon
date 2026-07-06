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
## Bei der Erstellung gewähltes Helden-Porträt (Kenney-Tile-Index).
## -1 = Altbestand: Porträt kommt über den Namen (SpriteLib.hero).
var portrait_tile := -1
var level := 1  ## Bestimmt u.a. Skill-Slots (1 + Level/5) und Baustein-Freischaltung
var xp := 0
var stat_points := 0  ## Noch nicht verteilte Statuspunkte

## Waffen-Training (DQ9-Stil): freie Skillpunkte (+3 pro Level-Up) werden
## pro Waffengattung investiert und schalten Technik-Bausteine frei.
const SKILL_POINTS_PER_LEVEL := 3
var skill_points := 0
var weapon_invest: Dictionary = {}  ## Gattung » investierte Punkte

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

## Grundtyp-ID aus der EnemyFactory (z.B. &"schleim" — fürs Schleim-Stapeln).
var archetype_id: StringName = &""

## Metallschleim & Co.: XP-Jackpot, aber flüchtet gern (pro eigenem Zug).
var xp_mult := 1.0
var flee_chance := 0.0

## Verstärkung rufen (Wolf/Kultist): einmal pro Gegner.
var can_call_reinforcements := false
var reinforcement_called := false

## Boss-Mechaniken (siehe Battle): Phasen, aufgeladener Spezialangriff,
## Signature-Mechanik pro Archetyp und Adds bei Phasenwechseln.
var is_boss := false
var boss_signature: StringName = &""  ## wut/steinpanzer/regeneration/adds/haltung
var signature_active := true          ## z.B. Steinpanzer: noch intakt?
var boss_phase := 1
var boss_add_id: StringName = &""     ## Archetyp der gerufenen Begleiter
var charge_active := false            ## lädt gerade den Spezialangriff auf
var charge_cooldown := 0
var stance_counter := 0               ## Haltungs-Wechsel (Schattenbestie)
var stance_physical := true

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
var innate_hit_count := 1  ## z.B. Skelett-Bogenschütze: 2 Pfeile pro Angriff

var skills: Array[Skill] = []

## Ausrüstung: Enums.EquipSlot » ItemInstance. Boni fließen über stat(),
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
	return _after_armor_mods(total)


## Effektive Rüstung gegen eine physische Schadensart: natürliche Rüstung
## wirkt neutral, jedes Rüstungsteil nach seinem Rüstungstyp, dazu DEF_UP-Buffs
## und Schild-Trainings-Passive.
## Trainings-Passive (+%) und Rüstungsriss (−%) auf die Rüstung anwenden.
func _after_armor_mods(total: float) -> int:
	total *= 1.0 + training_armor_percent() / 100.0
	var broken := get_status(Enums.Status.ARMOR_BREAK)
	if not broken.is_empty():
		total *= 1.0 - broken["potency"] / 100.0
	# Zertrümmern (Stumpf-Eigenheit): prozentual, skaliert ins Endgame.
	total *= 1.0 - mini(armor_shred, 50) / 100.0
	return maxi(0, roundi(total))


func armor_against(subtype: Enums.PhysicalSubtype) -> int:
	var total := float(armor)
	for slot in equipment:
		var item: ItemInstance = equipment[slot]
		total += item.get_total_armor() * ARMOR_CLASS_MULT[item.base.armor_class][subtype]
	var def_up := get_status(Enums.Status.DEF_UP)
	if not def_up.is_empty():
		total += def_up["potency"]
	return _after_armor_mods(total)


## Turmschild-Eigenheit: der Waffenschaden IST die Rüstung (×0,75).
func _tower_weapon_damage() -> int:
	return maxi(2, roundi(total_armor() * 0.75))


## Schadensprofil der geführten Waffe(n); bei Dual Wield (Dolch in der
## Nebenhand) vereinen sich die Profile. Gegner nutzen ihr innewohnendes
## Profil, unbewaffnete Spieler = Faust = Stumpf.
func weapon_subtypes() -> Array[Enums.PhysicalSubtype]:
	var result: Array[Enums.PhysicalSubtype] = []
	for slot in [Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND]:
		if not equipment.has(slot):
			continue
		var item: ItemInstance = equipment[slot]
		if item.base.base_damage <= 0:
			continue
		for subtype in item.base.weapon_subtypes:
			if subtype not in result:
				result.append(subtype)
	if result.is_empty():
		return innate_weapon_subtypes
	return result


## Treffer pro Waffennutzung (Bogen: 2 Pfeile) — bestimmt die Hauptwaffe;
## Gegner ohne Items nutzen ihren innewohnenden Wert (Bogenschützen-Variante).
func weapon_hit_count() -> int:
	if equipment.has(Enums.EquipSlot.WEAPON):
		return maxi(1, equipment[Enums.EquipSlot.WEAPON].base.hit_count)
	return maxi(1, innate_hit_count)


## Rüstungsdurchdringung der Hauptwaffe (Armbrust ignoriert 20% Rüstung).
func weapon_armor_pierce() -> float:
	if equipment.has(Enums.EquipSlot.WEAPON):
		return equipment[Enums.EquipSlot.WEAPON].base.armor_pierce
	return 0.0


func total_magic_resist() -> int:
	return magic_resist


## Physischer Waffenschaden (Waffennutzung). Spieler: aus der Ausrüstung
## (Hauptwaffe + Nebenhand-Dolch/Köcher); Gegner (ohne Items): innewohnend.
## Köcher-Bonus zählt nur, wenn die Hauptwaffe eine Fernkampfwaffe ist.
func weapon_damage() -> int:
	if wields_tower_shield():
		return _tower_weapon_damage()
	var total := 0
	var main: ItemInstance = equipment.get(Enums.EquipSlot.WEAPON)
	if main != null:
		total += main.get_total_damage()
	var off: ItemInstance = equipment.get(Enums.EquipSlot.OFF_HAND)
	if off != null:
		if not off.base.quiver or (main != null and main.base.ranged):
			total += off.get_total_damage()
	if total == 0:
		total = innate_weapon_damage
	return total


## Zauberschaden (Zauber-Quelle). Spieler: aus der GESAMTEN Ausrüstung
## (Stäbe, Foki, Roben); Gegner: innewohnend.
func spell_damage() -> int:
	var total := 0
	for slot in equipment:
		var item: ItemInstance = equipment[slot]
		total += item.get_total_spell_damage()
	if total == 0:
		total = innate_spell_damage
	return total


## Element-Rider der geführten Waffe(n): Element » Zusatzschaden, der bei
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
## leichte Waffen (Dolche) in die freie Nebenhand (Dual Wield); Zweihänder
## verdrängen die Nebenhand (und umgekehrt) — Fernkampfwaffen dulden aber
## einen Köcher. Gibt alle dabei abgelegten Items zurück.
func equip(item: ItemInstance) -> Array[ItemInstance]:
	var removed: Array[ItemInstance] = []
	var slot := item.base.slot
	if slot == Enums.EquipSlot.RING_1 and equipment.has(Enums.EquipSlot.RING_1) \
			and not equipment.has(Enums.EquipSlot.RING_2):
		slot = Enums.EquipSlot.RING_2
	# Zweiter Dolch: wandert in die freie Nebenhand, wenn die Haupthand von
	# einer Einhandwaffe belegt ist.
	if slot == Enums.EquipSlot.WEAPON and item.base.light \
			and equipment.has(Enums.EquipSlot.WEAPON) \
			and not equipment[Enums.EquipSlot.WEAPON].base.two_handed \
			and not equipment.has(Enums.EquipSlot.OFF_HAND):
		slot = Enums.EquipSlot.OFF_HAND
	# Zweihänder blockiert die Nebenhand — außer Fernkampfwaffe + Köcher.
	if slot == Enums.EquipSlot.WEAPON and item.base.two_handed \
			and equipment.has(Enums.EquipSlot.OFF_HAND):
		var off: ItemInstance = equipment[Enums.EquipSlot.OFF_HAND]
		if not (item.base.ranged and off.base.quiver):
			removed.append(off)
			equipment.erase(Enums.EquipSlot.OFF_HAND)
	# Nebenhand anlegen verdrängt einen geführten Zweihänder — außer ein
	# Köcher ergänzt eine Fernkampfwaffe.
	if slot == Enums.EquipSlot.OFF_HAND and equipment.has(Enums.EquipSlot.WEAPON) \
			and equipment[Enums.EquipSlot.WEAPON].base.two_handed:
		var main: ItemInstance = equipment[Enums.EquipSlot.WEAPON]
		if not (item.base.quiver and main.base.ranged):
			removed.append(main)
			equipment.erase(Enums.EquipSlot.WEAPON)
	var old: ItemInstance = equipment.get(slot)
	if old != null:
		removed.append(old)
	equipment[slot] = item
	recompute_derived()
	return removed


## Gattung der geführten Hauptwaffe (leer = unbewaffnet) — Waffentechniken
## prüfen dagegen.
func weapon_family() -> StringName:
	var weapon: ItemInstance = equipment.get(Enums.EquipSlot.WEAPON)
	return weapon.base.family if weapon != null else &""


## Führt der Held gerade etwas dieser Gattung? (Schild/zweiter Dolch
## zählen über die Nebenhand.)
func wields_family(family: StringName) -> bool:
	if weapon_family() == family:
		return true
	var off: ItemInstance = equipment.get(Enums.EquipSlot.OFF_HAND)
	return off != null and off.base.family == family


# --- Waffen-Eigenheiten ------------------------------------------------------------
# Jede Gattung hat EINE einzigartige Mechanik, die immer aktiv ist, solange
# die Waffe geführt wird (kein Baustein, kein Unlock — die Identität der
# Waffe selbst). Kampf-Zustand, wird in reset_for_battle() zurückgesetzt.

var combo_stacks := 0        ## Dolch: +8% Waffenschaden je Stack (max 5)
var duel_target: Combatant = null  ## Schwert: Duell gegen dasselbe Ziel
var duel_stacks := 0         ## Schwert: +10% je Wiederholung (max 4)
var arcane_flow := 0         ## Offensivstab: +6% Zauberkraft je Zauber (max 30)
var mercy_used := false      ## Heiligstab: 1×/Kampf tödlichen Schaden überleben
var mercy_just := false      ## fürs Kampf-Log
var aimed_used := false      ## Armbrust: erster Angriff = garantierter Krit
var armor_shred := 0         ## Stumpf: %-Rüstungs-Abriss-Stacks (auf dem ZIEL, max 50)

const TRAIT_NAMES := {
	&"schwert": ["Duell: +10% je weiterem Angriff aufs selbe Ziel (max +40%)",
		"Duel: +10% per repeated attack on the same target (max +40%)"],
	&"dolch": ["Kombo: +8% Waffenschaden je Angriff (max 5 Stacks)",
		"Combo: +8% weapon damage per attack (max 5 stacks)"],
	&"axt": ["Wut: bis +30% Waffenschaden, je mehr eigene HP fehlen",
		"Rage: up to +30% weapon damage the lower your HP"],
	&"stumpf": ["Zertrümmern: jeder Treffer −5% Rüstung des Ziels (max −50%, für den Kampf)",
		"Crush: every hit shreds 5% of the target's armor (max −50%, for the battle)"],
	&"bogen": ["Volltreffer: +25% gegen Ziele über 90% HP",
		"Opener: +25% against targets above 90% HP"],
	&"armbrust": ["Anvisiert: der erste Angriff im Kampf ist garantiert kritisch",
		"Aimed: the first attack each battle is a guaranteed crit"],
	&"offensivstab": ["Arkaner Fluss: +6% Zauberkraft je gewirktem Zauber (max +30%)",
		"Arcane flow: +6% spell power per spell cast (max +30%)"],
	&"heiligstab": ["Gnade: 1×/Kampf überlebt der Träger tödlichen Schaden mit 1 HP",
		"Mercy: once per battle the wielder survives lethal damage at 1 HP"],
	&"schild": ["Blocken: 20% Chance, physischen Schaden zu halbieren (Einhand) · Turmschild: −15% erlittener Schaden, Angriffe nutzen die RÜSTUNG als Waffe",
		"Block: 20% chance to halve physical damage (one-hand) · tower shield: −15% damage taken, attacks use ARMOR as the weapon"],
}


static func trait_label(family: StringName) -> String:
	if TRAIT_NAMES.has(family):
		return Loc.pick(TRAIT_NAMES[family][0], TRAIT_NAMES[family][1])
	return ""


## Führt der Held das zweihändige Turmschild als Waffe?
func wields_tower_shield() -> bool:
	var weapon: ItemInstance = equipment.get(Enums.EquipSlot.WEAPON)
	return weapon != null and weapon.base.family == &"schild"


## Führt der Held einen EINHAND-Schild in der Nebenhand?
func wields_buckler() -> bool:
	var off: ItemInstance = equipment.get(Enums.EquipSlot.OFF_HAND)
	return off != null and off.base.family == &"schild"


## Eigenheits-Multiplikator für WAFFENANGRIFFE auf `target`.
func trait_weapon_mult(target: Combatant) -> float:
	var mult := 1.0
	match weapon_family():
		&"dolch":
			mult *= 1.0 + combo_stacks * 0.08
		&"schwert":
			if target != null and target == duel_target:
				mult *= 1.0 + duel_stacks * 0.10
		&"axt":
			mult *= 1.0 + 0.30 * (1.0 - float(hp) / maxi(1, max_hp))
		&"bogen":
			if target != null and target.hp >= target.max_hp * 0.9:
				mult *= 1.25
	return mult


## Eigenheits-Multiplikator für ZAUBER (Offensivstab: Arkaner Fluss).
func trait_spell_mult() -> float:
	if weapon_family() == &"offensivstab":
		return 1.0 + arcane_flow / 100.0
	return 1.0


## Nach einem Waffenangriff: Kombo/Duell fortschreiben.
func after_weapon_attack(target: Combatant) -> void:
	match weapon_family():
		&"dolch":
			combo_stacks = mini(5, combo_stacks + 1)
		&"schwert":
			if target == duel_target:
				duel_stacks = mini(4, duel_stacks + 1)
			else:
				duel_target = target
				duel_stacks = 0


## Nach einem gewirkten Zauber: Arkaner Fluss aufbauen.
func after_spell_cast() -> void:
	if weapon_family() == &"offensivstab":
		arcane_flow = mini(30, arcane_flow + 6)


# --- Waffen-Training ------------------------------------------------------------

func invested(family: StringName) -> int:
	return int(weapon_invest.get(family, 0))


## Skillpunkte in eine Waffengattung stecken (unumkehrbar, wie DQ9).
func invest_point(family: StringName, amount := 1) -> bool:
	if skill_points < amount or amount <= 0:
		return false
	skill_points -= amount
	weapon_invest[family] = invested(family) + amount
	return true


## Summe eines Passiv-Typs über die GEFÜHRTEN Gattungen (Haupthand +
## Nebenhand), deren Trainings-Schwellen erreicht sind.
func _training_passive_total(kind: StringName) -> int:
	if weapon_invest.is_empty():
		return 0
	var families: Array[StringName] = []
	var main := weapon_family()
	if main != &"":
		families.append(main)
	var off: ItemInstance = equipment.get(Enums.EquipSlot.OFF_HAND)
	if off != null and off.base.family != &"" and off.base.family not in families:
		families.append(off.base.family)
	var total := 0
	for family in families:
		var points := invested(family)
		for passive in BlockLibrary.passives_for(family):
			if passive["kind"] == kind and points >= int(passive["points"]):
				total += int(passive["magnitude"])
	return total


func training_weapon_mult() -> float:
	return 1.0 + _training_passive_total(&"dmg") / 100.0


func training_spell_mult() -> float:
	return 1.0 + _training_passive_total(&"spell") / 100.0


func training_crit_bonus() -> int:
	return _training_passive_total(&"crit")


func training_armor_percent() -> int:
	return _training_passive_total(&"armor")


func training_mp_percent() -> int:
	return _training_passive_total(&"mp")


# --- Zweites Waffenset -----------------------------------------------------------

## Zweites Waffenset (nur Haupt- und Nebenhand): im Kampf FREI wechselbar,
## um mehr Gegner-Schwächen abzudecken (z.B. Hammer gegen Platte, Bogen
## gegen Flieger). Rüstung/Schmuck bleiben unverändert.
var weapon_set_b: Dictionary = {}  ## EquipSlot » ItemInstance
var active_weapon_set := 0  ## 0 = Set A, 1 = Set B

const _HAND_SLOTS: Array[Enums.EquipSlot] = [
	Enums.EquipSlot.WEAPON, Enums.EquipSlot.OFF_HAND,
]


## Hat das andere Set etwas in der Hand? (Sonst wäre Wechseln = entwaffnen.)
func has_second_weapon_set() -> bool:
	return not weapon_set_b.is_empty()


## Tauscht Haupt-/Nebenhand komplett gegen das andere Set.
func swap_weapon_set() -> void:
	var current := {}
	for slot in _HAND_SLOTS:
		if equipment.has(slot):
			current[slot] = equipment[slot]
			equipment.erase(slot)
	for slot in weapon_set_b:
		equipment[slot] = weapon_set_b[slot]
	weapon_set_b = current
	active_weapon_set = 1 - active_weapon_set
	recompute_derived()


# --- Wiedergeburt (Prestige, ab Level 100) ----------------------------------------

const REBIRTH_LEVEL := 100
var rebirths := 0


func can_rebirth() -> bool:
	return is_player and level >= REBIRTH_LEVEL


## Wiedergeburt: Level, XP und Statuspunkte auf Anfang — Waffen-Training,
## freie Skillpunkte, Skills und Ausrüstung BLEIBEN. So farmt man über
## mehrere Leben die Bäume bis 100 voll (Endlos-Progression).
func rebirth() -> bool:
	if not can_rebirth():
		return false
	rebirths += 1
	level = 1
	xp = 0
	stat_points = 0
	for stat_name in StatBlock.STAT_NAMES:
		stats.set(stat_name, 5)
	recompute_derived()
	hp = max_hp
	mp = max_mp
	return true


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
	combo_stacks = 0
	duel_target = null
	duel_stacks = 0
	arcane_flow = 0
	mercy_used = false
	mercy_just = false
	aimed_used = false
	armor_shred = 0
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
		skill_points += SKILL_POINTS_PER_LEVEL
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
	# Gnade (Heiligstab-Eigenheit): 1×/Kampf tödlichen Schaden überleben.
	if is_player and amount >= hp and not mercy_used \
			and weapon_family() == &"heiligstab":
		mercy_used = true
		mercy_just = true
		amount = hp - 1
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
	var set_b_list: Array = []
	for slot in weapon_set_b:
		set_b_list.append({"slot": int(slot), "item": weapon_set_b[slot].to_dict()})
	var skills_list: Array = []
	for skill in skills:
		skills_list.append(skill.to_dict())
	var invest_dict := {}
	for family in weapon_invest:
		invest_dict[String(family)] = weapon_invest[family]
	return {
		"name": display_name,
		"portrait_tile": portrait_tile,
		"stats": stats.to_dict(),
		"level": level,
		"xp": xp,
		"stat_points": stat_points,
		"skill_points": skill_points,
		"weapon_invest": invest_dict,
		"rebirths": rebirths,
		"weapon_set_b": set_b_list,
		"active_weapon_set": active_weapon_set,
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
	# Waffen-Training: Altbestand ohne das Feld bekommt die Punkte seiner
	# bisherigen Level-Ups rückwirkend gutgeschrieben.
	if data.has("skill_points") or data.has("weapon_invest"):
		combatant.skill_points = int(data.get("skill_points", 0))
	else:
		combatant.skill_points = (combatant.level - 1) * SKILL_POINTS_PER_LEVEL
	for family_str in data.get("weapon_invest", {}).keys():
		# Migration: der alte gemeinsame "stab"-Baum wurde aufgeteilt.
		var family := StringName(family_str) if family_str != "stab" else &"offensivstab"
		combatant.weapon_invest[family] = int(data["weapon_invest"][family_str])
	combatant.rebirths = int(data.get("rebirths", 0))
	combatant.armor = int(data.get("armor", 0))
	combatant.magic_resist = int(data.get("magic_resist", 0))
	for entry in data.get("equipment", []):
		var item := ItemInstance.from_dict(entry.get("item", {}))
		if item != null:
			combatant.equipment[int(entry.get("slot", 0))] = item
	for entry in data.get("weapon_set_b", []):
		var item := ItemInstance.from_dict(entry.get("item", {}))
		if item != null:
			combatant.weapon_set_b[int(entry.get("slot", 0))] = item
	combatant.active_weapon_set = int(data.get("active_weapon_set", 0))
	# recompute_derived() braucht die Ausrüstung, um Max-HP/MP korrekt zu
	# berechnen — danach erst die gespeicherten (ggf. verwundeten) Werte setzen.
	combatant.recompute_derived()
	combatant.hp = int(data.get("hp", combatant.max_hp))
	combatant.mp = int(data.get("mp", combatant.max_mp))
	var loaded_skills: Array[Skill] = []
	for skill_data in data.get("skills", []):
		loaded_skills.append(Skill.from_dict(skill_data))
	combatant.skills = loaded_skills
	combatant.portrait_tile = int(data.get("portrait_tile", -1))
	combatant.sprite = SpriteLib.tile(combatant.portrait_tile) \
		if combatant.portrait_tile >= 0 else SpriteLib.hero(combatant.display_name)
	return combatant


## Stack-basierte Statuseffekte (Phase 3): potency = Stacks, die sich bei
## jedem Treffer AUFADDIEREN. turns = -1 (kein Zeitablauf) — Brand klingt
## über Halbierung pro Tick ab, Gift bleibt bis zur Heilung bestehen.
const STACKING_STATUSES: Array[Enums.Status] = [
	Enums.Status.BURN, Enums.Status.POISON_DOT, Enums.Status.BLEED,
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
