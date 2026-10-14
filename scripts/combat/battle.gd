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
## Ein Element traf eine Schwäche/Resistenz — die UI merkt sich das Wissen.
signal element_reaktion(target: Combatant, element: Enums.Element, faktor: float)
## Darstellbares Ereignis für die Kampf-Effekte: {"art", "von", "an", …}
## art: element/waffe/magie/heilung/status/dot/krit/block (siehe KampfEffekte).
signal effekt(daten: Dictionary)

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

# Geist (SPI) ist der Support-Wert: Prozent-Effekte (Schild, Regeneration,
# Mana-Fluss, Wappnen) und Heilung wachsen mit ihm — aus dem UNskalierten
# Geist, abnehmender Ertrag, höchstens ×2 (siehe geist_prozent_faktor).
const GEIST_SKALIERT: Array[Enums.Status] = [Enums.Status.SHIELD, Enums.Status.REGEN,
	Enums.Status.MANA_REGEN, Enums.Status.DEF_UP]
const GEIST_PROZENT_HALB := 60.0     ## +50 % bei 60 rohem Geist, höchstens ×2

# Kontroll-Effekte gegen Bosse: halbe Chance, und jeder Erfolg macht den Boss
# widerstandsfähiger (kein Dauer-Lähmen).
const KONTROLL_STATUS: Array[Enums.Status] = [Enums.Status.STUN, Enums.Status.FROZEN]
const BOSS_KONTROLL_FAKTOR := 0.5
const BOSS_KONTROLL_ZUWACHS := 0.5   ## +50 % Resistenz je gelungener Kontrolle

## Überraschung zu Kampfbeginn (vom Dungeon gesetzt, vor der ersten Runde).
const KEINE_UEBERRASCHUNG := 0
const ERSTSCHLAG := 1     ## Party erwischt die Gegner von hinten: nur sie handelt in Runde 1
const HINTERHALT := -1    ## Gegner erwischen die Party von hinten: nur sie handeln in Runde 1

var rng := RandomNumberGenerator.new()
var crit_enabled := true  ## Tests schalten Krits für Determinismus ab
var ueberraschung := KEINE_UEBERRASCHUNG

# --- Skillbau 3.0 ----------------------------------------------------------------
## Gegner-KI: unter diesem HP-Anteil eines Verbündeten wird geheilt.
const KI_HEILEN_UNTER := 0.5
## Vollheilung: geplante Heilmenge je Ziel (wird beim Wirken verbraucht).
var _vollheil_plan: Dictionary = {}
const BLUTPREIS_FAKTOR := 1.5   ## Blutpreis: HP-Kosten = MP-Kosten × 1,5
const VOLLTREFFER := 4.0        ## Krit + Schwachstelle zugleich
const SCHWACHSTELLE_MULT := 2.0
## Vorrang aus geplanten Skills für die nächste Runde (+1 Flinkheit, −1 Wucht);
## die UI setzt ihn aus den Befehlen, der Rundenstart verbraucht ihn.
var vorrang: Dictionary = {}
## Aufgeladene Skills: Kämpfer » {"skill", "ziel"} (Eigenschaft Aufladen).
var _aufladungen: Dictionary = {}
## Wen hat diese Runde wer getroffen (Nachsetzen): Ziel » Array[Angreifer].
var _getroffen: Dictionary = {}
## Axt-Wucht: wer nach dieser Aktion erschöpft ist.
var _erschoepfen: Dictionary = {}
## Trefferkontext eines Skills für _deal_damage (Krit/Schwachstelle/Alles oder nichts).
var _kontext: Dictionary = {}
## Schaden über die Rest-HP hinaus beim letzten Treffer (Überschlag).
var _ueberschuss := 0

var players: Array[Combatant] = []
var enemies: Array[Combatant] = []
var round_number := 0
var is_over := false

var _queue: Array[Combatant] = []

## Echo-Zutat: geplante Zauber-Wiederholungen ({actor, skill, target, power}).
var _pending_echoes: Array[Dictionary] = []
## Verhindert Konter-auf-Konter-Kaskaden.
var _retaliating := false


func start(p_players: Array[Combatant], p_enemies: Array[Combatant]) -> void:
	# Kopien: Beschwörungen werden während des Kampfs hinzugefügt/entfernt —
	# das darf nie die geteilten GameState-Arrays (Party!) mutieren.
	players = p_players.duplicate()
	enemies = p_enemies.duplicate()
	round_number = 0
	is_over = false
	_queue.clear()
	_initiative_wurf.clear()
	_aufladungen.clear()
	_getroffen.clear()
	_erschoepfen.clear()
	vorrang.clear()
	_pending_echoes.clear()


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
	if is_over:
		return false
	var grund := skill.fehler(actor)
	if not grund.is_empty():
		if actor.is_player:
			log_line.emit("%s: %s" % [skill.display_name, grund])
		return false
	# Waffentechniken brauchen die passende geführte Waffe (DQ-Stil).
	if not skill.usable_with_weapon(actor):
		log_line.emit(Loc.pick("%s braucht dafür: %s!", "%s needs: %s for that!")
			% [skill.display_name,
			BlockLibrary.families_label(skill.required_weapon_families())])
		return false
	var cost := skill.get_mp_cost(actor)
	if skill.hat(Enums.SkillModifier.VOLLHEILUNG):
		cost = _vollheilung_planen(actor, skill, primary_target)
		if cost <= 0:
			return false
	if skill.hat(Enums.SkillModifier.BLUTPREIS):
		# Blutpreis: kostet Leben statt Mana — tötet aber nie selbst.
		var hp_kosten := maxi(1, roundi(cost * BLUTPREIS_FAKTOR))
		if actor.hp <= hp_kosten:
			log_line.emit(Loc.pick("%s hat nicht genug Leben für %s.", "%s does not have enough HP for %s.")
				% [actor.display_name, skill.display_name])
			return false
		actor.hp -= hp_kosten
		log_line.emit(Loc.pick("%s zahlt %d HP.", "%s pays %d HP.") % [actor.display_name, hp_kosten])
	else:
		if actor.mp < cost:
			log_line.emit(Loc.pick("%s hat nicht genug MP für %s.", "%s does not have enough MP for %s.") % [actor.display_name, skill.display_name])
			return false
		actor.mp -= cost
	# Aufladen: jetzt bezahlen, im nächsten eigenen Zug entfesseln.
	if skill.hat(Enums.SkillModifier.AUFLADEN):
		_aufladungen[actor] = {"skill": skill, "ziel": primary_target}
		log_line.emit(Loc.pick("%s sammelt Kraft für %s …", "%s gathers power for %s …")
			% [actor.display_name, skill.display_name])
		_fx(&"status", actor, actor, {"status": Enums.Status.FOCUS})
		return true
	_skill_wirken(actor, skill, primary_target)
	return true


## Vollheilung: wie viel heilt EIN normaler Wurf dieses Skills auf ein Ziel —
## mit allen Heil-Boni (Form, Eigenschaften, Training, Geist, Heiligstab).
func normale_heilung(actor: Combatant, skill: Skill) -> float:
	var form_block := skill.get_form_block()
	var power_mult := (form_block.power_multiplier if form_block != null else 1.0) * skill.schaden_faktor()
	for mod in skill.get_modifier_blocks():
		if mod.modifier == Enums.SkillModifier.OVERLOAD:
			power_mult *= 1.0 + mod.magnitude / 100.0
	var heal := 0.0
	for source in skill.get_sources():
		if source.source != Enums.SkillSource.SPELL:
			continue
		heal += (actor.spell_damage() + actor.stat(&"intelligence") * source.scaling_per_point) \
			* power_mult * source.power_multiplier * actor.training_spell_mult()
	heal *= geist_prozent_faktor(actor)
	if actor.weapon_family() == &"heiligstab":
		heal *= Combatant.HEILIGSTAB_HEILUNG
	return heal


