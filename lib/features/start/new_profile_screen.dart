import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/character/look.dart';
import '../../core/game/shop.dart';
import '../../core/suona_state.dart';
import '../../widgets/visuals.dart';

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
      body: AppBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 12,
                left: 12,
                child: RoundIconButton(
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
                          style: display(32),
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
                            style: display(26),
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
                            style: body(15, color: SuonaColors.muted),
                          ),
                        ],
                        const SizedBox(height: 26),
                        Text(
                          tr('Wie sollen wir dich nennen?', 'What should we call you?'),
                          style: display(24),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _name,
                          maxLength: 16,
                          textAlign: TextAlign.center,
                          textCapitalization: TextCapitalization.words,
                          style: display(26),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _create(),
                          decoration: InputDecoration(
                            counterStyle: body(13, color: SuonaColors.muted),
                            hintText: tr('Spitzname', 'Nickname'),
                            hintStyle: display(26, color: SuonaColors.muted, weight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          tr(
                            'Ein Spitzname reicht. Bitte keinen ganzen echten Namen.',
                            'A nickname is enough. Please don’t use your full real name.',
                          ),
                          textAlign: TextAlign.center,
                          style: body(15, color: SuonaColors.muted),
                        ),
                        const SizedBox(height: 26),
                        GradientButton(
                          label: tr('Los geht’s!', 'Let’s go!'),
                          icon: Icons.play_arrow_rounded,
                          height: 64,
                          fontSize: 24,
                          onPressed: _ready ? _create : null,
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
    return ChoiceCard(
      selected: selected,
      onTap: onTap,
      radius: 26,
      padding: const EdgeInsets.fromLTRB(10, 16, 10, 14),
      child: Column(
        children: [
          SizedBox(height: 230, child: CharacterView(look)),
          const SizedBox(height: 8),
          Text(look.character.displayName, style: display(28)),
        ],
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
    return ChoiceCard(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
      child: Column(
        children: [
          SizedBox(height: 150, child: CharacterView(look, guitar: true)),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: display(20)),
        ],
      ),
    );
  }
}
