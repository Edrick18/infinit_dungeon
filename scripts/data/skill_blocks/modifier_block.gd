class_name ModifierBlock
extends SkillBlock
## Verstärker/Modifikator-Baustein: verändert, wie die anderen Bausteine
## eines Skills wirken (Mehrfachtreffer, Kostenreduktion, Kettenreaktion, ...).

@export var modifier: Enums.SkillModifier = Enums.SkillModifier.POWER_AMP

## Bedeutung hängt vom Modifikator-Typ ab:
## MULTI_HIT: Anzahl Extra-Treffer · COST_REDUCTION/POWER_AMP: Prozent
## SPREAD: Prozent des Schadens auf Nachbarn · CHAIN_ON_KILL: max. Sprünge
@export var magnitude: int = 0
