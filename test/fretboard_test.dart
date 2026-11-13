import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:suona/core/game/arcade_settings.dart';
import 'package:suona/core/game/question.dart';
import 'package:suona/core/music/guitar.dart';
import 'package:suona/core/music/pitch.dart';
import 'package:suona/core/profiles/profile.dart';

void main() {
  group('Antworten prüfen', () {
    test('Notenname mit und ohne andere Schreibweise', () {
      final fis = Pitch.parse('F#3');
      expect(isRightName(fis, Letter.f, Accidental.sharp), isTrue);
      expect(isRightName(fis, Letter.g, Accidental.flat), isFalse);
      expect(isRightName(fis, Letter.g, Accidental.flat, enharmonicOk: true), isTrue);
      expect(isRightName(fis, Letter.f, Accidental.natural, enharmonicOk: true), isFalse);
      // H und B (Hb) sind verschieden.
      expect(isRightName(Pitch.parse('Bb3'), Letter.a, Accidental.sharp, enharmonicOk: true), isTrue);
    });

    test('Stelle im Notensystem → klingender Ton', () {
      for (final p in Pitch.range(40, 76, sharps: true, flats: true)) {
        expect(pitchFromStaffStep(p.staffStep, p.accidental), p);
      }
    });
  });

  group('Griffbrett-Bereich', () {
    test('Töne in der 1. Lage der g-Saite', () {
      const r = FretRange(strings: {3}, minFret: 0, maxFret: 4);
      expect(r.pitches().map((p) => p.key), ['G3', 'A3', 'B3']);
      expect(r.pitches(sharps: true).map((p) => p.key), ['G3', 'G#3', 'A3', 'A#3', 'B3']);
    });

    test('Stellen eines Tons nur im Bereich', () {
      const r = FretRange(minFret: 0, maxFret: 4);
      // e' liegt in der 1. Lage nur auf der leeren e-Saite (h-Saite 5. Bund ist draussen).
      expect(r.positionsOf(64), const [FretPosition(1, 0)]);
      expect(FretRange.full.positionsOf(64).length, 3);
    });

    test('Als Datei', () {
      const r = FretRange(strings: {2, 3}, minFret: 5, maxFret: 8);
      final again = FretRange.fromJson(r.toJson());
      expect(again.strings, {2, 3});
      expect(again.minFret, 5);
      expect(again.maxFret, 8);
    });
  });

  group('Fragen bauen', () {
    test('Wo liegt die Note: alle Stellen zählen', () {
      final q = QuestionFactory().build(QuestionType.fretFromStaff, Pitch.parse('E4'));
      expect(q.accepted.toSet(), {const FretPosition(1, 0), const FretPosition(2, 5), const FretPosition(3, 9)});
      expect(q.onString, isNull);
    });

    test('Wo liegt die Note mit vorgegebener Saite', () {
      final f = QuestionFactory(fixedString: true, random: Random(1));
      for (var i = 0; i < 20; i++) {
        final q = f.build(QuestionType.fretFromStaff, Pitch.parse('E4'));
        expect(q.accepted.length, 1);
        expect(q.accepted.single.string, q.onString);
        expect(Guitar.midiAt(q.accepted.single), 64);
      }
    });

    test('Ohne Bereich zeigt das Griffbrett die tiefste Stelle', () {
      final q = QuestionFactory().build(QuestionType.nameFromFret, Pitch.parse('E4'));
      expect(q.shown, const FretPosition(1, 0));
    });

    test('Mit Bereich liegt der Punkt im Bereich', () {
      const r = FretRange(minFret: 5, maxFret: 8);
      final f = QuestionFactory(range: r, random: Random(2));
      for (final p in r.pitches()) {
        final q = f.build(QuestionType.staffFromFret, p);
        expect(r.contains(q.shown!), isTrue);
        expect(Guitar.midiAt(q.shown!), p.midi);
      }
    });
  });

  group('Arcade', () {
    test('Einstellungen als Datei', () {
      final s = ArcadeSettings(
        answer: ArcadeAnswer.fret,
        byCurriculum: false,
        range: const FretRange(strings: {3}, maxFret: 4),
        accidentals: true,
        fixedString: true,
        speed: ArcadeSpeed.fast,
      );
      final again = ArcadeSettings.fromJson(s.toJson());
      expect(again.answer, ArcadeAnswer.fret);
      expect(again.byCurriculum, isFalse);
      expect(again.range.strings, {3});
      expect(again.fixedString, isTrue);
      expect(again.speed, ArcadeSpeed.fast);
    });

    test('Eingebaute Vorlagen ändern nur den Bereich', () {
      final current = ArcadeSettings(answer: ArcadeAnswer.staff, speed: ArcadeSpeed.fast);
      final g = ArcadePreset.builtIns.firstWhere((p) => p.id == 'g-saite').applyTo(current);
      expect(g.answer, ArcadeAnswer.staff);
      expect(g.speed, ArcadeSpeed.fast);
      expect(g.byCurriculum, isFalse);
      expect(g.range.strings, {3});
    });

    test('Rekorde pro Art, alte Profile bleiben lesbar', () {
      final old = Profile.fromJson({'id': 'x', 'nickname': 'Mia', 'character': 'fuzz', 'arcadeBest': 120});
      expect(old.arcadeBests['name'], 120);
      old.arcadeBests['fret'] = 200;
      final again = Profile.fromJson(old.toJson());
      expect(again.arcadeBests, {'name': 120, 'fret': 200});
      expect(again.arcadeBest, 200);
    });
  });
}
