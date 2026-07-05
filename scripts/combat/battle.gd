class_name Battle
extends RefCounted
## Rundenbasierte Kampflogik, komplett UI-frei (headless testbar).
## Die UI-Szene treibt den Kampf: next_turn() liefert den aktiven Kämpfer,
## bei Spielern wartet die UI auf Eingabe, bei Gegnern ruft sie ai_take_turn().

signal log_line(text: String)
signal battle_ended(victory: bool)
## Die Party ist erfolgreich geflohen (kein Sieg, keine Niederlage).
signal battle_fled
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
				_remove_summon(actor, Loc.pick("löst sich auf", "dissolves"))
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
	# Waffentechniken brauchen die passende geführte Waffe (DQ-Stil).
	if not skill.usable_with_weapon(actor):
		log_line.emit(Loc.pick("%s braucht dafür: %s!", "%s needs: %s for that!")
			% [skill.display_name,
			BlockLibrary.families_label(skill.required_weapon_families())])
		return false
	var cost := skill.get_mp_cost(actor)
	if actor.mp < cost:
		log_line.emit(Loc.pick("%s hat nicht genug MP für %s.", "%s does not have enough MP for %s.") % [actor.display_name, skill.display_name])
		return false
	actor.mp -= cost

	var form := skill.get_form()
	# Beschwörung: eigener Pfad — erschafft einen Verbündeten statt Ziele zu treffen.
	if form == Enums.SkillForm.SUMMON:
		log_line.emit(Loc.pick("%s setzt %s ein!", "%s uses %s!") % [actor.display_name, skill.display_name])
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
	log_line.emit(Loc.pick("%s setzt %s ein!", "%s uses %s!") % [actor.display_name, skill.display_name])

	# Wiederbelebungs-Effekte wirken auf Gefallene (die in keiner
	# normalen Zielliste auftauchen).
	for effect in skill.get_effect_blocks():
		if effect.status == Enums.Status.REVIVE \
				and rng.randi_range(1, 100) <= effect.chance_percent:
			for ally in allies_of(actor):
				if not ally.is_alive():
					ally.hp = maxi(1, roundi(ally.max_hp * effect.potency / 100.0))
					log_line.emit(Loc.pick("%s kehrt mit %d HP zurück!", "%s returns with %d HP!")
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
			log_line.emit(Loc.pick("Splitter treffen %s!", "Shrapnel hits %s!") % other.display_name)
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
			log_line.emit(Loc.pick("Die Kette springt auf %s über!", "The chain jumps to %s!") % next.display_name)
			_apply_skill_hit(actor, skill, next, power_mult)
			last_target = next
			jumps += 1

	if not _is_friendly_form(form):
		_consume_focus(actor)
	_check_battle_end()
	return true


func basic_attack(actor: Combatant, target: Combatant) -> void:
	if is_over:
		return
	target = _apply_protection(target)
	log_line.emit(Loc.pick("%s greift %s an.", "%s attacks %s.") % [actor.display_name, target.display_name])
	var raw := float(BASIC_ATTACK_BASE + actor.stat(&"strength") + actor.weapon_damage()) \
		* actor.training_weapon_mult()
	for hit in actor.weapon_hit_count():
		if not target.is_alive():
			break
		var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.PHYSICAL,
			actor.weapon_subtypes(), actor.weapon_armor_pierce())
		log_line.emit(Loc.pick("» %d Schaden an %s.", "» %d damage to %s.") % [dealt, target.display_name])
	if not target.is_alive():
		log_line.emit(Loc.pick("%s wurde besiegt!", "%s was defeated!") % target.display_name)
	_consume_focus(actor)
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
			log_line.emit(Loc.pick("%s setzt %s ein: %s heilt %d HP.", "%s uses %s: %s heals %d HP.")
				% [actor.display_name, item.display_name, target.display_name, heal])
		Enums.ConsumableEffect.RESTORE_MP:
			if not target.is_alive():
				return false
			var mana := item.mana_amount(target)
			target.mp = mini(target.max_mp, target.mp + mana)
			log_line.emit(Loc.pick("%s setzt %s ein: %s erhält %d MP.", "%s uses %s: %s gains %d MP.")
				% [actor.display_name, item.display_name, target.display_name, mana])
		Enums.ConsumableEffect.CURE_AILMENTS:
			if not target.is_alive():
				return false
			for entry in target.statuses.duplicate():
				if entry["status"] in item.cures:
					target.statuses.erase(entry)
			log_line.emit(Loc.pick("%s setzt %s ein: %s ist kuriert.", "%s uses %s: %s is cured.")
				% [actor.display_name, item.display_name, target.display_name])
		Enums.ConsumableEffect.REVIVE:
			if target.is_alive():
				return false
			target.hp = maxi(1, roundi(target.max_hp * item.potency / 100.0))
			log_line.emit(Loc.pick("%s setzt %s ein: %s kehrt mit %d HP zurück!", "%s uses %s: %s returns with %d HP!")
				% [actor.display_name, item.display_name, target.display_name, target.hp])
	return true


