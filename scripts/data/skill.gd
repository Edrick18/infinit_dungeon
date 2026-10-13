class_name Skill
extends Resource
## Ein vom Spieler zusammengebauter Skill aus Bausteinen ("Klötzen"):
## mindestens eine Quelle plus Element, Form, Effekte und Verstärker nach den
## Bauregeln von fehler(). Wird in der Werkstatt in die Sockel gesteckt
## (Sockelzahl nach Level, Combatant.block_sockets) und in einen der
## Skill-Slots gelegt (+1 Slot alle 5 Level, kein Cap).

@export var display_name: String = "Neuer Skill"
@export var blocks: Array[SkillBlock] = []


func get_sources() -> Array[SourceBlock]:
	var result: Array[SourceBlock] = []
	for block in blocks:
		if block is SourceBlock:
			result.append(block)
	return result


func has_source(source: Enums.SkillSource) -> bool:
	for block in blocks:
		if block is SourceBlock and block.source == source:
			return true
	return false


func get_element() -> ElementBlock:
	for block in blocks:
		if block is ElementBlock:
			return block
	return null


## Form-Baustein oder null (= Einzelziel-Standard).
func get_form_block() -> FormBlock:
	for block in blocks:
		if block is FormBlock:
			return block
	return null


## Effektive Form: SINGLE, wenn kein Form-Baustein da ist.
func get_form() -> Enums.SkillForm:
	var fb := get_form_block()
	return fb.form if fb != null else Enums.SkillForm.SINGLE


func get_effect_blocks() -> Array[EffectBlock]:
	var result: Array[EffectBlock] = []
	for block in blocks:
		if block is EffectBlock:
			result.append(block)
	return result


func get_modifier_blocks() -> Array[ModifierBlock]:
	var result: Array[ModifierBlock] = []
	for block in blocks:
		if block is ModifierBlock:
			result.append(block)
	return result


## Gültig = keine Bauregel verletzt (siehe fehler()). Mit `user` zählt auch
## die Sockelzahl des Helden.
func is_valid(user: Combatant = null) -> bool:
	return fehler(user).is_empty()


## Anzeigenamen der automatischen Gruppen (Variantengruppen: Klotzname).
const GRUPPEN_NAMEN := {
	&"quelle_waffe": ["Waffennutzung", "weapon use"], &"quelle_zauber": ["Zauber", "spell"],
	&"form": ["Form", "form"], &"element": ["Element", "element"],
}


## Gruppe eines Klotzes: Quelle je Art, Form, Element — sonst die
## Variantengruppe aus der Bibliothek (leer = keine Gruppe).
static func gruppe_von(block: SkillBlock) -> StringName:
	if block is SourceBlock:
		return &"quelle_waffe" if block.source == Enums.SkillSource.WEAPON else &"quelle_zauber"
	if block is FormBlock:
		return &"form"
	if block is ElementBlock:
		return &"element"
	return block.gruppe


## Erster Bauregel-Verstoß als lesbarer Grund — leer = einsatzbereit.
## Regeln (Baukasten 2.0): mind. eine Quelle · Waffennutzung ohne Form ·
## kein Klotz doppelt · je Gruppe nur einer (Waffen-/Zauberquelle, Form,
## Element, Varianten wie Verstärken I/II) · höchstens ein Kern-Klotz ·
## Techniken nur einer Waffengattung · Helden: nicht mehr Klötze als Sockel.
func fehler(user: Combatant = null) -> String:
	if get_sources().is_empty():
		return Loc.pick("Braucht eine Quelle (Waffennutzung oder Zauber)",
			"Needs a source (weapon use or spell)")
	if has_source(Enums.SkillSource.WEAPON) and get_form_block() != null:
		return Loc.pick("Waffennutzung erlaubt keine Form (Fläche/Aura/…) — dafür einen Zauber nehmen",
			"Weapon use allows no form (area/aura/…) — use a spell for that")
	var gesehen: Array[SkillBlock] = []
	var gruppen := {}
	var kern: SkillBlock = null
	for block in blocks:
		for frueher in gesehen:
			if frueher == block or (block.id != &"" and frueher.id == block.id):
				return Loc.pick("%s ist doppelt — jeder Klotz nur einmal pro Skill",
					"%s appears twice — each block only once per skill") % block.display_name
		gesehen.append(block)
		var gruppe := gruppe_von(block)
		if gruppe != &"":
			if gruppen.has(gruppe):
				return Loc.pick("Nur ein Klotz der Gruppe \"%s\" (%s + %s)",
					"Only one block of group \"%s\" (%s + %s)") \
					% [gruppen_name(gruppe, block), gruppen[gruppe].display_name, block.display_name]
			gruppen[gruppe] = block
		if block.kern:
			if kern != null:
				return Loc.pick("Nur ein Kern-Klotz pro Skill (%s + %s)",
					"Only one core block per skill (%s + %s)") % [kern.display_name, block.display_name]
			kern = block
	if has_technique() and required_weapon_families().is_empty():
		# Widersprüchliche Techniken (Schwert + Bogen) haben keine gemeinsame
		# Gattung — der Skill wäre nie einsetzbar.
		return Loc.pick("Techniken verschiedener Waffen passen nicht zusammen",
			"Techniques of different weapons don't fit together")
	if user != null and user.is_player and not user.is_summon \
			and blocks.size() > user.block_sockets():
		return Loc.pick("Zu viele Klötze: %d von %d Sockeln (mehr Sockel mit höherem Level)",
			"Too many blocks: %d of %d sockets (more sockets at higher level)") \
			% [blocks.size(), user.block_sockets()]
	return ""


