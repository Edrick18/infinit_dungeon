class_name Battle
extends RefCounted
## Rundenbasierte Kampflogik, komplett UI-frei (headless testbar).
## Die UI-Szene treibt den Kampf: next_turn() liefert den aktiven Kämpfer,
## bei Spielern wartet die UI auf Eingabe, bei Gegnern ruft sie ai_take_turn().

signal log_line(text: String)
signal battle_ended(victory: bool)
## Für die UI: Beschwörungen erscheinen/verschwinden mitten im Kampf.
signal combatant_added(combatant: Combatant)
signal combatant_removed(combatant: Combatant)

const BASIC_ATTACK_BASE := 5
const CRIT_BASE_PERCENT := 5
const CRIT_MULTIPLIER := 1.5

# Element-Signaturen (Phase 3)
const ICE_FREEZE_CHANCE := 50        ## % Chance auf Einfrieren, sonst Verlangsamen
const ICE_SHATTER_BONUS := 1.5       ## Physischer Treffer auf Eingefrorene: Bonus + Eis bricht
const LIGHTNING_CHAIN_FACTOR := 0.5  ## Ketten-Sprung macht 50% Schaden
const LIGHTNING_STUN_CHANCE := 25    ## % Betäubungs-Chance auf das Primärziel
const HOLY_UNDEAD_BONUS := 1.5       ## Heilig gegen Untote
const DARK_LIFESTEAL := 0.3          ## Dunkel heilt den Anwender um 30% des Schadens
const CURSE_TURNS := 2
const CURSE_POTENCY := 20            ## Fluch: +20% erlittener Schaden
const EXECUTE_HP_THRESHOLD := 0.3    ## Hinrichtung greift unter 30% HP

# Beschwörungen
const SUMMON_DURATION := 4           ## Züge, die eine Beschwörung bleibt
const SUMMON_POWER_FACTOR := 0.6     ## Anteil der Zauberkraft des Beschwörers
const SUMMON_HP_PER_SPIRIT := 5      ## HP-Skalierung mit SPI des Beschwörers

var rng := RandomNumberGenerator.new()
var crit_enabled := true  ## Tests schalten Krits für Determinismus ab

var players: Array[Combatant] = []
var enemies: Array[Combatant] = []
var round_number := 0
var is_over := false

var _queue: Array[Combatant] = []


