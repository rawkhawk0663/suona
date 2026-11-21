import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/game/rewards.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/visuals.dart';

/// Ergebnis eines Abenteuer-Levels.
class AdventureOutcome {
  const AdventureOutcome({required this.passed, required this.crowdGone, required this.firstClear});
  final bool passed;
  final bool crowdGone;
  final bool firstClear;
}

/// Ergebnis einer Runde: Sterne, Münzen, Streak. Gilt für Noten und Akkorde.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.profileId,
    required this.arcade,
    required this.again,
    this.concert = false,
    this.next,
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

  /// Arcade: Rekord statt Sterne.
  final bool arcade;

  /// „Nochmal“: dieselbe Runde neu.
  final WidgetBuilder again;

  /// Im Abenteuer war es ein Auftritt.
  final bool concert;

  /// „Weiter“ zum nächsten Level (null, wenn nichts offen ist).
  final Widget? Function(BuildContext context, SuonaState state, Profile profile)? next;
  final int correct;
  final int total;
  final int coins;
  final int bonus;
  final int stars;
  final bool newRecord;
  final StreakEvent? streakEvent;
  final AdventureOutcome? adventure;

  bool get _arcade => arcade;

  String get _headline {
    final adv = adventure;
    if (adv != null) {
      if (adv.crowdGone) return tr('Das Publikum ist gegangen', 'The crowd has left');
      if (!adv.passed) return tr('Fast! Nochmal?', 'Almost! Again?');
      if (concert) return tr('Was für ein Auftritt!', 'What a concert!');
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
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  if (profile != null)
                    Container(
                      width: 320,
                      height: 230,
                      decoration: BoxDecoration(gradient: characterGlow(strength: 1.2)),
                      child: CharacterView(profile.look),
                    ),
                  const SizedBox(height: 10),
                  Text(_headline, textAlign: TextAlign.center, style: display(44)),
                  const SizedBox(height: 8),
                  if (!_arcade)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < 3; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: i < stars
                                ? GradientTint(
                                    colors: SuonaColors.sun,
                                    child: Icon(Icons.star_rounded, size: i == 1 ? 78 : 62, color: Colors.white),
                                  )
                                : Icon(Icons.star_rounded, size: i == 1 ? 78 : 62, color: SuonaColors.muted.withValues(alpha: 0.3)),
                          ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    tr('$correct von $total richtig', '$correct of $total right'),
                    style: display(24, color: SuonaColors.muted, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  SuonaCard(
                    padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                    child: Column(
                      children: [
                        CoinCount(coins, size: 34),
                        if (bonus > 0)
                          Text(
                            adventure != null
                                ? tr('davon $bonus Bonus fürs erste Mal', 'incl. $bonus first-time bonus')
                                : tr('davon $bonus Sterne-Bonus', 'incl. $bonus star bonus'),
                            style: body(15, color: SuonaColors.muted),
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
                            style: display(20),
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
                      style: body(17, color: SuonaColors.muted),
                    ),
                  ],
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      if (adventure != null && adventure!.passed && profile != null && next != null)
                        ?next!(context, state, profile),
                      GradientButton(
                        label: tr('Nochmal', 'Again'),
                        icon: Icons.replay_rounded,
                        height: 60,
                        fontSize: 21,
                        onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: again)),
                      ),
                      GradientButton(
                        label: adventure != null ? tr('Zur Karte', 'To the map') : tr('Fertig', 'Done'),
                        icon: adventure != null ? Icons.map_rounded : Icons.home_rounded,
                        secondary: true,
                        height: 60,
                        fontSize: 21,
                        onPressed: () => Navigator.of(context).pop(),
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
