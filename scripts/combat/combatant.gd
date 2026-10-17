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
var sprite_scale := 1.0  ## Anzeige-Skalierung im Kampf (Koenig-Schleim & Co.)
## Bei der Erstellung gewähltes Helden-Porträt (Kenney-Tile-Index).
## -1 = Altbestand: Porträt kommt über den Namen (SpriteLib.hero).
var portrait_tile := -1
var level := 1  ## Bestimmt u.a. Skill-Slots (1 + Level/5) und Baustein-Freischaltung
var xp := 0
var stat_points := 0  ## Noch nicht verteilte Statuspunkte

## Waffen-Training (DQ9-Stil): freie Skillpunkte (+3 pro Level-Up) werden
## pro Waffengattung investiert und schalten Technik-Bausteine frei.
## Waffen-Training (Lutz 2026-10-15): 2 Punkte je Level, auf Level 50 und 100
## je einer extra — genau 200 Punkte bis Level 100 = zwei volle Bäume.
const SKILL_POINTS_PER_LEVEL := 2
## Meisterschafts-Rolle: wer einen Baum auf 100 bringt, darf dessen Rolle in
## den Meisterschafts-Slot legen — sie wirkt mit JEDER Waffe.
var meisterschaft: StringName = &""
const MEISTER_PARADE := 20       ## Klingenmeister: +20 % Parade
const MEISTER_KRIT := 2.5        ## Adlerauge: Krits ×2,5
const MEISTER_DURCHSCHLAG := 0.3 ## Belagerer: +30 % Rüstungsdurchschlag
const MEISTER_SCHLAECHTER := 1.5 ## Schlächter: ×1,5 gegen Ziele unter 50 % HP
const MEISTERSCHAFTEN := {
	&"schwert": ["Klingenmeister", "Blade master", "+20 % Parade gegen Nahkampf — mit jeder Waffe", "+20% parry vs melee — with any weapon"],
	&"dolch": ["Schattentänzer", "Shadow dancer", "Jeder Waffenangriff schlägt einmal mehr zu", "Every weapon attack strikes once more"],
	&"axt": ["Schlächter", "Butcher", "×1,5 Schaden gegen Ziele unter 50 % HP", "×1.5 damage vs targets below 50% HP"],
	&"stumpf": ["Erdbrecher", "Earthbreaker", "+15 % Betäubung je Treffer und Rüstung aufreißen — mit jeder Waffe, stapelt mit dem Hammer", "+15% stun per hit and armor shred — with any weapon, stacks with the hammer"],
	&"bogen": ["Adlerauge", "Eagle eye", "Kritische Treffer ×2,5 statt ×1,5", "Critical hits ×2.5 instead of ×1.5"],
	&"armbrust": ["Belagerer", "Besieger", "Waffenangriffe ignorieren 30 % mehr Rüstung", "Weapon attacks ignore 30% more armor"],
	&"offensivstab": ["Erzmagier", "Archmage", "Element-Signaturen +50 % (stapelt mit dem Stab)", "Element signatures +50% (stacks with the staff)"],
	&"heiligstab": ["Heiliger", "Saint", "Heilung +50 % (stapelt mit dem Stab)", "Healing +50% (stacks with the staff)"],
	&"schild": ["Bollwerk", "Bulwark", "+25 % Block-Chance — auch ohne Schild, stapelt mit dem Schild", "+25% block chance — even without a shield, stacks with the shield"],
}
var skill_points := 0
var weapon_invest: Dictionary = {}  ## Gattung » investierte Punkte

var max_hp := 1
var hp := 1
var max_mp := 0
var mp := 0

## Natürliche Rüstung/Magieresistenz. Gegner: PUNKTE (typisch 0-6), die im
## Kampf mit ihrem Level wachsen (natuerliche_einheit). Helden: 0, ihre
## Rüstung kommt aus der Ausrüstung. Elementarschaden (DoT) ignoriert beides.
var armor := 0
var magic_resist := 0

