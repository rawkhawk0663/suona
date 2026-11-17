import 'dart:math';

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/music/guitar.dart';
import '../core/music/note_names.dart';

/// Was links neben einer Saite steht: leer anschlagen oder nicht spielen.
enum OpenMark { none, open, muted }

/// Ein Punkt im Griffbild (mit Fingernummer).
class ChordDot {
  const ChordDot(this.position, {required this.color, this.label, this.filled = true});
  final FretPosition position;
  final Color color;
  final String? label;

  /// Gefüllt oder nur als Ring („hier hätte er hingehört“).
  final bool filled;
}

/// Griffbild für Akkorde, im Stil des Griffbretts ([Fretboard]): waagrecht,
/// die hohe e-Saite oben (oder unten, Einstellung „Tiefe E-Saite oben“),
/// links die Zone für leere Saiten mit „o“ und „x“. Es zeigt nur die hohen
/// [strings] Saiten und die ersten [frets] Bünde, damit die Punkte gross sind.
class ChordBoard extends StatelessWidget {
  const ChordBoard({
    super.key,
    required this.strings,
    this.dots = const [],
    this.openMarks = const {},
    this.openColors = const {},
    this.onTap,
    this.lowStringOnTop = false,
    this.naming = NoteNaming.german,
    this.frets = 5,
  });

  final int strings;
  final List<ChordDot> dots;

  /// Pro Saite: „o“ (leer) oder „x“ (nicht spielen).
  final Map<int, OpenMark> openMarks;

  /// Farbe der Zeichen links (z. B. rot, wenn falsch).
  final Map<int, Color> openColors;

