import '../../app/l10n.dart';
import 'guitar.dart';
import 'note_names.dart';
import 'pitch.dart';

/// Ein Intervall über dem Grundton: Abstand in Stammtönen und Halbtönen.
/// Daraus entsteht die richtige Schreibweise (D-Dur hat Fis, nicht Ges).
class _Interval {
  const _Interval(this.letters, this.semis);
  final int letters;
  final int semis;
}

const _root = _Interval(0, 0);
const _second = _Interval(1, 2);
const _minorThird = _Interval(2, 3);
const _majorThird = _Interval(2, 4);
const _fourth = _Interval(3, 5);
const _fifth = _Interval(4, 7);
const _minorSeventh = _Interval(6, 10);
const _majorSeventh = _Interval(6, 11);

const _letterSemis = [0, 2, 4, 5, 7, 9, 11];

/// Ein Griff auf der Gitarre, wie er im Liederbuch steht.
///
/// Gespeichert ist immer der volle Griff auf sechs Saiten. Für die ersten
/// Etappen wird er auf die hohen Saiten gekürzt ([fretsOn]): Der kleine
/// C-Griff auf drei Saiten ist einfach der grosse C-Griff ohne d-, A- und
/// E-Saite. So kennt das Kind die Griffe schon, wenn Saiten dazukommen.
class Chord {
  const Chord._(this.id, this.root, this.rootAccidental, this.suffix, this._tones, this._frets, this._fingers);

  /// Aus Liederbuch-Schreibweise: Bünde und Finger von der tiefen E-Saite
  /// zur hohen e-Saite, „x“ = nicht spielen, „0“ = leer.
  factory Chord._parse(
    String id,
    Letter root,
    String suffix,
    List<_Interval> tones,
    String frets,
    String fingers, {
    Accidental accidental = Accidental.natural,
  }) {
    assert(frets.length == 6 && fingers.length == 6);
    // Index 0 = Saite 1 (hohe e-Saite), wie in guitar.dart.
    final f = <int?>[for (var i = 5; i >= 0; i--) frets[i] == 'x' ? null : int.parse(frets[i])];
    final g = <int>[for (var i = 5; i >= 0; i--) int.parse(fingers[i])];
    return Chord._(id, root, accidental, suffix, tones, f, g);
  }

  /// Schlüssel zum Speichern (international, z. B. „B7“ für H7).
  final String id;
  final Letter root;
  final Accidental rootAccidental;

  /// Zusatz hinter dem Grundton: '', 'm', '7', 'maj7' …
  final String suffix;
  final List<_Interval> _tones;
  final List<int?> _frets;
  final List<int> _fingers;

  /// Dur, Moll oder Septakkord (für die Erklärung).
  bool get isMinor => suffix.startsWith('m') && !suffix.startsWith('maj');

  /// Bund auf Saite [string] (1 = hohe e-Saite) im vollen Griff; null = nicht spielen.
  int? fretOn(int string) => _frets[string - 1];

  /// Finger (1–4) auf Saite [string]; 0 = kein Finger.
  int fingerOn(int string) => _fingers[string - 1];

  /// Der Griff, gekürzt auf die hohen [strings] Saiten: Saite → Bund
  /// (fehlt eine Saite, wird sie nicht gespielt).
  Map<int, int> fretsOn(int strings) => {
    for (var s = 1; s <= strings; s++)
      if (_frets[s - 1] != null) s: _frets[s - 1]!,
  };

  /// Gespielte Stellen auf [strings] Saiten (Bund 0 = leer).
  List<FretPosition> positions(int strings) => [for (final e in fretsOn(strings).entries) FretPosition(e.key, e.value)];

  /// Gegriffene Stellen (ohne leere Saiten), so wie Punkte im Griffbild.
  Set<FretPosition> dots(int strings) => {
    for (final e in fretsOn(strings).entries)
      if (e.value > 0) FretPosition(e.key, e.value),
  };

