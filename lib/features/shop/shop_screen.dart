import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/audio/sounds.dart';
import '../../core/character/character_art.dart';
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

  /// Anprobiertes Set (alle Teile auf einmal, nur Vorschau).
  OutfitSet? _tryingSet;

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
    final set = _tryingSet;
    if (set != null) return withElectric(Shop.wearSet(p, set, all: true));
    final t = _trying;
    if (t == null || t.slot == ShopSlot.pedal) return p.look;
    final look = p.look.wear(t.slot.name, t.id);
    return t.slot == ShopSlot.amp ? withElectric(look) : look;
  }

  Future<void> _wear(SuonaState state, Profile p, ShopItem item, {bool off = false}) async {
    setState(() {
      _trying = null;
      _tryingSet = null;
    });
    p.look = p.look.wear(item.slot.name, off ? null : item.id);
    await state.saveProfile(p);
  }

  Future<void> _wearSet(SuonaState state, Profile p, OutfitSet set) async {
    setState(() {
      _trying = null;
      _tryingSet = null;
    });
    p.look = Shop.wearSet(p, set);
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
    if (item.slot != ShopSlot.pedal && _tryingSet == null) {
      await _wear(state, p, item);
    } else {
      await state.saveProfile(p);
    }
    if (!mounted) return;
    final set = Shop.setOf(item.id);
    final done = set != null && set.completeFor(p);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          done
              ? tr('Set „${set.name}“ komplett! Neues Abzeichen!', '“${set.name}” set complete! New badge!')
              : tr('${item.name} gehört jetzt dir!', '${item.name} is yours now!'),
          style: display(20),
        ),
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
      (tr('Sets', 'Sets'), Icons.collections_rounded),
      for (final s in ShopSlot.values)
        (
          s.label,
          switch (s) {
            ShopSlot.hat => Icons.face_retouching_natural_rounded,
            ShopSlot.glasses => Icons.visibility_rounded,
            ShopSlot.neck => Icons.diamond_rounded,
            ShopSlot.vest => Icons.checkroom_rounded,
            ShopSlot.guitar => Icons.music_note_rounded,
            ShopSlot.amp => Icons.speaker_rounded,
            ShopSlot.pedal => Icons.bolt_rounded,
          },
        ),
    ];
    final preview = Column(
      children: [
        Expanded(child: CharacterView(_preview(p))),
        const SizedBox(height: 8),
        if (_tryingSet != null || (_trying != null && _trying!.slot != ShopSlot.pedal))
          Text(
            _tryingSet != null
                ? tr('Du probierst: Set ${_tryingSet!.name}', 'Trying on: ${_tryingSet!.name} set')
                : tr('Du probierst: ${_trying!.name}', 'Trying on: ${_trying!.name}'),
            textAlign: TextAlign.center,
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
                              onTap: (_) => setState(() {
                                _trying = null;
                                _tryingSet = null;
                              }),
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
                                  _setsList(state, p),
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
    final ampHint = slot == ShopSlot.amp && CharacterArt.instance.isAcoustic(p.look.guitar);
    final grid = GridView.builder(
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
        final look = slot == ShopSlot.pedal ? null : p.look.wear(slot.name, item.id);
        return _ItemCard(
          item: item,
          look: slot == ShopSlot.amp ? withElectric(look!) : look,
          face: slot == ShopSlot.hat || slot == ShopSlot.glasses,
          guitarView: slot == ShopSlot.guitar,
          owned: owned,
          wearing: wearing,
          trying: trying,
          confirming: _confirming == item.id,
          canAfford: p.coins >= item.price,
          missing: item.price - p.coins,
          onTap: () => setState(() {
            _tryingSet = null;
            _trying = trying ? null : item;
          }),
          onBuy: () => _buy(state, p, item),
          onWear: () => _wear(state, p, item),
          onTakeOff: slot.removable ? () => _wear(state, p, item, off: true) : null,
        );
      },
    );
    if (!ampHint) return grid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Hint(
          tr(
            'Du spielst gerade eine akustische Gitarre. Ein Amp steht nur bei E-Gitarren neben dir.',
            'You’re playing an acoustic guitar right now. An amp only shows up with an electric guitar.',
          ),
        ),
        const SizedBox(height: 10),
        Expanded(child: grid),
      ],
    );
  }

  /// Sets zum Sammeln: Vorschau, Fortschritt und die einzelnen Teile.
  Widget _setsList(SuonaState state, Profile p) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 20, right: 6),
      children: [
        Text(
          tr(
            'Sammle alle Teile eines Sets und bekomme ein Abzeichen!',
            'Collect every part of a set and earn a badge!',
          ),
          style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 16),
        ),
        const SizedBox(height: 12),
        for (final set in Shop.sets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SetCard(
              set: set,
              profile: p,
              trying: _tryingSet?.id == set.id,
              confirming: _confirming,
              onTap: () => setState(() {
                _trying = null;
                _tryingSet = _tryingSet?.id == set.id ? null : set;
              }),
              onBuy: (item) => _buy(state, p, item),
              onWear: () => _wearSet(state, p, set),
            ),
          ),
      ],
    );
  }
}

