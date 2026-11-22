import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/visuals.dart';
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
      body: AppBackground(
        child: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final small = context.compact;
                  final cards = <Widget>[
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
                  ];
                  final title = Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SuonaLogo(size: small ? 64 : 96, glow: true),
                      SizedBox(height: small ? 10 : 18),
                      Text('Suona', style: display(small ? 36 : 60)),
                      const SizedBox(height: 4),
                      Text(tr('Wer spielt?', 'Who’s playing?'), style: body(small ? 17 : 22, color: SuonaColors.muted)),
                    ],
                  );
                  if (small && box.maxWidth > box.maxHeight) {
                    // Handy quer: Titel links, Profile rechts zum Wischen.
                    return Row(
                      children: [
                        SizedBox(width: box.maxWidth * 0.3, child: title),
                        Expanded(
                          child: Center(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.fromLTRB(8, 16, 72, 16),
                              child: Row(
                                children: [
                                  for (final c in cards) Padding(padding: const EdgeInsets.only(right: 14), child: c),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 70, 24, 90),
                      child: Column(
                        children: [
                          title,
                          const SizedBox(height: 32),
                          Wrap(spacing: 18, runSpacing: 18, alignment: WrapAlignment.center, children: cards),
                        ],
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 12,
                right: 12,
                child: RoundIconButton(
                  icon: Icons.lock_rounded,
                  tooltip: tr('Lehrerbereich', 'Teacher area'),
                  onPressed: () => openTeacherArea(context),
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
    final small = context.compact;
    return SizedBox(
      width: small ? 150 : 176,
      child: SuonaCard(
        onTap: onTap,
        radius: 24,
        gradient: characterGlow(strength: 0.8),
        padding: EdgeInsets.fromLTRB(12, small ? 14 : 20, 12, small ? 12 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaceBadge(profile.look, size: small ? 84 : 104),
            SizedBox(height: small ? 8 : 12),
            Text(profile.nickname, style: display(22), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            CoinCount(profile.coins, size: 18),
          ],
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
    final small = context.compact;
    return SizedBox(
      width: small ? 150 : 176,
      height: small ? 176 : 212,
      child: SuonaCard(
        onTap: onTap,
        radius: 24,
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GradientIcon(Icons.add_rounded, colors: SuonaColors.brand, size: 64, circle: true),
            const SizedBox(height: 14),
            Text(tr('Neues Profil', 'New profile'), textAlign: TextAlign.center, style: display(19)),
          ],
        ),
      ),
    );
  }
}
