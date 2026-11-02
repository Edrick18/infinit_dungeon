class_name MerchantOrders
extends RefCounted
## Händler-Aufträge: 3 rotierende Aufgaben mit Gold, Materialien oder einer
## WUNSCH-KARTE als Belohnung — gibt gezielten Farm-Loops eine Struktur.
## Arten: Material liefern (deliver), N Gegner besiegen (hunt), Biom-Karte
## abschließen (clear) und — mit Bezug zum Bestiarium (2026-11-02) —
## N Gegner eines Grundtyps (hunt_type), Elite mit Merkmal (elite),
## Eigenheit auslösen (eigenheit) und einen bestimmten Boss eines Bioms ab
## Stufe N (boss).
## Ziele kommen nur aus Gegnern, die auf Karten um den Party-Schnitt
## vorkommen; Eigenheiten nur bekannte oder dort vorkommende.

const ORDER_SLOTS := 3

## Wahrscheinlichkeiten der Auftragsarten (Summe 1). Fehlt ein passendes Ziel,
## wird ein Jagd-Auftrag daraus.
const ARTEN := [
	["deliver", 0.28], ["hunt", 0.18], ["clear", 0.14], ["hunt_type", 0.16],
	["elite", 0.09], ["eigenheit", 0.08], ["boss", 0.07],
]
## Ab welchem Party-Schnitt eine Art vorkommt.
const ARTEN_AB := {"elite": 3, "boss": 3, "eigenheit": 2}
## Gold-Belohnung je Art (Mühe), Faktor auf den Grundwert.
const GOLD_FAKTOR := {"hunt_type": 1.3, "elite": 1.5, "eigenheit": 1.4, "boss": 2.0}


## state (optional): GameState — für bekannte Eigenheiten.
static func make_order(avg_level: int, rng: RandomNumberGenerator, state: Node = null) -> Dictionary:
	var art := _art_wuerfeln(avg_level, rng)
	var order := _ziel_wuerfeln(art, avg_level, rng, state)
	if order.is_empty():
		order = {"type": "hunt", "count": rng.randi_range(8, 14), "progress": 0}
	order["reward"] = _roll_reward(avg_level, rng, float(GOLD_FAKTOR.get(order["type"], 1.0)))
	return order


static func _art_wuerfeln(avg_level: int, rng: RandomNumberGenerator) -> String:
	var roll := rng.randf()
	for eintrag in ARTEN:
		roll -= float(eintrag[1])
		if roll < 0.0:
			return eintrag[0] if avg_level >= int(ARTEN_AB.get(eintrag[0], 1)) else "hunt"
	return "hunt"


## Biome, deren Karten es um den Party-Schnitt gibt.
static func biome_fuer(avg_level: int) -> Array:
	var pool: Array = []
	for biome in CardFactory.BIOME_UNLOCK_TIER:
		if avg_level >= CardFactory.BIOME_UNLOCK_TIER[biome] \
				and avg_level <= CardFactory.BIOME_RETIRE_TIER[biome]:
			pool.append(biome)
	if pool.is_empty():
		pool.append(Enums.Biome.FOREST)
	return pool


## Normale Grundtypen, die auf Karten um den Party-Schnitt vorkommen.
static func grundtypen_fuer(avg_level: int) -> Array[StringName]:
	var result: Array[StringName] = []
	for biome in biome_fuer(avg_level):
		for archetype in EnemyLibrary.archetypes_for_biome(biome, false, maxi(1, avg_level)):
			if archetype.id != &"mimic" and archetype.id not in result:
				result.append(archetype.id)
	return result


## Eigenheiten, die man als Ziel bekommen kann: bekannte (Bestiarium) oder
## solche von Grundtypen der erreichbaren Biome.
static func eigenheiten_fuer(avg_level: int, state: Node = null) -> Array[StringName]:
	var result: Array[StringName] = []
	var quellen: Array = []
	for id in grundtypen_fuer(avg_level):
		quellen.append(String(id))
	if state != null and "eigenheit_wissen" in state:
		for id in state.eigenheit_wissen:
			quellen.append(String(id))
	for id in quellen:
		var eigenheit := Eigenheiten.fuer(StringName(id))
		if eigenheit != &"" and eigenheit not in result:
			result.append(eigenheit)
	return result


