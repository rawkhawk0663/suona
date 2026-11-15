import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/character/look.dart';
import '../../core/suona_state.dart';
import '../../widgets/stage.dart';

/// Neues Profil: Figur wählen und einen Spitznamen geben.
class NewProfileScreen extends StatefulWidget {
  const NewProfileScreen({super.key});

  @override
  State<NewProfileScreen> createState() => _NewProfileScreenState();
}

class _NewProfileScreenState extends State<NewProfileScreen> {
  Character? _character;
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ready => _character != null && _name.text.trim().isNotEmpty && !_busy;

  Future<void> _create() async {
    if (!_ready) return;
    setState(() => _busy = true);
    final p = await SuonaScope.read(context).addProfile(_name.text, _character!);
    if (mounted) Navigator.of(context).pop(p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StageBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 12,
                left: 12,
                child: StageIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: tr('Zurück', 'Back'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 70, 24, 90),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(
                      children: [
                        Text(
                          tr('Mit wem willst du rocken?', 'Who do you want to rock with?'),
                          textAlign: TextAlign.center,
                          style: display(34, color: SuonaColors.onStage),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            for (final c in Character.values)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: _CharacterChoice(
                                    character: c,
                                    selected: _character == c,
                                    onTap: () => setState(() => _character = c),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Text(
                          tr('Wie sollen wir dich nennen?', 'What should we call you?'),
                          style: display(24, color: SuonaColors.onStage, weight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _name,
                          maxLength: 16,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.words,
                          style: display(28, color: SuonaColors.ink),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _create(),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: SuonaColors.paper,
                            counterStyle: const TextStyle(color: SuonaColors.onStageMuted),
                            hintText: tr('Spitzname', 'Nickname'),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                        ),
                        Text(
                          tr(
                            'Ein Spitzname reicht. Bitte keinen ganzen echten Namen.',
                            'A nickname is enough. Please don’t use your full real name.',
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 15),
                        ),
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          onPressed: _ready ? _create : null,
                          icon: const Icon(Icons.play_arrow_rounded, size: 30),
                          label: Text(tr('Los geht’s!', 'Let’s go!')),
                          style: FilledButton.styleFrom(
                            backgroundColor: SuonaColors.spot,
                            foregroundColor: SuonaColors.ink,
                            disabledBackgroundColor: SuonaColors.stageFloor,
                            textStyle: display(26),
                            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CharacterChoice extends StatelessWidget {
  const _CharacterChoice({required this.character, required this.selected, required this.onTap});
  final Character character;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selected ? 1.04 : 1,
      duration: const Duration(milliseconds: 180),
      child: Material(
        color: selected ? SuonaColors.stageLine : SuonaColors.stageFloor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
          side: BorderSide(color: selected ? SuonaColors.spot : Colors.transparent, width: 4),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
            child: Column(
              children: [
                SizedBox(height: 230, child: CharacterView(CharacterLook.defaults(character))),
                const SizedBox(height: 6),
                Text(character.displayName, style: display(30, color: SuonaColors.spot)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
