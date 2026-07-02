class_name ConsumableDef
extends Resource
## Ein Verbrauchsgegenstand (Trank, Elixier, ...). Consumables stacken —
## das Inventar hält nur Anzahlen pro ID (GameState.consumables).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var effect: Enums.ConsumableEffect = Enums.ConsumableEffect.HEAL_HP

## Wirkstärke — Bedeutung je nach Effekt: HP/MP-Menge oder %-Max-HP bei Revive.
@export var potency: int = 0

## Ab welcher Kartenstufe das Item droppen kann, und wie häufig (Gewicht).
@export var min_tier: int = 1
@export var drop_weight: int = 1
