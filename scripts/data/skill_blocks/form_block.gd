class_name FormBlock
extends SkillBlock
## Form-Baustein (Phase-3-Rework): ändert Targeting/Reichweite eines Zaubers.
## Nur bei SPELL-Quelle erlaubt (eine Waffennutzung ist immer Einzelziel).
## Ohne Form-Baustein ist ein Zauber Einzelziel-Projektil.

@export var form: Enums.SkillForm = Enums.SkillForm.AOE

## Kostenfaktor: Fläche/Aura sind teurer als Einzelziel.
@export var cost_multiplier: float = 1.0

## Schadensfaktor: Fläche trifft alle, aber schwächer pro Ziel.
@export var power_multiplier: float = 1.0
