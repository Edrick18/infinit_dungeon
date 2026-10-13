# STIL-3D — Design-Standard „Infinit Dungeon 3D"

Verbindliche Regeln für ALLE 3D-Grafik. Umsetzung: `scripts/stil3d/`
(`Stil3D` = Bausteine, `FigurenBau` = Figuren/Objekte), Vorschau:
`scenes/stil3d/stil_showcase.tscn` (F6).

## 1. Grundsatz: Spielzeug-Diorama aus Grundkörpern
Alles entsteht im Code aus fünf Grundkörpern — **Kugel, Box, Zylinder/Kegel,
Kapsel, Prisma**. Keine externen Modelle, keine Texturen, keine KI-Bilder.
Warum: endlos erweiterbar, jede Variante ist ein Parameter (Farbe, Maß,
Zusatzteil), alles bleibt automatisch stilgleich.

## 2. Maßstab & Ausrichtung
- 1 Einheit = 1 Dungeon-Feld. Boden bei y = 0. Figuren blicken nach +Z.
- Normale Gegner 0.6–1.0 hoch, große 1.2–1.5, Bosse bis 2.0
  (zusätzlich `sprite_scale` der Archetypen gilt weiter als Skalierung).
- Proportionen leicht chibi: Köpfe groß, Beine kurz, Silhouette vor Detail.

## 3. Formensprache
- **Rund** (Kugel, Kapsel) = weich, flink, verspielt (Schleim, Fledermaus).
- **Kantig** (Box) = schwer, gepanzert, Konstrukt (Golem, Truhe, Mauern).
- **Spitz** (Kegel, Prisma) = gefährlich (Zähne, Hörner, Mähne, Flügel).
- Ausdruck über das Gesicht: Cartoon-Augen (`Stil3D.auge`) + böse Brauen
  (`Stil3D.braue`), kleine Zähne. Frech-fies, nie Horror.

## 4. Farbe
Nur Farben aus `Stil3D.PAL` (Hauspalette, Grundton Nachtblau `#14141f`,
Akzent Gold `#e8b44a`). Neue Farbe = erst in PAL aufnehmen, dann benutzen.
Helligkeits-Variation per Faktor (z. B. `farbe * 0.93`), nie freie Hexwerte.

## 5. Licht & Shader
- Toon-Shader mit **zwei harten Lichtstufen** (Cel-Shading).
- Schattenseiten tönt das **violette Umgebungslicht** — nie schwarz.
- Hauptlicht warm, von rechts-hinten (Kontrast statt Frontalbrei).
- Fackeln: orange Punktlichter, Energie ~0.7, flackern.
- Schmaler Randlicht-Saum, Leuchtteile (Augen, Kristalle, Flammen) über
  `leuchten` + Glow.

## 6. Kontur
- Dunkle Kontur `#14141f`, Dicke 0.022, um jede Figur und jedes Objekt
  (Inverted Hull) — das Erbe der Pixel-Ära, hält alles lesbar.
- **Maße gehören ins Mesh, nie in die Node-Skalierung** (sonst wird die
  Kontur ungleich dick).
- Kleinteile ohne Kontur: Pupillen, Zähne, Glanzpunkte, Bänder, Gürtel.
- Bodenplatten ohne Kontur — die dunklen Fugen übernehmen das.

## 7. Kameras
- **Erkunden:** orthografisch, 45°-Diorama-Blick (Position ~(11, 12.5, 11)
  relativ zum Ziel), `size` ~8.8.
- **Kein Fog of War:** Alles auf dem Bildschirm ist sichtbar, keine
  Überraschungen. Wände blockieren nur die Sicht der GEGNER auf den
  Spieler, nie die Sicht des Spielers.
- **Wände (Glas-Regel):** Jede Wand = fester dunkler **Sockel** (0.3 hoch,
  mit Kontur — zeigt IMMER, wo die Wand steht) + Körper und Deckel. Eine
  Wand blendet in ~0.3 s zu **Glas** über (Deckkraft 0.22, Kanten und
  Deckel etwas deckender, kein Schatten), sobald sie im 45°-Blick den
  Helden **oder** einen Gegner, eine Truhe, die Treppe oder ein Event
  verdeckt (Wand liegt auf deren x+z-Diagonale davor und seitlich nah).
  Alle anderen Wände bleiben massiv. Nie Wände ganz ausblenden — Gänge
  und Durchgänge müssen lesbar bleiben.
