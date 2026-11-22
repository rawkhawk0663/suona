import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/theme.dart';
import '../core/character/character_art.dart';
import '../core/character/look.dart';

/// Bildschirmgrösse: Auf dem Handy (quer) ist wenig Höhe da, dann wird
/// alles kompakter angeordnet.
extension ScreenFit on BuildContext {
  Size get screenSize => MediaQuery.sizeOf(this);

  /// Wenig Höhe (Handy quer, kleines Fenster).
  bool get compact => MediaQuery.sizeOf(this).height < 520;

  /// Schmal (Handy hochkant).
  bool get narrow => MediaQuery.sizeOf(this).width < 600;

  /// Rand der Bildschirme.
  EdgeInsets get screenPadding => compact
      ? const EdgeInsets.fromLTRB(16, 10, 16, 10)
      : (narrow ? const EdgeInsets.fromLTRB(16, 14, 16, 16) : const EdgeInsets.fromLTRB(28, 20, 28, 24));
}

/// Hintergrund der Spielbildschirme: ruhige, dunkle (oder helle) Fläche.
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: SuonaColors.background, child: child);
}

/// Karte mit feinem Rand und runden Ecken (wie in Volti).
class SuonaCard extends StatelessWidget {
  const SuonaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 22,
    this.color,
    this.borderColor,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;

  /// Weiches Leuchten in der Karte (z. B. hinter der Figur).
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor ?? SuonaColors.line),
    );
    Widget content = Padding(padding: padding, child: child);
    if (gradient != null) content = DecoratedBox(decoration: BoxDecoration(gradient: gradient), child: content);
    return Material(
      color: color ?? SuonaColors.card,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Weiches farbiges Leuchten hinter der Figur.
RadialGradient characterGlow({double strength = 1}) => RadialGradient(
  center: const Alignment(0, 0.16),
  radius: 0.75,
  colors: [
    SuonaColors.accent.withValues(alpha: (SuonaColors.isDark ? 0.34 : 0.22) * strength),
    SuonaColors.pink.withValues(alpha: (SuonaColors.isDark ? 0.10 : 0.07) * strength),
    SuonaColors.card.withValues(alpha: 0),
  ],
  stops: const [0, 0.55, 1],
);

/// Quadrat mit runden Ecken im Verlauf und weissem Symbol (Kacheln, Kopfzeile).
class GradientIcon extends StatelessWidget {
  const GradientIcon(this.icon, {super.key, required this.colors, this.size = 52, this.circle = false, this.child});

  final IconData? icon;
  final List<Color> colors;
  final double size;
  final bool circle;

  /// Statt des Symbols (z. B. ein Buchstabe).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: gradientOf(colors),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(size * 0.31),
      ),
      child: child ?? Icon(icon, color: SuonaColors.onGradient, size: size * 0.52),
    );
  }
}

/// Text oder Symbol im Verlauf eingefärbt.
class GradientTint extends StatelessWidget {
  const GradientTint({super.key, required this.colors, required this.child});
  final List<Color> colors;
  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (r) => gradientOf(colors).createShader(r),
    child: child,
  );
}

/// Pillenförmiger Knopf im Verlauf, weisse Schrift. `secondary` ist ruhig
/// (Fläche mit Rand), für Nebenaktionen.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.colors,
    this.secondary = false,
    this.height = 54,
    this.fontSize = 18,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final List<Color>? colors;
  final bool secondary;
  final double height;
  final double fontSize;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final small = context.compact;
    final height = small ? (this.height * 0.8).clamp(40.0, 52.0) : this.height;
    final fontSize = small ? this.fontSize * 0.86 : this.fontSize;
    final enabled = onPressed != null;
    final colors = this.colors ?? SuonaColors.brand;
    final plain = secondary || !enabled;
    final fg = plain ? (enabled ? SuonaColors.ink : SuonaColors.muted) : SuonaColors.onGradient;
    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, color: fg, size: fontSize * 1.25), SizedBox(width: fontSize * 0.45)],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: plain
                ? body(fontSize * 0.92, color: fg, weight: FontWeight.w600)
                : display(fontSize, color: fg),
          ),
        ),
      ],
    );
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height),
        gradient: plain ? null : gradientOf(colors, horizontal: true),
        color: plain ? SuonaColors.cardHigh : null,
        border: plain ? Border.all(color: SuonaColors.line) : null,
        boxShadow: plain ? null : glowOf(colors, strength: 0.32),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(height),
          onTap: onPressed,
          child: Padding(padding: EdgeInsets.symmetric(horizontal: height * 0.45), child: row),
        ),
      ),
    );
  }
}

