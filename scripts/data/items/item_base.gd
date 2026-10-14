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
@export var base_damage: int = 0  ## Physischer Waffenschaden (Waffennutzung)
@export var spell_damage: int = 0 ## Zauberschaden (Stäbe/Foki; Zauber-Quelle)
@export var base_armor: int = 0   ## Nur Rüstungsteile
@export var stat_bonus: StatBlock
## Schmuck: die Grund-Attribute wachsen linear mit dem Item-Level mit
## (sonst wäre ein gewöhnlicher Ring ohne Affix wertlos).
@export var stat_skaliert := false

## Nur Waffen: Schadensprofil — der Waffenschaden verteilt sich gleichmäßig
## auf diese Schadensarten (Schwert = Stich+Schnitt, Bogen = Stich, ...).
@export var weapon_subtypes: Array[Enums.PhysicalSubtype] = []

## Nur Waffen: Zweihänder blockieren den Nebenhand-Slot.
@export var two_handed := false

## Waffenart für die Schmiede (schwert/dolch/axt/stumpf/bogen/armbrust/stab).
@export var family: StringName = &""

## Leichte Waffen (Dolche): können zusätzlich in der Nebenhand geführt werden.
@export var light := false

## Fernkampf (Bogen/Armbrust): zweihändig, aber ein Köcher darf in die Nebenhand.
@export var ranged := false

## Köcher: Nebenhand-Ergänzung — der Schadensbonus zählt nur mit Fernkampfwaffe.
@export var quiver := false

## Treffer pro Waffennutzung (Bogen feuert 2 Pfeile).
@export var hit_count := 1

## Anteil der Rüstung, den diese Waffe ignoriert (Armbrust: 0.2).
@export var armor_pierce := 0.0

## Nur Rüstungsteile: bestimmt die Wirksamkeit gegen Stich/Schnitt/Stumpf.
@export var armor_class: Enums.ArmorClass = Enums.ArmorClass.NONE

## Ab welcher Kartenstufe dieses Basis-Item im Loot-Pool ist.
@export var min_tier: int = 1
