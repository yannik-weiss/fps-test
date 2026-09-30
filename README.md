# Aschenmark — Die Grenzlande

Ein eigenständiger, von der Idee eines rauen Fantasy-Sandbox-Rollenspiels inspirierter Godot-Prototyp. Alle Modelle werden direkt im Projekt erzeugt; externe Assets sind nicht erforderlich.

## Start

`project.godot` mit Godot 4.7.2 öffnen und F5 drücken. Im Startmenü **Grenzlande betreten** wählen.

## Spielen

- WASD: Bewegung, Maus: Blick, Shift: Sprint, Leertaste: Sprung
- Mausbewegung oder 1/2/3/4: Links / Oben / Rechts / Stich wählen (Maus nach unten = Stich)
- Linksklick halten: Ausholen und aufladen; loslassen: Schlag freigeben. Mindest-Ausholen 0,35 s, volle Ladung nach 1,1 s. Oben kostet 18, seitlich 15 und Stechen 12 Ausdauer. Die bewegte Klinge muss den Gegner treffen. Während der Erholung eingegebene Schläge werden gepuffert.
- Rechte Maustaste halten: auf der beim Drücken gewählten Seite frontal blocken. Die gehaltene Deckung folgt Maus / 1–4 und wird nach Erholung erneut angehoben. Ein Richtungswechsel verlängert das Paradenfenster nicht. Eine Parade in den ersten 0,2 s stoppt und betäubt den Angreifer. Normale Blocks kosten 0,8 Ausdauer pro Schadenspunkt; erschöpfte Deckung bricht und lässt halben Schaden durch.
- Q: das Ausholen in die gewählte Richtung umlenken (8 Ausdauer). Ist die Richtung unverändert, wird die nächste Richtung im Uhrzeigersinn gewählt. Blocken beim Ausholen bricht den Schlag ab.
- E: sammeln, schmieden, Beute bergen, am Lagerfeuer heilen
- J: Tagebuch, Esc: Pause, F5 im Spiel: Neustart

Folge dem Pfad vom Lager nach Norden. Sammle Holzstapel und die goldenen Erzbrocken am Wegesrand. Mit je zwei Holz und Erz verstärkst du an der Schmiede neben dem Feuer deine Klinge. Gegner kündigen ihre Angriffe mit goldenen Richtungspfeilen und einer passenden Schwertpose an. Die Pfeile zeigen die Seite, auf der du blocken musst, aus deiner Sicht. Seitliche Angriffe und Paraden werden zwischen Angreifer- und Verteidigersicht gespiegelt. Stiche erfordern eine Stichparade und haben etwas mehr Reichweite, aber einen engeren Zielwinkel. Gehe aus der Reichweite oder blocke auf der angezeigten Seite.

Gegner nutzen alle vier Angriffe, blocken nach einer Reaktionszeit und fintieren gelegentlich; der Wächter fintiert häufiger. Ihr blauer Blockhinweis zeigt die für deinen Angriff gesperrte Seite. Täusche einen Angriff an, brich ihn mit Q ab und wechsle die Richtung, bevor ihr festgelegter Block endet. Finten sind nur vor der Schlagfreigabe möglich. Treffer unterbrechen gegnerisches Ausholen und verursachen einen kurzen Rückstoß.

Treffer, Block und Parade haben unterschiedliche Meldungen und Klänge. Funken, kurze Trefferpausen, sichtbare Gegnerreaktionen, Waffenrückstoß und dezente Kamerastöße geben zusätzlich Rückmeldung. Wenn deine Ausdauer knapp wird, lass sie regenerieren.

Besiege den dunklen Ruinenwächter im Hof der Abtei. Sein Siegel erhältst du automatisch; Gold liegt als Beute neben besiegten Gegnern. Kehre zum Lagerfeuer zurück und gib das Siegel mit E ab. Danach kannst du weiter erkunden.

## Umfang

