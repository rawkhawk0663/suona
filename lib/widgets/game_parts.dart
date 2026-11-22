import 'package:flutter/material.dart';

import '../app/l10n.dart';
import '../app/theme.dart';
import 'visuals.dart';

/// Bausteine der Spielbildschirme (Noten und Akkorde): Antwortknöpfe,
/// Rückmeldung, Fortschritt, Zeit, Publikum.

enum AnswerState { normal, right, wrong, hint }

/// Grosser Antwortknopf (Notenname oder Akkord). Richtig leuchtet im
/// Mint-Verlauf, falsch rot, nach einem Fehler zeigt ein Mint-Rand die Lösung.
class AnswerButton extends StatelessWidget {
  const AnswerButton({
    super.key,
    required this.label,
    required this.width,
    required this.height,
    required this.state,
    required this.onTap,
    this.hidden = false,
  });

  final String label;
  final double width;
  final double height;
  final AnswerState state;
  final VoidCallback? onTap;

  /// Vom Stimmgerät weggestrichen.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height * 0.26);
    final right = state == AnswerState.right;
    final decoration = BoxDecoration(
      borderRadius: radius,
      gradient: right ? gradientOf(SuonaColors.mint) : null,
      color: switch (state) {
        AnswerState.right => null,
        AnswerState.wrong => SuonaColors.wrong,
        AnswerState.hint => SuonaColors.cardHigh,
        AnswerState.normal => SuonaColors.card,
      },
      border: switch (state) {
        AnswerState.normal => Border.all(color: SuonaColors.line),
        AnswerState.hint => Border.all(color: SuonaColors.ok, width: 3),
        _ => null,
      },
      boxShadow: right ? glowOf(SuonaColors.mint, strength: 0.45) : null,
    );
    final fg = state == AnswerState.right || state == AnswerState.wrong ? Colors.white : SuonaColors.ink;
    return AnimatedOpacity(
      opacity: hidden ? 0.18 : 1,
      duration: const Duration(milliseconds: 200),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: width,
        height: height,
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Center(
              child: FittedBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(label, style: display(height * 0.44, color: fg)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Knopf für ♯ und ♭ (Bravura-Zeichen). Gewählt im Bühnen-Verlauf.
class AccidentalKey extends StatelessWidget {
  const AccidentalKey({super.key, required this.glyph, required this.selected, required this.height, required this.onTap});

  final String glyph;
  final bool selected;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height * 0.32);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: height * 1.5,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: selected ? gradientOf(SuonaColors.brand) : null,
        color: selected ? null : SuonaColors.card,
        border: selected ? null : Border.all(color: SuonaColors.line),
        boxShadow: selected ? glowOf(SuonaColors.brand, strength: 0.3, blur: 18) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(
            child: Text(
              glyph,
              style: TextStyle(
                fontFamily: 'Bravura',
                fontSize: height * 0.95,
                height: 1.25,
                color: selected ? Colors.white : SuonaColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum FeedbackKind { right, wrong, shield }

/// Rückmeldung über dem Notenblatt: „G! +10“ im Mint-Verlauf oder rot.
class FeedbackBadge extends StatelessWidget {
  const FeedbackBadge({super.key, required this.kind, required this.text, this.icon, this.extra, this.gain});

  final FeedbackKind kind;
  final String text;
  final IconData? icon;

  /// Kleiner Zusatz (z. B. die Oktave).
  final String? extra;

  /// Gewonnene Münzen.
  final int? gain;

  @override
  Widget build(BuildContext context) {
    final small = context.compact;
    final colors = switch (kind) {
      FeedbackKind.right => SuonaColors.mint,
      FeedbackKind.shield => SuonaColors.brand,
      FeedbackKind.wrong => [SuonaColors.wrong, SuonaColors.wrong],
    };
    return Container(
      padding: small ? const EdgeInsets.symmetric(horizontal: 14, vertical: 6) : const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        gradient: gradientOf(colors, horizontal: true),
        borderRadius: BorderRadius.circular(999),
        boxShadow: glowOf(colors, strength: 0.4, blur: 28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon ?? (kind == FeedbackKind.right ? Icons.check_rounded : Icons.close_rounded),
            color: Colors.white,
            size: small ? 20 : 28,
          ),
          SizedBox(width: small ? 6 : 10),
          Flexible(child: Text(text, style: display(small ? 17 : 26, color: Colors.white))),
          if (extra != null) ...[
            const SizedBox(width: 8),
            Text(extra!, style: display(small ? 13 : 18, color: Colors.white70, weight: FontWeight.w600)),
          ],
          if (gain != null) ...[
            SizedBox(width: small ? 8 : 12),
            Text('+$gain', style: display(small ? 15 : 20, color: Colors.white.withValues(alpha: 0.95))),
          ],
        ],
      ),
    );
  }
}

/// Punkte für die Fragen einer Runde: Mint = richtig, rot = falsch.
class ProgressDots extends StatelessWidget {
  const ProgressDots({super.key, required this.total, required this.results, this.size = 22});
  final int total;
  final List<bool> results;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: size * 0.36,
      runSpacing: size * 0.28,
      children: [
        for (var i = 0; i < total; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: i < results.length && results[i] ? gradientOf(SuonaColors.mint) : null,
              color: i < results.length
                  ? (results[i] ? null : SuonaColors.wrong)
                  : SuonaColors.cardHigh,
              border: i < results.length
                  ? null
                  : Border.all(color: i == results.length ? SuonaColors.accent : SuonaColors.line, width: i == results.length ? 2.5 : 1),
            ),
          ),
      ],
    );
  }
}

/// „Combo ×2“ im Belohnungs-Verlauf.
class ComboBadge extends StatelessWidget {
  const ComboBadge(this.multiplier, {super.key});
  final int multiplier;

  @override
  Widget build(BuildContext context) {
    final small = context.compact;
    return Container(
      height: small ? 32 : 40,
      padding: EdgeInsets.symmetric(horizontal: small ? 10 : 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradientOf(SuonaColors.sun, horizontal: true),
        borderRadius: BorderRadius.circular(999),
        boxShadow: glowOf(SuonaColors.sun, strength: 0.3, blur: 18),
      ),
      child: Text(small ? '×$multiplier' : 'Combo ×$multiplier', style: display(small ? 14 : 17, color: Colors.white)),
    );
  }
}

/// Zeitbalken: Türkis → Blau, gegen Ende im Belohnungs-Verlauf als Warnung.
class TimeBar extends StatelessWidget {
  const TimeBar({super.key, required this.timer});
  final Animation<double> timer;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: timer,
      builder: (context, _) {
        final left = 1 - timer.value;
        return GradientBar(value: left, height: 10, colors: left < 0.25 ? SuonaColors.sun : SuonaColors.sky);
      },
    );
  }
}

