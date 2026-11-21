import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/music/chords.dart';
import '../../core/music/note_names.dart';
import '../../core/suona_state.dart';

/// Akkord-Lehrplan ansehen oder bearbeiten. Pro Schritt: Titel, wie viele
/// Saiten das Griffbild zeigt und welche Akkorde neu dazukommen. Eingebaute
/// Lehrpläne sind nur zum Ansehen (und Kopieren).
class ChordCurriculumEditor extends StatefulWidget {
  const ChordCurriculumEditor({super.key, required this.curriculum});
  final ChordCurriculum curriculum;

  @override
  State<ChordCurriculumEditor> createState() => _ChordCurriculumEditorState();
}

class _Step {
  _Step(String title, List<String> chords, this.strings) : title = TextEditingController(text: title), chords = [...chords];
  final TextEditingController title;
  final List<String> chords;
  int strings;
}

class _ChordCurriculumEditorState extends State<ChordCurriculumEditor> {
  late final TextEditingController _name;
  late final List<_Step> _steps;
  bool _dirty = false;

  bool get _readOnly => widget.curriculum.builtIn;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.curriculum.name);
    _steps = [for (final s in widget.curriculum.steps) _Step(s.title, s.chords, s.strings)];
  }

  @override
  void dispose() {
    _name.dispose();
    for (final s in _steps) {
      s.title.dispose();
    }
    super.dispose();
  }

  ChordCurriculum _build() => widget.curriculum.copyWith(
    name: _name.text.trim(),
    steps: [
      for (var i = 0; i < _steps.length; i++)
        ChordStep(
          title: _steps[i].title.text.trim().isEmpty ? '${tr('Schritt', 'Step')} ${i + 1}' : _steps[i].title.text.trim(),
          chords: _steps[i].chords,
          strings: _steps[i].strings,
        ),
    ],
  );

  String? get _problem {
    if (_name.text.trim().isEmpty) return tr('Bitte gib dem Lehrplan einen Namen.', 'Please name the curriculum.');
    if (_steps.isEmpty) return tr('Es braucht mindestens einen Schritt.', 'At least one step is needed.');
    if (_steps.first.chords.length < 2) {
      return tr(
        'Der erste Schritt braucht mindestens zwei Akkorde (sonst gibt es nichts zu wählen).',
        'The first step needs at least two chords (otherwise there is nothing to choose).',
      );
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _problem;
    if (problem != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    await SuonaScope.read(context).saveChordCurriculum(_build());
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _copy() async {
    final state = SuonaScope.read(context);
    final copy = widget.curriculum.copyWith(
      id: const Uuid().v4(),
      name: tr('${widget.curriculum.name} (Kopie)', '${widget.curriculum.name} (copy)'),
      builtIn: false,
    );
    await state.saveChordCurriculum(copy);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ChordCurriculumEditor(curriculum: copy)),
    );
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
              TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Weiter bearbeiten', 'Keep editing'))),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('Verwerfen', 'Discard'))),
            ],
          ),
        );
        if (leave == true && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_readOnly ? widget.curriculum.name : tr('Akkord-Lehrplan bearbeiten', 'Edit chord curriculum')),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _readOnly
                  ? FilledButton.tonalIcon(
                      onPressed: _copy,
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(tr('Als eigenen kopieren', 'Copy to edit')),
                    )
                  : FilledButton.icon(
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
                  labelText: tr('Name des Akkord-Lehrplans', 'Chord curriculum name'),
                  hintText: tr('z. B. Akkorde Play Guitar Junior', 'e.g. My chord plan'),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              tr(
                'Pro Schritt wählst du die neuen Akkorde und wie viele Saiten das Griffbild zeigt (3 = g, h, e). Ein Akkord darf später mit mehr Saiten nochmals vorkommen. Die Schritte werden auf die 8 Etappen der Akkord-Tour verteilt.',
                'For each step, pick the new chords and how many strings the chord chart shows (3 = G, B, E). A chord may come back later with more strings. Steps are spread over the 8 stops of the chord tour.',
              ),
              style: TextStyle(color: SuonaColors.muted),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < _steps.length; i++) _stepCard(i, naming),
            if (!_readOnly)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _steps.add(_Step('', const [], _steps.isEmpty ? 3 : _steps.last.strings));
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
                  backgroundColor: SuonaColors.rose,
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
                            hintText: tr('Titel, z. B. „Erste Griffe“', 'Title, e.g. “First shapes”'),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Text(tr('Saiten:', 'Strings:'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                DropdownButton<int>(
                  value: step.strings,
                  items: [for (final n in const [3, 4, 5, 6]) DropdownMenuItem(value: n, child: Text('$n'))],
                  onChanged: _readOnly
                      ? null
                      : (v) => setState(() {
                          step.strings = v ?? step.strings;
                          _dirty = true;
                        }),
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
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in _readOnly ? step.chords.map(ChordLibrary.byId).nonNulls : ChordLibrary.all)
                  FilterChip(
                    label: Text(chordName(c, naming), style: const TextStyle(fontWeight: FontWeight.w700)),
                    tooltip: chordKind(c),
                    selected: step.chords.contains(c.id),
                    onSelected: _readOnly
                        ? null
                        : (on) => setState(() {
                            on ? step.chords.add(c.id) : step.chords.remove(c.id);
                            _dirty = true;
                          }),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
