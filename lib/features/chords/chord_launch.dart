import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/game/adventure.dart';
import '../../core/game/chord_adventure.dart';
import '../../core/game/shop.dart';
import '../../core/music/chords.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/chord_board.dart';
import '../../widgets/visuals.dart';
import '../adventure/tour.dart';
import 'chord_quiz_screen.dart';

/// Einstellungen für ein Level der Akkord-Tour.
ChordQuizConfig chordAdventureConfig(SuonaState state, Profile p, int station, int level) {
  final c = state.chordCurriculumOf(p);
  final plan = ChordTour.plan(c, station, level, p.difficulty);
  return ChordQuizConfig(
    mode: ChordQuizMode.practice,
    tasks: plan.tasks,
    pool: plan.pool,
    focus: plan.focus,
    strings: plan.strings,
    length: plan.length,
    timeLimit: plan.timeLimit,
    alternate: plan.alternate,
    song: plan.song,
    adventure: ChordAdventureRef(
      curriculumId: c.id,
      station: station,
      level: level,
      crowdLoss: plan.crowdLoss,
      crowdGain: plan.crowdGain,
    ),
    pedals: [for (final i in Shop.pedalsOf(p)) i.id],
  );
}

/// Üben ohne Abenteuer: alle Akkorde bis zum aktuellen Schritt, gemischt, ohne Zeit.
ChordQuizConfig chordPracticeConfig(SuonaState state, Profile p) => ChordQuizConfig(
  mode: ChordQuizMode.practice,
  tasks: ChordTask.values,
  pool: state.chordPool(p),
  focus: state.chordFocus(p),
  strings: state.chordStrings(p),
);

/// Akkord-Arcade: endlos, bis drei Plektren weg sind, mit Zeit pro Akkord.
ChordQuizConfig chordArcadeConfig(SuonaState state, Profile p) => ChordQuizConfig(
  mode: ChordQuizMode.arcade,
  tasks: const [ChordTask.name, ChordTask.build],
  pool: state.chordPool(p),
  focus: state.chordFocus(p),
  strings: state.chordStrings(p),
  timeLimit: Duration(seconds: (12 * p.difficulty.timeFactor).round()),
);

Future<void> startChordLevel(
  BuildContext context,
  SuonaState state,
  Profile p,
  int station,
  int level, {
  bool replace = false,
}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => ChordQuizScreen(profileId: p.id, config: chordAdventureConfig(state, p, station, level)),
  );
  return replace ? Navigator.of(context).pushReplacement(route) : Navigator.of(context).push(route);
}

/// „Weiter“ zum nächsten Level oder zur nächsten Etappe (null, wenn nichts offen ist).
Widget? chordNextLevelButton(BuildContext context, SuonaState state, Profile p, ChordAdventureRef ref) {
  final c = state.chordCurriculumOf(p);
  var station = ref.station, level = ref.level + 1;
  if (level >= ChordTour.levelsPerStation) {
    station++;
    level = 0;
  }
  if (station >= ChordTour.stationCount || !ChordTour.levelOpen(p, c, station, level)) return null;
  return GradientButton(
    onPressed: () => startChordLevel(context, state, p, station, level, replace: true),
    icon: Icons.arrow_forward_rounded,
    colors: SuonaColors.mint,
    height: 60,
    fontSize: 21,
    label: level == 0
        ? tr('Weiter: ${ChordTour.stationName(station)}', 'Next: ${ChordTour.stationName(station)}')
        : tr('Weiter', 'Next'),
  );
}

IconData chordStationIcon(int s) => switch (s) {
  0 => Icons.local_fire_department_rounded,
  1 => Icons.sports_soccer_rounded,
  2 => Icons.storefront_rounded,
  3 => Icons.forest_rounded,
  4 => Icons.beach_access_rounded,
  5 => Icons.theater_comedy_rounded,
  6 => Icons.festival_rounded,
  _ => Icons.emoji_events_rounded,
};

/// Die Akkord-Tour für Weltkarte und Etappe.
class ChordTourSpec extends TourSpec {
  const ChordTourSpec();

  @override
  String get title => tr('Akkord-Tour', 'Chord tour');

