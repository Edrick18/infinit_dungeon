class_name Sonderregeln
extends RefCounted
## Besondere Dungeons (Design-Review 2026-10-17): manche Karten tragen eine
## SONDERREGEL, die verändert, wie man sie spielt — fix bei der Erstellung,
## wie alle Karten-Eigenschaften. Dazu kommt auf manchen Ebenen ein Tresor,
## dessen Schlüssel ein Gegner der Ebene trägt (DungeonGenerator).
##
## Wirkung: EnemyFactory.make_encounter (Gegner), Skill.get_mp_cost über
## Combatant.kosten_mult (Manaflut), DungeonGenerator (Schatzfieber).
##
## Regeln statt nur Grind (2026-11-02): die KAMPF_REGELN ändern, welche
## Befehle es gibt und wie Kämpfe verlaufen (Fliehen, Tränke, Verteidigen/
## Konzentrieren, Elemente, Nachschub, Anschleichen). Sie kommen erst auf
## höheren Stufen in den Pool (MIN_STUFE), ab Stufe 50 tragen deutlich mehr
## Karten eine Regel und manche eine zweite (sonderregel_2, nur Kampfregeln).
## Wirkung: BattleScene (Befehle, Kampfbeginn, Rundenbeginn) und
## DungeonScene (Wachsamkeit) über die Funktionen unten.

const ELEMENTARSTURM := &"elementarsturm"
const TOTENREICH := &"totenreich"
const JAGDGEBIET := &"jagdgebiet"
const RIESENWUCHS := &"riesenwuchs"
const MANAFLUT := &"manaflut"
const SCHATZFIEBER := &"schatzfieber"
# Kampfregeln (2026-11-02)
const AUSWEGLOS := &"ausweglos"
const WACHSAM := &"wachsam"
const POLARITAET := &"polaritaet"
const KAMPFRAUSCH := &"kampfrausch"
const VERSIEGELT := &"versiegelt"
const NACHSCHUB := &"nachschub"

const ALLE: Array[StringName] = [ELEMENTARSTURM, TOTENREICH, JAGDGEBIET, RIESENWUCHS,
	MANAFLUT, SCHATZFIEBER, AUSWEGLOS, WACHSAM, POLARITAET, KAMPFRAUSCH, VERSIEGELT, NACHSCHUB]
## Regeln, die als zweite Regel einer Karte kommen dürfen (wirken außerhalb
## der Gegner-Erzeugung).
const KAMPF_REGELN: Array[StringName] = [AUSWEGLOS, WACHSAM, POLARITAET, KAMPFRAUSCH,
	VERSIEGELT, NACHSCHUB]
## Ab welcher Kartenstufe eine Regel in den Pool kommt (fehlt = AB_STUFE).
const MIN_STUFE := {
	AUSWEGLOS: 15, WACHSAM: 20, POLARITAET: 25, KAMPFRAUSCH: 30, VERSIEGELT: 35, NACHSCHUB: 40,
}

## Ab dieser Kartenstufe gibt es Sonderregeln; Chance je Karten-Rarität.
const AB_STUFE := 3
const CHANCE := {
	Enums.Rarity.COMMON: 0.08, Enums.Rarity.MAGIC: 0.12, Enums.Rarity.RARE: 0.18,
	Enums.Rarity.EPIC: 0.25, Enums.Rarity.LEGENDARY: 0.25,
}
## Ab Stufe 50 deutlich öfter: +15 % und +0,2 % je weitere Stufe (höchstens +30 %).
const HOCH_AB := 50
const HOCH_BONUS := 0.15
const HOCH_JE_STUFE := 0.002
const HOCH_MAX := 0.3
## Zweite Regel (nur Kampfregeln) ab Stufe 50: 25 % + 0,3 % je Stufe, höchstens 45 %.
const ZWEITE_AB := 50
const ZWEITE_CHANCE := 0.25
const ZWEITE_JE_STUFE := 0.003
const ZWEITE_MAX := 0.45

