class_name ElementBlock
extends SkillBlock
## Element-Baustein (Phase-3-Rework): gibt einem Zauber seine Elementart und
## damit den Signature-Status. Ohne Element-Baustein macht ein Zauber rohen
## Magieschaden. Sinnvoll nur zusammen mit einer SPELL-Quelle.

@export var element: Enums.Element = Enums.Element.FIRE

## Wie viele Runden ein DoT-Element (Brand/Gift) grundsätzlich tickt.
## (Das genaue Stack-Verhalten regelt das Kampfsystem je Element.)
@export var dot_turns: int = 3

## Anteil des Zauberschadens, der in die Status-Stärke/Stacks fließt.
@export var status_scale: float = 1.0
