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


## Sockel pro Skill (Baukasten 2.0): 3 ab Start, je +1 auf diesen Leveln,
## +1 nach der ersten Wiedergeburt — Maximum 8.
const SOCKEL_START := 3
const SOCKEL_LEVEL: Array[int] = [8, 18, 30, 50]


static func block_sockets_for(level: int, rebirths := 0) -> int:
	var sockel := SOCKEL_START
	for schwelle in SOCKEL_LEVEL:
		if level >= schwelle:
			sockel += 1
	if rebirths > 0:
		sockel += 1
	return sockel


## Level, ab dem der nächste Sockel kommt (-1 = alle Level-Sockel erreicht).
static func next_socket_level(level: int) -> int:
	for schwelle in SOCKEL_LEVEL:
		if level < schwelle:
			return schwelle
	return -1


## Attribute auf einem bestimmten Level (ohne Ausrüstung).
func stats_at_level(level: int) -> StatBlock:
	var stats := base_stats.duplicated()
	stats.add_scaled(growth_per_level, maxi(0, level - 1))
	return stats
