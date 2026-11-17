import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:suona/core/audio/note_judge.dart';
import 'package:suona/core/audio/pitch_detector.dart';
import 'package:suona/core/audio/sounds.dart';

PitchReading note(int midi, {double clarity = 0.95, double cents = 0}) => PitchReading(
  frequency: 440 * pow(2, (midi + cents / 100 - 69) / 12).toDouble(),
  clarity: clarity,
  level: 0.1,
);

/// Werte so lange einspeisen, bis eine Entscheidung kommt.
NoteDecision? feed(NoteJudge j, Iterable<PitchReading> readings) {
  for (final r in readings) {
    final d = j.add(r);
    if (d != null) return d;
  }
  return null;
}

void main() {
  group('Mit der Gitarre antworten', () {
    test('Richtiger Ton nach kurzer Zeit erkannt', () {
      final j = NoteJudge()..expect(64);
      final d = feed(j, List.filled(20, note(64)));
      expect(d?.correct, isTrue);
      expect(d?.midi, 64);
    });

    test('Kurz nach der Frage wird noch nicht hingehört', () {
      final j = NoteJudge()..expect(64);
      // Acht Werte (0,4 s) Schonzeit, dann drei stabile Werte.
      expect(feed(j, List.filled(10, note(64))), isNull);
      expect(j.add(note(64))?.correct, isTrue);
    });

    test('Falscher Ton zählt erst nach etwas längerer Zeit', () {
      final j = NoteJudge(graceReadings: 0)..expect(64);
      expect(feed(j, List.filled(3, note(65))), isNull);
      final d = j.add(note(65));
      expect(d?.correct, isFalse);
      expect(d?.midi, 65);
    });

    test('Ein kurzer Knackser oder unklarer Ton zählt nicht', () {
      final j = NoteJudge(graceReadings: 0)..expect(64);
      expect(feed(j, [note(60), note(61), note(62), note(60, clarity: 0.5), note(60, clarity: 0.5)]), isNull);
      expect(feed(j, [note(64, cents: 45), note(64, cents: 45), note(64, cents: 45), note(64, cents: 45)]), isNull);
      expect(feed(j, List.filled(3, note(64)))?.correct, isTrue);
    });

    test('Der Ton der letzten Frage klingt nach und zählt nicht', () {
      final j = NoteJudge(graceReadings: 0)..expect(67, previous: 64);
      // Die alte Saite klingt weiter: keine Entscheidung.
      expect(feed(j, List.filled(20, note(64))), isNull);
      // Nach einer Pause zählt derselbe Ton wieder (falsch gespielt).
      j.add(PitchReading.silent);
      expect(feed(j, List.filled(4, note(64)))?.correct, isFalse);
    });

    test('Glöckchen der App (ausserhalb der Gitarre) zählt nicht', () {
      final j = NoteJudge(graceReadings: 0)..expect(64);
      expect(feed(j, List.filled(10, note(81))), isNull);
    });

    test('Echte gezupfte Saite über die Tonerkennung', () {
      // Wie im Spiel: 20 Auswertungen pro Sekunde, jeweils ein Fenster der Tonerkennung.
      const rate = 44100;
      final det = PitchDetector(sampleRate: rate);
      for (final midi in [40, 47, 55, 60, 64, 72]) {
        final samples = Sounds.pluckSamples(midi);
        final j = NoteJudge()..expect(midi);
        NoteDecision? d;
        for (var start = 0; start + det.windowSize < samples.length && d == null; start += rate ~/ 20) {
          final part = Float32List.fromList(Float32List.sublistView(samples, start, start + det.windowSize));
          d = j.add(det.detect(part));
        }
        expect(d?.correct, isTrue, reason: 'MIDI $midi');
      }
    });
  });
}
