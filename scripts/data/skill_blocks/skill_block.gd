class_name SkillBlock
extends Resource
## Basisklasse für alle Skill-Bausteine ("Bauklötze").
## Ein Skill besteht aus genau einem Träger-Baustein plus beliebig vielen
## Schadens-, Effekt- und Modifikator-Bausteinen (siehe Skill.is_valid()).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

## Grundkosten in MP, die dieser Baustein zum Skill beiträgt.
@export var mp_cost: int = 0

## Freischaltung: Basis-Bausteine über Level, spezielle über Forschung (Gold).
@export var unlock_kind: Enums.UnlockKind = Enums.UnlockKind.LEVEL
@export var unlock_level: int = 1        ## Nur relevant bei UnlockKind.LEVEL
@export var research_cost_gold: int = 0  ## Nur relevant bei UnlockKind.RESEARCH

## Waffentechnik (DQ-Stil): nicht leer = der Skill braucht Waffennutzung
## UND eine geführte Waffe aus einer dieser Gattungen (ItemBase.family).
## Der Ausgleich: Techniken sind stärker/billiger als generische Bausteine.
@export var weapon_families: Array[StringName] = []
