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
- **Wände (Glas-Regel):** Jede Wand = fester dunkler **Sockel** (0.3 hoch,
  mit Kontur — zeigt IMMER, wo die Wand steht) + Körper und Deckel. Wände,
  die im 45°-Blick **vor dem Helden** liegen (größere x+z-Diagonale) und
  seitlich in seiner Nähe, blenden in ~0.3 s zu **Glas** über
  (Deckkraft 0.22, Kanten und Deckel etwas deckender, kein Schatten).
  Alle anderen Wände bleiben massiv. Nie Wände ganz ausblenden — Gänge
  und Durchgänge müssen lesbar bleiben.
- **Kampf:** Perspektive, FOV 36, leicht erhöht. Monster in
  **3/4-Ansicht zur Bildmitte gedreht** (JRPG-Klassiker) — frontal wirken
  Schnauzen-Figuren wie Masken.

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
