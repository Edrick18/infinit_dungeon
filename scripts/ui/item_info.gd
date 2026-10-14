class_name ItemInfo
extends RefCounted
## Gemeinsame Item-Anzeige für Inventar, Schmiede und Händler: Werte als
## Zeilen, eine Info-Karte (Hover-Popup) und der Vergleich mit dem
## ausgerüsteten Gegenstand — besser grün, schlechter rot.

const BESSER := Color(0.45, 1.0, 0.5)
const SCHLECHTER := Color(1.0, 0.45, 0.4)

const SLOT_DE := {
	Enums.EquipSlot.WEAPON: "Waffe", Enums.EquipSlot.OFF_HAND: "Nebenhand",
	Enums.EquipSlot.HELMET: "Helm", Enums.EquipSlot.ARMOR: "Rüstung",
	Enums.EquipSlot.GLOVES: "Handschuhe", Enums.EquipSlot.BOOTS: "Stiefel",
	Enums.EquipSlot.RING_1: "Ring", Enums.EquipSlot.RING_2: "Ring",
	Enums.EquipSlot.AMULET: "Amulett",
}
const SLOT_EN := {
	Enums.EquipSlot.WEAPON: "Weapon", Enums.EquipSlot.OFF_HAND: "Off-hand",
	Enums.EquipSlot.HELMET: "Helmet", Enums.EquipSlot.ARMOR: "Armor",
	Enums.EquipSlot.GLOVES: "Gloves", Enums.EquipSlot.BOOTS: "Boots",
	Enums.EquipSlot.RING_1: "Ring", Enums.EquipSlot.RING_2: "Ring",
	Enums.EquipSlot.AMULET: "Amulet",
}
const STAT_KURZ := {&"strength": "STR", &"intelligence": "INT", &"vitality": "VIT",
	&"spirit": "SPI", &"agility": "AGI", &"luck": "LCK"}


static func slot_name(slot: Enums.EquipSlot) -> String:
	return Loc.pick(SLOT_DE.get(slot, "?"), SLOT_EN.get(slot, "?"))


static func raritaet_name(r: Enums.Rarity) -> String:
	var en := {Enums.Rarity.COMMON: "Common", Enums.Rarity.MAGIC: "Magic",
		Enums.Rarity.RARE: "Rare", Enums.Rarity.EPIC: "Epic", Enums.Rarity.LEGENDARY: "Legendary"}
	return Loc.pick(LootGenerator.RARITY_NAMES[r], en[r])


## Vergleichbare Zahlenwerte: [[schluessel, anzeigename, wert], …].
static func werte(item: ItemInstance) -> Array:
	var result := []
	if item == null:
		return result
	result.append([&"schaden", Loc.pick("Schaden", "Damage"), item.get_total_damage()])
	result.append([&"zauber", Loc.pick("Zauberkraft", "Spell power"), item.get_total_spell_damage()])
	result.append([&"ruestung", Loc.pick("Rüstung", "Armor"), item.get_total_armor()])
	var bonus := item.get_total_stat_bonus()
	for stat in StatBlock.STAT_NAMES:
		result.append([stat, STAT_KURZ.get(stat, String(stat)), int(bonus.get(stat))])
	result.append([&"mp", Loc.pick("MP-Ersparnis", "MP saving"), item.get_mp_cost_reduction()])
	return result


