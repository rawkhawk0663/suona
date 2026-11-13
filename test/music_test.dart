import 'package:flutter_test/flutter_test.dart';
import 'package:suona/core/music/curriculum.dart';
import 'package:suona/core/music/guitar.dart';
import 'package:suona/core/music/note_names.dart';
import 'package:suona/core/music/pitch.dart';

void main() {
  group('Pitch', () {
    test('MIDI und Frequenz', () {
      expect(Pitch.parse('E2').midi, 40);
      expect(Pitch.parse('A4').midi, 69);
      expect(Pitch.parse('A4').frequency, closeTo(440, 0.001));
      expect(Pitch.parse('E2').frequency, closeTo(82.41, 0.01));
      expect(Pitch.parse('F#3').midi, 54);
      expect(Pitch.parse('Bb3').midi, 58);
    });

    test('Stelle im Gitarren-Notensystem (eine Oktave höher notiert)', () {
      // Leere hohe e-Saite (E4) ist notiert e'' im obersten Zwischenraum.
      expect(Pitch.parse('E4').staffStep, 7);
      // Tiefe E-Saite: unter der dritten Hilfslinie.
      expect(Pitch.parse('E2').staffStep, -7);
      // 12. Bund hohe e-Saite: auf der dritten Hilfslinie oben.
      expect(Pitch.parse('E5').staffStep, 14);
      // g-Saite leer (G3) = notiertes g' auf der zweiten Linie.
      expect(Pitch.parse('G3').staffStep, 2);
      // Vorzeichen ändern die Stelle nicht.
      expect(Pitch.parse('F#3').staffStep, Pitch.parse('F3').staffStep);
    });

    test('Enharmonisch', () {
      expect(Pitch.parse('F#3').enharmonic, Pitch.parse('Gb3'));
      expect(Pitch.parse('Bb3').enharmonic, Pitch.parse('A#3'));
      expect(Pitch.parse('E3').enharmonic, isNull);
    });

    test('Bereich mit Vorzeichen', () {
      final r = Pitch.range(40, 44, sharps: true, flats: true);
      expect(r.map((p) => p.key), ['E2', 'F2', 'F#2', 'Gb2', 'G2', 'G#2', 'Ab2']);
      expect(Pitch.range(40, 44).map((p) => p.key), ['E2', 'F2', 'G2']);
    });

    test('Schlüssel hin und zurück', () {
      for (final p in Pitch.range(40, 76, sharps: true, flats: true)) {
        expect(Pitch.parse(p.key), p);
      }
    });
  });

  group('Notennamen', () {
    test('Deutsch', () {
      String n(String k) => pitchName(Pitch.parse(k), NoteNaming.german);
      expect(n('B3'), 'H');
      expect(n('Bb3'), 'B');
      expect(n('F#3'), 'Fis');
      expect(n('Eb3'), 'Es');
      expect(n('Ab3'), 'As');
      expect(n('Db3'), 'Des');
      String o(String k) => pitchNameWithOctave(Pitch.parse(k), NoteNaming.german);
      expect(o('E2'), 'E');
      expect(o('B2'), 'H');
      expect(o('Bb2'), 'B');
      expect(o('E3'), 'e');
      expect(o('E4'), "e'");
      expect(o('E5'), "e''");
      expect(o('F#4'), "fis'");
    });

    test('International', () {
      String n(String k) => pitchNameWithOctave(Pitch.parse(k), NoteNaming.international);
      expect(n('B3'), 'B3');
      expect(n('Bb3'), 'B♭3');
      expect(n('F#2'), 'F♯2');
      expect(letterLabel(Letter.b, NoteNaming.german), 'H');
      expect(letterLabel(Letter.b, NoteNaming.international), 'B');
    });
  });

  group('Gitarre', () {
    test('Stellen eines Tons', () {
      // e' liegt auf der leeren e-Saite, h-Saite 5. Bund, g-Saite 9. Bund, d-Saite 14 (zu hoch).
      final e4 = Guitar.positionsOf(64);
      expect(e4, containsAll(const [FretPosition(1, 0), FretPosition(2, 5), FretPosition(3, 9)]));
      expect(e4.length, 3);
      expect(Guitar.positionsOf(40), const [FretPosition(6, 0)]);
      expect(Guitar.midiAt(const FretPosition(3, 2)), 57); // a auf der g-Saite
    });

    test('Töne auf der e-Saite bis zum 3. Bund', () {
      final p = Guitar.pitchesIn(strings: {1}, maxFret: 3);
      expect(p.map((x) => x.key), ['E4', 'F4', 'G4']);
    });
  });

  group('Lehrplan', () {
    test('guitarTALKS', () {
      final c = BuiltInCurricula.guitarTalks;
      expect(c.steps.first.notes.map((p) => p.key), ['E4', 'F4', 'G4']);
      expect(c.notesUpTo(1).map((p) => p.key), ['B3', 'C4', 'D4', 'E4', 'F4', 'G4']);
      // Alle Stammtöne der offenen Lage nach sechs Schritten.
      expect(c.notesUpTo(5).length, 17);
      // Ganz am Ende: alles von E2 bis E5.
      expect(c.allNotes.first.key, 'E2');
      expect(c.allNotes.last.key, 'E5');
      // Hin und zurück als Datei.
      final again = Curriculum.fromJson(c.toJson());
      expect(again.allNotes, c.allNotes);
      expect(again.steps.length, c.steps.length);
    });
  });
}
