import 'dart:math';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/music/guitar.dart';
import '../core/music/note_names.dart';

/// Ein Punkt auf dem Griffbrett.
class FretMark {
  const FretMark(this.position, {required this.color, this.filled = true, this.label});
  final FretPosition position;
  final Color color;

  /// Gefüllter Punkt oder nur ein Ring („hier liegt der Ton auch“).
  final bool filled;
  final String? label;
}

/// Griffbrett bis zum 12. Bund mit gleich breiten Bünden (für Kinder
/// leichter zu treffen als echte Abstände). Links die leeren Saiten.
class Fretboard extends StatelessWidget {
  const Fretboard({
    super.key,
    this.marks = const [],
    this.onTap,
    this.lowStringOnTop = false,
    this.naming = NoteNaming.german,
    this.activeStrings,
    this.minFret = 0,
    this.maxFret = Guitar.maxFret,
    this.highlightString,
  });

  final List<FretMark> marks;
  final ValueChanged<FretPosition>? onTap;

  /// Tiefe E-Saite oben (Blick von oben auf die Gitarre). Sonst wie in der
  /// Tabulatur: hohe e-Saite oben.
  final bool lowStringOnTop;
  final NoteNaming naming;

  /// Nur diese Saiten und Bünde sind „im Spiel“, der Rest ist abgedunkelt.
  final Set<int>? activeStrings;
  final int minFret;
  final int maxFret;

