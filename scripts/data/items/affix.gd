class_name Affix
extends Resource
## Ein zufälliger Prefix oder Suffix auf einem generierten Item (Diablo-Stil),
## z.B. "Flammendes ..." oder "... des Sturms".

@export var id: StringName
@export var is_prefix: bool = true

## Namensteil: Prefixe vor dem Item-Namen ("Flammendes Schwert"),
## Suffixe dahinter ("Schwert des Sturms").
@export var name_part: String

## Attribut-Boni dieses Affixes.
@export var stat_bonus: StatBlock

## Direkte Kampfwert-Boni (unabhängig von Attributen).
@export var bonus_damage: int = 0
@export var bonus_armor: int = 0

## Zauberkraft-Bonus (für Stäbe/Foki — skaliert wie Waffenschaden mit dem Item-Level).
@export var bonus_spell_damage: int = 0

## Element-Achse: `element` bestimmt, worauf sich Rider und Resistenz beziehen.
## element_damage > 0 » Waffen-Rider: jeder Waffennutzungs-Treffer trägt
## zusätzlich diesen Elementschaden (inkl. Signatur: Brand-Stacks, Fluch, …).
## element_resist > 0 » flache Minderung gegen dieses Element; mit
## element == NONE wirkt die Resistenz gegen ALLE Elemente.
@export var element: Enums.Element = Enums.Element.NONE
@export var element_damage: int = 0
@export var element_resist: int = 0

## Flache MP-Kosten-Reduktion für alle Skills des Trägers (Skill-Suffix).
@export var mp_cost_reduction: int = 0

## Regelbrecher (Design-Review 2026-10-17): ändert eine Bauregel für den
## Träger — &"sockel" (+1 Sockel), &"doppelkern" (zwei Kern-Klötze),
## &"waffenfrei" (Techniken mit jeder Waffe). Rollt nie im normalen Pool.
@export var regelbruch: StringName = &""

## Boss-Affix (BossBeute): nur auf Boss-Beute, Pool je Boss-Grundtyp
## (boss_id = Archetyp-ID). boss_effekt = eigene Kampfwirkung (wut, jaeger,
## steinhaut, verschlingen, opfergabe, lebensraub, regeneration, rache) mit
## boss_wert in Prozent (× Qualitäts-Roll); leer = Wirkung über die
## normalen Felder (Element-Rider, Rüstung, Attribute, MP-Ersparnis).
@export var boss_id: StringName = &""
@export var boss_effekt: StringName = &""
@export var boss_wert: int = 0

## Prozent-Affix (ab Kartenstufe 10): prozent_art = &"ruestung", &"schaden"
## (Waffenschaden), &"zauberkraft" oder ein Attribut (&"strength" …);
## prozent_wert = Prozent (× Qualitäts-Roll). Alle Item-Prozente einer Art
## addieren sich (auch mit den Trainings-Prozenten) und wirken einmal auf die
## Summe der festen Werte (Combatant.item_prozent).
@export var prozent_art: StringName = &""
@export var prozent_wert: int = 0

## Skill-Affix: wirkt auf selbst gebaute Helden-Skills, die den Bezug
## erfüllen (Skill.passt_bezug) — „klotz:<id>“, „gruppe:<gruppe>“,
## „gattung:<waffe>“ (Techniken dieser Waffe), „element:<element>“,
## „form:<form>“. klotz_wirkung: &"schaden" (+% Schaden), &"mp" (−% MP-Kosten),
## &"dauer" (+Runden für Effekte), &"stacks" (+% Brand/Gift/Blutung-Stacks),
## &"treffer" (+% Chance auf einen Zusatztreffer), &"krit" (+% Krit-Chance).
## klotz_wert = Zahl (× Qualitäts-Roll, außer bei „dauer“).
## Wert über Combatant.skill_bonus — höchstens einmal je Skill.
@export var klotz_bezug: StringName = &""
@export var klotz_wirkung: StringName = &""
@export var klotz_wert: int = 0

