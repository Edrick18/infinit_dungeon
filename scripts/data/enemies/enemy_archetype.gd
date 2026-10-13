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

## NUR als Boss (taucht nie in normalen Encountern auf — z.B. Schleimgott).
@export var boss_only := false

## Ruft im Kampf Verstärkung der eigenen Art (Wölfe heulen das Rudel herbei).
@export var calls_reinforcements := false

## Bewegungsverhalten im begehbaren Dungeon (siehe Enums.Temperament).
@export var temperament: Enums.Temperament = Enums.Temperament.AGGRESSIVE

## Untot: nimmt Bonusschaden von Heilig (Synergie mit dem Heilig-Element).
@export var undead := false

## Element-Schwächen/-Resistenzen: Enums.Element » Schadensfaktor
## (1.5 = schwach, 0.5 = resistent). Spieler entdecken sie im Kampf.
@export var element_faktoren: Dictionary = {}

## Ab welcher Kartenstufe dieser Grundtyp im Pool auftaucht — der Gegnerpool
## wächst mit den Stufen, damit man immer wieder Neues entdeckt.
@export var unlock_tier := 1

## Klassen-Varianten-Gruppe (leer = keine): "humanoid" würfelt Krieger/
## Bogenschütze/Magier/Beschwörer (nutzt die Waffenarten!), "schleim"
## Metall-/Gift-/Heilschleim. Siehe EnemyFactory.VARIANT_GROUPS.
@export var variant_group: StringName = &""

## Anzeige-Skalierung im Kampf: Könige/Götter wirken wuchtiger (1.0 = normal).
@export var sprite_scale := 1.0