/// Runder Knopf mit Symbol (Zurück, Schliessen …).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onPressed, this.tooltip, this.size});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final size = this.size ?? (context.compact ? 42.0 : 52.0);
    final button = Material(
      color: SuonaColors.card,
      shape: CircleBorder(side: BorderSide(color: SuonaColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: size * 0.48, color: onPressed == null ? SuonaColors.muted : SuonaColors.ink),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Pille mit feinem Rand (Münzen, Streak, Profil in der Kopfzeile).
class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.child, this.onTap, this.height, this.color});
  final Widget child;
  final VoidCallback? onTap;
  final double? height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final height = this.height ?? (context.compact ? 40.0 : 48.0);
    return Material(
      color: color ?? SuonaColors.card,
      shape: StadiumBorder(side: BorderSide(color: SuonaColors.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: height,
          padding: EdgeInsets.fromLTRB(height * 0.15, 0, height * 0.36, 0),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

/// Balken mit Verlauf (Zeit, Fortschritt).
class GradientBar extends StatelessWidget {
  const GradientBar({super.key, required this.value, this.colors, this.height = 12});
  final double value;
  final List<Color>? colors;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(color: SuonaColors.track, borderRadius: BorderRadius.circular(height)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: gradientOf(colors ?? SuonaColors.sky, horizontal: true),
            borderRadius: BorderRadius.circular(height),
          ),
        ),
      ),
    );
  }
}

/// Grosse, gut treffbare Kachel: Symbol im Verlauf oben, Titel darunter.
class MenuTile extends StatelessWidget {
  const MenuTile({
    super.key,
    required this.title,
    required this.icon,
    required this.colors,
    this.subtitle,
    this.onTap,
    this.locked = false,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;
  final bool locked;

  /// Symbol links neben dem Titel statt darüber.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final small = context.compact || context.narrow;
    final box = small ? 42.0 : 52.0;
    final iconBox = locked
        ? Container(
            width: box,
            height: box,
            decoration: BoxDecoration(color: SuonaColors.cardHigh, borderRadius: BorderRadius.circular(box * 0.31)),
            child: Icon(Icons.lock_rounded, color: SuonaColors.muted, size: box / 2),
          )
        : GradientIcon(icon, colors: colors, size: box);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 1,
            style: display(small ? 18 : 22, color: locked ? SuonaColors.muted : SuonaColors.ink),
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            maxLines: small ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: body(small ? 13 : 15, color: SuonaColors.muted),
          ),
      ],
    );
    return SuonaCard(
      onTap: locked ? null : onTap,
      padding: EdgeInsets.all(small ? 12 : 20),
      child: compact
          ? Row(children: [iconBox, SizedBox(width: small ? 12 : 16), Expanded(child: text)])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [iconBox, SizedBox(height: small ? 8 : 16), text],
            ),
    );
  }
}

/// Luna oder Fuzz mit eigenem Aussehen, ganz oder nur das Gesicht.
class CharacterView extends StatelessWidget {
  const CharacterView(this.look, {super.key, this.face = false, this.bust = false, this.guitar = false, this.size});

  final CharacterLook look;
  final bool face;

  /// Kopf mit Platz für Kopfbedeckungen (Shop).
  final bool bust;

  /// Nur Oberkörper mit Gitarre (Auswahl der Startgitarre, Gitarren im Shop).
  final bool guitar;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final svg = CharacterArt.instance.svg(look, face: face, bust: bust, guitar: guitar);
    Widget picture(double? w, double? h) => SvgPicture.string(
      svg,
      key: ValueKey(look.key),
      width: w,
      height: h,
      fit: BoxFit.contain,
      semanticsLabel: look.character.displayName,
    );
    if (size != null) return picture(size, size);
    // Ohne feste Grösse: den verfügbaren Platz füllen (sofern begrenzt).
    return LayoutBuilder(
      builder: (context, c) => picture(c.hasBoundedWidth ? c.maxWidth : null, c.hasBoundedHeight ? c.maxHeight : null),
    );
  }
}

/// Rundes Gesicht in einem Kreis (Profil-Auswahl, Kopfzeile).
class FaceBadge extends StatelessWidget {
  const FaceBadge(this.look, {super.key, this.size = 56, this.ring});