- **Kampf:** Perspektive, FOV 36, leicht erhöht. Monster in
  **3/4-Ansicht zur Bildmitte gedreht** (JRPG-Klassiker) — frontal wirken
  Schnauzen-Figuren wie Masken.

- **Steuerung bildschirmrelativ:** „W" = im Bild nach oben (Karten-
  Diagonale), nicht Karten-Norden (`DungeonWelt3D.bildschirm_zu_karte`).
  Mausrad zoomt (6.5–16, Start 10.5).

## 7b. Dungeon-Umsetzung (`scripts/dungeon/dungeon_welt_3d.gd`)
- Reine Anzeige: Die Spiellogik rechnet weiter in Karten-Pixeln
  (32 px = 1 Feld = 1 Welteinheit, Karten-y = Welt-z) und ruft jedes Bild
  `aktualisieren()` auf.
- Boden und Wände als **MultiMesh** (Instanzfarbe über `COLOR`), nur
  Wände an Bodengrenzen werden gebaut — Räume schweben im Nachtschwarz.
  Glas-Wände: Instanz wird versteckt, ein Glas-Block blendet über.
- Figuren je Archetyp aus `FigurenBau.fuer_archetyp()` (Baukästen
  zweibeiner/vierbeiner/schleim/krabbler/golem/…), Truhenbänder in
  Raritätsfarbe, Schreine je Typ eingefärbt, Biom tönt Boden/Wände.
- Licht: Sonne + Laterne über dem Helden + vereinzelte Wandfackeln.
- Leistung (RX 7900 GRE): 144 FPS (Bildschirmlimit) auch bei 88×76.
- Dev-Screenshot: `scripts/dev/dungeon_shot.tscn -- --shot=<png>
  [--frames=N] [--zoom=Z] [--stufe=S] [--taste=move_up]`.

## 7c. Kampf-Umsetzung (`scripts/stil3d/kampf_buehne_3d.gd`)
- 3D-Arena hinter der unveränderten Kampf-UI (Host + Co-op-Gast), Biom
  tönt Boden und Säulen. Kamera perspektivisch, FOV 38, steil genug, dass
  die Gegner-Panels (oberes Bilddrittel) den Boden VOR den Säulen treffen.
- **Die UI bleibt Herr:** Jedes Gegner-Panel hat einen unsichtbaren
  Platzhalter (128 px × `sprite_scale`, Boss ×1.2). Die Figur stellt
  sich jedes Bild auf dessen Fußpunkt (Strahl auf den Boden) und skaliert
  so, dass eine 1 Einheit hohe Standardfigur den Platzhalter füllt —
  Eigengröße (Troll 1.4, Katze 0.8) wirkt zusätzlich. Klicks, Tooltips,
  Schadensvorschau und Layout funktionieren dadurch unverändert.
- Animationen laufen weiter als Tweens auf dem Platzhalter; die Figur
  übernimmt sie: Puls » Ausfallschritt zur Kamera, Rotation » Taumeln.
  Treffer/Heilung = `material_overlay`-Blitz, Besiegte verpuffen drehend.
- Vierbeiner/Krabbler/Igel tragen Meta `drehung` » 3/4-Ansicht zur Mitte.
- Kleine Bilder (Zugleiste, Party) rendert `PortraitStudio` einmal aus
  der 3D-Figur (eigene SubViewport-Welt, UPDATE_ONCE). Heldenfarbe kommt
  aus `FigurenBau.held_farbe(name)` — überall gleich.

## 7d. Helden, Ränge, Menüs
- **Helden zeigen ihre echte Ausrüstung** (`FigurenBau.held_aus`): Waffe
  (Schwert/Großschwert, Axt/Großaxt, Keule/Hammer, Dolch, Bogen,
  Armbrust, Turmschild, Stab mit Licht), Nebenhand (Schild, Köcher,
  Dolch, Buch, Fokus) und Rüstungsklasse (Platte/Kette = Helm, Leder =
  Kapuze, keine = Haare; Stab ohne Platte = Robe).
