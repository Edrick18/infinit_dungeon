class_name Enums
extends RefCounted
## Zentrale Enums für das gesamte Datenmodell.

## Die drei unabhängigen Schadensachsen. Ein Skill kann beliebig viele davon
## gleichzeitig nutzen (siehe DESIGN.md Abschnitt 4).
enum DamageAxis {
	PHYSICAL,   ## Waffen-/Nahkampfschaden (skaliert typischerweise mit STR)
	MAGICAL,    ## Roher Zauberschaden (skaliert typischerweise mit INT)
	ELEMENTAL,  ## DoT-/Status-lastiger Schaden über Zeit (Brand, Gift, ...)
}

enum Element {
	NONE,
	FIRE,
	ICE,
	LIGHTNING,
	POISON,
	HOLY,
	DARK,
}

## Unterarten des physischen Schadens — Waffen und physische Skill-Bausteine
## haben ein Schadensprofil, Rüstungstypen mindern sie unterschiedlich stark.
enum PhysicalSubtype {
	SLASH,   ## Schnitt (Schwerter, Äxte)
	PIERCE,  ## Stich (Schwerter, Bögen, Dolche)
	BLUNT,   ## Stumpf (Knüppel, Hämmer, Stäbe)
}

## Rüstungstyp eines Rüstungsteils — bestimmt, wie gut es gegen die
## physischen Schadensarten schützt.
enum ArmorClass {
	NONE,     ## Schmuck etc. — Rüstungswert wirkt neutral
	LEATHER,  ## Leder: neutral gegen alles
	CHAIN,    ## Kette: stark gegen Schnitt, schwach gegen Stich/Stumpf
	PLATE,    ## Platte: stark gegen Schnitt/Stich, schwach gegen Stumpf
}

## Schadensquelle eines Skills (Phase-3-Rework): der Schaden kommt aus der
## AUSGERÜSTETEN Waffe, nicht aus dem Baustein.
enum SkillSource {
	WEAPON,  ## Waffennutzung: physisch, Schaden + Art von der Waffe; Zielform fest durch Waffe
	SPELL,   ## Zauber: Zauberschaden der Waffe + INT; Standard Einzelziel-Projektil
}

## Form/Targeting eines Skills. Nur bei Zauber-Quelle wählbar; ohne Form-Baustein
## ist ein Zauber Einzelziel-Projektil, eine Waffennutzung Einzelziel (Waffe entscheidet
## Nahkampf/Fernkampf).
enum SkillForm {
	SINGLE,  ## Standard: ein Gegner (Default, kein Baustein)
	AOE,     ## Alle Gegner
	ALLY,    ## Ein gewählter Verbündeter (gezielte Heilung/Buff)
	AURA,    ## Ganze Party
	SELF,    ## Nur der Anwender
	SUMMON,  ## Beschwörung (kämpft eigenständig mit)
}

enum Status {
	STUN,
	BURN,
	POISON_DOT,
	SLOW,
	WEAKEN,
	LIFESTEAL,
	SHIELD,
	REGEN,
	GUARD,       ## Verteidigungshaltung: reduziert erlittenen Schaden prozentual
	ATK_UP,      ## Buff: erhöht ausgeteilten Schaden prozentual
	DEF_UP,      ## Buff: erhöht Rüstung flach
	MANA_REGEN,  ## Buff: regeneriert MP am Zugbeginn
	PROTECT,     ## Beschützer: fängt ALLE Angriffe auf Verbündete ab (auch Flächen!)
	CLEANSE,     ## Kein echter Status: entfernt beim Anwenden alle Leiden vom Ziel
	REVIVE,      ## Kein echter Status: belebt beim Anwenden gefallene Verbündete wieder
	FROZEN,      ## Eingefroren: setzt aus wie Betäubung; physischer Treffer zerschmettert
	CURSED,      ## Fluch (Dunkel): Ziel nimmt prozentual mehr Schaden
	FOCUS,       ## Konzentriert (DQ-Psyche-Up): nächster Angriff +%, wird verbraucht
}


static func physical_subtype_name(subtype: PhysicalSubtype) -> String:
	match subtype:
		PhysicalSubtype.SLASH: return "Schnitt"
		PhysicalSubtype.PIERCE: return "Stich"
		PhysicalSubtype.BLUNT: return "Stumpf"
	return "?"


static func armor_class_name(armor_class: ArmorClass) -> String:
	match armor_class:
		ArmorClass.LEATHER: return "Leder"
		ArmorClass.CHAIN: return "Kette"
		ArmorClass.PLATE: return "Platte"
	return ""

## Verstärker/Modifikator-Typen für Skill-Bausteine.
enum SkillModifier {
	MULTI_HIT,       ## Trifft mehrfach (magnitude = Anzahl Extra-Treffer)
	COST_REDUCTION,  ## Reduziert MP-Kosten (magnitude = Prozent)
	POWER_AMP,       ## Erhöht Schaden (magnitude = Prozent)
	CHAIN_ON_KILL,   ## Springt bei Kill auf nächstes Ziel über (magnitude = max. Sprünge)
	SPREAD,          ## Single-Target trifft zusätzlich alle anderen (magnitude = Prozent)
	PIERCE_ARMOR,    ## Durchdringung: ignoriert Teil der Rüstung/Resistenz (Prozent)
	EXECUTE,         ## Hinrichtung: Bonus gegen Ziele unter 30% HP (Prozent)
	OVERLOAD,        ## Überladung: mehr Schaden (Prozent), aber +50% MP-Kosten
	VS_UNDEAD,       ## Untotenschreck: Bonus gegen Untote (Prozent)
}

enum EquipSlot {
	WEAPON,
	OFF_HAND,
	HELMET,
	ARMOR,
	GLOVES,
	BOOTS,
	RING_1,
	RING_2,
	AMULET,
}

enum Rarity {
	COMMON,
	MAGIC,
	RARE,
	EPIC,
	LEGENDARY,
}

enum Biome {
	FOREST,
	CAVE,
	RUINS,
	CRYPT,
}

## Bewegungsverhalten der Gegner im begehbaren Dungeon (nicht im Kampf).
enum Temperament {
	AGGRESSIVE,   ## Verfolgt den Spieler immer, sobald in Wahrnehmungsreichweite
	TERRITORIAL,  ## Reagiert nur aus kurzer Distanz, sonst wie AGGRESSIVE
	SKITTISH,     ## Flieht vor deutlich stärkeren Spieler-Parteien, sonst zögerlich
}

## Wie ein Skill-Baustein freigeschaltet wird (DESIGN.md Abschnitt 4).
enum UnlockKind {
	LEVEL,     ## Automatisch ab Charakter-Level
	RESEARCH,  ## Permanent am Forschungstisch gegen Gold
	TRAINING,  ## Waffen-Training: investierte Skillpunkte in einer Gattung
}

enum ConsumableEffect {
	HEAL_HP,        ## Stellt HP wieder her
	RESTORE_MP,     ## Stellt MP wieder her
	CURE_AILMENTS,  ## Entfernt negative Statuseffekte
	REVIVE,         ## Belebt einen Gefallenen wieder (potency = % Max-HP)
}
