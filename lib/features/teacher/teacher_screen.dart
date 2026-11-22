import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/error_log.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../app/version.dart';
import '../../core/game/adventure.dart';
import '../../core/game/chord_adventure.dart';
import '../../core/game/difficulty.dart';
import '../../core/game/note_stats.dart';
import '../../core/music/chords.dart';
import '../../core/game/question.dart';
import '../../core/music/curriculum.dart';
import '../../core/music/note_names.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/visuals.dart';
import 'chord_curriculum_editor.dart';
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
    // Handy quer: niedrigere Leiste, Reiter nur mit Text.
    final small = context.compact;
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: small ? 44 : null,
          title: Text(tr('Lehrerbereich', 'Teacher area')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: display(17),
            unselectedLabelStyle: display(17, weight: FontWeight.w600),
            tabs: [
              small ? Tab(text: tr('Profile', 'Profiles')) : Tab(icon: const Icon(Icons.people_alt_rounded), text: tr('Profile', 'Profiles')),
              small ? Tab(text: tr('Lehrpläne', 'Curricula')) : Tab(icon: const Icon(Icons.route_rounded), text: tr('Lehrpläne', 'Curricula')),
              small ? Tab(text: tr('Einstellungen', 'Settings')) : Tab(icon: const Icon(Icons.tune_rounded), text: tr('Einstellungen', 'Settings')),
              small ? Tab(text: tr('Mikrofon-Test', 'Mic test')) : Tab(icon: const Icon(Icons.mic_rounded), text: tr('Mikrofon-Test', 'Mic test')),
              small ? Tab(text: tr('Über Suona', 'About Suona')) : Tab(icon: const Icon(Icons.info_outline_rounded), text: tr('Über Suona', 'About Suona')),
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
                FaceBadge(profile.look, size: 58),
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
                        style: TextStyle(color: SuonaColors.muted),
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
                    PopupMenuItem(value: 'adventure', child: Text(tr('Abenteuer neu beginnen', 'Restart adventure'))),
                    PopupMenuItem(value: 'chordtour', child: Text(tr('Akkord-Tour neu beginnen', 'Restart chord tour'))),
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
                _LabeledDropdown<Difficulty>(
                  label: tr('Stufe', 'Level'),
                  value: profile.difficulty,
                  items: {for (final d in Difficulty.values) d: d.label},
                  onChanged: (d) {
                    profile.difficulty = d;
                    state.saveProfile(profile);
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              tr(
                'Stufe im Abenteuer: ${profile.difficulty.help} Gespeichert wird nur die Stufe, nicht das Alter.',
                'Adventure level: ${profile.difficulty.help} Only the level is stored, not the age.',
              ),
              style: TextStyle(color: SuonaColors.muted),
            ),
            const SizedBox(height: 14),
            _AdventureLine(profile: profile, curriculum: curriculum),
            const SizedBox(height: 12),
            Text(tr('Lernstand Noten lesen', 'Progress: reading notes'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            _Mastery(profile: profile, curriculum: curriculum, step: step, naming: state.naming),
            const SizedBox(height: 12),
            Text(tr('Lernstand Griffbrett', 'Progress: fretboard'), style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            _Mastery(
              profile: profile,
              curriculum: curriculum,
              step: step,
              naming: state.naming,
              prefix: NoteStatsPrefix.fretboard,
              legend: false,
            ),
            const Divider(height: 34),
            _ChordSection(profile: profile),
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
      case 'adventure':
        if (await _confirm(
          context,
          tr('Abenteuer von ${profile.nickname} neu beginnen?', 'Restart ${profile.nickname}’s adventure?'),
          tr(
            'Alle Sterne auf der Weltkarte dieses Lehrplans gehen verloren. Münzen und gekaufte Teile bleiben.',
            'All stars on the world map for this curriculum are lost. Coins and bought items stay.',
          ),
        )) {
          profile.adventure.remove(profile.curriculumId);
          await state.saveProfile(profile);
        }
      case 'chordtour':
        if (await _confirm(
          context,
          tr('Akkord-Tour von ${profile.nickname} neu beginnen?', 'Restart ${profile.nickname}’s chord tour?'),
          tr(
            'Alle Sterne der Akkord-Tour gehen verloren. Münzen und gekaufte Teile bleiben.',
            'All chord tour stars are lost. Coins and bought items stay.',
          ),
        )) {
          profile.chordAdventure.remove(profile.chordCurriculumId);
          await state.saveProfile(profile);
        }
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
  const _Mastery({
    required this.profile,
    required this.curriculum,
    required this.step,
    required this.naming,
    this.prefix = '',
    this.legend = true,
  });
  final Profile profile;
  final Curriculum curriculum;
  final int step;
  final NoteNaming naming;
  final String prefix;
  final bool legend;

  @override
  Widget build(BuildContext context) {
    final notes = curriculum.notesUpTo(step);
    Color colorOf(int box, int seen) {
      if (seen == 0) return SuonaColors.line;
      if (box >= 4) return SuonaColors.ok;
      if (box >= 2) return SuonaColors.gold;
      return SuonaColors.wrong;
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
                  final s = profile.stats.of(n, prefix: prefix);
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
        if (legend) const SizedBox(height: 6),
        if (legend)
          Text(
            tr(
              'Grün: sitzt · Gelb: wird sicherer · Rot: noch unsicher · Grau: noch nie gezeigt',
              'Green: secure · Yellow: getting there · Red: still unsure · Grey: not shown yet',
            ),
            style: TextStyle(color: SuonaColors.muted, fontSize: 13),
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
        const SizedBox(height: 32),
        Text(tr('Akkord-Lehrpläne', 'Chord curricula'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          tr(
            'In welcher Reihenfolge die Akkorde kommen und auf wie vielen Saiten. Jedes Profil bekommt seinen eigenen (unter „Profile“).',
            'The order in which chords come and on how many strings. Each profile gets its own (under “Profiles”).',
          ),
          style: TextStyle(color: SuonaColors.muted),
        ),
        const SizedBox(height: 8),
        for (final c in state.chordCurricula)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              leading: Icon(c.builtIn ? Icons.library_music_rounded : Icons.edit_note_rounded, size: 32),
              title: Text(c.name, style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text(
                '${c.steps.length} ${tr('Schritte', 'steps')} · ${c.steps.isEmpty ? 0 : c.chordsUpTo(c.steps.length - 1).length} ${tr('Akkorde', 'chords')}'
                '${c.builtIn ? ' · ${tr('eingebaut', 'built in')}' : ''}'
                ' · ${tr('genutzt von', 'used by')} ${state.profiles.where((p) => p.chordCurriculumId == c.id).length}',
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => ChordCurriculumEditor(curriculum: c)),
              ),
              trailing: c.builtIn
                  ? const Icon(Icons.chevron_right_rounded)
                  : IconButton(
                      tooltip: tr('Löschen', 'Delete'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        if (await _confirm(
                          context,
                          tr('Akkord-Lehrplan „${c.name}“ löschen?', 'Delete chord curriculum “${c.name}”?'),
                          tr(
                            'Profile mit diesem Akkord-Lehrplan bekommen wieder die Akkord-Tour.',
                            'Profiles using it switch back to the chord tour.',
                          ),
                        )) {
                          await state.deleteChordCurriculum(c);
                        }
                      },
                    ),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () {
              final c = ChordCurriculum(
                id: state.newCurriculumId(),
                name: '',
                steps: [ChordStep(title: tr('Erste Akkorde', 'First chords'), chords: const [], strings: 3)],
              );
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => ChordCurriculumEditor(curriculum: c)),
              );
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(tr('Neuer Akkord-Lehrplan', 'New chord curriculum')),
          ),
        ),
        const SizedBox(height: 32),
        Text(tr('Arcade-Vorlagen', 'Arcade presets'), style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          tr(
            'Eigene Vorlagen speicherst du in den Arcade-Einstellungen eines Profils („Als Vorlage speichern“). Sie stehen dann allen Profilen auf diesem Gerät zur Verfügung.',
            'Save your own presets in a profile’s arcade settings (“Save as preset”). They are then available to all profiles on this device.',
          ),
          style: TextStyle(color: SuonaColors.muted),
        ),
        const SizedBox(height: 8),
        if (state.customArcadePresets.isEmpty) Text(tr('Noch keine eigenen Vorlagen.', 'No presets of your own yet.')),
        for (final p in state.customArcadePresets)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.bookmark_rounded),
              title: Text(p.name, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(
                '${p.settings.answer.label} · ${p.settings.byCurriculum ? tr('nach Lehrplan', 'by curriculum') : tr('Bund ${p.settings.range.minFret}–${p.settings.range.maxFret}', 'frets ${p.settings.range.minFret}–${p.settings.range.maxFret}')} · ${p.settings.speed.label}',
              ),
              trailing: IconButton(
                tooltip: tr('Löschen', 'Delete'),
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  if (await _confirm(
                    context,
                    tr('Vorlage „${p.name}“ löschen?', 'Delete preset “${p.name}”?'),
                    tr(
                      'Die Spielstände bleiben, nur die Vorlage verschwindet.',
                      'Game progress stays, only the preset is removed.',
                    ),
                  )) {
                    await state.deleteArcadePreset(p);
                  }
                },
              ),
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
          Text(help, style: TextStyle(color: SuonaColors.muted)),
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
          tr('Griffbrett', 'Fretboard'),
          tr('Welche Saite oben liegt.', 'Which string is at the top.'),
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(tr('Hohe e-Saite oben (wie Tabulatur)', 'High E string on top (like tab)')),
              ),
              ButtonSegment(
                value: true,
                label: Text(tr('Tiefe E-Saite oben (Blick auf die Gitarre)', 'Low E string on top (looking down)')),
              ),
            ],
            selected: {s.lowStringOnTop},
            onSelectionChanged: (v) => state.updateSettings((x) => x.lowStringOnTop = v.first),
          ),
        ),
        section(
          tr('Ton', 'Sound'),
          tr('Gitarrentöne und Klänge im Spiel.', 'Guitar notes and sounds in the game.'),
          Switch(value: s.sound, onChanged: (v) => state.updateSettings((x) => x.sound = v)),
        ),
        section(
          tr('Darstellung', 'Appearance'),
          tr(
            'Dunkel ist Standard. Hell passt in sehr helle Räume.',
            'Dark is the default. Light suits very bright rooms.',
          ),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_rounded), label: Text(tr('Dunkel', 'Dark'))),
              ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_rounded), label: Text(tr('Hell', 'Light'))),
              ButtonSegment(
                value: ThemeMode.system,
                icon: const Icon(Icons.brightness_auto_rounded),
                label: Text(tr('Wie das Gerät', 'Like the device')),
              ),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) => state.updateSettings((x) => x.themeMode = v.first),
          ),
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
        Row(
          children: [
            const SuonaLogo(size: 64),
            const SizedBox(width: 16),
            Text('Suona', style: display(44)),
          ],
        ),
        Text('${tr('Version', 'Version')} $suonaVersion', style: theme.textTheme.titleMedium),
        const SizedBox(height: 18),
        Text(tr('Updates', 'Updates'), style: theme.textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          tr(
            'Suona sucht nie von selbst im Internet. Nur dieser Knopf fragt bei GitHub nach einer neuen Version. Dabei wird nichts über die Kinder gesendet.',
            'Suona never goes online by itself. Only this button asks GitHub for a new version. Nothing about the children is sent.',
          ),
          style: TextStyle(color: SuonaColors.muted),
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

/// Wie weit ein Kind im Abenteuer ist, und ob es auf den Unterricht wartet.
/// Akkorde eines Profils: Akkord-Lehrplan, wie weit, Akkord-Tour, Lernstand.
class _ChordSection extends StatelessWidget {
  const _ChordSection({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final theme = Theme.of(context);
    final c = state.chordCurriculumOf(profile);
    final step = c.steps.isEmpty ? 0 : profile.chordStep.clamp(0, c.steps.length - 1);
    final chords = c.steps.isEmpty ? <Chord>[] : c.chordsUpTo(step);
    Color colorOf(NoteStat s) {
      if (s.seen == 0) return SuonaColors.line;
      if (s.box >= 4) return SuonaColors.ok;
      if (s.box >= 2) return SuonaColors.gold;
      return SuonaColors.wrong;
    }

    Widget row(String title, String prefix) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 120, child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final ch in chords)
                Builder(
                  builder: (_) {
                    final st = profile.stats.ofKey('$prefix${ch.id}');
                    return Tooltip(
                      message: tr('${st.correct} von ${st.seen} richtig', '${st.correct} of ${st.seen} right'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: colorOf(st), borderRadius: BorderRadius.circular(10)),
                        child: Text(chordName(ch, state.naming), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ],
    );

    var done = 0;
    for (var s = 0; s < ChordTour.stationCount; s++) {
      if (ChordTour.stationDone(profile, c.id, s)) done++;
    }
    final next = done < ChordTour.stationCount ? done : null;
    final waits = next != null && ChordTour.lockOf(profile, c, next) == StationLock.teacher;
    final (from, _) = next == null ? (0, 0) : Adventure.stepsOf(next, c.steps.length);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tr('Akkorde', 'Chords'), style: theme.textTheme.titleLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _LabeledDropdown<String>(
              label: tr('Akkord-Lehrplan', 'Chord curriculum'),
              value: c.id,
              items: {for (final x in state.chordCurricula) x.id: x.name},
              onChanged: (id) {
                profile
                  ..chordCurriculumId = id
                  ..chordStep = 0;
                state.saveProfile(profile);
              },
            ),
            if (c.steps.isNotEmpty)
              _LabeledDropdown<int>(
                label: tr('Ist bei', 'Currently at'),
                value: step,
                items: {for (var i = 0; i < c.steps.length; i++) i: '${i + 1}. ${c.steps[i].title}'},
                onChanged: (s) {
                  profile.chordStep = s;
                  state.saveProfile(profile);
                },
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (c.steps.isNotEmpty)
          Row(
            children: [
              Icon(Icons.airport_shuttle_rounded, color: SuonaColors.muted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  next == null
                      ? tr('Akkord-Tour: alle 8 Etappen geschafft!', 'Chord tour: all 8 stops done!')
                      : waits
                      ? tr(
                          'Akkord-Tour: $done von 8 Etappen. Wartet auf Schritt ${from + 1} („${c.steps[from].title}“), damit „${ChordTour.stationName(next)}“ aufgeht.',
                          'Chord tour: $done of 8 stops. Waiting for step ${from + 1} (“${c.steps[from].title}”) to open “${ChordTour.stationName(next)}”.',
                        )
                      : tr(
                          'Akkord-Tour: $done von 8 Etappen, jetzt in „${ChordTour.stationName(next)}“.',
                          'Chord tour: $done of 8 stops, now at “${ChordTour.stationName(next)}”.',
                        ),
                  style: TextStyle(
                    color: waits ? SuonaColors.accent : SuonaColors.muted,
                    fontWeight: waits ? FontWeight.w700 : null,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 10),
        row(tr('Erkennen', 'Recognise'), ChordTask.name.statsPrefix),
        const SizedBox(height: 8),
        row(tr('Griff bauen', 'Build shape'), ChordTask.build.statsPrefix),
      ],
    );
  }
}

class _AdventureLine extends StatelessWidget {
  const _AdventureLine({required this.profile, required this.curriculum});
  final Profile profile;
  final Curriculum curriculum;

  @override
  Widget build(BuildContext context) {
    final p = profile, c = curriculum;
    var done = 0;
    for (var s = 0; s < Adventure.stationCount; s++) {
      if (Adventure.stationDone(p, c.id, s)) done++;
    }
    final next = done < Adventure.stationCount ? done : null;
    final waits = next != null && Adventure.lockOf(p, c, next) == StationLock.teacher;
    final (from, _) = next == null ? (0, 0) : Adventure.stepsOf(next, c.steps.length);
    return Row(
      children: [
        Icon(Icons.map_rounded, color: SuonaColors.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            next == null
                ? tr('Abenteuer: alle 8 Stationen geschafft!', 'Adventure: all 8 stations done!')
                : waits
                ? tr(
                    'Abenteuer: $done von 8 Stationen. Wartet auf Schritt ${from + 1} („${c.steps[from].title}“), damit „${Adventure.stationName(next)}“ aufgeht.',
                    'Adventure: $done of 8 stations. Waiting for step ${from + 1} (“${c.steps[from].title}”) to open “${Adventure.stationName(next)}”.',
                  )
                : tr(
                    'Abenteuer: $done von 8 Stationen, jetzt in „${Adventure.stationName(next)}“.',
                    'Adventure: $done of 8 stations, now at “${Adventure.stationName(next)}”.',
                  ),
            style: TextStyle(
              color: waits ? SuonaColors.accent : SuonaColors.muted,
              fontWeight: waits ? FontWeight.w700 : null,
            ),
          ),
        ),
      ],
    );
  }
}
