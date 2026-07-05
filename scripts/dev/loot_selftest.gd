extends SceneTree
## Headless-Selbsttest für Loot-Generierung und Ausrüstungs-Wirkung:
##   godot\Godot_v4.7-stable_win64_console.exe --headless -s scripts/dev/loot_selftest.gd

var failures := 0


func _init() -> void:
	_test_item_generation()
	_test_tier_gating()
	_test_equipment_effects()
	_test_battle_loot()
	_test_element_affixes()
	_test_skill_affixes()
	_test_affix_rolls_and_rarities()
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
		"gleicher RNG-Seed » gleiches Item")

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
	sword.base = ItemLibrary.bases_for_tier(1)[0]  # Schwert, +8 Schaden
	var vit_affix: Affix = null
	for affix in ItemLibrary.affixes_for_tier(1, false):
		if affix.id == &"vitalitaet":
			vit_affix = affix
	sword.affixes = [vit_affix]

	var hp_before := hero.max_hp
	var replaced := hero.equip(sword)
	_check(replaced.is_empty(), "Slot war leer » nichts ersetzt")
	_check(hero.weapon_damage() == 8, "Waffenschaden +8 vom Schwert")
	_check(hero.max_hp == hp_before + 3 * Combatant.HP_PER_VIT,
		"'der Vitalität' erhöht Max-HP (+3 VIT)")

	# Basisangriff nutzt Waffe: 5 Basis + 5 STR + 8 Waffe = 18
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 1
	var dummy := Combatant.create("Ziel", StatBlock.new(), false)
	battle.start([hero], [dummy])
	var target_hp := dummy.hp
	battle.basic_attack(hero, dummy)
	_check(target_hp - dummy.hp == 18, "Basisangriff: 5 + 5 STR + 8 Waffe = 18")

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


func _item_with_affix(base_id: StringName, affix_id: StringName,
		item_level := 1) -> ItemInstance:
	var item := ItemLibrary.make_item(base_id, item_level)
	item.affixes = [ItemLibrary.get_affix(affix_id)] as Array[Affix]
	return item


func _test_element_affixes() -> void:
	print("Element-Affixe (Rider + Resistenzen):")
	# Slot-Bindung: Rider landen nie auf Rüstung, Resistenzen nie auf Waffen.
	var slots_ok := true
	for i in 400:
		var item := LootGenerator.roll_item(10, _rng(i))
		for affix in item.affixes:
			if affix.element_damage > 0 and item.base.slot != Enums.EquipSlot.WEAPON:
				slots_ok = false
			if affix.element_resist > 0 and item.base.slot == Enums.EquipSlot.WEAPON:
				slots_ok = false
	_check(slots_ok, "Slot-Bindung: Rider nur auf Waffen, Resistenzen nie auf Waffen")

	# Rider: Waffennutzung trägt Elementschaden mit voller Signatur (Brand-Stacks).
	var stats := StatBlock.new()
	stats.strength = 5
	var hero := Combatant.create("Held", stats, true)
	hero.equip(_item_with_affix(&"schwert", &"lodernd"))
	_check(hero.element_riders().get(Enums.Element.FIRE, 0) == 4,
		"'Loderndes' Schwert: +4 Feuer-Rider")
	var battle := Battle.new()
	battle.crit_enabled = false
	battle.rng.seed = 1
	var dummy := Combatant.create("Ziel", StatBlock.new(), false)
	dummy.max_hp = 500
	dummy.hp = 500
	battle.start([hero], [dummy])
	var weapon_skill := Skill.new()
	weapon_skill.blocks.append(BlockLibrary.get_block(&"src_weapon"))
	hero.skills = [weapon_skill]
	hero.mp = 99
	battle.use_skill(hero, weapon_skill, dummy)
	_check(dummy.has_status(Enums.Status.BURN),
		"Feuer-Rider baut Brand-Stacks über Waffennutzung auf")

	# Resistenz: senkt Elementschaden und damit auch die aufgebauten Stacks.
	var resist_hero := Combatant.create("Verteidiger", StatBlock.new(), true)
	resist_hero.equip(_item_with_affix(&"ruestung_leicht", &"feuerabwehr"))
	_check(resist_hero.element_resist(Enums.Element.FIRE) == 4,
		"'der Feuerabwehr': +4 Feuer-Resistenz")
	_check(resist_hero.element_resist(Enums.Element.ICE) == 0,
		"Feuer-Resistenz wirkt nicht gegen Eis")
	var banish_hero := Combatant.create("Bannträger", StatBlock.new(), true)
	banish_hero.equip(_item_with_affix(&"ruestung_leicht", &"bannung"))
	_check(banish_hero.element_resist(Enums.Element.DARK) == 3
		and banish_hero.element_resist(Enums.Element.FIRE) == 3,
		"'der Bannung' wirkt gegen alle Elemente")

	var naked := Combatant.create("Nackt", StatBlock.new(), true)
	var fire_block: ElementBlock = BlockLibrary.element_block(Enums.Element.FIRE)
	var battle2 := Battle.new()
	battle2.crit_enabled = false
	battle2.rng.seed = 1
	battle2.start([hero], [naked, resist_hero])
	battle2._apply_elemental_hit(hero, naked, 10.0, fire_block)
	battle2._apply_elemental_hit(hero, resist_hero, 10.0, fire_block)
	var naked_stacks: int = naked.get_status(Enums.Status.BURN)["potency"]
	var resist_stacks: int = resist_hero.get_status(Enums.Status.BURN)["potency"]
	_check(resist_stacks < naked_stacks,
		"Resistenz senkt Brand-Stacks (%d < %d)" % [resist_stacks, naked_stacks])

	# Zauberkraft skaliert jetzt mit dem Item-Level (Caster-Endgame-Fix).
	var staff_low := ItemLibrary.make_item(&"offensivstab", 1)
	var staff_high := ItemLibrary.make_item(&"offensivstab", 12)
	_check(staff_high.get_total_spell_damage() > staff_low.get_total_spell_damage(),
		"Zauberkraft skaliert mit Item-Level (%d > %d)"
		% [staff_high.get_total_spell_damage(), staff_low.get_total_spell_damage()])
	var arcane_staff := _item_with_affix(&"offensivstab", &"arkan")
	_check(arcane_staff.get_total_spell_damage() == 12,
		"'Arkanes': +3 Zauberkraft (9 + 3)")


