import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/character/look.dart';
import '../../core/game/shop.dart';
import '../../core/suona_state.dart';
import '../../widgets/stage.dart';

/// Neues Profil: Figur und Startgitarre wählen und einen Spitznamen geben.
class NewProfileScreen extends StatefulWidget {
  const NewProfileScreen({super.key});

  @override
  State<NewProfileScreen> createState() => _NewProfileScreenState();
}

class _NewProfileScreenState extends State<NewProfileScreen> {
  Character? _character;

  /// Startgitarre: true = Konzertgitarre (akustisch), false = E-Gitarre.
  bool? _acoustic;
  final _name = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _ready => _character != null && _acoustic != null && _name.text.trim().isNotEmpty && !_busy;

  String _guitarFor(Character c, bool acoustic) =>
      acoustic ? Shop.starterAcoustic : CharacterLook.defaults(c).guitar;

  Future<void> _create() async {
    if (!_ready) return;
    setState(() => _busy = true);
    final p = await SuonaScope.read(
      context,
    ).addProfile(_name.text, _character!, guitar: _guitarFor(_character!, _acoustic!));
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
                                    look: CharacterLook.defaults(c).copyWith(
                                      guitar: _acoustic == null ? null : _guitarFor(c, _acoustic!),
                                    ),
                                    selected: _character == c,
                                    onTap: () => setState(() => _character = c),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_character != null) ...[
                          const SizedBox(height: 26),
                          Text(
                            tr('Welche Gitarre spielst du?', 'Which guitar do you play?'),
                            textAlign: TextAlign.center,
                            style: display(28, color: SuonaColors.onStage),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              for (final acoustic in const [false, true])
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: _GuitarChoice(
                                      look: CharacterLook.defaults(
                                        _character!,
                                      ).copyWith(guitar: _guitarFor(_character!, acoustic)),
                                      label: acoustic
                                          ? tr('Konzertgitarre', 'Classical guitar')
                                          : tr('E-Gitarre', 'Electric guitar'),
                                      selected: _acoustic == acoustic,
                                      onTap: () => setState(() => _acoustic = acoustic),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            tr(
                              'Im Shop gibt es später noch viele andere Gitarren.',
                              'There are lots more guitars in the shop later.',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 15),
                          ),
                        ],
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
  const _CharacterChoice({required this.look, required this.selected, required this.onTap});
  final CharacterLook look;
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
                SizedBox(height: 230, child: CharacterView(look)),
                const SizedBox(height: 6),
                Text(look.character.displayName, style: display(30, color: SuonaColors.spot)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Startgitarre: zeigt die gewählte Figur mit der Gitarre in der Hand.
class _GuitarChoice extends StatelessWidget {
  const _GuitarChoice({required this.look, required this.label, required this.selected, required this.onTap});
  final CharacterLook look;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? SuonaColors.stageLine : SuonaColors.stageFloor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: selected ? SuonaColors.spot : Colors.transparent, width: 4),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Column(
            children: [
              SizedBox(height: 150, child: CharacterView(look, guitar: true)),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: display(22, color: SuonaColors.spot)),
            ],
          ),
        ),
      ),
    );
  }
}