  /// Antippen: Bund 0 = Zone der leeren Saiten.
  final ValueChanged<FretPosition>? onTap;
  final bool lowStringOnTop;
  final NoteNaming naming;
  final int frets;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final geo = ChordBoardGeometry(
          Size(c.maxWidth, c.maxHeight),
          strings: strings,
          frets: frets,
          lowStringOnTop: lowStringOnTop,
        );
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
              painter: _ChordBoardPainter(
                geo: geo,
                dots: dots,
                openMarks: openMarks,
                openColors: openColors,
                naming: naming,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Lage der Saiten und Bünde im Griffbild.
class ChordBoardGeometry {
  ChordBoardGeometry(this.size, {required this.strings, required this.frets, required this.lowStringOnTop});

  final Size size;
  final int strings;
  final int frets;
  final bool lowStringOnTop;

  static const labelWidth = 40.0;
  static const numbersHeight = 28.0;
  static const openZone = 1.0;

  double get fretWidth => (size.width - labelWidth) / (frets + openZone);
  double get nutX => labelWidth + fretWidth * openZone;
  double get boardTop => 4;
  double get boardBottom => size.height - numbersHeight;
  double get stringGap => (boardBottom - boardTop) / strings;

  /// Zeile einer Saite von oben (0 = oberste).
  int rowOf(int string) => lowStringOnTop ? strings - string : string - 1;
  double stringY(int string) => boardTop + (rowOf(string) + 0.5) * stringGap;

  Offset centerOf(FretPosition p) {
    final x = p.fret == 0 ? labelWidth + fretWidth * openZone / 2 : nutX + (p.fret - 0.5) * fretWidth;
    return Offset(x, stringY(p.string));
  }

  FretPosition? positionAt(Offset o) {
    if (o.dy < boardTop - 6 || o.dy > boardBottom + 10 || o.dx < labelWidth * 0.5) return null;
    final row = ((o.dy - boardTop) / stringGap).floor().clamp(0, strings - 1);
    final string = lowStringOnTop ? strings - row : row + 1;
    final fret = o.dx < nutX ? 0 : (((o.dx - nutX) / fretWidth).floor() + 1).clamp(1, frets);
    return FretPosition(string, fret);
  }

  double get dotRadius => min(stringGap * 0.42, fretWidth * 0.36);
}

class _ChordBoardPainter extends CustomPainter {
  _ChordBoardPainter({
    required this.geo,
    required this.dots,
    required this.openMarks,
    required this.openColors,
    required this.naming,
  });

  final ChordBoardGeometry geo;
  final List<ChordDot> dots;
  final Map<int, OpenMark> openMarks;
  final Map<int, Color> openColors;
  final NoteNaming naming;

  static const _wood = Color(0xFF5B3A26);
  static const _woodDark = Color(0xFF452A1A);
  static const _fret = Color(0xFFC9CAD8);
  static const _nut = Color(0xFFF1E9D2);
  static const _string = Color(0xFFE9DDC2);
  static const _inlay = Color(0xFFEFE6D2);

  @override
  void paint(Canvas canvas, Size size) {
    final g = geo;
    final r = const Radius.circular(12);
    final board = Rect.fromLTRB(g.nutX, g.boardTop, size.width, g.boardBottom);
    final open = Rect.fromLTRB(ChordBoardGeometry.labelWidth, g.boardTop, g.nutX, g.boardBottom);
    canvas.drawRRect(
      RRect.fromRectAndCorners(board, topRight: r, bottomRight: r),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_woodDark, _wood, _woodDark],
        ).createShader(board),
    );
    canvas.drawRRect(RRect.fromRectAndCorners(open, topLeft: r, bottomLeft: r), Paint()..color = SuonaColors.stageLine);

    // Einlagen beim 3. und 5. Bund (zur Orientierung wie auf der Gitarre)
    final inlay = Paint()..color = _inlay.withValues(alpha: 0.8);
    final midY = (g.boardTop + g.boardBottom) / 2;
    for (final f in const [3, 5]) {
      if (f <= g.frets) canvas.drawCircle(Offset(g.nutX + (f - 0.5) * g.fretWidth, midY), g.dotRadius * 0.28, inlay);
    }
    final fretPaint = Paint()
      ..color = _fret
      ..strokeWidth = 4;
    for (var f = 1; f <= g.frets; f++) {
      final x = g.nutX + f * g.fretWidth;
      canvas.drawLine(Offset(x, g.boardTop), Offset(x, g.boardBottom), fretPaint);
    }
    canvas.drawRect(Rect.fromLTRB(g.nutX - 7, g.boardTop, g.nutX + 2, g.boardBottom), Paint()..color = _nut);

    // Saiten (tiefe dicker) mit Namen
    final names = naming == NoteNaming.german ? Guitar.stringNamesGerman : Guitar.stringNamesInternational;
    for (var s = 1; s <= g.strings; s++) {
      final y = g.stringY(s);
      canvas.drawLine(
        Offset(ChordBoardGeometry.labelWidth, y),
        Offset(size.width, y),
        Paint()
          ..color = _string
          ..strokeWidth = 1.6 + (s - 1) * 0.7,
      );
      _text(
        canvas,
        names[s - 1],
        Offset(ChordBoardGeometry.labelWidth / 2, y),
        display(min(26, g.stringGap * 0.55), color: SuonaColors.onStage),
      );
      // „o“ oder „x“ in der Zone der leeren Saiten
      final mark = openMarks[s] ?? OpenMark.none;
      if (mark != OpenMark.none) {
        final c = Offset(ChordBoardGeometry.labelWidth + g.fretWidth * ChordBoardGeometry.openZone / 2, y);
        final color = openColors[s] ?? SuonaColors.onStage;
        final rad = min(g.dotRadius * 0.5, 22.0);
        final stroke = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = max(3.0, rad * 0.28)
          ..strokeCap = StrokeCap.round
          ..color = color;
        canvas.drawCircle(c, rad + 4, Paint()..color = SuonaColors.stage.withValues(alpha: 0.85));
        if (mark == OpenMark.open) {
          canvas.drawCircle(c, rad, stroke);
        } else {
          canvas.drawLine(c + Offset(-rad, -rad), c + Offset(rad, rad), stroke);
          canvas.drawLine(c + Offset(rad, -rad), c + Offset(-rad, rad), stroke);
        }
      }
    }

    // Bundnummern
    for (var f = 1; f <= g.frets; f++) {
      _text(
        canvas,
        '$f',
        Offset(g.nutX + (f - 0.5) * g.fretWidth, g.boardBottom + ChordBoardGeometry.numbersHeight / 2 + 1),
        display(17, color: SuonaColors.onStageMuted, weight: FontWeight.w700),
      );
    }

    // Punkte mit Fingernummern
    final dot = g.dotRadius;
    for (final d in dots) {
      final c = g.centerOf(d.position);
      if (d.filled) {
        canvas.drawCircle(c.translate(0, 3), dot, Paint()..color = Colors.black38);
        canvas.drawCircle(c, dot, Paint()..color = d.color);
        canvas.drawCircle(
          c,
          dot,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white,
        );
      } else {
        canvas.drawCircle(
          c,
          dot * 0.9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = d.color,
        );
      }
      if (d.label != null) {
        _text(canvas, d.label!, c, display(dot * 1.05, color: d.filled ? Colors.white : d.color));
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
  bool shouldRepaint(_ChordBoardPainter old) => true;
}
