class_name Eigenheiten
extends RefCounted
## Gegner-Eigenheiten (Design-Review 2026-10-17, Säule „Jeder Kampf ist eine
## kleine Frage“): jeder normale Grundtyp hat EINE eigene Regel, die eine
## bestimmte Antwort verlangt (Fläche, Zauber, Heilig, Stumpf, Kontrolle …).
## Angezeigt wird vorher nichts — die Regel zeigt sich im Kampf (Log) und
## steht danach im Bestiarium (GameState.eigenheit_wissen).
## Bosse haben stattdessen ihre Signaturen (EnemyFactory.BOSS_SIGNATURES).
## Die Wirkung steckt in Battle (_eigenheit_*).

# --- Werte ---------------------------------------------------------------------
const RUDEL_BONUS := 0.15          ## +15 % Schaden je weiterem Exemplar
const RASEREI_SCHWELLE := 0.5
const RASEREI_BONUS := 0.3
const NACHTJAEGER_BONUS := 0.5
const KOERPERLOS_FAKTOR := 0.5     ## Waffenschaden gegen Geister
const FLATTERHAFT_CHANCE := 30     ## % Ausweichen gegen Einzel-Nahkampf
const SCHILDWALL_CHANCE := 30      ## % Waffentreffer halbiert
const KOENIG_SCHUTZ := 0.7         ## andere Schleime nehmen ×0,7
const HOELLENPAKT_FAKTOR := 0.5
const STACHEL_ANTEIL := 0.15       ## Nahkampf-Rückschaden
const SPIEGEL_ANTEIL := 0.3        ## Zauber-Rückschaden
const REGEN_TROLL := 0.05
const REGEN_PILZ := 0.06
const WIEDERKEHR_HP := 0.3
const TOTENRUF_HP := 0.5
const LEICHENSCHMAUS := 0.25
const NETZ_TEMPO := 30             ## Verlangsamen-Stärke
const NETZ_ZUEGE := 2
const SPOREN_PROZENT := 0.03       ## Gift-Stacks = 3 % Max-HP (= Tick-Deckel)
const DIEB_ANTEIL := 0.03          ## 3 % des Goldes je Diebstahl …
const DIEB_MAX_JE_STUFE := 25      ## … höchstens 25 Gold × Stufe
const DIEB_FLUCHT := 0.5
const SCHNAPPEN_KRIT := 20
const OPFER_STAERKE := 20
const SEUCHE_PROZENT := 0.02       ## Gift-Stacks = 2 % Max-HP, einmal je Held
const KRISTALL_FAKTOR := 0.5       ## Zauberschaden gegen Kristallpanzer
const HAEUTUNG_SCHWELLE := 0.5
const HAEUTUNG_HEIL := 0.2
const MAX_GEGNER := 8              ## Teilung/Zerfall nur bis zu dieser Gruppengröße

## Grundtyp » Eigenheit.
const ZUORDNUNG := {
	&"wolf": &"rudel", &"toddiener": &"rudel", &"pilzkrabbel": &"rudel",
	&"bandit": &"taschendieb", &"mimic": &"zuschnappen", &"baer": &"raserei",
	&"schleim": &"teilung", &"schleimstapel": &"zerfall", &"koenigschleim": &"hoheit",
	&"fledermaus": &"flatterhaft", &"spinne": &"netz", &"golem": &"gesteinskoerper",
	&"troll": &"regeneration", &"skelett": &"wiederkehr", &"kultist": &"opfer",
	&"geist": &"koerperlos", &"nekromant": &"totenruf", &"schattenbestie": &"nachtjaeger",
	&"leichenfresser": &"leichenschmaus", &"schattenkrieger": &"schildwall",
	&"kleindaemon": &"feuerseele", &"demonenjager": &"bannklaue",
	&"demonenbeschwoerer": &"hoellenpakt", &"verfluchtkatz": &"neun_leben",
	&"verfluchtigel": &"stachelpanzer", &"verfluchtdachs": &"dickfellig",
	&"verfluchtbock": &"sturmangriff", &"pilzhexe": &"sporenwolke",
	&"pilzstamm": &"wurzelwerk", &"hexenmeisterin": &"fluchspiegel",
	&"grubenratte": &"seuchenbiss", &"kristallkaefer": &"kristallpanzer", &"blindolm": &"haeutung",
	# Höllenschlund (2026-11-02): Peiniger jagt Geschwächte, der Aschekoloss
	# trägt einen glühenden Stachelpanzer.
	&"peiniger": &"nachtjaeger", &"aschekoloss": &"stachelpanzer",
}

