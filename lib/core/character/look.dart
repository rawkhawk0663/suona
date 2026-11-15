import '../../app/l10n.dart';

/// Grundfigur eines Profils.
enum Character {
  luna,
  fuzz;

  String get displayName => name == 'luna' ? 'Luna' : 'Fuzz';
}

/// Eine wählbare Farbe mit Schattenton (und bei Haaren einem Glanzton).
class Swatch {
  const Swatch(this.key, this.base, this.shade, [this.light]);
  final String key;
  final String base;
  final String shade;
  final String? light;

  int get argb => 0xFF000000 | int.parse(base.substring(1), radix: 16);
}

/// Farben, die im Charakter-Editor frei wählbar sind (ohne Münzen).
class Palettes {
  Palettes._();

  static const skin = [
    Swatch('light', '#F3BE98', '#D99A72'),
    Swatch('peach', '#F4C7A1', '#D9A27A'),
    Swatch('mid', '#E3A47A', '#C4825A'),
    Swatch('tan', '#C68863', '#A66A47'),
    Swatch('dark', '#8D5A3B', '#6E4329'),
  ];

  static const hair = [
    Swatch('violet', '#3D2263', '#2A1747', '#7A4FC2'),
    Swatch('brown', '#4A2A16', '#33190A', '#7A4A2A'),
    Swatch('black', '#1E1A26', '#0E0B14', '#4A4458'),
    Swatch('blond', '#E8B84A', '#C49530', '#F6D98A'),
    Swatch('red', '#C2452D', '#93301E', '#E6795F'),
    Swatch('blue', '#2F5BD3', '#1F3E99', '#6E93F0'),
    Swatch('pink', '#E0569A', '#B23C77', '#F28DBF'),
    Swatch('green', '#2BA36B', '#1C7A4E', '#6FD3A0'),
  ];

  static const eyes = [
    Swatch('violet', '#5B3F8C', '#5B3F8C'),
    Swatch('brown', '#3A2416', '#3A2416'),
    Swatch('blue', '#2F6FCB', '#2F6FCB'),
    Swatch('green', '#2E8B57', '#2E8B57'),
  ];

  static const shirt = [
    Swatch('violet', '#8E6CEF', '#6A48C9'),
    Swatch('teal', '#23A89C', '#167F75'),
    Swatch('red', '#E23D3D', '#B52530'),
    Swatch('yellow', '#F2B630', '#C8901A'),
    Swatch('black', '#2B2340', '#1A1428'),
    Swatch('pink', '#FF7AB2', '#D94F8C'),
  ];

  static Swatch find(List<Swatch> list, String key) => list.firstWhere((s) => s.key == key, orElse: () => list.first);
}

/// Wie eine Figur aussieht: Farben (frei wählbar) und angezogene Shop-Teile.
class CharacterLook {
  const CharacterLook({
    required this.character,
    required this.skin,
    required this.hair,
    required this.eyes,
    required this.shirt,
    required this.guitar,
    this.hat,
    this.glasses,
    this.vest,
    this.neck,
    this.amp,
  });

  factory CharacterLook.defaults(Character c) => c == Character.luna
      ? const CharacterLook(
          character: Character.luna,
          skin: 'light',
          hair: 'violet',
          eyes: 'violet',
          shirt: 'violet',
          guitar: 'g_pointy',
        )
      : const CharacterLook(
          character: Character.fuzz,
          skin: 'peach',
          hair: 'brown',
          eyes: 'brown',
          shirt: 'teal',
          guitar: 'g_double',
        );

  final Character character;
  final String skin;
  final String hair;
  final String eyes;
  final String shirt;
  final String guitar;
  final String? hat;
  final String? glasses;
  final String? vest;

  /// Halsschmuck (Halstuch, Kette, Fliege …).
  final String? neck;

  /// Verstärker neben der Figur. Sichtbar nur mit E-Gitarre.
  final String? amp;

  /// Teil in einem Fach (hat, glasses, vest, neck, amp, guitar).
  String? itemIn(String slot) => switch (slot) {
    'hat' => hat,
    'glasses' => glasses,
    'vest' => vest,
    'neck' => neck,
    'amp' => amp,
    'guitar' => guitar,
    _ => null,
  };

