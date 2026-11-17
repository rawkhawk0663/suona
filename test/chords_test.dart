import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:suona/core/game/adventure.dart';
import 'package:suona/core/game/chord_adventure.dart';
import 'package:suona/core/game/difficulty.dart';
import 'package:suona/core/music/chords.dart';
import 'package:suona/core/music/guitar.dart';
import 'package:suona/core/music/note_names.dart';
import 'package:suona/core/profiles/profile.dart';

Chord ch(String id) => ChordLibrary.byId(id)!;

void main() {
  group('Griffe', () {
    test('Kleine Griffe auf drei Saiten (g, h, e)', () {
      // Saite 3 = g, 2 = h, 1 = e
      expect(ch('C').fretsOn(3), {3: 0, 2: 1, 1: 0});
      expect(ch('G').fretsOn(3), {3: 0, 2: 0, 1: 3});
      expect(ch('G7').fretsOn(3), {3: 0, 2: 0, 1: 1});
      expect(ch('Em').fretsOn(3), {3: 0, 2: 0, 1: 0});
      expect(ch('F').fretsOn(3), {3: 2, 2: 1, 1: 1});
      expect(ch('Am').fretsOn(3), {3: 2, 2: 1, 1: 0});
      expect(ch('D7').fretsOn(3), {3: 2, 2: 1, 1: 2});
      // Auf drei Saiten wird nie eine Saite gedämpft.
      for (final c in ['C', 'G', 'G7', 'Em', 'F', 'Am', 'D', 'Dm', 'D7']) {
        expect(ch(c).muted(3), isEmpty, reason: c);
      }
      // Ab fünf Saiten: C ohne tiefe E-Saite, D ohne A-Saite.
      expect(ch('C').muted(6), {6});
      expect(ch('D').muted(5), {5});
      expect(ch('G').muted(6), isEmpty);
    });

    test('Die Töne jedes Griffs passen zum Akkord', () {
      for (final c in ChordLibrary.all) {
        final names = c.toneNames.map((t) => t.$1).toSet();
        for (final p in c.pitches(6)) {
          expect(names.contains(p.letter), isTrue, reason: '${c.id}: ${p.key}');
        }
      }
    });

    test('Richtige Schreibweise: D-Dur mit Fis, H7 mit Dis', () {
      expect(ch('D').pitches(3).map((p) => p.key), ['A3', 'D4', 'F#4']);
      expect(ch('C').pitches(3).map((p) => p.key), ['G3', 'C4', 'E4']);
      expect(ch('B7').pitches(6).map((p) => p.key), ['B2', 'D#3', 'A3', 'B3', 'F#4']);
      expect(ch('E').pitches(6).map((p) => p.key), ['E2', 'B2', 'E3', 'G#3', 'B3', 'E4']);
    });

    test('Gleiche Griffbilder auf wenigen Saiten', () {
      expect(ch('E').sameShape(ch('E7'), 3), isTrue);
      expect(ch('E').sameShape(ch('E7'), 6), isFalse);
      expect(ch('Em').sameShape(ch('Cmaj7'), 3), isTrue);
      expect(ch('C').sameShape(ch('G'), 3), isFalse);
    });

    test('Namen nach Einstellung', () {
      expect(chordName(ch('B7'), NoteNaming.german), 'H7');
      expect(chordName(ch('B7'), NoteNaming.international), 'B7');
      expect(chordName(ch('Am'), NoteNaming.german), 'Am');
    });

    test('Klang von tief nach hoch', () {
      expect(ch('G').midis(6), [43, 47, 50, 55, 59, 67]);
      expect(ch('C').midis(3), [Guitar.openStrings[2], 60, 64]);
    });
  });

  group('Akkord-Lehrplan und Tour', () {
    final c = BuiltInChordCurricula.tour;

    test('Reihenfolge wie besprochen, Saiten wachsen', () {
      expect(c.steps.length, 8);
      expect(c.steps[0].chords, ['C', 'G', 'G7']);
      expect(c.steps[1].chords, ['Em', 'F']);
      expect(c.steps[2].chords, ['Am']);
      expect(c.steps[3].chords, ['D', 'Dm', 'D7']);
      expect([for (var i = 0; i < 8; i++) c.stringsAt(i)], [3, 3, 3, 3, 4, 5, 6, 6]);
      expect(c.chordsUpTo(1).map((x) => x.id), ['C', 'G', 'G7', 'Em', 'F']);
      // Jeder Akkord im Lehrplan existiert.
      for (final s in c.steps) {
        expect(s.chordList.length, s.chords.length);
      }
    });

    test('Level-Pläne', () {
      final warm = ChordTour.plan(c, 0, 0);
      expect(warm.pool.map((x) => x.id).toSet(), {'C', 'G', 'G7'});
      expect(warm.timeLimit, isNull);
      expect(warm.strings, 3);
      // Nur Am neu: Aufwärmen mit allen bisherigen Akkorden.
      expect(ChordTour.plan(c, 2, 0).pool.length, 6);
      final change = ChordTour.plan(c, 1, 3);
      expect(change.alternate, isTrue);
      expect(change.pool.map((x) => x.id), ['Em', 'F']);
      expect(ChordTour.plan(c, 2, 3).pool.map((x) => x.id), ['F', 'Am']);
      final concert = ChordTour.plan(c, 6, ChordTour.concertLevel);
      expect(concert.song, isTrue);
      expect(concert.strings, 6);
      expect(concert.timeLimit, isNotNull);
      final mini = ChordTour.plan(c, 6, 4, Difficulty.mini);
      final pro = ChordTour.plan(c, 6, 4, Difficulty.pro);
      expect(mini.timeLimit!.inSeconds, greaterThan(pro.timeLimit!.inSeconds));
    });

    test('Etappen öffnen sich nach Auftritt und Lehrperson', () {
      final p = Profile(id: 'x', nickname: 'Mia', character: Character.luna);
      expect(ChordTour.lockOf(p, c, 0), isNull);
      expect(ChordTour.lockOf(p, c, 1), StationLock.previous);
      ChordTour.record(p, c.id, 0, ChordTour.concertLevel, 2);
      expect(ChordTour.lockOf(p, c, 1), StationLock.teacher);
      p.chordStep = 1;
      expect(ChordTour.lockOf(p, c, 1), isNull);
      // Getrennt vom Noten-Abenteuer, und als Datei hin und zurück.
      expect(p.adventure, isEmpty);
      final again = Profile.fromJson(jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>);
      expect(again.chordStep, 1);
      expect(ChordTour.stars(again, c.id, 0, ChordTour.concertLevel), 2);
      expect(Profile.fromJson({'id': 'y'}).chordCurriculumId, BuiltInChordCurricula.tourId);
    });

    test('Lieder: richtige Länge, nie zweimal derselbe Akkord hintereinander', () {
      final pool = c.chordsUpTo(3);
      for (var seed = 0; seed < 30; seed++) {
        final song = Song.generate(pool, {ch('D'), ch('Dm')}, 15, Random(seed));
        expect(song.bars.length, 15);
        expect(song.title, isNotEmpty);
        for (var i = 1; i < song.bars.length; i++) {
          expect(song.bars[i], isNot(song.bars[i - 1]));
        }
        expect(song.bars.every(pool.contains), isTrue);
      }
    });

    test('Eigener Akkord-Lehrplan als Datei', () {
      final mine = ChordCurriculum(
        id: 'm',
        name: 'Meiner',
        steps: const [ChordStep(title: 'Start', chords: ['Am', 'Em'], strings: 3)],
      );
      final back = ChordCurriculum.fromJson(jsonDecode(jsonEncode(mine.toJson())) as Map<String, dynamic>);
      expect(back.steps.single.chords, ['Am', 'Em']);
      expect(back.steps.single.strings, 3);
    });
  });
}
