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
import '../../widgets/visuals.dart';

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
          style: display(18),
        ),
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
    final preview = SuonaCard(
      radius: 24,
      gradient: characterGlow(),
      child: Column(
      children: [
        Expanded(child: CharacterView(_preview(p))),
        const SizedBox(height: 8),
        if (_tryingSet != null || (_trying != null && _trying!.slot != ShopSlot.pedal))
          Text(
            _tryingSet != null
                ? tr('Du probierst: Set ${_tryingSet!.name}', 'Trying on: ${_tryingSet!.name} set')
                : tr('Du probierst: ${_trying!.name}', 'Trying on: ${_trying!.name}'),
            textAlign: TextAlign.center,
            style: display(18, color: SuonaColors.muted, weight: FontWeight.w600),
          ),
      ],
      ),
    );
    return DefaultTabController(
      length: tabs.length,
      initialIndex: widget.startTab,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: context.screenPadding,
              child: Column(
                children: [
                  ScreenHeader(
                    title: 'Shop',
                    subtitle: tr('Nur mit Spiel-Münzen, nie mit Geld', 'Game coins only, never real money'),
                    trailing: [InfoPill(child: CoinCount(p.coins, size: 21))],
                  ),
                  SizedBox(height: context.compact ? 8 : 18),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, c) {
                        final content = Column(
                          children: [
                            TabBar(
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              labelColor: Colors.white,
                              unselectedLabelColor: SuonaColors.ink,
                              labelStyle: display(16),
                              unselectedLabelStyle: display(16, weight: FontWeight.w600),
                              splashBorderRadius: BorderRadius.circular(999),
                              indicator: BoxDecoration(
                                gradient: gradientOf(SuonaColors.brand, horizontal: true),
                                borderRadius: BorderRadius.circular(999),
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
                                    height: context.compact ? 38 : 48,
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
                            SizedBox(height: context.compact ? 6 : 12),
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
                        if (c.maxWidth >= 820 || (context.compact && c.maxWidth >= 600)) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: c.maxWidth * (context.compact ? 0.26 : 0.32), child: preview),
                              SizedBox(width: context.compact ? 12 : 24),
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
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: context.compact ? 170 : 230,
        mainAxisExtent: context.compact ? 214 : 286,
        crossAxisSpacing: context.compact ? 8 : 12,
        mainAxisSpacing: context.compact ? 8 : 12,
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
          style: body(16, color: SuonaColors.muted),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: SuonaColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SuonaColors.line),
      ),
      child: Row(
        children: [
          GradientIcon(Icons.lightbulb_rounded, colors: SuonaColors.sky, size: 36),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: body(15.5))),
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
      color: trying ? SuonaColors.cardHigh : SuonaColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: done || trying
            ? BorderSide(color: done ? SuonaColors.ok : SuonaColors.accent, width: 3)
            : BorderSide(color: SuonaColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: context.compact ? 100 : 150,
                height: context.compact ? 150 : 210,
                child: CharacterView(withElectric(Shop.wearSet(p, set, all: true))),
              ),
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
                            style: display(23),
                          ),
                        ),
                        if (done)
                          GradientIcon(Icons.military_tech_rounded, colors: SuonaColors.sun, size: 40, circle: true)
                        else
                          Text(
                            tr('$have von ${set.items.length}', '$have of ${set.items.length}'),
                            style: body(17, color: SuonaColors.muted, weight: FontWeight.w600),
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
                              color: Shop.owns(p, item) ? SuonaColors.ok : SuonaColors.muted,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item.name,
                                style: body(17),
                              ),
                            ),
                            if (!Shop.owns(p, item))
                              SizedBox(
                                width: 140,
                                child: p.coins >= item.price
                                    ? _Button(
                                        confirming == item.id ? tr('Ja, kaufen!', 'Yes, buy!') : tr('Kaufen', 'Buy'),
                                        confirming == item.id ? SuonaColors.brand : SuonaColors.sun,
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
                                            style: body(16, color: SuonaColors.muted, weight: FontWeight.w600),
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
                        SuonaColors.mint,
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
      action = _Pill(tr('Gehört dir', 'Yours'), SuonaColors.mint);
    } else if (wearing) {
      action = onTakeOff == null
          ? _Pill(tr('Trägst du', 'Wearing'), SuonaColors.mint)
          : _Button(tr('Ausziehen', 'Take off'), null, onTakeOff);
    } else if (owned) {
      action = _Button(tr('Anziehen', 'Wear'), SuonaColors.mint, onWear);
    } else if (!canAfford) {
      action = _Pill(tr('Noch $missing Münzen', '$missing coins to go'), null);
    } else {
      action = _Button(
        confirming ? tr('Ja, kaufen!', 'Yes, buy!') : tr('Kaufen', 'Buy'),
        confirming ? SuonaColors.brand : SuonaColors.sun,
        onBuy,
        coins: confirming ? null : item.price,
      );
    }
    return Material(
      color: trying ? SuonaColors.cardHigh : SuonaColors.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: wearing || trying
            ? BorderSide(color: wearing ? SuonaColors.ok : SuonaColors.accent, width: 3)
            : BorderSide(color: SuonaColors.line),
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
                    ? Center(child: GradientIcon(pedalIcon, colors: SuonaColors.sun, size: 96))
                    : CharacterView(look!, bust: face, guitar: guitarView),
              ),
              const SizedBox(height: 6),
              Text(
                item.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: display(17),
              ),
              if (item.help.isNotEmpty && !context.compact)
                Text(
                  item.help,
                  textAlign: TextAlign.center,
                  style: body(12.5, color: SuonaColors.muted, height: 1.25),
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

/// Knopf in einer Karte: Verlauf (kaufen, anziehen) oder ruhig ([colors] null).
class _Button extends StatelessWidget {
  const _Button(this.label, this.colors, this.onTap, {this.coins, this.compact = false});
  final String label;
  final List<Color>? colors;
  final VoidCallback? onTap;
  final int? coins;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final plain = colors == null;
    final fg = plain ? SuonaColors.ink : Colors.white;
    final height = compact ? 40.0 : 46.0;
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height),
        gradient: plain ? null : gradientOf(colors!, horizontal: true),
        color: plain ? SuonaColors.cardHigh : null,
        border: plain ? Border.all(color: SuonaColors.line) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(height),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: display(compact ? 15 : 16, color: fg),
                ),
              ),
              if (coins != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('$coins', style: display(compact ? 14 : 15, color: fg)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, this.colors);
  final String label;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 46,
      decoration: BoxDecoration(
        gradient: colors == null ? null : gradientOf(colors!, horizontal: true),
        color: colors == null ? SuonaColors.cardHigh : null,
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: display(15, color: colors == null ? SuonaColors.muted : Colors.white),
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
              style: display(20),
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
                            color: s.key == current ? SuonaColors.accent : SuonaColors.line,
                            width: s.key == current ? 4 : 2,
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
          style: body(16, color: SuonaColors.muted),
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
            icon: Icon(Icons.restart_alt_rounded, color: SuonaColors.muted),
            label: Text(
              tr('Grundfarben', 'Original colours'),
              style: body(16, color: SuonaColors.muted),
            ),
          ),
        ),
      ],
    );
  }
}
