import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../app/l10n.dart';
import 'game/arcade_settings.dart';
import 'music/chords.dart';
import 'music/curriculum.dart';
import 'music/note_names.dart';
import 'music/pitch.dart';
import 'profiles/json_files.dart';
import 'profiles/profile.dart';

/// Einstellungen dieses Geräts (Lehrerbereich).
class SuonaSettings {
  SuonaSettings({
    this.language,
    this.naming = NoteNaming.german,
    this.accidentals = AccidentalStyle.mixed,
    this.sound = true,
    this.lowStringOnTop = false,
  });

  /// Null = wie das System.
  AppLanguage? language;
  NoteNaming naming;
  AccidentalStyle accidentals;
  bool sound;

  /// Griffbrett mit der tiefen E-Saite oben (Blick von oben auf die eigene
  /// Gitarre). Sonst wie in der Tabulatur: hohe e-Saite oben.
  bool lowStringOnTop;

  Map<String, dynamic> toJson() => {
    'language': language?.name,
    'naming': naming.name,
    'accidentals': accidentals.name,
    'sound': sound,
    'lowStringOnTop': lowStringOnTop,
  };

  static SuonaSettings fromJson(Map<String, dynamic> j) => SuonaSettings(
    language: AppLanguage.fromCode(j['language'] as String?),
    naming: NoteNaming.values.asNameMap()[j['naming']] ?? NoteNaming.german,
    accidentals: AccidentalStyle.values.asNameMap()[j['accidentals']] ?? AccidentalStyle.mixed,
    sound: j['sound'] as bool? ?? true,
    lowStringOnTop: j['lowStringOnTop'] as bool? ?? false,
  );
}

/// Zustand der ganzen App: Einstellungen, Profile, Lehrpläne.
///
/// Alles liegt nur auf diesem Gerät, im Datenordner der App:
/// `Spielstaende/<id>.json`, `Lehrplaene/<id>.json`, `einstellungen.json`.
class SuonaState extends ChangeNotifier {
  SuonaState(this.dataDir)
    : _profilesDir = JsonFolder(p.join(dataDir, 'Spielstaende')),
      _curriculaDir = JsonFolder(p.join(dataDir, 'Lehrplaene')),
      _chordCurriculaDir = JsonFolder(p.join(dataDir, 'Akkordplaene')),
      _settingsFile = JsonFile(p.join(dataDir, 'einstellungen.json')),
      _presetsFile = JsonFile(p.join(dataDir, 'arcade_vorlagen.json'));

  final String dataDir;
  final JsonFolder _profilesDir;
  final JsonFolder _curriculaDir;
  final JsonFolder _chordCurriculaDir;
  final JsonFile _settingsFile;
  final JsonFile _presetsFile;

  SuonaSettings settings = SuonaSettings();
  final List<Profile> profiles = [];
  final List<Curriculum> _custom = [];
  final List<ChordCurriculum> _customChords = [];
  final List<ArcadePreset> _presets = [];
  bool loaded = false;

  NoteNaming get naming => settings.naming;

  Future<void> load() async {
    settings = SuonaSettings.fromJson(await _settingsFile.read());
    L10n.language.value = settings.language ?? AppLanguage.system;
    profiles
      ..clear()
      ..addAll([
        for (final j in await _profilesDir.readAll())
          if (j['id'] is String) Profile.fromJson(j),
      ])
      ..sort((a, b) => a.created.compareTo(b.created));
    _custom
      ..clear()
      ..addAll([
        for (final j in await _curriculaDir.readAll())
          if (j['id'] is String) Curriculum.fromJson(j),
      ])
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _customChords
      ..clear()
      ..addAll([
        for (final j in await _chordCurriculaDir.readAll())
          if (j['id'] is String) ChordCurriculum.fromJson(j),
      ])
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final presets = await _presetsFile.read();
    _presets
      ..clear()
      ..addAll([
        for (final j in (presets['presets'] as List<dynamic>? ?? const []))
          if (j is Map<String, dynamic> && j['id'] is String) ArcadePreset.fromJson(j),
      ]);
    loaded = true;
    notifyListeners();
  }

