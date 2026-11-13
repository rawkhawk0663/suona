/// Ein notierter Ton: Stammton, Vorzeichen und Oktave.
///
/// Die Oktave zählt wie international üblich: C4 ist das eingestrichene c'
/// (das „mittlere C“). Gespeichert wird immer der **klingende** Ton. Gitarren
/// lesen eine Oktave höher, als sie klingen (Violinschlüssel mit kleiner 8),
/// das rechnet [staffStep] ein.
library;

import 'dart:math' as math;

/// Stammtöne. `b` ist das deutsche H.
enum Letter { c, d, e, f, g, a, b }

/// Halbtöne von C aus für jeden Stammton.
const _letterSemis = [0, 2, 4, 5, 7, 9, 11];

/// Vorzeichen in der Notenschrift.
enum Accidental {
  flat(-1),
  natural(0),
  sharp(1);

  const Accidental(this.shift);
  final int shift;
}

class Pitch implements Comparable<Pitch> {
  const Pitch(this.letter, this.octave, [this.accidental = Accidental.natural]);

  final Letter letter;
  final int octave;
  final Accidental accidental;

  /// MIDI-Nummer (E2 = 40, A4 = 69).
  int get midi => 12 * (octave + 1) + _letterSemis[letter.index] + accidental.shift;

  /// Frequenz in Hz (A4 = 440 Hz).
  double get frequency => 440.0 * math.pow(2, (midi - 69) / 12.0);

  /// Stelle im Notensystem der Gitarre (Violinschlüssel mit 8, also eine
  /// Oktave höher notiert): 0 = unterste Linie (notiertes e'), 1 = erster
  /// Zwischenraum … 8 = oberste Linie. Negative Werte liegen darunter.
  int get staffStep => (octave + 1) * 7 + letter.index - 30;

  bool get hasAccidental => accidental != Accidental.natural;

  /// Gleicher Klang, andere Schreibweise (Fis ↔ Ges). Null bei Stammtönen,
  /// die keine einfache Alternative haben.
  Pitch? get enharmonic {
    if (accidental == Accidental.sharp) {
      // Cis → Des, aber Eis/His gibt es hier nicht.
      if (letter == Letter.e || letter == Letter.b) return null;
      final next = Letter.values[(letter.index + 1) % 7];
      return Pitch(next, letter == Letter.b ? octave + 1 : octave, Accidental.flat);
    }
    if (accidental == Accidental.flat) {
      if (letter == Letter.f || letter == Letter.c) return null;
      final prev = Letter.values[(letter.index + 6) % 7];
      return Pitch(prev, letter == Letter.c ? octave - 1 : octave, Accidental.sharp);
    }
    return null;
  }

  /// Kurzer Schlüssel zum Speichern, z. B. „E2“, „F#3“, „Bb3“.
  String get key {
    final acc = switch (accidental) {
      Accidental.sharp => '#',
      Accidental.flat => 'b',
      Accidental.natural => '',
    };
    return '${letter.name.toUpperCase()}$acc$octave';
  }

  static Pitch? tryParse(String key) {
    final m = RegExp(r'^([A-Ga-g])([#b]?)(-?\d)$').firstMatch(key.trim());
    if (m == null) return null;
    final letter = Letter.values.byName(m.group(1)!.toLowerCase());
    final acc = switch (m.group(2)) {
      '#' => Accidental.sharp,
      'b' => Accidental.flat,
      _ => Accidental.natural,
    };
    return Pitch(letter, int.parse(m.group(3)!), acc);
  }

  static Pitch parse(String key) => tryParse(key) ?? (throw FormatException('Unbekannter Ton: $key'));

  /// Alle chromatischen Töne in [low]..[high] (MIDI), je nach Schreibweise.
  /// [sharps]/[flats]: welche Vorzeichen vorkommen dürfen. Ist beides an,
  /// erscheinen erhöhte und erniedrigte Fassung.
  static List<Pitch> range(int low, int high, {bool naturals = true, bool sharps = false, bool flats = false}) {
    final out = <Pitch>[];
    for (var m = low; m <= high; m++) {
      final octave = m ~/ 12 - 1;
      final semi = m % 12;
      final natural = _letterSemis.indexOf(semi);
      if (natural >= 0) {
        if (naturals) out.add(Pitch(Letter.values[natural], octave));
        continue;
      }
      if (sharps) {
        out.add(Pitch(Letter.values[_letterSemis.indexOf(semi - 1)], octave, Accidental.sharp));
      }
      if (flats) {
        out.add(Pitch(Letter.values[_letterSemis.indexOf(semi + 1)], octave, Accidental.flat));
      }
    }
    return out;
  }

  @override
  int compareTo(Pitch other) {
    final d = midi - other.midi;
    return d != 0 ? d : staffStep - other.staffStep;
  }

  @override
  bool operator ==(Object other) =>
      other is Pitch && other.letter == letter && other.octave == octave && other.accidental == accidental;

  @override
  int get hashCode => Object.hash(letter, octave, accidental);

  @override
  String toString() => key;
}
