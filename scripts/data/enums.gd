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

## Träger/Form eines Skills — bestimmt im rundenbasierten Kampf das Targeting.
enum Carrier {
	PROJECTILE,  ## Ein Ziel, Fernangriff
	MELEE,       ## Ein Ziel, Nahkampf
	AOE,         ## Alle Gegner
	AURA,        ## Selbst / alle Verbündeten
	SUMMON,      ## Beschwörung (kämpft eigenständig mit)
	SELF,        ## Nur der Anwender selbst (z.B. Schutzwall)
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
	PROTECT,     ## Beschützer: fängt Einzelziel-Angriffe auf Verbündete ab
	CLEANSE,     ## Kein echter Status: entfernt beim Anwenden alle Leiden vom Ziel
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
	CHAIN_ON_KILL,   ## Springt bei Kill auf nächstes Ziel über
	SPREAD,          ## Single-Target trifft zusätzlich Nachbarn (abgeschwächt)
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

## Wie ein Skill-Baustein freigeschaltet wird (DESIGN.md Abschnitt 4).
enum UnlockKind {
	LEVEL,     ## Automatisch ab Charakter-Level
	RESEARCH,  ## Permanent am Forschungstisch gegen Gold
}

enum ConsumableEffect {
	HEAL_HP,        ## Stellt HP wieder her
	RESTORE_MP,     ## Stellt MP wieder her
	CURE_AILMENTS,  ## Entfernt negative Statuseffekte
	REVIVE,         ## Belebt einen Gefallenen wieder (potency = % Max-HP)
}