# Werte
const TOTENREICH_HP := 1.15
const RIESEN_HP := 1.8
const RIESEN_SCHADEN := 1.25
const RIESEN_BEUTE := 1.8
const RIESEN_GRUPPE := 2
const MANAFLUT_KOSTEN := 0.5
const SCHATZFIEBER_MIMIC := 0.25
## Mimic-Chance einer normalen Truhe beim Öffnen (Lutz 2026-10-24: ein Wurf
## wie bei der Beute, vorher nicht erkennbar): nie auf Stufe 1–2, sonst 5 %,
## mit Schatzfieber 25 %.
const MIMIC_CHANCE := 0.05
const MIMIC_AB_STUFE := 3
## Kampfrausch: Konzentrieren +100 % je Zug, höchstens +300 %.
const RAUSCH_SCHRITT := 100
const RAUSCH_MAX := 300
## Polarität: Schwäche-Bonus ×2 (1,5 » 2,0), Resistenz nochmals ×0,5 (0,5 » 0,25).
const POL_SCHWAECHE := 2.0
const POL_RESISTENZ := 0.5
## Nachschub: Chance je gefallenem Gegner, höchstens so viele je Kampf.
const NACHSCHUB_CHANCE := 0.4
const NACHSCHUB_MAX := 2


static func mimic_chance(karte: DungeonCard) -> float:
	if karte.tier < MIMIC_AB_STUFE:
		return 0.0
	if hat(karte, SCHATZFIEBER):
		return SCHATZFIEBER_MIMIC
	return MIMIC_CHANCE
const JAGD_CHAMPION := 2.0

## Bonus auf Beute bzw. XP der ganzen Karte (Regeln multiplizieren sich).
const BEUTE := {ELEMENTARSTURM: 1.25, JAGDGEBIET: 1.4, AUSWEGLOS: 1.2, POLARITAET: 1.15,
	VERSIEGELT: 1.15}
const XP := {TOTENREICH: 1.3, WACHSAM: 1.15, POLARITAET: 1.1, KAMPFRAUSCH: 1.2, VERSIEGELT: 1.25,
	NACHSCHUB: 1.15}

## Regel » [Name DE, Name EN, Text DE, Text EN] — sachlich, was sie tut.
const TEXTE := {
	ELEMENTARSTURM: ["Elementarsturm", "Elemental storm",
		"Alle Gegner tragen das Element %s. +25 % Beute.",
		"All enemies carry the element %s. +25% loot."],
	TOTENREICH: ["Totenreich", "Realm of the dead",
		"Alle Gegner sind untot und haben +15 % HP. +30 % Erfahrung.",
		"All enemies are undead and have +15% HP. +30% experience."],
	JAGDGEBIET: ["Jagdgebiet", "Hunting ground",
		"Jede Gruppe wird von einem Elite-Gegner angeführt, Champions doppelt so häufig. +40 % Beute.",
		"Every group is led by an elite enemy, champions twice as common. +40% loot."],
	RIESENWUCHS: ["Riesenwuchs", "Giant growth",
		"Höchstens 2 Gegner pro Gruppe, jeder mit +80 % HP, +25 % Schaden und +80 % Erfahrung und Beute.",
		"At most 2 enemies per group, each with +80% HP, +25% damage and +80% experience and loot."],
	MANAFLUT: ["Manaflut", "Mana flood",
		"Alle Skills kosten die Hälfte an MP — für Helden und Gegner.",
		"All skills cost half the MP — for heroes and enemies."],
	SCHATZFIEBER: ["Schatzfieber", "Treasure fever",
		"Doppelt so viele Truhen. Jede Truhe ist beim Öffnen mit 25 % Chance ein Mimic.",
		"Twice as many chests. Every chest has a 25% chance to be a mimic when opened."],
	AUSWEGLOS: ["Ausweglos", "No way out",
		"Fliehen ist in keinem Kampf möglich. +20 % Beute.",
		"Fleeing is impossible in every battle. +20% loot."],
	WACHSAM: ["Wachsamkeit", "Vigilance",
		"Gegner bemerken die Party auch von hinten, es gibt keinen Erstschlag. +15 % Erfahrung.",
		"Enemies notice the party from behind as well; there are no preemptive strikes. +15% experience."],
	POLARITAET: ["Polarität", "Polarity",
		"Element-Schwächen der Gegner verdoppeln ihren Bonus (×1,5 wird ×2), Element-Resistenzen halbieren noch einmal (×0,5 wird ×0,25). +15 % Beute, +10 % Erfahrung.",
		"Enemy element weaknesses double their bonus (×1.5 becomes ×2), element resistances halve once more (×0.5 becomes ×0.25). +15% loot, +10% experience."],
	KAMPFRAUSCH: ["Kampfrausch", "Battle frenzy",
		"Verteidigen ist nicht möglich. Konzentrieren gibt +100 % je Zug (höchstens +300 %). +20 % Erfahrung.",
		"Defending is impossible. Focus grants +100% per turn (at most +300%). +20% experience."],
	VERSIEGELT: ["Versiegelte Taschen", "Sealed bags",
		"Im Kampf lassen sich keine Gegenstände benutzen. +25 % Erfahrung, +15 % Beute.",
		"No items can be used in battle. +25% experience, +15% loot."],
	NACHSCHUB: ["Nachschub", "Reinforcements",
		"Fällt ein Gegner, rückt zu Beginn der nächsten Runde mit 40 % Chance ein neuer Gegner der Karte nach (höchstens 2 je Kampf, nicht im Bosskampf). +15 % Erfahrung.",
		"When an enemy falls, a new enemy of the map joins at the start of the next round with a 40% chance (at most 2 per battle, not in boss battles). +15% experience."],
}