## Rüstung und Magieresistenz mindern PROZENTUAL (Lutz: alles in Prozent):
## Minderung = Wert ÷ (Wert + K), K wächst mit dem Level des Angreifers.
## Vorher flacher Abzug: Heldenrüstung wuchs mit dem Gear und schluckte ab
## Level 30 jeden Boss-Hieb komplett, Gegnerrüstung schluckte auf Level 100
## nur 1 % — Wappnen, Rüstungsriss, Durchschlag und Rüstungsklassen waren
## wirkungslos. Jetzt: schwer gerüsteter Tank ~50 % auf gleichem Level,
## Gegner mit 5 Rüstungspunkten ~26 %, Golem im Steinpanzer ~47 %.
const RUESTUNG_K := 8.0
const RUESTUNG_K_OFFSET := 5
const GEGNER_PUNKT := 0.55      ## ein Rüstungspunkt eines Gegners, relativ zu K/8
const MINDERUNG_MAX := 0.9


static func ruestung_k(angreifer_level: int) -> float:
	var stufe := maxi(1, angreifer_level)
	return RUESTUNG_K * (stufe + RUESTUNG_K_OFFSET) * Scaling.factor(stufe)


## Anteil, den `wert` (Rüstung bzw. Magieresistenz) gegen einen Angreifer
## dieses Levels abfängt (0 bis 0,9).
static func minderung(wert: float, angreifer_level: int) -> float:
	if wert <= 0.0:
		return 0.0
	return minf(MINDERUNG_MAX, wert / (wert + ruestung_k(angreifer_level)))


## Wert eines natürlichen Rüstungs-/Resistenzpunkts: Gegner wachsen mit
## ihrem Level mit, Helden (Rüstung aus dem Gear) zählen 1:1.
func natuerliche_einheit() -> float:
	if is_player:
		return 1.0
	return GEGNER_PUNKT * (maxi(1, level) + RUESTUNG_K_OFFSET) * Scaling.factor(level)

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
## Bosse: wächst mit jeder gelungenen Betäubung/Vereisung (Battle.kontrolle_gelingt).
var kontroll_resistenz := 0.0
## Gegner: Element » Schadensfaktor (1.5 schwach, 0.5 resistent), aus dem
## Archetyp + Element-Schicht (EnemyFactory). Spieler: leer.
var element_faktoren: Dictionary = {}


func element_faktor(element: Enums.Element) -> float:
	return float(element_faktoren.get(element, 1.0))


## Schlüssel fürs Element-Wissen der Spieler: Grundtyp, bei Element-Schicht
## mit Element ("wolf@0"), weil ein Feuer-Wolf anders reagiert als ein Wolf.
func wissens_schluessel() -> String:
	if archetype_id == &"":
		return ""
	if has_meta(&"element_schicht"):
		return "%s@%d" % [archetype_id, int(get_meta(&"element_schicht"))]
	return String(archetype_id)
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
## Gegner-Eigenheit (Eigenheiten.gd) — nur normale Gegner, Bosse haben Signaturen.
var eigenheit: StringName = &""
var eigenheit_verbraucht := false  ## Einmal-Eigenheiten (Wiederkehr, Neun Leben …)
var eigenheit_zaehler := 0
## Faktor auf alle MP-Kosten (Sonderregel Manaflut) — setzt die Kampfszene.
var kosten_mult := 1.0
var summoner: Combatant = null
var summon_turns_left := 0

## Innewohnende Waffenwerte für Gegner (sie tragen keine Items). Bei Spielern 0 —
## dort kommen die Werte aus der Ausrüstung (weapon_damage()/spell_damage()).
var innate_weapon_damage := 0
var innate_spell_damage := 0
var innate_weapon_subtypes: Array[Enums.PhysicalSubtype] = [Enums.PhysicalSubtype.BLUNT]
var innate_hit_count := 1  ## z.B. Skelett-Bogenschütze: 2 Pfeile pro Angriff

