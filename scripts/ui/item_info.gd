class_name ItemInfo
extends RefCounted
## Gemeinsame Item-Anzeige für Inventar, Schmiede und Händler: Werte als
## Zeilen, eine Info-Karte (Hover-Popup) und der Vergleich mit dem
## ausgerüsteten Gegenstand — besser grün, schlechter rot.

## Farben direkt aus Stil3D.PAL (dieselben Rollen wie UiTheme GUT, SCHLECHT,
## INFO, TEXT, HOLZ_TIEF, BLASS): ItemInfo läuft auch in Headless-Selbsttests
## (-s, data_selftest), dort kompiliert UiTheme nicht (MenueKulisse braucht
## den Autoload GameState) — eine Abhängigkeit auf UiTheme riss ItemInfo mit.
const BESSER: Color = Stil3D.PAL["ui_gut"]
const SCHLECHTER: Color = Stil3D.PAL["ui_schlecht"]
const NEBEN := Color(Stil3D.PAL["ui_text"], 0.6)  ## Nebentext (Deckkraft wie BLASS)

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
	return LootGenerator.rarity_name(r)


## Vergleichbare Zahlenwerte: [[schluessel, anzeigename, wert], …].
static func werte(item: ItemInstance) -> Array:
	var result := []
	if item == null:
		return result
	result.append([&"schaden", Loc.pick("Schaden", "Damage"), item.get_total_damage()])
	result.append([&"zauber", Loc.pick("Zauberkraft", "Spell power"), item.get_total_spell_damage()])
	result.append([&"ruestung", Loc.pick("Rüstung", "Armor"), item.get_total_armor()])
	result.append([&"magieschutz", Loc.pick("Magieschutz", "Magic ward"), Combatant.magieschutz_von(item)])
	var bonus := item.get_total_stat_bonus()
	for stat in StatBlock.STAT_NAMES:
		result.append([stat, STAT_KURZ.get(stat, String(stat)), int(bonus.get(stat))])
	result.append([&"mp", Loc.pick("% MP-Ersparnis", "% MP saving"), item.get_mp_cost_reduction()])
	# Prozent-Affixe (Summe je Art auf diesem Item).
	for art in PROZENT_NAMEN:
		result.append([StringName("p_" + String(art)), "%% %s" % prozent_name(art), item.get_prozent(art)])
	return result


## Anzeigenamen der Prozent-Arten (Affix.prozent_art).
const PROZENT_NAMEN := {
	&"ruestung": ["Rüstung", "armor"], &"schaden": ["Waffenschaden", "weapon damage"],
	&"zauberkraft": ["Zauberkraft", "spell power"],
	&"strength": ["STR", "STR"], &"intelligence": ["INT", "INT"],
	&"vitality": ["VIT", "VIT"], &"spirit": ["SPI", "SPI"],
}


static func prozent_name(art: StringName) -> String:
	var paar: Array = PROZENT_NAMEN.get(art, [String(art), String(art)])
	return Loc.pick(paar[0], paar[1])


## Zusätzliche Text-Eigenschaften (Zweihändig, Element-Schaden, Resistenzen,
## Regelbrecher, Boss-Beute, Skill-Affixe) — für Listen und Kurzzeilen.
static func eigenschaften(item: ItemInstance) -> Array[String]:
	var parts := basis_eigenschaften(item)
	var riders := item.get_element_riders()
	for element in riders:
		var block := BlockLibrary.element_block(element)
		if block != null:
			parts.append(Loc.pick("+%d %s-Schaden", "+%d %s damage") % [riders[element], block.display_name])
	for i in item.affixes.size():
		var affix: Affix = item.affixes[i]
		if affix.regelbruch != &"" or affix.ist_skill_affix():
			parts.append(affix_text(item, i))
		if affix.boss_id != &"":
			parts.append(BossBeute.eigenschaft_text(item, i))
		if affix.element_resist > 0:
			parts.append(_resist_text(item, i))
	return parts


## Eigenschaften der Basis (Fernkampf, Zweihändig, Schadensarten, Rüstungsklasse …).
static func basis_eigenschaften(item: ItemInstance) -> Array[String]:
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
	return parts


