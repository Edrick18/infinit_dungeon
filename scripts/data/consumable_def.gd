class_name ConsumableDef
extends Resource
## Ein Verbrauchsgegenstand (Trank, Elixier, ...). Consumables stacken —
## das Inventar hält nur Anzahlen pro ID (GameState.consumables).
## Tränke droppen NICHT von Gegnern: einfache sind beim Händler kaufbar,
## alle sind aus Materialien craftbar (Design-Entscheidung 2026-07-02).

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var effect: Enums.ConsumableEffect = Enums.ConsumableEffect.HEAL_HP

## Flat-Wirkung (HP/MP-Menge; bei Revive: % Max-HP).
@export var potency: int = 0

## Prozentuale Wirkung relativ zum Max-Wert des Ziels. Es gilt immer der
## höhere von beiden Werten — so bleiben Tränke auch auf Level 100 relevant.
@export var potency_percent: int = 0

## Welche Statuseffekte dieser Trank entfernt (nur CURE_AILMENTS).
@export var cures: Array[Enums.Status] = []

## Kaufpreis beim Händler in Gold. 0 = nicht kaufbar (nur craftbar).
@export var price: int = 0

## Craft-Rezept: Material-ID » Anzahl.
@export var craft_materials: Dictionary = {}

## Craft-Rezept-Anteil aus anderen Tränken: Consumable-ID » Anzahl
## (z.B. Allheilmittel = 1× jeder Status-Trank).
@export var craft_consumables: Dictionary = {}


func heal_amount(target: Combatant) -> int:
	return maxi(potency, roundi(target.max_hp * potency_percent / 100.0))


func mana_amount(target: Combatant) -> int:
	return maxi(potency, roundi(target.max_mp * potency_percent / 100.0))


func is_craftable() -> bool:
	return not craft_materials.is_empty() or not craft_consumables.is_empty()
