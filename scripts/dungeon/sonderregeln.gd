class_name Sonderregeln
extends RefCounted
## Besondere Dungeons (Design-Review 2026-10-17): manche Karten tragen eine
## SONDERREGEL, die verändert, wie man sie spielt — fix bei der Erstellung,
## wie alle Karten-Eigenschaften. Dazu kommt auf manchen Ebenen ein Tresor,
## dessen Schlüssel ein Gegner der Ebene trägt (DungeonGenerator).
##
## Wirkung: EnemyFactory.make_encounter (Gegner), Skill.get_mp_cost über
## Combatant.kosten_mult (Manaflut), DungeonGenerator (Schatzfieber).

const ELEMENTARSTURM := &"elementarsturm"
const TOTENREICH := &"totenreich"
const JAGDGEBIET := &"jagdgebiet"
const RIESENWUCHS := &"riesenwuchs"
const MANAFLUT := &"manaflut"
const SCHATZFIEBER := &"schatzfieber"

const ALLE: Array[StringName] = [ELEMENTARSTURM, TOTENREICH, JAGDGEBIET, RIESENWUCHS,
	MANAFLUT, SCHATZFIEBER]

## Ab dieser Kartenstufe gibt es Sonderregeln; Chance je Karten-Rarität.
const AB_STUFE := 3
const CHANCE := {
	Enums.Rarity.COMMON: 0.08, Enums.Rarity.MAGIC: 0.12, Enums.Rarity.RARE: 0.18,
	Enums.Rarity.EPIC: 0.25, Enums.Rarity.LEGENDARY: 0.25,
}

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


static func mimic_chance(karte: DungeonCard) -> float:
	if karte.tier < MIMIC_AB_STUFE:
		return 0.0
	if karte.sonderregel == SCHATZFIEBER:
		return SCHATZFIEBER_MIMIC
	return MIMIC_CHANCE
const JAGD_CHAMPION := 2.0

## Bonus auf Beute bzw. XP der ganzen Karte.
const BEUTE := {ELEMENTARSTURM: 1.25, JAGDGEBIET: 1.4}
const XP := {TOTENREICH: 1.3}

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
}


## Würfelt die Sonderregel einer neuen Karte (am Ende von make_card, damit
## alle anderen Würfe gleich bleiben).
static func wuerfeln(card: DungeonCard, rng: RandomNumberGenerator) -> void:
	card.sonderregel = &""
	card.sonder_element = -1
	if card.tier < AB_STUFE:
		return
	if rng.randf() >= float(CHANCE.get(card.card_rarity, 0.08)):
		return
	card.sonderregel = ALLE[rng.randi_range(0, ALLE.size() - 1)]
	if card.sonderregel == ELEMENTARSTURM:
		var elemente := [Enums.Element.FIRE, Enums.Element.ICE, Enums.Element.LIGHTNING,
			Enums.Element.POISON, Enums.Element.HOLY, Enums.Element.DARK]
		card.sonder_element = elemente[rng.randi_range(0, elemente.size() - 1)]


static func name_von(card: DungeonCard) -> String:
	var t: Array = TEXTE.get(card.sonderregel, [])
	return "" if t.is_empty() else Loc.pick(t[0], t[1])


static func text_von(card: DungeonCard) -> String:
	var t: Array = TEXTE.get(card.sonderregel, [])
	if t.is_empty():
		return ""
	var text: String = Loc.pick(t[2], t[3])
	if card.sonderregel == ELEMENTARSTURM:
		var block := BlockLibrary.element_block(card.sonder_element)
		text = text.replace("%s", block.display_name if block != null else "?")
	return text


static func beute_mult(card: DungeonCard) -> float:
	return float(BEUTE.get(card.sonderregel, 1.0))


static func xp_mult(card: DungeonCard) -> float:
	return float(XP.get(card.sonderregel, 1.0))


static func kosten_mult(card: DungeonCard) -> float:
	return MANAFLUT_KOSTEN if card != null and card.sonderregel == MANAFLUT else 1.0
