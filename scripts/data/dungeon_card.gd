class_name DungeonCard
extends Resource
## Eine Dungeon-Karte: speicherbar, wiederholbar, farmbar, löschbar.
## Alle Eigenschaften (inkl. Elite-/Boss-Modifikatoren) werden bei der
## Erstellung fix festgelegt und bleiben bei jedem Betreten gleich —
## dadurch sind Karten gezielt planbar zum Farmen.
## Nach Abschluss eines Dungeons erhält man eine neue Karte auf Stufe ±3.

@export var display_name: String

## Seed für die prozedurale Generierung — gleicher Seed = gleiches Layout,
## gleiche Gegner-Platzierung, gleiche Loot-Tabellen-Rolls des Layouts.
@export var seed: int = 0

## Kartenstufe: bestimmt Gegnerstärke, Loot-Tier und die Stufe der Folgekarte.
@export var tier: int = 1

@export var biome: Enums.Biome = Enums.Biome.FOREST

## Elite-/Boss-Modifikator-IDs, fix bei Erstellung gewürfelt.
## Aufgelöst werden sie vom Gegner-Baukasten-System.
@export var modifier_ids: Array[StringName] = []

## Wie oft die Karte bereits abgeschlossen wurde (Statistik/Anzeige).
@export var times_completed: int = 0
