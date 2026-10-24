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
	if item.rarity == Enums.Rarity.LEGENDARY and rng.randf() < REGELBRUCH_CHANCE:
		regelbruch_hinzufuegen(item, rng)


## Legendäre Items tragen selten einen Regelbrecher; die Regelrune garantiert ihn.
const REGELBRUCH_CHANCE := 0.03


static func regelbruch_hinzufuegen(item: ItemInstance, rng: RandomNumberGenerator) -> void:
	for affix in item.affixes:
		if affix.regelbruch != &"":
			return
	var pool := ItemLibrary.regel_affixe()
	item.affixes.append(pool[rng.randi_range(0, pool.size() - 1)])
	item.affix_rolls.append(1.0)


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

## Themen-Drops (DQ-Prinzip): Jeder Grundtyp lässt bevorzugt SEINE Material-Art
## fallen — Karten mit den richtigen Gegnern werden gezielte Farm-Ziele. Die
## Stufe (Eisen … Sternen) bestimmt die Kartenstufe.
const ARCHETYPE_MATERIALS := {
	&"bandit": &"leder",
	&"wolf": &"leder", &"baer": &"leder", &"fledermaus": &"leder",
	&"spinne": &"leder", &"troll": &"leder", &"schattenbestie": &"leder",
	&"skelett": &"erz", &"golem": &"erz", &"mimic": &"erz",
	&"schleim": &"kristall", &"schleimstapel": &"kristall",
	&"koenigschleim": &"kristall", &"schleimgott": &"kristall",
	&"nekromant": &"kristall",
	&"kultist": &"kraut", &"geist": &"kraut",
}
const THEMED_DROP_CHANCE := 0.6  ## sonst: globale Tabelle (Kräuter & Co.)


## Material-Drop eines Gegners: meist sein Themen-Material, sonst global.
static func material_for_enemy(enemy: Combatant, rng: RandomNumberGenerator, tier := 1) -> StringName:
	if ARCHETYPE_MATERIALS.has(enemy.archetype_id) and rng.randf() < THEMED_DROP_CHANCE:
		return MaterialLibrary.roll_der_art(ARCHETYPE_MATERIALS[enemy.archetype_id], rng, tier)
	return MaterialLibrary.roll(rng, tier)


## Komplette Beute eines gewonnenen Kampfs: Gold + evtl. Items + Materialien.
## Tränke droppen bewusst NICHT — sie werden gekauft oder aus den
## Materialien gecraftet. Elite-Gegner droppen häufiger (loot_mult),
## Bosse garantiert mehrere Items.
## luck = Ø-Glück der Party: erhöht Gold (+0,4%/Punkt) und die
## Item-Drop-Chance (+0,5%/Punkt relativ) — Glücks zweiter Job neben Krit.
## Level-Abstand: schwächere Gegner geben weniger XP (−8 % je Level, min.
## 10 % — alte Karten farmen lohnt nicht), stärkere mehr (+5 % je Level,
## max. +50 % — höhere Karten wagen lohnt).
const XP_UNTER_JE_LEVEL := 0.08
const XP_UNTER_MIN := 0.1
const XP_UEBER_JE_LEVEL := 0.05
const XP_UEBER_MAX := 1.5


static func xp_level_faktor(held_level: int, gegner_level: int) -> float:
	var abstand := gegner_level - held_level
	if abstand >= 0:
		return minf(XP_UEBER_MAX, 1.0 + XP_UEBER_JE_LEVEL * abstand)
	return maxf(XP_UNTER_MIN, 1.0 + XP_UNTER_JE_LEVEL * abstand)


## Nachzügler-Bonus (Lutz 2026-10-16): Haben die Helden im Kampf
## unterschiedliche Level, bekommt der niedrigste (bzw. die gleich niedrigen
## zusammen) die HÄLFTE der Kampf-XP, der Rest teilt sich die andere Hälfte.
## So holt ein frisch eingewechselter Held schnell auf. Bank-Helden: nichts.
const NACHZUEGLER_ANTEIL := 0.5


