import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/suona_state.dart';
import '../../widgets/stage.dart';
import '../quiz/quiz_screen.dart';

/// Wie schnell es im Arcade-Modus gehen soll.
enum ArcadeSpeed {
  off(null),
  relaxed(Duration(seconds: 8)),
  fast(Duration(seconds: 4));

  const ArcadeSpeed(this.limit);
  final Duration? limit;

  String get label => switch (this) {
    ArcadeSpeed.off => tr('Ohne Zeit', 'No timer'),
    ArcadeSpeed.relaxed => tr('Gemütlich', 'Relaxed'),
    ArcadeSpeed.fast => tr('Schnell', 'Fast'),
  };

  IconData get icon => switch (this) {
    ArcadeSpeed.off => Icons.self_improvement_rounded,
    ArcadeSpeed.relaxed => Icons.directions_walk_rounded,
    ArcadeSpeed.fast => Icons.rocket_launch_rounded,
  };
}

/// Arcade vorbereiten: welche Töne (bis zu welchem Schritt im Lehrplan)
/// und wie schnell. Die Auswahl nach Saiten und Bünden kommt mit dem
/// Griffbrett (Paket 2).
class ArcadeSetupScreen extends StatefulWidget {
  const ArcadeSetupScreen({super.key, required this.profileId});
  final String profileId;

  @override
  State<ArcadeSetupScreen> createState() => _ArcadeSetupScreenState();
}

class _ArcadeSetupScreenState extends State<ArcadeSetupScreen> {
  int? _upTo;
  ArcadeSpeed _speed = ArcadeSpeed.relaxed;

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final profile = state.profiles.firstWhere((p) => p.id == widget.profileId);
    final curriculum = state.curriculumOf(profile);
    final maxStep = curriculum.steps.length - 1;
    final upTo = (_upTo ?? profile.step).clamp(0, maxStep);
    final notes = applyAccidentalStyle(curriculum.notesUpTo(upTo), state.settings.accidentals);

    return Scaffold(
      body: StageBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 12,
                left: 12,
                child: StageIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: tr('Zurück', 'Back'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 70, 24, 90),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Arcade',
                          textAlign: TextAlign.center,
                          style: display(54, color: SuonaColors.spot),
                        ),
                        if (profile.arcadeBest > 0)
                          Text(
                            tr('Dein Rekord: ${profile.arcadeBest} Münzen', 'Your best: ${profile.arcadeBest} coins'),
                            textAlign: TextAlign.center,
                            style: display(22, color: SuonaColors.onStage, weight: FontWeight.w700),
                          ),
                        const SizedBox(height: 26),
                        _label(tr('Welche Töne?', 'Which notes?')),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          decoration: BoxDecoration(
                            color: SuonaColors.stageFloor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${tr('Bis', 'Up to')} ${tr('Schritt', 'step')} ${upTo + 1}: ${curriculum.steps[upTo].title}',
                                style: display(22, color: SuonaColors.onStage, weight: FontWeight.w700),
                              ),
                              Text(
                                tr(
                                  '${notes.length} Töne aus „${curriculum.name}“',
                                  '${notes.length} notes from “${curriculum.name}”',
                                ),
                                style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 15),
                              ),
                              if (maxStep > 0)
                                Slider(
                                  value: upTo.toDouble(),
                                  min: 0,
                                  max: maxStep.toDouble(),
                                  divisions: maxStep,
                                  activeColor: SuonaColors.spot,
                                  inactiveColor: SuonaColors.stageLine,
                                  label: curriculum.steps[upTo].title,
                                  onChanged: (v) => setState(() => _upTo = v.round()),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        _label(tr('Wie schnell?', 'How fast?')),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (final s in ArcadeSpeed.values)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  child: _SpeedChoice(
                                    speed: s,
                                    selected: _speed == s,
                                    onTap: () => setState(() => _speed = s),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Center(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pushReplacement(
                              MaterialPageRoute<void>(
                                builder: (_) => QuizScreen(
                                  profileId: profile.id,
                                  config: QuizConfig(
                                    mode: QuizMode.arcade,
                                    timeLimit: _speed.limit,
                                    pool: notes,
                                    focus: applyAccidentalStyle(
                                      curriculum.steps[upTo].notes,
                                      state.settings.accidentals,
                                    ).toSet(),
                                  ),
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 34),
                            label: Text(tr('Los!', 'Go!')),
                            style: FilledButton.styleFrom(
                              backgroundColor: SuonaColors.spot,
                              foregroundColor: SuonaColors.ink,
                              textStyle: display(30),
                              padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: display(24, color: SuonaColors.onStage, weight: FontWeight.w700),
  );
}

class _SpeedChoice extends StatelessWidget {
  const _SpeedChoice({required this.speed, required this.selected, required this.onTap});
  final ArcadeSpeed speed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SuonaColors.violet : SuonaColors.stageFloor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected ? SuonaColors.spot : Colors.transparent, width: 3),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          child: Column(
            children: [
              Icon(speed.icon, size: 34, color: SuonaColors.onStage),
              const SizedBox(height: 4),
              Text(
                speed.label,
                style: display(19, color: SuonaColors.onStage, weight: FontWeight.w700),
              ),
              if (speed.limit != null)
                Text(
                  tr('${speed.limit!.inSeconds} s pro Ton', '${speed.limit!.inSeconds} s per note'),
                  style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 13),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
