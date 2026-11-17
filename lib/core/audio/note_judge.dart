import '../music/guitar.dart';
import 'pitch_detector.dart';

/// Was der Schiedsrichter gehört hat.
class NoteDecision {
  const NoteDecision(this.midi, {required this.correct});

  /// Gehörter Ton (klingende MIDI-Zahl).
  final int midi;
  final bool correct;
}

/// Entscheidet aus den laufenden Mikrofon-Werten, welcher Ton gespielt wurde.
///
/// Damit Kinder nicht wegen eines Knacksers einen Fehler bekommen, zählt ein
/// Ton erst, wenn er einige Male hintereinander klar erkannt wurde
/// (richtig: [stableRight] Werte ≈ 0,15 s, falsch: [stableWrong] ≈ 0,2 s).
/// Kurz nach einer neuen Frage hört er noch nicht hin ([graceReadings]),
/// und der Ton der letzten Frage (der vielleicht noch klingt oder den die
/// App selbst abgespielt hat) zählt erst wieder, wenn er einmal aufgehört hat.
/// Töne ausserhalb der Gitarre (Glöckchen, Münzen) werden überhört.
class NoteJudge {
  NoteJudge({this.stableRight = 3, this.stableWrong = 4, this.graceReadings = 8, this.minClarity = 0.85});

  final int stableRight;
  final int stableWrong;
  final int graceReadings;
  final double minClarity;

  int? _target;
  int? _ignore;
  int _grace = 0;
  int? _candidate;
  int _count = 0;

  /// Zuletzt sicher erkannter Ton (für die Anzeige „Ich höre …“), auch ohne Entscheidung.
  int? heard;

  /// Neue Frage: auf [target] warten. [previous] ist der Ton der letzten Frage.
  void expect(int target, {int? previous}) {
    _target = target;
    _ignore = previous;
    _grace = graceReadings;
    _candidate = null;
    _count = 0;
    heard = null;
  }

  /// Nichts mehr erwarten (Antwort ist schon da).
  void pause() => _target = null;

  /// Einen Wert verarbeiten. Gibt eine Entscheidung zurück, sobald sie feststeht.
  NoteDecision? add(PitchReading r) {
    final ok = r.hasPitch &&
        r.clarity >= minClarity &&
        r.midi >= Guitar.lowest - 1 &&
        r.midi <= Guitar.highest + 1 &&
        r.cents.abs() <= 40;
    final midi = ok ? r.midi : null;
    // Der alte Ton zählt erst wieder, wenn er einmal weg war.
    if (_ignore != null && midi != _ignore) _ignore = null;
    if (_grace > 0) {
      _grace--;
      return null;
    }
    if (midi == null || midi == _ignore) {
      _candidate = null;
      _count = 0;
      return null;
    }
    if (midi == _candidate) {
      _count++;
    } else {
      _candidate = midi;
      _count = 1;
    }
    if (_count >= stableRight) heard = midi;
    final target = _target;
    if (target == null) return null;
    if (midi == target && _count >= stableRight) {
      _target = null;
      return NoteDecision(midi, correct: true);
    }
    if (midi != target && _count >= stableWrong) {
      _target = null;
      return NoteDecision(midi, correct: false);
    }
    return null;
  }
}
