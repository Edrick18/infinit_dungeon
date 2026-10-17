# Infinit Dungeon — Design-Dokument (Stand: 2026-10-17)

Klassenloses, rundenbasiertes JRPG mit prozedural erzeugten Dungeons, einer Party aus bis zu
vier Helden und freiem Skill-Bau aus Klötzen. Ausrüstung, Waffen-Training und selbst gebaute
Skills bestimmen die Rolle eines Helden. Solo-Hobbyprojekt, Godot 4.7, GDScript.

Dieses Dokument beschreibt den **Ist-Stand**. Zahlen-Details und Messwerte stehen bei den
Systemen; die Entwicklungsgeschichte steht im Vault-Entwicklungslog.

---

## 0. Design-Säulen

Jede neue Idee muss mindestens eine Säule stärken und darf keine verletzen.

1. **Baue deine eigenen Skills.** Der Klotz-Baukasten ist der Kern. Keine fertigen Muster als
   Klotz, jede Eigenschaft hat einen Preis, keine Abklingzeiten — nur Mana.
2. **Jeder Kampf ist eine kleine Frage.** Gegner verlangen unterschiedliche Antworten (Element,
   Schadensart, Kontrolle, Heilung). Was ein Gegner vorhat, zeigt das Spiel nicht an — Raten und
   Lernen gehören dazu. Ausnahme: besonders starke Boss-Angriffe werden angekündigt.
3. **Bosse sind gefährlich.** Auf gleichem Level kann jeder fallen, auch Magier und Heiler mit
   einem Schlag. Der Tank beschützt, Wiederbeleben gehört dazu.
4. **Unendlicher, ehrlicher Fortschritt.** Kein Level-Cap, keine Karten-Obergrenze. Früh schnell,
   ab Stufe 50 Grind; Wiedergeburt statt Deckel.
5. **Respektiere die Zeit des Spielers.** Weniger, dafür lohnendere Kämpfe; kein Kartenverlust bei
   Niederlage; Umbauen überall außer im Kampf.

### Feste Entscheidungen (nicht wieder vorschlagen)
- Keine Abklingzeiten (DQ-Prinzip: jeder Skill jeden Zug, solange das Mana reicht).
- Keine Gegner-Absichtsanzeige; nur Boss-Aufladungen werden angekündigt.
- Kein Taktik-/Auto-Kampf.
- Keine Fallen in Dungeons.
- Keine Unikate/Sets als reine Zufallsdrops.
- Kein Permadeath.
- Spieltexte nur sachlich: Klötze, Lexikon, Banner sagen, was etwas tut — keine Warnungen, keine Tipps.

---

## 1. Technik & Präsentation
- **Engine:** Godot 4.7, GDScript, Renderer gl_compatibility. Windows-EXE-Export.
- **Grafik:** 3D-Spielzeug-Diorama aus Code-Grundkörpern (Kugel, Box, Zylinder/Kegel, Kapsel,
  Prisma) — keine Modelle, Texturen oder Sprites. Verbindliche Regeln in `STIL-3D.md`.
- **Audio:** komplett prozedural, keine Audio-Dateien.
  - Musik = Partituren in `autoload/music.gd` (Tonart, Modus, Akkordfolgen A/B, Form, Instrumente,
    Schlagzeug; Melodie aus einem Motiv je Formteil), Stereo mit Hall + Echo, im Hintergrund-Thread
    gerendert (~2 s je Track). Tracks: menu, stadt, wald, hoehle, ruinen, krypta, kampf, boss, sieg
    (Fanfare + Schleife), niederlage.
  - Effekte in `autoload/sfx.gd` (~47 Klänge, Bus „Effekte“, Tonhöhen-Variation, Drosselung 45 ms);
    jedes Kampf-Ereignis hat seinen Klang (`Sfx.klang_fuer`). WAV-Export: `scripts/dev/musik_export.gd`.