## Resistenz-Text eines Affixes („+8% Feuer-Resistenz“).
static func _resist_text(item: ItemInstance, i: int) -> String:
	var affix: Affix = item.affixes[i]
	var resist := item.affix_value(i, affix.element_resist)
	if affix.element == Enums.Element.NONE:
		return Loc.pick("+%d%% Resistenz (alle Elemente)", "+%d%% resistance (all elements)") % resist
	var block := BlockLibrary.element_block(affix.element)
	return Loc.pick("+%d%% %s-Resistenz", "+%d%% %s resistance") \
		% [resist, block.display_name if block != null else "?"]


## Wirkungen der Skill-Affixe (Affix.klotz_wirkung) » [DE, EN], %d = Wert, %s = Bezug.
const SKILL_WIRKUNG := {
	&"schaden": ["+%d %% Schaden für %s", "+%d%% damage for %s"],
	&"mp": ["−%d %% MP-Kosten für %s", "−%d%% MP cost for %s"],
	&"dauer": ["+%d Runde Effektdauer für %s", "+%d round effect duration for %s"],
	&"stacks": ["+%d %% Stacks (Brand, Gift, Blutung) für %s", "+%d%% stacks (burn, poison, bleed) for %s"],
	&"treffer": ["+%d %% Chance auf einen Zusatztreffer für %s", "+%d%% chance of an extra hit for %s"],
	&"krit": ["+%d %% Krit-Chance für %s", "+%d%% crit chance for %s"],
}


## Bezug eines Skill-Affixes lesbar: „Skills mit Zusatztreffer“, „Schwert-Techniken“,
## „Feuer-Skills“, „Skills mit Form „Aura““.
static func bezug_name(bezug: StringName) -> String:
	var teile := String(bezug).split(":")
	if teile.size() != 2:
		return String(bezug)
	var wert := teile[1]
	match teile[0]:
		"klotz":
			var block := BlockLibrary.get_block(StringName(wert))
			return Loc.pick("Skills mit %s", "skills with %s") % (block.display_name if block != null else wert)
		"gruppe":
			var paar: Array = BlockLibrary.GRUPPEN.get(StringName(wert), [wert, wert])
			return Loc.pick("Skills mit %s-Klotz", "skills with a %s block") % Loc.pick(paar[0], paar[1])
		"gattung":
			return Loc.pick("%s-Techniken", "%s techniques") % BlockLibrary.family_label(StringName(wert))
		"element":
			var element: Enums.Element = Skill.BEZUG_ELEMENT.get(wert, Enums.Element.NONE)
			var block := BlockLibrary.element_block(element)
			return Loc.pick("%s-Skills", "%s skills") % (block.display_name if block != null else wert)
		"form":
			var name := wert
			for block in BlockLibrary.all_blocks():
				if block is FormBlock and int(block.form) == int(Skill.BEZUG_FORM.get(wert, -1)):
					name = block.display_name
			return Loc.pick("Skills mit Form „%s“", "skills with form “%s”") % name
	return String(bezug)