- **Rüstungsfarbe ist frei wählbar** (ersetzt die alte Porträtwahl; der
  gespeicherte `portrait_tile` ist jetzt der Farbindex — alte Spielstände
  behalten ihre Wahl). Ohne Wahl: Farbe nach Namen.
- **Ränge:** Elite = violette Aura, Champion = rote Aura mit Zacken,
  Güldene = goldener Glanz mit wanderndem Streifen (Material-Overlay;
  Treffer-Blitze stellen den Glanz danach wieder her).
- **Riesen-Deckel:** Kampf-Figuren ragen nie über die Zugleiste.
- Menüs: drehende `FigurenVorschau` (Inventar, Taverne, Heldenerstellung,
  Titel), Porträts aus `PortraitStudio` auf Knöpfen und Listen.

## 7e. Menü-Kulisse & UI (`scripts/stil3d/menue_kulisse.gd`, `scripts/ui/`)
- **Alle Menüs sind 3D:** `UiTheme.make_background(ort, ruhig)` liefert
  `MenueKulisse` — ein Diorama (Steininsel, Ruinenbogen, zwei Fackeln)
  mit der **eigenen Party**, Kamera pendelt langsam (±0.55 rad).
  Herzstück je Ort: `lager` (Lagerfeuer, Standard), `taverne` (Tisch mit
  Krügen + Kerze), `schmiede` (Esse + Amboss + Waffenständer), `laden`
  (Tresen, Trankregal, Münzen, Truhe). Schleier 0.30 bzw. 0.68 bei
  `ruhig` (Inventar, Lexikon, Werkstatt …) + radiale Vignette.
- Aufheller von vorn, damit Gesichter trotz Gegenlicht lesbar bleiben.
- **Theme = Spielzeugklötze:** Knöpfe mit dunkler Unterkante (4 px), Hover
  = Goldrand, Drücken sinkt ein; Tafeln halbtransparent mit Schatten und
  hellem Saum oben; Labels mit Schlagschatten (Text über 3D).
  Gewählte Reiter: `UiTheme.als_aktiv()` (gold statt ausgegraut).
- **Kampf-UI (`KampfUi`, Host + Gast):** Log über den Party-Karten neben
  den Befehlen (Arena bekommt die Mitte), Log blendet erst mit der
  ersten Zeile ein; Party-Karten mit Porträt und Zahlen auf HP/MP; HP
  wird unter 50 % gold, unter 25 % rot; Held am Zug = Goldrahmen.
  Arena-Boden aus Steinplatten-Ringen (MultiMesh) + Biom-Deko am Rand.
- **Dungeon-HUD (`DungeonHud`):** Titel + Wert-Chips oben links,
  Party-Karten unten links, Tastenkappen unten rechts, Meldungen oben
  mittig auf einer Glastafel, Minimap oben rechts.
- **Bildschirm-Vorlage (`Bildschirm.bauen`, UI-Layout-Pass 2026-10-14):**
  jede Menü-/Hub-Szene außer dem Hauptmenü nutzt sie. 24 px Rand, ruhige
  Kulisse; Kopfzeile = Titel links, Info-Chips (`b.info`, Gold, Punkte …) +
  Zusatzknöpfe + **„‹ Ziel“-Zurück rechts** (Esc löst ihn aus); Stadt-Reiter
  über der Kopfzeile; Untertitel = eine gedämpfte Erklärzeile. Inhalt in
  Glastafeln (`Bildschirm.tafel`), Listen nur senkrecht scrollend
  (`Bildschirm.scroll_liste`), lange Texte mit Autowrap — nie quer scrollen.
  Tastatur-Fokus startet im Inhalt (Kopfzeile/Reiter tragen `nicht_zuerst`).
- Falle: `Range` (ProgressBar) meldet `value_changed` nur im Baum —
  Anzeigen beim Einhängen (`_ready`) nachziehen.

