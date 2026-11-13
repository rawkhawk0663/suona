import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:suona/core/audio/pitch_detector.dart';
import 'package:suona/core/audio/sounds.dart';
import 'package:suona/core/game/note_stats.dart';
import 'package:suona/core/game/rewards.dart';
import 'package:suona/core/music/note_names.dart';
import 'package:suona/core/music/pitch.dart';
import 'package:suona/core/profiles/profile.dart';
import 'package:suona/core/suona_state.dart';

void main() {
  group('Combo und Sterne', () {
    test('Faktor steigt mit der Serie', () {
      final c = Combo();
      final coins = [for (var i = 0; i < 11; i++) c.hit()];
      expect(coins.take(4), everyElement(5));
      expect(coins[4], 10); // 5. Treffer in Folge
      expect(coins[9], 15); // 10. Treffer
      c.miss();
      expect(c.hit(), 5);
    });

    test('Sterne', () {
      expect(starsFor(10, 10), 3);
      expect(starsFor(9, 10), 3);
      expect(starsFor(7, 10), 2);
      expect(starsFor(4, 10), 1);
      expect(starsFor(3, 10), 0);
    });
  });

  group('Tages-Streak', () {
    test('Folgetage, Pause und Schutz', () {
      final s = DailyStreak();
      final d0 = DateTime(2026, 11, 1);
      expect(s.registerPractice(d0), StreakEvent.started);
      expect(s.registerPractice(d0.add(const Duration(hours: 5))), StreakEvent.alreadyToday);
      for (var i = 1; i < 7; i++) {
        expect(s.registerPractice(DateTime(2026, 11, 1 + i)), StreakEvent.continued);
      }
      expect(s.days, 7);
      expect(s.shields, 1); // nach 7 Tagen
      // Ein Tag verpasst (8.11.), am 9.11. geübt: Schutz rettet.
      expect(s.currentDays(DateTime(2026, 11, 9)), 7);
      expect(s.registerPractice(DateTime(2026, 11, 9)), StreakEvent.savedByShield);
      expect(s.days, 8);
      expect(s.shields, 0);
      // Zwei Tage verpasst ohne Schutz: neu anfangen, aber nichts geht verloren.
      expect(s.currentDays(DateTime(2026, 11, 12)), 0);
      expect(s.registerPractice(DateTime(2026, 11, 12)), StreakEvent.started);
      expect(s.days, 1);
      expect(s.best, 8);
    });

    test('Monatswechsel', () {
      final s = DailyStreak();
      s.registerPractice(DateTime(2026, 10, 31));
      expect(s.registerPractice(DateTime(2026, 11, 1)), StreakEvent.continued);
    });
  });

  group('Lernkartei', () {
    test('Unsichere Töne kommen öfter', () {
      final stats = NoteStats();
      final e = Pitch.parse('E4'), f = Pitch.parse('F4');
      for (var i = 0; i < 5; i++) {
        stats.record(e, correct: true);
      }
      stats.record(f, correct: false);
      final picker = NotePicker(pool: [e, f], stats: stats, random: Random(1));
      var fCount = 0;
      for (var i = 0; i < 200; i++) {
        if (picker.next() == f) fCount++;
      }
      // Ohne Wiederholung wechseln sich zwei Töne ab, also genau die Hälfte.
      expect(fCount, 100);
      final three = NotePicker(pool: [e, f, Pitch.parse('G4')], stats: stats, random: Random(2));
      final counts = <Pitch, int>{};
      for (var i = 0; i < 3000; i++) {
        final p = three.next();
        counts[p] = (counts[p] ?? 0) + 1;
      }
      expect(counts[f]!, greaterThan(counts[e]! * 2));
    });

    test('Nie zweimal derselbe Ton hintereinander', () {
      final pool = Pitch.range(64, 67);
      final picker = NotePicker(pool: pool, stats: NoteStats(), random: Random(3));
      var last = picker.next();
      for (var i = 0; i < 100; i++) {
        final n = picker.next();
        expect(n, isNot(last));
        last = n;
      }
    });
  });

  group('Vorzeichen-Schreibweise', () {
    test('nur Kreuze, nur Bs, gemischt', () {
      final notes = Pitch.range(54, 56, sharps: true, flats: true); // F#3 Gb3 G3 G#3 Ab3
      expect(applyAccidentalStyle(notes, AccidentalStyle.sharps).map((p) => p.key), ['F#3', 'G3', 'G#3']);
      expect(applyAccidentalStyle(notes, AccidentalStyle.flats).map((p) => p.key), ['Gb3', 'G3', 'Ab3']);
      expect(applyAccidentalStyle(notes, AccidentalStyle.mixed).length, 5);
    });
  });

  test('Profil als Datei', () {
    final p = Profile(id: 'x', nickname: 'Mia', character: Character.luna, coins: 42, step: 2);
    p.stats.record(Pitch.parse('E4'), correct: true);
    p.streak.registerPractice(DateTime(2026, 11, 1));
    final again = Profile.fromJson(p.toJson());
    expect(again.nickname, 'Mia');
    expect(again.coins, 42);
    expect(again.step, 2);
    expect(again.stats.of(Pitch.parse('E4')).box, 1);
    expect(again.streak.days, 1);
  });

  group('Tonerkennung', () {
    const rate = 22050;
    Float32List sine(double f, int n) =>
        Float32List.fromList([for (var i = 0; i < n; i++) 0.3 * sin(2 * pi * f * i / rate)]);

    test('Sinustöne', () {
      final d = PitchDetector(sampleRate: rate);
      for (final midi in [40, 45, 55, 64, 76]) {
        final f = 440 * pow(2, (midi - 69) / 12).toDouble();
        final r = d.detect(sine(f, d.windowSize));
        expect(r.midi, midi, reason: 'MIDI $midi');
        expect(r.cents.abs(), lessThan(5));
      }
    });

    test('Gezupfte Saiten (mit Obertönen)', () {
      final d = PitchDetector(sampleRate: 44100);
      for (final midi in [40, 45, 50, 55, 59, 64, 69, 76]) {
        final s = Sounds.pluckSamples(midi);
        // Ein Stück aus der Mitte des Tons nehmen.
        final start = 44100 ~/ 5;
        final part = Float32List.sublistView(s, start, start + d.windowSize);
        final r = d.detect(Float32List.fromList(part));
        expect(r.midi, midi, reason: 'MIDI $midi');
      }
    });

    test('Stille', () {
      final d = PitchDetector(sampleRate: rate);
      expect(d.detect(Float32List(d.windowSize)).hasPitch, isFalse);
    });
  });
}
