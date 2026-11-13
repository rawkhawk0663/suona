import 'pitch.dart';

/// Eine Stelle auf dem Griffbrett. Saite 1 ist die hohe e-Saite, 6 die tiefe E-Saite.
class FretPosition {
  const FretPosition(this.string, this.fret);
  final int string;
  final int fret;

  @override
  bool operator ==(Object other) => other is FretPosition && other.string == string && other.fret == fret;

  @override
  int get hashCode => Object.hash(string, fret);

  @override
  String toString() => '$string/$fret';
}

/// Standardstimmung und Griffbrett bis zum 12. Bund.
class Guitar {
  Guitar._();

  /// Leere Saiten (MIDI), Index 0 = Saite 1 (e'), Index 5 = Saite 6 (E).
  static const openStrings = [64, 59, 55, 50, 45, 40];

  /// Saitennamen, wie sie Gitarristen sagen (deutsch: e h g d A E).
  static const stringNamesGerman = ['e', 'h', 'g', 'd', 'A', 'E'];
  static const stringNamesInternational = ['E', 'B', 'G', 'D', 'A', 'E'];

  static const maxFret = 12;

  /// Tiefster und höchster Ton bis zum 12. Bund.
  static const lowest = 40; // E2
  static const highest = 76; // E5

  /// Klingender Ton an einer Stelle.
  static int midiAt(FretPosition p) => openStrings[p.string - 1] + p.fret;

  /// Alle Stellen, an denen [midi] liegt (bis [maxFret]).
  static List<FretPosition> positionsOf(int midi, {int maxFret = Guitar.maxFret}) {
    final out = <FretPosition>[];
    for (var s = 1; s <= 6; s++) {
      final fret = midi - openStrings[s - 1];
      if (fret >= 0 && fret <= maxFret) out.add(FretPosition(s, fret));
    }
    return out;
  }

  /// Alle Töne auf den gewählten [strings] zwischen [minFret] und [maxFret].
  static List<Pitch> pitchesIn({
    Set<int> strings = const {1, 2, 3, 4, 5, 6},
    int minFret = 0,
    int maxFret = 12,
    bool sharps = false,
    bool flats = false,
  }) {
    final midis = <int>{};
    for (final s in strings) {
      for (var f = minFret; f <= maxFret; f++) {
        midis.add(openStrings[s - 1] + f);
      }
    }
    final out = <Pitch>[];
    for (final m in midis.toList()..sort()) {
      out.addAll(Pitch.range(m, m, sharps: sharps, flats: flats));
    }
    return out;
  }
}