Lokaler Einzelspieler mit einer kleinen erkundbaren Welt, drei Besatzern, einem Wächter, Nahkampf, Ausdauer, Blocken, Rohstoffen, einer Waffenverbesserung, Beute und einer abschließbaren Aufgabe. Ungefähr 5–10 Minuten. Zusätzlich gibt es einen LAN-PvPvE-Modus für bis zu acht Teilnehmer mit einem Spieler als Gastgeber. Es gibt keinen Internetdienst, persistenten Charakter oder Speicherstand. Das Projekt ist eine spielbare Grundlage, kein vollständiges MMO und verwendet keine Mortal-Online-Assets.

## Aufbau

- `scripts/world.gd`: Weltaufbau, Oberfläche, Interaktion und Aufgaben
- `scripts/player.gd`: Ego-Steuerung und Kampf
- `scripts/enemy.gd`: Gegnerverhalten und Angriffsankündigungen
- `scripts/art.gd`: Landschaft, Vegetation, Mauerwerk, Figuren und Schwerter
- `scripts/lan.gd`: LAN-Lobby, Rundensuche, ENet-Verbindung und Synchronisierung

## Darstellung

Die Welt verwendet geformte Rüstungen und Schwerter mit Schneiden und Griffwicklung, ein hügeliges Gelände mit einem nahtlosen Erdpfad, Gras, verzweigte Bäume, unregelmäßige Felsen, einzelne abgerundete Mauersteine und einen Torbogen. Wolken, dezente Vegetationsbewegung und flackerndes Feuer ergänzen die Fantasy-Optik. Die Waffenhand und die Beine der Gegner bewegen sich mit. Alle Modelle und Oberflächendetails entstehen lokal; es werden keine externen Asset-Pakete benötigt.

## Prüfung

`tests/playthrough.gd` prüft in einem automatischen Spieldurchlauf 21 Fälle, darunter Ressourcen und Schmiede, Blocken von vorn und Schaden von hinten, Trefferverdeckung durch Mauern, Angriffskosten und Abklingzeit, Wächterkampf, Beute, Questabschluss und Tod.

Auf macOS mit der hier installierten Godot-App:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/playthrough.gd
```

`tests/directional_combat.gd` prüft die vollständige Richtungs-Matrix für beide Seiten, echte Klingentreffer aller vier Richtungen, Ladung und Schaden, Deckungsbruch, Paraden, gepufferte Folgeschläge sowie Spieler- und KI-Richtungsfinten.

`tests/render_preview.gd` erstellt die Spielansichten unter `screenshots/` mit dem tatsächlichen Renderer.


## LAN PvPvE

1. Auf allen Rechnern dieselbe Version dieses Projekts mit Godot 4.7.2 starten. Alle Teilnehmer müssen im selben lokalen Netzwerk sein.
2. Im Startmenü **LAN · Runde eröffnen / beitreten** wählen und einen Namen eingeben.
3. Ein Spieler klickt **LAN-Runde eröffnen**. Sein Rechner berechnet die gemeinsame Welt.
4. Andere Spieler wählen die gefundene Runde und **Ausgewählte Runde betreten**. Alternativ die private IPv4-Adresse des Gastgebers eingeben und **Mit IP verbinden** wählen. Die Adresse wird dem Gastgeber beim Start angezeigt.
5. Außerhalb des Lagers sind Kämpfe gegen Spieler und NPCs möglich. Richtungsangriffe, Stechen, passende Paraden und Finten gelten auch im PvP. Das Lager schützt vor PvP. Nach dem Tod führt die Schaltfläche im Todesmenü zurück zum Lager; Ausrüstung und Inventar bleiben während der Runde erhalten.
6. Esc und die LAN-Schaltfläche öffnen das Menü zum Verlassen. Die Welt läuft während der Menüs weiter. Wenn der Gastgeber die Runde beendet, werden die anderen Spieler getrennt. F5 ist im LAN deaktiviert, damit kein einzelner Rechner die gemeinsame Welt zurücksetzt.

Die Suche verwendet UDP-Broadcast, mit gezielten Antworten auf den Suchenden. **UPnP ist nicht erforderlich:** Es dient zur Router-Portfreigabe; die LAN-Suche benötigt keine Internet-Portfreigabe. Das Spiel legt keine Routerfreigaben an und akzeptiert direkte Verbindungen zu privaten IPv4- und Loopback-Adressen. Gastnetze/WLAN-Client-Isolation können die Suche und Verbindung verhindern. Falls das Betriebssystem fragt, Godot für das lokale Netzwerk zulassen. Auf dem Gastgeber müssen UDP 27841 (Spiel) und 27842 (Suche) erreichbar sein. Bei mehreren Netzwerksegmenten die direkte IP nutzen.

Gegner, Treffer, Rohstoffe, Waffenverbesserungen und Beute werden vom Gastgeber berechnet. Bewegung reagiert sofort lokal. Der Abgleich verwendet die bestätigten Physikeingaben, sodass noch unterwegs befindliche Bewegung nicht zurückgezogen wird. Kleine Bewegungs- und Kampfpose-Pakete laufen mit 30 Hz getrennt von den zuverlässig übertragenen Weltänderungen; Figuren und Klingen werden zwischen Updates geglättet. Ein kurzes Eingabefenster fängt verlorene Pakete ab und verhindert doppelte Sprünge. Alle Teilnehmer benötigen dieselbe aktualisierte Spielversion (LAN-Protokoll 4). Ein verbrauchter Rohstoff oder Beutebeutel kann nur einmal abgeholt werden; auch später beitretende Spieler erhalten den aktuellen Weltzustand. Die Welt und die verfügbaren Ressourcen bleiben die kleine Prototyp-Welt; es gibt noch keine neue große Multiplayer-Karte oder Speicherdatei. Die Sitzung endet mit dem Gastgeber, ohne Host-Migration.

`tests/lan_integration.gd` verbindet über echte Loopback-ENet-Sockets einen Gastgeber mit zwei Clients in getrennten Physikwelten. 24 Prüfungen decken UDP-Rundensuche, Verbindung, Namen, Bewegung, PvP-Schaden und Richtungsblocks, Lagerschutz, einmaliges Sammeln, Inventar, PvE-Tod und Beute, späteren Beitritt, Respawn, Verlassen und Host-Abbruch ab. Zwei physische Rechner und die Netzwerk-/Firewall-Einstellungen vor Ort wurden hier nicht getestet.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/lan_integration.gd
```

