class_name Affix
extends Resource
## Ein zufälliger Prefix oder Suffix auf einem generierten Item (Diablo-Stil),
## z.B. "Flammendes ..." oder "... des Sturms".

@export var id: StringName
@export var is_prefix: bool = true

## Namensteil: Prefixe vor dem Item-Namen ("Flammendes Schwert"),
## Suffixe dahinter ("Schwert des Sturms").
@export var name_part: String

## Attribut-Boni dieses Affixes.
@export var stat_bonus: StatBlock

## Direkte Kampfwert-Boni (unabhängig von Attributen).
@export var bonus_damage: int = 0
@export var bonus_armor: int = 0

## Zauberkraft-Bonus (für Stäbe/Foki — skaliert wie Waffenschaden mit dem Item-Level).
@export var bonus_spell_damage: int = 0

## Element-Achse: `element` bestimmt, worauf sich Rider und Resistenz beziehen.
## element_damage > 0 → Waffen-Rider: jeder Waffennutzungs-Treffer trägt
## zusätzlich diesen Elementschaden (inkl. Signatur: Brand-Stacks, Fluch, …).
## element_resist > 0 → flache Minderung gegen dieses Element; mit
## element == NONE wirkt die Resistenz gegen ALLE Elemente.
@export var element: Enums.Element = Enums.Element.NONE
@export var element_damage: int = 0
@export var element_resist: int = 0

## Flache MP-Kosten-Reduktion für alle Skills des Trägers (Skill-Suffix).
@export var mp_cost_reduction: int = 0

## Auf welchen Slots dieser Affix rollen darf (leer = überall).
## Element-Rider gehören auf Waffen, Resistenzen auf Rüstung/Schmuck.
@export var allowed_slots: Array[Enums.EquipSlot] = []

## Tier bestimmt, ab welcher Dungeon-Kartenstufe dieser Affix droppen kann
## und wie stark seine Werte ausfallen.
@export var tier: int = 1