## Chance einer Karte auf eine Sonderregel.
static func chance_fuer(tier: int, rarity: Enums.Rarity) -> float:
	var chance := float(CHANCE.get(rarity, 0.08))
	if tier >= HOCH_AB:
		chance += minf(HOCH_MAX, HOCH_BONUS + HOCH_JE_STUFE * (tier - HOCH_AB))
	return chance


static func zweite_chance(tier: int) -> float:
	if tier < ZWEITE_AB:
		return 0.0
	return minf(ZWEITE_MAX, ZWEITE_CHANCE + ZWEITE_JE_STUFE * (tier - ZWEITE_AB))


## Regeln, die auf dieser Stufe vorkommen können.
static func pool(tier: int, nur_kampf := false) -> Array[StringName]:
	var result: Array[StringName] = []
	for regel in (KAMPF_REGELN if nur_kampf else ALLE):
		if tier >= int(MIN_STUFE.get(regel, AB_STUFE)):
			result.append(regel)
	return result


## Würfelt die Sonderregel(n) einer neuen Karte (am Ende von make_card, damit
## alle anderen Würfe gleich bleiben).
static func wuerfeln(card: DungeonCard, rng: RandomNumberGenerator) -> void:
	card.sonderregel = &""
	card.sonderregel_2 = &""
	card.sonder_element = -1
	if card.tier < AB_STUFE:
		return
	if rng.randf() >= chance_fuer(card.tier, card.card_rarity):
		return
	var erste := pool(card.tier)
	card.sonderregel = erste[rng.randi_range(0, erste.size() - 1)]
	if card.sonderregel == ELEMENTARSTURM:
		var elemente := [Enums.Element.FIRE, Enums.Element.ICE, Enums.Element.LIGHTNING,
			Enums.Element.POISON, Enums.Element.HOLY, Enums.Element.DARK]
		card.sonder_element = elemente[rng.randi_range(0, elemente.size() - 1)]
	if rng.randf() < zweite_chance(card.tier):
		var zweite := pool(card.tier, true)
		zweite.erase(card.sonderregel)
		if not zweite.is_empty():
			card.sonderregel_2 = zweite[rng.randi_range(0, zweite.size() - 1)]


