import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/game/adventure.dart';
import '../../core/game/shop.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../quiz/quiz_screen.dart';

/// Einstellungen für ein Level im Abenteuer.
QuizConfig adventureConfig(SuonaState state, Profile p, int station, int level) {
  final c = state.curriculumOf(p);
  final plan = Adventure.plan(c, state.settings.accidentals, station, level, p.difficulty);
  return QuizConfig(
    mode: QuizMode.practice,
    types: plan.types,
    length: plan.length,
    timeLimit: plan.timeLimit,
    pool: plan.pool,
    focus: plan.focus,
    adventure: AdventureRef(curriculumId: c.id, station: station, level: level, crowdLoss: plan.crowdLoss,
      crowdGain: plan.crowdGain,
    ),
    pedals: [for (final i in Shop.pedalsOf(p)) i.id],
  );
}

/// Level starten. [replace]: den aktuellen Bildschirm ersetzen (vom Ergebnis aus).
Future<void> startNoteLevel(
  BuildContext context,
  SuonaState state,
  Profile p,
  int station,
  int level, {
  bool replace = false,
}) {
  final route = MaterialPageRoute<void>(
    builder: (_) => QuizScreen(profileId: p.id, config: adventureConfig(state, p, station, level)),
  );
  return replace ? Navigator.of(context).pushReplacement(route) : Navigator.of(context).push(route);
}

/// „Weiter“ zum nächsten Level oder zur nächsten Station (null, wenn nichts offen ist).
Widget? nextLevelButton(BuildContext context, SuonaState state, Profile p, AdventureRef ref) {
  final c = state.curriculumOf(p);
  var station = ref.station, level = ref.level + 1;
  if (level >= Adventure.levelsPerStation) {
    station++;
    level = 0;
  }
  if (station >= Adventure.stationCount || !Adventure.levelOpen(p, c, station, level)) return null;
  return FilledButton.icon(
    onPressed: () => startNoteLevel(context, state, p, station, level, replace: true),
    icon: const Icon(Icons.arrow_forward_rounded, size: 28),
    label: Text(
      level == 0
          ? tr('Weiter: ${Adventure.stationName(station)}', 'Next: ${Adventure.stationName(station)}')
          : tr('Weiter', 'Next'),
    ),
    style: FilledButton.styleFrom(
      backgroundColor: SuonaColors.ok,
      foregroundColor: Colors.white,
      textStyle: display(24),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
    ),
  );
}

/// Symbol einer Station.
IconData noteStationIcon(int s) => switch (s) {
  0 => Icons.bed_rounded,
  1 => Icons.garage_rounded,
  2 => Icons.school_rounded,
  3 => Icons.nightlife_rounded,
  4 => Icons.festival_rounded,
  5 => Icons.mic_external_on_rounded,
  6 => Icons.celebration_rounded,
  _ => Icons.stadium_rounded,
};