## Konzentrieren (DQ-Psyche-Up): opfert den Zug — der nächste Angriff macht
## +50% Schaden, stapelbar bis +200%. Wird beim nächsten offensiven Einsatz
## verbraucht.
const FOCUS_STEP := 50
const FOCUS_MAX := 200

func concentrate(actor: Combatant) -> void:
	if is_over:
		return
	var focus := actor.get_status(Enums.Status.FOCUS)
	var potency := FOCUS_STEP
	if not focus.is_empty():
		potency = mini(FOCUS_MAX, int(focus["potency"]) + FOCUS_STEP)
		actor.statuses.erase(focus)
	actor.add_status(Enums.Status.FOCUS, 99, potency)
	log_line.emit(Loc.pick("%s konzentriert sich — nächster Angriff +%d%%!",
		"%s focuses — next attack +%d%%!") % [actor.display_name, potency])


## Verbraucht die Konzentration nach einer offensiven Aktion.
func _consume_focus(actor: Combatant) -> void:
	var focus := actor.get_status(Enums.Status.FOCUS)
	if not focus.is_empty():
		actor.statuses.erase(focus)


## Verteidigungshaltung: halbiert erlittenen Schaden bis zum eigenen nächsten Zug.
func defend(actor: Combatant) -> void:
	if is_over:
		return
	actor.add_status(Enums.Status.GUARD, 1, 50)
	log_line.emit(Loc.pick("%s geht in Verteidigungshaltung.", "%s takes a defensive stance.") % actor.display_name)


## Kämpft hier ein Boss? (Vor Bossen gibt es kein Entkommen.)
func has_boss() -> bool:
	for foe in enemies:
		if foe.is_boss:
			return true
	return false


const FLEE_BASE_CHANCE := 0.5
const FLEE_AGI_FACTOR := 0.03  ## pro Punkt Ø-Geschick-Vorsprung


## Fluchtversuch der Party (DQ-Stil): Chance aus dem Geschick-Vergleich.
## Misslingt er, ist der Zug verbraucht. Vor Bossen unmöglich.
func attempt_flee(actor: Combatant) -> bool:
	if is_over:
		return false
	if has_boss():
		log_line.emit(Loc.pick("Vor einem Boss gibt es kein Entkommen!",
			"There is no escape from a boss!"))
		return false
	var chance := clampf(FLEE_BASE_CHANCE
		+ (_average_agility(players) - _average_agility(enemies)) * FLEE_AGI_FACTOR,
		0.25, 0.95)
	if rng.randf() < chance:
		log_line.emit(Loc.pick("%s gibt das Zeichen — die Party entkommt!",
			"%s gives the signal — the party escapes!") % actor.display_name)
		is_over = true
		battle_fled.emit()
		return true
	log_line.emit(Loc.pick("%s versucht zu fliehen — doch der Weg ist versperrt!",
		"%s tries to flee — but the path is blocked!") % actor.display_name)
	return false


func _average_agility(group: Array[Combatant]) -> float:
	var total := 0.0
	var count := 0
	for combatant in group:
		if combatant.is_alive() and not combatant.is_summon:
			total += combatant.stat(&"agility")
			count += 1
	return total / maxf(1.0, count)


## Die nächsten Kämpfer dieser Runde als Namen (Log/Kompaktanzeige);
## die Kampf-UI nutzt upcoming_turns() für die Sprite-Leiste.
func get_turn_preview(count := 5) -> Array[String]:
	var names: Array[String] = []
	for combatant in upcoming_turns(count):
		names.append(combatant.display_name)
	return names


## Simple Gegner-KI: bezahlbaren Skill oder Basisangriff auf zufälliges Ziel.
## Bosse haben eigene Mechaniken (Aufladung/Haltung/Wut), Schleime stapeln
## sich, Metallschleime flüchten, Rudeltiere rufen Verstärkung.
func ai_take_turn(actor: Combatant) -> void:
	if actor.is_boss and _boss_pre_turn(actor):
		return  # Aufladung/Entfesselung hat den Zug verbraucht
	if _try_flee(actor):
		return
	if _try_slime_merge(actor):
		return
	if _try_call_reinforcements(actor):
		return
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


# --- Boss-Mechaniken -----------------------------------------------------------

const BOSS_CHARGE_COOLDOWN := 4   ## eigene Züge zwischen zwei Aufladungen
const BOSS_CHARGE_MULT := 1.5     ## Wucht des entfesselten Flächenangriffs

