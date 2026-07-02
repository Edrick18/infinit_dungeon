extends SceneTree
## Headless-Selbsttest für Loot-Generierung und Ausrüstungs-Wirkung:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/loot_selftest.gd

var failures := 0


func _init() -> void:
	_test_item_generation()
	_test_tier_gating()
	_test_equipment_effects()
	_test_battle_loot()
	if failures == 0:
		print("SELFTEST OK — alle Loot-Tests bestanden")
		quit(0)
	else:
		print("SELFTEST FEHLGESCHLAGEN — %d Fehler" % failures)
		quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("  ok: " + label)
	else:
		failures += 1
		printerr("  FEHLER: " + label)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _test_item_generation() -> void:
	print("Item-Generierung:")
	var a := LootGenerator.roll_item(3, _rng(42))
	var b := LootGenerator.roll_item(3, _rng(42))
	_check(a.get_display_name() == b.get_display_name() and a.rarity == b.rarity,
		"gleicher RNG-Seed → gleiches Item")

	var counts_ok := true
	var name_ok := true
	var rarities := {}
	for i in 300:
		var item := LootGenerator.roll_item(3, _rng(i))
		rarities[item.rarity] = true
		if item.affixes.size() != LootGenerator.AFFIX_COUNT[item.rarity]:
			counts_ok = false
		if item.base.display_name not in item.get_display_name():
			name_ok = false
	_check(counts_ok, "Affix-Anzahl passt immer zur Rarity (0/1/2/3/4)")
	_check(name_ok, "Basisname steckt immer im Item-Namen")
	_check(rarities.size() >= 4, "über 300 Rolls kommen ≥4 Raritäten vor (%d)" % rarities.size())


func _test_tier_gating() -> void:
	print("Tier-Begrenzung:")
	var ok := true
	for i in 200:
		var item := LootGenerator.roll_item(1, _rng(i))
		if item.base.min_tier > 1:
			ok = false
		for affix in item.affixes:
			if affix.tier > 1:
				ok = false
	_check(ok, "Tier-1-Drops enthalten keine höherstufigen Basen/Affixe")
	_check(ItemLibrary.bases_for_tier(4).size() > ItemLibrary.bases_for_tier(1).size(),
		"höhere Stufen schalten mehr Basis-Items frei")


func _test_equipment_effects() -> void:
	print("Ausrüstung wirkt im Kampf:")
	var stats := StatBlock.new()
	stats.strength = 5
	stats.vitality = 5
	var hero := Combatant.create("Held", stats, true)

	var sword := ItemInstance.new()
	sword.base = ItemLibrary.bases_for_tier(1)[0]  # Kurzschwert, +6 Schaden
	var vit_affix: Affix = null
	for affix in ItemLibrary.affixes_for_tier(1, false):
		if affix.id == &"vitalitaet":
			vit_affix = affix
	sword.affixes = [vit_affix]

	var hp_before := hero.max_hp
	var replaced := hero.equip(sword)
	_check(replaced.is_empty(), "Slot war leer → nichts ersetzt")
	_check(hero.weapon_damage() == 6, "Waffenschaden +6 vom Kurzschwert")
	_check(hero.max_hp == hp_before + 3 * Combatant.HP_PER_VIT,
		"'der Vitalität' erhöht Max-HP (+3 VIT)")

	# Basisangriff nutzt Waffe: 5 Basis + 5 STR + 6 Waffe = 16
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 1
	var dummy := Combatant.create("Ziel", StatBlock.new(), false)
	battle.start([hero], [dummy])
	var target_hp := dummy.hp
	battle.basic_attack(hero, dummy)
	_check(target_hp - dummy.hp == 16, "Basisangriff: 5 + 5 STR + 6 Waffe = 16")

	# Ringe: zweiter Ring wandert in Slot 2.
	var ring_base: ItemBase = null
	for base in ItemLibrary.bases_for_tier(1):
		if base.slot == Enums.EquipSlot.RING_1:
			ring_base = base
	var ring1 := ItemInstance.new()
	ring1.base = ring_base
	var ring2 := ItemInstance.new()
	ring2.base = ring_base
	hero.equip(ring1)
	var replaced_ring := hero.equip(ring2)
	_check(replaced_ring.is_empty() and hero.equipment.has(Enums.EquipSlot.RING_2),
		"zweiter Ring belegt Ring-Slot 2 statt zu ersetzen")

	var removed := hero.unequip(Enums.EquipSlot.WEAPON)
	_check(removed == sword and hero.weapon_damage() == 0, "Ablegen entfernt Waffenbonus")


func _test_battle_loot() -> void:
	print("Kampf-Beute:")
	var stats := StatBlock.new()
	var normal := Combatant.create("Gegner", stats, false)
	var elite := Combatant.create("Elite", stats, false)
	elite.loot_mult = 1.5

	var loot := LootGenerator.roll_battle_loot([normal, elite], 2, false, _rng(1))
	_check(loot["gold"] > 0, "Kills geben Gold")

	var boss_loot := LootGenerator.roll_battle_loot([normal], 2, true, _rng(1))
	_check(boss_loot["items"].size() >= LootGenerator.BOSS_ITEM_COUNT,
		"Boss droppt garantiert %d+ Items" % LootGenerator.BOSS_ITEM_COUNT)
	_check(boss_loot["materials"].size() >= 2, "Boss droppt garantiert Materialien")

	var material_found := false
	var potion_free := true
	for i in 40:
		var roll := LootGenerator.roll_battle_loot([normal, elite], 1, false, _rng(i))
		if not roll["materials"].is_empty():
			material_found = true
		if roll.has("consumables"):
			potion_free = false
	_check(material_found, "Materialien droppen aus normalen Kämpfen")
	_check(potion_free, "Tränke droppen NICHT mehr von Gegnern")

	var item := LootGenerator.roll_item(2, _rng(5))
	_check(LootGenerator.sell_price(item) > 0, "Verkaufspreis ist positiv")