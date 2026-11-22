import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import 'teacher_screen.dart';

/// Öffnet den Lehrerbereich hinter einer kleinen Sperre: eine
/// Rechenaufgabe, die jüngere Kinder noch nicht lösen (Eltern-Sperre).
Future<void> openTeacherArea(BuildContext context) async {
  final ok = await passTeacherGate(context);
  if (ok && context.mounted) {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TeacherScreen()));
  }
}

/// Nur die Sperre: true, wenn die Rechenaufgabe gelöst wurde. Für Dinge,
/// die nur Erwachsene tun sollen (z. B. eine Arcade-Vorlage speichern).
Future<bool> passTeacherGate(BuildContext context) async {
  final ok = await showDialog<bool>(context: context, builder: (_) => const _GateDialog());
  return ok == true;
}

class _GateDialog extends StatefulWidget {
  const _GateDialog();

  @override
  State<_GateDialog> createState() => _GateDialogState();
}

class _GateDialogState extends State<_GateDialog> {
  final _random = Random();
  late int _a, _b;
  String _input = '';
  bool _wrong = false;

  @override
  void initState() {
    super.initState();
    _newTask();
  }

  void _newTask() {
    _a = 6 + _random.nextInt(4); // 6..9
    _b = 12 + _random.nextInt(8); // 12..19
  }

  void _press(String d) {
    setState(() {
      _wrong = false;
      if (d == '⌫') {
        if (_input.isNotEmpty) _input = _input.substring(0, _input.length - 1);
      } else if (_input.length < 4) {
        _input += d;
      }
    });
    if (int.tryParse(_input) == _a * _b) {
      Navigator.of(context).pop(true);
    } else if (_input.length >= (_a * _b).toString().length) {
      Future<void>.delayed(const Duration(milliseconds: 250), () {
        if (!mounted) return;
        setState(() {
          _wrong = true;
          _input = '';
          _newTask();
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final small = MediaQuery.sizeOf(context).height < 520;
    final task = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr('Bitte rechne:', 'Please solve:'), style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 6),
        Text('$_a × $_b = ${_input.isEmpty ? '?' : _input}', style: display(small ? 30 : 38)),
        SizedBox(
          height: 22,
          child: _wrong
              ? Text(
                  tr('Nicht ganz. Neue Aufgabe.', 'Not quite. New task.'),
                  style: TextStyle(color: SuonaColors.wrong),
                )
              : null,
        ),
      ],
    );
    final keypad = GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      mainAxisSpacing: small ? 6 : 8,
      crossAxisSpacing: small ? 6 : 8,
      childAspectRatio: small ? 2.0 : 1.7,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'])
          d.isEmpty
              ? const SizedBox()
              : OutlinedButton(
                  onPressed: () => _press(d),
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(d, style: display(small ? 20 : 24)),
                ),
      ],
    );
    return AlertDialog(
      title: Text(tr('Für Lehrpersonen und Eltern', 'For teachers and parents')),
      titlePadding: small ? const EdgeInsets.fromLTRB(24, 16, 24, 0) : null,
      contentPadding: small ? const EdgeInsets.fromLTRB(24, 10, 24, 0) : null,
      insetPadding: small ? const EdgeInsets.symmetric(horizontal: 40, vertical: 12) : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      content: SizedBox(
        width: small ? 520 : 340,
        child: small
            // Handy quer: Aufgabe links, Zahlen rechts.
            ? Row(
                children: [
                  Expanded(child: task),
                  const SizedBox(width: 16),
                  SizedBox(width: 250, child: keypad),
                ],
              )
            : Column(mainAxisSize: MainAxisSize.min, children: [task, const SizedBox(height: 8), keypad]),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(tr('Abbrechen', 'Cancel')))],
    );
  }
}
