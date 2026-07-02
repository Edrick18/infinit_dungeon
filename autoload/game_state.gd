extends Node
## Autoload "GameState": persistenter Spielzustand über Szenenwechsel hinweg —
## Party, Gold, erforschte Bausteine. Später kommt hier das Speichersystem dran.

var gold := 150
var researched: Array[StringName] = []
var party: Array[Combatant] = []
var inventory: Array[ItemInstance] = []

## Verbrauchsgegenstände stacken: ID → Anzahl.
var consumables: Dictionary = {}

## Crafting-Materialien (droppen von Gegnern/Truhen): ID → Anzahl.
var materials: Dictionary = {}

## Kartenlager: begrenzt, aber gegen Gold erweiterbar (siehe Design).
var cards: Array[DungeonCard] = []
var card_capacity := 25
var storage_expansions := 0

## Laufender Dungeon-Besuch: {"card": DungeonCard, "defeated": Array[int],
## "opened": Array[int], "player_pos": Vector2, "boss_defeated": bool}.
## Leer = kein aktiver Run. Nur die Karte + Fortschritt werden gehalten,
## das Layout selbst kommt deterministisch aus dem Karten-Seed.
var current_run: Dictionary = {}

## Übergabe an die Kampfszene: {"enemy_id": int, "is_boss": bool,
## "enemies": Array[Combatant]}. Leer = normaler Testkampf aus dem Menü.
var pending_battle: Dictionary = {}

## Wohin "Zurück" in UI-Szenen führt (z.B. Inventar aus dem Dungeon heraus
## geöffnet → zurück in den Dungeon statt ins Menü). Leer = Hauptmenü.
var ui_return_scene := ""


func _ready() -> void:
	if party.is_empty():
		party = TestContent.make_party()
	if cards.is_empty():
		# Zwei Startkarten, damit es direkt losgehen kann.
		cards.append(CardFactory.make_starter_card())
		cards.append(CardFactory.make_starter_card())
	if consumables.is_empty():
		# Startvorrat als Puffer gegen die Dungeon-Attrition.
		add_consumable(&"heiltrank", 3)
		add_consumable(&"manatrank", 1)
	if materials.is_empty():
		add_material(&"heilkraut", 2)


func add_consumable(id: StringName, amount := 1) -> void:
	consumables[id] = consumable_count(id) + amount


func consumable_count(id: StringName) -> int:
	return consumables.get(id, 0)


## Verbraucht ein Exemplar. false, wenn keins da ist.
func consume(id: StringName) -> bool:
	if consumable_count(id) <= 0:
		return false
	consumables[id] -= 1
	if consumables[id] <= 0:
		consumables.erase(id)
	return true


func add_material(id: StringName, amount := 1) -> void:
	materials[id] = material_count(id) + amount


func material_count(id: StringName) -> int:
	return materials.get(id, 0)


## Einfache Tränke beim Händler kaufen.
func buy(def: ConsumableDef) -> bool:
	if def.price <= 0 or gold < def.price:
		return false
	gold -= def.price
	add_consumable(def.id)
	return true


## Prüft, ob Materialien + Zutaten-Tränke fürs Rezept reichen.
func can_craft(def: ConsumableDef) -> bool:
	if not def.is_craftable():
		return false
	for id in def.craft_materials:
		if material_count(id) < def.craft_materials[id]:
			return false
	for id in def.craft_consumables:
		if consumable_count(id) < def.craft_consumables[id]:
			return false
	return true


## Craftet einen Trank beim Alchemisten (verbraucht das Rezept).
func craft(def: ConsumableDef) -> bool:
	if not can_craft(def):
		return false
	for id in def.craft_materials:
		materials[id] -= def.craft_materials[id]
		if materials[id] <= 0:
			materials.erase(id)
	for id in def.craft_consumables:
		for i in def.craft_consumables[id]:
			consume(id)
	add_consumable(def.id)
	return true


## Karte ins Lager legen. false, wenn das Lager voll ist (Karte verfällt —
## bewusste Design-Konsequenz des begrenzten Lagers).
func add_card(card: DungeonCard) -> bool:
	if cards.size() >= card_capacity:
		return false
	cards.append(card)
	return true


func delete_card(card: DungeonCard) -> void:
	cards.erase(card)


func storage_expansion_cost() -> int:
	return 100 + storage_expansions * 50


func can_expand_storage() -> bool:
	return gold >= storage_expansion_cost()


## Lager gegen Gold um 5 Slots erweitern.
func expand_storage() -> bool:
	if not can_expand_storage():
		return false
	gold -= storage_expansion_cost()
	card_capacity += 5
	storage_expansions += 1
	return true


func start_run(card: DungeonCard) -> void:
	# Das Hub heilt: Jeder Run startet mit frischer Party (HP und MP voll).
	heal_party()
	current_run = {
		"card": card,
		"floor": 0,
		"defeated": [],
		"opened": [],
		"player_pos": Vector2.ZERO,
		"boss_defeated": false,
	}


func clear_run() -> void:
	current_run = {}
	pending_battle = {}
	# Zurück im Hub: volle Heilung für HP und MP.
	heal_party()


func heal_party() -> void:
	for member in party:
		member.reset_for_battle(true)


func is_block_unlocked(block: SkillBlock, char_level: int) -> bool:
	return BlockLibrary.is_unlocked(block, char_level, researched)


func can_research(block: SkillBlock) -> bool:
	return block.unlock_kind == Enums.UnlockKind.RESEARCH \
		and block.id not in researched \
		and gold >= block.research_cost_gold


func research(block: SkillBlock) -> bool:
	if not can_research(block):
		return false
	gold -= block.research_cost_gold
	researched.append(block.id)
	return true
