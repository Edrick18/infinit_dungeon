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

## Händler-Aufträge: 3 rotierende Aufgaben (siehe MerchantOrders).
var merchant_orders: Array[Dictionary] = []

## Sprache ("de"/"en", später mehr) — gespiegelt nach Loc, wird gespeichert.
var language := "de":
	set(value):
		language = value
		Loc.language = value

## Laufender Dungeon-Besuch: {"card": DungeonCard, "defeated": Array[int],
## "opened": Array[int], "player_pos": Vector2, "boss_defeated": bool,
## "explored_by_floor": {floor_index: Dictionary[Vector2i, bool]}}.
## Leer = kein aktiver Run. Nur die Karte + Fortschritt werden gehalten,
## das Layout selbst kommt deterministisch aus dem Karten-Seed.
## explored_by_floor hält den Fog-of-War-Fortschritt über Szenenwechsel
## (z.B. Kämpfe) hinweg am Leben — er wird nur bei einer neuen Ebene oder
## einem neuen Dungeon-Run zurückgesetzt, nicht nach jedem Kampf.
var current_run: Dictionary = {}

## Übergabe an die Kampfszene: {"enemy_id": int, "is_boss": bool,
## "enemies": Array[Combatant]}. Leer = normaler Testkampf aus dem Menü.
var pending_battle: Dictionary = {}

## Wohin "Zurück" in UI-Szenen führt (z.B. Inventar aus dem Dungeon heraus
## geöffnet → zurück in den Dungeon statt ins Menü). Leer = Hauptmenü.
var ui_return_scene := ""


func _ready() -> void:
	if load_game():
		return
	# Kein (nutzbarer) Spielstand vorhanden — frischer Start. Die Party bleibt
	# LEER: Das Hauptmenü führt durch die Erstellung des ersten Helden, weitere
	# werden kostenlos in der Taverne angeheuert.
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


## Kosten-Helfer für Schmiede & Co.: {"gold": int, "materials": {id: Anzahl}}.
func can_pay(cost: Dictionary) -> bool:
	if gold < cost.get("gold", 0):
		return false
	var mats: Dictionary = cost.get("materials", {})
	for id in mats:
		if material_count(id) < mats[id]:
			return false
	return true


func pay(cost: Dictionary) -> bool:
	if not can_pay(cost):
		return false
	gold -= cost.get("gold", 0)
	var mats: Dictionary = cost.get("materials", {})
	for id in mats:
		materials[id] -= mats[id]
		if materials[id] <= 0:
			materials.erase(id)
	return true


## Durchschnittliches Party-Level (Basis für Schmiede-Crafts).
func average_party_level() -> int:
	if party.is_empty():
		return 1
	var total := 0
	for member in party:
		total += member.level
	return maxi(1, roundi(float(total) / party.size()))


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


# --- Händler-Aufträge ----------------------------------------------------------

## Freie Auftrags-Slots nachfüllen (beim Betreten des Händlers).
func ensure_orders() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while merchant_orders.size() < MerchantOrders.ORDER_SLOTS:
		merchant_orders.append(MerchantOrders.make_order(average_party_level(), rng))


## Erfüllten Auftrag abgeben: zieht bei Lieferaufträgen die Materialien ein,
## gewährt die Belohnung und rückt einen neuen Auftrag nach.
func claim_order(order: Dictionary) -> bool:
	if order not in merchant_orders or not MerchantOrders.is_complete(order, self):
		return false
	var reward: Dictionary = order["reward"]
	# Wunsch-Karte braucht Platz im Lager — sonst bleibt der Auftrag offen.
	if reward["kind"] == "card" and cards.size() >= card_capacity:
		return false
	if order["type"] == "deliver":
		if not pay({"materials": {order["material"]: order["count"]}}):
			return false
	match reward["kind"]:
		"gold":
			gold += reward["gold"]
		"materials":
			for id in reward["materials"]:
				add_material(id, reward["materials"][id])
		"card":
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			add_card(CardFactory.make_card(average_party_level(), rng, reward["biome"]))
	merchant_orders.erase(order)
	ensure_orders()
	return true


## Kampf gewonnen → Jagd-Aufträge zählen mit.
func note_kills(count: int) -> void:
	for order in merchant_orders:
		if order["type"] == "hunt":
			order["progress"] = mini(int(order["count"]), int(order["progress"]) + count)


## Karte abgeschlossen (Boss besiegt) → passende Abschluss-Aufträge erfüllen.
func note_card_cleared(card: DungeonCard) -> void:
	for order in merchant_orders:
		if order["type"] == "clear" and int(order["progress"]) < 1 \
				and card.biome == int(order["biome"]) and card.tier >= int(order["min_tier"]):
			order["progress"] = 1


