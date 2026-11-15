import '../../app/l10n.dart';

/// Schwierigkeitsstufe eines Profils, nach Alter gedacht. Die Lehrperson
/// wählt sie im Lehrerbereich. Gespeichert wird nur die Stufe, nie das Alter
/// (Kinderschutz: so wenig Daten wie möglich).
///
/// Sie bestimmt im Abenteuer, wie viel Zeit es pro Ton gibt, wie geduldig das
/// Publikum ist und wie lang die Level sind.
enum Difficulty {
  mini(timeFactor: 1.6, lossFactor: 0.6, gain: 0.10, untimedRehearsal: 4, untimedFretboard: 2, shorter: true),
  junior(timeFactor: 1.3, lossFactor: 0.8, gain: 0.09, untimedRehearsal: 3, untimedFretboard: 1, shorter: false),
  teen(timeFactor: 1.0, lossFactor: 1.0, gain: 0.08, untimedRehearsal: 2, untimedFretboard: 1, shorter: false),
  pro(timeFactor: 0.8, lossFactor: 1.2, gain: 0.07, untimedRehearsal: 1, untimedFretboard: 0, shorter: false);

  const Difficulty({
    required this.timeFactor,
    required this.lossFactor,
    required this.gain,
    required this.untimedRehearsal,
    required this.untimedFretboard,
    required this.shorter,
  });

  /// Mehr oder weniger Zeit pro Ton als die Grundzeit.
  final double timeFactor;

  /// Wie stark ein Fehler das Publikum enttäuscht (1 = Grundwert).
  final double lossFactor;

  /// Wie viel Stimmung ein richtiger Ton bringt.
  final double gain;

  /// Bis zu welcher Station (ausschliesslich) die Probe ohne Zeit läuft.
  final int untimedRehearsal;

  /// Bis zu welcher Station Griffbrett und „Welcher Ton?“ ohne Zeit laufen.
  final int untimedFretboard;

  /// Kürzere Level (für die Jüngsten).
  final bool shorter;

  /// Standard für bestehende und neue Profile.
  static const standard = Difficulty.junior;

  String get label => switch (this) {
    Difficulty.mini => tr('Mini (etwa 6–8 Jahre)', 'Mini (about 6–8 years)'),
    Difficulty.junior => tr('Junior (etwa 9–11 Jahre)', 'Junior (about 9–11 years)'),
    Difficulty.teen => tr('Teen (etwa 12–15 Jahre)', 'Teen (about 12–15 years)'),
    Difficulty.pro => tr('Profi (ab etwa 16 Jahren)', 'Pro (about 16 and up)'),
  };

  String get shortLabel => switch (this) {
    Difficulty.mini => 'Mini',
    Difficulty.junior => 'Junior',
    Difficulty.teen => 'Teen',
    Difficulty.pro => tr('Profi', 'Pro'),
  };

  String get help => switch (this) {
    Difficulty.mini => tr(
      'Viel Zeit, ein geduldiges Publikum und kürzere Level.',
      'Lots of time, a patient crowd and shorter levels.',
    ),
    Difficulty.junior => tr('Etwas mehr Zeit und ein freundliches Publikum.', 'A bit more time and a friendly crowd.'),
    Difficulty.teen => tr('Normale Zeit und ein normales Publikum.', 'Normal time and a normal crowd.'),
    Difficulty.pro => tr('Knappe Zeit und ein strenges Publikum.', 'Tight time and a strict crowd.'),
  };

  static Difficulty fromName(String? name) => Difficulty.values.asNameMap()[name] ?? standard;
}