## Wirkung eines Affixes als Text OHNE Spanne: „+52 Rüstung“, „+14 % Rüstung“,
## „+18 % Schaden für Skills mit Zusatztreffer“, „Regelbruch: …“.
static func affix_text(item: ItemInstance, i: int) -> String:
	var affix: Affix = item.affixes[i]
	match affix.regelbruch:
		&"sockel":
			return Loc.pick("Regelbruch: +1 Sockel für alle Skills", "Rule break: +1 socket for all skills")
		&"doppelkern":
			return Loc.pick("Regelbruch: zwei Kern-Klötze pro Skill", "Rule break: two core blocks per skill")
		&"waffenfrei":
			return Loc.pick("Regelbruch: Waffen-Techniken mit jeder Waffe",
				"Rule break: weapon techniques with any weapon")
	if affix.ist_skill_affix():
		var t: Array = SKILL_WIRKUNG.get(affix.klotz_wirkung, ["%d %s", "%d %s"])
		return Loc.pick(t[0], t[1]) % [item.affix_wert(i), bezug_name(affix.klotz_bezug)]
	if affix.boss_id != &"" and affix.boss_effekt != &"":
		return BossBeute.eigenschaft_text(item, i)
	var parts: Array[String] = []
	if affix.prozent_art != &"":
		parts.append(Loc.pick("+%d %% %s", "+%d%% %s") % [item.affix_wert(i), prozent_name(affix.prozent_art)])
	var skaliert := item.affix_wert(i) if affix.skaliert_mit_level() else 0
	if affix.bonus_damage != 0:
		parts.append(Loc.pick("+%d Schaden", "+%d damage") % skaliert)
	if affix.bonus_armor != 0:
		parts.append(Loc.pick("+%d Rüstung", "+%d armor") % skaliert)
	if affix.bonus_spell_damage != 0:
		parts.append(Loc.pick("+%d Zauberkraft", "+%d spell power") % skaliert)
	if affix.element_damage > 0 and affix.element != Enums.Element.NONE:
		var block := BlockLibrary.element_block(affix.element)
		parts.append(Loc.pick("+%d %s-Schaden", "+%d %s damage")
			% [skaliert, block.display_name if block != null else "?"])
	if affix.element_resist > 0:
		parts.append(_resist_text(item, i))
	if affix.mp_cost_reduction > 0:
		parts.append(Loc.pick("−%d %% MP-Kosten", "−%d%% MP cost") % item.affix_value(i, affix.mp_cost_reduction))
	if affix.stat_bonus != null:
		for stat in StatBlock.STAT_NAMES:
			var wert := item.affix_value(i, int(affix.stat_bonus.get(stat)))
			if wert != 0:
				parts.append("%+d %s" % [wert, STAT_KURZ.get(stat, String(stat))])
	var text := ", ".join(parts)
	if affix.boss_id != &"":
		text = BossBeute.eigenschaft_text(item, i) + (": " + text if not text.is_empty() else "")
	return text


## Ist der Affix-Wert ein Prozentwert? (Spanne „[10–16 %]“ statt „[40–64]“.)
static func _affix_in_prozent(affix: Affix) -> bool:
	if affix.ist_skill_affix():
		return affix.klotz_wirkung != &"dauer"
	return affix.prozent_art != &"" or affix.element_resist > 0 or affix.mp_cost_reduction > 0 \
		or affix.boss_effekt != &""


## Affix-Zeile der Item-Karte: Wirkung, Spanne und Güte des Wurfs —
## „+52 Rüstung [40–64] · 50 %“, „+14 % Rüstung [10–16 %] · 67 %“.
## Ohne Qualitäts-Roll (Regelbrecher, „+1 Runde“) nur die Wirkung.
static func affix_zeile(item: ItemInstance, i: int) -> String:
	var affix: Affix = item.affixes[i]
	var text := affix_text(item, i)
	if not affix.rollt() or affix.grundwert() == 0:
		return text
	var spanne := item.affix_spanne(i)
	# Spanne und Güte bleiben beim Zeilenumbruch zusammen (geschützte
	# Leerzeichen, Wortverbinder um den Strich).
	var einheit := Loc.pick(NBSP + "%", "%") if _affix_in_prozent(affix) else ""
	return "%s [%d%s–%s%d%s]%s·%s%s" % [text, int(spanne.x), WJ, WJ, int(spanne.y), einheit, NBSP, NBSP,
		Loc.pick("%d" + NBSP + "%%", "%d%%") % roundi(item.affix_guete(i) * 100.0)]


const NBSP := "\u00a0"  ## geschütztes Leerzeichen
const WJ := "\u2060"    ## Wortverbinder (kein Umbruch am Strich)


## Kurzform der Skill-Affix-Wirkungen (ohne Bezug) für die Werkstatt (SkillWorkshop).
const BONUS_KURZ := {
	&"schaden": ["+%d %% Schaden", "+%d%% damage"], &"mp": ["−%d %% MP-Kosten", "−%d%% MP cost"],
	&"dauer": ["+%d Runde Effektdauer", "+%d round effect duration"],
	&"stacks": ["+%d %% Stacks", "+%d%% stacks"],
	&"treffer": ["+%d %% Zusatztreffer-Chance", "+%d%% extra hit chance"],
	&"krit": ["+%d %% Krit-Chance", "+%d%% crit chance"],
}


