class_name KlotzKette
extends RefCounted
## Klotz-Kette der Skill-Werkstatt (Formen-Pass 2026-11, Wunsch Lutz): An der
## FORM eines Klotzes sieht man, was zuerst gebraucht wird und was woran passt.
##  • Feste Reihenfolge Quelle → Form → Element → Effekte → Eigenschaften
##    (Skill.rang); Klick/E schiebt einen Klotz an seine Stelle, Ziehen legt
##    ihn genau dorthin, wo man ihn ablegt (falsch = abgewiesen).
##  • Die Quelle ist das Startstück (glatte linke Kante). Rechts trägt sie die
##    Nase ihres Typs: Waffe eckig, Zauber rund, Körper spitz; jeder Klotz der
##    Kette gibt diese Nase weiter.
##  • Jeder Typ hat seine eigene Höhe: Waffe oben, Zauber Mitte, Körper unten.
##    Die Kerben links zeigen, an welchen Quellen ein Klotz geht — eine Kerbe
##    je passendem Typ (alle drei = passt an jede Quelle).
## Logik ohne UI (headless testbar) plus Geometrie und Zeichnen der Teile.

const TYPEN: Array[StringName] = [&"waffe", &"zauber", &"koerper"]
const _TYP_QUELLE := {&"waffe": &"src_weapon", &"zauber": &"src_spell", &"koerper": &"src_koerper"}

## Geometrie: Nase ragt NASE px über die rechte Kante; Kerben sind etwas
## größer (SPIEL), damit die Nase sichtbar hineinpasst.
const NASE := 14.0
const SPIEL := 2.0

static var _typen_cache: Dictionary = {}
static var _form_cache: Dictionary = {}


# --- Kette -----------------------------------------------------------------------

## Stelle, an die `block` in der Kette gehört: hinter den letzten Klotz
## gleichen oder kleineren Rangs (Klick/E schiebt ihn dorthin).
static func einfuege_index(skill: Skill, block: SkillBlock) -> int:
	var r := Skill.rang(block)
	var index := 0
	for i in skill.blocks.size():
		if Skill.rang(skill.blocks[i]) <= r:
			index = i + 1
	return index


## Fehler in der Werkstatt: die Regeln des Skills (auch im Kampf) und dazu die
## Kettenfolge (nur Werkstatt — markiert, „Reparieren“ sortiert).
static func werkstatt_fehler(skill: Skill, held: Combatant) -> String:
	var grund := skill.fehler(held)
	if grund.is_empty() and not skill.get_sources().is_empty():
		grund = skill.reihenfolge_fehler()
	return grund


## Ablegen per Ziehen auf Sockel `index` (ersetzt oder hängt an): die Regeln
## (WerkstattLogik.passt) und die Kettenfolge — an die falsche Stelle geht nichts.
static func passt_ablegen(skill: Skill, index: int, block: SkillBlock, held: Combatant) -> String:
	var grund := WerkstattLogik.passt(skill, index, block, held)
	if not grund.is_empty():
		return grund
	var probe := Skill.new()
	probe.blocks = skill.blocks.duplicate()
	if index < probe.blocks.size():
		probe.blocks[index] = block
	else:
		probe.blocks.append(block)
	var folge := probe.reihenfolge_fehler()
	if not folge.is_empty() and folge != skill.reihenfolge_fehler():
		return folge
	return ""


## Passt `block`, wenn er an `index` EINGEFÜGT wird (die Kette rückt nach)?
## "" = ja, sonst der Grund. Ohne Quelle passt zuerst nur eine Quelle; ein
## Fehler, den der Skill ohnehin hat, sperrt nicht (reparieren muss gehen).
static func passt_einfuegen(skill: Skill, index: int, block: SkillBlock, held: Combatant) -> String:
	if skill.blocks.size() >= held.block_sockets():
		return Loc.pick("Alle Sockel belegt", "All sockets taken")
	if skill.get_sources().is_empty() and not block is SourceBlock:
		return Loc.pick("Zuerst eine Quelle", "A source comes first")
	var probe := Skill.new()
	probe.blocks = skill.blocks.duplicate()
	probe.blocks.insert(clampi(index, 0, probe.blocks.size()), block)
	var grund := werkstatt_fehler(probe, held)
	if grund.is_empty() or grund == werkstatt_fehler(skill, held):
		return ""
	return grund