  CharacterLook copyWith({
    String? skin,
    String? hair,
    String? eyes,
    String? shirt,
    String? guitar,
    String? hat,
    String? glasses,
    String? vest,
    String? neck,
    String? amp,
    bool clearHat = false,
    bool clearGlasses = false,
    bool clearVest = false,
    bool clearNeck = false,
    bool clearAmp = false,
  }) => CharacterLook(
    character: character,
    skin: skin ?? this.skin,
    hair: hair ?? this.hair,
    eyes: eyes ?? this.eyes,
    shirt: shirt ?? this.shirt,
    guitar: guitar ?? this.guitar,
    hat: clearHat ? null : (hat ?? this.hat),
    glasses: clearGlasses ? null : (glasses ?? this.glasses),
    vest: clearVest ? null : (vest ?? this.vest),
    neck: clearNeck ? null : (neck ?? this.neck),
    amp: clearAmp ? null : (amp ?? this.amp),
  );

  /// Ein Teil anziehen oder (mit null) das Fach leeren. Gitarren lassen sich nicht ausziehen.
  CharacterLook wear(String slot, String? id) => switch (slot) {
    'hat' => id == null ? copyWith(clearHat: true) : copyWith(hat: id),
    'glasses' => id == null ? copyWith(clearGlasses: true) : copyWith(glasses: id),
    'vest' => id == null ? copyWith(clearVest: true) : copyWith(vest: id),
    'neck' => id == null ? copyWith(clearNeck: true) : copyWith(neck: id),
    'amp' => id == null ? copyWith(clearAmp: true) : copyWith(amp: id),
    'guitar' => id == null ? this : copyWith(guitar: id),
    _ => this,
  };

  /// Eindeutiger Schlüssel (für den Zwischenspeicher der Bilder).
  String get key => '${character.name}|$skin|$hair|$eyes|$shirt|$guitar|$hat|$glasses|$vest|$neck|$amp';

  Map<String, dynamic> toJson() => {
    'character': character.name,
    'skin': skin,
    'hair': hair,
    'eyes': eyes,
    'shirt': shirt,
    'guitar': guitar,
    'hat': hat,
    'glasses': glasses,
    'vest': vest,
    'neck': neck,
    'amp': amp,
  };

  static CharacterLook fromJson(Map<String, dynamic>? j, Character fallback) {
    if (j == null) return CharacterLook.defaults(fallback);
    final c = Character.values.asNameMap()[j['character']] ?? fallback;
    final d = CharacterLook.defaults(c);
    return CharacterLook(
      character: c,
      skin: j['skin'] as String? ?? d.skin,
      hair: j['hair'] as String? ?? d.hair,
      eyes: j['eyes'] as String? ?? d.eyes,
      shirt: j['shirt'] as String? ?? d.shirt,
      guitar: j['guitar'] as String? ?? d.guitar,
      hat: j['hat'] as String?,
      glasses: j['glasses'] as String?,
      vest: j['vest'] as String?,
      neck: j['neck'] as String?,
      amp: j['amp'] as String?,
    );
  }
}

/// Namen der Farben für den Editor.
String swatchName(String group, String key) => switch ('$group/$key') {
  'skin/light' => tr('Hell', 'Light'),
  'skin/peach' => tr('Pfirsich', 'Peach'),
  'skin/mid' => tr('Mittel', 'Medium'),
  'skin/tan' => tr('Gebräunt', 'Tan'),
  'skin/dark' => tr('Dunkel', 'Dark'),
  _ => switch (key) {
    'violet' => tr('Lila', 'Purple'),
    'brown' => tr('Braun', 'Brown'),
    'black' => tr('Schwarz', 'Black'),
    'blond' => tr('Blond', 'Blond'),
    'red' => tr('Rot', 'Red'),
    'blue' => tr('Blau', 'Blue'),
    'pink' => tr('Pink', 'Pink'),
    'green' => tr('Grün', 'Green'),
    'teal' => tr('Türkis', 'Teal'),
    'yellow' => tr('Gelb', 'Yellow'),
    _ => key,
  },
};