## Eigenheit » [Name DE, Name EN, Text DE, Text EN] — sachlich, was sie tut.
const TEXTE := {
	&"rudel": ["Rudel", "Pack",
		"+15 % Schaden für jeden weiteren lebenden Gegner derselben Art.",
		"+15% damage for every other living enemy of the same kind."],
	&"taschendieb": ["Taschendieb", "Pickpocket",
		"Der erste Treffer stiehlt Gold (3 %, höchstens 25 × Stufe). Danach versucht er zu fliehen. Wird er besiegt, kommt das Gold zurück.",
		"The first hit steals gold (3%, at most 25 × tier). Then he tries to flee. Defeating him returns the gold."],
	&"zuschnappen": ["Zuschnappen", "Snap",
		"+20 % Krit-Chance.", "+20% crit chance."],
	&"raserei": ["Raserei", "Frenzy",
		"Unter 50 % HP: +30 % Schaden.", "Below 50% HP: +30% damage."],
	&"teilung": ["Teilung", "Split",
		"Überlebt er einen Flächentreffer, spaltet sich einmal ein Schleim ab.",
		"If it survives an area hit, a slime splits off once."],
	&"zerfall": ["Zerfall", "Fall apart",
		"Zerfällt beim Tod in einen Schleim.", "Falls apart into a slime on death."],
	&"hoheit": ["Königliche Hoheit", "Royal Majesty",
		"Solange er lebt, nehmen andere Schleime 30 % weniger Schaden.",
		"While it lives, other slimes take 30% less damage."],
	&"flatterhaft": ["Flatterhaft", "Flighty",
		"Weicht 30 % der Nahkampf-Treffer gegen ein Einzelziel aus.",
		"Dodges 30% of single-target melee hits."],
	&"netz": ["Netz", "Web",
		"Treffer verlangsamen das Ziel für 2 Züge.", "Hits slow the target for 2 turns."],
	&"gesteinskoerper": ["Gesteinskörper", "Stone body",
		"Gift und Blutung wirken nicht.", "Poison and bleeding have no effect."],
	&"regeneration": ["Regeneration", "Regeneration",
		"Heilt zu Beginn jedes Zuges 5 % der Max-HP.",
		"Heals 5% of max HP at the start of each turn."],
	&"wiederkehr": ["Wiederkehr", "Reassemble",
		"Steht einmal mit 30 % HP wieder auf.",
		"Gets back up once with 30% HP."],
	&"opfer": ["Opferbereit", "Devoted",
		"Fällt er, stärkt er einen anderen Gegner (Stärken).",
		"When he falls, he empowers another enemy (attack up)."],
	&"koerperlos": ["Körperlos", "Incorporeal",
		"Waffentreffer machen nur halben Schaden.", "Weapon hits deal only half damage."],
	&"totenruf": ["Totenruf", "Call of the dead",
		"Erweckt einmal einen gefallenen Verbündeten mit 50 % HP.",
		"Raises a fallen ally once with 50% HP."],
	&"nachtjaeger": ["Nachtjäger", "Night hunter",
		"+50 % Schaden gegen Ziele unter 50 % HP.", "+50% damage against targets below 50% HP."],
	&"leichenschmaus": ["Leichenschmaus", "Corpse feast",
		"Heilt 25 % der Max-HP, wenn irgendein Kämpfer fällt.",
		"Heals 25% of max HP whenever any combatant falls."],
	&"schildwall": ["Schildwall", "Shield wall",
		"Halbiert 30 % der Waffentreffer. Zauber nicht.",
		"Halves 30% of weapon hits. Not spells."],
	&"feuerseele": ["Feuerseele", "Fire soul",
		"Feuer heilt ihn, statt zu schaden.", "Fire heals it instead of dealing damage."],
	&"bannklaue": ["Bannklaue", "Dispel claw",
		"Treffer entfernen eine Stärkung des Ziels.", "Hits remove one buff from the target."],
	&"hoellenpakt": ["Höllenpakt", "Hell pact",
		"Solange eine seiner Beschwörungen lebt, nimmt er 50 % weniger Schaden.",
		"While one of his summons lives, he takes 50% less damage."],
	&"neun_leben": ["Neun Leben", "Nine lives",
		"Überlebt einmal einen tödlichen Treffer mit 1 HP.", "Survives one lethal hit with 1 HP."],
	&"stachelpanzer": ["Stachelpanzer", "Spiked hide",
		"Nahkampf-Treffer werfen 15 % des Schadens auf den Angreifer zurück.",
		"Melee hits reflect 15% of the damage back to the attacker."],
	&"dickfellig": ["Dickfellig", "Thick-skinned",
		"Schüttelt jeden zweiten eigenen Zug alle Schwächungen ab.",
		"Shakes off all debuffs every second turn."],
	&"sturmangriff": ["Sturmangriff", "Charge",
		"Der erste Angriff im Kampf macht doppelten Schaden.",
		"The first attack of the battle deals double damage."],
	&"sporenwolke": ["Sporenwolke", "Spore cloud",
		"Fällt sie, vergiftet sie alle Helden.", "When she falls, she poisons all heroes."],
	&"wurzelwerk": ["Wurzelwerk", "Root network",
		"Heilt zu Beginn jedes Zuges 6 % der Max-HP.",
		"Heals 6% of max HP at the start of each turn."],
	&"fluchspiegel": ["Fluchspiegel", "Curse mirror",
		"Zauberschaden gegen sie wird zu 30 % auf den Zaubernden zurückgeworfen.",
		"30% of spell damage against her is reflected to the caster."],
	&"seuchenbiss": ["Seuchenbiss", "Plague bite",
		"Sein erster Treffer an jedem Helden vergiftet diesen (Gift-Stacks: 2 % seiner Max-HP).",
		"Its first hit on each hero poisons that hero (poison stacks: 2% of their max HP)."],
	&"kristallpanzer": ["Kristallpanzer", "Crystal shell",
		"Direkter Zauberschaden gegen ihn ist halbiert. Waffentreffer, Brand und Gift nicht.",
		"Direct spell damage against it is halved. Weapon hits, burn and poison are not."],
	&"haeutung": ["Häutung", "Molting",
		"Fällt er unter 50 % HP, streift er einmal alle Leiden ab und heilt 20 % der Max-HP.",
		"Below 50% HP it sheds all ailments once and heals 20% of its max HP."],
}

