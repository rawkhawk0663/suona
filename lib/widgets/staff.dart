import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../core/music/pitch.dart';

/// Zeichen aus der Notenschrift Bravura (SMuFL).
class Smufl {
  Smufl._();
  static const gClef8vb = ''; // Violinschlüssel mit kleiner 8 darunter
  static const noteheadWhole = '';
  static const noteheadBlack = '';
  static const sharp = '';
  static const flat = '';
  static const natural = '';
}

/// Eine Note im Notensystem mit eigener Farbe.
class StaffNote {
  const StaffNote(this.pitch, {this.color});
  final Pitch pitch;
  final Color? color;
}

/// Ein Notensystem für Gitarre (Violinschlüssel mit 8) mit einer oder
/// mehreren ganzen Noten. Die Höhe bestimmt die Grösse: Ein Linienabstand
/// ist ein Zwölftel der Höhe, so passen drei Hilfslinien oben und unten.
class StaffView extends StatelessWidget {
  const StaffView({
    super.key,
    required this.notes,
    this.lineColor = SuonaColors.ink,
    this.noteColor = SuonaColors.ink,
    this.drawStaff = true,
    this.drawNotes = true,
  });

  final List<StaffNote> notes;
  final Color lineColor;
  final Color noteColor;

  /// Linien und Schlüssel malen. Aus, wenn nur die Noten darüber gelegt
  /// werden (z. B. damit nur die Note beim Wechsel hereinrutscht).
  final bool drawStaff;
  final bool drawNotes;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: StaffPainter(
        notes: drawNotes ? notes : const [],
        lineColor: lineColor,
        noteColor: noteColor,
        drawStaff: drawStaff,
      ),
      size: Size.infinite,
    );
  }
}

class StaffPainter extends CustomPainter {
  StaffPainter({required this.notes, required this.lineColor, required this.noteColor, this.drawStaff = true});

  final List<StaffNote> notes;
  final Color lineColor;
  final Color noteColor;
  final bool drawStaff;

  /// Linienabstand im Verhältnis zur Höhe.
  static const spacesPerHeight = 12.0;

  /// Y-Lage der untersten Linie in Linienabständen von oben.
  static const bottomLineSpaces = 7.75;

  @override
  void paint(Canvas canvas, Size size) {
    final space = size.height / spacesPerHeight;
    final bottom = bottomLineSpaces * space;
    double yOf(int step) => bottom - step * space / 2;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = (space * 0.11).clamp(1.0, 3.0);
    if (drawStaff) {
      // Notenlinien
      for (var i = 0; i < 5; i++) {
        final y = yOf(i * 2);
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
      // Schlüssel: Der Bezugspunkt des Zeichens liegt auf der g-Linie (Schritt 2).
      _glyph(canvas, Smufl.gClef8vb, space, Offset(space * 0.6, yOf(2)), lineColor);
    }

    if (notes.isEmpty) return;
    // Noten gleichmässig im freien Bereich rechts vom Schlüssel verteilen.
    final left = space * 5.5;
    final usable = size.width - left - space * 2;
    final gap = usable / notes.length;
    final ledgerPaint = Paint()
      ..color = lineColor
      ..strokeWidth = linePaint.strokeWidth * 1.15;
    final headWidth = space * 1.69;
    for (var i = 0; i < notes.length; i++) {
      final n = notes[i];
      final color = n.color ?? noteColor;
      final cx = left + gap * (i + 0.5);
      final step = n.pitch.staffStep;
      // Hilfslinien
      final ledgerHalf = headWidth * 0.85;
      for (var s = -2; s >= step; s -= 2) {
        canvas.drawLine(Offset(cx - ledgerHalf, yOf(s)), Offset(cx + ledgerHalf, yOf(s)), ledgerPaint);
      }
      for (var s = 10; s <= step; s += 2) {
        canvas.drawLine(Offset(cx - ledgerHalf, yOf(s)), Offset(cx + ledgerHalf, yOf(s)), ledgerPaint);
      }
      // Notenkopf
      _glyph(canvas, Smufl.noteheadWhole, space, Offset(cx - headWidth / 2, yOf(step)), color);
      // Vorzeichen links davon
      final acc = switch (n.pitch.accidental) {
        Accidental.sharp => Smufl.sharp,
        Accidental.flat => Smufl.flat,
        Accidental.natural => null,
      };
      if (acc != null) {
        final w = _glyphWidth(acc, space);
        _glyph(canvas, acc, space, Offset(cx - headWidth / 2 - space * 0.35 - w, yOf(step)), color);
      }
    }
  }

  /// Zeichen so malen, dass sein Bezugspunkt (Grundlinie, links) bei [origin] liegt.
  void _glyph(Canvas canvas, String glyph, double space, Offset origin, Color color) {
    final tp = _painter(glyph, space, color);
    final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    tp.paint(canvas, Offset(origin.dx, origin.dy - baseline));
  }

  double _glyphWidth(String glyph, double space) => _painter(glyph, space, noteColor).width;

  TextPainter _painter(String glyph, double space, Color color) {
    return TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(fontFamily: 'Bravura', fontSize: space * 4, color: color, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(StaffPainter old) =>
      old.lineColor != lineColor ||
      old.noteColor != noteColor ||
      old.drawStaff != drawStaff ||
      !_sameNotes(old.notes, notes);

  static bool _sameNotes(List<StaffNote> a, List<StaffNote> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].pitch != b[i].pitch || a[i].color != b[i].color) return false;
    }
    return true;
  }
}
