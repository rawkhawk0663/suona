import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/game/adventure.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/visuals.dart';
import 'station_screen.dart';
import 'tour.dart';

/// Weltkarte: acht Stationen, verbunden durch einen Weg. Geschaffte
/// Stationen leuchten, die aktuelle pulsiert. Für Noten-Abenteuer und
/// Akkord-Tour ([tour]).
class AdventureMapScreen extends StatelessWidget {
  const AdventureMapScreen({super.key, required this.profileId, this.tour = const NoteTour()});
  final String profileId;
  final TourSpec tour;

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final p = state.profiles.where((x) => x.id == profileId).firstOrNull;
    if (p == null) return const Scaffold();
    final progress = tour.progress(state, p);
    // Aktuelle Station: die letzte offene.
    var current = 0;
    for (var s = 0; s < tour.stationCount; s++) {
      if (tour.lockOf(state, p, s) == null) current = s;
    }
    final totalStars = progress.fold<int>(0, (a, row) => a + row.fold<int>(0, (b, x) => b + x));
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: context.screenPadding,
            child: Column(
              children: [
                ScreenHeader(
                  title: tour.title,
                  subtitle: tour.subtitle(state, p),
                  trailing: [
                    InfoPill(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GradientIcon(Icons.star_rounded, colors: SuonaColors.sun, size: 34, circle: true),
                          const SizedBox(width: 8),
                          Text(
                            '$totalStars/${Adventure.stationCount * Adventure.levelsPerStation * 3}',
                            style: body(17, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    InfoPill(child: CoinCount(p.coins, size: 21)),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => _MapView(
                      size: Size(box.maxWidth, box.maxHeight),
                      profile: p,
                      current: current,
                      progress: progress,
                      tour: tour,
                      lockOf: (s) => tour.lockOf(state, p, s),
                      onOpen: (s) {
                        final lock = tour.lockOf(state, p, s);
                        if (lock != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                lock == StationLock.previous
                                    ? tr(
                                        'Schaff zuerst den Auftritt in „${tour.stationName(s - 1)}“.',
                                        'First play the concert at “${tour.stationName(s - 1)}”.',
                                      )
                                    : tour.teacherLockText,
                                style: body(17),
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StationScreen(profileId: p.id, station: s, tour: tour),
                          ),
                        );
                      },
                    ),
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

class _MapView extends StatelessWidget {
  const _MapView({
    required this.tour,
    required this.size,
    required this.profile,
    required this.current,
    required this.progress,
    required this.lockOf,
    required this.onOpen,
  });

  final TourSpec tour;
  final Size size;
  final Profile profile;
  final int current;
  final List<List<int>> progress;
  final StationLock? Function(int) lockOf;
  final ValueChanged<int> onOpen;

  /// Lage der Stationen: zickzack von links unten nach rechts oben.
  List<Offset> _points() {
    final w = size.width, h = size.height;
    final node = min(min(110.0, w / 9), h / 3.6);
    return [
      for (var i = 0; i < Adventure.stationCount; i++)
        Offset(
          node * 0.8 + (w - node * 1.6) * i / (Adventure.stationCount - 1),
          h * (i.isEven ? 0.72 : 0.4) - (h * 0.22) * i / (Adventure.stationCount - 1),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pts = _points();
    final node = min(min(110.0, size.width / 9), size.height / 3.6);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: CustomPaint(painter: _PathPainter(pts, current))),
        for (var s = 0; s < Adventure.stationCount; s++)
          Positioned(
            left: pts[s].dx - node * 0.8,
            top: pts[s].dy - node / 2,
            width: node * 1.6,
            child: _StationNode(
              tour: tour,
              station: s,
              size: node,
              locked: lockOf(s),
              stars: progress[s],
              isCurrent: s == current,
              profile: profile,
              onTap: () => onOpen(s),
            ),
          ),
      ],
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.points, this.current);
  final List<Offset> points;
  final int current;

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i], b = points[i + 1];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2 + (i.isEven ? 30 : -30));
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy);
      final done = i < current;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..color = done ? SuonaColors.accent : SuonaColors.line;
      // Gestrichelt: Punkte entlang des Weges
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 22) {
          final seg = metric.extractPath(d, min(d + 10, metric.length));
          canvas.drawPath(seg, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) => old.current != current || old.points.length != points.length;
}

class _StationNode extends StatelessWidget {
  const _StationNode({
    required this.tour,
    required this.station,
    required this.size,
    required this.locked,
    required this.stars,
    required this.isCurrent,
    required this.profile,
    required this.onTap,
  });

  final TourSpec tour;
  final int station;
  final double size;
  final StationLock? locked;
  final List<int> stars;
  final bool isCurrent;
  final Profile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = stars[Adventure.concertLevel] > 0;
    final cleared = stars.where((x) => x > 0).length;
    final colors = done ? SuonaColors.mint : SuonaColors.brand;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: locked != null ? null : gradientOf(colors),
                  color: locked != null ? SuonaColors.card : null,
                  border: locked != null
                      ? Border.all(color: SuonaColors.line, width: 1.5)
                      : (isCurrent ? Border.all(color: Colors.white, width: 4) : null),
                  boxShadow: locked != null ? null : glowOf(colors, strength: isCurrent ? 0.6 : 0.3, blur: isCurrent ? 36 : 20),
                ),
                child: Icon(
                  locked != null ? Icons.lock_rounded : tour.stationIcon(station),
                  size: size * 0.46,
                  color: locked != null ? SuonaColors.muted : Colors.white,
                ),
              ),
              if (isCurrent && locked == null)
                Positioned(
                  top: -size * 0.42,
                  child: FaceBadge(profile.look, size: size * 0.55, ring: SuonaColors.card),
                ),
              if (done)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: GradientIcon(Icons.emoji_events_rounded, colors: SuonaColors.sun, size: 34, circle: true),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tour.stationName(station),
            textAlign: TextAlign.center,
            style: display(16, color: locked != null ? SuonaColors.muted : SuonaColors.ink),
          ),
          if (locked == null)
            Text(
              '$cleared/${Adventure.levelsPerStation}',
              style: body(14, color: SuonaColors.muted),
            ),
        ],
      ),
    );
  }
}
