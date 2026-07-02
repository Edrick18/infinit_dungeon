class_name EnemyArchetype
extends Resource
## Grundtyp eines Baukasten-Gegners (z.B. "Wolf", "Skelett", "Schleim").
## Das Gegner-System kombiniert einen Archetyp mit zufälligen Fähigkeiten
## und EnemyModifiers zu einem konkreten Gegner — gleiche Bauweise wie
## bei Items (Basis + Affixe) und Skills (Bausteine).

@export var id: StringName
@export var display_name: String
@export var sprite: Texture2D
@export var biomes: Array[Enums.Biome] = []  ## In welchen Biomen er vorkommt

## Attribute auf Tier 1; skalieren linear mit der Kartenstufe.
@export var base_stats: StatBlock
@export var stats_per_tier: StatBlock

## Flache Schadensreduktion (siehe Combatant).
@export var armor := 0
@export var magic_resist := 0

## Skills, aus denen der Generator für diesen Archetyp wählt.
@export var skill_pool: Array[Skill] = []

## Wie viele Skills ein generierter Gegner aus dem Pool bekommt.
@export var skill_count: int = 1

@export var is_boss_capable: bool = false  ## Kann als Boss-Basis dienen
