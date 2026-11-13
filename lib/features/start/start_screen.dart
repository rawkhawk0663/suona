import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/stage.dart';
import '../home/home_screen.dart';
import '../teacher/teacher_gate.dart';
import 'new_profile_screen.dart';

/// Startbildschirm: „Wer spielt?“ – Profile antippen oder ein neues anlegen.
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    return Scaffold(
      body: StageBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 12,
                right: 12,
                child: StageIconButton(
                  icon: Icons.lock_rounded,
                  tooltip: tr('Lehrerbereich', 'Teacher area'),
                  onPressed: () => openTeacherArea(context),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 70, 24, 90),
                  child: Column(
                    children: [
                      Text('Suona', style: display(72, color: SuonaColors.spot)),
                      const SizedBox(height: 4),
                      Text(
                        tr('Wer spielt?', 'Who’s playing?'),
                        style: display(30, color: SuonaColors.onStage, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final p in state.profiles)
                            _ProfileCard(
                              profile: p,
                              onTap: () =>
                                  Navigator.of(context)
                                      .push(MaterialPageRoute<void>(builder: (_) => HomeScreen(profileId: p.id))),
                            ),
                          _NewProfileCard(
                            onTap: () async {
                              final created = await Navigator.of(context)
                                  .push(MaterialPageRoute<Profile>(builder: (_) => const NewProfileScreen()));
                              if (created != null && context.mounted) {
                                await Navigator.of(context)
                                    .push(MaterialPageRoute<void>(builder: (_) => HomeScreen(profileId: created.id)));
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onTap});
  final Profile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: Material(
        color: SuonaColors.stageFloor,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 18, 12, 14),
            child: Column(
              children: [
                FaceBadge(profile.character, size: 104),
                const SizedBox(height: 10),
                Text(
                  profile.nickname,
                  style: display(24, color: SuonaColors.onStage),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                CoinCount(profile.coins, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewProfileCard extends StatelessWidget {
  const _NewProfileCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 196,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: SuonaColors.onStageMuted.withValues(alpha: 0.6), width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_rounded, size: 64, color: SuonaColors.spot),
              const SizedBox(height: 8),
              Text(
                tr('Neues Profil', 'New profile'),
                style: display(21, color: SuonaColors.onStage, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
