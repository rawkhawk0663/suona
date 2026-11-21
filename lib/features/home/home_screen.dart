import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/visuals.dart';
import '../../core/game/badges.dart';
import '../adventure/adventure_map_screen.dart';
import '../arcade/arcade_setup_screen.dart';
import '../chords/chords_screen.dart';
import '../shop/shop_screen.dart';
import 'badges_dialog.dart';
import '../quiz/quiz_screen.dart';
import '../adventure/tour.dart';

/// Das Zuhause eines Profils: Figur auf der Bühne und die Spielarten.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.profileId});
  final String profileId;

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    final profile = state.profiles.where((p) => p.id == profileId).firstOrNull;
    if (profile == null) {
      // Profil wurde im Lehrerbereich gelöscht.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      });
      return const Scaffold();
    }
    final now = DateTime.now();
    final curriculum = state.curriculumOf(profile);
    final step = profile.step.clamp(0, curriculum.steps.length - 1);
    final practicedToday = profile.streak.practicedOn(now);

    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

    final tiles = [
      MenuTile(
        title: tr('Noten lesen', 'Read notes'),
        subtitle: tr('Wie heisst die Note?', 'Name that note'),
        icon: Icons.music_note_rounded,
        colors: SuonaColors.brand,
        onTap: () => open(QuizScreen(profileId: profile.id, config: QuizConfig.practice())),
      ),
      MenuTile(
        title: tr('Griffbrett', 'Fretboard'),
        subtitle: tr('Wo liegt die Note?', 'Where is the note?'),
        icon: Icons.grid_on_rounded,
        colors: SuonaColors.sky,
        onTap: () => open(QuizScreen(profileId: profile.id, config: QuizConfig.fretboardPractice())),
      ),
      MenuTile(
        title: tr('Akkorde', 'Chords'),
        subtitle: tr('Griffe und Akkord-Tour', 'Shapes and chord tour'),
        icon: Icons.library_music_rounded,
        colors: SuonaColors.mint,
        onTap: () => open(ChordsScreen(profileId: profile.id)),
      ),
      MenuTile(
        title: 'Arcade',
        subtitle: profile.arcadeBest > 0
            ? tr('Rekord ${profile.arcadeBest}', 'Best ${profile.arcadeBest}')
            : tr('Endlos, bis 3 Fehler', 'Endless, until 3 mistakes'),
        icon: Icons.bolt_rounded,
        colors: SuonaColors.sun,
        onTap: () => open(ArcadeSetupScreen(profileId: profile.id)),
      ),
      MenuTile(
        title: tr('Abenteuer', 'Adventure'),
        subtitle: tr('Bis ins Stadion', 'To the stadium'),
        icon: Icons.map_rounded,
        colors: SuonaColors.brand,
        onTap: () => open(AdventureMapScreen(profileId: profile.id)),
      ),
      MenuTile(
        title: 'Shop',
        subtitle: tr('Outfits, Gitarren, Amps', 'Outfits, guitars, amps'),
        icon: Icons.storefront_rounded,
        colors: SuonaColors.sun,
        onTap: () => open(ShopScreen(profileId: profile.id, startTab: 1)),
      ),
    ];

    final earned = badgesOf(profile).where((b) => b.earned).length;
    final hero = SuonaCard(
      radius: 24,
      gradient: characterGlow(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _Bubble(
            text: practicedToday
                ? tr('Heute schon geübt. Stark!', 'Already practised today. Great!')
                : tr('Bereit für die Bühne, ${profile.nickname}?', 'Ready for the stage, ${profile.nickname}?'),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GestureDetector(
              // Figur antippen: Aussehen ändern.
              onTap: () => open(ShopScreen(profileId: profile.id)),
              child: CharacterView(profile.look),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              GradientButton(
                label: tr('Aussehen', 'Looks'),
                icon: Icons.palette_rounded,
                secondary: true,
                height: 46,
                fontSize: 17,
                onPressed: () => open(ShopScreen(profileId: profile.id)),
              ),
              GradientButton(
                label: tr('Abzeichen · $earned', 'Badges · $earned'),
                icon: Icons.military_tech_rounded,
                secondary: true,
                height: 46,
                fontSize: 17,
                onPressed: () => showBadges(context, profile),
              ),
            ],
          ),
        ],
      ),
    );

    Widget grid(int columns) => LayoutBuilder(
      builder: (context, c) {
        const gap = 16.0;
        final w = (c.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, height: 172, child: t)],
        );
      },
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Column(
            children: [
              _TopBar(
                profile: profile,
                subtitle:
                    '${curriculum.name} · ${tr('Schritt', 'Step')} ${step + 1}/${curriculum.steps.length}: ${curriculum.steps[step].title}',
              ),
              const SizedBox(height: 18),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, c) {
                    if (c.maxWidth >= 900 && c.maxHeight >= 640) {
                      return Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1360),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(width: (c.maxWidth * 0.33).clamp(340.0, 440.0), child: hero),
                              const SizedBox(width: 24),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _AdventureCard(profile: profile),
                                    const SizedBox(height: 16),
                                    grid(3),
                                    const SizedBox(height: 16),
                                    Expanded(child: _WeekCard(profile: profile)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: 360, child: hero),
                          const SizedBox(height: 16),
                          _AdventureCard(profile: profile),
                          const SizedBox(height: 16),
                          grid(c.maxWidth >= 560 ? 3 : 2),
                          const SizedBox(height: 16),
                          _WeekCard(profile: profile),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.profile, required this.subtitle});
  final Profile profile;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = profile.streak.currentDays(now);
    return Row(
      children: [
        const SuonaLogo(size: 46, glow: true),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Suona', style: display(26)),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(14, color: SuonaColors.muted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Profil: antippen führt zurück zur Auswahl.
        Tooltip(
          message: tr('Anderes Profil', 'Switch profile'),
          child: InfoPill(
            onTap: () => Navigator.of(context).pop(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaceBadge(profile.look, size: 36),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    profile.nickname,
                    overflow: TextOverflow.ellipsis,
                    style: body(16, weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Tooltip(
          message: tr('Tage in Folge geübt', 'Days in a row'),
          child: InfoPill(
            child: StreakCount(
              days,
              size: 21,
              active: profile.streak.practicedOn(now),
              shields: profile.streak.shields,
              label: tr(days == 1 ? '1 Tag' : '$days Tage', days == 1 ? '1 day' : '$days days'),
            ),
          ),
        ),
        const SizedBox(width: 10),
        InfoPill(child: CoinCount(profile.coins, size: 21)),
      ],
    );
  }
}

/// Grosse Karte im Bühnen-Verlauf: hier geht es im Abenteuer weiter.
class _AdventureCard extends StatelessWidget {
  const _AdventureCard({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final state = SuonaScope.of(context);
    const tour = NoteTour();
    final next = nextStop(tour, state, profile);
    final info = next.done ? null : tour.levelInfo(state, profile, next.station, next.level);
    final title = next.done
        ? tr('Alles geschafft!', 'All done!')
        : '${tour.stationName(next.station)} · ${tour.levelName(next.level)}';
    final line = next.done
        ? tr('Du hast im Stadion gespielt. Spiel Level nochmals für mehr Sterne.', 'You played the stadium. Replay levels for more stars.')
        : next.waiting
        ? tr('Die nächste Station gibt deine Lehrperson frei.', 'Your teacher unlocks the next station.')
        : [
            tr('Level ${next.level + 1} von ${tour.levelsPerStation}', 'Level ${next.level + 1} of ${tour.levelsPerStation}'),
            if (info?.time != null) info!.time!,
          ].join(' · ');
    void openMap() => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => AdventureMapScreen(profileId: profile.id)));
    final colors = [SuonaColors.brand[1], Color.lerp(SuonaColors.brand[1], SuonaColors.brand[0], 0.55)!, SuonaColors.brand[0]];
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: colors, begin: Alignment.centerLeft, end: Alignment.centerRight),
        boxShadow: glowOf(SuonaColors.brand, strength: 0.32, blur: 36),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: openMap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 24, 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Weiter im Abenteuer', 'Continue the adventure'),
                        style: body(15, color: Colors.white.withValues(alpha: 0.9), weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(title, maxLines: 1, style: display(34, color: Colors.white)),
                      ),
                      const SizedBox(height: 4),
                      Text(line, style: body(16, color: Colors.white.withValues(alpha: 0.9))),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (!next.done) _Ring(value: next.level / tour.levelsPerStation, label: '${next.level}/${tour.levelsPerStation}'),
                const SizedBox(width: 16),
                Material(
                  color: Colors.white,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: next.done || next.waiting
                        ? openMap
                        : () => tour.startLevel(context, state, profile, next.station, next.level),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            next.done || next.waiting ? Icons.map_rounded : Icons.play_arrow_rounded,
                            color: const Color(0xFF2A0F66),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            next.done || next.waiting ? tr('Zur Karte', 'Map') : tr('Weiter', 'Go'),
                            style: display(17, color: const Color(0xFF2A0F66)),
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
      ),
    );
  }
}