static func gruppen_name(gruppe: StringName, beispiel: SkillBlock) -> String:
	if GRUPPEN_NAMEN.has(gruppe):
		return Loc.pick(GRUPPEN_NAMEN[gruppe][0], GRUPPEN_NAMEN[gruppe][1])
	# Variantengruppe: Name ohne Stufen-Ziffer ("Verstärken II" » "Verstärken").
	var name := beispiel.display_name
	for stufe in [" III", " II", " I"]:
		if name.ends_with(stufe):
			return name.left(name.length() - stufe.length())
	return name


## Enthält der Skill mindestens eine Waffentechnik (gattungs-gebunden)?
func has_technique() -> bool:
	for block in blocks:
		if not block.weapon_families.is_empty():
			return true
	return false


## Schnittmenge der Gattungen aller Technik-Bausteine — mit einer Waffe
## aus dieser Liste ist der Skill einsetzbar. Leer + has_technique() =
## widersprüchlich (ungültig).
func required_weapon_families() -> Array[StringName]:
	var required: Array[StringName] = []
	var found := false
	for block in blocks:
		if block.weapon_families.is_empty():
			continue
		if not found:
			required = block.weapon_families.duplicate()
			found = true
			continue
		var merged: Array[StringName] = []
		for family in required:
			if family in block.weapon_families:
				merged.append(family)
		required = merged
	return required


## Kann `user` den Skill mit der GEFÜHRTEN Ausrüstung einsetzen? (Techniken
## verlangen die passende Gattung — Schild zählt über die Nebenhand.)
## Gegner tragen keine Items: ihre Techniken sind angeboren.
func usable_with_weapon(user: Combatant) -> bool:
	if not has_technique():
		return true
	if user == null:
		return false
	if not user.is_player:
		return true
	for family in required_weapon_families():
		if user.wields_family(family):
			return true
	return false


## Anteil des Skalierungs-Stats, der in die MP-Kosten fließt: Skills werden mit
## den Stats stärker UND teurer — dadurch bleiben MP-Kosten auf jedem Level
## relevant (kein Level-Cap!). Waffenskills zahlen weniger als Zauber: Zauber
## haben dafür Formen, Heilung, Support und die volle Element-Signatur.
const STAT_COST_SCALE := 0.25
const STAT_COST_SCALE_WAFFE := 0.15


## MP-Kosten (Baukasten 2.0):
##   Basis  = Σ Klotz-Grundkosten + Stat-Anteil je Quelle (STR 15 % / INT 25 %)
##   Kosten = Basis × Form-Faktor × Π Kostenfaktoren der Klötze
## Verstärker MULTIPLIZIEREN (PoE-Prinzip) — Effekte addieren flach.
## Danach Stab-Training (−%) und Ausrüstungs-Affixe (−flach).
func get_mp_cost(user: Combatant = null) -> int:
	if get_sources().is_empty():
		return 0
	var base := 0.0
	for block in blocks:
		base += block.mp_cost
		if user != null and block is SourceBlock:
			var waffe: bool = block.source == Enums.SkillSource.WEAPON
			base += user.stat(&"strength" if waffe else &"intelligence") * block.scaling_per_point \
				* (STAT_COST_SCALE_WAFFE if waffe else STAT_COST_SCALE)
	var form_block := get_form_block()
	var cost := base * (form_block.cost_multiplier if form_block != null else 1.0)
	cost *= kosten_faktor()
	if user != null:
		cost *= 1.0 - user.training_mp_percent() / 100.0
		cost -= user.mp_cost_reduction()
	return maxi(1, roundi(cost))


## Produkt aller Kostenfaktoren (Verstärker, Effizienz, Überladung).
func kosten_faktor() -> float:
	var faktor := 1.0
	for block in blocks:
		faktor *= block.kosten_faktor
		if block is ModifierBlock:
			if block.modifier == Enums.SkillModifier.COST_REDUCTION:
				faktor *= 1.0 - block.magnitude / 100.0
			elif block.modifier == Enums.SkillModifier.OVERLOAD and block.kosten_faktor == 1.0:
				faktor *= 1.5  # Überladung ohne eigenen Faktor (Altbestand/Tests)
	return faktor


## Bausteine sind kanonische, geteilte Objekte aus der BlockLibrary (jeder
## mit eindeutiger ID) — für den Spielstand reicht es, ihre IDs zu speichern.
func to_dict() -> Dictionary:
	var block_ids: Array = []
	for block in blocks:
		block_ids.append(String(block.id))
	return {"name": display_name, "block_ids": block_ids}


static func from_dict(data: Dictionary) -> Skill:
	var skill := Skill.new()
	skill.display_name = data.get("name", "")
	for id_str in data.get("block_ids", []):
		var block := BlockLibrary.get_block(StringName(id_str))
		if block != null:
			skill.blocks.append(block)
	return skill
