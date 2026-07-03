class_name SourceBlock
extends SkillBlock
## Quell-Baustein (Phase-3-Rework): bestimmt, WOHER der Schaden kommt.
## Der Betrag kommt aus der ausgerüsteten Waffe, nicht aus dem Baustein.
##   WEAPON — physischer Angriff: Schaden + Schadensart von der Waffe.
##            Zielform ist fest durch die Waffe (Nahkampf/Fernkampf).
##   SPELL  — Zauber: Zauberschaden der Waffe + INT. Standard Einzelziel-Projektil;
##            per Form-Baustein umstellbar. Elementart aus Element-Baustein.

@export var source: Enums.SkillSource = Enums.SkillSource.WEAPON

## Anteil des skalierenden Attributs (WEAPON→STR, SPELL→INT), der zum
## Waffen-/Zauberschaden addiert wird.
@export var scaling_per_point: float = 1.0

## Multipliziert den Gesamtschaden dieser Quelle.
@export var power_multiplier: float = 1.0
