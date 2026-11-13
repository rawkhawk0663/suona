import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/game/arcade_settings.dart';
import '../../core/game/question.dart';
import '../../core/music/guitar.dart';
import '../../core/music/note_names.dart';
import '../../core/music/pitch.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/fretboard.dart';
import '../../widgets/stage.dart';
import '../quiz/quiz_screen.dart';
import '../teacher/teacher_gate.dart';

/// Arcade vorbereiten: Spielart, welche Töne (nach Lehrplan oder nach
/// Saiten und Bünden), Tempo. Vorlagen setzen alles mit einem Tipp.
class ArcadeSetupScreen extends StatefulWidget {
  const ArcadeSetupScreen({super.key, required this.profileId});
  final String profileId;

  @override
  State<ArcadeSetupScreen> createState() => _ArcadeSetupScreenState();
}

class _ArcadeSetupScreenState extends State<ArcadeSetupScreen> {
  /// Zuletzt gewählte Einstellungen pro Profil (solange die App läuft).
  static final _last = <String, ArcadeSettings>{};

  late ArcadeSettings _s = (_last[widget.profileId] ?? ArcadeSettings()).copy();

  void _set(void Function(ArcadeSettings s) change) => setState(() => change(_s));

  /// Notenvorrat nach den aktuellen Einstellungen.
  List<Pitch> _pool(SuonaState state, Profile profile) {
    final style = state.settings.accidentals;
    if (_s.byCurriculum) {
      final c = state.curriculumOf(profile);
      final step = (_s.upToStep ?? profile.step).clamp(0, c.steps.length - 1);
      return applyAccidentalStyle(c.notesUpTo(step), style);
    }
    return _s.range.pitches(
      sharps: _s.accidentals && style != AccidentalStyle.flats,
      flats: _s.accidentals && style != AccidentalStyle.sharps,
    );
  }