## Anteil (0..1) der Kampf-XP für jeden Helden: {Combatant: float}.
static func xp_verteilung(helden: Array[Combatant]) -> Dictionary:
	var verteilung := {}
	if helden.is_empty():
		return verteilung
	var tiefst := helden[0].level
	var hoechst := helden[0].level
	for held in helden:
		tiefst = mini(tiefst, held.level)
		hoechst = maxi(hoechst, held.level)
	if tiefst == hoechst:
		for held in helden:
			verteilung[held] = 1.0 / helden.size()
		return verteilung
	var nachzuegler: Array[Combatant] = []
	for held in helden:
		if held.level == tiefst:
			nachzuegler.append(held)
	var rest := helden.size() - nachzuegler.size()
	# Stellen die Nachzügler die Mehrheit, würde „die Hälfte geteilt“ sie
	# SCHLECHTER stellen als gleichmäßig (Spieltest 2026-10-24: Leader +7,
	# zwei Lv-1-Helden je +4) — dann gilt die gleichmäßige Verteilung.
	var anteil := maxf(NACHZUEGLER_ANTEIL, float(nachzuegler.size()) / helden.size())
	for held in helden:
		if held in nachzuegler:
			verteilung[held] = anteil / nachzuegler.size()
		else:
			verteilung[held] = (1.0 - anteil) / rest
	return verteilung


## XP jedes Helden für diesen Sieg: Nachzügler-Verteilung × sein Level-Faktor.
static func xp_fuer_helden(enemies: Array[Combatant], is_boss: bool, run_affixes: Array,
		helden: Array[Combatant]) -> Dictionary:
	var ergebnis := {}
	var verteilung := xp_verteilung(helden)
	for held in helden:
		ergebnis[held] = maxi(1, roundi(xp_fuer(enemies, is_boss, run_affixes, held.level) * verteilung[held]))
	return ergebnis


## XP-Anteil EINES Helden: die Kampf-XP (mit seinem Level-Faktor) geteilt
## durch die Zahl der Helden im Kampf (Lutz: XP wird geteilt — wer einen
## Helden gezielt leveln will, setzt den Rest auf die Bank). Gefallene
## bekommen ihren Anteil trotzdem (kein Feel-Bad).
static func xp_anteil(enemies: Array[Combatant], is_boss: bool, run_affixes: Array,
		held_level: int, helden: int) -> int:
	return maxi(1, roundi(float(xp_fuer(enemies, is_boss, run_affixes, held_level)) / maxi(1, helden)))


## Kampf-XP über diese Gegner (VOR der Teilung): leicht überproportional mit
## dem Gegnerlevel, × xp_mult (Metallschleim), Boss ×3, Kartenaffix „uralt“
## ×1.25. held_level ≥ 0: mit Level-Faktor für diesen Helden.
static func xp_fuer(enemies: Array[Combatant], is_boss: bool, run_affixes: Array,
		held_level := -1) -> int:
	var xp := 0
	for foe in enemies:
		if foe.is_summon:
			continue
		var faktor := 1.0 if held_level < 0 else xp_level_faktor(held_level, foe.level)
		if not is_boss:
			faktor *= DungeonGenerator.beute_faktor(foe.level)
		xp += roundi((8 + foe.level * 4 + foe.level * foe.level / 20.0) * foe.xp_mult * faktor)
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
	# Weniger, dafür lohnendere Gegner (DungeonGenerator.beute_faktor) —
	# Chancen über 100 % geben mehrere Drops.
	var dichte := 1.0 if is_boss else DungeonGenerator.beute_faktor(tier)
	for enemy in enemies:
		gold += roundi(gold_for_kill(tier, enemy.loot_mult, rng) * dichte)
		var item_chance := ITEM_DROP_CHANCE * enemy.loot_mult * drop_mult * dichte
		while item_chance > 0.0:
			if rng.randf() < item_chance:
				items.append(roll_item(tier, rng))
			item_chance -= 1.0
		var material_chance := MATERIAL_DROP_CHANCE * enemy.loot_mult * dichte
		while material_chance > 0.0:
			if rng.randf() < material_chance:
				material_ids.append(material_for_enemy(enemy, rng, tier))
			material_chance -= 1.0
	gold = roundi(gold * (1.0 + luck * 0.004))
	if is_boss:
		while items.size() < BOSS_ITEM_COUNT:
			items.append(roll_item(tier, rng))
		material_ids.append(MaterialLibrary.roll(rng, tier, true))
		material_ids.append(MaterialLibrary.roll(rng, tier, true))
		# Selten: eine Rune, die beim Schmieden eine Mindest-Rarität garantiert.
		var rune := MaterialLibrary.roll_rune(rng)
		if rune != &"":
			material_ids.append(rune)
		gold *= 2
	return {"gold": gold, "items": items, "materials": material_ids}
