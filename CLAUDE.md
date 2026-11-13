# Suona – Hinweise für die Entwicklung

Suona ist ein Spiel, mit dem Kinder und Jugendliche (6 bis etwa 20 Jahre) das Notenlesen auf der Gitarre üben. Der Besitzer ist Gitarrenlehrer und programmiert nicht selbst. Erkläre Änderungen deshalb in einfacher Sprache und ohne Fachjargon. Schwester-App: Volti (`rawkhawk0663/volti`), von dort stammen Updater, Fehlerprotokoll, Build und Installer.

Der Bauplan (fünf Pakete) liegt als Artifact „Suona Bauplan“ beim Besitzer. Kurzfassung:
1. **Erste Töne** (fertig): Notensystem, „Wie heisst die Note?“, Profile, Münzen/Combo/Streak, einfacher Arcade, Lehrerbereich, Lehrpläne, Mikrofon-Test.
2. **Griffbrett** (fertig): vier Fragearten (`QuestionType`), Griffbrett-Übung auf der Startseite, Arcade mit Spielart, Lehrplan oder Saiten/Bünde, Vorzeichen, „Saite vorgeben“, Vorlagen.
3. **Abenteuer**: Weltkarte mit 8 Stationen (Kinderzimmer, Garage, Schulaula, Jugendclub, Stadtfest, Tonstudio, Festival, Stadion), Charakter-Editor, Shop, Pedale als Fähigkeiten (Schild-Pedal wehrt einen Fehler ab, Kapodaster hält die Zeit an, Stimmgerät streicht zwei falsche Antworten). Die Töne pro Station kommen aus dem Lehrplan des Profils.
4. **Echt spielen**: Tonerkennung über das Mikrofon (Grundlage `MicListener`/`PitchDetector` ist da).
5. **Rhythmus, Tabs & Band**.

## Kinderschutz und Datenschutz (nie brechen)
- **Keine Daten verlassen das Gerät.** Kein Konto, kein Server, keine Analyse, keine Absturzberichte nach aussen, keine Werbung, keine Käufe, keine Links nach aussen, kein Chat.
- Ein Profil hat nur **Spitzname und Figur** (Luna oder Fuzz). Kein echter Name, kein Alter, keine Fotos.
- **Internet nur für „Nach Updates suchen“** im gesperrten Lehrerbereich, nur auf Knopfdruck. Suona sucht **nie** von selbst (anders als Volti).
- **Mikrofon** nur im Mikrofon-Test und später in „Echt spielen“. Ton wird nur im Speicher ausgewertet, nie aufgenommen oder gespeichert. Sichtbar anzeigen, wann es an ist. Android fragt die Berechtigung erst beim Öffnen.
- **Lehrerbereich** hinter einer Rechenaufgabe (`teacher_gate.dart`). Löschen von Profilen nur dort.
- **Fair belohnen:** keine Zufalls-Kisten, kein Druck. Verpasste Tage kosten nur die Zählung, nie Münzen. Streak-Schutz (alle 7 Tage einer, höchstens 2) rettet Lücken automatisch.
- Datenschutz-Erklärung in zwei Fassungen (Kinder/Eltern): `features/teacher/privacy.dart`. Bei neuen Daten oder Berechtigungen dort nachtragen.

## Sprache
- Oberfläche Deutsch (Grundsprache, Schweizer Schreibweise: „ss“ statt „ß“) und Englisch (britisch). **Jeder sichtbare Text** als `tr('Deutsch', 'English')` (`lib/app/l10n.dart`, wie bei Volti). Kein `const` um Widgets mit `tr(...)`.
- Code-Kommentare deutsch, Bezeichner englisch. Ordner- und Dateinamen auf der Festplatte und JSON-Schlüssel nie übersetzen.
- Kindgerecht schreiben: kurze Sätze, grosse Knöpfe. Die Jüngsten lernen gerade lesen.

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
- `Spielstaende/<id>.json` (Format `suona-profil` v1)
- `Lehrplaene/<id>.json` (Format `suona-lehrplan` v1)
- `einstellungen.json`, `arcade_vorlagen.json`, `fehler.log`, `update.log`
Geschrieben wird immer über eine Zwischendatei (`json_files.dart`).

## Aufbau
```
lib/
  app/         l10n, Theme (Bühnen-Farben, Schriften Baloo 2 + Atkinson Hyperlegible), Updater, Fehlerprotokoll, Version
  core/
    music/     Pitch, Notennamen, Gitarre, Lehrpläne
    game/      Lernkartei, Münzen/Combo/Sterne, Tages-Streak
    profiles/  Profil, JSON-Dateien
    audio/     Klänge, Tonerkennung, Mikrofon
    suona_state.dart  Zustand der App (SuonaScope)
  features/    start (Wer spielt?), home, quiz (Üben + Arcade, Ergebnis), arcade (Einstellungen), teacher (Lehrerbereich)
  widgets/     Bühne, Figuren, Münzen, Notensystem, Griffbrett
assets/characters/  Luna und Fuzz als SVG (ganz und nur Gesicht). Fuzz: kurze Seiten, oben stachlig.
                    Anschlagarm liegt vor der Gitarre, Greifarm hinter dem Hals (Wunsch des Besitzers).
tool/make_icon.py   erzeugt das App-Symbol (Windows .ico, Android)
```

## Technik
- Flutter `3.47.9` (in `.github/workflows/build.yml`), Material 3. Hauptgerät: Microsoft Surface (Windows), danach Android, später evtl. iPad.
- Jeder Push auf `main` baut Windows (ZIP + `Suona-Setup.exe`) und Android (`Suona-Android.apk`) und legt sie als Release ab, zusätzlich im öffentlichen Projekt `rawkhawk0663/suona-releases` (Geheimnis `RELEASES_TOKEN`, ohne Geheimnis übersprungen). Von dort holt „Nach Updates suchen“ die neue Version (Ablauf wie Volti, siehe dort Punkt 33).
- Versionsnummer `v0.1.<run_number>` über `--dart-define=SUONA_VERSION`.
- Bedienung vollständig mit Finger möglich. Tastatur geht zusätzlich (Tasten c d e f g a h, `#` und `-` für die Vorzeichen).

## Prüfen
```bash
flutter analyze
flutter test
```
Sichtprüfung ohne Surface: `flutter build linux --debug`, unter Xvfb starten, mit `xdotool` bedienen, mit `import` Bildschirmfotos machen.
