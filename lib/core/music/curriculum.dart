import '../../app/l10n.dart';
import 'pitch.dart';

/// Ein Schritt im Lehrplan: welche Töne neu dazukommen.
class CurriculumStep {
  const CurriculumStep({required this.title, required this.notes});

  final String title;

  /// Neu in diesem Schritt (klingende Töne, mit Schreibweise).
  final List<Pitch> notes;

  Map<String, dynamic> toJson() => {
    'title': title,
    'notes': [for (final n in notes) n.key],
  };

  static CurriculumStep fromJson(Map<String, dynamic> j) => CurriculumStep(
    title: j['title'] as String? ?? '',
    notes: [for (final k in (j['notes'] as List<dynamic>? ?? const [])) ?Pitch.tryParse(k.toString())],
  );
}

/// Ein Lehrplan: die Reihenfolge, in der die Töne gelernt werden.
///
/// Eingebaute Lehrpläne (z. B. guitarTALKS) stehen im Code und lassen sich
/// nicht ändern, nur kopieren. Eigene liegen als Datei im Datenordner.
class Curriculum {
  const Curriculum({
    required this.id,
    required this.name,
    required this.steps,
    this.builtIn = false,
    this.description = '',
  });

  final String id;
  final String name;
  final String description;
  final List<CurriculumStep> steps;
  final bool builtIn;

  /// Alle Töne bis und mit Schritt [index] (0-basiert), ohne Doppelte.
  List<Pitch> notesUpTo(int index) {
    final out = <Pitch>{};
    for (var i = 0; i <= index && i < steps.length; i++) {
      out.addAll(steps[i].notes);
    }
    return out.toList()..sort();
  }

  /// Alle Töne des ganzen Lehrplans.
  List<Pitch> get allNotes => notesUpTo(steps.length - 1);

  Curriculum copyWith({String? id, String? name, List<CurriculumStep>? steps, bool? builtIn, String? description}) =>
      Curriculum(
        id: id ?? this.id,
        name: name ?? this.name,
        steps: steps ?? this.steps,
        builtIn: builtIn ?? this.builtIn,
        description: description ?? this.description,
      );

  Map<String, dynamic> toJson() => {
    'format': 'suona-lehrplan',
    'version': 1,
    'id': id,
    'name': name,
    'description': description,
    'steps': [for (final s in steps) s.toJson()],
  };

  static Curriculum fromJson(Map<String, dynamic> j) => Curriculum(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    description: j['description'] as String? ?? '',
    steps: [
      for (final s in (j['steps'] as List<dynamic>? ?? const [])) CurriculumStep.fromJson(s as Map<String, dynamic>),
    ],
  );
}

/// Eingebaute Lehrpläne.
class BuiltInCurricula {
  BuiltInCurricula._();

  static const guitarTalksId = 'guitartalks';

  static List<Curriculum> get all => [guitarTalks];

  /// guitarTALKS (Markus Engler): zuerst e-Saite, dann h, g, d, A, E,
  /// danach Vorzeichen in der offenen Lage und das Lagenspiel.
  /// Übernommen ist nur die Reihenfolge der Töne.
  static Curriculum get guitarTalks {
    List<Pitch> p(List<String> keys) => [for (final k in keys) Pitch.parse(k)];
    return Curriculum(
      id: guitarTalksId,
      name: 'guitarTALKS',
      builtIn: true,
      description: tr(
        'Reihenfolge der Töne wie in „guitarTALKS“ von Markus Engler.',
        'Order of notes as in “guitarTALKS” by Markus Engler.',
      ),
      steps: [
        CurriculumStep(title: tr('e-Saite', 'E string (1st)'), notes: p(['E4', 'F4', 'G4'])),
        CurriculumStep(title: tr('h-Saite', 'B string'), notes: p(['B3', 'C4', 'D4'])),
        CurriculumStep(title: tr('g-Saite', 'G string'), notes: p(['G3', 'A3'])),
        CurriculumStep(title: tr('d-Saite', 'D string'), notes: p(['D3', 'E3', 'F3'])),
        CurriculumStep(title: tr('A-Saite', 'A string'), notes: p(['A2', 'B2', 'C3'])),
        CurriculumStep(title: tr('E-Saite', 'Low E string'), notes: p(['E2', 'F2', 'G2'])),
        CurriculumStep(
          title: tr('Vorzeichen', 'Sharps and flats'),
          notes: Pitch.range(40, 68, naturals: false, sharps: true, flats: true),
        ),
        CurriculumStep(title: tr('2. Lage', '2nd position'), notes: p(['A4'])),
        CurriculumStep(
          title: tr('Bis zum 12. Bund', 'Up to the 12th fret'),
          notes: Pitch.range(70, 76, sharps: true, flats: true),
        ),
      ],
    );
  }
}
