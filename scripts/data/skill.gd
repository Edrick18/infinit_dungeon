class_name Skill
extends Resource
## Ein vom Spieler zusammengebauter Skill: genau ein Träger-Baustein plus
## beliebige Schadens-, Effekt- und Modifikator-Bausteine.
## Wird im Sockel-UI (Drag&Drop) zusammengesteckt und in einen der
## Skill-Slots des Charakters gelegt (+1 Slot alle 5 Level, kein Cap).

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


## Gültig, wenn: mindestens eine Quelle vorhanden, UND (falls eine Waffennutzung
## dabei ist) kein Form-Baustein (kein "Flächen-Schwertschwung").
func is_valid() -> bool:
	if get_sources().is_empty():
		return false
	if has_source(Enums.SkillSource.WEAPON) and get_form_block() != null:
		return false
	return true


## Anteil des Skalierungs-Stats, der in die MP-Kosten fließt: Skills werden mit
## den Stats stärker UND teurer — dadurch bleiben MP-Kosten auf jedem Level
## relevant (kein Level-Cap!).
const STAT_COST_SCALE := 0.25


## MP-Kosten: Summe aller Baustein-Kosten + dynamischer Stat-Anteil pro Quelle
## (WEAPON→STR, SPELL→INT), skaliert mit dem Kostenfaktor der Form, reduziert
## durch COST_REDUCTION-Modifikatoren.
func get_mp_cost(user: Combatant = null) -> int:
	if get_sources().is_empty():
		return 0
	var base := 0.0
	for block in blocks:
		base += block.mp_cost
		if user != null and block is SourceBlock:
			var stat_name := &"strength" if block.source == Enums.SkillSource.WEAPON else &"intelligence"
			base += user.stat(stat_name) * block.scaling_per_point * STAT_COST_SCALE
	var form_block := get_form_block()
	var cost := base * (form_block.cost_multiplier if form_block != null else 1.0)
	for mod in get_modifier_blocks():
		if mod.modifier == Enums.SkillModifier.COST_REDUCTION:
			cost *= 1.0 - mod.magnitude / 100.0
		elif mod.modifier == Enums.SkillModifier.OVERLOAD:
			cost *= 1.5  # Überladung: mehr Schaden, aber deutlich teurer
	# Skill-Affixe auf der Ausrüstung ("des Fokus" …) senken die Kosten flach.
	if user != null:
		cost -= user.mp_cost_reduction()
	return maxi(1, roundi(cost))


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