## Auf welchen Slots dieser Affix rollen darf (leer = überall).
## Element-Rider gehören auf Waffen, Resistenzen auf Rüstung/Schmuck.
@export var allowed_slots: Array[Enums.EquipSlot] = []

## Tier bestimmt, ab welcher Dungeon-Kartenstufe dieser Affix droppen kann
## und wie stark seine Werte ausfallen.
@export var tier: int = 1

## Rarität des Affixes: bestimmt, wie oft er beim Würfeln gezogen wird
## (gewichteter Pool) — seltene Affixe sind der Jackpot beim Neuwürfeln.
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON


## Gruppen dieses Affixes (Größe, die er verändert; Skill-Affixe je Bezug).
## Abgeleitet aus den Feldern — es gibt keine Liste zu pflegen.
func gruppen() -> Array[StringName]:
	var result: Array[StringName] = []
	if klotz_bezug != &"":
		result.append(StringName("skill:" + String(klotz_bezug)))
		return result
	if bonus_damage != 0 or prozent_art == &"schaden":
		result.append(&"schaden")
	if bonus_armor != 0 or prozent_art == &"ruestung":
		result.append(&"ruestung")
	if bonus_spell_damage != 0 or prozent_art == &"zauberkraft":
		result.append(&"zauberkraft")
	for stat in StatBlock.STAT_NAMES:
		if (stat_bonus != null and int(stat_bonus.get(stat)) != 0) or prozent_art == stat:
			result.append(StringName("attr_" + String(stat)))
	return result


## Schließen sich die beiden Affixe auf einem Item aus? Pro Item entweder
## „+x Rüstung“ oder „+x % Rüstung“: ein Prozent-Affix verträgt keinen
## anderen Affix derselben Größe (fest oder prozentual), Skill-Affixe keinen
## mit demselben Bezug. Feste Affixe untereinander bleiben kombinierbar.
func konflikt(andere: Affix) -> bool:
	if prozent_art == &"" and andere.prozent_art == &"" and not ist_skill_affix() \
			and not andere.ist_skill_affix():
		return false
	for gruppe in gruppen():
		if gruppe in andere.gruppen():
			return true
	return false


## Passt der Affix zu den schon gewählten (kein konflikt())?
func passt_zu(gewaehlt: Array[Affix]) -> bool:
	for andere in gewaehlt:
		if konflikt(andere):
			return false
	return true


## Würfelt der Affix einen Qualitäts-Roll? Regelbrecher und „+1 Runde“
## sind feste Werte (Roll 1,0).
func rollt() -> bool:
	return regelbruch == &"" and klotz_wirkung != &"dauer"


## Ist es ein Skill-Affix (wirkt auf gebaute Skills)?
func ist_skill_affix() -> bool:
	return klotz_bezug != &"" and klotz_wirkung != &""


## Grundwert für Anzeige und Spanne: der erste von null verschiedene
## Zahlenwert (Skill-, Prozent-, Kampf-, Element-, MP-, Boss-, Attributwert).
func grundwert() -> int:
	for wert in [klotz_wert, prozent_wert, bonus_damage, bonus_armor, bonus_spell_damage,
			element_damage, element_resist, mp_cost_reduction, boss_wert]:
		if wert != 0:
			return wert
	if stat_bonus != null:
		for stat in StatBlock.STAT_NAMES:
			if int(stat_bonus.get(stat)) != 0:
				return int(stat_bonus.get(stat))
	return 0


## Wächst der Wert mit dem Item-Level? (Feste Kampfwerte und Element-Rider —
## wie ItemInstance.get_total_damage & Co.; Prozente, Attribute, Resistenzen nicht.)
func skaliert_mit_level() -> bool:
	return bonus_damage != 0 or bonus_armor != 0 or bonus_spell_damage != 0 or element_damage != 0