  // ---------- Arcade-Vorlagen ----------

  /// Eingebaute und eigene Vorlagen (eigene zuletzt).
  List<ArcadePreset> get arcadePresets => [...ArcadePreset.builtIns, ..._presets];

  List<ArcadePreset> get customArcadePresets => List.unmodifiable(_presets);

  Future<void> saveArcadePreset(String name, ArcadeSettings settings) async {
    _presets.add(ArcadePreset(id: const Uuid().v4(), name: name.trim(), settings: settings.copy()));
    notifyListeners();
    await _writePresets();
  }

  Future<void> deleteArcadePreset(ArcadePreset preset) async {
    _presets.removeWhere((x) => x.id == preset.id);
    notifyListeners();
    await _writePresets();
  }

  Future<void> _writePresets() => _presetsFile.write({
    'format': 'suona-arcade-vorlagen',
    'version': 1,
    'presets': [for (final x in _presets) x.toJson()],
  });

  // ---------- Einstellungen ----------

  Future<void> updateSettings(void Function(SuonaSettings s) change) async {
    change(settings);
    L10n.set(settings.language ?? AppLanguage.system);
    notifyListeners();
    await _settingsFile.write(settings.toJson());
  }

  // ---------- Profile ----------

  Future<Profile> addProfile(String nickname, Character character, {String? curriculumId, String? guitar}) async {
    final profile = Profile(
      id: const Uuid().v4(),
      nickname: nickname.trim(),
      character: character,
      curriculumId: curriculumId ?? BuiltInCurricula.guitarTalksId,
    );
    // Startgitarre (beim neuen Profil gewählt: E-Gitarre oder Konzertgitarre).
    if (guitar != null) profile.look = CharacterLook.defaults(character).copyWith(guitar: guitar);
    profiles.add(profile);
    notifyListeners();
    await saveProfile(profile);
    return profile;
  }

  Future<void> saveProfile(Profile profile) async {
    notifyListeners();
    await _profilesDir.write(profile.id, profile.toJson());
  }

  Future<void> deleteProfile(Profile profile) async {
    profiles.removeWhere((x) => x.id == profile.id);
    notifyListeners();
    await _profilesDir.delete(profile.id);
  }

  // ---------- Lehrpläne ----------

  List<Curriculum> get curricula => [...BuiltInCurricula.all, ..._custom];

  Curriculum curriculumById(String id) =>
      curricula.firstWhere((c) => c.id == id, orElse: () => BuiltInCurricula.guitarTalks);

  Curriculum curriculumOf(Profile profile) => curriculumById(profile.curriculumId);

  String newCurriculumId() => const Uuid().v4();

  Future<void> saveCurriculum(Curriculum c) async {
    if (c.builtIn) return;
    _custom
      ..removeWhere((x) => x.id == c.id)
      ..add(c)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    await _curriculaDir.write(c.id, c.toJson());
  }

  Future<void> deleteCurriculum(Curriculum c) async {
    if (c.builtIn) return;
    _custom.removeWhere((x) => x.id == c.id);
    // Profile mit diesem Lehrplan bekommen wieder den eingebauten.
    for (final pr in profiles.where((x) => x.curriculumId == c.id).toList()) {
      pr
        ..curriculumId = BuiltInCurricula.guitarTalksId
        ..step = 0;
      await _profilesDir.write(pr.id, pr.toJson());
    }
    notifyListeners();
    await _curriculaDir.delete(c.id);
  }

  // ---------- Akkord-Lehrpläne ----------

  List<ChordCurriculum> get chordCurricula => [...BuiltInChordCurricula.all, ..._customChords];

  ChordCurriculum chordCurriculumById(String id) =>
      chordCurricula.firstWhere((c) => c.id == id, orElse: () => BuiltInChordCurricula.tour);

