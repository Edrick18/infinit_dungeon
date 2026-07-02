class_name CharacterDef
extends Resource
## Ein fester, handdesignter Party-Charakter (wird im Hub rekrutiert).
## Klassenlos: Die Rolle ergibt sich rein aus Ausrüstung und gebauten Skills.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var portrait: Texture2D
@export var battle_sprite: Texture2D

## Attribute auf Level 1.
@export var base_stats: StatBlock

## Attribut-Zuwachs pro Level-Up (linear, siehe DESIGN.md Abschnitt 3).
@export var growth_per_level: StatBlock


## Skill-Slots: 1 auf Level 1, +1 alle 5 Level, kein Cap.
static func skill_slots_for_level(level: int) -> int:
	return 1 + maxi(0, level) / 5


## Attribute auf einem bestimmten Level (ohne Ausrüstung).
func stats_at_level(level: int) -> StatBlock:
	var stats := base_stats.duplicated()
	stats.add_scaled(growth_per_level, maxi(0, level - 1))
	return stats