- **Optionen:** Tabs Audio (Gesamt/Musik/Effekte, stumm im Hintergrund), Anzeige (Fenstermodus,
  Auflösung, VSync, FPS-Grenze), Spiel (Sprache DE/EN, Kampftempo 1–3× über `Engine.time_scale`
  nur im Kampf, Bildschirmwackeln), Steuerung (Hotkeys). „Standard wiederherstellen“ lässt
  Hotkeys in Ruhe. Gespeichert in `user://settings.json`, getrennt vom Spielstand.
- **Spielstände:** 5 Slots, Autosave an vielen Punkten (Menü, Ebenenwechsel, Hub-Aktionen).
- **Co-op:** LAN/IP über ENet (`autoload/net.gd`), Karten-Beitritt, Welt- und Kampf-Sync.
- **Tests:** 22 Headless-Selbsttests (`scripts/dev/*_selftest.gd`) + Skript-Check
  (`scripts/dev/skript_check.tscn`, lädt alle Skripte mit Autoloads) + Balance-Simulation
  (`scripts/dev/balance_sim.gd`, Modi per Umgebungsvariable).

---

## 2. Helden & Charakteraufbau
- **Party:** bis zu 4 aktive Helden; in der Taverne bis zu 10 eigene Helden (Name, Farbe,
  Startwaffe aus 8 Ausstattungen). Alle starten gleich: Level 1, 5 Punkte auf jedem Attribut.
- **Attribute:** STR / INT / VIT / SPI / AGI / LCK, linear (1 Punkt = fester Bonus). Je Level 5
  frei verteilbare Punkte. Glück → Krit mit abnehmendem Ertrag (Asymptote 45 %).
- **Ausrüstung:** Waffe, Nebenhand/Schild, Helm, Rüstung, Handschuhe, Stiefel, 2 Ringe, Amulett.
  Zweihänder sperren die Nebenhand. Zweites Waffenset, frei wechselbar im Kampf.
- **Skill-Slots:** 1 + 1 je 5 Level (höchstes je erreichtes Level zählt). Weitere Bauten liegen im
  Rezeptbuch.
- **Rolle** entsteht nur aus Ausrüstung, Punkten, Waffen-Training und Skills — keine Klassen.

### Waffen-Training & Meisterschaft
- Je Level +2 Trainingspunkte (auf Level 50 und 100 je +1) = genau zwei volle Bäume bis Level 100.
- 81 Waffen-Klötze, 7–12 je Waffe, Schwellen 3 bis 100, nur mit der Waffe nutzbar; der höchste
  jedes Baums ist Kern (★). Dazu %-Passive an den Zwischen-Schwellen.
- **Meisterschaft:** Baum auf 100 → Rolle im Meisterschafts-Slot, wirkt mit jeder Waffe und
  stapelt mit der eigenen (Klingenmeister +20 % Parade, Schattentänzer +1 Hieb, Schlächter ×1,5
  unter 50 % HP, Erdbrecher +15 % Betäubung, Adlerauge Krit ×2,5, Belagerer +30 % Durchschlag,
  Erzmagier/Heiliger +50 % Signatur/Heilung, Bollwerk +25 % Block).

### Wiedergeburt
- Ab Level 100 zurück auf Level 1. Es bleiben: Waffen-Training, Meisterschaft, freie Skillpunkte,
  Skills, Ausrüstung und alle Freischaltungen (sie hängen am höchsten je erreichten Level).
- Je Wiedergeburt +10 % auf alle Werte; nach der ersten +1 Sockel pro Skill. Kein XP-Bonus.

### XP & Grind
- XP wird auf die Helden im Kampf geteilt (Gefallene bekommen ihren Anteil).
- **Nachzügler-Bonus:** bei unterschiedlichen Leveln bekommt der niedrigste Held 50 %, die anderen
  teilen sich den Rest. Level-Faktor: −8 %/Level unter dem Gegner (min. 10 %), +5 %/Level darüber
  (max. +50 %).
- **Bank:** 10 % Mittraining bis 5 Level unter dem Schwächsten der Party; Taverne-Training gegen
  Gold auf dieselbe Grenze. Wer einen Helden gezielt leveln will, setzt die anderen auf die Bank.