## Boss-Zugbeginn: Entfesselung > neue Aufladung > Signature-Pflege.
## true = der Zug ist verbraucht.
func _boss_pre_turn(actor: Combatant) -> bool:
	if actor.charge_active:
		actor.charge_active = false
		_unleash_charge(actor)
		return true
	# Schleimgott: verschlingt einen lebenden Schleim — heilt sich um dessen
	# HP und wird dauerhaft stärker. Seine Phasen rufen Schleime nach …
	if actor.boss_signature == &"verschlingen":
		for ally in _living(allies_of(actor)):
			if ally != actor and not ally.is_boss and not ally.is_summon \
					and (ally.archetype_id == &"schleim" or SLIME_CHAIN.has(ally.archetype_id)):
				actor.heal(ally.hp)
				actor.add_status(Enums.Status.ATK_UP, 99, 10)
				allies_of(actor).erase(ally)
				_queue.erase(ally)
				combatant_removed.emit(ally)
				log_line.emit(Loc.pick("%s verschlingt %s und wächst!", "%s devours %s and grows!")
					% [actor.display_name, ally.display_name])
				return true
	# Haltungswechsel (Schattenbestie): pendelt alle 3 eigene Züge.
	if actor.boss_signature == &"haltung":
		actor.stance_counter += 1
		if actor.stance_counter % 3 == 0:
			_toggle_stance(actor)
	# Wut (Bär): je weniger HP, desto härter schlägt er zu.
	if actor.boss_signature == &"wut":
		var missing := 1.0 - float(actor.hp) / actor.max_hp
		var potency := roundi(missing * 50)
		if potency > 0:
			actor.add_status(Enums.Status.ATK_UP, 1, potency)
	actor.charge_cooldown -= 1
	if actor.charge_cooldown <= 0:
		actor.charge_cooldown = BOSS_CHARGE_COOLDOWN
		actor.charge_active = true
		log_line.emit(Loc.pick("⚡ %s holt zu einem verheerenden Angriff aus! (Betäuben bricht die Aufladung)", "⚡ %s charges a devastating attack! (Stun breaks the charge)")
			% actor.display_name)
		return true
	return false


## Der aufgeladene Flächenangriff: trifft die GANZE Party (Schutzwall fängt ab).
func _unleash_charge(actor: Combatant) -> void:
	log_line.emit(Loc.pick("💥 %s entfesselt den aufgeladenen Angriff!", "💥 %s unleashes the charged attack!") % actor.display_name)
	var physical := actor.innate_weapon_damage >= actor.innate_spell_damage
	for target in _living(opponents_of(actor)):
		var victim := _apply_protection(target)
		var dealt: int
		if physical:
			var raw := (actor.weapon_damage() + actor.stat(&"strength")) * BOSS_CHARGE_MULT
			dealt = _deal_damage(actor, victim, raw, Enums.DamageAxis.PHYSICAL,
				actor.weapon_subtypes())
		else:
			var raw := (actor.spell_damage() + actor.stat(&"intelligence")) * BOSS_CHARGE_MULT
			dealt = _deal_damage(actor, victim, raw, Enums.DamageAxis.MAGICAL)
		log_line.emit(Loc.pick("» %d Schaden an %s.", "» %d damage to %s.") % [dealt, victim.display_name])
		if not victim.is_alive():
			log_line.emit(Loc.pick("%s wurde besiegt!", "%s was defeated!") % victim.display_name)
	_check_battle_end()


## Schattenbestie: wechselt zwischen physischer und magischer Haltung —
## in der falschen Haltung ist sie verwundbar (Verteidigungs-Anzeige lesen!).
func _toggle_stance(actor: Combatant) -> void:
	if actor.stance_physical:
		actor.stance_physical = false
		actor.armor -= 11
		actor.magic_resist += 11
		log_line.emit(Loc.pick("%s wechselt in die MAGISCHE Haltung (physisch verwundbar)!", "%s shifts to the MAGICAL stance (physically vulnerable)!")
			% actor.display_name)
	else:
		actor.stance_physical = true
		actor.armor += 11
		actor.magic_resist -= 11
		log_line.emit(Loc.pick("%s wechselt in die PHYSISCHE Haltung (magisch verwundbar)!", "%s shifts to the PHYSICAL stance (magically vulnerable)!")
			% actor.display_name)


## Phasen bei 66%/33% HP: Verstärkung + Adds (Adds-Signature ruft doppelt).
func _update_boss_phases() -> void:
	for boss in enemies:
		if not boss.is_boss or not boss.is_alive():
			continue
		var ratio := float(boss.hp) / boss.max_hp
		if boss.boss_phase == 1 and ratio <= 0.66:
			_enter_boss_phase(boss, 2)
		if boss.boss_phase == 2 and ratio <= 0.33:
			_enter_boss_phase(boss, 3)


func _enter_boss_phase(boss: Combatant, phase: int) -> void:
	boss.boss_phase = phase
	log_line.emit(Loc.pick("— %s erreicht Phase %d! —", "— %s enters phase %d! —") % [boss.display_name, phase])
	boss.add_status(Enums.Status.ATK_UP, 99, 10 if phase == 2 else 20)
	var add_count := 2 if boss.boss_signature == &"adds" else 1
	for i in add_count:
		_spawn_boss_add(boss)


## Ruft einen Begleiter (echter Gegner: gibt XP und Beute — der Kampf wird
## härter, aber auch lohnender).
func _spawn_boss_add(boss: Combatant) -> void:
	var archetype := EnemyLibrary.get_archetype(boss.boss_add_id)
	if archetype == null:
		return
	var add := EnemyFactory.build(archetype, maxi(1, boss.level - 2), rng)
	enemies.append(add)
	_queue.append(add)
	combatant_added.emit(add)
	log_line.emit(Loc.pick("%s ruft %s herbei!", "%s summons %s!") % [boss.display_name, add.display_name])


