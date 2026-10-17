class_name MedaillenStufen
extends RefCounted
## Medaillen-Stufen (Design-Review 2026-10-17, DQ-Medaillenmann): wer
## insgesamt genug Mini-Medaillen GESAMMELT hat (Ausgeben zählt nicht
## dagegen), holt beim Händler feste Belohnungen ab — eine je Stufe.

## [Schwelle, Belohnung] — nach der letzten alle DANACH_ALLE eine Regelrune.
const STUFEN := [
	[5, &"lager"], [10, &"rune_episch"], [20, &"schatzkarte"], [30, &"rune_regel"],
	[50, &"rune_legendaer"], [75, &"lager"], [100, &"rune_regel"],
]
const DANACH_ALLE := 50
const LAGER_PLAETZE := 5


static func schwelle(index: int) -> int:
	if index < STUFEN.size():
		return int(STUFEN[index][0])
	return int(STUFEN.back()[0]) + DANACH_ALLE * (index - STUFEN.size() + 1)


static func belohnung(index: int) -> StringName:
	if index < STUFEN.size():
		return STUFEN[index][1]
	return &"rune_regel"


static func text(art: StringName) -> String:
	match art:
		&"lager":
			return Loc.pick("+%d Plätze im Kartenlager", "+%d map storage slots") % LAGER_PLAETZE
		&"schatzkarte":
			return Loc.pick("Schatzkarte (episch oder legendär)", "Treasure map (epic or legendary)")
	return MaterialLibrary.display_name(art)


static func abholbar(gesamt: int, abgeholt: int) -> bool:
	return gesamt >= schwelle(abgeholt)


## Holt die nächste Stufe ab (state = GameState). Gibt den Belohnungstext
## zurück, leer wenn noch nicht erreicht.
static func abholen(state: Node) -> String:
	var index: int = state.medaillen_stufen
	if not abholbar(state.medaillen_gesamt, index):
		return ""
	var art := belohnung(index)
	match art:
		&"lager":
			state.card_capacity += LAGER_PLAETZE
		&"schatzkarte":
			state.add_card(CardFactory.make_schatzkarte(maxi(1, roundi(state.average_party_level()))))
		_:
			state.add_material(art, 1)
	state.medaillen_stufen = index + 1
	return text(art)
