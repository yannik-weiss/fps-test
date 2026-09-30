# Kampfkern

Quelle: https://github.com/Lennilidli/fpsgame
Autor/Repository-Inhaber: Lennilidli
Übernommener Stand: b87e42dd45e33a38aadf59f7e596f2ef65c20527

Übernommene Dateien:
- `fps_game/scripts/melee_combat.gd` → `scripts/upstream/melee_combat.gd`
- `fps_game/scripts/combat_profile.gd` → `scripts/upstream/combat_profile.gd`

Die beiden Kernskripte sind unverändert übernommen. Die Integration in Aschenmark
(Weltfilter, Schutzzone, Verdeckung, Feedback, LAN-Kontakte, Figuren und Gegnersteuerung)
liegt in den eigenen Adapter- und Spielskripten. Die Gegnersteuerung verwendet die
Entscheidungsabläufe des Referenzprojekts mit unseren vorhandenen Welt-/Figurenschnittstellen.
