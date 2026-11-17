import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/suona_state.dart';
import '../../widgets/stage.dart';
import 'tour.dart';

/// Eine Station: was hier neu ist und die sechs Level bis zum Auftritt.
class StationScreen extends StatelessWidget {
  const StationScreen({super.key, required this.profileId, required this.station, this.tour = const NoteTour()});
  final String profileId;
  final int station;
  final TourSpec tour;

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final p = state.profiles.where((x) => x.id == profileId).firstOrNull;
    if (p == null) return const Scaffold(backgroundColor: SuonaColors.stage);
    final progress = tour.progress(state, p);
    final levels = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var l = 0; l < tour.levelsPerStation; l++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LevelTile(
              name: tour.levelName(l),
              stars: progress[station][l],
              open: tour.levelOpen(state, p, station, l),
              info: tour.levelInfo(state, p, station, l),
              onTap: () => tour.startLevel(context, state, p, station, l),
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
        tour.stationInfo(context, state, p, station),
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
                    Icon(tour.stationIcon(station), color: SuonaColors.spot, size: 36),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tour.stationName(station), style: display(38, color: SuonaColors.spot)),
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
                            SizedBox(height: 460, child: info),
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
    required this.name,
    required this.stars,
    required this.open,
    required this.info,
    required this.onTap,
  });
  final String name;
  final int stars;
  final bool open;
  final LevelInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final concert = info.concert;
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
                    Text(name, style: display(24, color: open ? Colors.white : SuonaColors.onStageMuted)),
                    Text(
                      [info.what, info.count, ?info.time].join(' · '),
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
