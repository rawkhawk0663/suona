import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/updater.dart';

/// „Nach Updates suchen“ und – unter Windows – gleich installieren.
class UpdateSection extends StatefulWidget {
  const UpdateSection({super.key});

  @override
  State<UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<UpdateSection> {
  bool _busy = false;
  String? _message;
  UpdateInfo? _found;
  double? _progress;

  Future<void> _check() async {
    setState(() {
      _busy = true;
      _message = null;
      _found = null;
    });
    try {
      final u = await Updater.latest();
      if (!mounted) return;
      setState(() {
        if (u == null) {
          _message = tr('Noch keine Versionen zum Herunterladen gefunden.', 'No versions available for download yet.');
        } else if (Updater.isNewer(u)) {
          _found = u;
        } else {
          _message = tr('Du hast die neueste Version.', 'You have the latest version.');
        }
      });
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _message = tr('Keine Verbindung zu GitHub. Bist du online?', 'No connection to GitHub. Are you online?'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install(UpdateInfo u) async {
    if (!await Updater.canSelfInstall()) {
      await Updater.openPage(u);
      if (mounted) {
        setState(
          () => _message = tr(
            'Die Download-Seite ist im Browser geöffnet.',
            'The download page has opened in your browser.',
          ),
        );
      }
      return;
    }
    setState(() => _progress = 0);
    try {
      await Updater.installWindows(
        u,
        onProgress: (v) {
          if (mounted) setState(() => _progress = v);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _message = tr('Das Update ging nicht: $e', 'The update didn’t work: $e');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final u = _found;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (u == null)
          OutlinedButton.icon(
            onPressed: _busy ? null : _check,
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.system_update_alt),
            label: Text(tr('Nach Updates suchen', 'Check for updates')),
          )
        else ...[
          Text(
            tr('Neue Version ${u.tag} ist bereit.', 'New version ${u.tag} is ready.'),
            style: theme.textTheme.titleSmall,
          ),
          if (u.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                u.notes.split('\n').first,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 8),
          if (_progress != null) ...[
            LinearProgressIndicator(value: _progress),
            const SizedBox(height: 4),
            Text(
              _progress! < 1
                  ? tr('Wird heruntergeladen …', 'Downloading …')
                  : tr(
                      'Suona schliesst sich kurz und startet in der neuen Version neu …',
                      'Suona closes briefly and restarts in the new version …',
                    ),
              style: theme.textTheme.bodySmall,
            ),
          ] else
            FilledButton.icon(
              onPressed: () => Platform.isWindows ? _install(u) : Updater.openPage(u),
              icon: const Icon(Icons.download),
              label: Text(
                Platform.isWindows
                    ? tr('Jetzt installieren und neu starten', 'Install now and restart')
                    : tr('Herunterladen', 'Download'),
              ),
            ),
          if (!Platform.isWindows)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: SelectableText(u.page.toString(), style: theme.textTheme.bodySmall),
            ),
        ],
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_message!, style: theme.textTheme.bodySmall),
          ),
      ],
    );
  }
}