## Schleim-Stapeln (DQ-Prinzip): Schleime opfern ihren Zug und türmen sich
## zur nächsten Evolutionsstufe — die Kette geht bis zum SCHLEIMGOTT.
## HP der Teile bleiben erhalten (gedeckelt), die Beute addiert sich.
const SLIME_MERGE_CHANCE := 0.35
const SLIME_CHAIN := {
	&"schleim": &"schleimstapel",
	&"schleimstapel": &"koenigschleim",
	&"koenigschleim": &"schleimgott",
}
## Wie viele Exemplare für die nächste Stufe zusammenkommen müssen.
const SLIME_MERGE_NEEDED := {
	&"schleim": 3,
	&"schleimstapel": 2,
	&"koenigschleim": 2,
}

func _try_slime_merge(actor: Combatant) -> bool:
	if actor.is_boss or actor.is_summon or not SLIME_CHAIN.has(actor.archetype_id):
		return false
	var needed: int = SLIME_MERGE_NEEDED[actor.archetype_id]
	var parts: Array[Combatant] = [actor]
	for ally in _living(allies_of(actor)):
		if parts.size() >= needed:
			break
		if ally != actor and ally.archetype_id == actor.archetype_id \
				and not ally.is_boss and not ally.is_summon:
			parts.append(ally)
	if parts.size() < needed or rng.randf() > SLIME_MERGE_CHANCE:
		return false
	var next_archetype := EnemyLibrary.get_archetype(SLIME_CHAIN[actor.archetype_id])
	if next_archetype == null:
		return false
	# Ohne Varianten-Roll: der Stapel ist immer die reine Form.
	var merged := EnemyFactory.build(next_archetype, actor.level, rng,
		[], -1, Enums.Element.NONE, false)
	var hp_sum := 0
	var loot_sum := 0.0
	var side := allies_of(actor)
	for part in parts:
		hp_sum += part.hp
		loot_sum += part.loot_mult
		side.erase(part)
		_queue.erase(part)
		combatant_removed.emit(part)
	merged.hp = mini(merged.max_hp, hp_sum)
	merged.loot_mult = loot_sum
	side.append(merged)
	combatant_added.emit(merged)
	log_line.emit(Loc.pick("👑 Die Schleime stapeln sich — %s entsteht!", "👑 The slimes stack up — %s emerges!") % merged.display_name)
	return true


## Metallschleim & Co.: entwischt gern — dann gibt es weder XP noch Beute.
func _try_flee(actor: Combatant) -> bool:
	if actor.flee_chance <= 0.0 or rng.randf() > actor.flee_chance:
		return false
	log_line.emit(Loc.pick("💨 %s entwischt!", "💨 %s escapes!") % actor.display_name)
	players.erase(actor)
	enemies.erase(actor)
	_queue.erase(actor)
	combatant_removed.emit(actor)
	_check_battle_end()
	return true


## Rudeltiere (Wolf, Kultist): rufen einmalig ein weiteres Exemplar der
## eigenen Art — wer trödelt, kämpft plötzlich gegen mehr.
const REINFORCEMENT_CHANCE := 0.25
const MAX_GROUP_SIZE := 5

func _try_call_reinforcements(actor: Combatant) -> bool:
	if not actor.can_call_reinforcements or actor.reinforcement_called \
			or actor.is_summon or actor.archetype_id == &"":
		return false
	# Sanfter Einstieg: auf den ersten Stufen bleibt das Rudel klein.
	if actor.level < 3:
		return false
	if _living(allies_of(actor)).size() >= MAX_GROUP_SIZE:
		return false
	# EIN Wurf pro Gegner-Leben — sonst ruft am Ende doch jeder.
	actor.reinforcement_called = true
	if rng.randf() > REINFORCEMENT_CHANCE:
		return false
	var archetype := EnemyLibrary.get_archetype(actor.archetype_id)
	if archetype == null:
		return false
	var mate := EnemyFactory.build(archetype, actor.level, rng)
	mate.reinforcement_called = true  # Gerufene rufen nicht weiter (Kettenschutz)
	allies_of(actor).append(mate)
	_queue.append(mate)
	combatant_added.emit(mate)
	log_line.emit(Loc.pick("%s ruft Verstärkung — %s erscheint!", "%s calls for reinforcements — %s appears!")
		% [actor.display_name, mate.display_name])
	return true


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
	log_line.emit(Loc.pick("— Runde %d —", "— Round %d —") % round_number)


## Die nächsten Kämpfer in Zugreihenfolge (für die Zugleisten-UI):
## Rest der aktuellen Runde, dann Vorschau auf die nächste (nach Tempo).
func upcoming_turns(count := 8) -> Array[Combatant]:
	var result: Array[Combatant] = []
	for actor in _queue:
		if actor.is_alive() and result.size() < count:
			result.append(actor)
	if result.size() < count:
		var next_round := _living(players)
		next_round.append_array(_living(enemies))
		next_round.sort_custom(func(a: Combatant, b: Combatant) -> bool:
			return a.effective_speed() > b.effective_speed())
		for actor in next_round:
			if result.size() >= count:
				break
			result.append(actor)
	return result