/// Für die Vorschau eines Amps: Bei akustischer Gitarre die E-Gitarre der
/// Figur nehmen, sonst wäre der Amp unsichtbar.
CharacterLook withElectric(CharacterLook look) {
  if (look.amp == null || !CharacterArt.instance.isAcoustic(look.guitar)) return look;
  return look.copyWith(guitar: CharacterLook.defaults(look.character).guitar);
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: SuonaColors.stageLine, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: SuonaColors.spot),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: SuonaColors.onStage, fontSize: 15.5)),
          ),
        ],
      ),
    );
  }
}

class _SetCard extends StatelessWidget {
  const _SetCard({
    required this.set,
    required this.profile,
    required this.trying,
    required this.confirming,
    required this.onTap,
    required this.onBuy,
    required this.onWear,
  });

  final OutfitSet set;
  final Profile profile;
  final bool trying;
  final String? confirming;
  final VoidCallback onTap;
  final ValueChanged<ShopItem> onBuy;
  final VoidCallback onWear;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final have = set.ownedBy(p);
    final done = have == set.items.length;
    return Material(
      color: trying ? SuonaColors.stageLine : SuonaColors.stageFloor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: done ? SuonaColors.ok : (trying ? SuonaColors.spot : Colors.transparent), width: 3),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 150, height: 210, child: CharacterView(withElectric(Shop.wearSet(p, set, all: true)))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            set.name,
                            style: display(26, color: SuonaColors.onStage, weight: FontWeight.w700),
                          ),
                        ),
                        if (done)
                          const Icon(Icons.military_tech_rounded, color: SuonaColors.spot, size: 34)
                        else
                          Text(
                            tr('$have von ${set.items.length}', '$have of ${set.items.length}'),
                            style: display(20, color: SuonaColors.spot, weight: FontWeight.w700),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final item in set.parts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              Shop.owns(p, item) ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                              color: Shop.owns(p, item) ? SuonaColors.ok : SuonaColors.onStageMuted,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.name,
                                style: const TextStyle(color: SuonaColors.onStage, fontSize: 17),
                              ),
                            ),
                            if (!Shop.owns(p, item))
                              SizedBox(
                                width: 140,
                                child: p.coins >= item.price
                                    ? _Button(
                                        confirming == item.id ? tr('Ja, kaufen!', 'Yes, buy!') : tr('Kaufen', 'Buy'),
                                        confirming == item.id ? SuonaColors.coral : SuonaColors.spot,
                                        SuonaColors.ink,
                                        () => onBuy(item),
                                        coins: confirming == item.id ? null : item.price,
                                        compact: true,
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          const CoinIcon(size: 18),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${item.price}',
                                            style: display(17, color: SuonaColors.onStageMuted),
                                          ),
                                        ],
                                      ),
                              ),
                          ],
                        ),
                      ),
                    if (have > 0) ...[
                      const SizedBox(height: 4),
                      _Button(
                        done ? tr('Ganzes Set anziehen', 'Wear the whole set') : tr('Meine Teile anziehen', 'Wear my parts'),
                        SuonaColors.teal,
                        Colors.white,
                        onWear,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.look,
    required this.face,
    required this.guitarView,
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
  final bool guitarView;
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
                    : CharacterView(look!, bust: face, guitar: guitarView),
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
  const _Button(this.label, this.bg, this.fg, this.onTap, {this.coins, this.compact = false});
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback? onTap;
  final int? coins;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          padding: EdgeInsets.symmetric(vertical: compact ? 6 : 10),
          textStyle: display(compact ? 16 : 18),
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