## Gegenweg je Eigenheit (Lutz 2026-11-02): jede Eigenheit hat eine Antwort
## über Waffenart, Schadensart oder Element, damit Waffenwechsel zählt.
## [Treffer-Art, Satz DE, Satz EN]. Trifft ein Held den Gegner mit dieser
## Treffer-Art, ist die Eigenheit für den Rest des Kampfes aufgehoben
## (Battle._eigenheit_konter). Leere Treffer-Art = der Gegenweg steckt schon
## in der Regel selbst (Flatterhaft, Regeneration, Wiederkehr, Stachelpanzer);
## der Satz nennt ihn mit den Waffen.
## Treffer-Arten: stumpf, stich, schnitt (Schadensart), fern (Bogen, Armbrust),
## feuer, eis, blitz, gift, heilig, dunkel (Element).
const KONTER := {
	&"rudel": [&"feuer", "Ein Feuertreffer hebt den Rudel-Bonus auf.",
		"A fire hit cancels the pack bonus."],
	&"taschendieb": [&"fern", "Ein Fernkampftreffer (Bogen, Armbrust) lässt ihn das Gold fallen und hebt die Eigenheit auf.",
		"A ranged hit (bow, crossbow) makes him drop the gold and cancels the trait."],
	&"zuschnappen": [&"stumpf", "Ein stumpfer Treffer (Hammer, Knüppel, Turmschild) hebt den Krit-Bonus auf.",
		"A blunt hit (hammer, club, tower shield) cancels the crit bonus."],
	&"raserei": [&"eis", "Ein Eistreffer hebt die Raserei auf.", "An ice hit cancels the frenzy."],
	&"teilung": [&"feuer", "Ein Feuertreffer hebt die Teilung auf.", "A fire hit cancels the split."],
	&"zerfall": [&"feuer", "Ein Feuertreffer hebt den Zerfall auf.", "A fire hit cancels the falling apart."],
	&"hoheit": [&"blitz", "Ein Blitztreffer hebt die Hoheit auf.", "A lightning hit cancels the majesty."],
	&"flatterhaft": [&"", "Fernkampf (Bogen, Armbrust), Zauber und Flächen treffen immer.",
		"Ranged attacks (bow, crossbow), spells and area hits always land."],
	&"netz": [&"feuer", "Ein Feuertreffer verbrennt das Netz und hebt die Eigenheit auf.",
		"A fire hit burns the web and cancels the trait."],
	&"gesteinskoerper": [&"stumpf", "Ein stumpfer Treffer (Hammer, Knüppel, Turmschild) hebt den Gesteinskörper auf.",
		"A blunt hit (hammer, club, tower shield) cancels the stone body."],
	&"regeneration": [&"", "Brand (Feuer) und Gift halten die Regeneration an.",
		"Burn (fire) and poison stop the regeneration."],
	&"wiederkehr": [&"", "Ein heiliger oder stumpfer letzter Treffer (Hammer, Knüppel, Turmschild) verhindert das Aufstehen.",
		"A holy or blunt final hit (hammer, club, tower shield) prevents getting up."],
	&"opfer": [&"blitz", "Ein Blitztreffer hebt die Opferbereitschaft auf.", "A lightning hit cancels the devotion."],
	&"koerperlos": [&"heilig", "Zauber treffen voll. Ein heiliger Treffer hebt die Körperlosigkeit auf.",
		"Spells hit in full. A holy hit cancels the incorporeality."],
	&"totenruf": [&"stich", "Ein Stichtreffer (Dolch, Schwert, Bogen, Armbrust) hebt den Totenruf auf.",
		"A pierce hit (dagger, sword, bow, crossbow) cancels the call of the dead."],
	&"nachtjaeger": [&"heilig", "Ein heiliger Treffer hebt den Nachtjäger auf.", "A holy hit cancels the night hunter."],
	&"leichenschmaus": [&"heilig", "Ein heiliger Treffer hebt den Leichenschmaus auf.", "A holy hit cancels the corpse feast."],
	&"schildwall": [&"schnitt", "Ein Schnitttreffer (Axt, Schwert) zerschlägt den Schild und hebt die Eigenheit auf.",
		"A slash hit (axe, sword) breaks the shield and cancels the trait."],
	&"feuerseele": [&"eis", "Ein Eistreffer hebt die Feuerseele auf, Feuer schadet danach normal.",
		"An ice hit cancels the fire soul; fire deals normal damage afterwards."],
	&"bannklaue": [&"stich", "Ein Stichtreffer (Dolch, Schwert, Bogen, Armbrust) hebt die Bannklaue auf.",
		"A pierce hit (dagger, sword, bow, crossbow) cancels the dispel claw."],
	&"hoellenpakt": [&"heilig", "Ein heiliger Treffer hebt den Höllenpakt auf.", "A holy hit cancels the hell pact."],
	&"neun_leben": [&"stumpf", "Ein stumpfer Treffer (Hammer, Knüppel, Turmschild) hebt die neun Leben auf.",
		"A blunt hit (hammer, club, tower shield) cancels the nine lives."],
	&"stachelpanzer": [&"", "Fernkampf (Bogen, Armbrust) und Zauber lösen keinen Rückschaden aus.",
		"Ranged attacks (bow, crossbow) and spells cause no reflected damage."],
	&"dickfellig": [&"stich", "Ein Stichtreffer (Dolch, Schwert, Bogen, Armbrust) hebt die Eigenheit auf.",
		"A pierce hit (dagger, sword, bow, crossbow) cancels the trait."],
	&"sturmangriff": [&"fern", "Ein Fernkampftreffer (Bogen, Armbrust) vor seinem ersten Angriff hebt den Sturmangriff auf.",
		"A ranged hit (bow, crossbow) before its first attack cancels the charge."],
	&"sporenwolke": [&"feuer", "Ein Feuertreffer verbrennt die Sporen und hebt die Eigenheit auf.",
		"A fire hit burns the spores and cancels the trait."],
	&"wurzelwerk": [&"schnitt", "Brand (Feuer) hält das Heilen an. Ein Schnitttreffer (Axt, Schwert) kappt die Wurzeln und hebt die Eigenheit auf.",
		"Burn (fire) stops the healing. A slash hit (axe, sword) cuts the roots and cancels the trait."],
	&"fluchspiegel": [&"stumpf", "Ein stumpfer Treffer (Hammer, Knüppel, Turmschild) zerschlägt den Spiegel und hebt die Eigenheit auf.",
		"A blunt hit (hammer, club, tower shield) shatters the mirror and cancels the trait."],
	&"seuchenbiss": [&"feuer", "Ein Feuertreffer hebt den Seuchenbiss auf.", "A fire hit cancels the plague bite."],
	&"kristallpanzer": [&"stumpf", "Ein stumpfer Treffer (Hammer, Knüppel, Turmschild) zerschlägt den Kristallpanzer und hebt die Eigenheit auf.",
		"A blunt hit (hammer, club, tower shield) shatters the crystal shell and cancels the trait."],
	&"haeutung": [&"blitz", "Ein Blitztreffer hebt die Häutung auf.", "A lightning hit cancels the molting."],
}

