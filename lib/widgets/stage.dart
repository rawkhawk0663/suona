import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/theme.dart';
import '../core/character/character_art.dart';
import '../core/character/look.dart';

/// Bühnen-Hintergrund: dunkles Blau, zwei Scheinwerfer, Bühnenboden.
class StageBackground extends StatelessWidget {
  const StageBackground({super.key, required this.child, this.floor = true});

  final Widget child;
  final bool floor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [SuonaColors.stageDeep, SuonaColors.stage],
        ),
      ),
      child: CustomPaint(
        painter: _StagePainter(floor: floor),
        child: child,
      ),
    );
  }
}

class _StagePainter extends CustomPainter {
  _StagePainter({required this.floor});
  final bool floor;

  @override
  void paint(Canvas canvas, Size size) {
    final beam = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFFFFE9A8).withValues(alpha: 0.16), const Color(0xFFFFE9A8).withValues(alpha: 0.03)],
      ).createShader(Offset.zero & size);
    final h = size.height;
    for (final x in [0.22, 0.78]) {
      final top = size.width * x;
      final spread = max(size.width * 0.2, h * 0.32);
      canvas.drawPath(
        Path()
          ..moveTo(top - 8, 0)
          ..lineTo(top + 8, 0)
          ..lineTo(top + spread, h)
          ..lineTo(top - spread, h)
          ..close(),
        beam,
      );
    }
    // Sterne
    final rnd = Random(7);
    final star = Paint()..color = SuonaColors.onStage.withValues(alpha: 0.35);
    for (var i = 0; i < 26; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * h * 0.6),
        rnd.nextDouble() * 1.4 + 0.4,
        star,
      );
    }
    if (floor) {
      final floorTop = h - min(70.0, h * 0.09);
      canvas.drawRect(Rect.fromLTRB(0, floorTop, size.width, h), Paint()..color = SuonaColors.stageFloor);
      canvas.drawRect(
        Rect.fromLTRB(0, floorTop, size.width, floorTop + 3),
        Paint()..color = SuonaColors.spot.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_StagePainter old) => old.floor != floor;
}

/// Luna oder Fuzz mit eigenem Aussehen, ganz oder nur das Gesicht.
class CharacterView extends StatelessWidget {
  const CharacterView(this.look, {super.key, this.face = false, this.bust = false, this.size});

  final CharacterLook look;
  final bool face;

  /// Kopf mit Platz für Kopfbedeckungen (Shop).
  final bool bust;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final svg = CharacterArt.instance.svg(look, face: face, bust: bust);
    Widget picture(double? w, double? h) => SvgPicture.string(
      svg,
      key: ValueKey(look.key),
      width: w,
      height: h,
      fit: BoxFit.contain,
      semanticsLabel: look.character.displayName,
    );
    if (size != null) return picture(size, size);
    // Ohne feste Grösse: den verfügbaren Platz füllen (sofern begrenzt).
    return LayoutBuilder(
      builder: (context, c) => picture(c.hasBoundedWidth ? c.maxWidth : null, c.hasBoundedHeight ? c.maxHeight : null),
    );
  }
}

/// Rundes Gesicht in einem Kreis (Profil-Auswahl, Kopfzeile).
class FaceBadge extends StatelessWidget {
  const FaceBadge(this.look, {super.key, this.size = 56, this.ring = SuonaColors.spot});

  final CharacterLook look;
  final double size;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SuonaColors.stageFloor,
        border: Border.all(color: ring, width: max(2, size / 22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(top: size * 0.06),
        child: CharacterView(look, face: true),
      ),
    );
  }
}

/// Münze mit Zahl.
class CoinCount extends StatelessWidget {
  const CoinCount(this.coins, {super.key, this.size = 22, this.color = SuonaColors.onStage});

  final int coins;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoinIcon(size: size),
        SizedBox(width: size * 0.3),
        Text(
          '$coins',
          style: display(size * 0.95, color: color, weight: FontWeight.w800),
        ),
      ],
    );
  }
}

class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SuonaColors.spot,
        border: Border.all(color: SuonaColors.spotDeep, width: size * 0.08),
      ),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.5,
        height: size * 0.5,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: SuonaColors.spotDeep, width: size * 0.06),
        ),
      ),
    );
  }
}

/// Flamme mit Anzahl Tage in Folge.
class StreakCount extends StatelessWidget {
  const StreakCount(this.days, {super.key, this.size = 22, this.active = true, this.shields = 0});

  final int days;
  final double size;
  final bool active;
  final int shields;

  @override
  Widget build(BuildContext context) {
    final color = active ? SuonaColors.coral : SuonaColors.onStageMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department_rounded, size: size * 1.2, color: color),
        SizedBox(width: size * 0.15),
        Text('$days', style: display(size * 0.95, color: SuonaColors.onStage)),
        for (var i = 0; i < shields; i++)
          Padding(
            padding: EdgeInsets.only(left: size * 0.25),
            child: Icon(Icons.shield_rounded, size: size * 0.9, color: SuonaColors.teal),
          ),
      ],
    );
  }
}

/// Grosse, gut treffbare Kachel für Kinder.
class StageTile extends StatelessWidget {
  const StageTile({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
    this.locked = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final bg = locked ? SuonaColors.stageFloor : color;
    final fg = locked ? SuonaColors.onStageMuted : Colors.white;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: locked ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Row(
            children: [
              Icon(locked ? Icons.lock_rounded : icon, size: 40, color: fg),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(title, maxLines: 1, style: display(28, color: fg)),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(fontFamily: kBodyFont, fontSize: 15, color: fg.withValues(alpha: 0.85)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Runder Knopf mit Symbol auf der Bühne (Zurück, Schliessen …).
class StageIconButton extends StatelessWidget {
  const StageIconButton({super.key, required this.icon, required this.onPressed, this.tooltip});

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      icon: Icon(icon),
      iconSize: 28,
      style: IconButton.styleFrom(
        backgroundColor: SuonaColors.stageFloor,
        foregroundColor: SuonaColors.onStage,
        minimumSize: const Size(52, 52),
      ),
    );
  }
}
