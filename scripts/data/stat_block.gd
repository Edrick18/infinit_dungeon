class_name StatBlock
extends Resource
## Ein Satz der klassischen RPG-Attribute. Wird für Basiswerte, Level-Wachstum
## und Ausrüstungs-/Affix-Boni gleichermaßen verwendet.
##
## Balance-Philosophie: einfach linear — jeder Punkt gibt einen festen Bonus
## (siehe DESIGN.md Abschnitt 3). Die Umrechnung in abgeleitete Werte
## (HP, Schaden, ...) passiert im Kampfsystem, nicht hier.

@export var strength: int = 0      ## Physischer Schaden
@export var intelligence: int = 0  ## Magischer Schaden (raw)
@export var vitality: int = 0      ## Maximale HP
@export var spirit: int = 0        ## Maximale MP, Stärke von DoT/Heilung
@export var agility: int = 0       ## Zugreihenfolge, Ausweichen
@export var luck: int = 0          ## Kritische Treffer, Drop-Glück

const STAT_NAMES: Array[StringName] = [
	&"strength", &"intelligence", &"vitality", &"spirit", &"agility", &"luck",
]


func add(other: StatBlock) -> void:
	for stat in STAT_NAMES:
		set(stat, get(stat) + other.get(stat))


func add_scaled(other: StatBlock, factor: int) -> void:
	for stat in STAT_NAMES:
		set(stat, get(stat) + other.get(stat) * factor)


func duplicated() -> StatBlock:
	var copy := StatBlock.new()
	copy.add(self)
	return copy


func _to_string() -> String:
	var parts: Array[String] = []
	for stat in STAT_NAMES:
		var value: int = get(stat)
		if value != 0:
			parts.append("%s %+d" % [stat, value])
	return "[" + ", ".join(parts) + "]"
