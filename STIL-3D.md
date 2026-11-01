# STIL-3D — Design-Standard „Infinit Dungeon 3D"

Verbindliche Regeln für ALLE 3D-Grafik. Umsetzung: `scripts/stil3d/`
(`Stil3D` = Bausteine, `FigurenBau` = Figuren/Objekte), Vorschau:
`scenes/stil3d/stil_showcase.tscn` (F6).

## 1. Grundsatz: Spielzeug-Diorama aus Grundkörpern
Alles entsteht im Code aus fünf Grundkörpern — **Kugel, Box, Zylinder/Kegel,
Kapsel, Prisma** (dazu die gefaste Box `WeltMaterial.fasen_box`). Keine
externen Modelle, keine Bilddateien, keine KI-Bilder. Oberflächen-Material
(Mauerwerk, Plattenrisse, Moos, Runen) entsteht **prozedural im Shader** aus
der Weltposition — es ist Bemalung, keine Textur.
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
Biom-Flächen, Leuchtfugen und Untergrund stehen als eigene PAL-Einträge
(`wald_boden`, `krypta_fuge`, `hoehle_tief` …) und werden über `BiomStil`
benutzt. Lichtfarben (Sonne, Umgebung) sind Lichtwerte, keine Flächenfarben.

## 5. Licht & Shader
- Toon-Shader mit **zwei harten Lichtstufen nur auf dem Lichteinfall N·L**
  (Cel-Shading, `Stil3D.TOON_LICHT`). Die Reichweite der Punktlichter
  (ATTENUATION) läuft **weich** aus — keine harten Laternen-Scheiben oder
  Fackel-Ellipsen. Alle Stil-Shader (Figuren, Wände, Boden) teilen diesen
  Licht-Block.
- Schattenseiten tönt das **violette Umgebungslicht** — nie schwarz.
- Hauptlicht warm, von rechts-hinten (Kontrast statt Frontalbrei).
- Fackeln: orange Punktlichter, flackern. Im Dungeon tragen sie kein
  eigenes Licht (Licht-Pool, 7b); in Menü und Kampf je ein OmniLight mit
  flachem Abfall (`Stil3D.PUNKTLICHT_ABFALL`) und Energie mal
  `Stil3D.PUNKTLICHT_AUSGLEICH` — sonst verlören Fackeln und Feuer dort mit
  der weichen Abschwächung ihre warmen Flecken.
- Schmaler Randlicht-Saum, Leuchtteile (Augen, Kristalle, Flammen) über
  `leuchten` + Glow.

## 5b. Bildstimmung „Spielbrett im Laternenschein" (Dungeon)
- **Grundhelligkeit wie ein beleuchtetes Spielbrett** — gut lesbar, kein
  Fog of War, nichts versinkt im Dunkeln. Darüber eine **warme
  Laternen-Insel** um den Helden und warme Fackel-Lichtpunkte.
- **Tonemapping Filmic** (`Stil3D.umgebung`, Belichtung 0.9), Glow ab 0.9,
  leichte Sättigung/Kontrast. AgX wäre in Compatibility 4.7 verfügbar,
  bleicht aber Flammen, Augen und Gold zu Weiß aus. Debanding am Viewport
  an, Vignette als CanvasLayer (-1) unter der UI mit geditherter Blende.
- **Material (Spielbrett):** Mauerwerk aus der Weltposition — Ziegel (Wald,
  Ruinen mit größeren Quadern), Bruchstein (Höhle), Gruftquader (Krypta);
  Moos kriecht von unten (Wald, Höhle), gefaste Decksteine mit leichtem
  Höhen-Jitter. **Der Deckel ist nie die hellste Fläche** (dunkler als der
  Boden; Kontur und Sockel zeigen die Wand). Boden = gefaste Platten mit
  Abnutzung, Abplatzern, Rissen; Biom-Zweig (Moos, Pfützen, Flecken,
  Runenkreise) und Umgebungsverdeckung an Wandfüßen.
