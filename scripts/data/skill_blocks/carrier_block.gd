class_name CarrierBlock
extends SkillBlock
## Träger/Form-Baustein: bestimmt, wie der Skill ausgeliefert wird und
## damit das Targeting im rundenbasierten Kampf. Jeder Skill braucht genau einen.

@export var carrier: Enums.Carrier = Enums.Carrier.MELEE

## Kostenfaktor des Trägers: AoE/Summon sind teurer als Single-Target.
## Multipliziert die Summe der MP-Kosten aller anderen Bausteine.
@export var cost_multiplier: float = 1.0

## Schadensfaktor: AoE trifft alle, aber schwächer; Melee ggf. stärker.
@export var power_multiplier: float = 1.0
