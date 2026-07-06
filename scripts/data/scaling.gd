class_name Scaling
extends RefCounted
## EINE zentrale Wachstumskurve für die ganze Welt (Design: „alles wächst
## exponentiell“): Gegner (HP/Schaden/Rüstung), Item-Werte und Gold-Beute
## werden alle mit DEMSELBEN Faktor pro Stufe multipliziert — obendrauf auf
## ihre bisherigen linearen Kurven. Weil beide Seiten (Held über Gear,
## Welt über Gegner) exakt gleich wachsen, bleibt die Balance auf jeder
## Stufe erhalten; nur die Zahlen werden größer (DQ-„Big Numbers“) und
## zusammen mit der quadratischen XP-Kurve entsteht das Soft-Cap:
## Fortschritt braucht bessere Karten, nicht nur mehr Zeit.
##
## +3% pro Stufe: ×1,3 auf Stufe 10 · ×2,4 auf 30 · ×4,3 auf 50 · ×18,7 auf 100.

const GROWTH_PER_LEVEL := 1.03


static func factor(level: int) -> float:
	return pow(GROWTH_PER_LEVEL, maxi(1, level) - 1)
