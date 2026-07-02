class_name DamageBlock
extends SkillBlock
## Schadens-Baustein: eine der drei unabhängigen Schadensachsen.
## Ein Skill kann mehrere DamageBlocks kombinieren (z.B. physisch + elementar
## = Schwerthieb, der zusätzlich Brand verursacht).

@export var axis: Enums.DamageAxis = Enums.DamageAxis.PHYSICAL

## Grundschaden, bevor Stats einfließen.
@export var base_amount: int = 10

## Welches Attribut skaliert diesen Schaden und wie stark pro Punkt (linear).
@export var scaling_stat: StringName = &"strength"
@export var scaling_per_point: float = 1.0

## Nur für die elementare Achse relevant:
@export var element: Enums.Element = Enums.Element.NONE
@export var dot_turns: int = 0  ## Über wie viele Runden der Schaden tickt (0 = sofort)