## Vollheilung planen: Heilung je MP ergibt sich aus normaler Heilung ÷
## normalen Kosten. Reicht das Mana, heilt der Skill alle Ziele voll und
## kostet nur, was nötig ist; sonst kostet er ALLE MP und heilt anteilig so
## viel, wie sie hergeben. Gibt die MP-Kosten zurück (0 = nichts zu heilen).
func _vollheilung_planen(actor: Combatant, skill: Skill, primary_target: Combatant) -> int:
	_vollheil_plan.clear()
	var ziele := _resolve_targets(actor, skill.get_form(), primary_target)
	var fehlend := {}
	var summe := 0
	for ziel in ziele:
		if ziel.is_alive() and ziel.hp < ziel.max_hp:
			fehlend[ziel] = ziel.max_hp - ziel.hp
			summe += ziel.max_hp - ziel.hp
	if summe <= 0:
		log_line.emit(Loc.pick("%s: niemand ist verwundet.", "%s: nobody is wounded.") % skill.display_name)
		return 0
	var pro_wurf := normale_heilung(actor, skill) * maxi(1, ziele.size())
	var heil_pro_mp := pro_wurf / maxf(1.0, skill.get_mp_cost(actor))
	var noetig := maxi(1, ceili(summe / maxf(0.001, heil_pro_mp)))
	var zahlen := mini(noetig, actor.mp)
	if zahlen <= 0:
		log_line.emit(Loc.pick("%s hat keine MP mehr.", "%s has no MP left.") % actor.display_name)
		return 0
	var anteil := minf(1.0, float(zahlen) / noetig)
	for ziel in fehlend:
		_vollheil_plan[ziel] = maxi(1, roundi(fehlend[ziel] * anteil))
	if anteil < 1.0:
		log_line.emit(Loc.pick("%s setzt alle %d MP ein — es reicht für %d %% der Wunden.",
			"%s pours in all %d MP — enough for %d%% of the wounds.") % [actor.display_name, zahlen, roundi(anteil * 100)])
	return zahlen


## Hat der Kämpfer einen aufgeladenen Skill, der diesen Zug losbricht?
func hat_aufladung(actor: Combatant) -> bool:
	return _aufladungen.has(actor)


## Den aufgeladenen Skill entfesseln (verbraucht den Zug, keine Kosten mehr).
func aufladung_ausloesen(actor: Combatant) -> void:
	var aufladung: Dictionary = _aufladungen[actor]
	_aufladungen.erase(actor)
	var skill: Skill = aufladung["skill"]
	log_line.emit(Loc.pick("%s entfesselt %s!", "%s unleashes %s!") % [actor.display_name, skill.display_name])
	_skill_wirken(actor, skill, aufladung["ziel"], true)


## Der eigentliche Skill: Ziele, Treffer, Effekte. `entfesselt` = aus einer
## Aufladung (die Ansage kam schon).
func _skill_wirken(actor: Combatant, skill: Skill, primary_target: Combatant, entfesselt := false) -> void:
	var form := skill.get_form()
	if not entfesselt:
		log_line.emit(Loc.pick("%s setzt %s ein!", "%s uses %s!") % [actor.display_name, skill.display_name])
	# Beschwörung: eigener Pfad — erschafft einen Verbündeten statt Ziele zu treffen.
	if form == Enums.SkillForm.SUMMON:
		_summon(actor, skill)
		_gezielte_effekte(actor, skill, true)  # Anwender/Party-Effekte trägt die Beschwörung
		_check_battle_end()
		return

	# Wiederbelebungs-Effekte wirken auf Gefallene (die in keiner
	# normalen Zielliste auftauchen).
	for effect in skill.get_effect_blocks():
		if effect.status == Enums.Status.REVIVE \
				and rng.randi_range(1, 100) <= effect.chance_percent:
			for ally in allies_of(actor):
				if not ally.is_alive():
					ally.hp = maxi(1, roundi(ally.max_hp * effect.potency / 100.0))
					_fx(&"heilung", actor, ally)
					log_line.emit(Loc.pick("%s kehrt mit %d HP zurück!", "%s returns with %d HP!")
						% [ally.display_name, ally.hp])

	var form_block := skill.get_form_block()
	var power_mult := (form_block.power_multiplier if form_block != null else 1.0) * skill.schaden_faktor()
	# Überladung: mehr Schaden (die Mehrkosten trägt der Kostenfaktor).
	# Streuung, Kette & Co. gibt es nicht als Klotz — die baut man aus
	# Zusatztreffern und Zielwahl (_offensiv_treffer).
	for mod in skill.get_modifier_blocks():
		if mod.modifier == Enums.SkillModifier.OVERLOAD:
			power_mult *= 1.0 + mod.magnitude / 100.0

	var last_target: Combatant = null
	if _is_friendly_form(form):
		for target in _resolve_targets(actor, form, primary_target):
			_apply_skill_hit(actor, skill, target, power_mult)
			last_target = target
	else:
		last_target = _offensiv_treffer(actor, skill, primary_target, power_mult)

	_gezielte_effekte(actor, skill)
	_axt_erschoepfung(actor)

	# Echo: der Skill wiederholt sich beim nächsten Zug.
	if not _is_friendly_form(form):
		for mod in skill.get_modifier_blocks():
			if mod.modifier == Enums.SkillModifier.ECHO:
				_pending_echoes.append({"actor": actor, "skill": skill,
					"target": last_target, "power": mod.magnitude / 100.0})
				break

	if not _is_friendly_form(form):
		_consume_focus(actor)
	_check_battle_end()


## Offensive Treffer nach den Grundbausteinen: Anzahl (Zusatztreffer, der
## Schaden wird geteilt) × Zielwahl (gewählt / zufällig / wechselnd / alle).
## Überschlag trägt überschüssigen Schaden zum nächsten Gegner.
func _offensiv_treffer(actor: Combatant, skill: Skill, primary: Combatant, power_mult: float) -> Combatant:
	var treffer := skill.treffer()
	var je_treffer := skill.schaden_je_treffer()
	var modus := &"gewaehlt"
	if skill.get_form() == Enums.SkillForm.AOE:
		modus = &"alle"
	elif skill.hat(Enums.SkillModifier.ZIEL_ZUFALL):
		modus = &"zufall"
	elif skill.hat(Enums.SkillModifier.ZIEL_WECHSEL):
		modus = &"wechsel"
	var letzter: Combatant = null
	for i in treffer:
		var pool := _living(opponents_of(actor))
		if pool.is_empty():
			break
		var ziele: Array[Combatant] = []
		match modus:
			&"alle":
				ziele = pool
			&"zufall":
				ziele = [pool[rng.randi_range(0, pool.size() - 1)]]
			&"wechsel":
				var kandidaten := pool.filter(func(c: Combatant) -> bool: return c != letzter)
				if i == 0 and primary != null and primary.is_alive():
					ziele = [primary]
				elif not kandidaten.is_empty():
					ziele = [kandidaten[rng.randi_range(0, kandidaten.size() - 1)]]
				else:
					ziele = [pool[0]]
			_:
				# Gewähltes Ziel; ist es gefallen, springt der Rest auf einen Lebenden.
				if primary != null and primary.is_alive():
					ziele = [primary]
				elif letzter != null and letzter.is_alive():
					ziele = [letzter]
				else:
					ziele = [pool[rng.randi_range(0, pool.size() - 1)]]
		# Beschützer fangen JEDEN Treffer ab, der ein Teammitglied treffen würde.
		var umgeleitet: Array[Combatant] = []
		for ziel in ziele:
			umgeleitet.append(_apply_protection(ziel))
		for ziel in umgeleitet:
			if not ziel.is_alive():
				continue
			_apply_skill_hit(actor, skill, ziel, power_mult * je_treffer)
			if skill.hat(Enums.SkillModifier.UEBERSCHLAG) and _ueberschuss > 0:
				_ueberschlag(actor, ziel, _ueberschuss)
			letzter = ziel
	return letzter


## Überschlag: was über die Rest-HP hinausging, trifft den nächsten Gegner.
func _ueberschlag(actor: Combatant, von: Combatant, menge: int) -> void:
	for anderer in _living(opponents_of(actor)):
		if anderer == von:
			continue
		var dealt := anderer.take_damage(menge)
		_fx(&"waffe", von, anderer, {"fern": false})
		log_line.emit(Loc.pick("Überschlag: %d Schaden an %s!", "Overflow: %d damage to %s!")
			% [dealt, anderer.display_name])
		if not anderer.is_alive():
			log_line.emit(Loc.pick("%s wurde besiegt!", "%s was defeated!") % anderer.display_name)
		return


