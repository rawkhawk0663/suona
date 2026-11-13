import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../app/l10n.dart';
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
  });

  /// Null = wie das System.
  AppLanguage? language;
  NoteNaming naming;
  AccidentalStyle accidentals;
  bool sound;

  Map<String, dynamic> toJson() => {
    'language': language?.name,
    'naming': naming.name,
    'accidentals': accidentals.name,
    'sound': sound,
  };

  static SuonaSettings fromJson(Map<String, dynamic> j) => SuonaSettings(
    language: AppLanguage.fromCode(j['language'] as String?),
    naming: NoteNaming.values.asNameMap()[j['naming']] ?? NoteNaming.german,
    accidentals: AccidentalStyle.values.asNameMap()[j['accidentals']] ?? AccidentalStyle.mixed,
    sound: j['sound'] as bool? ?? true,
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
      _settingsFile = JsonFile(p.join(dataDir, 'einstellungen.json'));

  final String dataDir;
  final JsonFolder _profilesDir;
  final JsonFolder _curriculaDir;
  final JsonFile _settingsFile;

  SuonaSettings settings = SuonaSettings();
  final List<Profile> profiles = [];
  final List<Curriculum> _custom = [];
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
    loaded = true;
    notifyListeners();
  }

  // ---------- Einstellungen ----------

  Future<void> updateSettings(void Function(SuonaSettings s) change) async {
    change(settings);
    L10n.set(settings.language ?? AppLanguage.system);
    notifyListeners();
    await _settingsFile.write(settings.toJson());
  }

  // ---------- Profile ----------

  Future<Profile> addProfile(String nickname, Character character, {String? curriculumId}) async {
    final profile = Profile(
      id: const Uuid().v4(),
      nickname: nickname.trim(),
      character: character,
      curriculumId: curriculumId ?? BuiltInCurricula.guitarTalksId,
    );
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