/// Stimmung des Publikums im Abenteuer, daneben die Pedale.
class CrowdBar extends StatelessWidget {
  const CrowdBar({super.key, required this.mood, this.pedals = const []});
  final double mood;
  final List<Widget> pedals;

  @override
  Widget build(BuildContext context) {
    final good = mood > 0.55, ok = mood > 0.25;
    final small = context.compact;
    final colors = good ? SuonaColors.mint : (ok ? SuonaColors.sun : [SuonaColors.wrong, SuonaColors.rose]);
    return Row(
      children: [
        GradientTint(
          colors: colors,
          child: Icon(
            good
                ? Icons.sentiment_very_satisfied_rounded
                : (ok ? Icons.sentiment_neutral_rounded : Icons.sentiment_very_dissatisfied_rounded),
            size: small ? 24 : 32,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 8),
        if (!small) ...[Text(tr('Publikum', 'Crowd'), style: display(17)), const SizedBox(width: 12)],
        Expanded(
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: mood),
            duration: const Duration(milliseconds: 350),
            builder: (context, v, _) => GradientBar(value: v, height: small ? 8 : 12, colors: colors),
          ),
        ),
        for (final p in pedals) ...[SizedBox(width: small ? 6 : 10), p],
      ],
    );
  }
}

/// Weisses Notenblatt (in beiden Modi), leicht abgehoben.
class PaperCard extends StatelessWidget {
  const PaperCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final small = context.compact;
    return Container(
      decoration: BoxDecoration(
        color: SuonaColors.paper,
        borderRadius: BorderRadius.circular(small ? 18 : 28),
        border: Border.all(color: SuonaColors.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: SuonaColors.isDark ? 0.5 : 0.08),
            blurRadius: SuonaColors.isDark ? 50 : 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: padding ?? (small ? const EdgeInsets.fromLTRB(10, 4, 10, 4) : const EdgeInsets.fromLTRB(20, 8, 20, 8)),
      child: child,
    );
  }
}

/// Fläche für Griffbrett und Griffbild.
class BoardCard extends StatelessWidget {
  const BoardCard({super.key, required this.child, this.maxWidth = 1160});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SuonaCard(
          radius: context.compact ? 18 : 24,
          padding: context.compact ? const EdgeInsets.fromLTRB(6, 6, 8, 2) : const EdgeInsets.fromLTRB(10, 12, 14, 6),
          child: child,
        ),
      ),
    );
  }
}
