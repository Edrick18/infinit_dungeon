class_name LootGenerator
extends RefCounted
## Prozedurale Item-Drops: Rarity würfeln » Basis-Item wählen » Affixe rollen.
## Anders als das Dungeon-Layout ist Loot bewusst NICHT deterministisch pro
## Karte — beim Farmen derselben Karte fallen jedes Mal neue Items.

## Rarity » Anzahl Affixe.
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
	return roll_item_with_rarity(tier, roll_rarity(rng), rng)


## Item mit VORGEGEBENER Rarität (Truhen: die Truhen-Rarität bestimmt die
## Item-Rarität, nicht die Häufigkeit).
static func roll_item_with_rarity(tier: int, rarity: Enums.Rarity,
		rng: RandomNumberGenerator) -> ItemInstance:
	var bases := ItemLibrary.bases_for_tier(tier)
	var item := ItemInstance.new()
	item.base = bases[rng.randi_range(0, bases.size() - 1)]
	item.rarity = rarity
	item.item_level = tier
	apply_random_affixes(item, rng)
	return item


## Wie oft eine Affix-Rarität im gewichteten Pool gezogen wird.
const AFFIX_RARITY_WEIGHTS := {
	Enums.Rarity.COMMON: 100,
	Enums.Rarity.MAGIC: 55,
	Enums.Rarity.RARE: 25,
	Enums.Rarity.EPIC: 10,
	Enums.Rarity.LEGENDARY: 4,
}

## Spanne des Qualitäts-Rolls pro Affix: "+3" wird zu "+3 bis +5".
const AFFIX_ROLL_MIN := 1.0
const AFFIX_ROLL_MAX := 1.6


## Würfelt die zur Rarity passende Affix-Anzahl auf ein Item: Slot-gebundene
## Pools, Ziehung nach Affix-Rarität gewichtet, pro Affix ein Qualitäts-Roll.
## Auch von der Schmiede genutzt (Craften + Neuwürfeln).
static func apply_random_affixes(item: ItemInstance, rng: RandomNumberGenerator) -> void:
	var tier := item.item_level
	var prefixes := _pool_for_slot(ItemLibrary.affixes_for_tier(tier, true), item.base.slot)
	var suffixes := _pool_for_slot(ItemLibrary.affixes_for_tier(tier, false), item.base.slot)
	var want: int = AFFIX_COUNT[item.rarity]
	var take_prefix := rng.randf() < 0.5
	while item.affixes.size() < want and (not prefixes.is_empty() or not suffixes.is_empty()):
		var pool := prefixes if (take_prefix and not prefixes.is_empty()) else suffixes
		if pool.is_empty():
			pool = prefixes
		var index := _pick_weighted(pool, rng)
		item.affixes.append(pool[index])
		item.affix_rolls.append(snappedf(rng.randf_range(AFFIX_ROLL_MIN, AFFIX_ROLL_MAX), 0.01))
		pool.remove_at(index)
		take_prefix = not take_prefix


## Gewichtete Ziehung: häufige Affixe oft, legendäre selten.
static func _pick_weighted(pool: Array[Affix], rng: RandomNumberGenerator) -> int:
	var total := 0
	for affix in pool:
		total += AFFIX_RARITY_WEIGHTS[affix.rarity]
	var roll := rng.randi_range(1, total)
	for i in pool.size():
		roll -= AFFIX_RARITY_WEIGHTS[pool[i].rarity]
		if roll <= 0:
			return i
	return pool.size() - 1


## Affixe mit Slot-Bindung (Element-Rider nur auf Waffen, Resistenzen nur
## auf Rüstung/Schmuck, …) aus dem Pool filtern.
static func _pool_for_slot(pool: Array[Affix], slot: Enums.EquipSlot) -> Array[Affix]:
	var result: Array[Affix] = []
	for affix in pool:
		if affix.allowed_slots.is_empty() or slot in affix.allowed_slots:
			result.append(affix)
	return result


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


## Gold wächst mit derselben Exponential-Kurve wie Gegner und Items —
## die Ökonomie (Glücksbude, Händler) bleibt so in jeder Spielphase bezahlbar.
static func gold_for_kill(tier: int, loot_mult: float, rng: RandomNumberGenerator) -> int:
	return roundi((8 + tier * 4 + rng.randi_range(0, 6)) * loot_mult
		* Scaling.factor(tier))