  final CharacterLook look;
  final double size;

  /// Farbiger Ring (z. B. ausgewählt). Ohne Ring nur der Verlauf.
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradientOf(SuonaColors.brand),
        border: ring == null ? null : Border.all(color: ring!, width: max(2, size / 22)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: EdgeInsets.only(top: size * 0.06),
        child: CharacterView(look, face: true),
      ),
    );
  }
}

/// Münze mit Zahl.
class CoinCount extends StatelessWidget {
  const CoinCount(this.coins, {super.key, this.size = 22, this.color});

  final int coins;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoinIcon(size: size * 1.4),
        SizedBox(width: size * 0.35),
        Text('$coins', style: body(size * 0.85, color: color ?? SuonaColors.ink, weight: FontWeight.w600)),
      ],
    );
  }
}

/// Münze: Kreis im Belohnungs-Verlauf mit einem weissen Ring.
class CoinIcon extends StatelessWidget {
  const CoinIcon({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: gradientOf(SuonaColors.sun)),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.46,
        height: size * 0.46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: max(1.5, size * 0.09)),
        ),
      ),
    );
  }
}

/// Flamme mit Anzahl Tage in Folge.
class StreakCount extends StatelessWidget {
  const StreakCount(this.days, {super.key, this.size = 22, this.active = true, this.shields = 0, this.label});

  final int days;
  final double size;
  final bool active;
  final int shields;

  /// Statt der blossen Zahl (z. B. „5 Tage“).
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        active
            ? GradientIcon(Icons.local_fire_department_rounded, colors: SuonaColors.sun, size: size * 1.4, circle: true)
            : Container(
                width: size * 1.4,
                height: size * 1.4,
                decoration: BoxDecoration(shape: BoxShape.circle, color: SuonaColors.cardHigh),
                child: Icon(Icons.local_fire_department_rounded, size: size * 0.8, color: SuonaColors.muted),
              ),
        SizedBox(width: size * 0.35),
        Text(label ?? '$days', style: body(size * 0.85, weight: FontWeight.w600)),
        for (var i = 0; i < shields; i++)
          Padding(
            padding: EdgeInsets.only(left: size * 0.25),
            child: Icon(Icons.shield_rounded, size: size * 0.9, color: SuonaColors.teal),
          ),
      ],
    );
  }
}

/// Auswählbare Karte: gewählt mit violettem Rand und Leuchten.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.child,
    required this.selected,
    required this.onTap,
    this.padding = const EdgeInsets.all(12),
    this.radius = 22,
    this.glow = true,
  });

  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Weiches Leuchten hinter dem Inhalt, wenn gewählt (Figuren).
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: selected ? glowOf(SuonaColors.brand, strength: 0.25, blur: 22) : null,
      ),
      child: Material(
        color: selected ? SuonaColors.cardHigh : SuonaColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: selected ? SuonaColors.accent : SuonaColors.line, width: selected ? 3 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: selected && glow ? characterGlow() : null),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// Kopfzeile der Unterseiten: Zurück, Titel (Sora), Untertitel, rechts Extras.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing = const [],
    this.icon = Icons.arrow_back_rounded,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final List<Widget> trailing;
  final IconData icon;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final small = context.compact;
    return Row(
      children: [
        RoundIconButton(
          icon: icon,
          tooltip: icon == Icons.close_rounded ? 'OK' : null,
          onPressed: onBack ?? () => Navigator.of(context).maybePop(),
        ),
        SizedBox(width: small ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(title, maxLines: 1, style: display(small ? 22 : 32)),
              ),
              if (subtitle != null && !small)
                Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(15, color: SuonaColors.muted)),
            ],
          ),
        ),
        for (final t in trailing) ...[SizedBox(width: small ? 8 : 10), t],
      ],
    );
  }
}

/// Das App-Symbol (Quadrat mit Verlauf und weisser Marke).
class SuonaLogo extends StatelessWidget {
  const SuonaLogo({super.key, this.size = 46, this.glow = false});
  final double size;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        boxShadow: glow ? glowOf(SuonaColors.brand, strength: 0.4, blur: size * 0.5) : null,
      ),
      child: Image.asset('assets/brand/suona_icon.png', width: size, height: size, filterQuality: FilterQuality.medium),
    );
  }
}