  /// Nicht gespielte Saiten unter den [strings] gezeigten.
  Set<int> muted(int strings) => {
    for (var s = 1; s <= strings; s++)
      if (_frets[s - 1] == null) s,
  };

  /// Klingende Töne von tief nach hoch (für Klang und Notenstapel).
  List<int> midis(int strings) {
    final out = [for (final p in positions(strings)) Guitar.midiAt(p)]..sort();
    return out;
  }

  /// Die Töne des Akkords richtig geschrieben (D-Dur: D, Fis, A).
  List<(Letter, Accidental)> get toneNames => [
    for (final t in _tones)
      () {
        final letter = Letter.values[(root.index + t.letters) % 7];
        final want = (_letterSemis[root.index] + rootAccidental.shift + t.semis) % 12;
        var diff = (want - _letterSemis[letter.index]) % 12;
        if (diff > 6) diff -= 12;
        final acc = switch (diff) {
          1 => Accidental.sharp,
          -1 => Accidental.flat,
          _ => Accidental.natural,
        };
        return (letter, acc);
      }(),
  ];

  /// Klingende Töne mit Schreibweise, von tief nach hoch (für das Notensystem).
  List<Pitch> pitches(int strings) {
    final names = toneNames;
    final out = <Pitch>[];
    for (final m in midis(strings)) {
      Pitch? found;
      for (final (l, a) in names) {
        if ((_letterSemis[l.index] + a.shift - m) % 12 != 0) continue;
        // Oktave so wählen, dass genau dieser Ton herauskommt.
        for (final o in [m ~/ 12 - 2, m ~/ 12 - 1, m ~/ 12]) {
          final p = Pitch(l, o, a);
          if (p.midi == m) found = p;
        }
      }
      out.add(found ?? Pitch.range(m, m, sharps: true).first);
    }
    return out;
  }

  /// Gleich gegriffen auf [strings] Saiten (z. B. E und E7 auf drei Saiten).
  bool sameShape(Chord other, int strings) {
    final a = fretsOn(strings), b = other.fretsOn(strings);
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  bool operator ==(Object other) => other is Chord && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => id;
}

/// Name eines Akkords nach Einstellung: deutsch „H7“, international „B7“.
String chordName(Chord c, NoteNaming naming) {
  final acc = switch (c.rootAccidental) {
    Accidental.sharp => naming == NoteNaming.german ? 'is' : '♯',
    Accidental.flat => naming == NoteNaming.german ? 'es' : '♭',
    Accidental.natural => '',
  };
  return '${letterLabel(c.root, naming)}$acc${c.suffix}';
}

/// Kurze Beschreibung für die Lehrperson (Dur, Moll, Sept …).
String chordKind(Chord c) => switch (c.suffix) {
  '' => tr('Dur', 'major'),
  'm' => tr('Moll', 'minor'),
  '7' => tr('Septakkord', 'seventh'),
  'm7' => tr('Moll-Sept', 'minor seventh'),
  'maj7' => tr('grosse Sept', 'major seventh'),
  'sus2' => 'sus2',
  'sus4' => 'sus4',
  _ => c.suffix,
};

/// Alle Griffe, die Suona kennt. Offene Lage, ohne Barré.
class ChordLibrary {
  ChordLibrary._();

