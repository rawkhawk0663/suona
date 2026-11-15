# Suona – Hinweise für die Entwicklung

Suona ist ein Spiel, mit dem Kinder und Jugendliche (6 bis etwa 20 Jahre) das Notenlesen auf der Gitarre üben. Der Besitzer ist Gitarrenlehrer und programmiert nicht selbst. Erkläre Änderungen deshalb in einfacher Sprache und ohne Fachjargon. Schwester-App: Volti (`rawkhawk0663/volti`), von dort stammen Updater, Fehlerprotokoll, Build und Installer.

Der Bauplan (fünf Pakete) liegt als Artifact „Suona Bauplan“ beim Besitzer. Kurzfassung:
1. **Erste Töne** (fertig): Notensystem, „Wie heisst die Note?“, Profile, Münzen/Combo/Streak, einfacher Arcade, Lehrerbereich, Lehrpläne, Mikrofon-Test.
2. **Griffbrett** (fertig): vier Fragearten (`QuestionType`), Griffbrett-Übung auf der Startseite, Arcade mit Spielart, Lehrplan oder Saiten/Bünde, Vorzeichen, „Saite vorgeben“, Vorlagen.
3. **Abenteuer** (fertig): Weltkarte mit 8 Stationen, je 5 Level + Auftritt, Publikums-Balken, Shop mit Kleidung, Gitarren und Pedalen, freies Aussehen, Abzeichen. Siehe „Abenteuer und Shop“.
4. **Echt spielen**: Tonerkennung über das Mikrofon (Grundlage `MicListener`/`PitchDetector` ist da).
5. **Rhythmus, Tabs & Band**.

## Kinderschutz und Datenschutz (nie brechen)
- **Keine Daten verlassen das Gerät.** Kein Konto, kein Server, keine Analyse, keine Absturzberichte nach aussen, keine Werbung, keine Käufe, keine Links nach aussen, kein Chat.
- Ein Profil hat nur **Spitzname und Figur** (Luna oder Fuzz). Kein echter Name, kein Alter, keine Fotos. Statt des Alters wählt die Lehrperson eine **Stufe** (`Difficulty`), gespeichert wird nur die Stufe.
- **Internet nur für „Nach Updates suchen“** im gesperrten Lehrerbereich, nur auf Knopfdruck. Suona sucht **nie** von selbst (anders als Volti).
- **Mikrofon** nur im Mikrofon-Test und später in „Echt spielen“. Ton wird nur im Speicher ausgewertet, nie aufgenommen oder gespeichert. Sichtbar anzeigen, wann es an ist. Android fragt die Berechtigung erst beim Öffnen.
- **Lehrerbereich** hinter einer Rechenaufgabe (`teacher_gate.dart`). Löschen von Profilen nur dort.
- **Fair belohnen:** keine Zufalls-Kisten, kein Druck. Verpasste Tage kosten nur die Zählung, nie Münzen. Streak-Schutz (alle 7 Tage einer, höchstens 2) rettet Lücken automatisch.
- Datenschutz-Erklärung in zwei Fassungen (Kinder/Eltern): `features/teacher/privacy.dart`. Bei neuen Daten oder Berechtigungen dort nachtragen.

## Sprache
- Oberfläche Deutsch (Grundsprache, Schweizer Schreibweise: „ss“ statt „ß“) und Englisch (britisch). **Jeder sichtbare Text** als `tr('Deutsch', 'English')` (`lib/app/l10n.dart`, wie bei Volti). Kein `const` um Widgets mit `tr(...)`.
- Code-Kommentare deutsch, Bezeichner englisch. Ordner- und Dateinamen auf der Festplatte und JSON-Schlüssel nie übersetzen.
- Kindgerecht schreiben: kurze Sätze, grosse Knöpfe. Die Jüngsten lernen gerade lesen.
- **Beschreibung im öffentlichen Download-Projekt** (`rawkhawk0663/suona-releases`): `README.md` (Deutsch) und `README.en.md` (Englisch), Bilder in `bilder/` (`suona_icon.png`, `luna_und_fuzz.png`). **Bei jeder sichtbaren Änderung der App ungefragt nachführen** (ausdrücklicher Wunsch des Besitzers): neue Funktionen, geänderte Wege in der Bedienung, „Kommt bald“ abhaken, neues Symbol oder neue Figuren auch als Bild. Das Projekt mit `add_repo` (push) holen, ändern, direkt auf `main` schieben.

