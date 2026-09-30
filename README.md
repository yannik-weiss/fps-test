# Aschenmark — Die Grenzlande

Ein eigenständiger, von der Idee eines rauen Fantasy-Sandbox-Rollenspiels inspirierter Godot-Prototyp. Alle Modelle werden direkt im Projekt erzeugt; externe Assets sind nicht erforderlich.

## Start

`project.godot` mit Godot 4.7.2 öffnen und F5 drücken. Im Startmenü **Grenzlande betreten** wählen.

## Spielen

- WASD: Bewegung, Maus: Blick, Shift: Sprint, Leertaste: Sprung
- Mausbewegung oder 1/2/3/4: Links / Oben / Rechts / Stich wählen (Maus nach unten = Stich)
- Linksklick halten: Ausholen; loslassen: Angriff freigeben (20 Ausdauer). Ein kurzer Klick schlägt nach 0,34 Sekunden zu; spätestens nach 0,8 Sekunden wird ein gehaltener Angriff ausgelöst.
- Rechte Maustaste halten: auf der gewählten Seite frontal blocken (15 Ausdauer pro Treffer). Eine Parade in den ersten 0,2 Sekunden kostet nur 8 Ausdauer.
- Q: während des Ausholens fintieren (8 zusätzliche Ausdauer), dann Richtung wechseln und erneut angreifen
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

`tests/directional_combat.gd` prüft zusätzlich die vollständige Matrix der vier Angriffs- und Blockrichtungen für beide Seiten, Spieler- und KI-Finten sowie Stichreichweite.

`tests/render_preview.gd` erstellt die Spielansichten unter `screenshots/` mit dem tatsächlichen Renderer.


## LAN PvPvE

1. Auf allen Rechnern dieselbe Version dieses Projekts mit Godot 4.7.2 starten. Alle Teilnehmer müssen im selben lokalen Netzwerk sein.
2. Im Startmenü **LAN · Runde eröffnen / beitreten** wählen und einen Namen eingeben.
3. Ein Spieler klickt **LAN-Runde eröffnen**. Sein Rechner berechnet die gemeinsame Welt.
4. Andere Spieler wählen die gefundene Runde und **Ausgewählte Runde betreten**. Alternativ die private IPv4-Adresse des Gastgebers eingeben und **Mit IP verbinden** wählen. Die Adresse wird dem Gastgeber beim Start angezeigt.
5. Außerhalb des Lagers sind Kämpfe gegen Spieler und NPCs möglich. Richtungsangriffe, Stechen, passende Paraden und Finten gelten auch im PvP. Das Lager schützt vor PvP. Nach dem Tod führt die Schaltfläche im Todesmenü zurück zum Lager; Ausrüstung und Inventar bleiben während der Runde erhalten.
6. Esc und die LAN-Schaltfläche öffnen das Menü zum Verlassen. Die Welt läuft während der Menüs weiter. Wenn der Gastgeber die Runde beendet, werden die anderen Spieler getrennt. F5 ist im LAN deaktiviert, damit kein einzelner Rechner die gemeinsame Welt zurücksetzt.

Die Suche verwendet UDP-Broadcast, mit gezielten Antworten auf den Suchenden. **UPnP ist nicht erforderlich:** Es dient zur Router-Portfreigabe; die LAN-Suche benötigt keine Internet-Portfreigabe. Das Spiel legt keine Routerfreigaben an und akzeptiert direkte Verbindungen zu privaten IPv4- und Loopback-Adressen. Gastnetze/WLAN-Client-Isolation können die Suche und Verbindung verhindern. Falls das Betriebssystem fragt, Godot für das lokale Netzwerk zulassen. Auf dem Gastgeber müssen UDP 27841 (Spiel) und 27842 (Suche) erreichbar sein. Bei mehreren Netzwerksegmenten die direkte IP nutzen.

Gegner, Treffer, Rohstoffe, Waffenverbesserungen und Beute werden vom Gastgeber berechnet. Bewegung wird beim Client vorhergesagt und mit dem Gastgeber abgeglichen. Ein verbrauchter Rohstoff oder Beutebeutel kann nur einmal abgeholt werden; auch später beitretende Spieler erhalten den aktuellen Weltzustand. Die Welt und die verfügbaren Ressourcen bleiben die kleine Prototyp-Welt; es gibt noch keine neue große Multiplayer-Karte oder Speicherdatei. Die Sitzung endet mit dem Gastgeber, ohne Host-Migration.

`tests/lan_integration.gd` verbindet über echte Loopback-ENet-Sockets einen Gastgeber mit zwei Clients in getrennten Physikwelten. 22 Prüfungen decken UDP-Rundensuche, Verbindung, Namen, Bewegung, PvP-Schaden und Richtungsblocks, Lagerschutz, einmaliges Sammeln, Inventar, PvE-Tod und Beute, späteren Beitritt, Respawn, Verlassen und Host-Abbruch ab. Zwei physische Rechner und die Netzwerk-/Firewall-Einstellungen vor Ort wurden hier nicht getestet.

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/lan_integration.gd
```