## Effekte mit eigenem Ziel (Anwender, Party, alle Gegner) wirken einmal pro
## Skill — so kann auch ein Waffenangriff dich selbst oder die Party stärken.
func _gezielte_effekte(actor: Combatant, skill: Skill, nur_gegner := false) -> void:
	for effect in skill.get_effect_blocks():
		if nur_gegner and effect.ziel != EffectBlock.Ziel.ALLE_GEGNER:
			continue
		var empfaenger: Array[Combatant] = []
		match effect.ziel:
			EffectBlock.Ziel.ANWENDER:
				empfaenger = [actor]
			EffectBlock.Ziel.PARTY:
				empfaenger = _living(allies_of(actor))
			EffectBlock.Ziel.ALLE_GEGNER:
				empfaenger = _living(opponents_of(actor))
			_:
				continue
		if rng.randi_range(1, 100) > effect.chance_percent:
			continue
		for empfaenger_einzeln in empfaenger:
			_effekt_anwenden(actor, effect, empfaenger_einzeln, 0)


## Axt-Besonderheit: nach einem wuchtigen Angriff ist der Held erschöpft.
func _axt_erschoepfung(actor: Combatant) -> void:
	if _erschoepfen.has(actor):
		_erschoepfen.erase(actor)
		if actor.is_alive():
			actor.add_status(Enums.Status.EXHAUSTED, 1, 0)
			log_line.emit(Loc.pick("%s muss sich erholen.", "%s needs to recover.") % actor.display_name)


func _fx(art: StringName, von: Combatant, an: Combatant, extra := {}) -> void:
	var daten := {"art": art, "von": von, "an": an}
	daten.merge(extra)
	effekt.emit(daten)


## Geist-Bonus für Heilung und Prozent-Effekte (Schild, Regeneration,
## Mana-Fluss, Wappnen): aus dem UNskalierten Geist mit abnehmendem Ertrag,
## höchstens ×2 — der welt-skalierte Wert ließ beides im Endgame explodieren.
static func geist_prozent_faktor(actor: Combatant) -> float:
	var roh := float(maxi(0, actor.stat_roh(&"spirit")))
	return 1.0 + roh / (roh + GEIST_PROZENT_HALB)


## Gespeicherte Stärke eines Effekts auf `target`: Geist-skaliert in Prozent;
## der Schild wird sofort in HP umgerechnet (Prozent der Max-HP des Ziels),
## Regeneration/Mana-Fluss/Wappnen bleiben Prozent und wirken relativ.
func _effekt_potenz(actor: Combatant, effect: EffectBlock, target: Combatant) -> int:
	var potenz := float(effect.potency)
	if effect.status in GEIST_SKALIERT:
		potenz *= geist_prozent_faktor(actor)
	if effect.status == Enums.Status.SHIELD:
		return maxi(1, roundi(target.max_hp * potenz / 100.0))
	return roundi(potenz)


## Würfelt eine Kontroll-Chance (Betäuben/Einfrieren). Bosse: halbe Chance,
## geteilt durch ihre wachsende Kontroll-Resistenz.
func kontrolle_gelingt(target: Combatant, chance_percent: float) -> bool:
	var chance := chance_percent
	if target.is_boss:
		chance *= BOSS_KONTROLL_FAKTOR / (1.0 + target.kontroll_resistenz)
	if rng.randf() * 100.0 >= chance:
		return false
	if target.is_boss:
		target.kontroll_resistenz += BOSS_KONTROLL_ZUWACHS
	return true