## Ausgerüstete Skills: die ersten skill_slots() Einträge sind im Kampf nutzbar.
var skills: Array[Skill] = []
## Deckel für Prozent-Boni der Ausrüstung (Element-Resistenz, MP-Ersparnis).
const ELEMENT_RESIST_MAX := 60
const MP_ERSPARNIS_MAX := 50
## Rezeptbuch: beliebig viele gespeicherte Bauten, die gerade NICHT in einem
## Slot stecken — in der Werkstatt jederzeit gegen einen Slot tauschbar.
var rezeptbuch: Array[Skill] = []

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
## Kampf-Stats, die bei SPIELERN auf der Welt-Wachstumskurve reiten —
## Gegner-Stats werden in der Factory mit derselben Kurve multipliziert;
## ohne das Gegenstück kippen gleichstufige Kämpfe ab ~Stufe 25 (Sim).
## AGI/LCK bleiben draußen: Zugreihenfolge und Krit sind Relativwerte.
const _SCALED_STATS: Array[StringName] = [
	&"strength", &"intelligence", &"vitality", &"spirit",
]


## Attribut OHNE Welt-Skalierung (Basis + Ausrüstung) — für Prozent-Boni,
## die sonst mit dem Level explodieren würden.
func stat_roh(stat_name: StringName) -> int:
	var total: int = stats.get(stat_name)
	for slot in equipment:
		var item: ItemInstance = equipment[slot]
		total += item.get_total_stat_bonus().get(stat_name)
	return roundi(total * wiedergeburt_faktor())


func stat(stat_name: StringName) -> int:
	var total: int = stats.get(stat_name)
	for slot in equipment:
		var item: ItemInstance = equipment[slot]
		total += item.get_total_stat_bonus().get(stat_name)
	var faktor := wiedergeburt_faktor()
	if is_player and stat_name in _SCALED_STATS:
		faktor *= Scaling.factor(level)
	return roundi(total * faktor)


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
	Enums.ArmorClass.FELL: {
		Enums.PhysicalSubtype.SLASH: 1.25,
		Enums.PhysicalSubtype.PIERCE: 0.6,
		Enums.PhysicalSubtype.BLUNT: 1.0,
	},
	Enums.ArmorClass.KNOCHEN: {
		Enums.PhysicalSubtype.SLASH: 1.0,
		Enums.PhysicalSubtype.PIERCE: 1.5,
		Enums.PhysicalSubtype.BLUNT: 0.5,
	},
}

## Rüstungsklasse der NATÜRLICHEN Rüstung (Gegner: Fell, Knochen, Platte …;
## Helden: keine — ihre Klassen stecken in den Rüstungsteilen).
var natur_klasse: Enums.ArmorClass = Enums.ArmorClass.NONE


## Neutraler Gesamt-Rüstungswert (für Anzeigen).
func total_armor() -> int:
	var total := maxi(0, armor) * natuerliche_einheit()
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
	var total: float = maxi(0, armor) * natuerliche_einheit() * float(ARMOR_CLASS_MULT[natur_klasse][subtype])
	for slot in equipment:
		var item: ItemInstance = equipment[slot]
		total += item.get_total_armor() * ARMOR_CLASS_MULT[item.base.armor_class][subtype]
	var def_up := get_status(Enums.Status.DEF_UP)
	if not def_up.is_empty():
		total *= 1.0 + def_up["potency"] / 100.0  # Wappnen: Prozent, skaliert mit
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


## Magieschutz der Rüstungsteile je Klasse (Lutz 2026-10-16): seit Rüstung
## prozentual mindert, waren Zauber-Bosse die tödlichsten (Helden hatten 0
## Magieresistenz). Platte schützt am besten vor Waffen und am schlechtesten
## vor Magie, Roben umgekehrt — ein echter Tausch beim Ausrüsten.
const MAGIE_KLASSE_FAKTOR := {
	Enums.ArmorClass.NONE: 4.0,      # Roben (Schmuck hat 0 Rüstung → 0)
	Enums.ArmorClass.LEATHER: 1.2,
	Enums.ArmorClass.CHAIN: 0.6,
	Enums.ArmorClass.PLATE: 0.4,
}


func total_magic_resist() -> int:
	var total := maxi(0, magic_resist) * natuerliche_einheit()
	for slot in equipment:
		var item: ItemInstance = equipment[slot]
		total += item.get_total_armor() * float(MAGIE_KLASSE_FAKTOR.get(item.base.armor_class, 0.0))
	return roundi(total)


