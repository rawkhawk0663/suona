import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/suona_state.dart';
import '../../widgets/stage.dart';
import '../adventure/adventure_map_screen.dart';
import 'chord_launch.dart';
import 'chord_quiz_screen.dart';

/// Akkorde: üben, die Akkord-Tour und das Akkord-Arcade. Oben stehen die
/// Akkorde, die das Kind schon kennt (nach dem Akkord-Lehrplan).
class ChordsScreen extends StatelessWidget {
  const ChordsScreen({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final p = state.profiles.where((x) => x.id == profileId).firstOrNull;
    if (p == null) return const Scaffold(backgroundColor: SuonaColors.stage);
    final pool = state.chordPool(p);
    final strings = state.chordStrings(p);
    final best = p.arcadeBests[ChordQuizConfig.recordKey] ?? 0;
    void open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    final tiles = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StageTile(
          title: tr('Üben', 'Practise'),
          subtitle: tr('Erkennen, Griffe bauen, aus den Noten', 'Recognise, build shapes, read the notes'),
          icon: Icons.school_rounded,
          color: SuonaColors.red,
          onTap: pool.isEmpty ? null : () => open(ChordQuizScreen(profileId: p.id, config: chordPracticeConfig(state, p))),
        ),
        const SizedBox(height: 14),
        StageTile(
          title: tr('Akkord-Tour', 'Chord tour'),
          subtitle: tr('Vom Lagerfeuer zum grossen Finale', 'From the campfire to the grand finale'),
          icon: Icons.airport_shuttle_rounded,
          color: SuonaColors.coral,
          onTap: () => open(AdventureMapScreen(profileId: p.id, tour: const ChordTourSpec())),
        ),
        const SizedBox(height: 14),
        StageTile(
          title: tr('Akkord-Arcade', 'Chord arcade'),
          subtitle: best > 0
              ? tr('Endlos spielen · Rekord $best', 'Endless play · Best $best')
              : tr('Endlos spielen, bis 3 Fehler', 'Endless play until 3 mistakes'),
          icon: Icons.bolt_rounded,
          color: SuonaColors.violet,
          onTap: pool.isEmpty ? null : () => open(ChordQuizScreen(profileId: p.id, config: chordArcadeConfig(state, p))),
        ),
      ],
    );
    final known = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Deine Akkorde', 'Your chords'),
          style: display(24, color: SuonaColors.onStage, weight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: pool.isEmpty
              ? Text(
                  tr('Deine Lehrperson wählt deine Akkorde aus.', 'Your teacher picks your chords.'),
                  style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 17),
                )
              : SingleChildScrollView(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in pool) SizedBox(height: 210, child: ChordPreview(chord: c, strings: strings, width: 270)),
                    ],
                  ),
                ),
        ),
      ],
    );
    return Scaffold(
      body: StageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                Row(
                  children: [
                    StageIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: tr('Zurück', 'Back'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Text(tr('Akkorde', 'Chords'), style: display(40, color: SuonaColors.spot)),
                    const Spacer(),
                    CoinCount(p.coins, size: 26),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      if (c.maxWidth >= 820) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: known),
                            const SizedBox(width: 28),
                            SizedBox(width: 420, child: tiles),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          tiles,
                          const SizedBox(height: 18),
                          Expanded(child: known),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
