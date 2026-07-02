class_name Combatant
extends RefCounted
## Ein Kampfteilnehmer zur Laufzeit (Spieler-Charakter oder Gegner).
## Leitet HP/MP linear aus dem StatBlock ab und verwaltet Statuseffekte.

const HP_BASE := 20
const HP_PER_VIT := 8
const MP_BASE := 10
const MP_PER_SPI := 5

var display_name := ""
var stats: StatBlock
var is_player := false

var max_hp := 1
var hp := 1
var max_mp := 0
var mp := 0

## Flache Schadensreduktion: armor gegen physisch, magic_resist gegen magisch.
## Elementarschaden (DoT) ignoriert beides — das ist die Nische dieser Achse.
var armor := 0
var magic_resist := 0

var skills: Array[Skill] = []

## Aktive Statuseffekte: {"status": Enums.Status, "turns": int, "potency": int}
var statuses: Array[Dictionary] = []


static func create(p_name: String, p_stats: StatBlock, p_is_player: bool) -> Combatant:
	var c := Combatant.new()
	c.display_name = p_name
	c.stats = p_stats
	c.is_player = p_is_player
	c.max_hp = HP_BASE + p_stats.vitality * HP_PER_VIT
	c.hp = c.max_hp
	c.max_mp = MP_BASE + p_stats.spirit * MP_PER_SPI
	c.mp = c.max_mp
	return c


func is_alive() -> bool:
	return hp > 0


## Tempo für die Zugreihenfolge; SLOW reduziert prozentual.
func effective_speed() -> int:
	var speed := stats.agility
	var slow := get_status(Enums.Status.SLOW)
	if not slow.is_empty():
		speed = roundi(speed * (1.0 - slow["potency"] / 100.0))
	return speed


## Nimmt Schaden, SHIELD absorbiert zuerst. Gibt den tatsächlich
## an den HP angekommenen Schaden zurück.
func take_damage(amount: int) -> int:
	var shield := get_status(Enums.Status.SHIELD)
	if not shield.is_empty():
		var absorbed: int = mini(amount, shield["potency"])
		shield["potency"] -= absorbed
		amount -= absorbed
		if shield["potency"] <= 0:
			statuses.erase(shield)
	hp = maxi(0, hp - amount)
	return amount


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)


func get_status(status: Enums.Status) -> Dictionary:
	for entry in statuses:
		if entry["status"] == status:
			return entry
	return {}


func has_status(status: Enums.Status) -> bool:
	return not get_status(status).is_empty()


## Gleicher Status stackt nicht: Dauer und Stärke werden auf das Maximum gesetzt.
func add_status(status: Enums.Status, turns: int, potency: int) -> void:
	var existing := get_status(status)
	if existing.is_empty():
		statuses.append({"status": status, "turns": turns, "potency": potency})
	else:
		existing["turns"] = maxi(existing["turns"], turns)
		existing["potency"] = maxi(existing["potency"], potency)
