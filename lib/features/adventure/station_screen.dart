import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/suona_state.dart';
import '../../widgets/visuals.dart';
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
    if (p == null) return const Scaffold();
    final progress = tour.progress(state, p);
    final small = context.compact;
    final levels = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var l = 0; l < tour.levelsPerStation; l++)
          Padding(
            padding: EdgeInsets.only(bottom: small ? 8 : 10),
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
    final info = SuonaCard(
      radius: 24,
      gradient: characterGlow(),
      padding: EdgeInsets.all(small ? 12 : 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: CharacterView(p.look)),
          SizedBox(height: small ? 6 : 12),
          tour.stationInfo(context, state, p, station),
        ],
      ),
    );
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: context.screenPadding,
            child: Column(
              children: [
                ScreenHeader(
                  title: tour.stationName(station),
                  subtitle: tour.title,
                  icon: Icons.map_rounded,
                  trailing: [InfoPill(child: CoinCount(p.coins, size: 21))],
                ),
                SizedBox(height: small ? 10 : 20),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      if (box.maxWidth >= 820 || (small && box.maxWidth >= 600)) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(width: box.maxWidth * (small ? 0.4 : 0.36), child: info),
                            SizedBox(width: small ? 12 : 22),
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
    return SuonaCard(
      onTap: open ? onTap : null,
      radius: 22,
      padding: context.compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          open
              ? GradientIcon(
                  concert ? Icons.mic_rounded : Icons.play_arrow_rounded,
                  colors: concert ? SuonaColors.sun : (stars > 0 ? SuonaColors.mint : SuonaColors.brand),
                  size: context.compact ? 40 : 52,
                )
              : Container(
                  width: context.compact ? 40 : 52,
                  height: context.compact ? 40 : 52,
                  decoration: BoxDecoration(color: SuonaColors.cardHigh, borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.lock_rounded, color: SuonaColors.muted, size: 26),
                ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: display(context.compact ? 17 : 21, color: open ? SuonaColors.ink : SuonaColors.muted)),
                Text([info.what, info.count, ?info.time].join(' · '), style: body(context.compact ? 12.5 : 14.5, color: SuonaColors.muted)),
              ],
            ),
          ),
          for (var i = 0; i < 3; i++)
            i < stars
                ? GradientTint(colors: SuonaColors.sun, child: Icon(Icons.star_rounded, size: context.compact ? 22 : 30, color: Colors.white))
                : Icon(Icons.star_rounded, size: context.compact ? 22 : 30, color: SuonaColors.muted.withValues(alpha: 0.3)),
        ],
      ),
    );
  }
}
