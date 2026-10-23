class_name Anschleichen
extends RefCounted
## Sicht- und Rücken-Geometrie im Dungeon (reine Funktionen, headless
## testbar): Wer bemerkt wen, und wer zeigt beim Kontakt wem den Rücken?

## Entdecken mit Sichtfeld: ruhende Gegner bemerken den Spieler nur VOR sich
## (dot(Blick, Richtung Spieler) über SICHT_KEGEL ≈ ±110°) oder ganz nah
## (Hörradius). Wer sich von hinten anschleicht, bleibt unbemerkt.
## Jagende Gegner verfolgen weiter rundum.
const SICHT_KEGEL := -0.35
const HOER_RADIUS := 44.0
## Erstschlag/Hinterhalt bei Kontakt: zeigt der Rücken weg (dot < -RUECKEN).
const RUECKEN := 0.3


## Bemerkt ein ruhender Gegner (enemy: {"kurs"}) den Spieler?
static func bemerkt(player_pos: Vector2, enemy: Dictionary, enemy_pos: Vector2, distance: float) -> bool:
	if distance < HOER_RADIUS:
		return true
	var kurs: Vector2 = enemy.get("kurs", Vector2.ZERO)
	if kurs == Vector2.ZERO:
		return true
	return kurs.dot((player_pos - enemy_pos).normalized()) > SICHT_KEGEL


## Überraschung beim Kontakt: Gegner schaut weg » Erstschlag der Party; ein
## jagender Gegner erwischt den Helden von hinten (Held läuft weg) » Hinterhalt.
static func ueberraschung(player_pos: Vector2, blick: Vector2, enemy: Dictionary) -> int:
	var zum_spieler: Vector2 = (player_pos - enemy["pos"]).normalized()
	var kurs: Vector2 = enemy.get("kurs", Vector2.ZERO)
	# Ein jagender Gegner hat den Helden bemerkt — auch wenn er sich noch
	# umdreht (Kurs folgt träge), ist das kein Erstschlag (Spieltest 2026-10-24).
	if not enemy.get("jagd", false) and kurs != Vector2.ZERO and kurs.dot(zum_spieler) < -RUECKEN:
		return Battle.ERSTSCHLAG
	if enemy.get("jagd", false) and blick.dot(-zum_spieler) < -RUECKEN:
		return Battle.HINTERHALT
	return Battle.KEINE_UEBERRASCHUNG
