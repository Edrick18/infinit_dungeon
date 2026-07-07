class_name MaterialLibrary
extends RefCounted
## Crafting-Materialien: droppen von Gegnern und aus Truhen (statt Tränken)
## und werden beim Alchemisten zu Tränken verarbeitet.

## id » {"name": String, "weight": int (Drop-Gewicht)}
## Kräuter/Salze » Alchemist (Tränke); Erz/Leder/Kristall » Schmiede (Gear).
const MATERIALS := {
	&"heilkraut": {"name": "Heilkraut", "name_en": "Healing Herb", "weight": 4},
	&"manabluete": {"name": "Manablüte", "name_en": "Mana Blossom", "weight": 3},
	&"reinigungssalz": {"name": "Reinigungssalz", "name_en": "Purifying Salt", "weight": 3},
	&"eisenerz": {"name": "Eisenerz", "name_en": "Iron Ore", "weight": 3},
	&"lederreste": {"name": "Lederreste", "name_en": "Leather Scraps", "weight": 2},
	&"kristallstaub": {"name": "Kristallstaub", "name_en": "Crystal Dust", "weight": 1},
}


static func display_name(id: StringName) -> String:
	if MATERIALS.has(id):
		return Loc.pick(MATERIALS[id]["name"], MATERIALS[id]["name_en"])
	return str(id)


static func roll(rng: RandomNumberGenerator) -> StringName:
	var total := 0
	for id in MATERIALS:
		total += MATERIALS[id]["weight"]
	var pick := rng.randi_range(1, total)
	for id in MATERIALS:
		pick -= MATERIALS[id]["weight"]
		if pick <= 0:
			return id
	return MATERIALS.keys()[0]