func start(p_players: Array[Combatant], p_enemies: Array[Combatant]) -> void:
	# Kopien: Beschwörungen werden während des Kampfs hinzugefügt/entfernt —
	# das darf nie die geteilten GameState-Arrays (Party!) mutieren.
	players = p_players.duplicate()
	enemies = p_enemies.duplicate()
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
		# Beschwörungen laufen nach einer festen Zahl eigener Züge ab.
		if actor.is_summon:
			actor.summon_turns_left -= 1
			if actor.summon_turns_left < 0:
				_remove_summon(actor, "löst sich auf")
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
	var cost := skill.get_mp_cost(actor)
	if actor.mp < cost:
		log_line.emit("%s hat nicht genug MP für %s." % [actor.display_name, skill.display_name])
		return false
	actor.mp -= cost

	var form := skill.get_form()
	# Beschwörung: eigener Pfad — erschafft einen Verbündeten statt Ziele zu treffen.
	if form == Enums.SkillForm.SUMMON:
		log_line.emit("%s setzt %s ein!" % [actor.display_name, skill.display_name])
		_summon(actor, skill)
		return true

	var targets := _resolve_targets(actor, form, primary_target)
	# Beschützer fangen ALLE offensiven Angriffe ab (Einzelziel + Fläche) —
	# der Beschützer frisst jeden Treffer, der ein Teammitglied treffen würde
	# (und kann daran sterben).
	if form == Enums.SkillForm.SINGLE or form == Enums.SkillForm.AOE:
		var redirected: Array[Combatant] = []
		for target in targets:
			redirected.append(_apply_protection(target))
		targets = redirected
	log_line.emit("%s setzt %s ein!" % [actor.display_name, skill.display_name])

	# Wiederbelebungs-Effekte wirken auf Gefallene (die in keiner
	# normalen Zielliste auftauchen).
	for effect in skill.get_effect_blocks():
		if effect.status == Enums.Status.REVIVE \
				and rng.randi_range(1, 100) <= effect.chance_percent:
			for ally in allies_of(actor):
				if not ally.is_alive():
					ally.hp = maxi(1, roundi(ally.max_hp * effect.potency / 100.0))
					log_line.emit("%s kehrt mit %d HP zurück!"
						% [ally.display_name, ally.hp])

	var form_block := skill.get_form_block()
	var power_mult := form_block.power_multiplier if form_block != null else 1.0
	var hits := 1
	var chain_jumps := 0
	var spread_percent := 0
	for mod in skill.get_modifier_blocks():
		match mod.modifier:
			Enums.SkillModifier.POWER_AMP:
				power_mult *= 1.0 + mod.magnitude / 100.0
			Enums.SkillModifier.OVERLOAD:
				power_mult *= 1.0 + mod.magnitude / 100.0
			Enums.SkillModifier.MULTI_HIT:
				hits += mod.magnitude
			Enums.SkillModifier.CHAIN_ON_KILL:
				chain_jumps = maxi(chain_jumps, mod.magnitude)
			Enums.SkillModifier.SPREAD:
				spread_percent = maxi(spread_percent, mod.magnitude)

	var last_target: Combatant = null
	for target in targets:
		for i in hits:
			if not target.is_alive():
				break
			_apply_skill_hit(actor, skill, target, power_mult)
		last_target = target

	# Splitter: Einzelziel-Angriffe treffen zusätzlich alle anderen Gegner
	# abgeschwächt.
	if spread_percent > 0 and form == Enums.SkillForm.SINGLE and last_target != null:
		for other in _living(opponents_of(actor)):
			if other == last_target:
				continue
			log_line.emit("Splitter treffen %s!" % other.display_name)
			_apply_skill_hit(actor, skill, other, power_mult * spread_percent / 100.0)

	# Kettenreaktion: Stirbt das Ziel, springt der Skill auf ein weiteres über —
	# und weiter, solange die Kette tötet (max. magnitude Sprünge).
	if chain_jumps > 0 and form == Enums.SkillForm.SINGLE:
		var jumps := 0
		while last_target != null and not last_target.is_alive() and jumps < chain_jumps:
			var pool := _living(opponents_of(actor))
			if pool.is_empty():
				break
			var next: Combatant = pool[rng.randi_range(0, pool.size() - 1)]
			log_line.emit("Die Kette springt auf %s über!" % next.display_name)
			_apply_skill_hit(actor, skill, next, power_mult)
			last_target = next
			jumps += 1

	_check_battle_end()
	return true


func basic_attack(actor: Combatant, target: Combatant) -> void:
	if is_over:
		return
	target = _apply_protection(target)
	log_line.emit("%s greift %s an." % [actor.display_name, target.display_name])
	var raw := float(BASIC_ATTACK_BASE + actor.stat(&"strength") + actor.weapon_damage())
	var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.PHYSICAL,
		actor.weapon_subtypes())
	log_line.emit("→ %d Schaden an %s." % [dealt, target.display_name])
	if not target.is_alive():
		log_line.emit("%s wurde besiegt!" % target.display_name)
	_check_battle_end()


## Negative Statuseffekte, die ein Gegenmittel entfernt.
const CURABLE_STATUSES: Array[Enums.Status] = [
	Enums.Status.BURN, Enums.Status.POISON_DOT, Enums.Status.STUN,
	Enums.Status.SLOW, Enums.Status.WEAKEN,
	Enums.Status.FROZEN, Enums.Status.CURSED,
]


