class_name Battle
extends RefCounted
## Rundenbasierte Kampflogik, komplett UI-frei (headless testbar).
## Die UI-Szene treibt den Kampf: next_turn() liefert den aktiven Kämpfer,
## bei Spielern wartet die UI auf Eingabe, bei Gegnern ruft sie ai_take_turn().

signal log_line(text: String)
signal battle_ended(victory: bool)

const BASIC_ATTACK_BASE := 5
const CRIT_BASE_PERCENT := 5
const CRIT_MULTIPLIER := 1.5

var rng := RandomNumberGenerator.new()
var crit_enabled := true  ## Tests schalten Krits für Determinismus ab

var players: Array[Combatant] = []
var enemies: Array[Combatant] = []
var round_number := 0
var is_over := false

var _queue: Array[Combatant] = []


func start(p_players: Array[Combatant], p_enemies: Array[Combatant]) -> void:
	players = p_players
	enemies = p_enemies
	round_number = 0
	is_over = false
	_queue.clear()


## Liefert den nächsten handlungsfähigen Kämpfer. Verarbeitet dabei
## Statuseffekte am Zugbeginn (DoT-Ticks, Regeneration, Betäubung).
## Gibt null zurück, wenn der Kampf vorbei ist.
func next_turn() -> Combatant:
	while true:
		if is_over:
			return null
		if _queue.is_empty():
			_start_new_round()
			if _queue.is_empty():
				is_over = true
				return null
		var actor: Combatant = _queue.pop_front()
		if not actor.is_alive():
			continue
		var stunned := _process_turn_start(actor)
		if _check_battle_end():
			return null
		if not actor.is_alive():
			continue
		if stunned:
			continue
		return actor
	return null


func use_skill(actor: Combatant, skill: Skill, primary_target: Combatant) -> bool:
	if is_over or not skill.is_valid():
		return false
	var cost := skill.get_mp_cost()
	if actor.mp < cost:
		log_line.emit("%s hat nicht genug MP für %s." % [actor.display_name, skill.display_name])
		return false
	actor.mp -= cost

	var carrier := skill.get_carrier()
	var targets := _resolve_targets(actor, carrier.carrier, primary_target)
	log_line.emit("%s setzt %s ein!" % [actor.display_name, skill.display_name])

	var power_mult := carrier.power_multiplier
	var hits := 1
	for mod in skill.get_modifier_blocks():
		match mod.modifier:
			Enums.SkillModifier.POWER_AMP:
				power_mult *= 1.0 + mod.magnitude / 100.0
			Enums.SkillModifier.MULTI_HIT:
				hits += mod.magnitude

	for target in targets:
		for i in hits:
			if not target.is_alive():
				break
			_apply_skill_hit(actor, skill, target, power_mult)
	_check_battle_end()
	return true


func basic_attack(actor: Combatant, target: Combatant) -> void:
	if is_over:
		return
	log_line.emit("%s greift %s an." % [actor.display_name, target.display_name])
	var raw := float(BASIC_ATTACK_BASE + actor.stat(&"strength") + actor.weapon_damage())
	var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.PHYSICAL)
	log_line.emit("→ %d Schaden an %s." % [dealt, target.display_name])
	if not target.is_alive():
		log_line.emit("%s wurde besiegt!" % target.display_name)
	_check_battle_end()


## Simple Gegner-KI: bezahlbaren Skill oder Basisangriff auf zufälliges Ziel.
func ai_take_turn(actor: Combatant) -> void:
	var foes := _living(opponents_of(actor))
	if foes.is_empty():
		return
	var target: Combatant = foes[rng.randi_range(0, foes.size() - 1)]
	var usable: Array[Skill] = []
	for skill in actor.skills:
		if skill.is_valid() and actor.mp >= skill.get_mp_cost():
			usable.append(skill)
	if not usable.is_empty() and rng.randf() < 0.6:
		use_skill(actor, usable[rng.randi_range(0, usable.size() - 1)], target)
	else:
		basic_attack(actor, target)


func allies_of(c: Combatant) -> Array[Combatant]:
	return players if c.is_player else enemies


func opponents_of(c: Combatant) -> Array[Combatant]:
	return enemies if c.is_player else players


func _living(list: Array[Combatant]) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for c in list:
		if c.is_alive():
			result.append(c)
	return result


func _start_new_round() -> void:
	round_number += 1
	var all := _living(players)
	all.append_array(_living(enemies))
	all.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		return a.effective_speed() > b.effective_speed())
	_queue = all
	log_line.emit("— Runde %d —" % round_number)


