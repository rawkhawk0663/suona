import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/stage.dart';
import '../arcade/arcade_setup_screen.dart';
import '../quiz/quiz_screen.dart';

/// Das Zuhause eines Profils: Figur auf der Bühne und die Spielarten.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) {
      // Profil wurde im Lehrerbereich gelöscht.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
      return const Scaffold(backgroundColor: SuonaColors.stage);
    }
    final now = DateTime.now();
    final curriculum = state.curriculumOf(profile);
    final step = profile.step.clamp(0, curriculum.steps.length - 1);
    final practicedToday = profile.streak.practicedOn(now);

    final tiles = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StageTile(
          title: tr('Üben', 'Practise'),
          subtitle: tr('Wie heisst die Note? · 10 Töne', 'Name that note · 10 notes'),
          icon: Icons.music_note_rounded,
          color: SuonaColors.red,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => QuizScreen(profileId: profile.id, config: QuizConfig.practice()),
            ),
          ),
        ),
        const SizedBox(height: 14),
        StageTile(
          title: 'Arcade',
          subtitle: profile.arcadeBest > 0
              ? tr('Endlos spielen · Rekord ${profile.arcadeBest}', 'Endless play · Best ${profile.arcadeBest}')
              : tr('Endlos spielen, bis 3 Fehler', 'Endless play until 3 mistakes'),
          icon: Icons.bolt_rounded,
          color: SuonaColors.violet,
          onTap: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => ArcadeSetupScreen(profileId: profile.id))),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: StageTile(
                title: tr('Abenteuer', 'Adventure'),
                subtitle: tr('Kommt bald', 'Coming soon'),
                icon: Icons.map_rounded,
                color: SuonaColors.teal,
                locked: true,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: StageTile(
                title: 'Shop',
                subtitle: tr('Kommt bald', 'Coming soon'),
                icon: Icons.storefront_rounded,
                color: SuonaColors.teal,
                locked: true,
              ),
            ),
          ],
        ),
      ],
    );

    final hero = Column(
      children: [
        _Bubble(
          text: practicedToday
              ? tr('Heute schon geübt. Stark!', 'Already practised today. Great!')
              : tr('Bereit für die Bühne?', 'Ready for the stage?'),
        ),
        const SizedBox(height: 8),
        Expanded(child: CharacterView(profile.character)),
      ],
    );

    return Scaffold(
      body: StageBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              children: [
                _TopBar(profile: profile),
                const SizedBox(height: 6),
                Text(
                  '${curriculum.name} · ${tr('Schritt', 'Step')} ${step + 1}/${curriculum.steps.length}: ${curriculum.steps[step].title}',
                  style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, c) {
                      if (c.maxWidth >= 760) {
                        return Row(
                          children: [
                            Expanded(
                              child: Padding(padding: const EdgeInsets.only(bottom: 24), child: hero),
                            ),
                            const SizedBox(width: 24),
                            SizedBox(width: 470, child: Center(child: tiles)),
                          ],
                        );
                      }
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(height: 300, child: hero),
                            const SizedBox(height: 16),
                            tiles,
                          ],
                        ),
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      children: [
        StageIconButton(
          icon: Icons.people_alt_rounded,
          tooltip: tr('Anderes Profil', 'Switch profile'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 12),
        FaceBadge(profile.character, size: 52),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            profile.nickname,
            style: display(28, color: SuonaColors.onStage),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Tooltip(
          message: tr('Tage in Folge geübt', 'Days in a row'),
          child: StreakCount(
            profile.streak.currentDays(now),
            size: 26,
            active: profile.streak.practicedOn(now),
            shields: profile.streak.shields,
          ),
        ),
        const SizedBox(width: 20),
        CoinCount(profile.coins, size: 26),
        const SizedBox(width: 6),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(color: SuonaColors.onStage, borderRadius: BorderRadius.circular(18)),
      child: Text(text, style: display(22, color: SuonaColors.ink)),
    );
  }
}
