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

## Anzahl der Ebenen — höhere Kartenstufen haben mehr Ebenen.
## Der Boss wartet immer nur auf der untersten Ebene.
@export var floor_count: int = 1

## Elite-/Boss-Modifikator-IDs, fix bei Erstellung gewürfelt.
## Aufgelöst werden sie vom Gegner-Baukasten-System.
@export var modifier_ids: Array[StringName] = []

## Wie oft die Karte bereits abgeschlossen wurde (Statistik/Anzeige).
@export var times_completed: int = 0


func to_dict() -> Dictionary:
	var mod_ids: Array = []
	for id in modifier_ids:
		mod_ids.append(String(id))
	return {
		"display_name": display_name,
		"seed": seed,
		"tier": tier,
		"biome": biome,
		"floor_count": floor_count,
		"modifier_ids": mod_ids,
		"times_completed": times_completed,
	}


static func from_dict(data: Dictionary) -> DungeonCard:
	var card := DungeonCard.new()
	card.display_name = data.get("display_name", "")
	card.seed = int(data.get("seed", 0))
	card.tier = int(data.get("tier", 1))
	card.biome = int(data.get("biome", Enums.Biome.FOREST))
	card.floor_count = int(data.get("floor_count", 1))
	var mods: Array[StringName] = []
	for id_str in data.get("modifier_ids", []):
		mods.append(StringName(id_str))
	card.modifier_ids = mods
	card.times_completed = int(data.get("times_completed", 0))
	return card