  @override
  String subtitle(SuonaState s, Profile p) => tr(
    'Mit dem Tourbus vom Lagerfeuer zum grossen Finale · ${s.chordCurriculumOf(p).name}',
    'By tour bus from the campfire to the grand finale · ${s.chordCurriculumOf(p).name}',
  );

  @override
  String stationName(int station) => ChordTour.stationName(station);

  @override
  IconData stationIcon(int station) => chordStationIcon(station);

  @override
  String levelName(int level) => ChordTour.levelName(level);

  @override
  String get teacherLockText => tr(
    'Die neuen Akkorde dieser Etappe lernst du zuerst im Unterricht. Deine Lehrperson schaltet sie frei.',
    'You learn the new chords of this stop in your lesson first. Your teacher unlocks them.',
  );

  @override
  List<List<int>> progress(SuonaState s, Profile p) => ChordTour.progressOf(p, s.chordCurriculumOf(p).id);

  @override
  StationLock? lockOf(SuonaState s, Profile p, int station) => ChordTour.lockOf(p, s.chordCurriculumOf(p), station);

  @override
  bool levelOpen(SuonaState s, Profile p, int station, int level) =>
      ChordTour.levelOpen(p, s.chordCurriculumOf(p), station, level);

  @override
  LevelInfo levelInfo(SuonaState s, Profile p, int station, int level) {
    final plan = ChordTour.plan(s.chordCurriculumOf(p), station, level, p.difficulty);
    final what = plan.song
        ? tr('Ein Lied im Takt begleiten', 'Play along with a song')
        : plan.alternate
        ? tr('Zwei Griffe abwechselnd', 'Two shapes in turn')
        : plan.tasks.length > 1
        ? tr('Alles gemischt', 'Everything mixed')
        : plan.tasks.first.label;
    return LevelInfo(
      what: what,
      count: plan.song
          ? tr('${plan.length} Takte', '${plan.length} bars')
          : tr('${plan.length} Akkorde', '${plan.length} chords'),
      time: plan.timeLimit == null
          ? null
          : tr('${plan.timeLimit!.inSeconds} s pro Akkord', '${plan.timeLimit!.inSeconds} s per chord'),
      concert: plan.isConcert,
    );
  }

  @override
  Widget stationInfo(BuildContext context, SuonaState s, Profile p, int station) {
    final plan = ChordTour.plan(s.chordCurriculumOf(p), station, 0, p.difficulty);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          plan.strings == 3
              ? tr('Neue Akkorde hier · 3 Saiten', 'New chords here · 3 strings')
              : tr('Neue Akkorde hier · ${plan.strings} Saiten', 'New chords here · ${plan.strings} strings'),
          style: display(19),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 170,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final c in plan.focus)
                Padding(padding: const EdgeInsets.only(right: 10), child: ChordPreview(chord: c, strings: plan.strings, width: 220)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Future<void> startLevel(BuildContext context, SuonaState s, Profile p, int station, int level, {bool replace = false}) =>
      startChordLevel(context, s, p, station, level, replace: replace);
}

/// Kleines Griffbild mit Namen (Etappe, Lehrerbereich, Akkord-Seite).
class ChordPreview extends StatelessWidget {
  const ChordPreview({super.key, required this.chord, required this.strings, this.width = 190});
  final Chord chord;
  final int strings;
  final double width;

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final dots = [for (final d in chord.dots(strings)) ChordDot(d, color: SuonaColors.accent, label: '${chord.fingerOn(d.string)}')];
    final marks = <int, OpenMark>{
      for (var st = 1; st <= strings; st++)
        if (!chord.dots(strings).any((d) => d.string == st))
          st: chord.muted(strings).contains(st) ? OpenMark.muted : OpenMark.open,
    };
    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(6, 8, 8, 4),
      decoration: BoxDecoration(
        color: SuonaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SuonaColors.line),
      ),
      child: Column(
        children: [
          Text(chordName(chord, state.naming), style: display(21)),
          Expanded(
            child: ChordBoard(
              strings: strings,
              dots: dots,
              openMarks: marks,
              naming: state.naming,
              lowStringOnTop: state.settings.lowStringOnTop,
              frets: 4,
            ),
          ),
        ],
      ),
    );
  }
}
