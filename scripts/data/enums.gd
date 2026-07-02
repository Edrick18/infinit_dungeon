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

## Träger/Form eines Skills — bestimmt im rundenbasierten Kampf das Targeting.
enum Carrier {
	PROJECTILE,  ## Ein Ziel, Fernangriff
	MELEE,       ## Ein Ziel, Nahkampf
	AOE,         ## Alle Gegner
	AURA,        ## Selbst / alle Verbündeten
	SUMMON,      ## Beschwörung (kämpft eigenständig mit)
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
}

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
