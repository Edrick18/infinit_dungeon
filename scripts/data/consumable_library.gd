class_name ConsumableLibrary
extends RefCounted
## Katalog aller Verbrauchsgegenstände.
## Heilung/Mana: Prozent vom Max-Wert ODER Flat — es gilt der höhere Wert.
## Pro Statuseffekt gibt es einen eigenen Kur-Trank; das Allheilmittel wird
## aus allen fünf zusammen gecraftet und entfernt alles.

static var _defs: Dictionary = {}


## Sprachwechsel: Cache leeren, Namen backen sich neu.
static func reset_cache() -> void:
	_defs.clear()


static func get_def(id: StringName) -> ConsumableDef:
	_ensure_built()
	return _defs.get(id)


static func all_defs() -> Array[ConsumableDef]:
	_ensure_built()
	var result: Array[ConsumableDef] = []
	for id in _defs:
		result.append(_defs[id])
	return result


static func buyable_defs() -> Array[ConsumableDef]:
	var result: Array[ConsumableDef] = []
	for def in all_defs():
		if def.price > 0:
			result.append(def)
	return result


static func craftable_defs() -> Array[ConsumableDef]:
	var result: Array[ConsumableDef] = []
	for def in all_defs():
		if def.is_craftable():
			result.append(def)
	return result


static func _ensure_built() -> void:
	if not _defs.is_empty():
		return

	# --- Heilung & Mana (kaufbar: die einfachen; craftbar: alle) ------------
	var heil := _def(&"heiltrank", Loc.pick("Heiltrank", "Healing Potion"),
		Loc.pick("Stellt 20% der Max-HP wieder her (mind. 30).", "Restores 20% of max HP (at least 30)."),
		Enums.ConsumableEffect.HEAL_HP, 30, 20)
	heil.price = 25
	heil.craft_materials = {&"heilkraut": 2}

	var gross_heil := _def(&"grosser_heiltrank", Loc.pick("Großer Heiltrank", "Greater Healing Potion"),
		Loc.pick("Stellt 45% der Max-HP wieder her (mind. 80).", "Restores 45% of max HP (at least 80)."),
		Enums.ConsumableEffect.HEAL_HP, 80, 45)
	gross_heil.craft_materials = {&"heilkraut": 5}
	gross_heil.price = 80

	var mana := _def(&"manatrank", Loc.pick("Manatrank", "Mana Potion"),
		Loc.pick("Stellt 20% der Max-MP wieder her (mind. 20).", "Restores 20% of max MP (at least 20)."),
		Enums.ConsumableEffect.RESTORE_MP, 20, 20)
	mana.price = 25
	mana.craft_materials = {&"manabluete": 2}

	var gross_mana := _def(&"grosser_manatrank", Loc.pick("Großer Manatrank", "Greater Mana Potion"),
		Loc.pick("Stellt 45% der Max-MP wieder her (mind. 50).", "Restores 45% of max MP (at least 50)."),
		Enums.ConsumableEffect.RESTORE_MP, 50, 45)
	gross_mana.craft_materials = {&"manabluete": 5}
	gross_mana.price = 80

	var revive := _def(&"belebungselixier", Loc.pick("Belebungselixier", "Revival Elixir"),
		Loc.pick("Belebt einen Gefallenen mit 50% HP.", "Revives a fallen hero with 50% HP."),
		Enums.ConsumableEffect.REVIVE, 50, 0)
	revive.craft_materials = {&"heilkraut": 3, &"manabluete": 3}
	revive.price = 150

	# --- Ein Kur-Trank pro Statuseffekt --------------------------------------
	_cure(&"brandsalbe", Loc.pick("Brandsalbe", "Burn Salve"), Loc.pick("Löscht Brand.", "Extinguishes burn."),
		[Enums.Status.BURN])
	_cure(&"gegengift", Loc.pick("Gegengift", "Antidote"), Loc.pick("Neutralisiert Gift.", "Neutralizes poison."),
		[Enums.Status.POISON_DOT])
	_cure(&"weckelixier", Loc.pick("Weckelixier", "Waking Elixir"), Loc.pick("Beendet Betäubung.", "Ends stun."),
		[Enums.Status.STUN])
	_cure(&"tempotrunk", Loc.pick("Tempotrunk", "Haste Draught"), Loc.pick("Hebt Verlangsamung auf.", "Removes slow."),
		[Enums.Status.SLOW])
	_cure(&"staerkungstonikum", Loc.pick("Stärkungstonikum", "Fortifying Tonic"), Loc.pick("Vertreibt Schwächung.", "Removes weaken."),
		[Enums.Status.WEAKEN])
	_cure(&"waermetrank", Loc.pick("Wärmetrank", "Warming Potion"), Loc.pick("Taut Eingefrorene auf.", "Thaws the frozen."),
		[Enums.Status.FROZEN])
	_cure(&"fluchbrecher", Loc.pick("Fluchbrecher", "Curse Breaker"), Loc.pick("Bricht Flüche.", "Breaks curses."),
		[Enums.Status.CURSED])
	# Kuren für die Trainings-Leiden (Blutung/Markierung/Rüstungsriss).
	_cure(&"verbandszeug", Loc.pick("Verbandszeug", "Bandages"), Loc.pick("Stillt Blutungen.", "Stops bleeding."),
		[Enums.Status.BLEED])
	_cure(&"tarnpuder", Loc.pick("Tarnpuder", "Camouflage Powder"), Loc.pick("Entfernt Markierungen.", "Removes marks."),
		[Enums.Status.MARKED])
	_cure(&"schmiedepaste", Loc.pick("Schmiedepaste", "Armor Paste"), Loc.pick("Repariert gerissene Rüstung.", "Repairs broken armor."),
		[Enums.Status.ARMOR_BREAK])

	# --- Allheilmittel: aus ALLEN Kur-Tränken gecraftet ----------------------
	var panacea := _def(&"allheilmittel", Loc.pick("Allheilmittel", "Panacea"),
		Loc.pick("Entfernt sämtliche negativen Statuseffekte.", "Removes all negative status effects."),
		Enums.ConsumableEffect.CURE_AILMENTS, 0, 0)
	panacea.cures = Battle.CURABLE_STATUSES.duplicate()
	panacea.craft_consumables = {
		&"brandsalbe": 1, &"gegengift": 1, &"weckelixier": 1,
		&"tempotrunk": 1, &"staerkungstonikum": 1,
		&"waermetrank": 1, &"fluchbrecher": 1,
		&"verbandszeug": 1, &"tarnpuder": 1, &"schmiedepaste": 1,
	}


static func _def(id: StringName, name: String, description: String,
		effect: Enums.ConsumableEffect, potency: int, percent: int) -> ConsumableDef:
	var def := ConsumableDef.new()
	def.id = id
	def.display_name = name
	def.description = description
	def.effect = effect
	def.potency = potency
	def.potency_percent = percent
	_defs[id] = def
	return def


static func _cure(id: StringName, name: String, description: String,
		cures: Array[Enums.Status]) -> ConsumableDef:
	var def := _def(id, name, description, Enums.ConsumableEffect.CURE_AILMENTS, 0, 0)
	def.cures = cures
	def.craft_materials = {&"reinigungssalz": 2}
	def.price = 40
	return def