## Negative Statuseffekte, die ein Gegenmittel entfernt.
const CURABLE_STATUSES: Array[Enums.Status] = [
	Enums.Status.BURN, Enums.Status.POISON_DOT, Enums.Status.STUN,
	Enums.Status.SLOW, Enums.Status.WEAKEN,
	Enums.Status.FROZEN, Enums.Status.CURSED,
	Enums.Status.BLEED, Enums.Status.MARKED, Enums.Status.ARMOR_BREAK,
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


## Anzeige-Label eines Status-EINTRAGS: Stack-Statuseffekte (Brand/Gift/
## Blutung) zeigen ihre Stack-Zahl, Konzentration ihre Prozente — man soll
## sehen, wie viel da tickt, nicht nur DASS es tickt.
static func status_label(entry: Dictionary) -> String:
	var text := status_display_name(entry["status"])
	if entry["status"] in Combatant.STACKING_STATUSES:
		text += " ×%d" % int(entry["potency"])
	elif entry["status"] == Enums.Status.FOCUS:
		text += " +%d%%" % int(entry["potency"])
	return text


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
	if hat_aufladung(actor):
		aufladung_ausloesen(actor)
		return
	var foes := _living(opponents_of(actor))
	if foes.is_empty():
		return
	var heilen: Array[Skill] = []
	var helfen: Array[Skill] = []
	var angreifen: Array[Skill] = []
	for skill in actor.skills:
		if not (skill.is_valid(actor) and skill.usable_with_weapon(actor)) \
				or actor.mp < skill.get_mp_cost(actor):
			continue
		match ki_rolle(skill):
			&"heilen": heilen.append(skill)
			&"helfen": helfen.append(skill)
			_: angreifen.append(skill)
	# 1. Heilen, wenn ein Verbündeter angeschlagen ist.
	var verwundet := _am_meisten_verwundet(actor)
	if not heilen.is_empty() and verwundet != null \
			and float(verwundet.hp) / verwundet.max_hp < KI_HEILEN_UNTER and rng.randf() < 0.8:
		var skill: Skill = heilen[rng.randi_range(0, heilen.size() - 1)]
		if skill.get_form() != Enums.SkillForm.SELF or verwundet == actor:
			use_skill(actor, skill, verwundet)
			return
	# 2. Stärken/Schützen/Beschwören — nur, was gerade fehlt.
	if not helfen.is_empty() and rng.randf() < 0.4:
		var skill: Skill = helfen[rng.randi_range(0, helfen.size() - 1)]
		var ziel := _ki_hilfsziel(actor, skill)
		if ziel != null:
			use_skill(actor, skill, ziel)
			return
	# 3. Angriff: Skill oder Grundangriff, Ziel passend zum Skill.
	if not angreifen.is_empty() and rng.randf() < 0.6:
		var skill: Skill = angreifen[rng.randi_range(0, angreifen.size() - 1)]
		use_skill(actor, skill, _ki_angriffsziel(actor, skill, foes))
	else:
		basic_attack(actor, foes[rng.randi_range(0, foes.size() - 1)])


## Gegner-KI: wofür ein Skill gut ist — „heilen“ (Heilig auf Verbündete),
## „helfen“ (Buffs/Schutz/Beschwörung für die eigene Seite) oder „angreifen“.
static func ki_rolle(skill: Skill) -> StringName:
	var form := skill.get_form()
	if form == Enums.SkillForm.SUMMON:
		return &"helfen"
	if not _is_friendly_form(form):
		return &"angreifen"
	var element := skill.get_element()
	if element != null and element.element == Enums.Element.HOLY:
		return &"heilen"
	return &"helfen"


func _am_meisten_verwundet(actor: Combatant) -> Combatant:
	var bester: Combatant = null
	for ally in _living(allies_of(actor)):
		if ally.hp < ally.max_hp and (bester == null
				or float(ally.hp) / ally.max_hp < float(bester.hp) / bester.max_hp):
			bester = ally
	return bester


## Ziel für einen Hilfs-Skill — nur, wenn der Effekt dort noch fehlt
## (kein Dauer-Buffen). null = gerade nichts zu tun.
func _ki_hilfsziel(actor: Combatant, skill: Skill) -> Combatant:
	if skill.get_form() == Enums.SkillForm.SUMMON:
		for ally in allies_of(actor):
			if ally.is_summon and ally.summoner == actor and ally.is_alive():
				return null
		return actor
	var effekte := skill.get_effect_blocks()
	var kandidaten: Array[Combatant] = []
	match skill.get_form():
		Enums.SkillForm.SELF:
			kandidaten = [actor]
		_:
			kandidaten = _living(allies_of(actor))
	for kandidat in kandidaten:
		for effekt in effekte:
			if not kandidat.has_status(effekt.status):
				return kandidat
	return null


## Angriffsziel passend zum Skill: Hinrichtung jagt Angeschlagene, Ausnutzen
## Betäubte/Verlangsamte, Nachsetzen das schon getroffene Ziel — sonst Zufall.
func _ki_angriffsziel(actor: Combatant, skill: Skill, foes: Array[Combatant]) -> Combatant:
	if skill.hat(Enums.SkillModifier.EXECUTE):
		var schwaechster := foes[0]
		for foe in foes:
			if float(foe.hp) / foe.max_hp < float(schwaechster.hp) / schwaechster.max_hp:
				schwaechster = foe
		return schwaechster
	# Element-Skills suchen sich ein anfälliges Ziel (Schwäche ×1,5).
	var element := skill.get_element()
	if element != null:
		var anfaellig: Array[Combatant] = []
		for foe in foes:
			if foe.element_faktor(element.element) > 1.0:
				anfaellig.append(foe)
		if not anfaellig.is_empty():
			return anfaellig[rng.randi_range(0, anfaellig.size() - 1)]
	if skill.hat(Enums.SkillModifier.AUSNUTZEN):
		for foe in foes:
			if foe.has_status(Enums.Status.STUN) or foe.has_status(Enums.Status.FROZEN) \
					or foe.has_status(Enums.Status.SLOW):
				return foe
	if skill.hat(Enums.SkillModifier.NACHSETZEN):
		for foe in foes:
			for angreifer in _getroffen.get(foe, []):
				if angreifer != actor and angreifer.is_player == actor.is_player:
					return foe
	return foes[rng.randi_range(0, foes.size() - 1)]


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


## Initiative = Tempo × Würfel (0.85–1.15), einmal pro Kämpfer und Runde:
## Wer deutlich schneller ist, handelt immer zuerst; bei knappem Vorsprung
## meistens — aber nicht garantiert (Lutz: „ein bisschen Unberechenbarkeit“).
## Der Wurf für die NÄCHSTE Runde steht schon fest, damit die Zugleiste in
## der Befehlsphase die echte Reihenfolge zeigt.
const INITIATIVE_STREUUNG := 0.15
var _initiative_wurf: Dictionary = {}


func initiative(combatant: Combatant) -> float:
	if not _initiative_wurf.has(combatant):
		_initiative_wurf[combatant] = rng.randf_range(1.0 - INITIATIVE_STREUUNG, 1.0 + INITIATIVE_STREUUNG)
	return combatant.effective_speed() * float(_initiative_wurf[combatant])


func _start_new_round() -> void:
	round_number += 1
	var all := _living(players)
	all.append_array(_living(enemies))
	# Überraschung (Dungeon: von hinten erwischt): in Runde 1 handelt nur
	# die überlegene Seite — Erstschlag der Party bzw. Hinterhalt der Gegner.
	if round_number == 1 and ueberraschung != KEINE_UEBERRASCHUNG:
		var seite := _living(players) if ueberraschung == ERSTSCHLAG else _living(enemies)
		all = seite
		log_line.emit(Loc.pick("Erstschlag! Die Gegner sind völlig überrumpelt.",
			"Preemptive strike! The enemies are caught completely off guard.")
			if ueberraschung == ERSTSCHLAG else
			Loc.pick("Hinterhalt! Die Gegner schlagen zuerst zu.", "Ambush! The enemies strike first."))
	# Flinkheit (+1) handelt vor allen, Wucht (−1) nach allen — sonst Initiative.
	all.sort_custom(func(a: Combatant, b: Combatant) -> bool:
		var va: int = vorrang.get(a, 0)
		var vb: int = vorrang.get(b, 0)
		if va != vb:
			return va > vb
		return initiative(a) > initiative(b))
	_initiative_wurf.clear()  # nächste Runde wird neu gewürfelt
	vorrang.clear()
	_getroffen.clear()
	# Erstschlag (Dolch-Zutat): handelt garantiert zuerst, wird verbraucht.
	var first: Array[Combatant] = []
	for combatant in all.duplicate():
		if combatant.has_status(Enums.Status.FIRST_STRIKE):
			combatant.statuses.erase(combatant.get_status(Enums.Status.FIRST_STRIKE))
			all.erase(combatant)
			first.append(combatant)
	_queue = first + all
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
		if round_number == 0 and ueberraschung != KEINE_UEBERRASCHUNG:
			next_round = _living(players) if ueberraschung == ERSTSCHLAG else _living(enemies)
		# Dieselben Würfe wie beim echten Rundenstart — die Vorschau stimmt.
		next_round.sort_custom(func(a: Combatant, b: Combatant) -> bool:
			return initiative(a) > initiative(b))
		for actor in next_round:
			if result.size() >= count:
				break
			result.append(actor)
	return result


## true, wenn die aktuelle Runde abgearbeitet ist (das nächste next_turn()
## würde eine neue Runde beginnen) — die UI schaltet dann in die
## Kommandophase, in der ALLE Spieler erst ihre Aktion wählen (DQ-Stil).
func round_pending() -> bool:
	return not is_over and _queue.is_empty()


## Vorschau: Situations-Bonus (Hinrichtung, Kombos, Duell, Rache) gegen `target`.
func vorschau_situation(actor: Combatant, skill: Skill, target: Combatant) -> float:
	return _situations_faktor(actor, skill, target, true)


## Vorschau: Schadensfaktor und Durchschlag der Waffen-Besonderheit über alle
## Klingen (Axt ×2, Dolch 2 × 60 %, Armbrust durchschlägt Rüstung).
func vorschau_waffe(actor: Combatant, ohne_erschoepfung := false) -> Dictionary:
	var faktor := float(actor.weapon_hit_count())
	match actor.weapon_family():
		&"axt":
			if not ohne_erschoepfung:
				faktor *= Combatant.AXT_WUCHT
		&"dolch":
			faktor *= 2 * Combatant.DOLCH_TREFFER
	var durchschlag := Combatant.ARMBRUST_DURCHSCHLAG if actor.weapon_family() == &"armbrust" else 0.0
	return {"faktor": faktor, "pierce": actor.weapon_armor_pierce() + durchschlag}


## Erwarteter Schaden OHNE Anwendung (Vorschau bei der Zielwahl): dieselbe
## Mitigation wie _deal_damage, aber ohne Krit, ohne Nebenwirkungen und
## ohne das Eis zu brechen.
func preview_mitigated(attacker: Combatant, target: Combatant, raw: float,
		axis: Enums.DamageAxis,
		subtypes: Array[Enums.PhysicalSubtype] = [], pierce := 0.0) -> int:
	# Schwert-Besonderheit Parade: Nahkampftreffer abwehren und zurückschlagen.
	if axis == Enums.DamageAxis.PHYSICAL and not _retaliating and target.weapon_family() == &"schwert" \
			and not attacker.fernkampf() and rng.randi_range(1, 100) <= Combatant.SCHWERT_PARADE:
		log_line.emit(Loc.pick("%s pariert!", "%s parries!") % target.display_name)
		_fx(&"block", attacker, target)
		_retaliating = true
		var gegen := attacker.take_damage(maxi(1, roundi(target.weapon_damage() * Combatant.SCHWERT_RIPOSTE)))
		log_line.emit(Loc.pick("Gegenschlag: %d Schaden an %s.", "Riposte: %d damage to %s.") % [gegen, attacker.display_name])
		_retaliating = false
		_ueberschuss = 0
		return 0
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
	# Markiert (Bogen-Zutat): das Ziel nimmt von ALLEN mehr Schaden.
	var marked := target.get_status(Enums.Status.MARKED)
	if not marked.is_empty():
		amount = roundi(amount * (1.0 + marked["potency"] / 100.0))
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
	_fire_echoes(actor)
	var stunned := false
	var erschoepft := false
	# VOR der Verarbeitung erfassen: ein Brand, der diesen Tick erlischt,
	# blockiert die Troll-Regeneration trotzdem noch.
	var had_dot := actor.has_status(Enums.Status.BURN) \
		or actor.has_status(Enums.Status.POISON_DOT)
	for entry in actor.statuses.duplicate():
		match entry["status"]:
			Enums.Status.BURN:
				var burn_dmg: int = entry["potency"]
				_fx(&"dot", null, actor, {"element": Enums.Element.FIRE})
				actor.take_damage(burn_dmg)
				log_line.emit(Loc.pick("%s erleidet %d Brand-Schaden.", "%s takes %d burn damage.") % [actor.display_name, burn_dmg])
				entry["potency"] = int(entry["potency"] / 2.0)  # Stacks halbieren
				if entry["potency"] < 1:
					actor.statuses.erase(entry)
				continue
			Enums.Status.POISON_DOT:
				var poison_dmg: int = entry["potency"]
				_fx(&"dot", null, actor, {"element": Enums.Element.POISON})
				actor.take_damage(poison_dmg)
				log_line.emit(Loc.pick("%s erleidet %d Gift-Schaden.", "%s takes %d poison damage.") % [actor.display_name, poison_dmg])
				continue  # Gift läuft nie von selbst ab
			Enums.Status.BLEED:
				var bleed_dmg: int = entry["potency"]
				_fx(&"dot", null, actor, {"element": -1})
				actor.take_damage(bleed_dmg)
				log_line.emit(Loc.pick("%s erleidet %d Blutungs-Schaden.", "%s takes %d bleed damage.") % [actor.display_name, bleed_dmg])
				continue  # Blutung bleibt bis zur Kur
			Enums.Status.REGEN:
				# Prozent der Max-HP — bleibt auf jeder Stufe relevant.
				var hp_plus := maxi(1, roundi(actor.max_hp * int(entry["potency"]) / 100.0))
				actor.heal(hp_plus)
				_fx(&"heilung", null, actor)
				log_line.emit(Loc.pick("%s regeneriert %d HP.", "%s regenerates %d HP.") % [actor.display_name, hp_plus])
			Enums.Status.MANA_REGEN:
				var mp_plus := maxi(1, roundi(actor.max_mp * int(entry["potency"]) / 100.0))
				actor.mp = mini(actor.max_mp, actor.mp + mp_plus)
				log_line.emit(Loc.pick("%s regeneriert %d MP.", "%s regenerates %d MP.") % [actor.display_name, mp_plus])
			Enums.Status.STUN:
				stunned = true
				log_line.emit(Loc.pick("%s ist betäubt und setzt aus!", "%s is stunned and skips the turn!") % actor.display_name)
			Enums.Status.FROZEN:
				stunned = true
				log_line.emit(Loc.pick("%s ist eingefroren und setzt aus!", "%s is frozen and skips the turn!") % actor.display_name)
			Enums.Status.EXHAUSTED:
				erschoepft = true
				log_line.emit(Loc.pick("%s erholt sich von der Wucht.", "%s recovers from the heft.") % actor.display_name)
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
	return stunned or erschoepft  # Erschöpfung setzt aus, bricht aber keine Boss-Aufladung


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
	# Beschwörungs-HP folgen der Welt-Wachstumskurve des Beschwörers.
	summon.max_hp = roundi((15 + actor.stat(&"spirit") * SUMMON_HP_PER_SPIRIT) \
		* Scaling.factor(actor.level))
	summon.hp = summon.max_hp
	summon.max_mp = 999
	summon.mp = 999

	if element_block == null:
		# Wolf: physischer Angreifer (Biss über Waffennutzungs-Innenwerte).
		summon.innate_weapon_damage = maxi(1, roundi(power))
		summon.innate_weapon_subtypes = [Enums.PhysicalSubtype.PIERCE, Enums.PhysicalSubtype.SLASH] \
			as Array[Enums.PhysicalSubtype]
		summon.sprite = SpriteLib.enemy(&"wolf")
		summon.set_meta(&"figur", &"wolf")  # 3D-Figur (archetype_id bleibt leer!)
	else:
		# Elementar: zaubert mit dem Element des Skills (geteilte Bausteine).
		summon.innate_spell_damage = maxi(1, roundi(power))
		var elemental_skill := Skill.new()
		elemental_skill.display_name = "%s-Entladung" % element_block.display_name
		elemental_skill.blocks.append(BlockLibrary.get_block(&"src_spell"))
		elemental_skill.blocks.append(element_block)
		summon.skills = [elemental_skill]
		summon.sprite = SpriteLib.enemy(&"schleim")
		summon.set_meta(&"figur", &"schleim")

	# Effekt-Bausteine wirken auf die Beschwörung (Schutzwall, Regeneration, …).
	for effect in skill.get_effect_blocks():
		if effect.status in [Enums.Status.LIFESTEAL, Enums.Status.CLEANSE, Enums.Status.REVIVE] \
				or effect.ziel == EffectBlock.Ziel.ALLE_GEGNER:
			continue
		summon.add_status(effect.status, maxi(effect.duration_turns, SUMMON_DURATION),
			_effekt_potenz(actor, effect, summon))

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


func basic_attack(actor: Combatant, target: Combatant) -> void:
	if is_over:
		return
	target = _apply_protection(target)
	log_line.emit(Loc.pick("%s greift %s an.", "%s attacks %s.") % [actor.display_name, target.display_name])
	var raw := float(BASIC_ATTACK_BASE + actor.stat(&"strength") + actor.weapon_damage()) \
		* actor.training_weapon_mult()
	_waffen_treffer(actor, target, raw, 0.0, false)
	if not target.is_alive():
		log_line.emit(Loc.pick("%s wurde besiegt!", "%s was defeated!") % target.display_name)
	_axt_erschoepfung(actor)
	_consume_focus(actor)
	_check_battle_end()


## Ein Waffentreffer mit allen Waffen-Besonderheiten (Angriff UND Skills):
## Dolch doppelt (je 60 %), Axt ×2 (danach erschöpft), Armbrust ignoriert
## halbe Rüstung und trifft einen zweiten Gegner, Bogen mit 2 Pfeilen.
## Gibt den verursachten Schaden am Ziel zurück.
func _waffen_treffer(actor: Combatant, target: Combatant, raw: float, pierce: float,
		ohne_erschoepfung: bool) -> int:
	var familie := actor.weapon_family()
	if familie == &"axt" and not ohne_erschoepfung:
		raw *= Combatant.AXT_WUCHT
		_erschoepfen[actor] = true
	var klingen := 1
	if familie == &"dolch":
		klingen = 2
		raw *= Combatant.DOLCH_TREFFER
	var durchschlag := Combatant.ARMBRUST_DURCHSCHLAG if familie == &"armbrust" else 0.0
	var weapon_pierce := clampf(pierce + actor.weapon_armor_pierce() + durchschlag, 0.0, 0.9)
	var gesamt := 0
	for hit in actor.weapon_hit_count() * klingen:
		if not target.is_alive():
			break
		_fx(&"waffe", actor, target, {"fern": actor.fernkampf()})
		var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.PHYSICAL,
			actor.weapon_subtypes(), weapon_pierce)
		gesamt += dealt
		log_line.emit(Loc.pick("» %d Schaden an %s.", "» %d damage to %s.") % [dealt, target.display_name])
	# Armbrust: der Bolzen schlägt durch und trifft dahinter noch einen Gegner.
	if familie == &"armbrust":
		for anderer in _living(opponents_of(actor)):
			if anderer == target:
				continue
			_fx(&"waffe", actor, anderer, {"fern": true})
			var durch := _deal_damage(actor, anderer, raw * Combatant.ARMBRUST_NACHTREFFER,
				Enums.DamageAxis.PHYSICAL, actor.weapon_subtypes(), weapon_pierce)
			log_line.emit(Loc.pick("Der Bolzen schlägt durch: %d Schaden an %s.", "The bolt punches through: %d damage to %s.")
				% [durch, anderer.display_name])
			if not anderer.is_alive():
				log_line.emit(Loc.pick("%s wurde besiegt!", "%s was defeated!") % anderer.display_name)
			break
	actor.duel_target = target
	return gesamt


