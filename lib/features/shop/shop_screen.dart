import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/audio/sounds.dart';
import '../../core/character/look.dart';
import '../../core/game/shop.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/stage.dart';

/// Shop und Aussehen: links die Figur (mit dem gerade anprobierten Teil),
/// rechts Farben und Shop-Teile. Bezahlt wird nur mit Spiel-Münzen.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, required this.profileId, this.startTab = 0});
  final String profileId;
  final int startTab;

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  /// Anprobiertes, noch nicht gekauftes Teil (nur Vorschau).
  ShopItem? _trying;

  /// Kauf muss einmal bestätigt werden (gegen Versehen).
  String? _confirming;
  Timer? _confirmTimer;

  @override
  void dispose() {
    _confirmTimer?.cancel();
    super.dispose();
  }

  Profile _profile(SuonaState s) => s.profiles.firstWhere((p) => p.id == widget.profileId);

  CharacterLook _preview(Profile p) {
    final t = _trying;
    if (t == null || t.slot == ShopSlot.pedal) return p.look;
    return p.look.wear(t.slot.name, t.id);
  }

  Future<void> _wear(SuonaState state, Profile p, ShopItem item, {bool off = false}) async {
    setState(() => _trying = null);
    p.look = p.look.wear(item.slot.name, off ? null : item.id);
    await state.saveProfile(p);
  }

  Future<void> _buy(SuonaState state, Profile p, ShopItem item) async {
    if (_confirming != item.id) {
      setState(() => _confirming = item.id);
      _confirmTimer?.cancel();
      _confirmTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _confirming = null);
      });
      return;
    }
    _confirmTimer?.cancel();
    if (!Shop.buy(p, item)) return;
    unawaited(Sounds.instance.coins());
    setState(() => _confirming = null);
    if (item.slot != ShopSlot.pedal) {
      await _wear(state, p, item);
    } else {
      await state.saveProfile(p);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('${item.name} gehört jetzt dir!', '${item.name} is yours now!'), style: display(20)),
        backgroundColor: SuonaColors.ok,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final p = _profile(state);
    final tabs = [
      (tr('Aussehen', 'Looks'), Icons.palette_rounded),
      for (final s in ShopSlot.values)
        (
          s.label,
          switch (s) {
            ShopSlot.hat => Icons.face_retouching_natural_rounded,
            ShopSlot.glasses => Icons.visibility_rounded,
            ShopSlot.vest => Icons.checkroom_rounded,
            ShopSlot.guitar => Icons.music_note_rounded,
            ShopSlot.pedal => Icons.bolt_rounded,
          },
        ),
    ];
    final preview = Column(
      children: [
        Expanded(child: CharacterView(_preview(p))),
        const SizedBox(height: 8),
        if (_trying != null && _trying!.slot != ShopSlot.pedal)
          Text(
            tr('Du probierst: ${_trying!.name}', 'Trying on: ${_trying!.name}'),
            style: display(20, color: SuonaColors.spot, weight: FontWeight.w700),
          ),
      ],
    );
    return DefaultTabController(
      length: tabs.length,
      initialIndex: widget.startTab,
      child: Scaffold(
        body: StageBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      StageIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: tr('Zurück', 'Back'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 14),
                      Text('Shop', style: display(40, color: SuonaColors.spot)),
                      const Spacer(),
                      CoinCount(p.coins, size: 30),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final content = Column(
                          children: [
                            TabBar(
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              labelColor: SuonaColors.ink,
                              unselectedLabelColor: SuonaColors.onStage,
                              labelStyle: display(18, weight: FontWeight.w700),
                              indicator: BoxDecoration(
                                color: SuonaColors.spot,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: Colors.transparent,
                              onTap: (_) => setState(() => _trying = null),
                              tabs: [
                                for (final (label, icon) in tabs)
                                  Tab(
                                    height: 48,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [Icon(icon, size: 22), const SizedBox(width: 6), Text(label)],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  _LooksTab(
                                    profile: p,
                                    onChange: (look) async {
                                      p.look = look;
                                      await state.saveProfile(p);
                                    },
                                  ),
                                  for (final s in ShopSlot.values) _itemsGrid(state, p, s),
                                ],
                              ),
                            ),
                          ],
                        );
                        if (c.maxWidth >= 820) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: c.maxWidth * 0.32, child: preview),
                              const SizedBox(width: 18),
                              Expanded(child: content),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            SizedBox(height: 220, child: preview),
                            const SizedBox(height: 10),
                            Expanded(child: content),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _itemsGrid(SuonaState state, Profile p, ShopSlot slot) {
    final items = Shop.inSlot(slot);
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 230,
        mainAxisExtent: 286,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        final owned = Shop.owns(p, item);
        final wearing = slot != ShopSlot.pedal && p.look.itemIn(slot.name) == item.id;
        final trying = _trying?.id == item.id;
        return _ItemCard(
          item: item,
          look: slot == ShopSlot.pedal ? null : p.look.wear(slot.name, item.id),
          face: slot == ShopSlot.hat || slot == ShopSlot.glasses,
          owned: owned,
          wearing: wearing,
          trying: trying,
          confirming: _confirming == item.id,
          canAfford: p.coins >= item.price,
          missing: item.price - p.coins,
          onTap: () => setState(() => _trying = trying ? null : item),
          onBuy: () => _buy(state, p, item),
          onWear: () => _wear(state, p, item),
          onTakeOff: slot == ShopSlot.guitar ? null : () => _wear(state, p, item, off: true),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.look,
    required this.face,
    required this.owned,
    required this.wearing,
    required this.trying,
    required this.confirming,
    required this.canAfford,
    required this.missing,
    required this.onTap,
    required this.onBuy,
    required this.onWear,
    required this.onTakeOff,
  });

  final ShopItem item;
  final CharacterLook? look;
  final bool face;
  final bool owned;
  final bool wearing;
  final bool trying;
  final bool confirming;
  final bool canAfford;
  final int missing;
  final VoidCallback onTap;
  final VoidCallback onBuy;
  final VoidCallback onWear;
  final VoidCallback? onTakeOff;

  @override
  Widget build(BuildContext context) {
    final pedalIcon = switch (item.id) {
      'pedal_shield' => Icons.shield_rounded,
      'pedal_capo' => Icons.pause_circle_rounded,
      _ => Icons.tune_rounded,
    };
    Widget action;
    if (item.slot == ShopSlot.pedal && owned) {
      action = _Pill(tr('Gehört dir', 'Yours'), SuonaColors.ok);
    } else if (wearing) {
      action = onTakeOff == null
          ? _Pill(tr('Trägst du', 'Wearing'), SuonaColors.ok)
          : _Button(tr('Ausziehen', 'Take off'), SuonaColors.stageLine, SuonaColors.onStage, onTakeOff);
    } else if (owned) {
      action = _Button(tr('Anziehen', 'Wear'), SuonaColors.teal, Colors.white, onWear);
    } else if (!canAfford) {
      action = _Pill(tr('Noch $missing Münzen', '$missing coins to go'), SuonaColors.stageLine);
    } else {
      action = _Button(
        confirming ? tr('Ja, kaufen!', 'Yes, buy!') : tr('Kaufen', 'Buy'),
        confirming ? SuonaColors.coral : SuonaColors.spot,
        SuonaColors.ink,
        onBuy,
        coins: confirming ? null : item.price,
      );
    }
    return Material(
      color: trying ? SuonaColors.stageLine : SuonaColors.stageFloor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: wearing ? SuonaColors.ok : (trying ? SuonaColors.spot : Colors.transparent), width: 3),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Column(
            children: [
              Expanded(
                child: look == null
                    ? Icon(pedalIcon, size: 90, color: SuonaColors.spot)
                    : CharacterView(look!, bust: face),
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: display(18, color: SuonaColors.onStage, weight: FontWeight.w700),
              ),
              if (item.help.isNotEmpty)
                Text(
                  item.help,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 12.5, height: 1.25),
                ),
              const SizedBox(height: 8),
              action,
            ],
          ),
        ),
      ),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button(this.label, this.bg, this.fg, this.onTap, {this.coins});
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;
  final int? coins;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: const EdgeInsets.symmetric(vertical: 10),
          textStyle: display(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            if (coins != null) ...[
              const SizedBox(width: 10),
              const CoinIcon(size: 18),
              const SizedBox(width: 4),
              Text('$coins'),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.color);
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: Text(
        label,
        style: display(17, color: Colors.white, weight: FontWeight.w700),
      ),
    );
  }
}

