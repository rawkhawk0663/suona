import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/game/adventure.dart';
import '../../core/game/question.dart';
import '../../core/music/note_names.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/staff.dart';
import 'adventure_launch.dart';

/// Was eine Level-Kachel anzeigt.
class LevelInfo {
  const LevelInfo({required this.what, required this.count, this.time, this.concert = false});
  final String what;
  final String count;
  final String? time;
  final bool concert;
}

/// Ein Abenteuer mit Karte, acht Stationen und sechs Leveln pro Station.
/// Weltkarte ([AdventureMapScreen]) und Station ([StationScreen]) gelten
/// für das Noten-Abenteuer und die Akkord-Tour gleichermassen.
abstract class TourSpec {
  const TourSpec();

  int get stationCount => Adventure.stationCount;
  int get levelsPerStation => Adventure.levelsPerStation;
  int get concertLevel => Adventure.concertLevel;

  String get title;
  String subtitle(SuonaState s, Profile p);
  String stationName(int station);
  IconData stationIcon(int station);
  String levelName(int level);

  /// Text, wenn die Lehrperson eine Station noch nicht freigegeben hat.
  String get teacherLockText;

  List<List<int>> progress(SuonaState s, Profile p);
  StationLock? lockOf(SuonaState s, Profile p, int station);
  bool levelOpen(SuonaState s, Profile p, int station, int level);
  LevelInfo levelInfo(SuonaState s, Profile p, int station, int level);

  /// Linke Seite der Station: was hier neu ist.
  Widget stationInfo(BuildContext context, SuonaState s, Profile p, int station);

  Future<void> startLevel(BuildContext context, SuonaState s, Profile p, int station, int level, {bool replace = false});
}

/// Das Noten-Abenteuer: vom Kinderzimmer ins Stadion.
class NoteTour extends TourSpec {
  const NoteTour();

  @override
  String get title => tr('Abenteuer', 'Adventure');

  @override
  String subtitle(SuonaState s, Profile p) =>
      tr('Vom Kinderzimmer ins Stadion · ${s.curriculumOf(p).name}', 'From the bedroom to the stadium · ${s.curriculumOf(p).name}');

  @override
  String stationName(int station) => Adventure.stationName(station);

  @override
  IconData stationIcon(int station) => noteStationIcon(station);

  @override
  String levelName(int level) => Adventure.levelName(level);

  @override
  String get teacherLockText => tr(
    'Die neuen Töne dieser Station lernst du zuerst im Unterricht. Deine Lehrperson schaltet sie frei.',
    'You learn the new notes of this station in your lesson first. Your teacher unlocks them.',
  );

  @override
  List<List<int>> progress(SuonaState s, Profile p) => Adventure.progressOf(p, s.curriculumOf(p).id);

  @override
  StationLock? lockOf(SuonaState s, Profile p, int station) => Adventure.lockOf(p, s.curriculumOf(p), station);

  @override
  bool levelOpen(SuonaState s, Profile p, int station, int level) =>
      Adventure.levelOpen(p, s.curriculumOf(p), station, level);

  @override
  LevelInfo levelInfo(SuonaState s, Profile p, int station, int level) {
    final plan = Adventure.plan(s.curriculumOf(p), s.settings.accidentals, station, level, p.difficulty);
    final what = plan.types.length > 1
        ? tr('Alles gemischt', 'Everything mixed')
        : switch (plan.types.first) {
            QuestionType.nameFromStaff => tr('Noten lesen', 'Read notes'),
            QuestionType.fretFromStaff => tr('Wo liegt die Note?', 'Where is the note?'),
            QuestionType.nameFromFret => tr('Welcher Ton ist das?', 'Which note is this?'),
            QuestionType.staffFromFret => tr('Note setzen', 'Write the note'),
          };
    return LevelInfo(
      what: what,
      count: tr('${plan.length} Töne', '${plan.length} notes'),
      time: plan.timeLimit == null
          ? null
          : tr('${plan.timeLimit!.inSeconds} s pro Ton', '${plan.timeLimit!.inSeconds} s per note'),
      concert: plan.isConcert,
    );
  }

  @override
  Widget stationInfo(BuildContext context, SuonaState s, Profile p, int station) {
    final plan0 = Adventure.plan(s.curriculumOf(p), s.settings.accidentals, station, 0, p.difficulty);
    final fresh = plan0.focus.toList()..sort();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('Neue Töne hier', 'New notes here'),
          style: display(20, color: SuonaColors.onStage, weight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: SuonaColors.paper, borderRadius: BorderRadius.circular(16)),
          child: StaffView(notes: [for (final n in fresh.take(8)) StaffNote(n)]),
        ),
        const SizedBox(height: 4),
        Text(
          fresh.map((n) => pitchNameWithOctave(n, s.naming)).join(' · '),
          style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 15),
        ),
      ],
    );
  }

  @override
  Future<void> startLevel(BuildContext context, SuonaState s, Profile p, int station, int level, {bool replace = false}) =>
      startNoteLevel(context, s, p, station, level, replace: replace);
}
