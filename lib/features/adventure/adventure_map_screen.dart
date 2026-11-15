import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/game/adventure.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/stage.dart';
import 'adventure_launch.dart';
import 'station_screen.dart';

/// Weltkarte: acht Stationen vom Kinderzimmer bis ins Stadion, verbunden
/// durch einen Weg. Geschaffte Stationen leuchten, die aktuelle pulsiert.
class AdventureMapScreen extends StatelessWidget {
  const AdventureMapScreen({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final p = state.profiles.where((x) => x.id == profileId).firstOrNull;
    if (p == null) return const Scaffold(backgroundColor: SuonaColors.stage);
    final c = state.curriculumOf(p);
    final progress = Adventure.progressOf(p, c.id);
    // Aktuelle Station: die letzte offene.
    var current = 0;
    for (var s = 0; s < Adventure.stationCount; s++) {
      if (Adventure.lockOf(p, c, s) == null) current = s;
    }
    final totalStars = progress.fold<int>(0, (a, row) => a + row.fold<int>(0, (b, x) => b + x));
    return Scaffold(
      body: StageBackground(
        floor: false,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr('Abenteuer', 'Adventure'), style: display(40, color: SuonaColors.spot)),
                          Text(
                            tr(
                              'Vom Kinderzimmer ins Stadion · ${c.name}',
                              'From the bedroom to the stadium · ${c.name}',
                            ),
                            style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.star_rounded, color: SuonaColors.spot, size: 30),
                    const SizedBox(width: 4),
                    Text(
                      '$totalStars/${Adventure.stationCount * Adventure.levelsPerStation * 3}',
                      style: display(24, color: SuonaColors.onStage),
                    ),
                    const SizedBox(width: 18),
                    CoinCount(p.coins, size: 26),
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
                      lockOf: (s) => Adventure.lockOf(p, c, s),
                      onOpen: (s) {
                        final lock = Adventure.lockOf(p, c, s);
                        if (lock != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                lock == StationLock.previous
                                    ? tr(
                                        'Schaff zuerst den Auftritt in „${Adventure.stationName(s - 1)}“.',
                                        'First play the concert at “${Adventure.stationName(s - 1)}”.',
                                      )
                                    : tr(
                                        'Die neuen Töne dieser Station lernst du zuerst im Unterricht. Deine Lehrperson schaltet sie frei.',
                                        'You learn the new notes of this station in your lesson first. Your teacher unlocks them.',
                                      ),
                                style: const TextStyle(fontSize: 17),
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => StationScreen(profileId: p.id, station: s),
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
    required this.size,
    required this.profile,
    required this.current,
    required this.progress,
    required this.lockOf,
    required this.onOpen,
  });

  final Size size;
  final Profile profile;
  final int current;
  final List<List<int>> progress;
  final StationLock? Function(int) lockOf;
  final ValueChanged<int> onOpen;

  /// Lage der Stationen: zickzack von links unten nach rechts oben.
  List<Offset> _points() {
    final w = size.width, h = size.height;
    final node = min(110.0, w / 9);
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
    final node = min(110.0, size.width / 9);
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
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..color = done ? SuonaColors.spot : SuonaColors.stageLine;
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
    required this.station,
    required this.size,
    required this.locked,
    required this.stars,
    required this.isCurrent,
    required this.profile,
    required this.onTap,
  });

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
    final bg = locked != null ? SuonaColors.stageFloor : (done ? SuonaColors.ok : SuonaColors.violet);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (isCurrent && locked == null)
                Container(
                  width: size + 18,
                  height: size + 18,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: SuonaColors.spot.withValues(alpha: 0.3)),
                ),
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: bg,
                  border: Border.all(color: isCurrent ? SuonaColors.spot : SuonaColors.stageLine, width: 4),
                  boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 5))],
                ),
                child: Icon(
                  locked != null ? Icons.lock_rounded : stationIcon(station),
                  size: size * 0.48,
                  color: locked != null ? SuonaColors.onStageMuted : Colors.white,
                ),
              ),
              if (isCurrent && locked == null)
                Positioned(
                  top: -size * 0.42,
                  child: FaceBadge(profile.look, size: size * 0.55),
                ),
              if (done)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: SuonaColors.spot, shape: BoxShape.circle),
                    child: const Icon(Icons.emoji_events_rounded, size: 22, color: SuonaColors.ink),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            Adventure.stationName(station),
            textAlign: TextAlign.center,
            style: display(17, color: locked != null ? SuonaColors.onStageMuted : SuonaColors.onStage),
          ),
          if (locked == null)
            Text(
              '$cleared/${Adventure.levelsPerStation}',
              style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 14),
            ),
        ],
      ),
    );
  }
}