`tests/network_motion.gd` prüft zusätzlich Bewegung mit 100 ms künstlicher Eingabeverzögerung, 25 % Paketverlust und doppelten Paketen. 18 Prüfungen decken Vorhersage und Abgleich, Warteschlangen, Paketgröße, Sprünge, veraltete Updates, die Erholung nach längeren Paketlücken sowie das Glätten von Spieler-, Gegner- und Schwertbewegungen ab.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/network_motion.gd
```

## Übernommenes Kampfsystem

Der gemeinsame Kampfkern und das Kampfprofil stammen aus [Lennilidli/fpsgame](https://github.com/Lennilidli/fpsgame), Stand `b87e42dd45e33a38aadf59f7e596f2ef65c20527`. `scripts/upstream/` enthält die übernommenen Kernskripte. `scripts/fighter.gd` verbindet sie mit unseren Figuren, der Welt und dem LAN-Gastgeber. Das editierbare Profil liegt in `combat/sword_profile.tres`.

Übernommen sind aufgeladene Richtungsangriffe, Klingensweeps mit Zwischenprüfungen, Deckung auf der gewählten Seite, perfekte Paraden mit Angreifer-Stagger, Deckungsbruch, Waffenabprall, Erholung, Eingabepuffer und Richtungsfinten. Die Gegner verwenden denselben Kampfkern, reagieren auf Angriffe, versuchen Paraden und Finten und umkreisen den Spieler. Weltverdeckung und Lager-Schutzzone werden zusätzlich geprüft. Treffer werden im LAN vom Gastgeber entschieden und samt Ausgangswerten zuverlässig wiedergegeben, damit Schaden und Heilung nicht doppelt oder in falscher Reihenfolge angewendet werden.

`tests/combat_regressions.gd` prüft Richtungswechsel bei gehaltener Deckung, unveränderte Paradenzeit, erneutes Blocken nach Unterbrechung, echte Gegnerangriffe gegen die Spielerdeckung und die begrenzte Griffbewegung des Stichs einschließlich Nachschwingen. Der Stich bleibt in Armreichweite; seine Klinge trifft weiterhin physisch.
