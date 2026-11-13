import 'dart:math';

import '../music/guitar.dart';
import '../music/note_names.dart';
import '../music/pitch.dart';

/// Arten von Fragen.
enum QuestionType {
  /// Note im Notensystem → Namen antippen („Wie heisst die Note?“).
  nameFromStaff,

  /// Note im Notensystem → Stelle auf dem Griffbrett antippen („Wo liegt die Note?“).
  fretFromStaff,

  /// Punkt auf dem Griffbrett → Namen antippen („Welcher Ton ist das?“).
  nameFromFret,

  /// Punkt auf dem Griffbrett → Note ins Notensystem setzen.
  staffFromFret;

  bool get showsStaff => this == nameFromStaff || this == fretFromStaff;
  bool get answersWithName => this == nameFromStaff || this == nameFromFret;

  /// Lernstand: Notenlesen zählt getrennt vom Griffbrett-Wissen.
  String get statsPrefix => this == nameFromStaff ? '' : NoteStatsPrefix.fretboard;
}

class NoteStatsPrefix {
  NoteStatsPrefix._();

  /// Präfix der Lernkartei für alles, was mit dem Griffbrett zu tun hat.
  static const fretboard = 'G:';
}

/// Ausschnitt des Griffbretts: welche Saiten, welche Bünde.
class FretRange {
  const FretRange({this.strings = const {1, 2, 3, 4, 5, 6}, this.minFret = 0, this.maxFret = 12});

  /// Das ganze Griffbrett bis zum 12. Bund.
  static const full = FretRange();

  final Set<int> strings;
  final int minFret;
  final int maxFret;

  bool contains(FretPosition p) => strings.contains(p.string) && p.fret >= minFret && p.fret <= maxFret;

  /// Stellen von [midi] in diesem Ausschnitt.
  List<FretPosition> positionsOf(int midi) => Guitar.positionsOf(midi).where(contains).toList();

  /// Alle Töne in diesem Ausschnitt.
  List<Pitch> pitches({bool sharps = false, bool flats = false}) =>
      Guitar.pitchesIn(strings: strings, minFret: minFret, maxFret: maxFret, sharps: sharps, flats: flats);

  Map<String, dynamic> toJson() => {'strings': strings.toList()..sort(), 'min': minFret, 'max': maxFret};

  static FretRange fromJson(Map<String, dynamic>? j) {
    if (j == null) return full;
    final strings = {for (final s in (j['strings'] as List<dynamic>? ?? const [])) (s as num).toInt()};
    return FretRange(
      strings: strings.isEmpty ? const {1, 2, 3, 4, 5, 6} : strings,
      minFret: ((j['min'] as num?)?.toInt() ?? 0).clamp(0, Guitar.maxFret),
      maxFret: ((j['max'] as num?)?.toInt() ?? Guitar.maxFret).clamp(0, Guitar.maxFret),
    );
  }
}

/// Eine gestellte Frage.
class Question {
  const Question({required this.type, required this.pitch, this.shown, this.accepted = const [], this.onString});

  final QuestionType type;

  /// Der gesuchte Ton (bei Fragen mit Notensystem mit genau dieser Schreibweise).
  final Pitch pitch;

  /// Bei Fragen vom Griffbrett aus: der leuchtende Punkt.
  final FretPosition? shown;

  /// Bei „Wo liegt die Note?“: alle Stellen, die als richtig zählen.
  final List<FretPosition> accepted;

  /// Bei „Wo liegt die Note?“ mit vorgegebener Saite: diese Saite.
  final int? onString;
}

/// Baut Fragen zu einem Ton.
class QuestionFactory {
  QuestionFactory({this.range, this.fixedString = false, Random? random}) : _random = random ?? Random();

  /// Griffbrett-Ausschnitt (null = ganzes Griffbrett, gezeigt wird die
  /// tiefste Stelle, also so, wie man den Ton zuerst lernt).
  final FretRange? range;

  /// Bei „Wo liegt die Note?“ eine Saite vorgeben.
  final bool fixedString;
  final Random _random;

  Question build(QuestionType type, Pitch pitch) {
    final r = range ?? FretRange.full;
    var positions = r.positionsOf(pitch.midi);
    if (positions.isEmpty) positions = Guitar.positionsOf(pitch.midi);
    switch (type) {
      case QuestionType.nameFromStaff:
        return Question(type: type, pitch: pitch);
      case QuestionType.fretFromStaff:
        if (fixedString && positions.isNotEmpty) {
          final p = positions[_random.nextInt(positions.length)];
          return Question(type: type, pitch: pitch, accepted: [p], onString: p.string);
        }
        return Question(type: type, pitch: pitch, accepted: positions);
      case QuestionType.nameFromFret:
      case QuestionType.staffFromFret:
        final shown = range == null
            ? (positions.toList()..sort((a, b) => a.fret.compareTo(b.fret))).first
            : positions[_random.nextInt(positions.length)];
        return Question(type: type, pitch: pitch, shown: shown, accepted: positions);
    }
  }
}

/// Halbton (0–11) eines Stammtons mit Vorzeichen.
int pitchClassOf(Letter letter, Accidental accidental) =>
    (const [0, 2, 4, 5, 7, 9, 11][letter.index] + accidental.shift + 12) % 12;

/// Ist der angetippte Name richtig? Mit [enharmonicOk] zählt auch die
/// andere Schreibweise (Fis statt Ges), z. B. wenn nur ein Punkt auf dem
/// Griffbrett gezeigt wird und die Schreibweise offen ist.
bool isRightName(Pitch target, Letter letter, Accidental accidental, {bool enharmonicOk = false}) {
  if (letter == target.letter && accidental == target.accidental) return true;
  return enharmonicOk && pitchClassOf(letter, accidental) == target.midi % 12;
}

/// Klingender Ton zu einer Stelle im Gitarren-Notensystem (siehe [Pitch.staffStep]).
Pitch pitchFromStaffStep(int step, Accidental accidental) {
  final diatonic = step + 30;
  final writtenOctave = diatonic ~/ 7;
  return Pitch(Letter.values[diatonic % 7], writtenOctave - 1, accidental);
}

/// Kurzer Text für eine Stelle, z. B. „g-Saite, 2. Bund“ oder „leere A-Saite“.
String positionLabel(FretPosition p, NoteNaming naming, {required bool english}) {
  final names = naming == NoteNaming.german ? Guitar.stringNamesGerman : Guitar.stringNamesInternational;
  final s = names[p.string - 1];
  if (english) {
    final ord = '${p.string}${const ['st', 'nd', 'rd', 'th', 'th', 'th'][p.string - 1]}';
    return p.fret == 0 ? 'open $s string ($ord)' : '$s string ($ord), fret ${p.fret}';
  }
  return p.fret == 0 ? 'leere $s-Saite' : '$s-Saite, ${p.fret}. Bund';
}
