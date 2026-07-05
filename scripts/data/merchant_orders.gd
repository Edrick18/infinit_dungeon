class_name MerchantOrders
extends RefCounted
## Händler-Aufträge: 3 rotierende Aufgaben (Material liefern, Gegner jagen,
## Karte abschließen) mit Gold, Materialien oder einer WUNSCH-KARTE als
## Belohnung — gibt gezielten Farm-Loops eine Struktur.

const ORDER_SLOTS := 3


static func make_order(avg_level: int, rng: RandomNumberGenerator) -> Dictionary:
	var order: Dictionary
	var roll := rng.randf()
	if roll < 0.4:
		var mat_ids: Array = MaterialLibrary.MATERIALS.keys()
		order = {
			"type": "deliver",
			"material": mat_ids[rng.randi_range(0, mat_ids.size() - 1)],
			"count": rng.randi_range(3, 6),
		}
	elif roll < 0.75:
		order = {"type": "hunt", "count": rng.randi_range(8, 14), "progress": 0}
	else:
		var pool: Array = []
		for biome in CardFactory.BIOME_UNLOCK_TIER:
			if avg_level >= CardFactory.BIOME_UNLOCK_TIER[biome] \
					and avg_level <= CardFactory.BIOME_RETIRE_TIER[biome]:
				pool.append(biome)
		if pool.is_empty():
			pool.append(Enums.Biome.CRYPT)
		order = {
			"type": "clear",
			"biome": pool[rng.randi_range(0, pool.size() - 1)],
			"min_tier": maxi(1, avg_level - 1),
			"count": 1, "progress": 0,
		}
	order["reward"] = _roll_reward(avg_level, rng)
	return order


static func _roll_reward(avg_level: int, rng: RandomNumberGenerator) -> Dictionary:
	var roll := rng.randf()
	if roll < 0.45:
		return {"kind": "gold", "gold": 40 + avg_level * 12 + rng.randi_range(0, 20)}
	if roll < 0.75:
		var mat_ids: Array = MaterialLibrary.MATERIALS.keys()
		var first: StringName = mat_ids[rng.randi_range(0, mat_ids.size() - 1)]
		var second: StringName = mat_ids[rng.randi_range(0, mat_ids.size() - 1)]
		var mats := {first: 2}
		mats[second] = mats.get(second, 0) + 2
		return {"kind": "materials", "materials": mats}
	# Wunsch-Karte: Biom fix versprochen, Stufe = Party-Schnitt beim Abholen.
	var biomes: Array = CardFactory.BIOME_NAMES.keys()
	return {"kind": "card", "biome": biomes[rng.randi_range(0, biomes.size() - 1)]}


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
				" ✓" if order["progress"] >= 1 else ""]
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


## Erfüllt? deliver prüft den Materialvorrat, hunt/clear den Fortschritt.
static func is_complete(order: Dictionary, state: Node) -> bool:
	match order["type"]:
		"deliver":
			return state.material_count(order["material"]) >= order["count"]
		"hunt", "clear":
			return order["progress"] >= order["count"]
	return false


# --- Serialisierung (StringName/Enum → JSON-tauglich) ---------------------------

static func to_dict(order: Dictionary) -> Dictionary:
	var out := {
		"type": order["type"],
		"count": order.get("count", 0),
		"progress": order.get("progress", 0),
		"min_tier": order.get("min_tier", 0),
		"biome": int(order.get("biome", -1)),
	}
	if order.has("material"):
		out["material"] = String(order["material"])
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
	if data.has("material"):
		order["material"] = StringName(data["material"])
	if int(data.get("biome", -1)) >= 0:
		order["biome"] = int(data["biome"])
	if int(data.get("min_tier", 0)) > 0:
		order["min_tier"] = int(data["min_tier"])
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