  /// Diese Saite leuchtet (Saite vorgegeben).
  final int? highlightString;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final geo = FretboardGeometry(Size(c.maxWidth, c.maxHeight), lowStringOnTop: lowStringOnTop);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: onTap == null
              ? null
              : (d) {
                  final p = geo.positionAt(d.localPosition);
                  if (p != null) onTap!(p);
                },
          child: MouseRegion(
            cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
            child: CustomPaint(
              size: Size(c.maxWidth, c.maxHeight),
              painter: _FretboardPainter(
                geo: geo,
                marks: marks,
                naming: naming,
                activeStrings: activeStrings,
                minFret: minFret,
                maxFret: maxFret,
                highlightString: highlightString,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lage der Saiten und Bünde in einem Rechteck.
class FretboardGeometry {
  FretboardGeometry(this.size, {required this.lowStringOnTop});

  final Size size;
  final bool lowStringOnTop;

  double get labelWidth => 34.0;
  static const numbersHeight = 26.0;

  /// Breite der Zone für leere Saiten im Verhältnis zu einem Bund.
  static const openZone = 0.9;

  double get fretWidth => (size.width - labelWidth) / (Guitar.maxFret + openZone);
  double get nutX => labelWidth + fretWidth * openZone;
  double get boardTop => 4;
  double get boardBottom => size.height - numbersHeight;
  double get stringGap => (boardBottom - boardTop) / 6;

  int rowOf(int string) => lowStringOnTop ? 6 - string : string - 1;
  double stringY(int string) => boardTop + (rowOf(string) + 0.5) * stringGap;

  /// Mitte der Stelle für einen Punkt.
  Offset centerOf(FretPosition p) {
    final x = p.fret == 0 ? labelWidth + fretWidth * openZone / 2 : nutX + (p.fret - 0.5) * fretWidth;
    return Offset(x, stringY(p.string));
  }

  /// Welche Stelle liegt unter [o]? Null ausserhalb.
  FretPosition? positionAt(Offset o) {
    if (o.dy < boardTop || o.dy > boardBottom + 8 || o.dx < labelWidth * 0.4) return null;
    final row = ((o.dy - boardTop) / stringGap).floor().clamp(0, 5);
    final string = lowStringOnTop ? 6 - row : row + 1;
    final fret = o.dx < nutX ? 0 : (((o.dx - nutX) / fretWidth).floor() + 1).clamp(1, Guitar.maxFret);
    return FretPosition(string, fret);
  }

  double get dotRadius => min(stringGap, fretWidth) * 0.4;
}

class _FretboardPainter extends CustomPainter {
  _FretboardPainter({
    required this.geo,
    required this.marks,
    required this.naming,
    required this.activeStrings,
    required this.minFret,
    required this.maxFret,
    required this.highlightString,
  });

  final FretboardGeometry geo;
  final List<FretMark> marks;
  final NoteNaming naming;
  final Set<int>? activeStrings;
  final int minFret;
  final int maxFret;
  final int? highlightString;

  static const _wood = Color(0xFF5B3A26);
  static const _woodDark = Color(0xFF452A1A);
  static const _fret = Color(0xFFC9CAD8);
  static const _nut = Color(0xFFF1E9D2);
  static const _string = Color(0xFFE9DDC2);
  static const _inlay = Color(0xFFEFE6D2);

  @override
  void paint(Canvas canvas, Size size) {
    final g = geo;
    final board = Rect.fromLTRB(g.nutX, g.boardTop, size.width, g.boardBottom);
    final open = Rect.fromLTRB(g.labelWidth, g.boardTop, g.nutX, g.boardBottom);
    final r = Radius.circular(10);
    // Holz
    canvas.drawRRect(
      RRect.fromRectAndCorners(board, topRight: r, bottomRight: r),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_woodDark, _wood, _woodDark],
        ).createShader(board),
    );
    // Zone der leeren Saiten: etwas heller, wie die Kopfplatte
    canvas.drawRRect(RRect.fromRectAndCorners(open, topLeft: r, bottomLeft: r), Paint()..color = SuonaColors.stageLine);

    // Abgedunkelte Bünde ausserhalb des Bereichs
    final dim = Paint()..color = Colors.black.withValues(alpha: 0.45);
    if (minFret > 0) {
      final x = minFret == 1 ? g.nutX : g.nutX + (minFret - 1) * g.fretWidth;
      canvas.drawRect(Rect.fromLTRB(g.labelWidth, g.boardTop, x, g.boardBottom), dim);
    }
    if (maxFret < Guitar.maxFret) {
      final x = maxFret == 0 ? g.nutX : g.nutX + maxFret * g.fretWidth;
      canvas.drawRect(Rect.fromLTRB(x, g.boardTop, size.width, g.boardBottom), dim);
    }

    // Einlagen bei 3, 5, 7, 9 und doppelt bei 12
    final inlay = Paint()..color = _inlay.withValues(alpha: 0.85);
    final midY = (g.boardTop + g.boardBottom) / 2;
    final ir = min(g.stringGap, g.fretWidth) * 0.16;
    for (final f in const [3, 5, 7, 9]) {
      canvas.drawCircle(Offset(g.nutX + (f - 0.5) * g.fretWidth, midY), ir, inlay);
    }
    final x12 = g.nutX + 11.5 * g.fretWidth;
    canvas.drawCircle(Offset(x12, g.boardTop + g.stringGap * 1.5), ir, inlay);
    canvas.drawCircle(Offset(x12, g.boardBottom - g.stringGap * 1.5), ir, inlay);

    // Bundstäbchen
    final fretPaint = Paint()
      ..color = _fret
      ..strokeWidth = 3;
    for (var f = 1; f <= Guitar.maxFret; f++) {
      final x = g.nutX + f * g.fretWidth;
      canvas.drawLine(Offset(x, g.boardTop), Offset(x, g.boardBottom), fretPaint);
    }
    // Sattel
    canvas.drawRect(Rect.fromLTRB(g.nutX - 5, g.boardTop, g.nutX + 2, g.boardBottom), Paint()..color = _nut);

    // Saite vorgegeben: leuchtendes Band
    if (highlightString != null) {
      final y = g.stringY(highlightString!);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(g.labelWidth, y - g.stringGap * 0.42, size.width, y + g.stringGap * 0.42),
          const Radius.circular(8),
        ),
        Paint()..color = SuonaColors.spot.withValues(alpha: 0.28),
      );
    }

    // Saiten (tiefe dicker) und Namen
    final names = naming == NoteNaming.german ? Guitar.stringNamesGerman : Guitar.stringNamesInternational;
    for (var s = 1; s <= 6; s++) {
      final y = g.stringY(s);
      final active = activeStrings == null || activeStrings!.contains(s);
      canvas.drawLine(
        Offset(g.labelWidth, y),
        Offset(size.width, y),
        Paint()
          ..color = active ? _string : _string.withValues(alpha: 0.25)
          ..strokeWidth = 1.2 + (s - 1) * 0.55,
      );
      _text(
        canvas,
        names[s - 1],
        Offset(g.labelWidth / 2, y),
        display(min(22, g.stringGap * 0.62), color: active ? SuonaColors.onStage : SuonaColors.onStageMuted),
      );
    }

    // Bundnummern
    for (final f in const [0, 3, 5, 7, 9, 12]) {
      final x = f == 0 ? g.labelWidth + g.fretWidth * FretboardGeometry.openZone / 2 : g.nutX + (f - 0.5) * g.fretWidth;
      _text(
        canvas,
        '$f',
        Offset(x, g.boardBottom + FretboardGeometry.numbersHeight / 2 + 1),
        display(16, color: SuonaColors.onStageMuted, weight: FontWeight.w700),
      );
    }

    // Punkte
    final dot = g.dotRadius;
    for (final m in marks) {
      final c = g.centerOf(m.position);
      if (m.filled) {
        canvas.drawCircle(c.translate(0, 2), dot, Paint()..color = Colors.black38);
        canvas.drawCircle(c, dot, Paint()..color = m.color);
        canvas.drawCircle(
          c,
          dot,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Colors.white,
        );
      } else {
        canvas.drawCircle(
          c,
          dot * 0.92,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = m.color,
        );
      }
      if (m.label != null) {
        _text(canvas, m.label!, c, display(dot * 0.95, color: m.filled ? Colors.white : m.color));
      }
    }
  }

  void _text(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_FretboardPainter old) => true;
}