- XP-Bedarf = quadratische Grundkurve × max(0,22; 0,42 × (Level/10)^1,15).
- **Ziel-Tempo:** bis ~Stufe 45 hält man mit den Belohnungskarten mit, ab Stufe 50 beginnt der Grind.
  Level pro Lauf auf eigener Stufe (4er-Party, jede 2. Gruppe): Stufe 10 ~3,7 · 30 ~3,2 · 50 ~2,0 ·
  100 ~0,7 (Wächter `balance_selftest`). Die Spielzeit in Stunden muss nach der Umstellung auf
  weniger Gegner (2026-10-17) neu gemessen werden — vorher lagen auf hohen Stufen 60+ Gruppen pro Ebene.

---

## 3. Skill-Bau (Kern)

### Grundidee
Jeder baut seine Skills selbst — begrenzt durch Sockel und Freischaltungen. Keine fertigen
Muster als Klotz (Streuung, Hagel, Kette …) und kein reiner „+Schaden“-Klotz: Muster entstehen aus
Grundbausteinen, jede Eigenschaft hat einen Preis. **Der Schaden steckt in der Waffe**, Klötze
bestimmen nur, *wie* er geliefert wird.

### Klotz-Kategorien
1. **Quelle** (mind. 1): **Waffenangriff** (physisch, Schaden + Schadensart + Besonderheit der
   Waffe) oder **Zauber** (Zauberschaden der Waffe + INT). Hybrid Waffe + Zauber ist erlaubt
   (zwei Treffer, beide Kosten).
2. **Element** (max. 1): Feuer, Eis, Blitz, Gift, Heilig, Dunkel — am Zauber voll, an der Waffe als
   halber Zusatztreffer.
3. **Form** (max. 1): Alle Gegner / Verbündeter / Aura / Selbst / Beschwörung; Zielwahl
   (Zufallsziel, Wechselziel) zählt als Form. Waffenangriffe nur mit „Alle Gegner“.
4. **Effekte** (je einmal): Buffs, Debuffs, Schutz, Wiederbeleben, Betäuben … Ziel ist das
   Trefferziel oder (Figuren-Marke) Anwender, Party bzw. alle Gegner. Klötze wirken in Prozent
   (Schild = % Max-HP, Regeneration = % Max-HP/Zug, Wappnen = +% Rüstung).
5. **Eigenschaften:** Zusatztreffer (stapelbar, alle Treffer teilen sich 1 + 15 % je Zusatztreffer;
   mit Zufallsziel = Hagel, Wechselziel = Kette, Überschlag = Überschuss trifft den Nächsten).
   Mit Preis: Präzision, Wucht, Flinkheit, Aufladen, Sparsam, Blutpreis, Alles oder nichts,
   Durchschlag, Schwachstelle suchen, Überladung. Kombos: Ausnutzen, Entzünden, Nachsetzen,
   Zermalmen, Duell, Hinrichtung, Rache. Vollheilung (Kern, ab Level 25).
- **Treffer-Arten:** Krit ×1,5 · Schwachstelle ×2 · beides = Volltreffer ×4.

### Bauregeln
- **Sockel:** 3 auf Level 1, je +1 auf Level 8 / 18 / 30 / 50 und nach der ersten Wiedergeburt
  → max. 8. Gegner haben kein Sockel-Limit.
- Keine Werte-Anforderungen. Jeder Klotz einmal pro Skill (außer Zusatztreffer).
- **Gruppen (◆):** je höchstens ein Klotz (Quellen, Form/Zielwahl, Element, Varianten-Gruppen —
  `BlockLibrary.REGELN/GRUPPEN`). **Kern (★):** höchstens einer pro Skill.
- Regelwidrige alte Skills bleiben gespeichert und werden mit Grund gesperrt.