static func _ziel_wuerfeln(art: String, avg_level: int, rng: RandomNumberGenerator, state: Node) -> Dictionary:
	match art:
		"deliver":
			var mat_ids: Array = MaterialLibrary.basis_ids()
			return {"type": "deliver", "material": mat_ids[rng.randi_range(0, mat_ids.size() - 1)],
				"count": rng.randi_range(3, 6)}
		"hunt":
			return {"type": "hunt", "count": rng.randi_range(8, 14), "progress": 0}
		"clear":
			var pool := biome_fuer(avg_level)
			return {"type": "clear", "biome": pool[rng.randi_range(0, pool.size() - 1)],
				"min_tier": maxi(1, avg_level - 1), "count": 1, "progress": 0}
		"hunt_type":
			var typen := grundtypen_fuer(avg_level)
			if typen.is_empty():
				return {}
			return {"type": "hunt_type", "archetype": typen[rng.randi_range(0, typen.size() - 1)],
				"count": rng.randi_range(4, 8), "progress": 0}
		"elite":
			var merkmale: Array[StringName] = []
			for modifier in EnemyLibrary.all_modifiers():
				if modifier.min_tier <= avg_level:
					merkmale.append(modifier.id)
			if merkmale.is_empty():
				return {}
			return {"type": "elite", "modifier": merkmale[rng.randi_range(0, merkmale.size() - 1)],
				"count": rng.randi_range(1, 3), "progress": 0}
		"eigenheit":
			var eigenheiten := eigenheiten_fuer(avg_level, state)
			if eigenheiten.is_empty():
				return {}
			return {"type": "eigenheit", "eigenheit": eigenheiten[rng.randi_range(0, eigenheiten.size() - 1)],
				"count": rng.randi_range(1, 3), "progress": 0}
		"boss":
			var biome := biome_fuer(avg_level)
			var biome_id: int = biome[rng.randi_range(0, biome.size() - 1)]
			var min_tier := maxi(1, avg_level - 2)
			var bosse := EnemyFactory.boss_pool(biome_id as Enums.Biome, min_tier)
			if bosse.is_empty():
				return {}
			return {"type": "boss", "biome": biome_id, "min_tier": min_tier,
				"archetype": bosse[rng.randi_range(0, bosse.size() - 1)].id, "count": 1, "progress": 0}
	return {}


static func _roll_reward(avg_level: int, rng: RandomNumberGenerator, gold_faktor := 1.0) -> Dictionary:
	var roll := rng.randf()
	if roll < 0.45:
		return {"kind": "gold", "gold": roundi((40 + avg_level * 12 + rng.randi_range(0, 20)) * gold_faktor)}
	if roll < 0.75:
		var mat_ids: Array = MaterialLibrary.basis_ids()
		var first: StringName = mat_ids[rng.randi_range(0, mat_ids.size() - 1)]
		var second: StringName = mat_ids[rng.randi_range(0, mat_ids.size() - 1)]
		var menge := 3 if gold_faktor > 1.0 else 2
		var mats := {first: menge}
		mats[second] = mats.get(second, 0) + menge
		return {"kind": "materials", "materials": mats}
	# Wunsch-Karte: Biom fix versprochen, Stufe = Party-Schnitt beim Abholen.
	var biomes: Array = CardFactory.BIOME_NAMES.keys()
	return {"kind": "card", "biome": biomes[rng.randi_range(0, biomes.size() - 1)]}


static func _grundtyp_name(id: StringName) -> String:
	var archetype := EnemyLibrary.get_archetype(id)
	return archetype.display_name if archetype != null else String(id)


static func _merkmal_name(id: StringName) -> String:
	var modifier := EnemyLibrary.get_modifier(id)
	return modifier.display_name if modifier != null else String(id)


