import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/game/badges.dart';
import '../../core/profiles/profile.dart';

/// Alle Abzeichen: verdiente leuchten, die anderen zeigen, wie man sie bekommt.
Future<void> showBadges(BuildContext context, Profile p) {
  final badges = badgesOf(p);
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      backgroundColor: SuonaColors.stage,
      title: Text(tr('Deine Abzeichen', 'Your badges'), style: display(30, color: SuonaColors.spot)),
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
                    color: b.earned ? SuonaColors.stageLine : SuonaColors.stageFloor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: b.earned ? SuonaColors.spot : Colors.transparent, width: 2),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        b.earned ? Icons.military_tech_rounded : Icons.lock_outline_rounded,
                        size: 38,
                        color: b.earned ? SuonaColors.spot : SuonaColors.onStageMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              b.name,
                              style: display(17, color: b.earned ? SuonaColors.onStage : SuonaColors.onStageMuted),
                            ),
                            Text(b.help, style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 13)),
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
        FilledButton(
          onPressed: () => Navigator.pop(c),
          style: FilledButton.styleFrom(backgroundColor: SuonaColors.spot, foregroundColor: SuonaColors.ink),
          child: Text(tr('Schliessen', 'Close')),
        ),
      ],
    ),
  );
}