## Verkaufswert eines Items beim Händler.
static func sell_price(item: ItemInstance) -> int:
	# Folgt der Welt-Wachstumskurve — hochstufige Beute bleibt relativ wertvoll.
	return roundi((3 + item.item_level * 2) * (1 + int(item.rarity))
		* Scaling.factor(item.item_level))


const MATERIAL_DROP_CHANCE := 0.4

## Themen-Drops (DQ-Prinzip): Jeder Grundtyp lässt bevorzugt SEIN Material
## fallen — Karten mit den richtigen Gegnern werden gezielte Farm-Ziele.
const ARCHETYPE_MATERIALS := {
	&"bandit": &"lederreste",
	&"wolf": &"lederreste", &"baer": &"lederreste", &"fledermaus": &"lederreste",
	&"spinne": &"lederreste", &"troll": &"lederreste", &"schattenbestie": &"lederreste",
	&"skelett": &"eisenerz", &"golem": &"eisenerz", &"mimic": &"eisenerz",
	&"schleim": &"kristallstaub", &"schleimstapel": &"kristallstaub",
	&"koenigschleim": &"kristallstaub", &"schleimgott": &"kristallstaub",
	&"nekromant": &"kristallstaub",
	&"kultist": &"manabluete", &"geist": &"manabluete",
}
const THEMED_DROP_CHANCE := 0.6  ## sonst: globale Tabelle (Kräuter & Co.)


## Material-Drop eines Gegners: meist sein Themen-Material, sonst global.
static func material_for_enemy(enemy: Combatant, rng: RandomNumberGenerator) -> StringName:
	if ARCHETYPE_MATERIALS.has(enemy.archetype_id) and rng.randf() < THEMED_DROP_CHANCE:
		return ARCHETYPE_MATERIALS[enemy.archetype_id]
	return MaterialLibrary.roll(rng)


## Komplette Beute eines gewonnenen Kampfs: Gold + evtl. Items + Materialien.
## Tränke droppen bewusst NICHT — sie werden gekauft oder aus den
## Materialien gecraftet. Elite-Gegner droppen häufiger (loot_mult),
## Bosse garantiert mehrere Items.
## luck = Ø-Glück der Party: erhöht Gold (+0,4%/Punkt) und die
## Item-Drop-Chance (+0,5%/Punkt relativ) — Glücks zweiter Job neben Krit.
## XP für einen Sieg über diese Gegner (an jeden Helden der Party):
## leicht überproportional mit dem Gegnerlevel, × xp_mult (Metallschleim),
## Boss ×3, Kartenaffix „uralt“ ×1.25.
static func xp_fuer(enemies: Array[Combatant], is_boss: bool, run_affixes: Array) -> int:
	var xp := 0
	for foe in enemies:
		if foe.is_summon:
			continue
		xp += roundi((8 + foe.level * 4 + foe.level * foe.level / 20.0) * foe.xp_mult)
	if is_boss:
		xp *= 3
	if &"uralt" in run_affixes:
		xp = roundi(xp * 1.25)
	return xp


static func roll_battle_loot(enemies: Array[Combatant], tier: int, is_boss: bool,
		rng: RandomNumberGenerator, luck := 0) -> Dictionary:
	var gold := 0
	var items: Array[ItemInstance] = []
	var material_ids: Array[StringName] = []
	var drop_mult := 1.0 + luck * 0.005
	for enemy in enemies:
		gold += gold_for_kill(tier, enemy.loot_mult, rng)
		if rng.randf() < ITEM_DROP_CHANCE * enemy.loot_mult * drop_mult:
			items.append(roll_item(tier, rng))
		if rng.randf() < MATERIAL_DROP_CHANCE * enemy.loot_mult:
			material_ids.append(material_for_enemy(enemy, rng))
	gold = roundi(gold * (1.0 + luck * 0.004))
	if is_boss:
		while items.size() < BOSS_ITEM_COUNT:
			items.append(roll_item(tier, rng))
		material_ids.append(MaterialLibrary.roll(rng))
		material_ids.append(MaterialLibrary.roll(rng))
		gold *= 2
	return {"gold": gold, "items": items, "materials": material_ids}