## Welche Skill-Affixe der Ausrüstung gerade auf diesen Skill wirken
## (Combatant.skill_boni — dieselben Zahlen wie im Kampf), leer = keine.
## „Item-Boni: +10 % Schaden (Schwert des Fechters) · −8 % MP-Kosten (Ring der Weite)“
static func skill_boni_text(held: Combatant, skill: Skill) -> String:
	if held == null:
		return ""
	var teile: Array[String] = []
	for eintrag in held.skill_boni(skill):
		var t: Array = BONUS_KURZ.get(eintrag["wirkung"], ["%d", "%d"])
		var item: ItemInstance = eintrag["item"]
		teile.append("%s (%s)" % [Loc.pick(t[0], t[1]) % roundi(eintrag["wert"]), item.get_display_name()])
	if teile.is_empty():
		return ""
	return Loc.pick("Item-Boni: ", "Item bonuses: ") + "  ·  ".join(teile)


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
## Differenz versehen und grün/rot eingefärbt. Mit `studio` steht das
## Item-Icon links neben Name und Raritätszeile.
const KOPF_ICON := 44
const KARTE_BREITE := 280


static func karte(item: ItemInstance, ausgeruestet: ItemInstance = null, vergleich := false,
		studio: PortraitStudio = null) -> PanelContainer:
	var panel := PanelContainer.new()
	var stil := StyleBoxFlat.new()
	stil.bg_color = Color(Stil3D.PAL["ui_holz_tief"], 0.96)
	stil.border_color = LootGenerator.RARITY_COLORS[item.rarity]
	stil.set_border_width_all(2)
	stil.set_corner_radius_all(8)
	stil.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", stil)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.custom_minimum_size = Vector2(KARTE_BREITE, 0)
	panel.add_child(box)

	var kopf: VBoxContainer = box
	if studio != null and is_instance_valid(studio):
		var zeile := HBoxContainer.new()
		zeile.add_theme_constant_override("separation", 8)
		zeile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(zeile)
		zeile.add_child(UiHolz.icon(GegenstandIcons.textur(studio, item.base), KOPF_ICON))
		kopf = VBoxContainer.new()
		kopf.add_theme_constant_override("separation", 2)
		kopf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kopf.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		kopf.mouse_filter = Control.MOUSE_FILTER_IGNORE
		zeile.add_child(kopf)
	var name_label := _label(item.get_display_name(), 16, LootGenerator.RARITY_COLORS[item.rarity])
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kopf.add_child(name_label)
	kopf.add_child(_label("%s  ·  %s  ·  %s" % [raritaet_name(item.rarity),
		Loc.pick("Stufe %d", "Level %d") % item.item_level, slot_name(item.base.slot)], 11,
		NEBEN))
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
		var farbe: Color = Stil3D.PAL["ui_text"]
		if zeigt_vergleich:
			var diff := wert - alter_wert
			if diff != 0:
				text += "   (%+d)" % diff
				farbe = BESSER if diff > 0 else SCHLECHTER
		box.add_child(_label(text, 13, farbe))
	for eigenschaft in basis_eigenschaften(item):
		box.add_child(_label("• " + eigenschaft, 12, Stil3D.PAL["ui_info"]))
	# Je Affix eine Zeile mit Spanne und Güte des Wurfs.
	if not item.affixes.is_empty():
		box.add_child(HSeparator.new())
		for i in item.affixes.size():
			var zeile := _label(affix_zeile(item, i), 12, Stil3D.PAL["ui_info"])
			zeile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(zeile)
	if vergleich:
		box.add_child(HSeparator.new())
		var hinweis := Loc.pick("Vergleich mit: %s", "Compared to: %s") % ausgeruestet.get_display_name() \
			if zeigt_vergleich else Loc.pick("Nichts ausgerüstet zum Vergleichen", "Nothing equipped to compare")
		box.add_child(_label(hinweis, 10, NEBEN))
	return panel


static func _label(text: String, groesse: int, farbe: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", groesse)
	label.add_theme_color_override("font_color", farbe)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
