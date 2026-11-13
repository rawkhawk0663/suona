import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/error_log.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../app/version.dart';
import '../../core/music/curriculum.dart';
import '../../core/music/note_names.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/stage.dart';
import 'curriculum_editor.dart';
import 'mic_test.dart';
import 'privacy.dart';
import 'update_section.dart';

/// Lehrerbereich: Profile verwalten, Lehrpläne, Einstellungen,
/// Mikrofon-Test und „Über Suona“.
class TeacherScreen extends StatelessWidget {
  const TeacherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tr('Lehrerbereich', 'Teacher area')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: display(18, weight: FontWeight.w700),
            tabs: [
              Tab(icon: const Icon(Icons.people_alt_rounded), text: tr('Profile', 'Profiles')),
              Tab(icon: const Icon(Icons.route_rounded), text: tr('Lehrpläne', 'Curricula')),
              Tab(icon: const Icon(Icons.tune_rounded), text: tr('Einstellungen', 'Settings')),
              Tab(icon: const Icon(Icons.mic_rounded), text: tr('Mikrofon-Test', 'Mic test')),
              Tab(icon: const Icon(Icons.info_outline_rounded), text: tr('Über Suona', 'About Suona')),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_ProfilesTab(), _CurriculaTab(), _SettingsTab(), MicTestPanel(), _AboutTab()],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- Profile

class _ProfilesTab extends StatelessWidget {
  const _ProfilesTab();

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    if (state.profiles.isEmpty) {
      return Center(
        child: Text(
          tr(
            'Noch keine Profile. Die Kinder legen sie auf dem Startbildschirm an.',
            'No profiles yet. Children create them on the start screen.',
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [for (final p in state.profiles) _ProfileCard(profile: p)],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final curriculum = state.curriculumOf(profile);
    final step = profile.step.clamp(0, curriculum.steps.length - 1);
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FaceBadge(profile.character, size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.nickname, style: theme.textTheme.headlineSmall),
                      Text(
                        tr(
                          '${profile.coins} Münzen · ${profile.roundsPlayed} Runden · ${profile.totalCorrect} Töne richtig · Streak ${profile.streak.currentDays(DateTime.now())} (Rekord ${profile.streak.best})',
                          '${profile.coins} coins · ${profile.roundsPlayed} rounds · ${profile.totalCorrect} notes right · streak ${profile.streak.currentDays(DateTime.now())} (best ${profile.streak.best})',
                        ),
                        style: const TextStyle(color: SuonaColors.inkMuted),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: tr('Mehr', 'More'),
                  onSelected: (v) => _menu(context, v),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(tr('Umbenennen', 'Rename'))),
                    PopupMenuItem(value: 'character', child: Text(tr('Figur wechseln', 'Switch character'))),
                    PopupMenuItem(value: 'reset', child: Text(tr('Lernstand zurücksetzen', 'Reset progress'))),
                    PopupMenuItem(value: 'delete', child: Text(tr('Profil löschen', 'Delete profile'))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _LabeledDropdown<String>(
                  label: tr('Lehrplan', 'Curriculum'),
                  value: curriculum.id,
                  items: {for (final c in state.curricula) c.id: c.name},
                  onChanged: (id) {
                    profile
                      ..curriculumId = id
                      ..step = 0;
                    state.saveProfile(profile);
                  },
                ),
                _LabeledDropdown<int>(
                  label: tr('Ist bei', 'Currently at'),
                  value: step,
                  items: {
                    for (var i = 0; i < curriculum.steps.length; i++) i: '${i + 1}. ${curriculum.steps[i].title}',
                  },
                  onChanged: (s) {
                    profile.step = s;
                    state.saveProfile(profile);
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(tr('Lernstand', 'Progress'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            _Mastery(profile: profile, curriculum: curriculum, step: step, naming: state.naming),
          ],
        ),
      ),
    );
  }

  Future<void> _menu(BuildContext context, String action) async {
    final state = SuonaScope.read(context);
    switch (action) {
      case 'rename':
        final name = await _askText(context, tr('Neuer Spitzname', 'New nickname'), profile.nickname);
        if (name != null && name.trim().isNotEmpty) {
          profile.nickname = name.trim();
          await state.saveProfile(profile);
        }
      case 'character':
        profile.character = profile.character == Character.luna ? Character.fuzz : Character.luna;
        await state.saveProfile(profile);
      case 'reset':
        if (await _confirm(
          context,
          tr('Lernstand von ${profile.nickname} zurücksetzen?', 'Reset ${profile.nickname}’s progress?'),
          tr(
            'Die App vergisst, welche Töne schon sicher sitzen. Münzen und Streak bleiben.',
            'The app forgets which notes are already secure. Coins and streak stay.',
          ),
        )) {
          profile.stats.map.clear();
          await state.saveProfile(profile);
        }
      case 'delete':
        if (await _confirm(
          context,
          tr('Profil ${profile.nickname} löschen?', 'Delete profile ${profile.nickname}?'),
          tr(
            'Alles von diesem Profil wird von diesem Gerät gelöscht: Münzen, Streak und Lernstand. Das lässt sich nicht rückgängig machen.',
            'Everything of this profile is deleted from this device: coins, streak and progress. This can’t be undone.',
          ),
        )) {
          await state.deleteProfile(profile);
        }
    }
  }
}

/// Töne des Lehrplans bis zum aktuellen Schritt, gefärbt nach Lernstand.
class _Mastery extends StatelessWidget {
  const _Mastery({required this.profile, required this.curriculum, required this.step, required this.naming});
  final Profile profile;
  final Curriculum curriculum;
  final int step;
  final NoteNaming naming;

  @override
  Widget build(BuildContext context) {
    final notes = curriculum.notesUpTo(step);
    Color colorOf(int box, int seen) {
      if (seen == 0) return SuonaColors.line;
      if (box >= 4) return SuonaColors.ok;
      if (box >= 2) return SuonaColors.spot;
      return SuonaColors.coral;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final n in notes)
              Builder(
                builder: (_) {
                  final s = profile.stats.of(n);
                  return Tooltip(
                    message: tr('${s.correct} von ${s.seen} richtig', '${s.correct} of ${s.seen} right'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: colorOf(s.box, s.seen), borderRadius: BorderRadius.circular(10)),
                      child: Text(pitchNameWithOctave(n, naming), style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          tr(
            'Grün: sitzt · Gelb: wird sicherer · Rot: noch unsicher · Grau: noch nie gezeigt',
            'Green: secure · Yellow: getting there · Red: still unsure · Grey: not shown yet',
          ),
          style: const TextStyle(color: SuonaColors.inkMuted, fontSize: 13),
        ),
      ],
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  const _LabeledDropdown({required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
        DropdownButton<T>(
          value: items.containsKey(value) ? value : items.keys.first,
          items: [for (final e in items.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Lehrpläne

class _CurriculaTab extends StatelessWidget {
  const _CurriculaTab();

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          tr(
            'Ein Lehrplan legt fest, in welcher Reihenfolge die Töne kommen. Jedes Profil bekommt seinen eigenen Lehrplan (unter „Profile“).',
            'A curriculum sets the order in which notes are learned. Each profile gets its own curriculum (under “Profiles”).',
          ),
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 14),
        for (final c in state.curricula)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              leading: Icon(c.builtIn ? Icons.menu_book_rounded : Icons.edit_note_rounded, size: 32),
              title: Text(c.name, style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text(
                '${c.steps.length} ${tr('Schritte', 'steps')} · ${c.allNotes.length} ${tr('Töne', 'notes')}'
                '${c.builtIn ? ' · ${tr('eingebaut', 'built in')}' : ''}'
                ' · ${tr('genutzt von', 'used by')} ${state.profiles.where((p) => p.curriculumId == c.id).length}',
              ),
              onTap: () =>
                  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CurriculumEditor(curriculum: c))),
              trailing: c.builtIn
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      tooltip: tr('Löschen', 'Delete'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        if (await _confirm(
                          context,
                          tr('Lehrplan „${c.name}“ löschen?', 'Delete curriculum “${c.name}”?'),
                          tr(
                            'Profile mit diesem Lehrplan bekommen wieder guitarTALKS.',
                            'Profiles using it switch back to guitarTALKS.',
                          ),
                        )) {
                          await state.deleteCurriculum(c);
                        }
                      },
                    ),
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () {
              final c = Curriculum(
                id: state.newCurriculumId(),
                name: '',
                steps: [CurriculumStep(title: tr('Erste Töne', 'First notes'), notes: const [])],
              );
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => CurriculumEditor(curriculum: c)));
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(tr('Neuer Lehrplan', 'New curriculum')),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Einstellungen

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final s = state.settings;
    final theme = Theme.of(context);
    Widget section(String title, String help, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 2),
          Text(help, style: const TextStyle(color: SuonaColors.inkMuted)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        section(
          tr('Notennamen', 'Note names'),
          tr(
            'Wie die Töne auf den Tasten und in den Rückmeldungen heissen.',
            'How notes are named on the buttons and in feedback.',
          ),
          SegmentedButton<NoteNaming>(
            segments: [
              ButtonSegment(value: NoteNaming.german, label: Text(tr('Deutsch (H, B, Fis)', 'German (H, B, Fis)'))),
              ButtonSegment(
                value: NoteNaming.international,
                label: Text(tr('International (B, B♭, F♯)', 'International (B, B♭, F♯)')),
              ),
            ],
            selected: {s.naming},
            onSelectionChanged: (v) => state.updateSettings((x) => x.naming = v.first),
          ),
        ),
        section(
          tr('Vorzeichen', 'Sharps and flats'),
          tr(
            'Welche Schreibweise vorkommt, sobald ein Lehrplan Vorzeichen enthält.',
            'Which spelling appears once a curriculum contains sharps or flats.',
          ),
          SegmentedButton<AccidentalStyle>(
            segments: [
              ButtonSegment(value: AccidentalStyle.sharps, label: Text(tr('Nur ♯', 'Only ♯'))),
              ButtonSegment(value: AccidentalStyle.flats, label: Text(tr('Nur ♭', 'Only ♭'))),
              ButtonSegment(value: AccidentalStyle.mixed, label: Text(tr('♯ und ♭', '♯ and ♭'))),
            ],
            selected: {s.accidentals},
            onSelectionChanged: (v) => state.updateSettings((x) => x.accidentals = v.first),
          ),
        ),
        section(
          tr('Ton', 'Sound'),
          tr('Gitarrentöne und Klänge im Spiel.', 'Guitar notes and sounds in the game.'),
          Switch(value: s.sound, onChanged: (v) => state.updateSettings((x) => x.sound = v)),
        ),
        section(
          'Sprache · Language',
          tr('Sprache der App.', 'Language of the app.'),
          SegmentedButton<AppLanguage?>(
            segments: [
              ButtonSegment(value: null, label: Text(tr('Wie das System', 'Like the system'))),
              for (final l in AppLanguage.values) ButtonSegment(value: l, label: Text(l.label)),
            ],
            selected: {s.language},
            onSelectionChanged: (v) => state.updateSettings((x) => x.language = v.first),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- Über Suona

class _AboutTab extends StatelessWidget {
  const _AboutTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Suona', style: display(44, color: SuonaColors.red)),
        Text('${tr('Version', 'Version')} $suonaVersion', style: theme.textTheme.titleMedium),
        const SizedBox(height: 18),
        Text(tr('Updates', 'Updates'), style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          tr(
            'Suona sucht nie von selbst im Internet. Nur dieser Knopf fragt bei GitHub nach einer neuen Version. Dabei wird nichts über die Kinder gesendet.',
            'Suona never goes online by itself. Only this button asks GitHub for a new version. Nothing about the children is sent.',
          ),
          style: const TextStyle(color: SuonaColors.inkMuted),
        ),
        const SizedBox(height: 10),
        const UpdateSection(),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            OutlinedButton.icon(
              onPressed: () => showPrivacyDialog(context),
              icon: const Icon(Icons.shield_outlined),
              label: Text(tr('Datenschutz', 'Privacy')),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  showLicensePage(context: context, applicationName: 'Suona', applicationVersion: suonaVersion),
              icon: const Icon(Icons.description_outlined),
              label: Text(tr('Lizenzen', 'Licences')),
            ),
            OutlinedButton.icon(
              onPressed: () => _showErrorLog(context),
              icon: const Icon(Icons.bug_report_outlined),
              label: Text(tr('Fehlerprotokoll', 'Error log')),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showErrorLog(BuildContext context) async {
    final text = await ErrorLog.read();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Fehlerprotokoll', 'Error log')),
        content: SizedBox(
          width: 700,
          height: 420,
          child: text.isEmpty
              ? Center(child: Text(tr('Keine Fehler aufgezeichnet.', 'No errors recorded.')))
              : SingleChildScrollView(child: SelectableText(text, style: const TextStyle(fontSize: 12))),
        ),
        actions: [
          if (text.isNotEmpty)
            TextButton(
              onPressed: () async {
                await ErrorLog.clear();
                if (c.mounted) Navigator.pop(c);
              },
              child: Text(tr('Leeren', 'Clear')),
            ),
          if (text.isNotEmpty)
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: text)),
              child: Text(tr('Kopieren', 'Copy')),
            ),
          FilledButton(onPressed: () => Navigator.pop(c), child: Text(tr('Schliessen', 'Close'))),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- Hilfen

Future<bool> _confirm(BuildContext context, String title, String text) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Abbrechen', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Ja', 'Yes'))),
      ],
    ),
  );
  return ok == true;
}

Future<String?> _askText(BuildContext context, String title, String initial) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(controller: ctrl, autofocus: true, maxLength: 16, onSubmitted: (v) => Navigator.pop(c, v)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Abbrechen', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(tr('Speichern', 'Save'))),
      ],
    ),
  ).whenComplete(ctrl.dispose);
}
