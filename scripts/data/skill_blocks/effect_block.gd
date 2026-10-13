class_name EffectBlock
extends SkillBlock
## Zusatzeffekt/Status-Baustein: Betäubung, Verlangsamen, Buffs/Debuffs, ...

@export var status: Enums.Status = Enums.Status.STUN

## Chance in Prozent, dass der Effekt beim Treffer angewendet wird.
@export_range(0, 100) var chance_percent: int = 100

## Wirkdauer in Runden.
@export var duration_turns: int = 2

## Stärke des Effekts — Bedeutung hängt vom Status ab
## (z.B. Slow: Prozent Tempo-Verlust, Shield: absorbierte HP).
@export var potency: int = 0

## Wen der Effekt trifft (Skillbau 3.0) — so kann auch ein Waffenangriff
## den Anwender oder die Party stärken.
enum Ziel { ZIEL, ANWENDER, PARTY, ALLE_GEGNER }
@export var ziel: Ziel = Ziel.ZIEL