func start_run(card: DungeonCard) -> void:
	# Das Hub heilt: Jeder Run startet mit frischer Party (HP und MP voll).
	heal_party()
	current_run = {
		"card": card,
		"floor": 0,
		"defeated": [],
		"opened": [],
		"events_used": [],
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


## Held in der Taverne anheuern — kostenlos, bis die Party voll ist (4).
## Kein Permadeath im Spiel: Gefallene stehen nach dem Kampf wieder auf,
## die Taverne dient dem AUFBAU der Party, nicht dem Ersetzen von Toten.
func recruit(hero_name: String, kit_id: StringName) -> bool:
	if party.size() >= HeroLibrary.MAX_PARTY_SIZE:
		return false
	if hero_name not in HeroLibrary.available_names(party):
		return false
	party.append(HeroLibrary.create_hero(hero_name, kit_id))
	return true


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


# --- Speichersystem ----------------------------------------------------------
# Reine Serialisierung (to_save_dict/apply_save_dict) ist von der Datei-I/O
# (SaveManager) getrennt, damit sich der Rundweg ohne Festplattenzugriff
# testen lässt.

func save_game() -> bool:
	return SaveManager.save(to_save_dict())


## true, wenn ein nutzbarer Spielstand geladen und übernommen wurde.
func load_game() -> bool:
	var data := SaveManager.load_data()
	if data.is_empty():
		return false
	apply_save_dict(data)
	return true


func has_save_file() -> bool:
	return SaveManager.has_save()


func to_save_dict() -> Dictionary:
	var researched_list: Array = []
	for id in researched:
		researched_list.append(String(id))

	var party_list: Array = []
	for member in party:
		party_list.append(member.to_dict())

	var inventory_list: Array = []
	for item in inventory:
		inventory_list.append(item.to_dict())

	var consumables_dict := {}
	for id in consumables:
		consumables_dict[String(id)] = consumables[id]

	var materials_dict := {}
	for id in materials:
		materials_dict[String(id)] = materials[id]

	var cards_list: Array = []
	for card in cards:
		cards_list.append(card.to_dict())

	var orders_list: Array = []
	for order in merchant_orders:
		orders_list.append(MerchantOrders.to_dict(order))

	var data := {
		"version": 1,
		"gold": gold,
		"researched": researched_list,
		"party": party_list,
		"inventory": inventory_list,
		"consumables": consumables_dict,
		"materials": materials_dict,
		"cards": cards_list,
		"card_capacity": card_capacity,
		"storage_expansions": storage_expansions,
		"merchant_orders": orders_list,
		"language": language,
	}
	if not current_run.is_empty():
		data["current_run"] = _run_to_dict(current_run)
	return data


func apply_save_dict(data: Dictionary) -> void:
	gold = int(data.get("gold", 150))

	researched.clear()
	for id_str in data.get("researched", []):
		researched.append(StringName(id_str))

	party.clear()
	for member_data in data.get("party", []):
		party.append(Combatant.from_dict(member_data))

	inventory.clear()
	for item_data in data.get("inventory", []):
		var item := ItemInstance.from_dict(item_data)
		if item != null:
			inventory.append(item)

	consumables.clear()
	for id_str in data.get("consumables", {}).keys():
		consumables[StringName(id_str)] = int(data["consumables"][id_str])

	materials.clear()
	for id_str in data.get("materials", {}).keys():
		materials[StringName(id_str)] = int(data["materials"][id_str])

	cards.clear()
	for card_data in data.get("cards", []):
		cards.append(DungeonCard.from_dict(card_data))

	card_capacity = int(data.get("card_capacity", 25))
	storage_expansions = int(data.get("storage_expansions", 0))

	merchant_orders.clear()
	for order_data in data.get("merchant_orders", []):
		merchant_orders.append(MerchantOrders.from_dict(order_data))

	language = String(data.get("language", "de"))

	current_run = {}
	if data.has("current_run"):
		current_run = _run_from_dict(data["current_run"])
	pending_battle = {}


func _run_to_dict(run: Dictionary) -> Dictionary:
	var explored_out := {}
	var explored_by_floor: Dictionary = run.get("explored_by_floor", {})
	for floor_idx in explored_by_floor:
		var cells: Array = []
		for cell in explored_by_floor[floor_idx]:
			cells.append([cell.x, cell.y])
		explored_out[str(floor_idx)] = cells
	var pos: Vector2 = run.get("player_pos", Vector2.ZERO)
	var out := {
		"card": run["card"].to_dict(),
		"floor": run.get("floor", 0),
		"defeated": run.get("defeated", []),
		"opened": run.get("opened", []),
		"events_used": run.get("events_used", []),
		"player_pos": [pos.x, pos.y],
		"boss_defeated": run.get("boss_defeated", false),
		"explored_by_floor": explored_out,
	}
	if run.has("blessing"):
		out["blessing"] = String(run["blessing"])
	return out


func _run_from_dict(data: Dictionary) -> Dictionary:
	var explored_by_floor := {}
	var explored_in: Dictionary = data.get("explored_by_floor", {})
	for floor_str in explored_in.keys():
		var cells := {}
		for pair in explored_in[floor_str]:
			cells[Vector2i(int(pair[0]), int(pair[1]))] = true
		explored_by_floor[int(floor_str)] = cells
	var pos: Array = data.get("player_pos", [0, 0])
	var defeated: Array = []
	for id in data.get("defeated", []):
		defeated.append(int(id))
	var opened: Array = []
	for id in data.get("opened", []):
		opened.append(int(id))
	var events_used: Array = []
	for id in data.get("events_used", []):
		events_used.append(int(id))
	var run := {
		"card": DungeonCard.from_dict(data.get("card", {})),
		"floor": int(data.get("floor", 0)),
		"defeated": defeated,
		"opened": opened,
		"events_used": events_used,
		"player_pos": Vector2(float(pos[0]), float(pos[1])),
		"boss_defeated": bool(data.get("boss_defeated", false)),
		"explored_by_floor": explored_by_floor,
	}
	if data.has("blessing"):
		run["blessing"] = StringName(data["blessing"])
	return run
