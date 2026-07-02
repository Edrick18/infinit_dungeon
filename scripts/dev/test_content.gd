class_name TestContent
extends RefCounted
## Handgebauter Platzhalter-Content für den Kampf-Prototyp.
## Zeigt, wie Skills aus Bauklötzen entstehen — später kommt das alles
## aus dem Skill-Crafting-UI und dem Gegner-Generator.


static func make_party() -> Array[Combatant]:
	# Klassenlos und komplett gleichberechtigt: Alle Helden starten mit
	# identischen Stats (5 auf jedem Wert, Level 1). Die Rolle entsteht
	# erst durch Statuspunkte, Skill-Bauklötze und Ausrüstung —
	# nur der Start-Skill gibt eine erste Richtung vor.
	return [
		_hero("Aldric", [_wuchtschlag()]),
		_hero("Mira", [_feuerball()]),
		_hero("Talin", [_heilende_aura()]),
		_hero("Runa", [_giftwolke()]),
	]


static func _hero(name: String, skills: Array[Skill]) -> Combatant:
	var hero := Combatant.create(name, _stats(5, 5, 5, 5, 5, 5), true)
	hero.skills = skills
	hero.sprite = SpriteLib.hero(name)
	return hero


# --- Beispiel-Skills aus Bauklötzen ---------------------------------------

## Physisch, Nahkampf: harter Einzelziel-Schlag.
static func _wuchtschlag() -> Skill:
	return _skill("Wuchtschlag", [
		_damage(Enums.DamageAxis.PHYSICAL, 8, &"strength", 1.5, 3),
		_carrier(Enums.Carrier.MELEE, 1.0, 1.2),
	])


## Physisch + Status: weniger Schaden, Chance auf Betäubung.
static func _betaeubender_schlag() -> Skill:
	return _skill("Betäubender Schlag", [
		_damage(Enums.DamageAxis.PHYSICAL, 6, &"strength", 1.0, 2),
		_effect(Enums.Status.STUN, 60, 1, 0, 6),
		_carrier(Enums.Carrier.MELEE, 1.0, 1.0),
	])


## Magisch + elementar kombiniert: Rohschaden plus Brand-DoT — zwei Achsen in einem Skill.
static func _feuerball() -> Skill:
	var burn := _damage(Enums.DamageAxis.ELEMENTAL, 9, &"intelligence", 0.5, 3)
	burn.element = Enums.Element.FIRE
	burn.dot_turns = 3
	return _skill("Feuerball", [
		_damage(Enums.DamageAxis.MAGICAL, 10, &"intelligence", 1.2, 5),
		burn,
		_carrier(Enums.Carrier.PROJECTILE, 1.0, 1.0),
	])


## Magisch, Fläche + Verlangsamung.
static func _frostwelle() -> Skill:
	return _skill("Frostwelle", [
		_damage(Enums.DamageAxis.MAGICAL, 6, &"intelligence", 0.8, 4),
		_effect(Enums.Status.SLOW, 80, 2, 30, 3),
		_carrier(Enums.Carrier.AOE, 1.6, 0.7),
	])


## Rein elementar, Fläche: Gift über Zeit auf alle Gegner.
static func _giftwolke() -> Skill:
	var poison := _damage(Enums.DamageAxis.ELEMENTAL, 12, &"spirit", 1.0, 5)
	poison.element = Enums.Element.POISON
	poison.dot_turns = 4
	return _skill("Giftwolke", [
		poison,
		_carrier(Enums.Carrier.AOE, 1.6, 0.7),
	])


## Aura auf die eigene Party: Regeneration + Schild.
static func _heilende_aura() -> Skill:
	return _skill("Heilende Aura", [
		_effect(Enums.Status.REGEN, 100, 3, 8, 6),
		_effect(Enums.Status.SHIELD, 100, 3, 10, 4),
		_carrier(Enums.Carrier.AURA, 1.0, 1.0),
	])


# --- Baustein-Helfer --------------------------------------------------------

static func _stats(strength: int, intelligence: int, vitality: int,
		spirit: int, agility: int, luck: int) -> StatBlock:
	var s := StatBlock.new()
	s.strength = strength
	s.intelligence = intelligence
	s.vitality = vitality
	s.spirit = spirit
	s.agility = agility
	s.luck = luck
	return s


static func _damage(axis: Enums.DamageAxis, base_amount: int, scaling_stat: StringName,
		per_point: float, mp_cost: int) -> DamageBlock:
	var block := DamageBlock.new()
	block.axis = axis
	block.base_amount = base_amount
	block.scaling_stat = scaling_stat
	block.scaling_per_point = per_point
	block.mp_cost = mp_cost
	return block


static func _carrier(kind: Enums.Carrier, cost_mult: float, power_mult: float) -> CarrierBlock:
	var block := CarrierBlock.new()
	block.carrier = kind
	block.cost_multiplier = cost_mult
	block.power_multiplier = power_mult
	return block


static func _effect(status: Enums.Status, chance: int, turns: int,
		potency: int, mp_cost: int) -> EffectBlock:
	var block := EffectBlock.new()
	block.status = status
	block.chance_percent = chance
	block.duration_turns = turns
	block.potency = potency
	block.mp_cost = mp_cost
	return block


static func _skill(name: String, blocks: Array[SkillBlock]) -> Skill:
	var skill := Skill.new()
	skill.display_name = name
	skill.blocks = blocks
	return skill