func _test_skill_affixes() -> void:
	print("Skill-Affixe (MP-Kosten):")
	var stats := StatBlock.new()
	stats.intelligence = 5
	var mage := Combatant.create("Magier", stats, true)
	var spell := Skill.new()
	spell.blocks.append(BlockLibrary.get_block(&"src_spell"))
	var cost_before := spell.get_mp_cost(mage)
	mage.equip(_item_with_affix(&"ring", &"fokus"))
	_check(mage.mp_cost_reduction() == 2, "'des Fokus': -2 MP-Kosten")
	_check(spell.get_mp_cost(mage) == maxi(1, cost_before - 2),
		"MP-Kosten sinken um die Reduktion (%d » %d)" % [cost_before, spell.get_mp_cost(mage)])

func _test_affix_rolls_and_rarities() -> void:
	print("Affix-Qualität (Wertstreuung) und Affix-Raritäten:")
	# Qualitäts-Roll: "+5 Schaden" (der Verwüstung) wird zu +5 bis +8.
	var seen_values := {}
	var in_band := true
	for i in 80:
		var item := ItemLibrary.make_item(&"schwert", 1)
		item.affixes = [ItemLibrary.get_affix(&"verwuestung")] as Array[Affix]
		var roll_rng := _rng(i)
		var rolls: Array[float] = [snappedf(roll_rng.randf_range(
			LootGenerator.AFFIX_ROLL_MIN, LootGenerator.AFFIX_ROLL_MAX), 0.01)]
		item.affix_rolls = rolls
		var bonus := item.get_total_damage() - 8  # Basis Schwert = 8
		seen_values[bonus] = true
		if bonus < 5 or bonus > 8:
			in_band = false
	_check(in_band, "'der Verwüstung' rollt +5 bis +8 (Basis 5 × 1,0–1,6)")
	_check(seen_values.size() >= 3, "Werte streuen (%d verschiedene)" % seen_values.size())

	# Der Loot-Generator würfelt die Qualität automatisch mit.
	var rolls_ok := true
	for i in 60:
		var item := LootGenerator.roll_item(6, _rng(i * 13))
		if item.affix_rolls.size() != item.affixes.size():
			rolls_ok = false
		for roll in item.affix_rolls:
			if roll < LootGenerator.AFFIX_ROLL_MIN or roll > LootGenerator.AFFIX_ROLL_MAX:
				rolls_ok = false
	_check(rolls_ok, "jeder gedroppte Affix bekommt einen Qualitäts-Roll in der Spanne")

	# Affix-Raritäten: der Katalog nutzt mehrere Stufen …
	var rarities := {}
	for is_prefix in [true, false]:
		for affix in ItemLibrary.affixes_for_tier(99, is_prefix):
			rarities[affix.rarity] = true
	_check(rarities.size() >= 4, "Affix-Katalog nutzt ≥4 Raritätsstufen (%d)" % rarities.size())

	# … und die Gewichtung wirkt: häufige Affixe fallen öfter als legendäre.
	var common_hits := 0
	var legendary_hits := 0
	for i in 400:
		var item := LootGenerator.roll_item_with_rarity(9, Enums.Rarity.RARE, _rng(i * 7))
		for affix in item.affixes:
			if affix.rarity == Enums.Rarity.COMMON:
				common_hits += 1
			elif affix.rarity == Enums.Rarity.LEGENDARY:
				legendary_hits += 1
	_check(common_hits > legendary_hits * 3,
		"Gewichtung: häufige Affixe %d× vs. legendäre %d×" % [common_hits, legendary_hits])

	# Qualitäts-Rolls überstehen den Speicher-Rundweg.
	var original := LootGenerator.roll_item_with_rarity(6, Enums.Rarity.EPIC, _rng(42))
	var restored := ItemInstance.from_dict(original.to_dict())
	_check(restored.affix_rolls.size() == original.affix_rolls.size()
		and restored.get_total_damage() == original.get_total_damage()
		and restored.get_total_armor() == original.get_total_armor()
		and restored.get_total_stat_bonus().strength == original.get_total_stat_bonus().strength,
		"Qualitäts-Rolls überstehen den Speicher-Rundweg (Werte identisch)")