  static final List<Chord> all = [
    Chord._parse('C', Letter.c, '', const [_root, _majorThird, _fifth], 'x32010', '032010'),
    Chord._parse('G', Letter.g, '', const [_root, _majorThird, _fifth], '320003', '210003'),
    Chord._parse('G7', Letter.g, '7', const [_root, _majorThird, _fifth, _minorSeventh], '320001', '320001'),
    Chord._parse('Em', Letter.e, 'm', const [_root, _minorThird, _fifth], '022000', '023000'),
    Chord._parse('F', Letter.f, '', const [_root, _majorThird, _fifth], 'xx3211', '003211'),
    Chord._parse('Am', Letter.a, 'm', const [_root, _minorThird, _fifth], 'x02210', '002310'),
    Chord._parse('D', Letter.d, '', const [_root, _majorThird, _fifth], 'xx0232', '000132'),
    Chord._parse('Dm', Letter.d, 'm', const [_root, _minorThird, _fifth], 'xx0231', '000231'),
    Chord._parse('D7', Letter.d, '7', const [_root, _majorThird, _fifth, _minorSeventh], 'xx0212', '000213'),
    Chord._parse('A', Letter.a, '', const [_root, _majorThird, _fifth], 'x02220', '001230'),
    Chord._parse('A7', Letter.a, '7', const [_root, _majorThird, _fifth, _minorSeventh], 'x02020', '002030'),
    Chord._parse('E', Letter.e, '', const [_root, _majorThird, _fifth], '022100', '023100'),
    Chord._parse('E7', Letter.e, '7', const [_root, _majorThird, _fifth, _minorSeventh], '020100', '020100'),
    Chord._parse('B7', Letter.b, '7', const [_root, _majorThird, _fifth, _minorSeventh], 'x21202', '021304'),
    Chord._parse('C7', Letter.c, '7', const [_root, _majorThird, _fifth, _minorSeventh], 'x32310', '032410'),
    Chord._parse('Am7', Letter.a, 'm7', const [_root, _minorThird, _fifth, _minorSeventh], 'x02010', '002010'),
    Chord._parse('Em7', Letter.e, 'm7', const [_root, _minorThird, _fifth, _minorSeventh], '020000', '020000'),
    Chord._parse('Dm7', Letter.d, 'm7', const [_root, _minorThird, _fifth, _minorSeventh], 'xx0211', '000211'),
    Chord._parse('Cmaj7', Letter.c, 'maj7', const [_root, _majorThird, _fifth, _majorSeventh], 'x32000', '032000'),
    Chord._parse('Fmaj7', Letter.f, 'maj7', const [_root, _majorThird, _fifth, _majorSeventh], 'xx3210', '003210'),
    Chord._parse('Dsus2', Letter.d, 'sus2', const [_root, _second, _fifth], 'xx0230', '000130'),
    Chord._parse('Dsus4', Letter.d, 'sus4', const [_root, _fourth, _fifth], 'xx0233', '000134'),
    Chord._parse('Asus2', Letter.a, 'sus2', const [_root, _second, _fifth], 'x02200', '001200'),
    Chord._parse('Asus4', Letter.a, 'sus4', const [_root, _fourth, _fifth], 'x02230', '001230'),
    Chord._parse('Esus4', Letter.e, 'sus4', const [_root, _fourth, _fifth], '022200', '023400'),
  ];

  static final Map<String, Chord> _byId = {for (final c in all) c.id: c};

  static Chord? byId(String id) => _byId[id];
}

/// Ein Schritt im Akkord-Lehrplan: neue Akkorde und auf wie vielen Saiten.
class ChordStep {
  const ChordStep({required this.title, required this.chords, required this.strings});

  final String title;

  /// Neu (oder neu mit mehr Saiten) in diesem Schritt.
  final List<String> chords;

  /// Wie viele Saiten das Griffbild ab hier zeigt (3 = g, h, e … 6 = alle).
  final int strings;

  List<Chord> get chordList => [for (final id in chords) ?ChordLibrary.byId(id)];

  Map<String, dynamic> toJson() => {'title': title, 'chords': chords, 'strings': strings};

  static ChordStep fromJson(Map<String, dynamic> j) => ChordStep(
    title: j['title'] as String? ?? '',
    chords: [for (final x in (j['chords'] as List<dynamic>? ?? const [])) x.toString()],
    strings: ((j['strings'] as num?)?.toInt() ?? 6).clamp(3, 6),
  );
}

/// Ein Akkord-Lehrplan: in welcher Reihenfolge die Akkorde kommen.
class ChordCurriculum {
  const ChordCurriculum({
    required this.id,
    required this.name,
    required this.steps,
    this.builtIn = false,
    this.description = '',
  });