## Verbrauchsgegenstand einsetzen (kostet den Zug). Die Bestandsverwaltung
## macht die UI-Schicht — Battle bleibt frei von GameState-Zugriffen.
## false, wenn das Ziel ungültig ist (z.B. Heiltrank auf Gefallene).
func use_consumable(actor: Combatant, item: ConsumableDef, target: Combatant) -> bool:
	if is_over:
		return false
	match item.effect:
		Enums.ConsumableEffect.HEAL_HP:
			if not target.is_alive():
				return false
			var heal := item.heal_amount(target)
			target.heal(heal)
			log_line.emit("%s setzt %s ein: %s heilt %d HP."
				% [actor.display_name, item.display_name, target.display_name, heal])
		Enums.ConsumableEffect.RESTORE_MP:
			if not target.is_alive():
				return false
			var mana := item.mana_amount(target)
			target.mp = mini(target.max_mp, target.mp + mana)
			log_line.emit("%s setzt %s ein: %s erhält %d MP."
				% [actor.display_name, item.display_name, target.display_name, mana])
		Enums.ConsumableEffect.CURE_AILMENTS:
			if not target.is_alive():
				return false
			for entry in target.statuses.duplicate():
				if entry["status"] in item.cures:
					target.statuses.erase(entry)
			log_line.emit("%s setzt %s ein: %s ist kuriert."
				% [actor.display_name, item.display_name, target.display_name])
		Enums.ConsumableEffect.REVIVE:
			if target.is_alive():
				return false
			target.hp = maxi(1, roundi(target.max_hp * item.potency / 100.0))
			log_line.emit("%s setzt %s ein: %s kehrt mit %d HP zurück!"
				% [actor.display_name, item.display_name, target.display_name, target.hp])
	return true


## Verteidigungshaltung: halbiert erlittenen Schaden bis zum eigenen nächsten Zug.
func defend(actor: Combatant) -> void:
	if is_over:
		return
	actor.add_status(Enums.Status.GUARD, 1, 50)
	log_line.emit("%s geht in Verteidigungshaltung." % actor.display_name)


## Die nächsten Kämpfer dieser Runde (für die Zugreihenfolge-Anzeige).
func get_turn_preview(count := 5) -> Array[String]:
	var names: Array[String] = []
	for combatant in _queue:
		if combatant.is_alive():
			names.append(combatant.display_name)
		if names.size() >= count:
			break
	return names


## Simple Gegner-KI: bezahlbaren Skill oder Basisangriff auf zufälliges Ziel.
func ai_take_turn(actor: Combatant) -> void:
	var foes := _living(opponents_of(actor))
	if foes.is_empty():
		return
	var target: Combatant = foes[rng.randi_range(0, foes.size() - 1)]
	var usable: Array[Skill] = []
	for skill in actor.skills:
		if skill.is_valid() and actor.mp >= skill.get_mp_cost(actor):
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
## Stack-Statuseffekte (Brand/Gift): Schaden = aktuelle Stacks.
##   Brand halbiert seine Stacks nach jedem Tick (hoher Burst, kurz),
##   Gift behält seine Stacks für immer (bis kuriert).
## Gibt true zurück, wenn der Zug ausgesetzt wird.
func _process_turn_start(actor: Combatant) -> bool:
	var stunned := false
	for entry in actor.statuses.duplicate():
		match entry["status"]:
			Enums.Status.BURN:
				var burn_dmg: int = entry["potency"]
				actor.take_damage(burn_dmg)
				log_line.emit("%s erleidet %d Brand-Schaden." % [actor.display_name, burn_dmg])
				entry["potency"] = int(entry["potency"] / 2.0)  # Stacks halbieren
				if entry["potency"] < 1:
					actor.statuses.erase(entry)
				continue
			Enums.Status.POISON_DOT:
				var poison_dmg: int = entry["potency"]
				actor.take_damage(poison_dmg)
				log_line.emit("%s erleidet %d Gift-Schaden." % [actor.display_name, poison_dmg])
				continue  # Gift läuft nie von selbst ab
			Enums.Status.REGEN:
				actor.heal(entry["potency"])
				log_line.emit("%s regeneriert %d HP." % [actor.display_name, entry["potency"]])
			Enums.Status.MANA_REGEN:
				actor.mp = mini(actor.max_mp, actor.mp + entry["potency"])
				log_line.emit("%s regeneriert %d MP." % [actor.display_name, entry["potency"]])
			Enums.Status.STUN:
				stunned = true
				log_line.emit("%s ist betäubt und setzt aus!" % actor.display_name)
			Enums.Status.FROZEN:
				stunned = true
				log_line.emit("%s ist eingefroren und setzt aus!" % actor.display_name)
		entry["turns"] -= 1
	for entry in actor.statuses.duplicate():
		if entry["turns"] <= 0 and entry["status"] not in Combatant.STACKING_STATUSES:
			actor.statuses.erase(entry)
	if not actor.is_alive():
		log_line.emit("%s geht zu Boden!" % actor.display_name)
	return stunned