## Vorlagen-Rezepte mit Klotz-IDs in Kettenfolge (die Liste selbst bleibt).
static func rezepte_sortiert(rezepte: Array) -> Array:
	var result := []
	for rezept in rezepte:
		var bloecke: Array[SkillBlock] = []
		for id in rezept[2]:
			var block := BlockLibrary.get_block(id)
			if block != null:
				bloecke.append(block)
		var ids := []
		for block in Skill.sortiert(bloecke):
			ids.append(block.id)
		var kopie: Array = rezept.duplicate()
		kopie[2] = ids
		result.append(kopie)
	return result


## Rang, ab dem der nächste Klotz kommen darf (für den leeren Platz).
static func naechster_rang(skill: Skill) -> int:
	if skill.blocks.is_empty():
		return 0
	var r := Skill.rang(skill.blocks.back())
	# Form und Element gibt es nur einmal: danach geht es eine Stufe weiter.
	if r in [1, 2]:
		return r + 1
	if r == 0 and skill.has_source(Enums.SkillSource.KOERPER):
		return 1
	return r


# --- Anschluss-Typen ------------------------------------------------------------

## Typ einer Quelle: waffe (eckig), zauber (rund), koerper (spitz).
static func quellen_typ(quelle: SourceBlock) -> StringName:
	match quelle.source:
		Enums.SkillSource.SPELL:
			return &"zauber"
		Enums.SkillSource.KOERPER:
			return &"koerper"
	return &"waffe"


## Typen der Kette (alle Quellen des Skills) — die Nase, die sie weitergibt.
static func ketten_typen(skill: Skill) -> Array[StringName]:
	var typen: Array[StringName] = []
	for quelle in skill.get_sources():
		var t := quellen_typ(quelle)
		if not t in typen:
			typen.append(t)
	return typen


## An welchen Quellen ein Klotz grundsätzlich geht (seine Kerbe). Eine
## Quelle gibt ihren eigenen Typ; sonst zählt ein Typ, wenn es mit ihm
## mindestens einen gültigen Skill gibt (geprüft mit typischen Formen).
static func quelle_typen(block: SkillBlock) -> Array[StringName]:
	if block is SourceBlock:
		return [quellen_typ(block)]
	var schluessel := String(block.id) if block.id != &"" else block.display_name
	if _typen_cache.has(schluessel):
		return _typen_cache[schluessel]
	var zusaetze := [[], [&"form_self"], [&"form_aoe"], [&"form_ally"], [&"elem_holy", &"form_ally"]]
	var typen: Array[StringName] = []
	for typ in TYPEN:
		for zusatz in zusaetze:
			var probe := Skill.new()
			probe.blocks.append(BlockLibrary.get_block(_TYP_QUELLE[typ]))
			var unpassend := false
			for id in zusatz:
				var extra := BlockLibrary.get_block(id)
				if extra == null or extra.id == block.id \
						or (block is FormBlock and extra is FormBlock) \
						or (block is ElementBlock and extra is ElementBlock):
					unpassend = true
					break
				probe.blocks.append(extra)
			if unpassend:
				continue
			probe.blocks.append(block)
			probe.blocks = Skill.sortiert(probe.blocks)
			if probe.fehler().is_empty():
				typen.append(typ)
				break
	if typen.is_empty():
		typen = TYPEN.duplicate()  # keine Probe passt: nicht einschränken
	_typen_cache[schluessel] = typen
	return typen


## Kurztext zur Kerbe („nur Zauber“, „Zauber oder Körper“, „alle Quellen“).
static func typen_text(typen: Array[StringName]) -> String:
	if typen.size() >= TYPEN.size():
		return Loc.pick("alle Quellen", "any source")
	var namen: Array[String] = []
	for t in typen:
		match t:
			&"waffe": namen.append(Loc.pick("Waffe", "weapon"))
			&"zauber": namen.append(Loc.pick("Zauber", "spell"))
			&"koerper": namen.append(Loc.pick("Körper", "body"))
	if namen.size() == 1:
		return Loc.pick("nur %s", "%s only") % namen[0]
	return Loc.pick(" oder ", " or ").join(namen)


