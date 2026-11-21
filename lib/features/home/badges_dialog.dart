import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/game/badges.dart';
import '../../core/profiles/profile.dart';
import '../../widgets/visuals.dart';

/// Alle Abzeichen: verdiente leuchten, die anderen zeigen, wie man sie bekommt.
Future<void> showBadges(BuildContext context, Profile p) {
  final badges = badgesOf(p);
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(tr('Deine Abzeichen', 'Your badges'), style: display(28)),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final b in badges)
                Container(
                  width: 196,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: SuonaColors.cardHigh,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: SuonaColors.line),
                  ),
                  child: Row(
                    children: [
                      b.earned
                          ? GradientIcon(Icons.military_tech_rounded, colors: SuonaColors.sun, size: 44, circle: true)
                          : Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: SuonaColors.card),
                              child: Icon(Icons.lock_outline_rounded, size: 22, color: SuonaColors.muted),
                            ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.name,
                              style: display(17, color: b.earned ? SuonaColors.ink : SuonaColors.muted),
                            ),
                            Text(b.help, style: body(13, color: SuonaColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        GradientButton(label: tr('Schliessen', 'Close'), height: 48, fontSize: 17, onPressed: () => Navigator.pop(c)),
      ],
    ),
  );
}