func _resolve_targets(actor: Combatant, form: Enums.SkillForm, primary: Combatant) -> Array[Combatant]:
	match form:
		Enums.SkillForm.SINGLE, Enums.SkillForm.ALLY:
			var single: Array[Combatant] = []
			if primary != null and primary.is_alive():
				single.append(primary)
			return single
		Enums.SkillForm.AOE:
			return _living(opponents_of(actor))
		Enums.SkillForm.AURA:
			return _living(allies_of(actor))
		Enums.SkillForm.SELF:
			return [actor]
	return []


## Erschafft eine Beschwörung auf der Seite des Anwenders. Die Variante
## ergibt sich aus den Bausteinen: ohne Element ein Wolf (physisch),
## mit Element ein Elementar (zaubert mit diesem Element). Effekt-Bausteine
## des Skills wirken auf die Beschwörung (z.B. Schutzwall → Wächter-Tank).
func _summon(actor: Combatant, skill: Skill) -> void:
	# Pro Beschwörer nur eine Beschwörung: die alte weicht der neuen.
	for ally in allies_of(actor).duplicate():
		if ally.is_summon and ally.summoner == actor:
			_remove_summon(ally, "weicht einer neuen Beschwörung")

	var element_block := skill.get_element()
	var power := (actor.spell_damage() + actor.stat(&"intelligence")) * SUMMON_POWER_FACTOR

	var stats := StatBlock.new()
	stats.vitality = 0
	stats.agility = actor.stat(&"agility")
	var summon_name := "Beschworener Wolf"
	if element_block != null:
		summon_name = "%s-Elementar" % element_block.display_name
	var summon := Combatant.create(summon_name, stats, actor.is_player)
	summon.is_summon = true
	summon.summoner = actor
	summon.summon_turns_left = SUMMON_DURATION
	summon.level = actor.level
	summon.max_hp = 15 + actor.stat(&"spirit") * SUMMON_HP_PER_SPIRIT
	summon.hp = summon.max_hp
	summon.max_mp = 999
	summon.mp = 999

	if element_block == null:
		# Wolf: physischer Angreifer (Biss über Waffennutzungs-Innenwerte).
		summon.innate_weapon_damage = maxi(1, roundi(power))
		summon.innate_weapon_subtypes = [Enums.PhysicalSubtype.PIERCE, Enums.PhysicalSubtype.SLASH] \
			as Array[Enums.PhysicalSubtype]
		summon.sprite = SpriteLib.enemy(&"wolf")
	else:
		# Elementar: zaubert mit dem Element des Skills (geteilte Bausteine).
		summon.innate_spell_damage = maxi(1, roundi(power))
		var elemental_skill := Skill.new()
		elemental_skill.display_name = "%s-Entladung" % element_block.display_name
		elemental_skill.blocks.append(BlockLibrary.get_block(&"src_spell"))
		elemental_skill.blocks.append(element_block)
		summon.skills = [elemental_skill]
		summon.sprite = SpriteLib.enemy(&"schleim")

	# Effekt-Bausteine wirken auf die Beschwörung (Schutzwall, Regeneration, …).
	for effect in skill.get_effect_blocks():
		if effect.status in [Enums.Status.LIFESTEAL, Enums.Status.CLEANSE, Enums.Status.REVIVE]:
			continue
		summon.add_status(effect.status, maxi(effect.duration_turns, SUMMON_DURATION),
			effect.potency)

	allies_of(actor).append(summon)
	_queue.append(summon)  # handelt noch in dieser Runde
	combatant_added.emit(summon)
	log_line.emit("%s erscheint (%d HP, %d Züge)!"
		% [summon.display_name, summon.max_hp, SUMMON_DURATION])


func _remove_summon(summon: Combatant, reason: String) -> void:
	log_line.emit("%s %s." % [summon.display_name, reason])
	players.erase(summon)
	enemies.erase(summon)
	_queue.erase(summon)
	combatant_removed.emit(summon)