## Auftragstext für die Händler-UI.
static func describe(order: Dictionary) -> String:
	match order["type"]:
		"deliver":
			return Loc.pick("Liefere %d× %s", "Deliver %d× %s") % [order["count"],
				MaterialLibrary.display_name(order["material"])]
		"hunt":
			return Loc.pick("Besiege %d Gegner (%d/%d)", "Defeat %d enemies (%d/%d)") % [order["count"],
				order["progress"], order["count"]]
		"clear":
			return Loc.pick("Schließe eine %s-Karte (Stufe %d+) ab%s", "Complete a %s map (tier %d+)%s") % [
				CardFactory.biome_name(order["biome"]), order["min_tier"],
				" [OK]" if order["progress"] >= 1 else ""]
		"hunt_type":
			return Loc.pick("Besiege %d Gegner vom Grundtyp %s (%d/%d)", "Defeat %d enemies of the base type %s (%d/%d)") \
				% [order["count"], _grundtyp_name(order["archetype"]), order["progress"], order["count"]]
		"elite":
			return Loc.pick("Besiege %d Elite-Gegner mit dem Merkmal %s (%d/%d)",
				"Defeat %d elite enemies with the trait %s (%d/%d)") \
				% [order["count"], _merkmal_name(order["modifier"]), order["progress"], order["count"]]
		"eigenheit":
			return Loc.pick("Löse die Eigenheit %s aus (%d/%d)", "Trigger the trait %s (%d/%d)") \
				% [Eigenheiten.name_von(order["eigenheit"]), order["progress"], order["count"]]
		"boss":
			return Loc.pick("Besiege den Boss %s (Biom %s, Stufe %d+)%s",
				"Defeat the boss %s (biome %s, tier %d+)%s") % [_grundtyp_name(order["archetype"]),
				CardFactory.biome_name(order["biome"]), order["min_tier"],
				" [OK]" if order["progress"] >= 1 else ""]
	return "?"


static func reward_text(order: Dictionary) -> String:
	var reward: Dictionary = order["reward"]
	match reward["kind"]:
		"gold":
			return "%d Gold" % reward["gold"]
		"materials":
			var parts: Array[String] = []
			for id in reward["materials"]:
				parts.append("%d× %s" % [reward["materials"][id],
					MaterialLibrary.display_name(id)])
			return ", ".join(parts)
		"card":
			return Loc.pick("Wunsch-Karte: %s (Stufe = Party-Schnitt)",
				"Wish map: %s (tier = party average)") \
				% CardFactory.biome_name(reward["biome"])
	return "?"


## Erfüllt? deliver prüft den Materialvorrat, alle anderen den Fortschritt.
static func is_complete(order: Dictionary, state: Node) -> bool:
	match order["type"]:
		"deliver":
			return state.material_count(order["material"]) >= order["count"]
		"hunt", "clear", "hunt_type", "elite", "eigenheit", "boss":
			return order["progress"] >= order["count"]
	return false


# --- Fortschritt ---------------------------------------------------------------

## Trägt ein Gegner dieses Elite-Merkmal? Merkmale stehen im Namen
## („… [Gepanzert, Schnell]“), Elite/Champion im Meta „rang“.
static func traegt_merkmal(gegner: Combatant, modifier_id: StringName) -> bool:
	if String(gegner.get_meta(&"rang", "")) not in ["elite", "champion"]:
		return false
	var modifier := EnemyLibrary.get_modifier(modifier_id)
	if modifier == null:
		return false
	var name := gegner.display_name
	var auf := name.rfind("[")
	if auf < 0:
		return false
	for teil in name.substr(auf + 1).trim_suffix("]").split(","):
		if teil.strip_edges() == modifier.display_name:
			return true
	return false


