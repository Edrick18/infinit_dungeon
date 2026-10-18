class_name SkillBlock
extends Resource
## Basisklasse für alle Skill-Bausteine ("Bauklötze").
## Ein Skill besteht aus mindestens einer Quelle plus Element, Form, Effekten
## und Verstärkern — Bauregeln siehe Skill.fehler().

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D

## Grundkosten in MP, die dieser Baustein zum Skill beiträgt.
@export var mp_cost: int = 0

## Freischaltung: universelle Klötze über das Level, Waffen-Klötze über das Training.
@export var unlock_kind: Enums.UnlockKind = Enums.UnlockKind.LEVEL
@export var unlock_level: int = 1        ## Nur relevant bei UnlockKind.LEVEL

## Waffentechnik (DQ-Stil): nicht leer = der Skill braucht eine GEFÜHRTE
## Waffe aus einer dieser Gattungen (ItemBase.family; Schild zählt über
## die Nebenhand). Der Ausgleich: Techniken sind stärker/billiger als
## generische Bausteine.
@export var weapon_families: Array[StringName] = []

## Bei UnlockKind.TRAINING: so viele investierte Skillpunkte in dieser
## Gattung schalten den Baustein frei (Waffen-Training, DQ9-Stil).
@export var tree_family: StringName = &""
@export var tree_points: int = 0

## Baukasten 2.0 — Bauregeln:
## Variantengruppe (z.B. &"kraft" für Verstärken I/II): pro Skill nur EIN
## Klotz dieser Gruppe. Quelle/Form/Element bilden ihre Gruppe automatisch
## (Skill.gruppe_von).
@export var gruppe: StringName = &""
## Kern-Klotz (Meister-Stufe eines Baums, Echo, Kette, Beschwörung,
## Wiederbeleben): höchstens einer pro Skill — er prägt den Skill.
@export var kern := false
## Multipliziert die MP-Kosten des ganzen Skills (Verstärker, PoE-Prinzip):
## große Skills sind stark, aber teuer.
@export var kosten_faktor := 1.0
## Skillbau 3.0: multipliziert den Schaden/die Heilung des ganzen Skills —
## der „Preis“ (oder Lohn) einer Eigenschaft (Präzision 0.8, Wucht 1.6 …).
@export var schaden_faktor := 1.0
## Darf mehrfach in einen Skill (nur der Zusatztreffer) — die Sockel sind
## dann die einzige Grenze.
@export var stapelbar := false