## Ob eine Form auf Verbündete zielt (Heilung/Buffs statt Schaden).
static func _is_friendly_form(form: Enums.SkillForm) -> bool:
	return form == Enums.SkillForm.ALLY or form == Enums.SkillForm.AURA \
		or form == Enums.SkillForm.SELF


## Elemente, die als Schaden-über-Zeit wirken (statt Soforttreffer).
static func _is_dot_element(element: Enums.Element) -> bool:
	return element == Enums.Element.FIRE or element == Enums.Element.POISON


## Beschützer: Einzelziel-Angriffe treffen stattdessen den Verbündeten
## mit PROTECT-Status (Flächenangriffe treffen weiterhin alle).
func _apply_protection(target: Combatant) -> Combatant:
	if target == null or not target.is_alive() or target.has_status(Enums.Status.PROTECT):
		return target
	for ally in _living(allies_of(target)):
		if ally != target and ally.has_status(Enums.Status.PROTECT):
			log_line.emit("%s wirft sich schützend vor %s!"
				% [ally.display_name, target.display_name])
			return ally
	return target


func _apply_skill_hit(actor: Combatant, skill: Skill, target: Combatant, power_mult: float) -> void:
	var total_dealt := 0
	var friendly := _is_friendly_form(skill.get_form())
	var element_block := skill.get_element()

	# Modifikatoren, die pro Treffer wirken: Durchdringung + Hinrichtung.
	var pierce := 0.0
	var execute_bonus := 1.0
	for mod in skill.get_modifier_blocks():
		match mod.modifier:
			Enums.SkillModifier.PIERCE_ARMOR:
				pierce = maxf(pierce, mod.magnitude / 100.0)
			Enums.SkillModifier.EXECUTE:
				if target.hp <= target.max_hp * EXECUTE_HP_THRESHOLD:
					execute_bonus *= 1.0 + mod.magnitude / 100.0

	for source in skill.get_sources():
		if source.source == Enums.SkillSource.WEAPON:
			# Waffennutzung: physisch, nur gegen Gegner (hat nie eine Form).
			if friendly:
				continue
			var raw := (actor.weapon_damage() + actor.stat(&"strength") * source.scaling_per_point) \
				* power_mult * source.power_multiplier * execute_bonus
			var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.PHYSICAL,
				actor.weapon_subtypes(), pierce)
			total_dealt += dealt
			log_line.emit("→ %d Schaden an %s." % [dealt, target.display_name])
		else:
			# Zauber: Schaden aus Zauberschaden der Waffe + INT.
			var raw := (actor.spell_damage() + actor.stat(&"intelligence") * source.scaling_per_point) \
				* power_mult * source.power_multiplier * execute_bonus
			if friendly:
				# Heilig-Zauber auf Verbündete → Heilung (heiliger Schaden wird umgewandelt).
				if element_block != null and element_block.element == Enums.Element.HOLY:
					var heal := roundi(raw)
					target.heal(heal)
					log_line.emit("%s heilt %d HP." % [target.display_name, heal])
				# Ohne Heilig: reiner Support-Zauber, kein Schaden an Verbündeten.
			elif element_block != null:
				total_dealt += _apply_elemental_hit(actor, target, raw, element_block, pierce)
			else:
				var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.MAGICAL, [], pierce)
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
		elif effect.status == Enums.Status.REVIVE:
			pass  # Wird in use_skill auf Gefallene angewendet, nicht auf Zielliste.
		elif effect.status == Enums.Status.CLEANSE:
			# Kein Status: entfernt sofort alle Leiden vom Ziel.
			for entry in target.statuses.duplicate():
				if entry["status"] in CURABLE_STATUSES:
					target.statuses.erase(entry)
			log_line.emit("%s wird von allen Leiden gereinigt." % target.display_name)
		else:
			target.add_status(effect.status, effect.duration_turns, effect.potency)
			log_line.emit("%s: %s (%d Runden)."
				% [target.display_name, status_display_name(effect.status), effect.duration_turns])

	if not target.is_alive():
		log_line.emit("%s wurde besiegt!" % target.display_name)