## Erwarteter Schaden OHNE Anwendung (Vorschau bei der Zielwahl): dieselbe
## Mitigation wie _deal_damage, aber ohne Krit, ohne Nebenwirkungen und
## ohne das Eis zu brechen.
func preview_mitigated(attacker: Combatant, target: Combatant, raw: float,
		axis: Enums.DamageAxis,
		subtypes: Array[Enums.PhysicalSubtype] = [], pierce := 0.0) -> int:
	var weaken := attacker.get_status(Enums.Status.WEAKEN)
	if not weaken.is_empty():
		raw *= 1.0 - weaken["potency"] / 100.0
	var atk_up := attacker.get_status(Enums.Status.ATK_UP)
	if not atk_up.is_empty():
		raw *= 1.0 + atk_up["potency"] / 100.0
	var focus := attacker.get_status(Enums.Status.FOCUS)
	if not focus.is_empty():
		raw *= 1.0 + focus["potency"] / 100.0
	if axis == Enums.DamageAxis.PHYSICAL and target.has_status(Enums.Status.FROZEN):
		raw *= ICE_SHATTER_BONUS
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
	var curse := target.get_status(Enums.Status.CURSED)
	if not curse.is_empty():
		amount = roundi(amount * (1.0 + curse["potency"] / 100.0))
	var guard := target.get_status(Enums.Status.GUARD)
	if not guard.is_empty():
		amount = roundi(amount * (1.0 - guard["potency"] / 100.0))
	return maxi(1, amount)


