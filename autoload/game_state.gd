extends Node
## Autoload "GameState": persistenter Spielzustand über Szenenwechsel hinweg —
## Party, Gold, erforschte Bausteine. Später kommt hier das Speichersystem dran.

var gold := 150
var researched: Array[StringName] = []
var party: Array[Combatant] = []


func _ready() -> void:
	if party.is_empty():
		party = TestContent.make_party()


func is_block_unlocked(block: SkillBlock, char_level: int) -> bool:
	return BlockLibrary.is_unlocked(block, char_level, researched)


func can_research(block: SkillBlock) -> bool:
	return block.unlock_kind == Enums.UnlockKind.RESEARCH \
		and block.id not in researched \
		and gold >= block.research_cost_gold


func research(block: SkillBlock) -> bool:
	if not can_research(block):
		return false
	gold -= block.research_cost_gold
	researched.append(block.id)
	return true
