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

## Tier bestimmt, ab welcher Dungeon-Kartenstufe dieser Affix droppen kann
## und wie stark seine Werte ausfallen.
@export var tier: int = 1