/// Farben frei wählen: Haut, Haare, Augen, Shirt.
class _LooksTab extends StatelessWidget {
  const _LooksTab({required this.profile, required this.onChange});
  final Profile profile;
  final ValueChanged<CharacterLook> onChange;

  @override
  Widget build(BuildContext context) {
    final look = profile.look;
    Widget row(String title, String group, List<Swatch> list, String current, CharacterLook Function(String) apply) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: display(22, color: SuonaColors.onStage, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final s in list)
                  Tooltip(
                    message: swatchName(group, s.key),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => onChange(apply(s.key)),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(s.argb),
                          border: Border.all(
                            color: s.key == current ? SuonaColors.spot : SuonaColors.stageLine,
                            width: s.key == current ? 5 : 3,
                          ),
                        ),
                        child: s.key == current ? const Icon(Icons.check_rounded, color: Colors.white, size: 28) : null,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 20, right: 8),
      children: [
        Text(
          tr('Farben kosten nichts. Probier aus!', 'Colours are free. Try them out!'),
          style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 16),
        ),
        const SizedBox(height: 12),
        row(tr('Haut', 'Skin'), 'skin', Palettes.skin, look.skin, (k) => look.copyWith(skin: k)),
        row(tr('Haare', 'Hair'), 'hair', Palettes.hair, look.hair, (k) => look.copyWith(hair: k)),
        row(tr('Augen', 'Eyes'), 'eyes', Palettes.eyes, look.eyes, (k) => look.copyWith(eyes: k)),
        row(tr('Shirt', 'Shirt'), 'shirt', Palettes.shirt, look.shirt, (k) => look.copyWith(shirt: k)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              final d = CharacterLook.defaults(look.character);
              onChange(look.copyWith(skin: d.skin, hair: d.hair, eyes: d.eyes, shirt: d.shirt));
            },
            icon: const Icon(Icons.restart_alt_rounded, color: SuonaColors.onStageMuted),
            label: Text(
              tr('Grundfarben', 'Original colours'),
              style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