  final String id;
  final String name;
  final String description;
  final List<ChordStep> steps;
  final bool builtIn;

  /// Alle Akkorde bis und mit Schritt [index], ohne Doppelte, in Lernreihenfolge.
  List<Chord> chordsUpTo(int index) {
    final out = <Chord>[];
    for (var i = 0; i <= index && i < steps.length; i++) {
      for (final c in steps[i].chordList) {
        if (!out.contains(c)) out.add(c);
      }
    }
    return out;
  }

  /// Saiten im Griffbild bis und mit Schritt [index] (nie weniger als vorher).
  int stringsAt(int index) {
    var s = 3;
    for (var i = 0; i <= index && i < steps.length; i++) {
      if (steps[i].strings > s) s = steps[i].strings;
    }
    return s;
  }

  ChordCurriculum copyWith({String? id, String? name, List<ChordStep>? steps, bool? builtIn, String? description}) =>
      ChordCurriculum(
        id: id ?? this.id,
        name: name ?? this.name,
        steps: steps ?? this.steps,
        builtIn: builtIn ?? this.builtIn,
        description: description ?? this.description,
      );

  Map<String, dynamic> toJson() => {
    'format': 'suona-akkordplan',
    'version': 1,
    'id': id,
    'name': name,
    'description': description,
    'steps': [for (final s in steps) s.toJson()],
  };

  static ChordCurriculum fromJson(Map<String, dynamic> j) => ChordCurriculum(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    description: j['description'] as String? ?? '',
    steps: [for (final s in (j['steps'] as List<dynamic>? ?? const [])) ChordStep.fromJson(s as Map<String, dynamic>)],
  );
}

/// Eingebaute Akkord-Lehrpläne.
class BuiltInChordCurricula {
  BuiltInChordCurricula._();

  static const tourId = 'akkord-tour';

  static List<ChordCurriculum> get all => [tour];

  /// Von drei Saiten zu sechs (Reihenfolge vom Besitzer festgelegt):
  /// zuerst die kleinen Griffe auf g-, h- und e-Saite, dann kommen dieselben
  /// Akkorde mit mehr Saiten wieder.
  static ChordCurriculum get tour => ChordCurriculum(
    id: tourId,
    name: tr('Akkord-Tour', 'Chord tour'),
    builtIn: true,
    description: tr(
      'Zuerst kleine Griffe auf drei Saiten, dann bis zu allen sechs Saiten.',
      'Small shapes on three strings first, then up to all six strings.',
    ),
    steps: [
      ChordStep(title: tr('C, G und G7', 'C, G and G7'), chords: const ['C', 'G', 'G7'], strings: 3),
      ChordStep(title: tr('Em und F', 'Em and F'), chords: const ['Em', 'F'], strings: 3),
      ChordStep(title: tr('Am', 'Am'), chords: const ['Am'], strings: 3),
      ChordStep(title: tr('D, Dm und D7', 'D, Dm and D7'), chords: const ['D', 'Dm', 'D7'], strings: 3),
      ChordStep(title: tr('Mit der d-Saite', 'With the D string'), chords: const ['D', 'D7', 'Dm', 'F'], strings: 4),
      ChordStep(title: tr('Mit der A-Saite', 'With the A string'), chords: const ['C', 'Am', 'A', 'A7'], strings: 5),
      ChordStep(title: tr('Alle sechs Saiten', 'All six strings'), chords: const ['Em', 'E', 'E7', 'G', 'G7'], strings: 6),
      ChordStep(title: tr('H7 und alles', 'B7 and everything'), chords: const ['B7'], strings: 6),
    ],
  );
}
