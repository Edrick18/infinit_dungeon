class_name ConsumableLibrary
extends RefCounted
## Katalog aller Verbrauchsgegenstände.
## Heilung/Mana: Prozent vom Max-Wert ODER Flat — es gilt der höhere Wert.
## Pro Statuseffekt gibt es einen eigenen Kur-Trank; das Allheilmittel wird
## aus allen fünf zusammen gecraftet und entfernt alles.

static var _defs: Dictionary = {}


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
	var heil := _def(&"heiltrank", "Heiltrank",
		"Stellt 20% der Max-HP wieder her (mind. 30).",
		Enums.ConsumableEffect.HEAL_HP, 30, 20)
	heil.price = 25
	heil.craft_materials = {&"heilkraut": 2}

	var gross_heil := _def(&"grosser_heiltrank", "Großer Heiltrank",
		"Stellt 45% der Max-HP wieder her (mind. 80).",
		Enums.ConsumableEffect.HEAL_HP, 80, 45)
	gross_heil.craft_materials = {&"heilkraut": 5}

	var mana := _def(&"manatrank", "Manatrank",
		"Stellt 20% der Max-MP wieder her (mind. 20).",
		Enums.ConsumableEffect.RESTORE_MP, 20, 20)
	mana.price = 25
	mana.craft_materials = {&"manabluete": 2}

	var gross_mana := _def(&"grosser_manatrank", "Großer Manatrank",
		"Stellt 45% der Max-MP wieder her (mind. 50).",
		Enums.ConsumableEffect.RESTORE_MP, 50, 45)
	gross_mana.craft_materials = {&"manabluete": 5}

	var revive := _def(&"belebungselixier", "Belebungselixier",
		"Belebt einen Gefallenen mit 50% HP.",
		Enums.ConsumableEffect.REVIVE, 50, 0)
	revive.craft_materials = {&"heilkraut": 3, &"manabluete": 3}

	# --- Ein Kur-Trank pro Statuseffekt --------------------------------------
	_cure(&"brandsalbe", "Brandsalbe", "Löscht Brand.",
		[Enums.Status.BURN])
	_cure(&"gegengift", "Gegengift", "Neutralisiert Gift.",
		[Enums.Status.POISON_DOT])
	_cure(&"weckelixier", "Weckelixier", "Beendet Betäubung.",
		[Enums.Status.STUN])
	_cure(&"tempotrunk", "Tempotrunk", "Hebt Verlangsamung auf.",
		[Enums.Status.SLOW])
	_cure(&"staerkungstonikum", "Stärkungstonikum", "Vertreibt Schwächung.",
		[Enums.Status.WEAKEN])
	_cure(&"waermetrank", "Wärmetrank", "Taut Eingefrorene auf.",
		[Enums.Status.FROZEN])
	_cure(&"fluchbrecher", "Fluchbrecher", "Bricht Flüche.",
		[Enums.Status.CURSED])

	# --- Allheilmittel: aus allen sieben Kur-Tränken gecraftet ---------------
	var panacea := _def(&"allheilmittel", "Allheilmittel",
		"Entfernt sämtliche negativen Statuseffekte.",
		Enums.ConsumableEffect.CURE_AILMENTS, 0, 0)
	panacea.cures = Battle.CURABLE_STATUSES.duplicate()
	panacea.craft_consumables = {
		&"brandsalbe": 1, &"gegengift": 1, &"weckelixier": 1,
		&"tempotrunk": 1, &"staerkungstonikum": 1,
		&"waermetrank": 1, &"fluchbrecher": 1,
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
	return def