## Kampfregel der Tiefe (endlose Ebenen, 2026-11-09): ab Tiefe 1 (Ebene 11+)
## gilt genau eine Kampfregel, fest aus Karten-Seed und Tiefe gewürfelt; mit
## der nächsten Tiefe kommt eine neue. Nur Regeln, deren Mindeststufe die
## Gegnerstufe der Ebene erreicht, und keine, die die Karte schon trägt.
## "" = keine (Tiefe 0 oder noch keine Regel freigeschaltet).
static func tiefen_regel_fuer(card: DungeonCard, ebene: int) -> StringName:
	var tiefe := DungeonGenerator.tiefe(ebene)
	if card == null or tiefe < 1:
		return &""
	var kandidaten := pool(DungeonGenerator.gegner_stufe(card, ebene), true)
	kandidaten.erase(card.sonderregel)
	kandidaten.erase(card.sonderregel_2)
	if kandidaten.is_empty():
		return &""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([card.seed, tiefe, "tiefen_regel"])
	return kandidaten[rng.randi_range(0, kandidaten.size() - 1)]


## Trägt die Karte diese Regel (als erste, zweite oder als Regel der Tiefe)?
static func hat(card: DungeonCard, regel: StringName) -> bool:
	return card != null and regel != &"" and (card.sonderregel == regel
		or card.sonderregel_2 == regel or card.tiefen_regel == regel)


## Alle Regeln der Karte (0 bis 3, mit der Regel der aktuellen Tiefe).
static func regeln(card: DungeonCard) -> Array[StringName]:
	var result: Array[StringName] = []
	if card == null:
		return result
	for regel in [card.sonderregel, card.sonderregel_2, card.tiefen_regel]:
		if regel != &"" and TEXTE.has(regel) and regel not in result:
			result.append(regel)
	return result


static func regel_name(regel: StringName) -> String:
	var t: Array = TEXTE.get(regel, [])
	return "" if t.is_empty() else Loc.pick(t[0], t[1])


static func regel_text(card: DungeonCard, regel: StringName) -> String:
	var t: Array = TEXTE.get(regel, [])
	if t.is_empty():
		return ""
	var text: String = Loc.pick(t[2], t[3])
	if regel == ELEMENTARSTURM:
		var block := BlockLibrary.element_block(card.sonder_element)
		text = text.replace("%s", block.display_name if block != null else "?")
	return text


## Namen aller Regeln („Ausweglos · Polarität“), "" = keine.
static func name_von(card: DungeonCard) -> String:
	var namen: Array[String] = []
	for regel in regeln(card):
		namen.append(regel_name(regel))
	return " · ".join(namen)


## Text der ersten Regel (ältere Aufrufer); alle Regeln: zeile().
static func text_von(card: DungeonCard) -> String:
	return regel_text(card, card.sonderregel) if card != null else ""


## Alle Regeln als Anzeige: „Name: Text“, je Regel eine Zeile.
static func zeile(card: DungeonCard) -> String:
	var zeilen: Array[String] = []
	for regel in regeln(card):
		zeilen.append("%s: %s" % [regel_name(regel), regel_text(card, regel)])
	return "\n".join(zeilen)


static func beute_mult(card: DungeonCard) -> float:
	var mult := 1.0
	for regel in regeln(card):
		mult *= float(BEUTE.get(regel, 1.0))
	return mult


static func xp_mult(card: DungeonCard) -> float:
	var mult := 1.0
	for regel in regeln(card):
		mult *= float(XP.get(regel, 1.0))
	return mult


static func kosten_mult(card: DungeonCard) -> float:
	return MANAFLUT_KOSTEN if hat(card, MANAFLUT) else 1.0


# --- Kampfregeln ---------------------------------------------------------------

## Ist dieser Befehl (Plan-Art der Kampfszene: flee, item, defend …) auf der
## Karte gesperrt? "" = erlaubt, sonst die Meldung.
static func befehl_gesperrt(card: DungeonCard, art: String) -> String:
	if card == null:
		return ""
	if art == "flee" and hat(card, AUSWEGLOS):
		return Loc.pick("Ausweglos: Fliehen ist nicht möglich.", "No way out: fleeing is impossible.")
	if art == "item" and hat(card, VERSIEGELT):
		return Loc.pick("Versiegelte Taschen: Im Kampf lassen sich keine Gegenstände benutzen.",
			"Sealed bags: no items can be used in battle.")
	if art == "defend" and hat(card, KAMPFRAUSCH):
		return Loc.pick("Kampfrausch: Verteidigen ist nicht möglich.", "Battle frenzy: defending is impossible.")
	return ""


