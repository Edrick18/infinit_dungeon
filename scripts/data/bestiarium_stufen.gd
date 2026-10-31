class_name BestiariumStufen
extends RefCounted
## Bestiarium-Stufen (Lutz 2026-11, wie die Medaillen-Stufen): je JE
## entdeckten Grundtypen (mindestens einmal besiegt) holt man beim Händler
## eine feste Belohnung ab — Gold oder Mini-Medaillen UND eine neue
## Rüstungsfarbe für die Helden (FigurenBau.SONDER_FARBEN, rein kosmetisch).
## Die letzte Stufe gilt für ALLE Grundtypen.

const JE := 5
## [Art, Menge] je Stufe; Gold-Menge = Kämpfe-Beute auf Party-Level (GOLD_KAEMPFE je Menge).
const STUFEN := [
	[&"medaillen", 1], [&"gold", 1], [&"medaillen", 2], [&"gold", 2],
	[&"medaillen", 2], [&"gold", 3], [&"medaillen", 3],
]
const GOLD_KAEMPFE := 10


## Zahl der Grundtypen im Spiel (Ziel der letzten Stufe).
static func grundtypen() -> int:
	return EnemyLibrary.all_archetypes().size()


## Zahl der Stufen: alle JE Grundtypen eine, die letzte bei allen.
static func anzahl() -> int:
	return ceili(float(grundtypen()) / JE)


static func schwelle(index: int) -> int:
	return mini((index + 1) * JE, grundtypen())


static func belohnung(index: int) -> Array:
	return STUFEN[index % STUFEN.size()]


## Die Rüstungsfarbe dieser Stufe (leer, wenn es keine mehr gibt).
static func farbe(index: int) -> StringName:
	if index < FigurenBau.SONDER_FARBEN.size():
		return FigurenBau.SONDER_FARBEN[index][0]
	return &""


## Gold einer Gold-Stufe: so viel wie GOLD_KAEMPFE Kämpfe auf diesem Level
## (wie die Taverne-Trainingspreise) — skaliert mit dem Party-Level.
static func gold_betrag(menge: int, level: int) -> int:
	return roundi(menge * GOLD_KAEMPFE * (8 + level * 4) * Scaling.factor(level))


static func abholbar(entdeckt: int, abgeholt: int) -> bool:
	return abgeholt < anzahl() and entdeckt >= schwelle(abgeholt)


## Belohnungstext einer Stufe (Gold mit dem Betrag für dieses Level).
static func text(index: int, level: int) -> String:
	var art: Array = belohnung(index)
	var teil := ""
	if art[0] == &"gold":
		teil = Loc.pick("%d Gold", "%d gold") % gold_betrag(int(art[1]), level)
	else:
		teil = Loc.anzahl(int(art[1]), "Mini-Medaille", "Mini-Medaillen", "mini medal", "mini medals")
	var farb_id := farbe(index)
	if farb_id != &"":
		teil += Loc.pick(" + Rüstungsfarbe %s", " + armor color %s") % FigurenBau.sonder_farb_name(farb_id)
	return teil


## Holt die nächste Stufe ab (state = GameState). Gibt den Belohnungstext
## zurück, leer wenn noch nicht erreicht.
static func abholen(state: Node) -> String:
	var index: int = state.bestiarium_stufen
	if not abholbar(state.entdeckte_grundtypen(), index):
		return ""
	var level: int = state.average_party_level()
	var ergebnis := text(index, level)
	var art: Array = belohnung(index)
	if art[0] == &"gold":
		state.gold += gold_betrag(int(art[1]), level)
	else:
		# Direkt statt medaille(): Hub-Belohnung, zählt nicht in der Lauf-Bilanz.
		state.medals += int(art[1])
		state.medaillen_gesamt += int(art[1])
	var farb_id := farbe(index)
	if farb_id != &"" and farb_id not in state.farben_frei:
		state.farben_frei.append(farb_id)
	state.bestiarium_stufen = index + 1
	return ergebnis