## Situations-Bonus eines Skills gegen dieses Ziel: Hinrichtung, Kombo-
## Klötze (Entzünden, Ausnutzen, Nachsetzen, Zermalmen), Duell, Rache.
func _situations_faktor(actor: Combatant, skill: Skill, target: Combatant, nur_vorschau := false) -> float:
	var faktor := 1.0
	for mod in skill.get_modifier_blocks():
		var bonus := 1.0 + mod.magnitude / 100.0
		match mod.modifier:
			Enums.SkillModifier.EXECUTE:
				if target.hp <= target.max_hp * EXECUTE_HP_THRESHOLD:
					faktor *= bonus
			Enums.SkillModifier.RAGE:
				# Rache: bei vollen HP −30 %, je mehr fehlt, desto härter.
				var fehlt := 1.0 - float(actor.hp) / maxi(1, actor.max_hp)
				faktor *= 0.7 + (mod.magnitude / 100.0 + 0.3) * fehlt
			Enums.SkillModifier.ENTZUENDEN:
				var brand := target.get_status(Enums.Status.BURN)
				if not brand.is_empty():
					faktor *= bonus
					if nur_vorschau:
						continue
					target.statuses.erase(brand)
					log_line.emit(Loc.pick("Entzündet! Der Brand an %s lodert auf.", "Ignited! The burn on %s flares up.")
						% target.display_name)
			Enums.SkillModifier.AUSNUTZEN:
				if target.has_status(Enums.Status.STUN) or target.has_status(Enums.Status.FROZEN) \
						or target.has_status(Enums.Status.SLOW):
					faktor *= bonus
			Enums.SkillModifier.NACHSETZEN:
				for angreifer in _getroffen.get(target, []):
					if angreifer != actor and angreifer.is_player == actor.is_player:
						faktor *= bonus
						break
			Enums.SkillModifier.ZERMALMEN:
				if target.has_status(Enums.Status.ARMOR_BREAK):
					faktor *= bonus
			Enums.SkillModifier.DUELL:
				if actor.duel_target == target:
					faktor *= bonus
	return faktor