- **Leuchtfugen (dezent):** Boden- und Mauerfugen, Krypta-Runen glimmen in
  Biomfarbe — fast aus in der Ferne, in Heldennähe stärker (Uniform
  `held_pos`). Nie heller als die Glow-Schwelle außer direkt am Helden.
- **Untergrund:** Sternen-Nebel in Biomfarbe unter der Karte statt schwarzer
  Leere (auch auf der Boss-Ebene), mit künstlicher Parallaxe (das Muster
  wandert mit dem Kamera-Ziel).
- **Atmosphäre:** wenige Partikel um das Kamera-Ziel — Wald Glühwürmchen,
  Höhle Tropfen, Ruinen Asche, Krypta Irrlichter.
- Alle Werte je Biom stehen in **einem** Datensatz: `BiomStil`
  (`scripts/stil3d/biom_stil.gd`): Flächen, Muster, Moos, Fugenfarbe,
  Umgebungs-/Sonnen-/Laternenlicht, Untergrund, Partikel.

## 6. Kontur
- Dunkle Kontur `#14141f`, Dicke 0.022, um jede Figur und jedes Objekt
  (Inverted Hull) — das Erbe der Pixel-Ära, hält alles lesbar.
- **Maße gehören ins Mesh, nie in die Node-Skalierung** (sonst wird die
  Kontur ungleich dick).
- Kleinteile ohne Kontur: Pupillen, Zähne, Glanzpunkte, Bänder, Gürtel.
- Bodenplatten ohne Kontur — die dunklen Fugen übernehmen das.
- Wände mit Screen-Door-Glas: Kontur über `Stil3D.kontur(modus, true)` —
  sie liest dieselbe Deckkraft (INSTANCE_CUSTOM.a) und lässt dieselben
  Bildpunkte aus, sonst bliebe eine dunkle Hülle stehen.

## 7. Kameras
- **Erkunden:** orthografisch, 45°-Diorama-Blick (Position ~(11, 12.5, 11)
  relativ zum Ziel), `size` ~8.8.
- **Kein Fog of War:** Alles auf dem Bildschirm ist sichtbar, keine
  Überraschungen. Wände blockieren nur die Sicht der GEGNER auf den
  Spieler, nie die Sicht des Spielers.
- **Wände (Glas-Regel):** Jede Wand = fester dunkler **Sockel** (0.3 hoch,
  mit Kontur — zeigt IMMER, wo die Wand steht) + Körper und Deckel. Eine
  Wand wird in ~0.3 s **durchsichtig** (Deckkraft 0.25), sobald sie im
  45°-Blick den Helden **oder** einen Gegner, eine Truhe, die Treppe oder
  ein Event verdeckt (Wand liegt auf deren x+z-Diagonale davor und
  seitlich nah). **Kein Milchglas:** Der opake Wand-Shader lässt Bildpunkte
  nach einem 4×4-Bayer-Muster aus (Screen-Door, Deckkraft je Instanz in
  `INSTANCE_CUSTOM.a`); Kanten bleiben deutlich dichter, die Kontur
  dithert mit. Was dahinter steht, erscheint in voller Farbe — der Held
  wird nie ausgewaschen. Alle anderen Wände bleiben massiv. Nie Wände ganz
  ausblenden — Gänge und Durchgänge müssen lesbar bleiben.
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
- Boden und Wände als **MultiMesh** (Instanzfarbe über `COLOR`,
  Zusatzdaten über `INSTANCE_CUSTOM`) mit den Shadern aus `WeltMaterial`
  (`scripts/stil3d/welt_material.gd`); nur Wände an Bodengrenzen werden
  gebaut — Räume schweben über dem Sternen-Nebel. Glas-Wände: nur die
  Instanz-Deckkraft ändert sich (keine Extra-Nodes, keine Transparenz).
