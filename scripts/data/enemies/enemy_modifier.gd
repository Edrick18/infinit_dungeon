class_name EnemyModifier
extends Resource
## Elite-/Boss-Modifikator für Baukasten-Gegner (z.B. "brennend", "gepanzert",
## "schnell"). Welche Modifikatoren in einem Dungeon vorkommen, legt die
## DungeonCard bei ihrer Erstellung fix fest (modifier_ids).

@export var id: StringName
@export var display_name: String

## Multiplikative Anpassungen (1.0 = unverändert).
@export var hp_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var speed_multiplier: float = 1.0

## Flacher Rüstungsbonus (z.B. "Gepanzert").
@export var armor_bonus := 0

## Zusätzlicher Skill, den der Modifikator dem Gegner gibt (optional).
@export var granted_skill: Skill

## Loot-Bonus als Ausgleich fürs höhere Risiko.
@export var loot_multiplier: float = 1.0
## XP-Bonus (Anführer-Affixe geben mehr Erfahrung).
@export var xp_multiplier: float = 1.0

## Anführer-Aura: an jedem eigenen Zugbeginn stärkt der Träger seine ganze
## Gruppe mit diesem Status (Buff-Stufen: zweimal = Stufe 2). -1 = keine Aura.
@export var aura_status: int = -1
@export var aura_potency := 0

## Ab welcher Kartenstufe dieser Modifikator gewürfelt werden kann.
@export var min_tier: int = 1
