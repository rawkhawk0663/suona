import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/audio/mic_listener.dart';
import '../../core/audio/pitch_detector.dart';
import '../../core/music/guitar.dart';
import '../../core/music/note_names.dart';
import '../../core/music/pitch.dart';
import '../../core/suona_state.dart';

/// Mikrofon-Test: Erkennt das Gerät die Gitarre? Grundlage für den Modus
/// „Echt spielen“ (Paket 4). Der Ton wird nur ausgewertet, nie gespeichert.
class MicTestPanel extends StatefulWidget {
  const MicTestPanel({super.key});

  @override
  State<MicTestPanel> createState() => _MicTestPanelState();
}

class _MicTestPanelState extends State<MicTestPanel> {
  final _mic = MicListener();
  StreamSubscription<PitchReading>? _sub;
  PitchReading _reading = PitchReading.silent;
  PitchReading? _lastPitch;
  String? _error;
  bool _starting = false;

  @override
  void dispose() {
    _sub?.cancel();
    _mic.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_mic.running) {
      await _sub?.cancel();
      await _mic.stop();
      setState(() {
        _reading = PitchReading.silent;
      });
      return;
    }
    setState(() {
      _starting = true;
      _error = null;
    });
    final err = await _mic.start();
    if (!mounted) return;
    setState(() {
      _starting = false;
      _error = err;
    });
    if (err == null) {
      _sub = _mic.readings.listen((r) {
        if (!mounted) return;
        setState(() {
          _reading = r;
          if (r.hasPitch && r.clarity > 0.8) _lastPitch = r;
        });
      });
    }
  }

  /// Name des nächsten Halbtons, mit Kreuz geschrieben.
  String _nameOf(int midi, NoteNaming naming) {
    final p = Pitch.range(midi, midi, sharps: true).first;
    return pitchNameWithOctave(p, naming);
  }

  @override
  Widget build(BuildContext context) {
    final naming = SuonaScope.of(context).naming;
    final theme = Theme.of(context);
    final shown = _lastPitch;
    final inRange = shown != null && shown.midi >= Guitar.lowest - 2 && shown.midi <= Guitar.highest + 5;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(tr('Mikrofon-Test', 'Microphone test'), style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          tr(
            'Hier prüfen wir, ob dieses Gerät die Gitarre gut hört. Das ist die Grundlage für den späteren Modus „Echt spielen“. '
                'Spiel einzelne Töne, z. B. die leeren Saiten. Der Ton wird nur ausgewertet und nie aufgenommen oder gespeichert.',
            'This checks whether this device hears the guitar well. It is the basis for the later “Play for real” mode. '
                'Play single notes, e.g. the open strings. The sound is only analysed, never recorded or stored.',
          ),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            FilledButton.icon(
              onPressed: _starting ? null : _toggle,
              icon: Icon(_mic.running ? Icons.mic_off_rounded : Icons.mic_rounded),
              label: Text(_mic.running ? tr('Mikrofon aus', 'Microphone off') : tr('Mikrofon ein', 'Microphone on')),
            ),
            const SizedBox(width: 16),
            if (_mic.running)
              Row(
                children: [
                  Icon(Icons.fiber_manual_record_rounded, color: SuonaColors.accent, size: 16),
                  const SizedBox(width: 4),
                  Text(tr('Mikrofon ist an', 'Microphone is on')),
                ],
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error == 'permission'
                ? tr(
                    'Suona darf das Mikrofon nicht benutzen. Bitte in den Einstellungen des Geräts erlauben.',
                    'Suona may not use the microphone. Please allow it in the device settings.',
                  )
                : tr(
                    'Das Mikrofon liess sich nicht starten. Unter Windows: Einstellungen → Datenschutz → Mikrofon → Desktop-Apps erlauben. ($_error)',
                    'The microphone could not be started. On Windows: Settings → Privacy → Microphone → allow desktop apps. ($_error)',
                  ),
            style: TextStyle(color: SuonaColors.wrong),
          ),
        ],
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Text(
                  shown == null ? '–' : _nameOf(shown.midi, naming),
                  style: display(84, color: inRange ? SuonaColors.ink : SuonaColors.muted),
                ),
                Text(
                  shown == null
                      ? tr('Noch kein Ton erkannt', 'No note detected yet')
                      : '${shown.frequency.toStringAsFixed(1)} Hz · ${shown.cents >= 0 ? '+' : ''}${shown.cents.round()} Cent',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 18),
                _CentsMeter(cents: shown?.cents ?? 0, active: shown != null),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Text(tr('Lautstärke', 'Level')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: (_reading.level * 6).clamp(0.0, 1.0),
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: Text(
                        _reading.hasPitch
                            ? tr(
                                'Klarheit ${(100 * _reading.clarity).round()} %',
                                'Clarity ${(100 * _reading.clarity).round()} %',
                              )
                            : '',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          tr(
            'Leere Saiten zum Vergleich: E (82 Hz), A (110 Hz), d (147 Hz), g (196 Hz), h (247 Hz), e\' (330 Hz).',
            'Open strings for comparison: E2 (82 Hz), A2 (110 Hz), D3 (147 Hz), G3 (196 Hz), B3 (247 Hz), E4 (330 Hz).',
          ),
          style: theme.textTheme.bodyMedium?.copyWith(color: SuonaColors.muted),
        ),
      ],
    );
  }
}

/// Anzeige wie bei einem Stimmgerät: Mitte = sauber.
class _CentsMeter extends StatelessWidget {
  const _CentsMeter({required this.cents, required this.active});
  final double cents;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final x = w / 2 + (cents.clamp(-50, 50) / 50) * (w / 2 - 10);
          final ok = cents.abs() < 10;
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 18,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(color: SuonaColors.line, borderRadius: BorderRadius.circular(5)),
                ),
              ),
              Positioned(
                left: w / 2 - w * 0.1,
                width: w * 0.2,
                top: 18,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: SuonaColors.ok.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              if (active)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 90),
                  left: x - 5,
                  top: 4,
                  child: Container(
                    width: 10,
                    height: 38,
                    decoration: BoxDecoration(
                      color: ok ? SuonaColors.ok : SuonaColors.accent,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