## Zusätzliche Text-Eigenschaften (Zweihändig, Element-Schaden, Resistenzen …).
static func eigenschaften(item: ItemInstance) -> Array[String]:
	var parts: Array[String] = []
	if item.base.ranged:
		parts.append(Loc.pick("Fernkampf", "Ranged"))
	elif item.base.two_handed:
		parts.append(Loc.pick("Zweihändig", "Two-handed"))
	if item.base.light:
		parts.append(Loc.pick("Leicht (auch Nebenhand)", "Light (off-hand too)"))
	if item.base.quiver:
		parts.append(Loc.pick("Köcher (nur mit Bogen/Armbrust)", "Quiver (bow/crossbow only)"))
	var arten: Array[String] = []
	for subtype in item.base.weapon_subtypes:
		arten.append(Enums.physical_subtype_name(subtype))
	if item.get_total_damage() > 0 and not arten.is_empty():
		parts.append("/".join(arten))
	var klasse := Enums.armor_class_name(item.base.armor_class)
	if item.get_total_armor() > 0 and not klasse.is_empty():
		parts.append(klasse)
	if item.base.hit_count > 1:
		parts.append(Loc.pick("%d Treffer pro Angriff", "%d hits per attack") % item.base.hit_count)
	if item.base.armor_pierce > 0.0:
		parts.append(Loc.pick("ignoriert %d%% Rüstung", "ignores %d%% armor") % roundi(item.base.armor_pierce * 100))
	var riders := item.get_element_riders()
	for element in riders:
		var block := BlockLibrary.element_block(element)
		if block != null:
			parts.append(Loc.pick("+%d %s-Schaden", "+%d %s damage") % [riders[element], block.display_name])
	for i in item.affixes.size():
		var affix: Affix = item.affixes[i]
		if affix.element_resist > 0:
			var resist := roundi(item.affix_value(i, affix.element_resist)
				* (1.0 + ItemInstance.LEVEL_SCALE * (item.item_level - 1)))
			if affix.element == Enums.Element.NONE:
				parts.append(Loc.pick("+%d Resistenz (alle)", "+%d resistance (all)") % resist)
			else:
				var block := BlockLibrary.element_block(affix.element)
				if block != null:
					parts.append(Loc.pick("+%d %s-Resistenz", "+%d %s resistance") % [resist, block.display_name])
	return parts


## Einzeilige Zusammenfassung (Listen, Meldungen).
static func kurz(item: ItemInstance) -> String:
	var teile: Array[String] = [slot_name(item.base.slot)]
	for w in werte(item):
		if int(w[2]) != 0:
			teile.append("%+d %s" % [w[2], w[1]])
	teile.append_array(eigenschaften(item))
	return "  ·  ".join(teile)


## Info-Karte: Name (Raritätsfarbe), Rarität/Stufe/Slot, Werte, Eigenschaften.
## Mit `vergleich` und einem `ausgeruestet`-Item wird jede Zeile mit der
## Differenz versehen und grün/rot eingefärbt.
static func karte(item: ItemInstance, ausgeruestet: ItemInstance = null, vergleich := false) -> PanelContainer:
	var panel := PanelContainer.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(0.07, 0.07, 0.14, 0.96)
	stil.border_color = LootGenerator.RARITY_COLORS[item.rarity]
	stil.set_border_width_all(2)
	stil.set_corner_radius_all(8)
	stil.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", stil)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.custom_minimum_size = Vector2(260, 0)
	panel.add_child(box)

	var name_label := _label(item.get_display_name(), 16, LootGenerator.RARITY_COLORS[item.rarity])
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(name_label)
	box.add_child(_label("%s  ·  %s  ·  %s" % [raritaet_name(item.rarity),
		Loc.pick("Stufe %d", "Level %d") % item.item_level, slot_name(item.base.slot)], 11,
		Color(1, 1, 1, 0.6)))
	box.add_child(HSeparator.new())

	var alt := {}
	if vergleich and ausgeruestet != null and ausgeruestet != item:
		for w in werte(ausgeruestet):
			alt[w[0]] = int(w[2])
	var zeigt_vergleich := not alt.is_empty()
	for w in werte(item):
		var wert := int(w[2])
		var alter_wert := int(alt.get(w[0], 0))
		if wert == 0 and (not zeigt_vergleich or alter_wert == 0):
			continue
		var text := "%+d %s" % [wert, w[1]]
		var farbe := Color(0.92, 0.92, 1.0)
		if zeigt_vergleich:
			var diff := wert - alter_wert
			if diff != 0:
				text += "   (%+d)" % diff
				farbe = BESSER if diff > 0 else SCHLECHTER
		box.add_child(_label(text, 13, farbe))
	for eigenschaft in eigenschaften(item):
		box.add_child(_label("• " + eigenschaft, 12, Color(0.75, 0.88, 1.0)))
	if vergleich:
		box.add_child(HSeparator.new())
		var hinweis := Loc.pick("Vergleich mit: %s", "Compared to: %s") % ausgeruestet.get_display_name() \
			if zeigt_vergleich else Loc.pick("Nichts ausgerüstet zum Vergleichen", "Nothing equipped to compare")
		box.add_child(_label(hinweis, 10, Color(1, 1, 1, 0.5)))
	return panel


static func _label(text: String, groesse: int, farbe: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", groesse)
	label.add_theme_color_override("font_color", farbe)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
