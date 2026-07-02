class_name ItemBase
extends Resource
## Handdefiniertes Basis-Item (z.B. "Kurzschwert", "Lederharnisch").
## Aus einem ItemBase plus zufälligen Affixen generiert das Loot-System
## eine konkrete ItemInstance.

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var slot: Enums.EquipSlot = Enums.EquipSlot.WEAPON

## Grundwerte vor Affixen.
@export var base_damage: int = 0  ## Nur Waffen
@export var base_armor: int = 0   ## Nur Rüstungsteile
@export var stat_bonus: StatBlock

## Ab welcher Kartenstufe dieses Basis-Item im Loot-Pool ist.
@export var min_tier: int = 1
