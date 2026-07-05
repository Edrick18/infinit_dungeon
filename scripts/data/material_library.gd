class_name MaterialLibrary
extends RefCounted
## Crafting-Materialien: droppen von Gegnern und aus Truhen (statt Tränken)
## und werden beim Alchemisten zu Tränken verarbeitet.

## id » {"name": String, "weight": int (Drop-Gewicht)}
## Kräuter/Salze » Alchemist (Tränke); Erz/Leder/Kristall » Schmiede (Gear).
const MATERIALS := {
	&"heilkraut": {"name": "Heilkraut", "weight": 4},
	&"manabluete": {"name": "Manablüte", "weight": 3},
	&"reinigungssalz": {"name": "Reinigungssalz", "weight": 3},
	&"eisenerz": {"name": "Eisenerz", "weight": 3},
	&"lederreste": {"name": "Lederreste", "weight": 2},
	&"kristallstaub": {"name": "Kristallstaub", "weight": 1},
}


static func display_name(id: StringName) -> String:
	if MATERIALS.has(id):
		return MATERIALS[id]["name"]
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