## Musik
- `Pitch` speichert den **klingenden** Ton (C4 = c'). Gitarrennoten stehen eine Oktave höher (Violinschlüssel mit kleiner 8), das rechnet `staffStep` ein: 0 = unterste Linie, E2 = −7 (unter der 3. Hilfslinie), E5 = 14 (auf der 3. Hilfslinie oben).
- Notennamen (`note_names.dart`): deutsch H/B/Fis/Es und Helmholtz-Oktaven (E, e, e', e''), international B/B♭/F♯ und E2…E5. Einstellung im Lehrerbereich. Benannt wird nach dem **klingenden** Ton (so wie in guitarTALKS: leere e-Saite = e').
- Vorzeichen-Schreibweise (`AccidentalStyle`: nur ♯, nur ♭, gemischt) wird mit `applyAccidentalStyle` auf jeden Notenvorrat angewendet.
- Gefragt wird die Schreibweise (Fis ≠ Ges), nicht nur der Klang.
- Notenschrift: Bravura (SMuFL, `assets/fonts/Bravura.otf`, OFL). Grösse = 4 Linienabstände pro Schriftgrösse, Bezugspunkt der Zeichen ist die Grundlinie (`StaffPainter._glyph`). Das Notensystem malt Linien/Schlüssel und Noten getrennt (`drawStaff`/`drawNotes`), damit beim Wechsel nur die Note hereinrutscht.
- Standardstimmung und Griffbrett bis 12. Bund: `guitar.dart` (Saite 1 = hohe e-Saite).

## Griffbrett (Paket 2)
- Fragearten (`core/game/question.dart`): `nameFromStaff` (Note → Name), `fretFromStaff` (Note → Stelle antippen), `nameFromFret` (Punkt → Name), `staffFromFret` (Punkt → Note ins Notensystem setzen). `QuestionFactory` baut eine Frage zu einem Ton.
- Ohne Griffbrett-Bereich (Übung nach Lehrplan) zählt jede Stelle bis zum 12. Bund, und gezeigt wird die tiefste Stelle (so lernt man den Ton zuerst). Mit Bereich (`FretRange`: Saiten, Bünde) nur Stellen darin, gezeigt wird eine zufällige.
- Vom Griffbrett aus ist die Schreibweise offen: Fis und Ges zählen beide (`isRightName(enharmonicOk:)`, beim Setzen zählt der Klang).
- Lernkartei getrennt: Notenlesen ohne Präfix, Griffbrett mit `G:` (`NoteStatsPrefix.fretboard`). Der Lehrerbereich zeigt beides.
- `Fretboard` (`widgets/fretboard.dart`): gleich breite Bünde (leichter zu treffen), links die leeren Saiten, Einlagen 3/5/7/9/12. Einstellung „Tiefe E-Saite oben“ (`lowStringOnTop`), Standard wie Tabulatur (hohe e-Saite oben). Ein falsch angetippter Punkt zeigt, welcher Ton dort liegt.
- `StaffTapArea` (`widgets/staff.dart`) macht das Notensystem antippbar (`stepAt`), `pitchFromStaffStep` rechnet zurück.
- Arcade (`core/game/arcade_settings.dart`): Spielart `ArcadeAnswer` (Rekord pro Art in `Profile.arcadeBests`, altes Feld `arcadeBest` wird übernommen), Töne nach Lehrplan oder nach Saiten/Bünden, Tempo. Eingebaute Vorlagen ändern nur den Bereich, eigene Vorlagen (alles) speichert die Lehrperson hinter der Sperre (`passTeacherGate`) in `arcade_vorlagen.json`, löschen im Lehrerbereich unter „Lehrpläne“.

## Abenteuer und Shop (Paket 3)
- **Stationen** (`core/game/adventure.dart`): Kinderzimmer, Garage, Schulaula, Jugendclub, Stadtfest, Tonstudio, Festival, Stadion. Die Lehrplan-Schritte werden gleichmässig verteilt (`stepsOf`, bei 9 Schritten bekommt das Stadion zwei). Eine Station öffnet sich, wenn der Auftritt der vorigen geschafft ist **und** das Profil im Lehrplan mindestens beim ersten Schritt der Station steht (`StationLock.teacher`: neue Töne kommen zuerst im Unterricht, Wunsch des Besitzers: die Lehrperson steuert). Der Lehrerbereich zeigt, worauf ein Kind wartet.
- **Level** (`Adventure.plan`): 0 Aufwärmen (nur neue Töne, ohne Zeit), 1 Probe (Notenname), 2 Griffbrett, 3 Welcher Ton?, 4 Generalprobe (gemischt), 5 Auftritt (15 Töne, gemischt). Zeit pro Ton 12 s in der ersten bis 5 s in der letzten Station (`timeFor`). Sterne strenger als beim Üben (60/75/90 %). Erstes Schaffen gibt 15 Münzen, ein Auftritt 50. Das beste Ergebnis zählt. Gespeichert in `Profile.adventure[curriculumId]` (8 × 6 Sterne).
- **Publikum**: Stimmung startet bei 0.6, richtig +0.08, falsch −(0.14 + 0.01 × Station, Auftritt +0.04). Bei 0 ist das Level vorbei.
- **Stufen** (`core/game/difficulty.dart`, Wunsch des Besitzers: nach Alter): Mini (6–8), Junior (9–11, Standard), Teen (12–15), Profi (16+). Die Lehrperson stellt sie pro Profil im Lehrerbereich ein (`Profile.difficulty`). Sie verändert Zeit pro Ton (×1.6/1.3/1.0/0.8, mindestens 3 s), wie lange Probe und Griffbrett ohne Zeit bleiben, Publikum (Fehler ×0.6/0.8/1.0/1.2, richtig +0.10/0.09/0.08/0.07) und bei Mini die Länge der Level (6/8/12 statt 8/10/15). Die Zahlen oben gelten für Teen.
- **Pedale** (nur im Abenteuer, je einmal pro Level): Schild-Pedal (der nächste Fehler zählt nicht), Kapodaster (Zeit für einen Ton anhalten, nur mit Zeitdruck), Stimmgerät (streicht zwei falsche Namen oder zeigt die Saite, nicht bei „Note setzen“).
- **Shop** (`core/game/shop.dart`, `features/shop/shop_screen.dart`): Reiter Aussehen, Sets, Kopf, Brillen, Hals, Westen, Gitarren, Amps, Pedale. Rund 50 Teile. Nur Spiel-Münzen, keine Käufe mit Geld. Anprobieren vor dem Kauf, Kauf muss einmal bestätigt werden (gegen Versehen). Farben (Haut, Haare, Augen, Shirt) sind gratis.
- **Gitarren**: akustisch (`Shop.acousticGuitars`, muss zu `ACOUSTIC_GUITARS` im Figuren-Programm passen, der Test prüft das) oder E-Gitarre. Gratis sind die beiden E-Gitarren der Figuren und die Konzertgitarre (`Shop.starterAcoustic`). Beim neuen Profil wählt das Kind nach der Figur seine Startgitarre (E-Gitarre oder Konzertgitarre, Pflicht).
- **Amps** (Fach `amp`) stehen rechts neben der Figur, aber nur mit E-Gitarre. Mit akustischer Gitarre bleiben sie unsichtbar, der Shop zeigt dann einen Hinweis und in der Vorschau die E-Gitarre der Figur (`withElectric`).
- **Sets** (`Shop.sets`, `OutfitSet`): Strasse, Strand, Flower-Power, Country, Jazz-Gala, Heavy Metal, Weltall, Rockstar. Jedes Teil gehört zu höchstens einem Set. Ein volles Set gibt ein Abzeichen (`set_<id>`), „Meine Teile anziehen“ zieht alle gekauften Teile eines Sets an. Kaufen geht direkt in der Set-Karte.
- **Abzeichen** (`core/game/badges.dart`): werden aus dem Spielstand berechnet, nicht gespeichert.

## Lehrpläne
- `Curriculum` = Schritte mit **neuen** Tönen. Eingebaut: guitarTALKS (Markus Engler), nur die Reihenfolge der Töne, keine Stücke oder Figuren aus dem Buch (Urheberrecht). Eigene Lehrpläne legt die Lehrperson an (`curriculum_editor.dart`), z. B. „Play Guitar Junior“ (macht der Besitzer selbst).
- Jedes Profil hat `curriculumId` und `step` (wie weit das Kind ist, setzt die Lehrperson). Üben nimmt alle Töne bis `step`, die neuen Töne des aktuellen Schritts kommen doppelt so oft.

## Spiel
- Lernkartei (`note_stats.dart`): pro Ton Fach 0–5, richtig = ein Fach höher, falsch = Fach 0. Unsichere Töne kommen öfter, nie zweimal derselbe hintereinander.
- Münzen: 5 pro richtigem Ton, Combo ×2 ab 5 und ×3 ab 10 in Folge. Sterne nach Trefferquote (90/70/40 %), Bonus 5/10/20.
- Ein Übungstag zählt nach einer ganzen Übungsrunde (10 Töne) oder ab 10 Tönen im Arcade.
- Klänge werden im Speicher erzeugt (`sounds.dart`, `flutter_soloud` 5.2.3 wie Volti): gezupfte Saite (Karplus-Strong), richtig, falsch, Münzen, Fanfare.
- Tonerkennung (`pitch_detector.dart`): YIN, getestet mit Sinustönen und gezupften Saiten E2–E5. Mikrofon über `flutter_recorder` (miniaudio, alle Plattformen, unter Linux braucht der Build `libasound2-dev`).

## Daten
Alles im Datenordner der App (`getApplicationSupportDirectory`, unter Windows `%APPDATA%\Suona\Suona`):
- `Spielstaende/<id>.json` (Format `suona-profil` v1, mit `difficulty`, `look` (auch `neck`, `amp`), `owned`, `adventure`)
- `Lehrplaene/<id>.json` (Format `suona-lehrplan` v1)
- `einstellungen.json`, `arcade_vorlagen.json`, `fehler.log`, `update.log`
Geschrieben wird immer über eine Zwischendatei (`json_files.dart`).

## Aufbau
```
lib/
  app/         l10n, Theme (Bühnen-Farben, Schriften Baloo 2 + Atkinson Hyperlegible), Updater, Fehlerprotokoll, Version
  core/
    music/     Pitch, Notennamen, Gitarre, Lehrpläne
    game/      Lernkartei, Münzen/Combo/Sterne, Tages-Streak, Fragen, Arcade, Abenteuer, Shop, Abzeichen
    character/ Aussehen (CharacterLook, Farbpaletten), Figuren zusammensetzen (CharacterArt)
    profiles/  Profil, JSON-Dateien
    audio/     Klänge, Tonerkennung, Mikrofon
    suona_state.dart  Zustand der App (SuonaScope)
  features/    start (Wer spielt?), home (mit Abzeichen), quiz (Üben, Arcade, Abenteuer-Level, Ergebnis), arcade (Einstellungen),
               adventure (Weltkarte, Station), shop (Shop und Aussehen), teacher (Lehrerbereich)
  widgets/     Bühne, Figuren, Münzen, Notensystem, Griffbrett
assets/characters/  Luna und Fuzz als SVG (ganz und nur Gesicht), erzeugt mit tool/make_characters.py.
tool/make_characters.py  zeichnet die Figuren (siehe „Figuren“)
tool/make_icon.py   erzeugt das App-Symbol (Windows .ico, Android)
```

## Figuren
- Stil „Mix 2“ (vom Besitzer gewählt, aus einem Vergleich von vier Stilen): grosse, glänzende Chibi-Augen und Bäckchen, dazu dicke dunkle Konturen (`#15121F`), harte Schatten als Sichel und Rock-Details. Luna: lange Haare, Stern im Haar (verschwindet unter Kopfbedeckungen) und auf dem Shirt, korallroter Rock, Ringelstrumpfhose, Stiefel, türkise Pfeil-Gitarre. Fuzz: oben stachlige Haare mit kurzen Seiten, Shirt mit Blitz, Jeans mit Riss, Turnschuhe, schwarzes Schweissband, rote Rock-Gitarre.
- **Baukasten:** `tool/make_characters.py` erzeugt `assets/characters/<figur>_template.svg` (Farben als Platzhalter `{{skin}}`, `{{hair}}` …, Stellen `<!--slot:guitar|vest|neck|glasses|hat|amp-->`, `<!--defs-->`) und `items.json` (Gitarren mit `kind` acoustic/electric und Amps für beide, übrige Teile pro Figur). Halsschmuck liegt im Körper über Shirt und Weste, der Amp ganz hinten in den Koordinaten der fertigen Figur (rechts der Füsse, Boden y = 296). `CharacterArt` (`core/character/character_art.dart`) setzt zur Laufzeit zusammen, `CharacterLook` (`core/character/look.dart`) hält Farben und Teile. `luna.svg`/`fuzz.svg` sind nur Vorschau und Download-Bild.
- Nie von Hand in den SVGs ändern, sondern im Python-Programm und neu erzeugen (`python3 tool/make_characters.py`). Ein neues Shop-Teil: im Programm zeichnen (für beide Figuren), in `Shop.items` mit Preis und Namen eintragen. Der Test prüft, dass jedes Shop-Teil für beide Figuren existiert.
- Grosse Hüte sitzen auf der Krempen-Höhe `BRIM` (Fuzz höher wegen der Stacheln, die dürfen seitlich herausschauen). `CharacterView(guitar: true)` zeigt nur Oberkörper und Gitarre (Gitarren im Shop, Startgitarre).
- Kopf und Körper sind getrennte Gruppen (`HEAD_SCALE` 1.16, `BODY_SCALE` 0.95), die Konturen bleiben trotzdem gleich dick (auch bei den Teilen).
- Der Anschlagarm liegt vor der Gitarre, der Greifarm hinter dem Hals (Wunsch des Besitzers).
- Keine Strichelung (`stroke-dasharray`) verwenden, `flutter_svg` kennt sie nicht. Schatten über `clipPath` funktionieren.
- Das Bild `bilder/luna_und_fuzz.png` im Download-Projekt bei Änderungen an den Grundfiguren neu erzeugen.

## Technik
- Flutter `3.47.9` (in `.github/workflows/build.yml`), Material 3. Hauptgerät: Microsoft Surface (Windows), danach Android, später evtl. iPad.
- Jeder Push auf `main` baut Windows (ZIP + `Suona-Setup.exe`) und Android (`Suona-Android.apk`) und legt sie als Release ab, zusätzlich im öffentlichen Projekt `rawkhawk0663/suona-releases` (Geheimnis `RELEASES_TOKEN`, ohne Geheimnis übersprungen). Von dort holt „Nach Updates suchen“ die neue Version (Ablauf wie Volti, siehe dort Punkt 33). Die Builds laden ihre Dateien direkt in einen Release-Entwurf (Job `draft`), der am Schluss veröffentlicht wird. Keine `upload-artifact`-Schritte: Der Speicher dafür ist im Konto voll (mit Volti geteilt).
- Versionsnummer `v0.1.<run_number>` über `--dart-define=SUONA_VERSION`.
- Bedienung vollständig mit Finger möglich. Tastatur geht zusätzlich (Tasten c d e f g a h, `#` und `-` für die Vorzeichen).

## Prüfen
```bash
flutter analyze
flutter test
```
Sichtprüfung ohne Surface: `flutter build linux --debug`, unter Xvfb starten, mit `xdotool` bedienen, mit `import` Bildschirmfotos machen.
