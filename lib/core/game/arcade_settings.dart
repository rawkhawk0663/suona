import '../../app/l10n.dart';
import 'question.dart';

/// Was im Arcade-Modus gefragt wird.
enum ArcadeAnswer {
  /// Note → Name
  name,

  /// Note → Griffbrett
  fret,

  /// Griffbrett → Name
  fretName,

  /// Griffbrett → Note setzen
  staff,

  /// Alles gemischt
  mixed;

  List<QuestionType> get types => switch (this) {
    ArcadeAnswer.name => const [QuestionType.nameFromStaff],
    ArcadeAnswer.fret => const [QuestionType.fretFromStaff],
    ArcadeAnswer.fretName => const [QuestionType.nameFromFret],
    ArcadeAnswer.staff => const [QuestionType.staffFromFret],
    ArcadeAnswer.mixed => QuestionType.values,
  };

  /// Braucht diese Art das Griffbrett?
  bool get usesFretboard => this != ArcadeAnswer.name;

  String get label => switch (this) {
    ArcadeAnswer.name => tr('Notenname', 'Note name'),
    ArcadeAnswer.fret => tr('Wo liegt sie?', 'Where is it?'),
    ArcadeAnswer.fretName => tr('Welcher Ton?', 'Which note?'),
    ArcadeAnswer.staff => tr('Note setzen', 'Write the note'),
    ArcadeAnswer.mixed => tr('Gemischt', 'Mixed'),
  };

  String get help => switch (this) {
    ArcadeAnswer.name => tr('Note sehen, Namen tippen', 'See the note, tap its name'),
    ArcadeAnswer.fret => tr('Note sehen, Griffbrett tippen', 'See the note, tap the fretboard'),
    ArcadeAnswer.fretName => tr('Punkt sehen, Namen tippen', 'See the dot, tap its name'),
    ArcadeAnswer.staff => tr('Punkt sehen, Note setzen', 'See the dot, place the note'),
    ArcadeAnswer.mixed => tr('Alles durcheinander', 'Everything mixed'),
  };
}

/// Wie schnell es im Arcade-Modus gehen soll.
enum ArcadeSpeed {
  off(null),
  relaxed(Duration(seconds: 8)),
  fast(Duration(seconds: 4));

  const ArcadeSpeed(this.limit);
  final Duration? limit;

  String get label => switch (this) {
    ArcadeSpeed.off => tr('Ohne Zeit', 'No timer'),
    ArcadeSpeed.relaxed => tr('Gemütlich', 'Relaxed'),
    ArcadeSpeed.fast => tr('Schnell', 'Fast'),
  };
}

/// Alle Einstellungen einer Arcade-Runde. Auch als Vorlage speicherbar.
class ArcadeSettings {
  ArcadeSettings({
    this.answer = ArcadeAnswer.name,
    this.byCurriculum = true,
    this.upToStep,
    this.range = FretRange.full,
    this.accidentals = false,
    this.fixedString = false,
    this.speed = ArcadeSpeed.relaxed,
  });

  ArcadeAnswer answer;

  /// Töne nach Lehrplan (bis Schritt [upToStep]) oder nach Griffbrett-Bereich.
  bool byCurriculum;

  /// Null = aktueller Schritt des Profils.
  int? upToStep;
  FretRange range;

  /// Im Griffbrett-Bereich: auch Töne mit Vorzeichen.
  bool accidentals;

  /// Bei „Wo liegt sie?“: Saite vorgeben.
  bool fixedString;
  ArcadeSpeed speed;

  ArcadeSettings copy() => ArcadeSettings(
    answer: answer,
    byCurriculum: byCurriculum,
    upToStep: upToStep,
    range: range,
    accidentals: accidentals,
    fixedString: fixedString,
    speed: speed,
  );

  Map<String, dynamic> toJson() => {
    'answer': answer.name,
    'byCurriculum': byCurriculum,
    'upToStep': upToStep,
    'range': range.toJson(),
    'accidentals': accidentals,
    'fixedString': fixedString,
    'speed': speed.name,
  };

  static ArcadeSettings fromJson(Map<String, dynamic> j) => ArcadeSettings(
    answer: ArcadeAnswer.values.asNameMap()[j['answer']] ?? ArcadeAnswer.name,
    byCurriculum: j['byCurriculum'] as bool? ?? true,
    upToStep: (j['upToStep'] as num?)?.toInt(),
    range: FretRange.fromJson(j['range'] as Map<String, dynamic>?),
    accidentals: j['accidentals'] as bool? ?? false,
    fixedString: j['fixedString'] as bool? ?? false,
    speed: ArcadeSpeed.values.asNameMap()[j['speed']] ?? ArcadeSpeed.relaxed,
  );
}

/// Eine Vorlage: eingebaut (nur ein Griffbrett-Bereich) oder von der
/// Lehrperson gespeichert (alle Einstellungen, z. B. „Hausaufgabe Mia“).
class ArcadePreset {
  const ArcadePreset({required this.id, required this.name, required this.settings, this.builtIn = false});

  final String id;
  final String name;
  final ArcadeSettings settings;
  final bool builtIn;

  /// Vorlage auf [current] anwenden. Eingebaute Vorlagen ändern nur den
  /// Bereich, nicht Spielart und Tempo.
  ArcadeSettings applyTo(ArcadeSettings current) {
    if (!builtIn) return settings.copy();
    return current.copy()
      ..byCurriculum = false
      ..range = settings.range
      ..accidentals = settings.accidentals;
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'settings': settings.toJson()};

  static ArcadePreset fromJson(Map<String, dynamic> j) => ArcadePreset(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    settings: ArcadeSettings.fromJson(j['settings'] as Map<String, dynamic>? ?? const {}),
  );

  static List<ArcadePreset> get builtIns => [
    ArcadePreset(
      id: 'lage1',
      name: tr('1. Lage', '1st position'),
      builtIn: true,
      settings: ArcadeSettings(byCurriculum: false, range: const FretRange(minFret: 0, maxFret: 4)),
    ),
    ArcadePreset(
      id: 'g-saite',
      name: tr('Nur g-Saite', 'G string only'),
      builtIn: true,
      settings: ArcadeSettings(byCurriculum: false, range: const FretRange(strings: {3}, minFret: 0, maxFret: 4)),
    ),
    ArcadePreset(
      id: 'tiefe-saiten',
      name: tr('Tiefe Saiten', 'Low strings'),
      builtIn: true,
      settings: ArcadeSettings(byCurriculum: false, range: const FretRange(strings: {4, 5, 6}, minFret: 0, maxFret: 4)),
    ),
    ArcadePreset(
      id: 'lage5',
      name: tr('5. Lage', '5th position'),
      builtIn: true,
      settings: ArcadeSettings(byCurriculum: false, range: const FretRange(minFret: 5, maxFret: 8)),
    ),
    ArcadePreset(
      id: 'alles',
      name: tr('Bis 12. Bund', 'Up to 12th fret'),
      builtIn: true,
      settings: ArcadeSettings(byCurriculum: false, range: FretRange.full, accidentals: true),
    ),
  ];
}