## Kampfrausch-Konzentrieren: +100 % je Zug, höchstens +300 % (statt +50/+200).
static func rausch_konzentrieren(battle: Battle, actor: Combatant) -> void:
	if battle.is_over:
		return
	var focus := actor.get_status(Enums.Status.FOCUS)
	var potency := RAUSCH_SCHRITT
	if not focus.is_empty():
		potency = mini(RAUSCH_MAX, int(focus["potency"]) + RAUSCH_SCHRITT)
		actor.statuses.erase(focus)
	actor.add_status(Enums.Status.FOCUS, 99, potency)
	battle.log_line.emit(Loc.pick("%s konzentriert sich — nächster Angriff +%d%%!",
		"%s focuses — next attack +%d%%!") % [actor.display_name, potency])


## Polarität: verstärkt die Element-Schwächen/-Resistenzen eines Gegners
## (einmal je Kämpfer, auch für später erscheinende).
static func polaritaet_anwenden(card: DungeonCard, kaempfer: Combatant) -> void:
	if not hat(card, POLARITAET) or kaempfer.is_player or kaempfer.has_meta(&"polaritaet"):
		return
	kaempfer.set_meta(&"polaritaet", true)
	for element in kaempfer.element_faktoren.keys():
		var faktor := float(kaempfer.element_faktoren[element])
		if faktor > 1.0:
			kaempfer.element_faktoren[element] = 1.0 + (faktor - 1.0) * POL_SCHWAECHE
		elif faktor < 1.0:
			kaempfer.element_faktoren[element] = faktor * POL_RESISTENZ


## Nachschub zu Rundenbeginn: je neu gefallenem Gegner ein Wurf. Gibt die
## neuen Gegner zurück (schon im Kampf und gemeldet).
static func nachschub(battle: Battle, card: DungeonCard, ebene: int,
		rng: RandomNumberGenerator) -> Array[Combatant]:
	var neu: Array[Combatant] = []
	if not hat(card, NACHSCHUB) or battle.is_over or battle.has_boss():
		return neu
	for foe in battle.enemies:
		if foe.archetype_id == &"mimic":
			return neu  # Mimic-Kampf: die Truhe ruft niemanden
	var gerufen := int(battle.get_meta(&"nachschub", 0))
	for foe in battle.enemies.duplicate():
		if foe.is_alive() or foe.is_summon or foe.has_meta(&"nachschub_geprueft"):
			continue
		foe.set_meta(&"nachschub_geprueft", true)
		var lebend := 0
		for andere in battle.enemies:
			if andere.is_alive():
				lebend += 1
		if gerufen >= NACHSCHUB_MAX or lebend >= Eigenheiten.MAX_GEGNER:
			continue
		if rng.randf() >= NACHSCHUB_CHANCE:
			continue
		var gruppe := EnemyFactory.make_encounter(card, rng, false, ebene)
		if gruppe.is_empty():
			continue
		var kaempfer: Combatant = gruppe[0]
		kaempfer.reinforcement_called = true
		polaritaet_anwenden(card, kaempfer)
		battle.enemies.append(kaempfer)
		battle.combatant_added.emit(kaempfer)
		battle.log_line.emit(Loc.pick("Nachschub: %s rückt nach!", "Reinforcements: %s joins the battle!")
			% kaempfer.display_name)
		gerufen += 1
		neu.append(kaempfer)
	battle.set_meta(&"nachschub", gerufen)
	return neu


## Wachsamkeit: Gegner sehen rundum (Sichtkegel entfällt).
static func rundumsicht(card: DungeonCard) -> bool:
	return hat(card, WACHSAM)


## Wachsamkeit: kein Erstschlag der Party.
static func ueberraschung_anpassen(card: DungeonCard, ueberraschung: int) -> int:
	if hat(card, WACHSAM) and ueberraschung == Battle.ERSTSCHLAG:
		return Battle.KEINE_UEBERRASCHUNG
	return ueberraschung