### Kosten statt Abklingzeit
`Kosten = (Σ Klotz-Grundkosten + Stat-Anteil je Quelle) × Form-Faktor × Π Kostenfaktoren`.
Effekte addieren flach, Eigenschaften multiplizieren und tragen einen Schadensfaktor.
- Waffen-Skills: 1 MP + 3 % der Max-MP, Schaden ×1,2 gegenüber dem freien Angriff.
- Zauber: 3 MP + 15 % INT. Ihre Stärke: Formen, Heilung/Support, volle Element-Signatur,
  magisch statt gegen Rüstung.

### Freischaltung
- **49 universelle Klötze** über das Charakter-Level — Level 1 das Fundament (Waffenangriff,
  Zauber, Selbst, Zusatztreffer, Feuer, Heilig), Level 2–20 jedes Level einer, danach alle 2–5
  Level bis Beschwörung auf 60. Der Level-up nennt sie.
- **81 Waffen-Klötze** über das Waffen-Training (s. o.).

### Werkstatt (UI)
- Sockel-Grid mit Drag & Drop oder Klick; jeder Klotz hat ein 3D-Icon; Sockel färben sich beim
  Ziehen grün/rot (Grund im Tooltip). Regeln in `WerkstattLogik` (getestet).
- Live-Vorschau gegen eine Puppe, ausführlich über „Testen“. 22 Vorlagen, Reparieren alter Skills.
- Rezeptbuch mit beliebig vielen Bauten pro Held. Werkstatt öffnet auch im Dungeon (Taste K).

### Waffen-Besonderheiten
Gelten für jeden Waffenangriff: Dolch trifft doppelt (je 60 %) · Axt höchster Grundschaden und ×2,
danach erschöpft (Klotz „Unermüdlich“ hebt das auf, dann kein ×2) · Bogen 15 % Schwachstelle
(+Glück/3), Pfeile je 60 % · Armbrust durchschlägt 50 % Rüstung + zweites Ziel mit 40 % · Schwert
20 % Parade · Hammer 15 % Betäubung · Offensivstab Element-Signaturen +50 % · Heiligstab Heilung
+50 % · Schild 25 % Block. Dolch-Kern „Serienschlag“: +3 Treffer, jeder aufs selbe Ziel stärker.

---

## 4. Kampf
- Rundenbasiert wie Dragon Quest: **Befehlsphase** (alle Helden planen), dann handeln alle nach
  Zugreihenfolge (Geschick + Würfel). Zugleiste, Kampflog, Schadensvorschau, Typ-Chips.
- Aktionen: Angriff, Skills, Verteidigen, Konzentrieren, Waffenset wechseln, Fliehen.
- **Erstschlag/Hinterhalt:** Kontakt mit dem Rücken eines Gegners → in Runde 1 handelt nur die
  Party; wird man von hinten erwischt, nur die Gegner. Mimics immer Hinterhalt.
- **Überlegenheit:** Party ≥ 8 Level über Karte → normale Gegner fliehen; Berühren = Sofortsieg mit
  halber XP und halbem Gold, ohne Items.
- **Niederlage:** zurück in den Hub, die Karte bleibt erhalten.

### Schaden & Verteidigung
- Achsen: physisch (Stich/Schnitt/Stumpf von der Waffe), magisch (Zauber ohne Element),
  elementar.
- **Rüstung prozentual:** Minderung = Wert ÷ (Wert + K), K = 8 × (Angreifer-Level + 5) × Weltkurve,
  max. 90 %. Tank (schwer) ~50 %, Robe ~20 %.
- **Magieschutz der Helden** = Σ Rüstung × Klassenfaktor (Robe ×4, Leder ×1,2, Kette ×0,6,
  Platte ×0,4).
- **Gegner-Rüstungsklassen:** Fell (Hieb ×1,25 / Stich ×0,6 / Stumpf ×1), Knochen (1 / 1,5 / 0,5),
  Kette, Platte, Leder — Anzeige z. B. „Rüstung −8-16 % (Stich ▲)“.
- **SPI = Support-Wert:** Heilung und Prozent-Effekte × (1 + SPI_roh ÷ (SPI_roh + 60)), max. ×2.