## DoT-Ticks, Regeneration und Betäubung am Zugbeginn.
## Gibt true zurück, wenn der Zug ausgesetzt wird.
func _process_turn_start(actor: Combatant) -> bool:
	var stunned := false
	for entry in actor.statuses.duplicate():
		match entry["status"]:
			Enums.Status.BURN, Enums.Status.POISON_DOT:
				var dmg: int = entry["potency"]
				actor.take_damage(dmg)
				var kind: String = "Brand" if entry["status"] == Enums.Status.BURN else "Gift"
				log_line.emit("%s erleidet %d %s-Schaden." % [actor.display_name, dmg, kind])
			Enums.Status.REGEN:
				actor.heal(entry["potency"])
				log_line.emit("%s regeneriert %d HP." % [actor.display_name, entry["potency"]])
			Enums.Status.STUN:
				stunned = true
				log_line.emit("%s ist betäubt und setzt aus!" % actor.display_name)
		entry["turns"] -= 1
	for entry in actor.statuses.duplicate():
		if entry["turns"] <= 0:
			actor.statuses.erase(entry)
	if not actor.is_alive():
		log_line.emit("%s geht zu Boden!" % actor.display_name)
	return stunned


func _resolve_targets(actor: Combatant, carrier: Enums.Carrier, primary: Combatant) -> Array[Combatant]:
	match carrier:
		Enums.Carrier.MELEE, Enums.Carrier.PROJECTILE:
			var single: Array[Combatant] = []
			if primary != null and primary.is_alive():
				single.append(primary)
			return single
		Enums.Carrier.AOE:
			return _living(opponents_of(actor))
		Enums.Carrier.AURA:
			return _living(allies_of(actor))
		Enums.Carrier.SUMMON:
			log_line.emit("(Beschwörungen sind noch nicht implementiert.)")
	return []


func _apply_skill_hit(actor: Combatant, skill: Skill, target: Combatant, power_mult: float) -> void:
	var total_dealt := 0
	for dmg_block in skill.get_damage_blocks():
		var stat_value: int = actor.stat(dmg_block.scaling_stat)
		var raw := (dmg_block.base_amount + stat_value * dmg_block.scaling_per_point) * power_mult
		if dmg_block.axis == Enums.DamageAxis.ELEMENTAL and dmg_block.dot_turns > 0:
			var per_tick := maxi(1, roundi(raw / dmg_block.dot_turns))
			var status := Enums.Status.POISON_DOT if dmg_block.element == Enums.Element.POISON \
				else Enums.Status.BURN
			target.add_status(status, dmg_block.dot_turns, per_tick)
			var kind: String = "Gift" if status == Enums.Status.POISON_DOT else "Brand"
			log_line.emit("%s erleidet %s (%d Schaden über %d Runden)."
				% [target.display_name, kind, per_tick * dmg_block.dot_turns, dmg_block.dot_turns])
		else:
			var dealt := _deal_damage(actor, target, raw, dmg_block.axis)
			total_dealt += dealt
			log_line.emit("→ %d Schaden an %s." % [dealt, target.display_name])

	for effect in skill.get_effect_blocks():
		if rng.randi_range(1, 100) > effect.chance_percent:
			continue
		if effect.status == Enums.Status.LIFESTEAL:
			var healed := roundi(total_dealt * effect.potency / 100.0)
			if healed > 0:
				actor.heal(healed)
				log_line.emit("%s raubt %d HP." % [actor.display_name, healed])
		else:
			target.add_status(effect.status, effect.duration_turns, effect.potency)
			log_line.emit("%s: %s (%d Runden)."
				% [target.display_name, status_display_name(effect.status), effect.duration_turns])

	if not target.is_alive():
		log_line.emit("%s wurde besiegt!" % target.display_name)


## Rechnet Rohschaden gegen Mitigation, Schwächung und Krit, wendet ihn an.
func _deal_damage(attacker: Combatant, target: Combatant, raw: float, axis: Enums.DamageAxis) -> int:
	var weaken := attacker.get_status(Enums.Status.WEAKEN)
	if not weaken.is_empty():
		raw *= 1.0 - weaken["potency"] / 100.0
	var amount := roundi(raw)
	match axis:
		Enums.DamageAxis.PHYSICAL:
			amount -= target.total_armor()
		Enums.DamageAxis.MAGICAL:
			amount -= target.total_magic_resist()
	amount = maxi(1, amount)
	if crit_enabled and rng.randi_range(1, 100) <= CRIT_BASE_PERCENT + attacker.stat(&"luck"):
		amount = roundi(amount * CRIT_MULTIPLIER)
		log_line.emit("Kritischer Treffer!")
	return target.take_damage(amount)


func _check_battle_end() -> bool:
	if is_over:
		return true
	if _living(enemies).is_empty():
		is_over = true
		log_line.emit("Sieg! Alle Gegner wurden besiegt.")
		battle_ended.emit(true)
	elif _living(players).is_empty():
		is_over = true
		log_line.emit("Niederlage … Die Party wurde besiegt.")
		battle_ended.emit(false)
	return is_over


static func status_display_name(status: Enums.Status) -> String:
	match status:
		Enums.Status.STUN: return "Betäubt"
		Enums.Status.BURN: return "Brand"
		Enums.Status.POISON_DOT: return "Gift"
		Enums.Status.SLOW: return "Verlangsamt"
		Enums.Status.WEAKEN: return "Geschwächt"
		Enums.Status.LIFESTEAL: return "Lebensraub"
		Enums.Status.SHIELD: return "Schild"
		Enums.Status.REGEN: return "Regeneration"
	return "?"