func _apply_skill_hit(actor: Combatant, skill: Skill, target: Combatant, power_mult: float) -> void:
	var total_dealt := 0
	var friendly := _is_friendly_form(skill.get_form())
	var element_block := skill.get_element()
	_ueberschuss = 0
	# Trefferkontext für _deal_damage: Krit-Bonus/-Multiplikator, Alles oder
	# nichts, Schwachstellen-Chance, Volltreffer-Multiplikator.
	_kontext = {
		"krit_bonus": skill.staerke(Enums.SkillModifier.KRIT_BONUS),
		"krit_mult": skill.staerke(Enums.SkillModifier.KRIT_MULT) / 100.0,
		"aon": skill.hat(Enums.SkillModifier.ALLES_ODER_NICHTS),
		"schwach": skill.staerke(Enums.SkillModifier.SCHWACHSTELLE),
		"voll": skill.staerke(Enums.SkillModifier.VOLLTREFFER_MULT) / 100.0,
	}

	var pierce := 0.0
	for mod in skill.get_modifier_blocks():
		if mod.modifier == Enums.SkillModifier.PIERCE_ARMOR:
			pierce = maxf(pierce, mod.magnitude / 100.0)
	var situation := 1.0 if friendly else _situations_faktor(actor, skill, target)
	var signatur := 1.0
	if actor.weapon_family() == &"offensivstab":
		signatur *= Combatant.STAB_SIGNATUR
	if skill.hat(Enums.SkillModifier.ELEMENT_FOKUS):
		signatur *= 2.0

	for source in skill.get_sources():
		if source.source == Enums.SkillSource.WEAPON:
			# Waffenangriff: physisch, nur gegen Gegner.
			if friendly:
				continue
			var raw := (BASIC_ATTACK_BASE + actor.weapon_damage() \
					+ actor.stat(&"strength") * source.scaling_per_point) \
				* power_mult * source.power_multiplier * situation * actor.training_weapon_mult()
			total_dealt += _waffen_treffer(actor, target, raw, pierce,
				skill.hat(Enums.SkillModifier.KEIN_ERSCHOEPFT))
			# Element-Rider (Loot-Affixe): Zusatz-Elementschaden mit voller Signatur.
			var riders := actor.element_riders()
			for rider_element in riders:
				if not target.is_alive():
					break
				var rider_block := BlockLibrary.element_block(rider_element)
				if rider_block == null:
					continue
				total_dealt += _apply_elemental_hit(actor, target,
					riders[rider_element] * power_mult, rider_block, pierce, signatur)
			# Element-BAUSTEIN am Waffenangriff: halber Zusatztreffer mit Signatur.
			if element_block != null and target.is_alive():
				total_dealt += _apply_elemental_hit(actor, target,
					raw * 0.5, element_block, pierce, signatur)
		else:
			# Zauber: Schaden aus Zauberschaden der Waffe + INT.
			var raw := (actor.spell_damage() + actor.stat(&"intelligence") * source.scaling_per_point) \
				* power_mult * source.power_multiplier * situation * actor.training_spell_mult()
			if friendly:
				# Heilig-Zauber auf Verbündete » Heilung (heiliger Schaden wird umgewandelt).
				if element_block != null and element_block.element == Enums.Element.HOLY:
					# Geist-Bonus gedeckelt (wie bei den Prozent-Effekten): der welt-skalierte
					# Geist ließ Heilung sonst doppelt wachsen (Lv 50: Vollheilung je Zauber).
					var heal := raw * geist_prozent_faktor(actor)
					if actor.weapon_family() == &"heiligstab":
						heal *= Combatant.HEILIGSTAB_HEILUNG
					if _vollheil_plan.has(target):
						heal = _vollheil_plan[target]
						_vollheil_plan.erase(target)
					_heilen(actor, skill, target, roundi(heal))
				# Ohne Heilig: reiner Support-Zauber, kein Schaden an Verbündeten.
			elif element_block != null:
				total_dealt += _apply_elemental_hit(actor, target, raw, element_block, pierce, signatur)
			else:
				_fx(&"magie", actor, target)
				var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.MAGICAL, [], pierce)
				total_dealt += dealt
				log_line.emit(Loc.pick("» %d Schaden an %s.", "» %d damage to %s.") % [dealt, target.display_name])

	for effect in skill.get_effect_blocks():
		if effect.ziel != EffectBlock.Ziel.ZIEL:
			continue  # Anwender/Party/alle Gegner: einmal pro Skill (_gezielte_effekte)
		if rng.randi_range(1, 100) > effect.chance_percent:
			continue
		_effekt_anwenden(actor, effect, target, total_dealt)
	_kontext = {}

	if not target.is_alive():
		log_line.emit(Loc.pick("%s wurde besiegt!", "%s was defeated!") % target.display_name)


## Heilung mit Überheilung (Überschuss wird zu Schild-HP, wenn der Skill sie hat).
func _heilen(actor: Combatant, skill: Skill, target: Combatant, heal: int) -> void:
	_fx(&"heilung", actor, target)
	var missing := target.max_hp - target.hp
	target.heal(heal)
	log_line.emit(Loc.pick("%s heilt %d HP.", "%s heals %d HP.") % [target.display_name, heal])
	if heal > missing:
		for mod in skill.get_modifier_blocks():
			if mod.modifier != Enums.SkillModifier.OVERHEAL_SHIELD:
				continue
			var overshield := roundi((heal - missing) * mod.magnitude / 100.0)
			if overshield > 0:
				target.add_status(Enums.Status.SHIELD, 3, overshield)
				log_line.emit(Loc.pick("Überheilung: %s erhält einen Schild (%d HP).",
					"Overheal: %s gains a shield (%d HP).") % [target.display_name, overshield])
			break