  ChordCurriculum chordCurriculumOf(Profile profile) => chordCurriculumById(profile.chordCurriculumId);

  Future<void> saveChordCurriculum(ChordCurriculum c) async {
    if (c.builtIn) return;
    _customChords
      ..removeWhere((x) => x.id == c.id)
      ..add(c)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    notifyListeners();
    await _chordCurriculaDir.write(c.id, c.toJson());
  }

  Future<void> deleteChordCurriculum(ChordCurriculum c) async {
    if (c.builtIn) return;
    _customChords.removeWhere((x) => x.id == c.id);
    // Profile mit diesem Akkord-Lehrplan bekommen wieder den eingebauten.
    for (final pr in profiles.where((x) => x.chordCurriculumId == c.id).toList()) {
      pr
        ..chordCurriculumId = BuiltInChordCurricula.tourId
        ..chordStep = 0;
      await _profilesDir.write(pr.id, pr.toJson());
    }
    notifyListeners();
    await _chordCurriculaDir.delete(c.id);
  }

  /// Akkorde zum Üben: alles bis zum aktuellen Akkord-Schritt.
  List<Chord> chordPool(Profile profile) {
    final c = chordCurriculumOf(profile);
    if (c.steps.isEmpty) return const [];
    return c.chordsUpTo(profile.chordStep.clamp(0, c.steps.length - 1));
  }

  /// Neu im aktuellen Akkord-Schritt.
  Set<Chord> chordFocus(Profile profile) {
    final c = chordCurriculumOf(profile);
    if (c.steps.isEmpty) return {};
    return c.steps[profile.chordStep.clamp(0, c.steps.length - 1)].chordList.toSet();
  }

  /// Saiten im Griffbild beim Üben.
  int chordStrings(Profile profile) {
    final c = chordCurriculumOf(profile);
    if (c.steps.isEmpty) return 6;
    return c.stringsAt(profile.chordStep.clamp(0, c.steps.length - 1));
  }

  // ---------- Notenvorrat ----------

  /// Töne für eine Übungsrunde: alles bis zum aktuellen Schritt.
  List<Pitch> practicePool(Profile profile) {
    final c = curriculumOf(profile);
    final step = profile.step.clamp(0, c.steps.length - 1);
    return applyAccidentalStyle(c.notesUpTo(step), settings.accidentals);
  }

  /// Neu im aktuellen Schritt: kommt öfter dran.
  Set<Pitch> practiceFocus(Profile profile) {
    final c = curriculumOf(profile);
    if (c.steps.isEmpty) return {};
    final step = profile.step.clamp(0, c.steps.length - 1);
    return applyAccidentalStyle(c.steps[step].notes, settings.accidentals).toSet();
  }
}

/// Schreibweise der Vorzeichen anwenden: „nur ♯“ macht aus Ges ein Fis,
/// „nur ♭“ aus Fis ein Ges. Doppelte fallen weg.
List<Pitch> applyAccidentalStyle(List<Pitch> notes, AccidentalStyle style) {
  final out = <Pitch>{};
  for (final n in notes) {
    final converted = switch (style) {
      AccidentalStyle.sharps when n.accidental == Accidental.flat => n.enharmonic ?? n,
      AccidentalStyle.flats when n.accidental == Accidental.sharp => n.enharmonic ?? n,
      _ => n,
    };
    out.add(converted);
  }
  return out.toList()..sort();
}

/// Macht den Zustand überall erreichbar: `SuonaScope.of(context)`.
class SuonaScope extends InheritedNotifier<SuonaState> {
  const SuonaScope({super.key, required SuonaState state, required super.child}) : super(notifier: state);

  static SuonaState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SuonaScope>()!.notifier!;

  /// Ohne Neuaufbau bei Änderungen (für Aktionen in Knöpfen).
  static SuonaState read(BuildContext context) => context.getInheritedWidgetOfExactType<SuonaScope>()!.notifier!;
}