## DoT-Ticks, Regeneration und Betäubung am Zugbeginn.
## Stack-Statuseffekte (Brand/Gift): Schaden = aktuelle Stacks.
##   Brand halbiert seine Stacks nach jedem Tick (hoher Burst, kurz),
##   Gift behält seine Stacks für immer (bis kuriert).
## Gibt true zurück, wenn der Zug ausgesetzt wird.
func _process_turn_start(actor: Combatant) -> bool:
	var stunned := false
	# VOR der Verarbeitung erfassen: ein Brand, der diesen Tick erlischt,
	# blockiert die Troll-Regeneration trotzdem noch.
	var had_dot := actor.has_status(Enums.Status.BURN) \
		or actor.has_status(Enums.Status.POISON_DOT)
	for entry in actor.statuses.duplicate():
		match entry["status"]:
			Enums.Status.BURN:
				var burn_dmg: int = entry["potency"]
				actor.take_damage(burn_dmg)
				log_line.emit(Loc.pick("%s erleidet %d Brand-Schaden.", "%s takes %d burn damage.") % [actor.display_name, burn_dmg])
				entry["potency"] = int(entry["potency"] / 2.0)  # Stacks halbieren
				if entry["potency"] < 1:
					actor.statuses.erase(entry)
				continue
			Enums.Status.POISON_DOT:
				var poison_dmg: int = entry["potency"]
				actor.take_damage(poison_dmg)
				log_line.emit(Loc.pick("%s erleidet %d Gift-Schaden.", "%s takes %d poison damage.") % [actor.display_name, poison_dmg])
				continue  # Gift läuft nie von selbst ab
			Enums.Status.REGEN:
				actor.heal(entry["potency"])
				log_line.emit(Loc.pick("%s regeneriert %d HP.", "%s regenerates %d HP.") % [actor.display_name, entry["potency"]])
			Enums.Status.MANA_REGEN:
				actor.mp = mini(actor.max_mp, actor.mp + entry["potency"])
				log_line.emit(Loc.pick("%s regeneriert %d MP.", "%s regenerates %d MP.") % [actor.display_name, entry["potency"]])
			Enums.Status.STUN:
				stunned = true
				log_line.emit(Loc.pick("%s ist betäubt und setzt aus!", "%s is stunned and skips the turn!") % actor.display_name)
			Enums.Status.FROZEN:
				stunned = true
				log_line.emit(Loc.pick("%s ist eingefroren und setzt aus!", "%s is frozen and skips the turn!") % actor.display_name)
		entry["turns"] -= 1
	for entry in actor.statuses.duplicate():
		if entry["turns"] <= 0 and entry["status"] not in Combatant.STACKING_STATUSES:
			actor.statuses.erase(entry)
	# Betäubung/Einfrieren BRICHT die Boss-Aufladung — das Gegenspiel.
	if stunned and actor.charge_active:
		actor.charge_active = false
		log_line.emit(Loc.pick("Die Aufladung von %s wird unterbrochen!", "%s's charge-up is interrupted!") % actor.display_name)
	# Troll-Signature: regeneriert jede Runde — außer Brand oder Gift nagen.
	if actor.is_boss and actor.boss_signature == &"regeneration" and actor.is_alive():
		if had_dot:
			log_line.emit(Loc.pick("%s kann nicht regenerieren (Brand/Gift)!", "%s cannot regenerate (burn/poison)!") % actor.display_name)
		else:
			var regen := maxi(1, roundi(actor.max_hp * 0.08))
			actor.heal(regen)
			log_line.emit(Loc.pick("%s regeneriert %d HP — Brand oder Gift würden das stoppen.", "%s regenerates %d HP — burn or poison would stop it.")
				% [actor.display_name, regen])
	if not actor.is_alive():
		log_line.emit(Loc.pick("%s geht zu Boden!", "%s goes down!") % actor.display_name)
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
## des Skills wirken auf die Beschwörung (z.B. Schutzwall » Wächter-Tank).
func _summon(actor: Combatant, skill: Skill) -> void:
	# Pro Beschwörer nur eine Beschwörung: die alte weicht der neuen.
	for ally in allies_of(actor).duplicate():
		if ally.is_summon and ally.summoner == actor:
			_remove_summon(ally, Loc.pick("weicht einer neuen Beschwörung", "makes way for a new summon"))

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
	log_line.emit(Loc.pick("%s erscheint (%d HP, %d Züge)!", "%s appears (%d HP, %d turns)!")
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
			log_line.emit(Loc.pick("%s wirft sich schützend vor %s!", "%s leaps in front of %s!")
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
			Enums.SkillModifier.VS_UNDEAD:
				if target.is_undead:
					execute_bonus *= 1.0 + mod.magnitude / 100.0

	for source in skill.get_sources():
		if source.source == Enums.SkillSource.WEAPON:
			# Waffennutzung: physisch, nur gegen Gegner (hat nie eine Form).
			if friendly:
				continue
			var raw := (actor.weapon_damage() + actor.stat(&"strength") * source.scaling_per_point) \
				* power_mult * source.power_multiplier * execute_bonus \
				* actor.training_weapon_mult()
			# Waffen-Durchdringung (Armbrust) stapelt mit Skill-Modifikatoren.
			var weapon_pierce := clampf(pierce + actor.weapon_armor_pierce(), 0.0, 0.9)
			# Mehrfach-Treffer (Bogen: 2 Pfeile) — Mitigation greift pro Pfeil.
			for hit in actor.weapon_hit_count():
				if not target.is_alive():
					break
				var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.PHYSICAL,
					actor.weapon_subtypes(), weapon_pierce)
				total_dealt += dealt
				log_line.emit(Loc.pick("» %d Schaden an %s.", "» %d damage to %s.") % [dealt, target.display_name])
			# Element-Rider (Loot-Affixe): die Waffe trägt Zusatz-Elementschaden,
			# der mit voller Signatur einschlägt (Brand-Stacks, Fluch, …).
			var riders := actor.element_riders()
			for rider_element in riders:
				if not target.is_alive():
					break
				var rider_block := BlockLibrary.element_block(rider_element)
				if rider_block == null:
					continue
				total_dealt += _apply_elemental_hit(actor, target,
					riders[rider_element] * power_mult, rider_block, pierce)
			# Element-BAUSTEIN auf Waffennutzung ("Flammenklinge"): die Hälfte
			# des Waffen-Rohschadens schlägt zusätzlich mit voller Element-
			# Signatur ein (Brand-Stacks, Einfrieren, Fluch, …).
			if element_block != null and target.is_alive():
				total_dealt += _apply_elemental_hit(actor, target,
					raw * 0.5, element_block, pierce)
		else:
			# Zauber: Schaden aus Zauberschaden der Waffe + INT.
			var raw := (actor.spell_damage() + actor.stat(&"intelligence") * source.scaling_per_point) \
				* power_mult * source.power_multiplier * execute_bonus \
				* actor.training_spell_mult()
			if friendly:
				# Heilig-Zauber auf Verbündete » Heilung (heiliger Schaden wird umgewandelt).
				if element_block != null and element_block.element == Enums.Element.HOLY:
					var heal := roundi(raw)
					target.heal(heal)
					log_line.emit(Loc.pick("%s heilt %d HP.", "%s heals %d HP.") % [target.display_name, heal])
				# Ohne Heilig: reiner Support-Zauber, kein Schaden an Verbündeten.
			elif element_block != null:
				total_dealt += _apply_elemental_hit(actor, target, raw, element_block, pierce)
			else:
				var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.MAGICAL, [], pierce)
				total_dealt += dealt
				log_line.emit(Loc.pick("» %d Schaden an %s.", "» %d damage to %s.") % [dealt, target.display_name])

	for effect in skill.get_effect_blocks():
		if rng.randi_range(1, 100) > effect.chance_percent:
			continue
		if effect.status == Enums.Status.LIFESTEAL:
			var healed := roundi(total_dealt * effect.potency / 100.0)
			if healed > 0:
				actor.heal(healed)
				log_line.emit(Loc.pick("%s raubt %d HP.", "%s drains %d HP.") % [actor.display_name, healed])
		elif effect.status == Enums.Status.REVIVE:
			pass  # Wird in use_skill auf Gefallene angewendet, nicht auf Zielliste.
		elif effect.status == Enums.Status.CLEANSE:
			# Kein Status: entfernt sofort alle Leiden vom Ziel.
			for entry in target.statuses.duplicate():
				if entry["status"] in CURABLE_STATUSES:
					target.statuses.erase(entry)
			log_line.emit(Loc.pick("%s wird von allen Leiden gereinigt.", "%s is cleansed of all ailments.") % target.display_name)
		else:
			target.add_status(effect.status, effect.duration_turns, effect.potency)
			log_line.emit(Loc.pick("%s: %s (%d Runden).", "%s: %s (%d rounds).")
				% [target.display_name, status_display_name(effect.status), effect.duration_turns])

	if not target.is_alive():
		log_line.emit(Loc.pick("%s wurde besiegt!", "%s was defeated!") % target.display_name)