## Element-Signaturen (Phase 3): Jedes Element spielt sich eigen.
##   Feuer → Brand-Stacks (Burst, halbiert sich) · Gift → permanente Stacks
##   Eis → Einfrieren/Verlangsamen · Blitz → Kette + Betäubungs-Chance
##   Heilig → Bonus vs. Untote · Dunkel → Lebensraub + Fluch
## Gibt den direkt verursachten Schaden zurück (für Lebensraub-Effekte).
func _apply_elemental_hit(actor: Combatant, target: Combatant, raw: float,
		element_block: ElementBlock, pierce := 0.0) -> int:
	match element_block.element:
		Enums.Element.FIRE, Enums.Element.POISON:
			# DoT-Elemente: Stacks basierend auf dem Schaden, addieren sich.
			var stacks := maxi(1, roundi(raw * element_block.status_scale))
			var status := Enums.Status.BURN if element_block.element == Enums.Element.FIRE \
				else Enums.Status.POISON_DOT
			target.add_status(status, -1, stacks)
			var kind: String = "Brand" if status == Enums.Status.BURN else "Gift"
			var total: int = target.get_status(status)["potency"]
			log_line.emit("%s: +%d %s-Stacks (jetzt %d)."
				% [target.display_name, stacks, kind, total])
			return 0
		Enums.Element.ICE:
			var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.MAGICAL, [], pierce)
			log_line.emit("→ %d Eisschaden an %s." % [dealt, target.display_name])
			if target.is_alive():
				if rng.randi_range(1, 100) <= ICE_FREEZE_CHANCE:
					target.add_status(Enums.Status.FROZEN, 1, 0)
					log_line.emit("%s friert ein!" % target.display_name)
				else:
					target.add_status(Enums.Status.SLOW, 2, 30)
					log_line.emit("%s ist unterkühlt (verlangsamt)." % target.display_name)
			return dealt
		Enums.Element.LIGHTNING:
			var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.MAGICAL, [], pierce)
			log_line.emit("→ %d Blitzschaden an %s." % [dealt, target.display_name])
			if target.is_alive() and rng.randi_range(1, 100) <= LIGHTNING_STUN_CHANCE:
				target.add_status(Enums.Status.STUN, 1, 0)
				log_line.emit("%s ist vom Blitz betäubt!" % target.display_name)
			# Kette: springt auf ein weiteres lebendes Ziel über.
			var others: Array[Combatant] = []
			for foe in _living(opponents_of(actor)):
				if foe != target:
					others.append(foe)
			if not others.is_empty():
				var jump_target: Combatant = others[rng.randi_range(0, others.size() - 1)]
				var jump_dealt := _deal_damage(actor, jump_target,
					raw * LIGHTNING_CHAIN_FACTOR, Enums.DamageAxis.MAGICAL, [], pierce)
				log_line.emit("Der Blitz springt über: %d Schaden an %s."
					% [jump_dealt, jump_target.display_name])
				if not jump_target.is_alive():
					log_line.emit("%s wurde besiegt!" % jump_target.display_name)
			return dealt
		Enums.Element.HOLY:
			var holy_raw := raw
			if target.is_undead:
				holy_raw *= HOLY_UNDEAD_BONUS
			var dealt := _deal_damage(actor, target, holy_raw, Enums.DamageAxis.MAGICAL, [], pierce)
			if target.is_undead:
				log_line.emit("→ %d heiliger Schaden an %s (sehr effektiv gegen Untote!)."
					% [dealt, target.display_name])
			else:
				log_line.emit("→ %d heiliger Schaden an %s." % [dealt, target.display_name])
			return dealt
		Enums.Element.DARK:
			var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.MAGICAL, [], pierce)
			log_line.emit("→ %d Dunkelschaden an %s." % [dealt, target.display_name])
			var healed := roundi(dealt * DARK_LIFESTEAL)
			if healed > 0:
				actor.heal(healed)
				log_line.emit("%s raubt %d HP." % [actor.display_name, healed])
			if target.is_alive():
				target.add_status(Enums.Status.CURSED, CURSE_TURNS, CURSE_POTENCY)
				log_line.emit("%s ist verflucht (+%d%% erlittener Schaden)."
					% [target.display_name, CURSE_POTENCY])
			return dealt
	# Unbekanntes Element: roher Magieschaden.
	return _deal_damage(actor, target, raw, Enums.DamageAxis.MAGICAL, [], pierce)


