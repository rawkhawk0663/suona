import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/game/adventure.dart';
import '../../core/game/question.dart';
import '../../core/music/note_names.dart';
import '../../core/suona_state.dart';
import '../../widgets/stage.dart';
import '../../widgets/staff.dart';
import 'adventure_launch.dart';

/// Eine Station: ihre neuen Töne und die sechs Level bis zum Auftritt.
class StationScreen extends StatelessWidget {
  const StationScreen({super.key, required this.profileId, required this.station});
  final String profileId;
  final int station;

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final p = state.profiles.where((x) => x.id == profileId).firstOrNull;
    if (p == null) return const Scaffold(backgroundColor: SuonaColors.stage);
    final c = state.curriculumOf(p);
    final plan0 = Adventure.plan(c, state.settings.accidentals, station, 0, p.difficulty);
    final fresh = plan0.focus.toList()..sort();
    final levels = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var l = 0; l < Adventure.levelsPerStation; l++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LevelTile(
              level: l,
              stars: Adventure.stars(p, c.id, station, l),
              open: Adventure.levelOpen(p, c, station, l),
              plan: Adventure.plan(c, state.settings.accidentals, station, l, p.difficulty),
              onTap: () => startLevel(context, state, p, station, l),
            ),
          ),
      ],
    );
    final info = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: CharacterView(p.look)),
        const SizedBox(height: 10),
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
          fresh.map((n) => pitchNameWithOctave(n, state.naming)).join(' · '),
          style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 15),
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
                      icon: Icons.map_rounded,
                      tooltip: tr('Zur Karte', 'To the map'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 14),
                    Icon(stationIcon(station), color: SuonaColors.spot, size: 36),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(Adventure.stationName(station), style: display(38, color: SuonaColors.spot)),
                    ),
                    CoinCount(p.coins, size: 26),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      if (box.maxWidth >= 820) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: box.maxWidth * 0.36, child: info),
                            const SizedBox(width: 22),
                            Expanded(child: SingleChildScrollView(child: levels)),
                          ],
                        );
                      }
                      return SingleChildScrollView(
                        child: Column(
                          children: [
                            SizedBox(height: 420, child: info),
                            const SizedBox(height: 14),
                            levels,
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

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.stars,
    required this.open,
    required this.plan,
    required this.onTap,
  });
  final int level;
  final int stars;
  final bool open;
  final LevelPlan plan;
  final VoidCallback onTap;

  String get _what {
    if (plan.types.length > 1) return tr('Alles gemischt', 'Everything mixed');
    return switch (plan.types.first) {
      QuestionType.nameFromStaff => tr('Noten lesen', 'Read notes'),
      QuestionType.fretFromStaff => tr('Wo liegt die Note?', 'Where is the note?'),
      QuestionType.nameFromFret => tr('Welcher Ton ist das?', 'Which note is this?'),
      QuestionType.staffFromFret => tr('Note setzen', 'Write the note'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final concert = plan.isConcert;
    final bg = !open ? SuonaColors.stageFloor : (concert ? SuonaColors.red : SuonaColors.violet);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: open ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              Icon(
                !open ? Icons.lock_rounded : (concert ? Icons.mic_rounded : Icons.play_circle_fill_rounded),
                size: 38,
                color: open ? Colors.white : SuonaColors.onStageMuted,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Adventure.levelName(level),
                      style: display(24, color: open ? Colors.white : SuonaColors.onStageMuted),
                    ),
                    Text(
                      [
                        _what,
                        tr('${plan.length} Töne', '${plan.length} notes'),
                        if (plan.timeLimit != null)
                          tr('${plan.timeLimit!.inSeconds} s pro Ton', '${plan.timeLimit!.inSeconds} s per note'),
                      ].join(' · '),
                      style: TextStyle(color: open ? Colors.white70 : SuonaColors.onStageMuted, fontSize: 14.5),
                    ),
                  ],
                ),
              ),
              for (var i = 0; i < 3; i++)
                Icon(Icons.star_rounded, size: 30, color: i < stars ? SuonaColors.spot : Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}