## Element-Signaturen (Phase 3): Jedes Element spielt sich eigen.
##   Feuer » Brand-Stacks (Burst, halbiert sich) · Gift » permanente Stacks
##   Eis » Einfrieren/Verlangsamen · Blitz » Kette + Betäubungs-Chance
##   Heilig » Bonus vs. Untote · Dunkel » Lebensraub + Fluch
## Gibt den direkt verursachten Schaden zurück (für Lebensraub-Effekte).
func _apply_elemental_hit(actor: Combatant, target: Combatant, raw: float,
		element_block: ElementBlock, pierce := 0.0) -> int:
	# Element-Resistenz (Loot-Affixe): flache Minderung VOR der Signatur —
	# senkt bei Brand/Gift auch die aufgebauten Stacks.
	var resist := target.element_resist(element_block.element)
	if resist > 0:
		raw = maxf(1.0, raw - resist * (1.0 - pierce))
	match element_block.element:
		Enums.Element.FIRE, Enums.Element.POISON:
			# DoT-Elemente: Stacks basierend auf dem Schaden, addieren sich.
			var stacks := maxi(1, roundi(raw * element_block.status_scale))
			var status := Enums.Status.BURN if element_block.element == Enums.Element.FIRE \
				else Enums.Status.POISON_DOT
			target.add_status(status, -1, stacks)
			var kind: String = "Brand" if status == Enums.Status.BURN else "Gift"
			var total: int = target.get_status(status)["potency"]
			log_line.emit(Loc.pick("%s: +%d %s-Stacks (jetzt %d).", "%s: +%d %s stacks (now %d).")
				% [target.display_name, stacks, kind, total])
			return 0
		Enums.Element.ICE:
			var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.MAGICAL, [], pierce)
			log_line.emit(Loc.pick("» %d Eisschaden an %s.", "» %d ice damage to %s.") % [dealt, target.display_name])
			if target.is_alive():
				if rng.randi_range(1, 100) <= ICE_FREEZE_CHANCE:
					target.add_status(Enums.Status.FROZEN, 1, 0)
					log_line.emit(Loc.pick("%s friert ein!", "%s freezes solid!") % target.display_name)
				else:
					target.add_status(Enums.Status.SLOW, 2, 30)
					log_line.emit(Loc.pick("%s ist unterkühlt (verlangsamt).", "%s is chilled (slowed).") % target.display_name)
			return dealt
		Enums.Element.LIGHTNING:
			var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.MAGICAL, [], pierce)
			log_line.emit(Loc.pick("» %d Blitzschaden an %s.", "» %d lightning damage to %s.") % [dealt, target.display_name])
			if target.is_alive() and rng.randi_range(1, 100) <= LIGHTNING_STUN_CHANCE:
				target.add_status(Enums.Status.STUN, 1, 0)
				log_line.emit(Loc.pick("%s ist vom Blitz betäubt!", "%s is stunned by the lightning!") % target.display_name)
			# Kette: springt auf ein weiteres lebendes Ziel über.
			var others: Array[Combatant] = []
			for foe in _living(opponents_of(actor)):
				if foe != target:
					others.append(foe)
			if not others.is_empty():
				var jump_target: Combatant = others[rng.randi_range(0, others.size() - 1)]
				var jump_dealt := _deal_damage(actor, jump_target,
					raw * LIGHTNING_CHAIN_FACTOR, Enums.DamageAxis.MAGICAL, [], pierce)
				log_line.emit(Loc.pick("Der Blitz springt über: %d Schaden an %s.", "The lightning chains: %d damage to %s.")
					% [jump_dealt, jump_target.display_name])
				if not jump_target.is_alive():
					log_line.emit(Loc.pick("%s wurde besiegt!", "%s was defeated!") % jump_target.display_name)
			return dealt
		Enums.Element.HOLY:
			var holy_raw := raw
			if target.is_undead:
				holy_raw *= HOLY_UNDEAD_BONUS
			var dealt := _deal_damage(actor, target, holy_raw, Enums.DamageAxis.MAGICAL, [], pierce)
			if target.is_undead:
				log_line.emit(Loc.pick("» %d heiliger Schaden an %s (sehr effektiv gegen Untote!).", "» %d holy damage to %s (super effective vs undead!).")
					% [dealt, target.display_name])
			else:
				log_line.emit(Loc.pick("» %d heiliger Schaden an %s.", "» %d holy damage to %s.") % [dealt, target.display_name])
			return dealt
		Enums.Element.DARK:
			var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.MAGICAL, [], pierce)
			log_line.emit(Loc.pick("» %d Dunkelschaden an %s.", "» %d dark damage to %s.") % [dealt, target.display_name])
			var healed := roundi(dealt * DARK_LIFESTEAL)
			if healed > 0:
				actor.heal(healed)
				log_line.emit(Loc.pick("%s raubt %d HP.", "%s drains %d HP.") % [actor.display_name, healed])
			if target.is_alive():
				target.add_status(Enums.Status.CURSED, CURSE_TURNS, CURSE_POTENCY)
				log_line.emit(Loc.pick("%s ist verflucht (+%d%% erlittener Schaden).", "%s is cursed (+%d%% damage taken).")
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
	var focus := attacker.get_status(Enums.Status.FOCUS)
	if not focus.is_empty():
		raw *= 1.0 + focus["potency"] / 100.0
	# Eingefrorene Ziele zerschmettern bei physischen Treffern: Bonusschaden,
	# aber das Eis (und damit die Handlungsunfähigkeit) bricht sofort.
	if axis == Enums.DamageAxis.PHYSICAL and target.has_status(Enums.Status.FROZEN):
		raw *= ICE_SHATTER_BONUS
		target.statuses.erase(target.get_status(Enums.Status.FROZEN))
		log_line.emit(Loc.pick("Das Eis um %s zerschmettert!", "The ice around %s shatters!") % target.display_name)
	var amount: int
	match axis:
		Enums.DamageAxis.PHYSICAL:
			var parts := subtypes
			if parts.is_empty():
				parts = [Enums.PhysicalSubtype.BLUNT]
			# Golem-Steinpanzer: der erste STUMPFE Treffer sprengt die Panzerung.
			if target.is_boss and target.boss_signature == &"steinpanzer" \
					and target.signature_active and Enums.PhysicalSubtype.BLUNT in parts:
				target.signature_active = false
				target.armor = maxi(0, target.armor - EnemyFactory.STONE_ARMOR_BONUS)
				log_line.emit(Loc.pick("Der Steinpanzer von %s zerbirst unter dem stumpfen Schlag!", "%s's stone armor shatters under the blunt blow!")
					% target.display_name)
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
	if crit_enabled and rng.randi_range(1, 100) <= CRIT_BASE_PERCENT \
			+ attacker.stat(&"luck") + attacker.training_crit_bonus():
		amount = roundi(amount * CRIT_MULTIPLIER)
		log_line.emit(Loc.pick("Kritischer Treffer!", "Critical hit!"))
	return target.take_damage(amount)


func _check_battle_end() -> bool:
	if is_over:
		return true
	_update_boss_phases()
	# Beschwörungen zählen nicht: der Kampf endet, wenn alle ECHTEN
	# Kämpfer einer Seite fallen (ein übriger Wolf rettet niemanden).
	if _living_real(enemies).is_empty():
		is_over = true
		log_line.emit(Loc.pick("Sieg! Alle Gegner wurden besiegt.", "Victory! All enemies defeated."))
		battle_ended.emit(true)
	elif _living_real(players).is_empty():
		is_over = true
		log_line.emit(Loc.pick("Niederlage … Die Party wurde besiegt.", "Defeat … the party has fallen."))
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
		Enums.Status.STUN: return Loc.pick("Betäubt", "Stunned")
		Enums.Status.BURN: return Loc.pick("Brand", "Burn")
		Enums.Status.POISON_DOT: return Loc.pick("Gift", "Poison")
		Enums.Status.SLOW: return Loc.pick("Verlangsamt", "Slowed")
		Enums.Status.WEAKEN: return Loc.pick("Geschwächt", "Weakened")
		Enums.Status.LIFESTEAL: return Loc.pick("Lebensraub", "Lifesteal")
		Enums.Status.SHIELD: return Loc.pick("Schild", "Shield")
		Enums.Status.REGEN: return Loc.pick("Regeneration", "Regeneration")
		Enums.Status.GUARD: return Loc.pick("Verteidigt", "Guarding")
		Enums.Status.ATK_UP: return Loc.pick("Gestärkt", "Strengthened")
		Enums.Status.DEF_UP: return Loc.pick("Gewappnet", "Braced")
		Enums.Status.MANA_REGEN: return Loc.pick("Mana-Fluss", "Mana flow")
		Enums.Status.PROTECT: return Loc.pick("Beschützer", "Protector")
		Enums.Status.CLEANSE: return Loc.pick("Reinigung", "Cleanse")
		Enums.Status.REVIVE: return Loc.pick("Wiederbelebung", "Revive")
		Enums.Status.FROZEN: return Loc.pick("Eingefroren", "Frozen")
		Enums.Status.CURSED: return Loc.pick("Verflucht", "Cursed")
		Enums.Status.FOCUS: return Loc.pick("Konzentriert", "Focused")
	return "?"