## Rechnet Rohschaden gegen Mitigation, Buffs/Debuffs und Krit, wendet ihn an.
## Physischer Schaden verteilt sich auf seine Schadensarten (Stich/Schnitt/
## Stumpf) und wird pro Anteil gegen die passende Rüstung gemindert.
## pierce (Durchdringung): ignoriert diesen Anteil der Rüstung/Resistenz.
func _deal_damage(attacker: Combatant, target: Combatant, raw: float,
		axis: Enums.DamageAxis,
		subtypes: Array[Enums.PhysicalSubtype] = [], pierce := 0.0) -> int:
	var weaken := attacker.get_status(Enums.Status.WEAKEN)
	if not weaken.is_empty():
		raw *= 1.0 - weaken["potency"] / 100.0
	var atk_up := attacker.get_status(Enums.Status.ATK_UP)
	if not atk_up.is_empty():
		raw *= 1.0 + atk_up["potency"] / 100.0
	# Eingefrorene Ziele zerschmettern bei physischen Treffern: Bonusschaden,
	# aber das Eis (und damit die Handlungsunfähigkeit) bricht sofort.
	if axis == Enums.DamageAxis.PHYSICAL and target.has_status(Enums.Status.FROZEN):
		raw *= ICE_SHATTER_BONUS
		target.statuses.erase(target.get_status(Enums.Status.FROZEN))
		log_line.emit("Das Eis um %s zerschmettert!" % target.display_name)
	var amount: int
	match axis:
		Enums.DamageAxis.PHYSICAL:
			var parts := subtypes
			if parts.is_empty():
				parts = [Enums.PhysicalSubtype.BLUNT]
			var per_part := raw / parts.size()
			var total := 0.0
			for subtype in parts:
				total += maxf(0.0, per_part - target.armor_against(subtype) * (1.0 - pierce))
			amount = roundi(total)
		Enums.DamageAxis.MAGICAL:
			amount = roundi(raw) - roundi(target.total_magic_resist() * (1.0 - pierce))
		_:
			amount = roundi(raw)
	# Fluch (Dunkel): das Ziel nimmt prozentual mehr Schaden.
	var curse := target.get_status(Enums.Status.CURSED)
	if not curse.is_empty():
		amount = roundi(amount * (1.0 + curse["potency"] / 100.0))
	var guard := target.get_status(Enums.Status.GUARD)
	if not guard.is_empty():
		amount = roundi(amount * (1.0 - guard["potency"] / 100.0))
	amount = maxi(1, amount)
	if crit_enabled and rng.randi_range(1, 100) <= CRIT_BASE_PERCENT + attacker.stat(&"luck"):
		amount = roundi(amount * CRIT_MULTIPLIER)
		log_line.emit("Kritischer Treffer!")
	return target.take_damage(amount)


func _check_battle_end() -> bool:
	if is_over:
		return true
	# Beschwörungen zählen nicht: der Kampf endet, wenn alle ECHTEN
	# Kämpfer einer Seite fallen (ein übriger Wolf rettet niemanden).
	if _living_real(enemies).is_empty():
		is_over = true
		log_line.emit("Sieg! Alle Gegner wurden besiegt.")
		battle_ended.emit(true)
	elif _living_real(players).is_empty():
		is_over = true
		log_line.emit("Niederlage … Die Party wurde besiegt.")
		battle_ended.emit(false)
	return is_over


## Lebende Kämpfer ohne Beschwörungen (für Sieg/Niederlage-Prüfung).
func _living_real(list: Array[Combatant]) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for combatant in list:
		if combatant.is_alive() and not combatant.is_summon:
			result.append(combatant)
	return result


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
		Enums.Status.GUARD: return "Verteidigt"
		Enums.Status.ATK_UP: return "Gestärkt"
		Enums.Status.DEF_UP: return "Gewappnet"
		Enums.Status.MANA_REGEN: return "Mana-Fluss"
		Enums.Status.PROTECT: return "Beschützer"
		Enums.Status.CLEANSE: return "Reinigung"
		Enums.Status.REVIVE: return "Wiederbelebung"
		Enums.Status.FROZEN: return "Eingefroren"
		Enums.Status.CURSED: return "Verflucht"
	return "?"