## Magieschutz, den ein einzelnes Rüstungsteil gibt (Item-Karte).
static func magieschutz_von(item: ItemInstance) -> int:
	return roundi(item.get_total_armor() * float(MAGIE_KLASSE_FAKTOR.get(item.base.armor_class, 0.0)))


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
## Element-Resistenz der Ausrüstung in Prozent (höchstens ELEMENT_RESIST_MAX).
func element_resist(element: Enums.Element) -> int:
	var total := 0
	for slot in equipment:
		var item: ItemInstance = equipment[slot]
		total += item.get_element_resist(element)
	return mini(total, ELEMENT_RESIST_MAX)


## MP-Kosten-Ersparnis aus Skill-Affixen in Prozent (höchstens MP_ERSPARNIS_MAX).
func mp_cost_reduction() -> int:
	var total := 0
	for slot in equipment:
		var item: ItemInstance = equipment[slot]
		total += item.get_mp_cost_reduction()
	return mini(total, MP_ERSPARNIS_MAX)


## HP/MP neu ableiten (nach Ausrüstungswechsel oder Level-Up).
func recompute_derived() -> void:
	# VIT/SPI sind bei Spielern bereits welt-skaliert (siehe stat()) —
	# HP/MP wachsen dadurch automatisch exponentiell mit dem Level.
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
## Schießt dieser Kämpfer (Bogen/Armbrust, Gegner-Bogenschützen)? Für die
## Kampf-Effekte: Fernkampf fliegt als Projektil, Nahkampf ist ein Hieb.
func fernkampf() -> bool:
	var waffe: ItemInstance = equipment.get(Enums.EquipSlot.WEAPON)
	if waffe != null:
		return waffe.base.ranged
	return innate_hit_count > 1


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


# --- Waffen-Besonderheiten (Skillbau 3.0) ---------------------------------------
# Jede Gattung hat EINE starke Besonderheit, die immer wirkt, solange die Waffe
# geführt wird — sie macht DENSELBEN Skill je nach Waffe anders (Lutz: „Dolch
# doppelt so viele Angriffe, Axt doppelt so hart aber eine Runde Erholung,
# Bogen Krit + Schwachstelle = 4×“). Umgesetzt in Battle._waffen_treffer /
# _deal_damage; hier nur Zustand + Texte.

const DOLCH_TREFFER := 0.6         ## Zwillingsklinge: jeder Treffer doppelt, je 60 %
const AXT_WUCHT := 2.0             ## Wucht: doppelter Schaden, danach erschöpft
const BOGEN_SCHWACHSTELLE := 15    ## Schwachstellen-Chance in % (+ Glück)
## Zwei Pfeile, je 60 % (wie die Zwillingsklinge). Früher volle 2 × Schaden —
## der Preis war die flache Rüstung PRO Pfeil; seit Rüstung prozentual mindert,
## fiel der Preis weg und der Bogen legte Bosse doppelt so schnell wie jede
## andere Waffe (Waffen-Matrix).
const BOGEN_PFEIL := 0.6
const ARMBRUST_DURCHSCHLAG := 0.5  ## ignoriert die halbe Rüstung
const ARMBRUST_NACHTREFFER := 0.4  ## der Bolzen trifft dahinter noch einen Gegner
const SCHWERT_PARADE := 20         ## % Chance, Nahkampftreffer abzuwehren
const SCHWERT_RIPOSTE := 0.5       ## Gegenschlag nach Parade (Anteil Waffenschaden)
const STUMPF_BETAEUBUNG := 15      ## % Betäubung je Treffer
const STAB_SIGNATUR := 1.5         ## Offensivstab: Element-Signaturen +50 %
const HEILIGSTAB_HEILUNG := 1.5    ## Heiligstab: Heilung +50 %
const SCHILD_BLOCK := 25           ## % Chance, physischen Schaden zu halbieren

var duel_target: Combatant = null  ## zuletzt selbst getroffenes Ziel (Duellstoß)
var mercy_used := false      ## Heiligstab: 1×/Kampf tödlichen Schaden überleben
var mercy_just := false      ## fürs Kampf-Log
var armor_shred := 0         ## Stumpf: %-Rüstungs-Abriss-Stacks (auf dem ZIEL, max 50)