## Gewonnener Kampf: Grundtyp-, Elite- und Boss-Aufträge zählen mit.
## besiegte = die gefallenen Gegner (ohne Beschwörungen).
static func kampf_zaehlen(orders: Array, besiegte: Array, is_boss: bool, card: DungeonCard) -> void:
	for order in orders:
		var vorher := int(order.get("progress", 0))
		match order["type"]:
			"hunt_type":
				for foe: Combatant in besiegte:
					if foe.archetype_id == order["archetype"]:
						order["progress"] = int(order["progress"]) + 1
			"elite":
				for foe: Combatant in besiegte:
					if traegt_merkmal(foe, order["modifier"]):
						order["progress"] = int(order["progress"]) + 1
			"boss":
				if is_boss and card != null and card.biome == int(order["biome"]) \
						and card.tier >= int(order["min_tier"]):
					for foe: Combatant in besiegte:
						if (foe.ist_bossgegner or foe.is_boss) and foe.archetype_id == order["archetype"]:
							order["progress"] = 1
		if order.has("count") and order["type"] != "deliver":
			order["progress"] = mini(int(order["count"]), maxi(vorher, int(order["progress"])))


## Eine Eigenheit hat gewirkt (Kampf-Signal).
static func eigenheit_zaehlen(orders: Array, eigenheit: StringName) -> void:
	for order in orders:
		if order["type"] == "eigenheit" and StringName(order["eigenheit"]) == eigenheit:
			order["progress"] = mini(int(order["count"]), int(order["progress"]) + 1)


# --- Serialisierung (StringName/Enum » JSON-tauglich) ---------------------------

static func to_dict(order: Dictionary) -> Dictionary:
	var out := {
		"type": order["type"],
		"count": order.get("count", 0),
		"progress": order.get("progress", 0),
		"min_tier": order.get("min_tier", 0),
		"biome": int(order.get("biome", -1)),
	}
	for schluessel in ["material", "archetype", "modifier", "eigenheit"]:
		if order.has(schluessel):
			out[schluessel] = String(order[schluessel])
	var reward: Dictionary = order["reward"]
	var reward_out := {"kind": reward["kind"]}
	if reward.has("gold"):
		reward_out["gold"] = reward["gold"]
	if reward.has("biome"):
		reward_out["biome"] = int(reward["biome"])
	if reward.has("materials"):
		var mats := {}
		for id in reward["materials"]:
			mats[String(id)] = reward["materials"][id]
		reward_out["materials"] = mats
	out["reward"] = reward_out
	return out


static func from_dict(data: Dictionary) -> Dictionary:
	var order := {
		"type": data.get("type", "hunt"),
		"count": int(data.get("count", 1)),
		"progress": int(data.get("progress", 0)),
	}
	for schluessel in ["material", "archetype", "modifier", "eigenheit"]:
		if data.has(schluessel):
			order[schluessel] = StringName(data[schluessel])
	if int(data.get("biome", -1)) >= 0:
		order["biome"] = int(data["biome"])
	if int(data.get("min_tier", 0)) > 0:
		order["min_tier"] = int(data["min_tier"])
	# Unbekannte Art (neuerer Spielstand) oder fehlendes Ziel: Jagd-Auftrag.
	var ziel_fehlt: bool = (order["type"] == "hunt_type" and not order.has("archetype")) \
		or (order["type"] == "elite" and not order.has("modifier")) \
		or (order["type"] == "eigenheit" and not order.has("eigenheit")) \
		or (order["type"] == "clear" and not order.has("biome")) \
		or (order["type"] == "boss" and not (order.has("biome") and order.has("archetype")))
	if order["type"] not in ["deliver", "hunt", "clear", "hunt_type", "elite", "eigenheit", "boss"] or ziel_fehlt:
		order["type"] = "hunt"
	if order["type"] in ["clear", "boss"] and not order.has("min_tier"):
		order["min_tier"] = 1
	var reward_in: Dictionary = data.get("reward", {"kind": "gold", "gold": 50})
	var reward := {"kind": reward_in.get("kind", "gold")}
	if reward_in.has("gold"):
		reward["gold"] = int(reward_in["gold"])
	if reward_in.has("biome"):
		reward["biome"] = int(reward_in["biome"])
	if reward_in.has("materials"):
		var mats := {}
		for id_str in reward_in["materials"]:
			mats[StringName(id_str)] = int(reward_in["materials"][id_str])
		reward["materials"] = mats
	order["reward"] = reward
	return order