## Einen Effekt-Klotz auf ein Ziel anwenden (Chance schon gewürfelt).
## Gift/Brand/Blutung mit Dauer −1 = Stacks aus % des verursachten Schadens.
func _effekt_anwenden(actor: Combatant, effect: EffectBlock, target: Combatant, total_dealt: int) -> void:
	if not target.is_alive() and effect.status != Enums.Status.REVIVE:
		return
	match effect.status:
		Enums.Status.LIFESTEAL:
			var healed := roundi(total_dealt * effect.potency / 100.0)
			if healed > 0:
				actor.heal(healed)
				log_line.emit(Loc.pick("%s raubt %d HP.", "%s drains %d HP.") % [actor.display_name, healed])
		Enums.Status.REVIVE:
			pass  # Wird in _skill_wirken auf Gefallene angewendet, nicht auf Zielliste.
		Enums.Status.CLEANSE:
			_fx(&"status", actor, target, {"status": Enums.Status.CLEANSE})
			for entry in target.statuses.duplicate():
				if entry["status"] in CURABLE_STATUSES:
					target.statuses.erase(entry)
			log_line.emit(Loc.pick("%s wird von allen Leiden gereinigt.", "%s is cleansed of all ailments.") % target.display_name)
		Enums.Status.BLEED, Enums.Status.POISON_DOT, Enums.Status.BURN:
			if effect.duration_turns >= 0:
				target.add_status(effect.status, effect.duration_turns, effect.potency)
				return
			# Stacks aus dem Trefferschaden (Blutung, Giftklinge, Brandbolzen).
			if total_dealt > 0:
				var stacks := maxi(1, roundi(total_dealt * effect.potency / 100.0))
				target.add_status(effect.status, -1, stacks)
				_fx(&"dot", actor, target, {"element": Enums.Element.POISON if effect.status == Enums.Status.POISON_DOT
					else (Enums.Element.FIRE if effect.status == Enums.Status.BURN else -1)})
				log_line.emit(Loc.pick("%s: +%d %s-Stacks.", "%s: +%d %s stacks.")
					% [target.display_name, stacks, status_display_name(effect.status)])
		_:
			if effect.status in KONTROLL_STATUS and not kontrolle_gelingt(target, 100):
				log_line.emit(Loc.pick("%s widersteht!", "%s resists!") % target.display_name)
				return
			target.add_status(effect.status, effect.duration_turns, _effekt_potenz(actor, effect, target))
			_fx(&"status", actor, target, {"status": effect.status})
			log_line.emit(Loc.pick("%s: %s (%d Runden).", "%s: %s (%d rounds).")
				% [target.display_name, status_display_name(effect.status), effect.duration_turns])


## Element-Signaturen (Phase 3): Jedes Element spielt sich eigen.
##   Feuer » Brand-Stacks (Burst, halbiert sich) · Gift » permanente Stacks
##   Eis » Einfrieren/Verlangsamen · Blitz » Kette + Betäubungs-Chance
##   Heilig » Bonus vs. Untote · Dunkel » Lebensraub + Fluch
## Gibt den direkt verursachten Schaden zurück (für Lebensraub-Effekte).
func _apply_elemental_hit(actor: Combatant, target: Combatant, raw: float,
		element_block: ElementBlock, pierce := 0.0, signatur := 1.0) -> int:
	# signatur: Stärke der Element-Signatur (Offensivstab ×1,5, Element-Fokus ×2).
	# Element-Resistenz (Loot-Affixe): prozentuale Minderung VOR der Signatur —
	# senkt bei Brand/Gift auch die aufgebauten Stacks. Durchschlag hebelt sie aus.
	var resist := target.element_resist(element_block.element)
	if resist > 0:
		raw = maxf(1.0, raw * (1.0 - resist / 100.0 * (1.0 - pierce)))
	# Schwäche/Resistenz des Grundtyps (gilt auch für Brand-/Gift-Stacks).
	var faktor := target.element_faktor(element_block.element)
	if not is_equal_approx(faktor, 1.0):
		raw *= faktor
		if faktor > 1.0:
			log_line.emit(Loc.pick("%s ist anfällig für %s — sehr effektiv!", "%s is weak to %s — super effective!")
				% [target.display_name, element_block.display_name])
		else:
			log_line.emit(Loc.pick("%s widersteht %s — kaum Wirkung …", "%s resists %s — barely any effect …")
				% [target.display_name, element_block.display_name])
		element_reaktion.emit(target, element_block.element, faktor)
	_fx(&"element", actor, target, {"element": element_block.element, "faktor": faktor})
	match element_block.element:
		Enums.Element.FIRE, Enums.Element.POISON:
			# DoT-Elemente: Stacks basierend auf dem Schaden, addieren sich.
			var stacks := maxi(1, roundi(raw * element_block.status_scale * signatur))
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
				if kontrolle_gelingt(target, minf(100.0, ICE_FREEZE_CHANCE * signatur)):
					target.add_status(Enums.Status.FROZEN, 1, 0)
					log_line.emit(Loc.pick("%s friert ein!", "%s freezes solid!") % target.display_name)
				else:
					target.add_status(Enums.Status.SLOW, 2, 30)
					log_line.emit(Loc.pick("%s ist unterkühlt (verlangsamt).", "%s is chilled (slowed).") % target.display_name)
			return dealt
		Enums.Element.LIGHTNING:
			var dealt := _deal_damage(actor, target, raw, Enums.DamageAxis.MAGICAL, [], pierce)
			log_line.emit(Loc.pick("» %d Blitzschaden an %s.", "» %d lightning damage to %s.") % [dealt, target.display_name])
			if target.is_alive() and kontrolle_gelingt(target, minf(100.0, LIGHTNING_STUN_CHANCE * signatur)):
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
					raw * minf(1.0, LIGHTNING_CHAIN_FACTOR * signatur), Enums.DamageAxis.MAGICAL, [], pierce)
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
			var healed := roundi(dealt * DARK_LIFESTEAL * signatur)
			if healed > 0:
				actor.heal(healed)
				log_line.emit(Loc.pick("%s raubt %d HP.", "%s drains %d HP.") % [actor.display_name, healed])
			if target.is_alive():
				var fluch := roundi(CURSE_POTENCY * signatur)
				target.add_status(Enums.Status.CURSED, CURSE_TURNS, fluch)
				log_line.emit(Loc.pick("%s ist verflucht (+%d%% erlittener Schaden).", "%s is cursed (+%d%% damage taken).")
					% [target.display_name, fluch])
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
	# Schwert-Besonderheit Parade: Nahkampftreffer abwehren und zurückschlagen.
	if axis == Enums.DamageAxis.PHYSICAL and not _retaliating and target.weapon_family() == &"schwert" \
			and not attacker.fernkampf() and rng.randi_range(1, 100) <= Combatant.SCHWERT_PARADE:
		log_line.emit(Loc.pick("%s pariert!", "%s parries!") % target.display_name)
		_fx(&"block", attacker, target)
		_retaliating = true
		var gegen := attacker.take_damage(maxi(1, roundi(target.weapon_damage() * Combatant.SCHWERT_RIPOSTE)))
		log_line.emit(Loc.pick("Gegenschlag: %d Schaden an %s.", "Riposte: %d damage to %s.") % [gegen, attacker.display_name])
		_retaliating = false
		_ueberschuss = 0
		return 0
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
	# Markiert (Bogen-Zutat): das Ziel nimmt von ALLEN mehr Schaden.
	var marked := target.get_status(Enums.Status.MARKED)
	if not marked.is_empty():
		amount = roundi(amount * (1.0 + marked["potency"] / 100.0))
	var guard := target.get_status(Enums.Status.GUARD)
	if not guard.is_empty():
		amount = roundi(amount * (1.0 - guard["potency"] / 100.0))
	# Schild-Eigenheiten: Blocken (Einhand-Schild) / Bollwerk (Turmschild).
	if axis == Enums.DamageAxis.PHYSICAL and target.wields_buckler() \
			and rng.randi_range(1, 100) <= Combatant.SCHILD_BLOCK:
		amount = roundi(amount * 0.5)
		log_line.emit(Loc.pick("%s blockt mit dem Schild!", "%s blocks with the shield!")
			% target.display_name)
		_fx(&"block", attacker, target)
	if target.wields_tower_shield():
		amount = roundi(amount * 0.85)
	amount = maxi(1, amount)
	# Treffer-Arten: Krit (×1,5 bzw. Skill-Multiplikator), Schwachstelle (×2),
	# beides zugleich = VOLLTREFFER (×4). Glück wirkt mit abnehmendem Ertrag.
	var krit := crit_enabled and rng.randi_range(1, 100) <= CRIT_BASE_PERCENT \
		+ Combatant.luck_crit_bonus(attacker.stat(&"luck")) \
		+ attacker.training_crit_bonus() + int(_kontext.get("krit_bonus", 0))
	var schwach_chance: int = attacker.schwachstellen_chance() + int(_kontext.get("schwach", 0))
	var schwach := crit_enabled and schwach_chance > 0 and rng.randi_range(1, 100) <= schwach_chance
	if _kontext.get("aon", false) and not krit:
		log_line.emit(Loc.pick("Alles oder nichts — verfehlt!", "All or nothing — missed!"))
		_ueberschuss = 0
		return 0
	var mult := 1.0
	if krit:
		mult = float(_kontext.get("krit_mult", 0.0))
		if mult <= 0.0:
			mult = 3.0 if _kontext.get("aon", false) else CRIT_MULTIPLIER
	if schwach:
		mult *= SCHWACHSTELLE_MULT
	if krit and schwach:
		var voll := float(_kontext.get("voll", 0.0))
		mult = maxf(mult, voll if voll > 0.0 else VOLLTREFFER)
		log_line.emit(Loc.pick("VOLLTREFFER!", "BULLSEYE!"))
		_fx(&"krit", attacker, target, {"voll": true})
	elif krit:
		log_line.emit(Loc.pick("Kritischer Treffer!", "Critical hit!"))
		_fx(&"krit", attacker, target)
	elif schwach:
		log_line.emit(Loc.pick("Schwachstelle getroffen!", "Weak spot hit!"))
		_fx(&"krit", attacker, target, {"schwach": true})
	amount = roundi(amount * mult)
	# Erschütterung (Stumpf): jeder Treffer −5% Rüstung und Betäubungs-Chance.
	var stumpf := axis == Enums.DamageAxis.PHYSICAL and attacker.weapon_family() == &"stumpf"
	if stumpf:
		target.armor_shred = mini(50, target.armor_shred + 5)
	_ueberschuss = maxi(0, amount - target.hp)
	var dealt_final := target.take_damage(amount)
	if dealt_final > 0:
		var liste: Array = _getroffen.get(target, [])
		liste.append(attacker)
		_getroffen[target] = liste
	if stumpf and target.is_alive() and not target.has_status(Enums.Status.STUN) \
			and kontrolle_gelingt(target, Combatant.STUMPF_BETAEUBUNG):
		target.add_status(Enums.Status.STUN, 1, 0)
		log_line.emit(Loc.pick("%s ist von der Wucht benommen!", "%s is dazed by the blow!") % target.display_name)
	if target.mercy_just:
		target.mercy_just = false
		log_line.emit(Loc.pick("Gnade! Der Heiligstab hält %s mit 1 HP am Leben.",
			"Mercy! The holy staff keeps %s alive at 1 HP.") % target.display_name)
	_retaliate(attacker, target, dealt_final, axis)
	return dealt_final


