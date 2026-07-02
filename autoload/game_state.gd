extends Node
## Autoload "GameState": persistenter Spielzustand über Szenenwechsel hinweg —
## Party, Gold, erforschte Bausteine. Später kommt hier das Speichersystem dran.

var gold := 150
var researched: Array[StringName] = []
var party: Array[Combatant] = []

## Laufender Dungeon-Besuch: {"card": DungeonCard, "defeated": Array[int],
## "opened": Array[int], "player_pos": Vector2, "boss_defeated": bool}.
## Leer = kein aktiver Run. Nur die Karte + Fortschritt werden gehalten,
## das Layout selbst kommt deterministisch aus dem Karten-Seed.
var current_run: Dictionary = {}

## Übergabe an die Kampfszene: {"enemy_id": int, "is_boss": bool,
## "enemies": Array[Combatant]}. Leer = normaler Testkampf aus dem Menü.
var pending_battle: Dictionary = {}


func _ready() -> void:
	if party.is_empty():
		party = TestContent.make_party()


func start_run(card: DungeonCard) -> void:
	current_run = {
		"card": card,
		"defeated": [],
		"opened": [],
		"player_pos": Vector2.ZERO,
		"boss_defeated": false,
	}


func clear_run() -> void:
	current_run = {}
	pending_battle = {}


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