## Logzeilen-Anfang je Treffer-Art (Battle._eigenheit_konter).
const TREFFER_NAMEN := {
	&"stumpf": ["Der stumpfe Treffer", "The blunt hit"], &"stich": ["Der Stichtreffer", "The pierce hit"],
	&"schnitt": ["Der Schnitttreffer", "The slash hit"], &"fern": ["Der Fernkampftreffer", "The ranged hit"],
	&"feuer": ["Der Feuertreffer", "The fire hit"], &"eis": ["Der Eistreffer", "The ice hit"],
	&"blitz": ["Der Blitztreffer", "The lightning hit"], &"gift": ["Der Gifttreffer", "The poison hit"],
	&"heilig": ["Der heilige Treffer", "The holy hit"], &"dunkel": ["Der Dunkeltreffer", "The dark hit"],
}

## Treffer-Art eines Elements (Enums.Element » Schlüssel in KONTER).
const ELEMENT_ART := {
	Enums.Element.FIRE: &"feuer", Enums.Element.ICE: &"eis", Enums.Element.LIGHTNING: &"blitz",
	Enums.Element.POISON: &"gift", Enums.Element.HOLY: &"heilig", Enums.Element.DARK: &"dunkel",
}


static func fuer(archetype_id: StringName) -> StringName:
	return ZUORDNUNG.get(archetype_id, &"")


static func name_von(eigenheit: StringName) -> String:
	var t: Array = TEXTE.get(eigenheit, [])
	return "" if t.is_empty() else Loc.pick(t[0], t[1])


## Regeltext samt Gegenweg (Tooltip, Bestiarium).
static func text_von(eigenheit: StringName) -> String:
	var t: Array = TEXTE.get(eigenheit, [])
	if t.is_empty():
		return ""
	var konter := konter_text(eigenheit)
	return Loc.pick(t[2], t[3]) + ("" if konter.is_empty() else " " + konter)


## Treffer-Art, die diese Eigenheit aufhebt (&"" = Gegenweg steckt in der Regel).
static func konter_art(eigenheit: StringName) -> StringName:
	var k: Array = KONTER.get(eigenheit, [])
	return &"" if k.is_empty() else k[0]


static func konter_text(eigenheit: StringName) -> String:
	var k: Array = KONTER.get(eigenheit, [])
	return "" if k.is_empty() else Loc.pick(k[1], k[2])


static func treffer_name(art: StringName) -> String:
	var t: Array = TREFFER_NAMEN.get(art, [])
	return String(art) if t.is_empty() else Loc.pick(t[0], t[1])
