class_name LootGenerator
extends RefCounted
## Prozedurale Item-Drops: Rarity würfeln → Basis-Item wählen → Affixe rollen.
## Anders als das Dungeon-Layout ist Loot bewusst NICHT deterministisch pro
## Karte — beim Farmen derselben Karte fallen jedes Mal neue Items.

## Rarity → Anzahl Affixe.
const AFFIX_COUNT := {
	Enums.Rarity.COMMON: 0,
	Enums.Rarity.MAGIC: 1,
	Enums.Rarity.RARE: 2,
	Enums.Rarity.EPIC: 3,
	Enums.Rarity.LEGENDARY: 4,
}

const RARITY_NAMES := {
	Enums.Rarity.COMMON: "Gewöhnlich",
	Enums.Rarity.MAGIC: "Magisch",
	Enums.Rarity.RARE: "Selten",
	Enums.Rarity.EPIC: "Episch",
	Enums.Rarity.LEGENDARY: "Legendär",
}

const RARITY_COLORS := {
	Enums.Rarity.COMMON: Color(0.9, 0.9, 0.9),
	Enums.Rarity.MAGIC: Color(0.42, 0.62, 1.0),
	Enums.Rarity.RARE: Color(1.0, 0.85, 0.3),
	Enums.Rarity.EPIC: Color(0.75, 0.48, 1.0),
	Enums.Rarity.LEGENDARY: Color(1.0, 0.61, 0.25),
}

const ITEM_DROP_CHANCE := 0.35
const BOSS_ITEM_COUNT := 2


static func roll_item(tier: int, rng: RandomNumberGenerator) -> ItemInstance:
	var bases := ItemLibrary.bases_for_tier(tier)
	var item := ItemInstance.new()
	item.base = bases[rng.randi_range(0, bases.size() - 1)]
	item.rarity = roll_rarity(rng)
	item.item_level = tier

	var prefixes := ItemLibrary.affixes_for_tier(tier, true)
	var suffixes := ItemLibrary.affixes_for_tier(tier, false)
	var want: int = AFFIX_COUNT[item.rarity]
	var take_prefix := rng.randf() < 0.5
	while item.affixes.size() < want and (not prefixes.is_empty() or not suffixes.is_empty()):
		var pool := prefixes if (take_prefix and not prefixes.is_empty()) else suffixes
		if pool.is_empty():
			pool = prefixes
		var index := rng.randi_range(0, pool.size() - 1)
		item.affixes.append(pool[index])
		pool.remove_at(index)
		take_prefix = not take_prefix
	return item


static func roll_rarity(rng: RandomNumberGenerator) -> Enums.Rarity:
	var roll := rng.randf()
	if roll < 0.45:
		return Enums.Rarity.COMMON
	if roll < 0.75:
		return Enums.Rarity.MAGIC
	if roll < 0.90:
		return Enums.Rarity.RARE
	if roll < 0.98:
		return Enums.Rarity.EPIC
	return Enums.Rarity.LEGENDARY


static func gold_for_kill(tier: int, loot_mult: float, rng: RandomNumberGenerator) -> int:
	return roundi((8 + tier * 4 + rng.randi_range(0, 6)) * loot_mult)


## Verkaufswert eines Items beim Händler.
static func sell_price(item: ItemInstance) -> int:
	return (3 + item.item_level * 2) * (1 + int(item.rarity))


## Komplette Beute eines gewonnenen Kampfs: Gold + evtl. Items.
## Elite-Gegner droppen häufiger (loot_mult), Bosse garantiert mehrere Items.
static func roll_battle_loot(enemies: Array[Combatant], tier: int, is_boss: bool,
		rng: RandomNumberGenerator) -> Dictionary:
	var gold := 0
	var items: Array[ItemInstance] = []
	for enemy in enemies:
		gold += gold_for_kill(tier, enemy.loot_mult, rng)
		if rng.randf() < ITEM_DROP_CHANCE * enemy.loot_mult:
			items.append(roll_item(tier, rng))
	if is_boss:
		while items.size() < BOSS_ITEM_COUNT:
			items.append(roll_item(tier, rng))
		gold *= 2
	return {"gold": gold, "items": items}