## 7f. Kampf-Effekte (`scripts/stil3d/kampf_effekte.gd`)
- **Quelle:** `Battle.effekt` meldet darstellbare Ereignisse (element, waffe, magie,
  heilung, status, dot, krit, block) — die Kampflogik bleibt UI-frei. Die Kampfszene
  sammelt sie pro Aktion und spielt sie VOR den Schadenszahlen ab; Co-op-Gäste
  bekommen sie als Netz-Nachricht `fx` (Netz-IDs statt Kämpfern).
- **Aus Grundkörpern:** Kugel-Explosion, Funken (CPUParticles3D), Ring (TorusMesh),
  Lichtsäule, Eissplitter (Prismen), Blitz (Zickzack aus dünnen Boxen), Implosion,
  Hieb (gestreckte Box). Shader: unshaded, gemischt (nicht additiv — sonst wird auf
  hellem Boden alles weiß), satter Kern + heller Fresnel-Rand.
- **Element-Signaturen:** Feuer = Explosion + Funkenregen · Eis = Splitter ·
  Blitz = Strahl vom Himmel · Gift = aufsteigende Blasen · Heilig = Lichtsäule ·
  Dunkel = Implosion. Zauber und Fernkampf fliegen als Projektil mit Schweif
  (Zauber im Bogen, Pfeile gerade), 0.22 s.
- **Helden** sind Karten in der UI → ihre Effekte sind 2D (weiche Lichtpunkte +
  Farbblitz über der Karte), sonst lägen sie hinter der UI. Nahkampf hinterlässt
  Krallenspuren, Treffer schütteln die Karte (Rotation, containersicher).
- **Wucht:** kurzes farbiges Aufleuchten am Ziel (OmniLight, nur Akzent — Energie
  ×0.22, sonst flutet es den hellen Boden), Rückstoß der Figur von der Kamera weg,
  Bodenwelle bei Krit und Schwäche, Mündungsblitz beim Werfer, Rauchwolke beim Tod.
- **Dauerzustände an den Figuren** (`KampfBuehne3D.status_setzen`): Brand =
  flackernde Flammen, Gift/Blutung/Regeneration = Partikel, Gefroren = Eispanzer,
  Betäubt = kreisende Sterne am Kopf, Schild/Schutzwall = Blase, Gestärkt/Gewappnet/
  Verlangsamt = Bodenring, Markiert/Verflucht = Zeichen über dem Kopf. Höhen in den
  Maßstab der Figur umrechnen (große Figuren haben Eigen-Skalierung).
- **Popups** gestapelt über dem Ziel: „SEHR EFFEKTIV!" (gold), „kaum Wirkung …"
  (grau), „KRITISCH!" (orange, plus Kamerastoß), „Block!". Schadenszahlen größer,
  mit Kontur und kurzem Aufploppen.
- Dev: `dungeon_shot.tscn -- --szene=res://scenes/battle/battle_scene.tscn --stufe=7
  --fxtest [--fxzeit=0.3]` (Standbild mitten im Effekt) · `--auto` spielt echte Runden.

## 8. Lebendigkeit
Keine Skelett-Animationen. Bewegung entsteht aus Transform-Tweens:
Idle-Wippen (Meta `wippen`), Schleim-Quetschen (Meta `quetschen`),
Fackel-Flackern; Angriffe/Treffer als Squash & Stretch, Sprünge, Wackeln.

## 9. Varianten (passt zum Gegner-Baukasten)
Varianten = Palettentausch + Zusatzteile: Elite/Champion bekommen Hörner,
Krone, Aura-Ring; Elemente färben Akzente (Feuer = Flamme/Glut, Gift =
Moos/Schleim, Eis = Kristall). „Güldene" Gegner: Gold-Palette.

## 10. Technik-Fallen
- Renderer bleibt **Compatibility** (läuft überall); MSAA 4×, Glow an.
- `Environment.background_color` erwartet **lineare** Farbe →
  `PAL["nacht"].srgb_to_linear()`, sonst wird der Hintergrund lila.
- Klassen-Aliase per `const X := Klasse` werden nicht als Konstante
  akzeptiert → Klassennamen direkt verwenden.
- Screenshot-Modus der Showcase: `-- --shot=<pfad.png> [--modus=kampf]`.