### Elemente & Signaturen
- Feuer: Brand-Stacks (Schaden = Stacks, danach halbieren; ignoriert Magieresistenz).
- Gift: Stacks bleiben bis zur Kur (Tick ≤ 3 % Max-HP; Blutung ebenso).
- Eis: Einfrieren oder Verlangsamen, Direktschaden ×1,3.
- Blitz: springt auf Nachbarn, Betäubungs-Chance, Direktschaden ×1,25.
- Heilig: Bonus gegen Untote, heilt Verbündete. Dunkel: Lebensraub + Fluch.
- Element-Signatur additiv: Stab +50 %, Erzmagier +50 %, Element-Fokus +100 % = ×3.
- **Schwächen/Resistenzen** je Grundtyp ×1,5 / ×0,5 (`EnemyLibrary.SCHWAECHEN`); werden erst
  nach dem ersten Treffer sichtbar und dauerhaft im Bestiarium gespeichert.
- Brand auf Helden ≤ 10 % Max-HP pro Tick.

### Buffs & Debuffs (DQ9-Stufen)
Stärken, Wappnen, Magieschild, Elementschutz, Schwächen, Rüstungsriss, Verlangsamen, Magiebruch,
Elementschwäche stapeln zweimal (Stufe 2 = doppelt), danach nur Auffrischen. Deckel: Stärken 60 %,
Wappnen 100 %, Schilde 50 %.

### Schutzwall
Fängt alle Angriffe auf Verbündete ab, bei Flächen jeden Treffer einzeln; der Beschützer kann
daran sterben. Hält nur die Runde, in der er eingesetzt wird, keine Abklingzeit; geplant steht er
ab Rundenbeginn, auch wenn der Beschützer langsam ist.

---

## 5. Gegner & Bosse

### Aufbau (geschichtet)
- **33 Grundtypen** über 4 Biome (`scripts/data/enemy_library.gd`), plus Mimic (nur Risiko-Truhe).
- Schichten: 4 Regionsvarianten, 5 Element-Schichten (ab Stufe 2/3/5/7/9), 17 Klassenvarianten,
  6 Elite-Modifikatoren (Elite 25 %), Champion (8 % ab Stufe 5), 4 Anführer-Affixe (stärken jeden
  Zug ihre Gruppe, ×1,5 Beute/XP; Gegenmittel Klotz „Entzaubern“).
- **Sondergegner:** Güldener 3 % (Gold ×6, XP ×1,5), Strahlender 3 % (XP ×8), Kartenhüter 1 % ab
  Stufe 4 (Schatzkarte episch/legendär).
- **Untot-Tag** (Skelett, Kultist, Geist, Nekromant) → Heilig-Bonus.
- 50 Grund-Skills + 56 Kombo-Skills, alle aus dem Klotz-System der Spieler gebaut.
- **KI:** gemeinsame Routine (heilen unter 50 %, sonst Buff/Beschwörung, sonst Angriff) mit
  schlauer Zielwahl (Hinrichtung auf wenig HP, Elemente auf Schwächen).
- **Eigenheiten (2026-10-17):** jeder normale Grundtyp hat eine eigene Kampfregel
  (`scripts/combat/eigenheiten.gd`, 30 Stück, z. B. Rudel, Taschendieb, Teilung, Flatterhaft, Netz,
  Gesteinskörper, Wiederkehr, Körperlos, Totenruf, Feuerseele, Neun Leben, Fluchspiegel). Keine
  Vorab-Anzeige; nach dem ersten Auslösen im Tooltip und Bestiarium (`GameState.eigenheit_wissen`).
- **Gegner-Schere:** zusätzlich zur Weltkurve ab Stufe 25 (`BRUTAL_RAMPEN`), wirkt voll auf HP,
  halb auf Schaden.
- Dynamischer Bestand: Gegner ziehen nach 2–4 min weiter, freie Plätze werden weit weg neu besetzt.

