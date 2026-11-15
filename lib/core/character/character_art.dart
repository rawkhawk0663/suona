import 'dart:convert';

import 'package:flutter/services.dart';

import 'look.dart';

/// Setzt Figuren zur Laufzeit zusammen: Vorlage (mit Farb-Platzhaltern und
/// Stellen für Shop-Teile) plus die Teile aus `items.json`. Beides erzeugt
/// `tool/make_characters.py`.
class CharacterArt {
  CharacterArt._(this._templates, this._items);

  static CharacterArt? _instance;
  static CharacterArt get instance => _instance ?? (throw StateError('CharacterArt.load() fehlt'));

  /// Ausschnitte für die runden Profilbilder (wie in make_characters.py).
  static const _faceBox = {Character.luna: '58 24 124 124', Character.fuzz: '56 22 128 128'};

  /// Grösserer Kopf-Ausschnitt mit Platz für Mützen und Kronen (Shop).
  static const _bustBox = {Character.luna: '42 -16 156 156', Character.fuzz: '36 -52 168 168'};

  final Map<Character, String> _templates;
  final Map<String, dynamic> _items;
  final _cache = <String, String>{};

  static Future<void> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final templates = {
      for (final c in Character.values) c: await b.loadString('assets/characters/${c.name}_template.svg'),
    };
    final items = jsonDecode(await b.loadString('assets/characters/items.json')) as Map<String, dynamic>;
    _instance = CharacterArt._(templates, items);
  }

  /// Für Tests: direkt aus Texten.
  static void loadFrom(Map<Character, String> templates, Map<String, dynamic> items) {
    _instance = CharacterArt._(templates, items);
  }

  bool hasGuitar(String id) => (_items['guitars'] as Map<String, dynamic>).containsKey(id);

  bool hasItem(Character c, String id) => (_items[c.name] as Map<String, dynamic>).containsKey(id);

  /// Fertiges SVG einer Figur, auf Wunsch nur der Kopf.
  String svg(CharacterLook look, {bool face = false, bool bust = false}) {
    final key = '${look.key}|$face|$bust';
    final hit = _cache[key];
    if (hit != null) return hit;
    var s = _templates[look.character]!;
    final skin = Palettes.find(Palettes.skin, look.skin);
    final hair = Palettes.find(Palettes.hair, look.hair);
    final eyes = Palettes.find(Palettes.eyes, look.eyes);
    final shirt = Palettes.find(Palettes.shirt, look.shirt);
    final colors = {
      'skin': skin.base,
      'skinS': skin.shade,
      'hair': hair.base,
      'hairS': hair.shade,
      'hairL': hair.light ?? hair.base,
      'eyes': eyes.base,
      'shirt': shirt.base,
      'shirtS': shirt.shade,
    };
    for (final e in colors.entries) {
      s = s.replaceAll('{{${e.key}}}', e.value);
    }
    final defs = StringBuffer();
    final guitars = _items['guitars'] as Map<String, dynamic>;
    final guitar =
        (guitars[look.guitar] ?? guitars[CharacterLook.defaults(look.character).guitar]) as Map<String, dynamic>;
    defs.write(guitar['defs']);
    s = s.replaceFirst('<!--slot:guitar-->', guitar['svg'] as String);
    final own = _items[look.character.name] as Map<String, dynamic>;
    for (final slot in const ['vest', 'glasses', 'hat']) {
      final id = look.itemIn(slot);
      final it = id == null ? null : own[id] as Map<String, dynamic>?;
      if (it == null) continue;
      defs.write(it['defs']);
      s = s.replaceFirst('<!--slot:$slot-->', it['svg'] as String);
      // Mit Kopfbedeckung verschwindet Lunas Haarspange.
      if (slot == 'hat') s = s.replaceFirst(RegExp(r'<!--slot:hairclip-->.*?<!--/slot:hairclip-->', dotAll: true), '');
    }
    s = s.replaceFirst('<!--defs-->', defs.toString());
    if (face || bust) {
      final box = bust ? _bustBox[look.character] : _faceBox[look.character];
      s = s.replaceFirst(RegExp(r'viewBox="[^"]+"'), 'viewBox="$box"');
    }
    if (_cache.length > 200) _cache.clear();
    return _cache[key] = s;
  }
}
