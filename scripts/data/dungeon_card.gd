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

## Karten-Affixe (fix bei Erstellung): verändern die ganze Karte —
## mehr Gold, mehr Gegner, mehr Truhen, Elite-Dichte … (CardFactory.CARD_AFFIXES).
## Machen jede Karte zu einem eigenen Angebot mit Risiko/Belohnungs-Profil.
@export var card_affix_ids: Array[StringName] = []

## Wie oft die Karte bereits abgeschlossen wurde (Statistik/Anzeige —
## und bei legendären Karten der Boss-Level-Zähler!).
@export var times_completed: int = 0

## Legendäre Karte (DQ9-Legacy-Boss): Der Boss wird bei JEDEM Abschluss
## stärker (+2 Stufen pro Abschluss) und gibt entsprechend mehr Beute —
## eine endlose, selbst-eskalierende Herausforderung pro Karte.
@export var legendary := false

## Karten-Rarität (Diablo-Prinzip auch für Karten): seltene Karten haben
## STÄRKERE Gegner (Bonus-Stufen) und lukrativere Beute/XP.
@export var card_rarity: Enums.Rarity = Enums.Rarity.COMMON
## Favorit (Kartenlager): steht oben und lässt sich nicht versehentlich löschen.
@export var favorit := false


func rarity_level_bonus() -> int:
	match card_rarity:
		Enums.Rarity.MAGIC: return 1
		Enums.Rarity.RARE: return 1
		Enums.Rarity.EPIC: return 2
		Enums.Rarity.LEGENDARY: return 2
	return 0


func rarity_loot_mult() -> float:
	match card_rarity:
		Enums.Rarity.MAGIC: return 1.15
		Enums.Rarity.RARE: return 1.3
		Enums.Rarity.EPIC: return 1.6
		Enums.Rarity.LEGENDARY: return 2.0
	return 1.0


func rarity_xp_mult() -> float:
	match card_rarity:
		Enums.Rarity.RARE: return 1.15
		Enums.Rarity.EPIC: return 1.3
		Enums.Rarity.LEGENDARY: return 1.5
	return 1.0


## Effektiver Boss-Stufen-Bonus durchs Legacy-Leveln.
func legacy_boss_bonus() -> int:
	if not legendary:
		return 0
	return mini(40, 2 * times_completed)


func to_dict() -> Dictionary:
	var mod_ids: Array = []
	for id in modifier_ids:
		mod_ids.append(String(id))
	var affix_ids: Array = []
	for id in card_affix_ids:
		affix_ids.append(String(id))
	return {
		"display_name": display_name,
		"seed": seed,
		"tier": tier,
		"biome": biome,
		"floor_count": floor_count,
		"modifier_ids": mod_ids,
		"card_affix_ids": affix_ids,
		"times_completed": times_completed,
		"legendary": legendary,
		"card_rarity": int(card_rarity),
		"favorit": favorit,
	}


static func from_dict(data: Dictionary) -> DungeonCard:
	var card := DungeonCard.new()
	card.display_name = data.get("display_name", "")
	# Migration: frühere Legendär-Karten trugen ein Stern-Zeichen im
	# Namen, das die Schrift nicht darstellen kann.
	if card.display_name.begins_with("★ "):
		card.display_name = card.display_name.substr(2)
	card.seed = int(data.get("seed", 0))
	card.tier = int(data.get("tier", 1))
	card.biome = int(data.get("biome", Enums.Biome.FOREST))
	card.floor_count = int(data.get("floor_count", 1))
	var mods: Array[StringName] = []
	for id_str in data.get("modifier_ids", []):
		mods.append(StringName(id_str))
	card.modifier_ids = mods
	var affixes: Array[StringName] = []
	for id_str in data.get("card_affix_ids", []):
		affixes.append(StringName(id_str))
	card.card_affix_ids = affixes
	card.times_completed = int(data.get("times_completed", 0))
	card.legendary = bool(data.get("legendary", false))
	card.card_rarity = int(data.get("card_rarity", Enums.Rarity.COMMON)) as Enums.Rarity
	card.favorit = bool(data.get("favorit", false))
	return card