### Bosse
- 11 Grundtypen können Boss sein, 3 nur als Boss (Schleimgott, Todesmeister, Dämonen-König).
- **Signaturen** ab Stufe 3: Wut (Bär), Steinpanzer (Golem), Regeneration (Troll), Beschwören
  (Kultist, Nekromant), Haltung (Schattenbestie), Verschlingen (Schleimgott).
- **Aufladung:** alle 4 eigenen Züge ein angekündigter Flächenangriff (×1,25), Betäuben bricht ihn.
- **Bannwelle** ab Stufe 20: hebt Helden-Buffs auf und Boss-Debuffs ab, sobald sich das lohnt.
- **Vernichtende Treffer:** +10 % Krit, Krit ×2. Kontrolle: halbe Chance, +50 % Resistenz je Erfolg.
- Nachschub-Wellen bei 66 % und 33 % HP.
- Werte: HP ×6 (Rampe +1,2 %/Stufe von 10 bis 60), Schaden ×1,9 (Rampe bis ×2,5 auf 60).
- **Messstand 2026-10-16** (Sim, gleiches Level): Sieg 80–98 %, Tod in 45–90 % der Kämpfe,
  Wiederbelebung 0,6–2,4/Kampf, One-Shots Magier 2–12 %, Heiler 0–4 %, Tank 1–6 %; Tank fängt
  55–63 %; 7–15 Runden. Rückstand: Stufe 50 mit Lv 45 ~42 %, Stufe 100 mit Lv 95 ~62 %.

---

## 6. Dungeons & Karten
- **Karten** sind gespeicherte, wiederholbare Dungeons: Stufe = Gegnerlevel, Biom, Rarität
  (5 Stufen), 0–2 Karten-Affixe (Reich, Bevölkert, Schatz, Elitär, Uralt, Gefährlich), fester
  Seed. Legendäre Karten mit mitwachsendem Boss, Schatzkarten.
- Nach einem Abschluss gibt es eine neue Karte (Stufe ±, steigt ~2,5 Stufen pro Lauf).
- **Kartenlager:** 25 Plätze, gegen Gold erweiterbar (+5), Favoriten, Notizen, Archiv (15).
- **Biome:** Wald ab 1, Höhle ab 3, Ruinen ab 5, Krypta ab 7 — alle bleiben im Pool.
- **Ebenen:** Stufe 1–4 eine, je 4 Stufen eine mehr (max. 5); Boss auf der untersten.
  3 Layouts (Höhlen, Räume, Tunnel), Größe 48×36 wachsend bis 88×76.
- **Gegnerdichte (2026-10-17):** 8 + 2 Gruppen je Größenstufe, also 8–16 pro Ebene (Bevölkert +3).
  Ausgleich `DungeonGenerator.beute_faktor`: XP, Gold und Drop-Chancen normaler Gegner steigen so,
  dass eine Ebene so viel abwirft wie früher mit 6 + Stufe + 2 je Größenstufe Gruppen (Faktor 1 auf
  Stufe 1, ×1,7 auf 10, ×4,25 ab 75). Drop-Chancen über 100 % geben mehrere Drops. Bosse unverändert.
- **Ereignisse:** 4 Schreine (Heilung, Mana, Kraft, Schutz), Opferstein (15 % HP je Held für Beute),
  Risiko-Truhe (50 % Beute + Medaille, 50 % Mimic).
- **Besondere Dungeons (2026-10-17, `scripts/dungeon/sonderregeln.gd`):** ab Stufe 3 trägt eine Karte mit
  8–25 % (nach Rarität) eine Sonderregel: Elementarsturm (alle Gegner ein Element, +25 % Beute),
  Totenreich (alle untot, +15 % HP, +30 % XP), Jagdgebiet (Elite-Anführer, Champions ×2, +40 % Beute),
  Riesenwuchs (≤ 2 pro Gruppe, +80 % HP/XP/Beute, +25 % Schaden), Manaflut (MP-Kosten ×0,5 für alle),
  Schatzfieber (Truhen ×2, jede 4. ein Mimic).