  void _start(SuonaState state, Profile profile, List<Pitch> pool) {
    _last[widget.profileId] = _s.copy();
    final c = state.curriculumOf(profile);
    final step = (_s.upToStep ?? profile.step).clamp(0, c.steps.length - 1);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => QuizScreen(
          profileId: profile.id,
          config: QuizConfig(
            mode: QuizMode.arcade,
            types: _s.answer.types,
            timeLimit: _s.speed.limit,
            pool: pool,
            focus: _s.byCurriculum
                ? applyAccidentalStyle(c.steps[step].notes, state.settings.accidentals).toSet()
                : const {},
            range: _s.byCurriculum ? null : _s.range,
            fixedString: _s.fixedString && _canFixString,
            recordKey: _s.answer.name,
          ),
        ),
      ),
    );
  }

  bool get _canFixString => _s.answer == ArcadeAnswer.fret || _s.answer == ArcadeAnswer.mixed;

  Future<void> _savePreset(SuonaState state) async {
    if (!await passTeacherGate(context) || !mounted) return;
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Als Vorlage speichern', 'Save as preset')),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 24,
          decoration: InputDecoration(hintText: tr('z. B. Hausaufgabe Mia', 'e.g. Homework Mia')),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('Abbrechen', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(tr('Speichern', 'Save'))),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.trim().isEmpty) return;
    await state.saveArcadePreset(name, _s);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('Vorlage „${name.trim()}“ gespeichert.', 'Preset “${name.trim()}” saved.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final profile = state.profiles.firstWhere((p) => p.id == widget.profileId);
    final pool = _pool(state, profile);
    final record = profile.arcadeBests[_s.answer.name] ?? 0;

    return Scaffold(
      body: StageBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 90),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 820),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Arcade',
                          textAlign: TextAlign.center,
                          style: display(54, color: SuonaColors.spot),
                        ),
                        Text(
                          record > 0
                              ? tr(
                                  'Dein Rekord bei „${_s.answer.label}“: $record Münzen',
                                  'Your best at “${_s.answer.label}”: $record coins',
                                )
                              : tr(
                                  'Noch kein Rekord bei „${_s.answer.label}“',
                                  'No record at “${_s.answer.label}” yet',
                                ),
                          textAlign: TextAlign.center,
                          style: display(20, color: SuonaColors.onStage, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 18),
                        _presets(state),
                        const SizedBox(height: 22),
                        _label(tr('Was willst du spielen?', 'What do you want to play?')),
                        const SizedBox(height: 8),
                        _answers(),
                        const SizedBox(height: 22),
                        _label(tr('Welche Töne?', 'Which notes?')),
                        const SizedBox(height: 8),
                        _source(state, profile, pool),
                        const SizedBox(height: 22),
                        _label(tr('Wie schnell?', 'How fast?')),
                        const SizedBox(height: 8),
                        _speeds(),
                        const SizedBox(height: 28),
                        Center(
                          child: FilledButton.icon(
                            onPressed: pool.isEmpty ? null : () => _start(state, profile, pool),
                            icon: const Icon(Icons.play_arrow_rounded, size: 34),
                            label: Text(tr('Los!', 'Go!')),
                            style: FilledButton.styleFrom(
                              backgroundColor: SuonaColors.spot,
                              foregroundColor: SuonaColors.ink,
                              disabledBackgroundColor: SuonaColors.stageFloor,
                              textStyle: display(30),
                              padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => _savePreset(state),
                            icon: const Icon(Icons.bookmark_add_outlined, color: SuonaColors.onStageMuted),
                            label: Text(
                              tr('Als Vorlage speichern (Lehrperson)', 'Save as preset (teacher)'),
                              style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 15),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                left: 12,
                child: StageIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: tr('Zurück', 'Back'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: display(24, color: SuonaColors.onStage, weight: FontWeight.w700),
  );

  Widget _presets(SuonaState state) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final p in state.arcadePresets)
          ActionChip(
            avatar: Icon(
              p.builtIn ? Icons.auto_awesome_rounded : Icons.bookmark_rounded,
              size: 18,
              color: SuonaColors.spot,
            ),
            label: Text(
              p.name,
              style: display(17, color: SuonaColors.onStage, weight: FontWeight.w700),
            ),
            backgroundColor: SuonaColors.stageFloor,
            side: const BorderSide(color: SuonaColors.stageLine),
            onPressed: () => setState(() => _s = p.applyTo(_s)),
          ),
      ],
    );
  }

  Widget _answers() {
    IconData icon(ArcadeAnswer a) => switch (a) {
      ArcadeAnswer.name => Icons.music_note_rounded,
      ArcadeAnswer.fret => Icons.touch_app_rounded,
      ArcadeAnswer.fretName => Icons.radio_button_checked_rounded,
      ArcadeAnswer.staff => Icons.edit_rounded,
      ArcadeAnswer.mixed => Icons.shuffle_rounded,
    };
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final a in ArcadeAnswer.values)
          SizedBox(
            width: 152,
            height: 124,
            child: _Choice(
              selected: _s.answer == a,
              color: SuonaColors.violet,
              onTap: () => _set((s) => s.answer = a),
              child: Column(
                children: [
                  Icon(icon(a), size: 32, color: SuonaColors.onStage),
                  const SizedBox(height: 2),
                  Text(
                    a.label,
                    textAlign: TextAlign.center,
                    style: display(18, color: SuonaColors.onStage),
                  ),
                  Text(
                    a.help,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _source(SuonaState state, Profile profile, List<Pitch> pool) {
    final c = state.curriculumOf(profile);
    final maxStep = c.steps.length - 1;
    final upTo = (_s.upToStep ?? profile.step).clamp(0, maxStep);
    final naming = state.naming;
    final names = naming == NoteNaming.german ? Guitar.stringNamesGerman : Guitar.stringNamesInternational;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: SuonaColors.stageFloor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<bool>(
            style: SegmentedButton.styleFrom(
              backgroundColor: SuonaColors.stage,
              foregroundColor: SuonaColors.onStage,
              selectedBackgroundColor: SuonaColors.spot,
              selectedForegroundColor: SuonaColors.ink,
              textStyle: display(17, weight: FontWeight.w700),
            ),
            segments: [
              ButtonSegment(value: true, label: Text(tr('Aus meinem Lehrplan', 'From my curriculum'))),
              ButtonSegment(value: false, label: Text(tr('Saiten und Bünde', 'Strings and frets'))),
            ],
            selected: {_s.byCurriculum},
            onSelectionChanged: (v) => _set((s) => s.byCurriculum = v.first),
          ),
          const SizedBox(height: 12),
          if (_s.byCurriculum) ...[
            Text(
              '${tr('Bis', 'Up to')} ${tr('Schritt', 'step')} ${upTo + 1}: ${c.steps[upTo].title}',
              style: display(22, color: SuonaColors.onStage, weight: FontWeight.w700),
            ),
            Text(
              tr('${pool.length} Töne aus „${c.name}“', '${pool.length} notes from “${c.name}”'),
              style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 15),
            ),
            if (maxStep > 0)
              Slider(
                value: upTo.toDouble(),
                min: 0,
                max: maxStep.toDouble(),
                divisions: maxStep,
                activeColor: SuonaColors.spot,
                inactiveColor: SuonaColors.stageLine,
                label: c.steps[upTo].title,
                onChanged: (v) => _set((s) => s.upToStep = v.round()),
              ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  tr('Saiten:', 'Strings:'),
                  style: display(19, color: SuonaColors.onStage, weight: FontWeight.w700),
                ),
                for (var string = 1; string <= 6; string++)
                  FilterChip(
                    label: Text(
                      names[string - 1],
                      style: display(
                        18,
                        color: _s.range.strings.contains(string) ? SuonaColors.ink : SuonaColors.onStage,
                      ),
                    ),
                    selected: _s.range.strings.contains(string),
                    showCheckmark: false,
                    selectedColor: SuonaColors.spot,
                    backgroundColor: SuonaColors.stageLine,
                    onSelected: (on) => _set((s) {
                      final next = {...s.range.strings};
                      on ? next.add(string) : next.remove(string);
                      if (next.isNotEmpty) {
                        s.range = FretRange(strings: next, minFret: s.range.minFret, maxFret: s.range.maxFret);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _s.range.minFret == _s.range.maxFret
                  ? tr('Nur Bund ${_s.range.minFret}', 'Only fret ${_s.range.minFret}')
                  : tr(
                      'Bund ${_s.range.minFret} bis ${_s.range.maxFret}',
                      'Frets ${_s.range.minFret} to ${_s.range.maxFret}',
                    ),
              style: display(19, color: SuonaColors.onStage, weight: FontWeight.w700),
            ),
            RangeSlider(
              values: RangeValues(_s.range.minFret.toDouble(), _s.range.maxFret.toDouble()),
              min: 0,
              max: Guitar.maxFret.toDouble(),
              divisions: Guitar.maxFret,
              activeColor: SuonaColors.spot,
              inactiveColor: SuonaColors.stageLine,
              labels: RangeLabels('${_s.range.minFret}', '${_s.range.maxFret}'),
              onChanged: (v) => _set(
                (s) => s.range = FretRange(strings: s.range.strings, minFret: v.start.round(), maxFret: v.end.round()),
              ),
            ),
            SizedBox(
              height: 170,
              child: Fretboard(
                naming: naming,
                lowStringOnTop: state.settings.lowStringOnTop,
                activeStrings: _s.range.strings,
                minFret: _s.range.minFret,
                maxFret: _s.range.maxFret,
              ),
            ),
            const SizedBox(height: 6),
            _switch(
              tr('Auch Töne mit ♯ und ♭', 'Include sharps and flats'),
              _s.accidentals,
              (v) => _set((s) => s.accidentals = v),
            ),
            Text(
              tr('${pool.length} Töne', '${pool.length} notes'),
              style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 15),
            ),
          ],
          if (_canFixString)
            _switch(
              tr('Saite vorgeben (bei „Wo liegt sie?“)', 'Tell me the string (for “Where is it?”)'),
              _s.fixedString,
              (v) => _set((s) => s.fixedString = v),
            ),
        ],
      ),
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        label,
        style: display(18, color: SuonaColors.onStage, weight: FontWeight.w700),
      ),
      value: value,
      activeThumbColor: SuonaColors.spot,
      onChanged: onChanged,
    );
  }

  Widget _speeds() {
    IconData icon(ArcadeSpeed s) => switch (s) {
      ArcadeSpeed.off => Icons.self_improvement_rounded,
      ArcadeSpeed.relaxed => Icons.directions_walk_rounded,
      ArcadeSpeed.fast => Icons.rocket_launch_rounded,
    };
    return Row(
      children: [
        for (final sp in ArcadeSpeed.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: _Choice(
                selected: _s.speed == sp,
                color: SuonaColors.violet,
                onTap: () => _set((s) => s.speed = sp),
                child: Column(
                  children: [
                    Icon(icon(sp), size: 34, color: SuonaColors.onStage),
                    const SizedBox(height: 4),
                    Text(
                      sp.label,
                      style: display(19, color: SuonaColors.onStage, weight: FontWeight.w700),
                    ),
                    if (sp.limit != null)
                      Text(
                        tr('${sp.limit!.inSeconds} s pro Ton', '${sp.limit!.inSeconds} s per note'),
                        style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.selected, required this.color, required this.onTap, required this.child});
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : SuonaColors.stageFloor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: selected ? SuonaColors.spot : Colors.transparent, width: 3),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6), child: child),
      ),
    );
  }
}
