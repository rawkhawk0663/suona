import 'pitch.dart';

/// Wie Töne heissen (Einstellung im Lehrerbereich).
enum NoteNaming {
  /// C D E F G A H, Cis, Es, B; Oktaven als E, e, e', e''.
  german,

  /// C D E F G A B, C♯, E♭, B♭; Oktaven als E2 … E5.
  international,
}

/// Welche Vorzeichen in Arcade und freien Übungen vorkommen.
enum AccidentalStyle { sharps, flats, mixed }

const _sharpSign = '♯';
const _flatSign = '♭';

/// Name des Stammtons auf einer Taste (ohne Vorzeichen).
String letterLabel(Letter l, NoteNaming naming) {
  if (l == Letter.b) return naming == NoteNaming.german ? 'H' : 'B';
  return l.name.toUpperCase();
}

/// Name eines Tons ohne Oktave, wie ihn ein Kind sagen würde:
/// deutsch „Fis“, „Es“, „B“; international „F♯“, „E♭“, „B♭“.
String pitchName(Pitch p, NoteNaming naming) {
  if (naming == NoteNaming.international) {
    final acc = switch (p.accidental) {
      Accidental.sharp => _sharpSign,
      Accidental.flat => _flatSign,
      Accidental.natural => '',
    };
    return '${letterLabel(p.letter, naming)}$acc';
  }
  final lower = _germanLower(p);
  return lower[0].toUpperCase() + lower.substring(1);
}

/// Name mit Oktave: deutsch „E“, „e“, „e'“, „e''“ (Helmholtz),
/// international „E2“ … „E5“.
String pitchNameWithOctave(Pitch p, NoteNaming naming) {
  if (naming == NoteNaming.international) return '${pitchName(p, naming)}${p.octave}';
  final lower = _germanLower(p);
  switch (p.octave) {
    case <= 1:
      return '${lower[0].toUpperCase()}${lower.substring(1)}${"͵" * (2 - p.octave)}';
    case 2:
      return lower[0].toUpperCase() + lower.substring(1);
    case 3:
      return lower;
    default:
      return lower + "'" * (p.octave - 3);
  }
}

/// Deutscher Name klein: c, cis, des, es, b …
String _germanLower(Pitch p) {
  const base = ['c', 'd', 'e', 'f', 'g', 'a', 'h'];
  switch (p.accidental) {
    case Accidental.natural:
      return base[p.letter.index];
    case Accidental.sharp:
      return p.letter == Letter.b ? 'his' : '${base[p.letter.index]}is';
    case Accidental.flat:
      return switch (p.letter) {
        Letter.b => 'b',
        Letter.e => 'es',
        Letter.a => 'as',
        _ => '${base[p.letter.index]}es',
      };
  }
}

/// Zeichen für ein Vorzeichen auf einer Taste.
String accidentalSign(Accidental a) => switch (a) {
  Accidental.sharp => _sharpSign,
  Accidental.flat => _flatSign,
  Accidental.natural => '♮',
};