- **Tresor (Ebenen-Ziel):** ab Stufe 2 auf ~25 % der Ebenen (Sonder-Dungeons 50 %), eigener Würfel. Ein
  Gegner der Ebene trägt den Schlüssel (schwebt über ihm, zieht nicht weiter); Sieg über ihn = Schlüssel.
  Inhalt: episch (20 % legendär), 5× Truhen-Gold, 1 Mini-Medaille.
- Anschleichen: ruhende Gegner sehen nur nach vorn (±110°) plus Hörradius.

---

## 7. Beute & Wirtschaft
- **Items:** 32 Basen, 34 Affixe (16 Präfixe, 18 Suffixe), 5 Raritäten, Affix-Qualität.
  Affixe wirken in Prozent.
- **Tränke:** % der Max-HP/MP oder ein Festwert, je nachdem was höher ist. Keine Trank-Drops —
  Tränke kommen vom Händler/Alchemisten. Pro Leiden ein Kur-Trank, Allheilmittel aus allen fünf.
  16 Verbrauchsgüter. Der Hub heilt immer voll.
- **Werkstoffe:** Erz/Leder/Kristall in 5 Stufen (Eisen, Stahl, Mithril, Adamant, Sternen), Drop-
  Stufe nach Kartenstufe (ab 1/8/18/32/50); Kräuter; Runen (Boss, 25 %) garantieren beim Schmieden
  Selten/Episch/Legendär.
- **Schmiede:** Werkstoff + Item-Level + optionale Rune; Basis, Rarität, Affixe sind Zufall.
  Affixe neu würfeln.
- **Händler & Alchemist:** Tränke, Kräuter, Eisen-Werkstoffe, Ausrüstung gegen Gold (Art wählbar),
  Brauen, 3 wechselnde Aufträge (Liefern, Jagen, Biom säubern).
- **Mini-Medaillen** (Truhen, Risiko-Truhen, Bosse): Schmiede-Paket (3), Wunschkarte (5),
  garantiert episches Item (8).

---

## 8. Hub
Hauptmenü mit Dungeon fortsetzen, Kartenlager, Stadt, Skill-Werkstatt, Ausrüstung, Lexikon; in der
Ecke Co-op, Spielstände, Speichern, Optionen.
- **Stadt** (ein Ort, drei Tabs): Taverne (Helden anlegen, Bank, Training gegen Gold), Händler &
  Alchemist, Schmiede.
- **Werkstatt** (Skill-Bau) und **Training** (Waffen-Bäume, Meisterschaft, Wiedergeburt).
- **Lexikon** (32 Einträge) mit Bestiarium (Fortschritt X/33, Element-Wissen).

---

## 9. Story & Setting
Klassisches High Fantasy, Story bewusst minimal — der Fokus liegt auf Bauen, Beute und Kampf.

---

## 10. Offene Entscheidungen
- **Forschungstisch:** im Code nur angelegt (`UnlockKind.RESEARCH`, Knopf in der Werkstatt), kein
  Klotz nutzt ihn. Streichen oder ausbauen?
- **Feste Rekruten** mit Namen, Aussehen und einer kleinen Eigenheit statt nur selbst erstellter
  Helden?
- **Co-op:** weiter ausbauen oder auf „funktioniert, wird nicht erweitert“ setzen?

## 11. Fahrplan (Design-Review 2026-10-17)
1. Dieses Dokument auf den Ist-Stand bringen, Säulen festlegen. ✔
2. Eigene Verhaltensregeln je Gegnertyp (ohne Absichtsanzeige). ✔ (Eigenheiten)
3. Weniger Gegner pro Ebene, dafür mehr XP und Beute je Gegner. ✔
4. Besondere Dungeons: Karten mit Spielregel-Affixen und Nebenzielen pro Ebene. ✔ (Sonderregeln, Tresor)
5. Medaillen-Stufen und Regelbrecher-Affixe (gezielt über die Schmiede erreichbar).
6. Spielrunde ab Neustart (2–3 h) mit Notizen — erst danach wieder Balance.