## Konter-Haltung (% Waffenschaden, nur gegen physische Treffer) und
## Vergeltung (% des erlittenen Schadens) — nie kaskadierend.
func _retaliate(attacker: Combatant, target: Combatant, dealt: int,
		axis: Enums.DamageAxis) -> void:
	if _retaliating or is_over or attacker == target:
		return
	if not attacker.is_alive() or not target.is_alive():
		return
	_retaliating = true
	var counter := target.get_status(Enums.Status.COUNTER)
	if not counter.is_empty() and axis == Enums.DamageAxis.PHYSICAL:
		var back := attacker.take_damage(maxi(1,
			roundi(target.weapon_damage() * counter["potency"] / 100.0)))
		log_line.emit(Loc.pick("%s kontert: %d Schaden an %s!",
			"%s counters: %d damage to %s!")
			% [target.display_name, back, attacker.display_name])
	var thorns := target.get_status(Enums.Status.THORNS)
	if not thorns.is_empty():
		var reflected := attacker.take_damage(maxi(1,
			roundi(dealt * thorns["potency"] / 100.0)))
		log_line.emit(Loc.pick("Vergeltung! %s erleidet %d Schaden.",
			"Retribution! %s suffers %d damage.")
			% [attacker.display_name, reflected])
	_retaliating = false
	_check_battle_end()


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


## Präzise Wirkungs-Beschreibung eines Status-Effekts mit eingesetzter
## Stärke — exakt das, was der Kampf-Code tut (Werkstatt + Tooltips).
static func status_effect_text(status: Enums.Status, potency: int) -> String:
	match status:
		Enums.Status.WEAKEN:
			return Loc.pick("Ziel verursacht −%d%% Schaden", "target deals −%d%% damage") % potency
		Enums.Status.SLOW:
			return Loc.pick("Ziel ist −%d%% langsamer (handelt später)", "target is −%d%% slower (acts later)") % potency
		Enums.Status.STUN:
			return Loc.pick("Ziel setzt aus (bricht Boss-Aufladungen)", "target skips its turn (breaks boss charge-ups)")
		Enums.Status.LIFESTEAL:
			return Loc.pick("heilt dich um %d%% des verursachten Schadens", "heals you for %d%% of damage dealt") % potency
		Enums.Status.SHIELD:
			return Loc.pick("Schild absorbiert %d%% der Max-HP des Ziels", "shield absorbs %d%% of the target's max HP") % potency
		Enums.Status.REGEN:
			return Loc.pick("heilt %d%% der Max-HP am Zugbeginn", "heals %d%% of max HP at turn start") % potency
		Enums.Status.DEF_UP:
			return Loc.pick("+%d%% Rüstung (gegen physische Treffer)", "+%d%% armor (vs physical hits)") % potency
		Enums.Status.ATK_UP:
			return Loc.pick("+%d%% verursachter Schaden", "+%d%% damage dealt") % potency
		Enums.Status.MANA_REGEN:
			return Loc.pick("+%d%% der Max-MP am Zugbeginn", "+%d%% of max MP at turn start") % potency
		Enums.Status.PROTECT:
			return Loc.pick("fängt ALLE Angriffe auf Verbündete ab (auch Flächen)", "intercepts ALL attacks on allies (even AoE)")
		Enums.Status.CLEANSE:
			return Loc.pick("entfernt sofort alle Leiden vom Ziel (Buffs bleiben)", "instantly removes all ailments from the target (buffs stay)")
		Enums.Status.REVIVE:
			return Loc.pick("belebt Gefallene mit %d%% Max-HP wieder", "revives the fallen with %d%% max HP") % potency
		Enums.Status.BLEED:
			return Loc.pick("Blutung: Stacks = %d%% des Trefferschadens, ticken jede Runde bis zur Kur", "bleed: stacks = %d%% of hit damage, tick every round until cured") % potency
		Enums.Status.COUNTER:
			return Loc.pick("physische Angreifer kassieren %d%% deines Waffenschadens", "physical attackers take %d%% of your weapon damage") % potency
		Enums.Status.THORNS:
			return Loc.pick("reflektiert %d%% des erlittenen Schadens", "reflects %d%% of damage taken") % potency
		Enums.Status.MARKED:
			return Loc.pick("Ziel nimmt +%d%% Schaden von ALLEN", "target takes +%d%% damage from EVERYONE") % potency
		Enums.Status.ARMOR_BREAK:
			return Loc.pick("−%d%% Rüstung des Ziels", "−%d%% of the target's armor") % potency
		Enums.Status.FIRST_STRIKE:
			return Loc.pick("du handelst nächste Runde garantiert zuerst", "you are guaranteed to act first next round")
	return status_display_name(status)


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
		Enums.Status.BLEED: return Loc.pick("Blutung", "Bleeding")
		Enums.Status.COUNTER: return Loc.pick("Konter-Haltung", "Counter stance")
		Enums.Status.THORNS: return Loc.pick("Vergeltung", "Retribution")
		Enums.Status.MARKED: return Loc.pick("Markiert", "Marked")
		Enums.Status.ARMOR_BREAK: return Loc.pick("Rüstungsriss", "Armor break")
		Enums.Status.FIRST_STRIKE: return Loc.pick("Erstschlag", "First strike")
		Enums.Status.FOCUS: return Loc.pick("Konzentriert", "Focused")
		Enums.Status.EXHAUSTED: return Loc.pick("Erschöpft", "Exhausted")
	return "?"


## Echo-Zutat: geplante Wiederholungen dieses Kämpfers zünden (halbe Kraft,
## keine MP-Kosten). Totes Ziel » ein lebender Gegner rückt nach.
func _fire_echoes(actor: Combatant) -> void:
	for entry in _pending_echoes.duplicate():
		if entry["actor"] != actor:
			continue
		_pending_echoes.erase(entry)
		if is_over or not actor.is_alive():
			continue
		var target: Combatant = entry["target"]
		if target == null or not target.is_alive():
			var pool := _living(opponents_of(actor))
			if pool.is_empty():
				continue
			target = pool[rng.randi_range(0, pool.size() - 1)]
		var skill: Skill = entry["skill"]
		log_line.emit(Loc.pick("Das Echo von %s hallt nach!", "The echo of %s resounds!")
			% skill.display_name)
		_apply_skill_hit(actor, skill, target, entry["power"])
		_check_battle_end()