- Figuren je Archetyp aus `FigurenBau.fuer_archetyp()` (Baukästen
  zweibeiner/vierbeiner/schleim/krabbler/golem/…), Truhenbänder in
  Raritätsfarbe, Schreine je Typ eingefärbt. Jede Figur am Boden hat einen
  weichen **Blob-Schatten** (bleibt beim Schweben am Boden, wird kleiner),
  der eigene Held zusätzlich einen goldenen **Bodenring** und einen
  leichten **Lauf-Hopser** (`WeltBau.naechster_hopser`).
- **Licht:** Sonne (Biomfarbe) + warme Laterne über dem Helden + **Licht-
  Pool** aus 6 echten OmniLights, die jedes Bild an die nächsten Fackeln
  um das Kamera-Ziel wandern (`WeltBau.pool_auswahl`, zum Rand weich
  ausgeblendet). So bleiben es 7 Punktlichter — unter den Compatibility-
  Grenzen 8 pro Objekt (der Boden ist EIN Objekt) und 32 gesamt, egal wie
  viele Fackeln die Karte hat. Fackeln hängen in einem Wandhalter
  (`FigurenBau.fackel(false, true)`). Keine Uniform-Arrays, keine
  Licht-Schleifen im Shader.
- Reine Funktionen (Wandhöhe, Pool-Auswahl, Hopser) in `WeltBau` — ohne
  Autoloads, darum headless testbar (`grafik_selftest.gd`).
- Leistung (RX 7900 GRE, ohne VSync, Stufe 20 / 88×76, Mittel der Bilder
  400–800): vorher ~430 FPS, nachher ~410 FPS; mit VSync 144 (Bildschirm).
- Dev-Screenshot: `scripts/dev/dungeon_shot.tscn -- --shot=<png>
  [--frames=N] [--zoom=Z] [--stufe=S] [--biom=0..3] [--ebene=N]
  [--taste=move_up] [--ohne-vsync]` — gibt „FPS-Mittel (2. Hälfte)" aus.

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
  Skill-Knöpfe mit Tooltip (`KampfUi.skill_knopf`) und „Punkte
  verteilen“ (`KampfUi.punkte_knopf`) teilen Host und Gast.
  Arena-Boden aus Steinplatten-Ringen (MultiMesh) + Biom-Deko am Rand.
- **Dungeon-HUD (`DungeonHud`):** Titel + Wert-Chips oben links,
  Party-Karten unten links, Tastenkappen unten rechts, Meldungen oben
  mittig auf einer Glastafel, Minimap oben rechts.
- **Bildschirm-Vorlage (`Bildschirm.bauen`, UI-Layout-Pass 2026-10-14,
  abgeschlossen 2026-11-01):** jede Menü-/Hub-Szene nutzt sie; das
  Hauptmenü nur Rand + Glastafel (kein Zurück, keine Kopfzeile).
  Ergebnis- und Abschlussfenster (Kampfende Host/Gast, Dungeon
  abgeschlossen): `Bildschirm.fenster` (Tafel, 24 px Innenrand, 440 px
  Mindestbreite) + `fenster_titel` (gold, 32 px). 24 px Rand, ruhige
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
  Grenzen: 8 Punktlichter pro Objekt, 32 gesamt; globale Shader-Uniforms
  ohne Arrays. Transparenz nur, wo nötig — Wände dithern opak.
- Tonemapping: Dungeon Filmic über `Stil3D.umgebung`; Kampf, Menüs,
  Porträts noch Linear (Umstellung mit den Paketen Kampf/UI).
- `get_meta(name, null)` meldet bei fehlendem Eintrag einen Fehler — erst
  `has_meta` prüfen.
- Neue `class_name`-Skripte: einmal `godot --headless --path . --import`,
  sonst kennt der Skript-Check die Klasse nicht.
- `Environment.background_color` erwartet **lineare** Farbe →
  `PAL["nacht"].srgb_to_linear()`, sonst wird der Hintergrund lila.
- Klassen-Aliase per `const X := Klasse` werden nicht als Konstante
  akzeptiert → Klassennamen direkt verwenden.
- Screenshot-Modus der Showcase: `-- --shot=<pfad.png> [--modus=kampf]`.
