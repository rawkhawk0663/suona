import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/game/adventure.dart';
import '../../core/game/rewards.dart';
import '../../core/suona_state.dart';
import '../../widgets/stage.dart';
import '../adventure/adventure_launch.dart';
import 'quiz_screen.dart';

/// Ergebnis eines Abenteuer-Levels.
class AdventureOutcome {
  const AdventureOutcome({required this.passed, required this.crowdGone, required this.firstClear});
  final bool passed;
  final bool crowdGone;
  final bool firstClear;
}

/// Ergebnis einer Runde: Sterne, Münzen, Streak.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.profileId,
    required this.config,
    required this.correct,
    required this.total,
    required this.coins,
    required this.bonus,
    required this.stars,
    required this.newRecord,
    required this.streakEvent,
    this.adventure,
  });

  final String profileId;
  final QuizConfig config;
  final int correct;
  final int total;
  final int coins;
  final int bonus;
  final int stars;
  final bool newRecord;
  final StreakEvent? streakEvent;
  final AdventureOutcome? adventure;

  bool get _arcade => config.mode == QuizMode.arcade;

  String get _headline {
    final adv = adventure;
    if (adv != null) {
      if (adv.crowdGone) return tr('Das Publikum ist gegangen', 'The crowd has left');
      if (!adv.passed) return tr('Fast! Nochmal?', 'Almost! Again?');
      final ref = config.adventure!;
      if (ref.level == Adventure.concertLevel) return tr('Was für ein Auftritt!', 'What a concert!');
      return tr('Level geschafft!', 'Level cleared!');
    }
    if (_arcade) {
      if (newRecord) return tr('Neuer Rekord!', 'New record!');
      return correct == 0 ? tr('Weiter üben!', 'Keep practising!') : tr('Gut gespielt!', 'Well played!');
    }
    return switch (stars) {
      3 => tr('Super gemacht!', 'Brilliant!'),
      2 => tr('Sehr gut!', 'Very good!'),
      1 => tr('Gut so!', 'Nice!'),
      _ => tr('Weiter üben!', 'Keep practising!'),
    };
  }

  String? get _streakText => switch (streakEvent) {
    StreakEvent.started => tr('Dein erster Übungstag in Folge!', 'Your first day in a row!'),
    StreakEvent.continued => tr('Wieder ein Tag mehr in Folge!', 'One more day in a row!'),
    StreakEvent.savedByShield => tr(
      'Der Streak-Schutz hat deine Serie gerettet!',
      'Your streak shield saved your streak!',
    ),
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    return Scaffold(
      body: StageBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (profile != null) SizedBox(height: 210, child: CharacterView(profile.look)),
                  const SizedBox(height: 10),
                  Text(_headline, style: display(48, color: SuonaColors.spot)),
                  const SizedBox(height: 8),
                  if (!_arcade)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.star_rounded,
                              size: i == 1 ? 74 : 60,
                              color: i < stars ? SuonaColors.spot : SuonaColors.stageFloor,
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    tr('$correct von $total richtig', '$correct of $total right'),
                    style: display(28, color: SuonaColors.onStage, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    decoration: BoxDecoration(color: SuonaColors.stageFloor, borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      children: [
                        CoinCount(coins, size: 34),
                        if (bonus > 0)
                          Text(
                            adventure != null
                                ? tr('davon $bonus Bonus fürs erste Mal', 'incl. $bonus first-time bonus')
                                : tr('davon $bonus Sterne-Bonus', 'incl. $bonus star bonus'),
                            style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 15),
                          ),
                      ],
                    ),
                  ),
                  if (_streakText != null && profile != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        StreakCount(profile.streak.days, size: 28),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _streakText!,
                            style: display(21, color: SuonaColors.onStage, weight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (adventure != null && !adventure!.passed) ...[
                    const SizedBox(height: 10),
                    Text(
                      adventure!.crowdGone
                          ? tr(
                              'Zu viele Fehler hintereinander. Mit einem Schild-Pedal aus dem Shop geht es leichter.',
                              'Too many mistakes in a row. A shield pedal from the shop makes it easier.',
                            )
                          : tr(
                              'Für einen Stern brauchst du 6 von 10 richtig.',
                              'You need 6 out of 10 right for a star.',
                            ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 17),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      if (adventure != null && adventure!.passed && profile != null)
                        ?nextLevelButton(context, state, profile, config.adventure!),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => QuizScreen(profileId: profileId, config: config),
                          ),
                        ),
                        icon: const Icon(Icons.replay_rounded, size: 28),
                        label: Text(tr('Nochmal', 'Again')),
                        style: FilledButton.styleFrom(
                          backgroundColor: SuonaColors.spot,
                          foregroundColor: SuonaColors.ink,
                          textStyle: display(24),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(adventure != null ? Icons.map_rounded : Icons.home_rounded, size: 28),
                        label: Text(adventure != null ? tr('Zur Karte', 'To the map') : tr('Fertig', 'Done')),
                        style: FilledButton.styleFrom(
                          backgroundColor: SuonaColors.stageLine,
                          foregroundColor: SuonaColors.onStage,
                          textStyle: display(24),
                          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