/// Fortschrittsring: geschaffte Level der Station.
class _Ring extends StatelessWidget {
  const _Ring({required this.value, required this.label});
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: 1,
            strokeWidth: 9,
            color: Colors.white.withValues(alpha: 0.28),
          ),
          CircularProgressIndicator(
            value: value,
            strokeWidth: 9,
            strokeCap: StrokeCap.round,
            color: Colors.white,
            backgroundColor: Colors.transparent,
          ),
          Center(child: Text(label, style: display(22, color: Colors.white))),
        ],
      ),
    );
  }
}

/// Übungstage dieser Woche als Punkte (Mint = geübt).
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.profile});
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final streak = profile.streak;
    final days = streak.currentDays(now);
    // Geübt: die Tage der laufenden Serie bis zum letzten Übungstag.
    final last = streak.lastDay == null ? null : DateTime.tryParse(streak.lastDay!);
    bool practiced(DateTime d) {
      if (last == null || days == 0) return false;
      final ago = DateTime(last.year, last.month, last.day).difference(d).inDays;
      return ago >= 0 && ago < days;
    }

    final names = L10n.isEnglish ? ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'] : ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final practicedToday = streak.practicedOn(now);
    final todayInfo = Row(
      children: [
        practicedToday
            ? GradientIcon(Icons.check_rounded, colors: SuonaColors.mint, size: 52, circle: true)
            : GradientIcon(Icons.music_note_rounded, colors: SuonaColors.brand, size: 52, circle: true),
        const SizedBox(width: 16),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tr('Heute', 'Today'), style: display(19)),
              const SizedBox(height: 2),
              Text(
                practicedToday
                    ? tr('Geübt! Der Tag zählt.', 'Practised! Today counts.')
                    : tr('Eine Übungsrunde (10 Töne) und der Tag zählt.', 'One round (10 notes) and today counts.'),
                style: body(15, color: SuonaColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
    final week = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tr('Diese Woche', 'This week'), style: body(14, color: SuonaColors.muted)),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 7; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              _DayDot(name: names[i], done: practiced(monday.add(Duration(days: i)))),
            ],
          ],
        ),
      ],
    );
    return SuonaCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 680
            ? Row(children: [Expanded(child: todayInfo), const SizedBox(width: 24), week])
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [todayInfo, const SizedBox(height: 14), week],
              ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.name, required this.done});
  final String name;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: done ? gradientOf(SuonaColors.mint) : null,
        color: done ? null : SuonaColors.cardHigh,
        border: done ? null : Border.all(color: SuonaColors.line),
      ),
      child: Text(
        name,
        style: body(12, weight: FontWeight.w600, color: done ? Colors.white : SuonaColors.muted),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: SuonaColors.cardHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SuonaColors.line),
      ),
      child: Text(text, textAlign: TextAlign.center, style: display(19)),
    );
  }
}