# --- Geometrie ------------------------------------------------------------------

## Höhe (Anteil) der Nase/Kerbe eines Typs: Waffe oben, Zauber Mitte, Körper unten.
const HOEHE := {&"waffe": 0.25, &"zauber": 0.5, &"koerper": 0.75}


## Nase eines Typs an der senkrechten Kante x = `kante` für ein Teil der
## Höhe `h`. `groesser` > 0 macht daraus eine Kerbe mit etwas Spiel.
static func _nase(typ: StringName, kante: float, h: float, groesser := 0.0) -> PackedVector2Array:
	var punkte := PackedVector2Array()
	var mitte: float = h * float(HOEHE.get(typ, 0.5))
	var halb := clampf(h * 0.1, 5.0, 10.0) + groesser
	var t := NASE + groesser
	match typ:
		&"waffe":
			punkte = PackedVector2Array([Vector2(kante - 2, mitte - halb), Vector2(kante + t - 1, mitte - halb),
				Vector2(kante + t - 1, mitte + halb), Vector2(kante - 2, mitte + halb)])
		&"zauber":
			punkte.append(Vector2(kante - 2, mitte + halb))
			for i in 13:
				var w := PI * 0.5 - PI * float(i) / 12.0
				punkte.append(Vector2(kante - 2 + cos(w) * (t - 1), mitte + sin(w) * halb))
			punkte.append(Vector2(kante - 2, mitte - halb))
		_:
			punkte = PackedVector2Array([Vector2(kante - 2, mitte - halb), Vector2(kante + t, mitte),
				Vector2(kante - 2, mitte + halb)])
	return punkte


static func _groesstes(teile: Array) -> PackedVector2Array:
	var bestes := PackedVector2Array()
	var flaeche := -1.0
	for teil in teile:
		var poly: PackedVector2Array = teil
		if Geometry2D.is_polygon_clockwise(poly) and teile.size() > 1:
			continue  # Loch
		var f := absf(_flaeche(poly))
		if f > flaeche:
			flaeche = f
			bestes = poly
	return bestes


static func _flaeche(poly: PackedVector2Array) -> float:
	var summe := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		summe += a.x * b.y - b.x * a.y
	return summe * 0.5


## Umriss eines Teils der Größe `groesse`: links eine Kerbe für `links`
## (leer = glatte Startkante), rechts eine Nase für `rechts` (leer = glatt;
## dann reicht der Körper bis zum Rand, sonst bis `groesse.x - NASE`).
static func umriss(groesse: Vector2, links: Array, rechts: Array) -> PackedVector2Array:
	var schluessel := "%d|%d|%s|%s" % [roundi(groesse.x), roundi(groesse.y), ",".join(links), ",".join(rechts)]
	if _form_cache.has(schluessel):
		return _form_cache[schluessel]
	var rechts_kante := groesse.x - (NASE if not rechts.is_empty() else 0.0)
	var koerper := PackedVector2Array([Vector2(0, 0), Vector2(rechts_kante, 0),
		Vector2(rechts_kante, groesse.y), Vector2(0, groesse.y)])
	for typ in links:
		koerper = _groesstes(Geometry2D.clip_polygons(koerper, _nase(typ, 0.0, groesse.y, SPIEL)))
	for typ in rechts:
		koerper = _groesstes(Geometry2D.merge_polygons(koerper, _nase(typ, rechts_kante, groesse.y)))
	_form_cache[schluessel] = koerper
	return koerper


## Zeichnet ein Teil auf `ci` (im eigenen _draw): Füllung, Rand, wahlweise
## gestrichelt (leerer Platz).
static func zeichnen(ci: CanvasItem, groesse: Vector2, links: Array, rechts: Array,
		fuellung: Color, rand: Color, gestrichelt := false, breite := 2.0) -> void:
	var poly := umriss(groesse, links, rechts)
	if poly.size() < 3:
		return
	if fuellung.a > 0.0:
		ci.draw_colored_polygon(poly, fuellung)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if gestrichelt:
			ci.draw_dashed_line(a, b, rand, breite, 5.0)
		else:
			ci.draw_line(a, b, rand, breite, true)