const TRAIT_NAMES := {
	&"dolch": ["Zwillingsklinge: jeder Treffer kommt doppelt (je 60 %) — Gift und Effekte würfeln pro Treffer",
		"Twin blade: every hit lands twice (60 % each) — poison and effects roll per hit"],
	&"axt": ["Wucht: doppelter Schaden, danach erschöpft — der nächste eigene Zug fällt aus",
		"Heft: double damage, then exhausted — your next own turn is skipped"],
	&"bogen": ["Schwachstellen: 15 % Chance (+ Glück) auf ×2 — zusammen mit einem Krit ein VOLLTREFFER ×4",
		"Weak spots: 15 % chance (+ luck) for ×2 — together with a crit a BULLSEYE ×4"],
	&"armbrust": ["Durchschlag: ignoriert die halbe Rüstung, der Bolzen trifft dahinter noch einen Gegner (40 %)",
		"Punch-through: ignores half the armor, the bolt also hits another enemy behind (40 %)"],
	&"schwert": ["Parade: 20 % Chance, einen Nahkampftreffer abzuwehren und sofort zurückzuschlagen",
		"Parry: 20 % chance to deflect a melee hit and strike back at once"],
	&"stumpf": ["Erschütterung: jeder Treffer 15 % Betäubung und −5 % Rüstung des Ziels (bis −50 %)",
		"Concussion: every hit 15 % stun and −5 % of the target's armor (down to −50 %)"],
	&"offensivstab": ["Elementarmeister: Element-Signaturen (Brand, Frost, Blitzsprung, Fluch …) +50 %",
		"Elementalist: element signatures (burn, frost, lightning jump, curse …) +50 %"],
	&"heiligstab": ["Segen: Heilung +50 % — und einmal pro Kampf überlebt der Träger einen tödlichen Treffer",
		"Blessing: healing +50 % — and once per battle the wielder survives a lethal hit"],
	&"schild": ["Block: 25 % Chance, physischen Schaden zu halbieren (Einhand) · Turmschild: −15 % erlittener Schaden, Angriffe nutzen die RÜSTUNG als Waffe",
		"Block: 25 % chance to halve physical damage (one-hand) · tower shield: −15 % damage taken, attacks use ARMOR as the weapon"],
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


## Skillpunkte für den Aufstieg AUF `stufe`: 2, auf Level 50 und 100 je 3.
static func skill_punkte_fuer_level(stufe: int) -> int:
	return SKILL_POINTS_PER_LEVEL + (1 if stufe == 50 or stufe == 100 else 0)


## Alle Skillpunkte, die ein Held bis `stufe` bekommen hat (Level 1 = 0).
static func skill_punkte_bis(stufe: int) -> int:
	var summe := 0
	for l in range(2, stufe + 1):
		summe += skill_punkte_fuer_level(l)
	return summe


## Meisterschaft aktiv? Die Rolle muss im Slot liegen UND der Baum auf 100 sein.
func meister(family: StringName) -> bool:
	return meisterschaft == family and invested(family) >= 100


## Meisterschaften, die der Held freigeschaltet hat (Baum auf 100).
func meisterschaften_frei() -> Array[StringName]:
	var result: Array[StringName] = []
	for family in MEISTERSCHAFTEN:
		if invested(family) >= 100:
			result.append(family)
	return result


static func meisterschaft_name(family: StringName) -> String:
	var m: Array = MEISTERSCHAFTEN.get(family, [])
	return Loc.pick(m[0], m[1]) if not m.is_empty() else ""


static func meisterschaft_text(family: StringName) -> String:
	var m: Array = MEISTERSCHAFTEN.get(family, [])
	return Loc.pick(m[2], m[3]) if not m.is_empty() else ""


## Parade-Chance in %: Schwert-Besonderheit + Meisterschaft „Klingenmeister“.
func parade_chance() -> int:
	var chance := SCHWERT_PARADE if weapon_family() == &"schwert" else 0
	if meister(&"schwert"):
		chance += MEISTER_PARADE
	return chance


## Block-Chance in %: Einhand-Schild + Meisterschaft „Bollwerk“.
func block_chance() -> int:
	var chance := SCHILD_BLOCK if wields_buckler() else 0
	if meister(&"schild"):
		chance += SCHILD_BLOCK
	return chance


## Betäubungs-Chance je physischem Treffer: Hammer + Meisterschaft „Erdbrecher“.
func betaeubungs_chance() -> int:
	var chance := STUMPF_BETAEUBUNG if weapon_family() == &"stumpf" else 0
	if meister(&"stumpf"):
		chance += STUMPF_BETAEUBUNG
	return chance


## Heil-Faktor aus Heiligstab-Besonderheit und Meisterschaft „Heiliger“.
func heil_faktor() -> float:
	var faktor := HEILIGSTAB_HEILUNG if weapon_family() == &"heiligstab" else 1.0
	if meister(&"heiligstab"):
		faktor *= HEILIGSTAB_HEILUNG
	return faktor


## Grund-Schwachstellenchance (Bogen-Besonderheit, Glück hilft mit).
func schwachstellen_chance() -> int:
	if weapon_family() == &"bogen":
		return BOGEN_SCHWACHSTELLE + luck_crit_bonus(stat(&"luck")) / 3
	return 0

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
## +10 % auf alle Werte je Wiedergeburt (Lutz 2026-10-16) — auf Grundwerte
## und Ausrüstungs-Boni, für Helden. Ersetzt den früheren +1 Statuspunkt je
## Level und Wiedergeburt.
const WIEDERGEBURT_BONUS := 0.10
var rebirths := 0


func wiedergeburt_faktor() -> float:
	return 1.0 + WIEDERGEBURT_BONUS * rebirths if is_player else 1.0
## Höchstes je erreichtes Level (überlebt die Wiedergeburt) — daran hängen
## die Skill-Slots, damit gebaute Skills nach dem Neustart nutzbar bleiben.
var peak_level := 1


func can_rebirth() -> bool:
	return is_player and level >= REBIRTH_LEVEL


## Wiedergeburt: Level, XP und Statuspunkte auf Anfang — Waffen-Training,
## freie Skillpunkte, Skills und Ausrüstung BLEIBEN. So farmt man über
## mehrere Leben die Bäume bis 100 voll (Endlos-Progression).
func rebirth() -> bool:
	if not can_rebirth():
		return false
	rebirths += 1
	peak_level = maxi(peak_level, level)
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


## Skill-Slots hängen am LEBENSZEIT-Maximum, nicht am aktuellen Level —
## sonst nähme die Wiedergeburt gebaute Skills weg (fühlt sich wie Strafe an).
func skill_slots() -> int:
	return CharacterDef.skill_slots_for_level(maxi(level, peak_level))


## Sockel pro Skill (Baukasten 2.0) — hängt am höchsten Level, damit gebaute
## Skills nach der Wiedergeburt nutzbar bleiben.
func block_sockets() -> int:
	return CharacterDef.block_sockets_for(maxi(level, peak_level), rebirths) \
		+ (1 if regelbruch(&"sockel") else 0)


## Trägt der Held einen Regelbrecher-Affix dieser Art (Affix.regelbruch)?
func regelbruch(art: StringName) -> bool:
	for slot in equipment:
		var item: ItemInstance = equipment[slot]
		if item == null:
			continue
		for affix in item.affixes:
			if affix.regelbruch == art:
				return true
	return false


## Statuspunkte pro Level-Up: Basis 5 — und ab Level
## 100 wächst der Strom pro Level weiter (+2% je Level darüber, User-
## Design): flat würde relativ zur Exponential-Welt bedeutungslos, und
## die Endgame-Schere der Gegner (EnemyFactory.brutal_faktor) will mit
## Punkten, Training, Affixen und Wiedergeburten geschlossen werden.
static func stat_points_for_level(at_level: int, _at_rebirths := 0) -> int:
	var base := POINTS_PER_LEVEL
	if at_level <= 100:
		return base
	return roundi(base * (1.0 + (at_level - 100) * 0.02))


func stat_points_per_level() -> int:
	return stat_points_for_level(level, rebirths)


## Glück » Kritchance mit ABNEHMENDEM Ertrag (Asymptote 45%) — statt
## „95 Glück = 100% Krit“: 30 Glück » +15%, 60 » +22%, 120 » +30%.
static func luck_crit_bonus(luck: int) -> int:
	return roundi(45.0 * luck / (luck + 60.0))


## Umskillen (gegen Gold, die UI kassiert): alle verteilten Statuspunkte
## zurück in den freien Pool, Attribute auf die Basis 5 — dieselbe Basis
## wie nach der Wiedergeburt.
func respec() -> int:
	if not is_player:
		return 0
	var refunded := 0
	for stat_name in StatBlock.STAT_NAMES:
		var invested: int = stats.get(stat_name) - 5
		if invested > 0:
			refunded += invested
			stats.set(stat_name, 5)
	stat_points += refunded
	recompute_derived()
	hp = mini(hp, max_hp)
	mp = mini(mp, max_mp)
	return refunded


## Kampfvorbereitung: Statuseffekte weg; volle Heilung nur außerhalb von
## Dungeon-Runs (im Dungeon herrscht Attrition — Wunden bleiben).
func reset_for_battle(full_heal := true) -> void:
	kontroll_resistenz = 0.0
	duel_target = null
	mercy_used = false
	mercy_just = false
	armor_shred = 0
	statuses.clear()
	if full_heal:
		recompute_derived()
		hp = max_hp
		mp = max_mp


## XP-Schwelle für den nächsten Level-Up: quadratische Grundkurve × ein
## wachsender Faktor (Lutz 2026-10-15). Die XP eines Kampfs wird auf die
## Party geteilt; mit 4 Helden bringt ein Lauf auf eigener Stufe ~+4 Level
## auf 10-20, ~+2 auf 50, ~+0,7 auf 100, ~+0,3 auf 200. Belohnungskarten
## steigen ~2,5 Stufen pro Lauf — bis ~Stufe 45 hält man mit, AB STUFE 50
## BEGINNT DER GRIND. Wer einen Helden gezielt leveln will, setzt den Rest
## auf die Bank (er bekommt dann die ganze XP).
const XP_KURVE_FAKTOR := 0.42
const XP_KURVE_EXPONENT := 1.15
const XP_KURVE_MIN := 0.22


static func xp_bedarf(stufe: int) -> int:
	var basis := 40 + 20 * stufe + 3 * stufe * stufe
	var faktor := maxf(XP_KURVE_MIN, XP_KURVE_FAKTOR * pow(stufe / 10.0, XP_KURVE_EXPONENT))
	return maxi(1, roundi(basis * faktor))


func xp_to_next() -> int:
	return xp_bedarf(level)


## XP sammeln, ggf. mehrfach aufleveln (kein Cap). Jedes Level gibt
## stat_points_per_level() frei verteilbare Statuspunkte und heilt voll
## (klassisches JRPG-Gefühl). Gibt die Anzahl Level-Ups zurück.
func gain_xp(amount: int) -> int:
	if not is_player:
		return 0
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		peak_level = maxi(peak_level, level)
		gained += 1
		stat_points += stat_points_per_level()
		skill_points += skill_punkte_fuer_level(level)
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
	var buch_list: Array = []
	for skill in rezeptbuch:
		buch_list.append(skill.to_dict())
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
		"meisterschaft": String(meisterschaft),
		"weapon_invest": invest_dict,
		"rebirths": rebirths,
		"peak_level": peak_level,
		"weapon_set_b": set_b_list,
		"active_weapon_set": active_weapon_set,
		"hp": hp,
		"mp": mp,
		"armor": armor,
		"magic_resist": magic_resist,
		"equipment": equip_list,
		"skills": skills_list,
		"rezeptbuch": buch_list,
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
		combatant.skill_points = skill_punkte_bis(combatant.level)
	for family_str in data.get("weapon_invest", {}).keys():
		# Migration: der alte gemeinsame "stab"-Baum wurde aufgeteilt.
		var family := StringName(family_str) if family_str != "stab" else &"offensivstab"
		combatant.weapon_invest[family] = int(data["weapon_invest"][family_str])
	combatant.rebirths = int(data.get("rebirths", 0))
	combatant.meisterschaft = StringName(data.get("meisterschaft", ""))
	# Alte Spielstände kennen peak_level nicht » mindestens das aktuelle Level.
	combatant.peak_level = maxi(int(data.get("peak_level", 1)), combatant.level)
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
	for skill_data in data.get("rezeptbuch", []):
		combatant.rezeptbuch.append(Skill.from_dict(skill_data))
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


## Buffs/Debuffs mit Stufen (wie DQ9): der zweite Zauber hebt auf Stufe 2
## (doppelte Wirkung) und frischt die Dauer auf, jeder weitere frischt nur
## noch auf. Gilt für Effekte aus Klötzen — Boss-Phasen setzen ihre
## Stärkung direkt über add_status und zählen hier als Stufe 0.
const STUFEN_STATUS: Array[Enums.Status] = [Enums.Status.ATK_UP, Enums.Status.DEF_UP,
	Enums.Status.MAGIE_SCHUTZ, Enums.Status.ELEMENT_SCHUTZ, Enums.Status.WEAKEN,
	Enums.Status.ARMOR_BREAK, Enums.Status.SLOW, Enums.Status.MAGIE_BRUCH,
	Enums.Status.ELEMENT_SCHWAECHE]
const STUFEN_MAX := 2
## Obergrenze der Gesamtwirkung in % — Stufe 2 soll stark sein, nicht alles aushebeln.
const STUFEN_DECKEL := {Enums.Status.ATK_UP: 60, Enums.Status.DEF_UP: 100,
	Enums.Status.MAGIE_SCHUTZ: 50, Enums.Status.ELEMENT_SCHUTZ: 50, Enums.Status.WEAKEN: 60,
	Enums.Status.ARMOR_BREAK: 75, Enums.Status.SLOW: 60, Enums.Status.MAGIE_BRUCH: 60,
	Enums.Status.ELEMENT_SCHWAECHE: 60}


## Setzt einen Stufen-Effekt oder hebt ihn eine Stufe an. element: nur für
## die Elementschwäche (−1 = alle Elemente). Gibt die neue Stufe zurück.
func stufen_status_setzen(status: Enums.Status, turns: int, potency: int, element := -1) -> int:
	var eintrag := {}
	for entry in statuses:
		if entry["status"] == status and int(entry.get("element", -1)) == element:
			eintrag = entry
			break
	if eintrag.is_empty():
		eintrag = {"status": status, "turns": turns, "potency": 0, "basis": potency, "element": element}
		statuses.append(eintrag)
	eintrag["basis"] = maxi(int(eintrag.get("basis", 0)), potency)
	eintrag["stufe"] = mini(STUFEN_MAX, int(eintrag.get("stufe", 0)) + 1)
	var gesamt: int = eintrag["basis"] * eintrag["stufe"]
	eintrag["potency"] = mini(gesamt, int(STUFEN_DECKEL.get(status, gesamt)))
	eintrag["turns"] = maxi(int(eintrag["turns"]), turns)
	return eintrag["stufe"]


## Magieschild (−%) und Magiebruch (+%) auf erlittenen Magieschaden.
func magie_schaden_faktor() -> float:
	var faktor := 1.0
	var schutz := get_status(Enums.Status.MAGIE_SCHUTZ)
	if not schutz.is_empty():
		faktor *= 1.0 - schutz["potency"] / 100.0
	var bruch := get_status(Enums.Status.MAGIE_BRUCH)
	if not bruch.is_empty():
		faktor *= 1.0 + bruch["potency"] / 100.0
	return faktor


## Elementschutz (−%, alle Elemente) und Elementschwäche (+% für ihr
## Element; ohne Element im Zauber gilt sie für alle mit halber Wirkung).
func element_status_faktor(element: Enums.Element) -> float:
	var faktor := 1.0
	for entry in statuses:
		match entry["status"]:
			Enums.Status.ELEMENT_SCHUTZ:
				faktor *= 1.0 - entry["potency"] / 100.0
			Enums.Status.ELEMENT_SCHWAECHE:
				var e := int(entry.get("element", -1))
				if e == int(element):
					faktor *= 1.0 + entry["potency"] / 100.0
				elif e == -1:
					faktor *= 1.0 + entry["potency"] / 200.0
	return faktor


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
