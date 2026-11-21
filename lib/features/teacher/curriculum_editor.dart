import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/music/curriculum.dart';
import '../../core/music/guitar.dart';
import '../../core/music/note_names.dart';
import '../../core/music/pitch.dart';
import '../../core/suona_state.dart';
import '../../widgets/staff.dart';

/// Lehrplan ansehen oder bearbeiten. Eingebaute Lehrpläne sind nur zum
/// Ansehen (und Kopieren).
class CurriculumEditor extends StatefulWidget {
  const CurriculumEditor({super.key, required this.curriculum});
  final Curriculum curriculum;

  @override
  State<CurriculumEditor> createState() => _CurriculumEditorState();
}

class _EditableStep {
  _EditableStep(String title, List<Pitch> notes) : title = TextEditingController(text: title), notes = {...notes};
  final TextEditingController title;
  final Set<Pitch> notes;
}

class _CurriculumEditorState extends State<CurriculumEditor> {
  late final TextEditingController _name;
  late final List<_EditableStep> _steps;
  bool _dirty = false;

  bool get _readOnly => widget.curriculum.builtIn;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.curriculum.name);
    _steps = [for (final s in widget.curriculum.steps) _EditableStep(s.title, s.notes)];
  }

  @override
  void dispose() {
    _name.dispose();
    for (final s in _steps) {
      s.title.dispose();
    }
    super.dispose();
  }

  Curriculum _build() => widget.curriculum.copyWith(
    name: _name.text.trim(),
    steps: [
      for (var i = 0; i < _steps.length; i++)
        CurriculumStep(
          title: _steps[i].title.text.trim().isEmpty
              ? '${tr('Schritt', 'Step')} ${i + 1}'
              : _steps[i].title.text.trim(),
          notes: _steps[i].notes.toList()..sort(),
        ),
    ],
  );

  String? get _problem {
    if (_name.text.trim().isEmpty) return tr('Bitte gib dem Lehrplan einen Namen.', 'Please name the curriculum.');
    if (_steps.isEmpty) return tr('Es braucht mindestens einen Schritt.', 'At least one step is needed.');
    if (_steps.first.notes.isEmpty) {
      return tr('Der erste Schritt braucht mindestens einen Ton.', 'The first step needs at least one note.');
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _problem;
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    await SuonaScope.read(context).saveCurriculum(_build());
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _copy() async {
    final state = SuonaScope.read(context);
    final copy = widget.curriculum.copyWith(
      id: state.newCurriculumId(),
      name: tr('${widget.curriculum.name} (Kopie)', '${widget.curriculum.name} (copy)'),
      builtIn: false,
    );
    await state.saveCurriculum(copy);
    if (!mounted) return;
    await Navigator.of(context)
        .pushReplacement(MaterialPageRoute<void>(builder: (_) => CurriculumEditor(curriculum: copy)));
  }

  Set<Pitch> _earlierNotes(int index) => {for (var i = 0; i < index; i++) ..._steps[i].notes};

  Future<void> _pickNotes(int index) async {
    final result = await showDialog<Set<Pitch>>(
      context: context,
      builder: (_) => _NotePickerDialog(
        selected: _steps[index].notes,
        earlier: _earlierNotes(index),
        naming: SuonaScope.read(context).naming,
      ),
    );
    if (result != null) {
      setState(() {
        _steps[index].notes
          ..clear()
          ..addAll(result);
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final naming = SuonaScope.of(context).naming;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(tr('Änderungen verwerfen?', 'Discard changes?')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: Text(tr('Weiter bearbeiten', 'Keep editing')),
              ),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Verwerfen', 'Discard'))),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_readOnly ? widget.curriculum.name : tr('Lehrplan bearbeiten', 'Edit curriculum')),
          actions: [
            if (_readOnly)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.tonalIcon(
                  onPressed: _copy,
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(tr('Als eigenen kopieren', 'Copy to edit')),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(tr('Speichern', 'Save')),
                ),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
          children: [
            if (_readOnly)
              Text(
                '${widget.curriculum.description}\n${tr('Eingebaute Lehrpläne lassen sich nicht ändern. Mit „Als eigenen kopieren“ entsteht eine Kopie, die du anpassen kannst.', 'Built-in curricula can’t be changed. “Copy to edit” makes a copy you can adjust.')}',
                style: TextStyle(color: SuonaColors.muted, fontSize: 16),
              )
            else
              TextField(
                controller: _name,
                onChanged: (_) => _dirty = true,
                style: display(24, color: SuonaColors.ink, weight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: tr('Name des Lehrplans', 'Curriculum name'),
                  hintText: tr('z. B. Play Guitar Junior', 'e.g. My guitar method'),
                ),
              ),
            const SizedBox(height: 18),
            for (var i = 0; i < _steps.length; i++) _stepCard(i, naming),
            if (!_readOnly)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _steps.add(_EditableStep('', const []));
                    _dirty = true;
                  }),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(tr('Schritt hinzufügen', 'Add step')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stepCard(int i, NoteNaming naming) {
    final step = _steps[i];
    final notes = step.notes.toList()..sort();
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: SuonaColors.accent,
                  child: Text('${i + 1}', style: display(16, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _readOnly
                      ? Text(step.title.text, style: Theme.of(context).textTheme.titleLarge)
                      : TextField(
                          controller: step.title,
                          onChanged: (_) => _dirty = true,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: tr('Titel, z. B. „g-Saite“', 'Title, e.g. “G string”'),
                          ),
                        ),
                ),
                if (!_readOnly) ...[
                  IconButton(
                    tooltip: tr('Nach oben', 'Move up'),
                    onPressed: i == 0
                        ? null
                        : () => setState(() {
                            _steps.insert(i - 1, _steps.removeAt(i));
                            _dirty = true;
                          }),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                  IconButton(
                    tooltip: tr('Nach unten', 'Move down'),
                    onPressed: i == _steps.length - 1
                        ? null
                        : () => setState(() {
                            _steps.insert(i + 1, _steps.removeAt(i));
                            _dirty = true;
                          }),
                    icon: const Icon(Icons.arrow_downward_rounded),
                  ),
                  IconButton(
                    tooltip: tr('Schritt löschen', 'Delete step'),
                    onPressed: () => setState(() {
                      _steps.removeAt(i).title.dispose();
                      _dirty = true;
                    }),
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            if (notes.isNotEmpty && notes.length <= 8)
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 170.0 + 64 * notes.length,
                  height: 120,
                  child: StaffView(notes: [for (final n in notes) StaffNote(n)]),
                ),
              ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final n in notes) Chip(label: Text(pitchNameWithOctave(n, naming))),
                if (notes.isEmpty)
                  Text(tr('Noch keine Töne', 'No notes yet'), style: TextStyle(color: SuonaColors.muted)),
                if (!_readOnly)
                  ActionChip(
                    avatar: const Icon(Icons.edit_rounded, size: 18),
                    label: Text(tr('Töne wählen', 'Choose notes')),
                    onPressed: () => _pickNotes(i),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Töne für einen Schritt wählen: alle Töne von E bis e'' (12. Bund), nach Saiten geordnet.
class _NotePickerDialog extends StatefulWidget {
  const _NotePickerDialog({required this.selected, required this.earlier, required this.naming});
  final Set<Pitch> selected;
  final Set<Pitch> earlier;
  final NoteNaming naming;

  @override
  State<_NotePickerDialog> createState() => _NotePickerDialogState();
}

class _NotePickerDialogState extends State<_NotePickerDialog> {
  late final Set<Pitch> _sel = {...widget.selected};
  late bool _accidentals = widget.selected.any((p) => p.hasAccidental);

  @override
  Widget build(BuildContext context) {
    final names = widget.naming == NoteNaming.german ? Guitar.stringNamesGerman : Guitar.stringNamesInternational;
    // Pro Saite die Töne der 1. Lage (Bund 0–4), dann alles darüber.
    final rows = <(String, List<Pitch>)>[];
    for (var s = 6; s >= 1; s--) {
      final open = Guitar.openStrings[s - 1];
      final top = s == 1 ? open + 4 : Guitar.openStrings[s - 2] - 1;
      rows.add((
        tr('${names[s - 1]}-Saite', '${names[s - 1]} string'),
        Pitch.range(open, top, sharps: _accidentals, flats: _accidentals),
      ));
    }
    rows.add((
      tr('Höher (bis 12. Bund)', 'Higher (up to 12th fret)'),
      Pitch.range(Guitar.openStrings[0] + 5, Guitar.highest, sharps: _accidentals, flats: _accidentals),
    ));

    return AlertDialog(
      title: Text(tr('Töne wählen', 'Choose notes')),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tr('Töne mit Vorzeichen zeigen', 'Show sharps and flats')),
                value: _accidentals,
                onChanged: (v) => setState(() => _accidentals = v),
              ),
              Text(
                tr('Grau: schon in einem früheren Schritt.', 'Grey: already in an earlier step.'),
                style: TextStyle(color: SuonaColors.muted),
              ),
              const SizedBox(height: 8),
              for (final (label, pitches) in rows) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 4),
                  child: Text(label, style: Theme.of(context).textTheme.titleMedium),
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final p in pitches)
                      FilterChip(
                        label: Text(pitchNameWithOctave(p, widget.naming)),
                        selected: _sel.contains(p),
                        onSelected: widget.earlier.contains(p)
                            ? null
                            : (v) => setState(() => v ? _sel.add(p) : _sel.remove(p)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('Abbrechen', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(context, _sel), child: Text(tr('Übernehmen', 'Apply'))),
      ],
    );
  }
}
