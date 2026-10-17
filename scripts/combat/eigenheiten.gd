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
		"Weicht 30 % der Nahkampf-Treffer gegen ein Einzelziel aus. Fernkampf, Zauber und Flächen treffen immer.",
		"Dodges 30% of single-target melee hits. Ranged, spells and area hits always land."],
	&"netz": ["Netz", "Web",
		"Treffer verlangsamen das Ziel für 2 Züge.", "Hits slow the target for 2 turns."],
	&"gesteinskoerper": ["Gesteinskörper", "Stone body",
		"Gift und Blutung wirken nicht.", "Poison and bleeding have no effect."],
	&"regeneration": ["Regeneration", "Regeneration",
		"Heilt zu Beginn jedes Zuges 5 % der Max-HP, außer bei Brand oder Gift.",
		"Heals 5% of max HP at the start of each turn, except while burning or poisoned."],
	&"wiederkehr": ["Wiederkehr", "Reassemble",
		"Steht einmal mit 30 % HP wieder auf, außer der letzte Treffer war Heilig oder stumpf.",
		"Gets back up once with 30% HP, unless the final hit was holy or blunt."],
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
		"Heilt zu Beginn jedes Zuges 6 % der Max-HP, außer bei Brand.",
		"Heals 6% of max HP at the start of each turn, except while burning."],
	&"fluchspiegel": ["Fluchspiegel", "Curse mirror",
		"Zauberschaden gegen sie wird zu 30 % auf den Zaubernden zurückgeworfen.",
		"30% of spell damage against her is reflected to the caster."],
}


static func fuer(archetype_id: StringName) -> StringName:
	return ZUORDNUNG.get(archetype_id, &"")


static func name_von(eigenheit: StringName) -> String:
	var t: Array = TEXTE.get(eigenheit, [])
	return "" if t.is_empty() else Loc.pick(t[0], t[1])


static func text_von(eigenheit: StringName) -> String:
	var t: Array = TEXTE.get(eigenheit, [])
	return "" if t.is_empty() else Loc.pick(t[2], t[3])
