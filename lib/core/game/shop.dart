import '../../app/l10n.dart';
import '../profiles/profile.dart';

/// Fächer im Shop. Pedale sind Fähigkeiten im Abenteuer, keine Kleidung.
enum ShopSlot {
  hat,
  glasses,
  vest,
  guitar,
  pedal;

  String get label => switch (this) {
    ShopSlot.hat => tr('Kopf', 'Headwear'),
    ShopSlot.glasses => tr('Brillen', 'Glasses'),
    ShopSlot.vest => tr('Westen', 'Vests'),
    ShopSlot.guitar => tr('Gitarren', 'Guitars'),
    ShopSlot.pedal => tr('Pedale', 'Pedals'),
  };
}

/// Ein Teil im Shop. Bezahlt wird nur mit Münzen aus dem Spiel, nie mit Geld.
class ShopItem {
  const ShopItem(this.id, this.slot, this.price);

  final String id;
  final ShopSlot slot;
  final int price;

  bool get free => price == 0;

  String get name => switch (id) {
    'hat_beanie' => tr('Mütze', 'Beanie'),
    'hat_bandana' => tr('Bandana', 'Bandana'),
    'hat_headphones' => tr('Kopfhörer', 'Headphones'),
    'hat_crown' => tr('Rockstar-Krone', 'Rock star crown'),
    'glasses_sun' => tr('Sonnenbrille', 'Sunglasses'),
    'glasses_star' => tr('Sternenbrille', 'Star glasses'),
    'vest_leather' => tr('Lederweste', 'Leather vest'),
    'vest_jeans' => tr('Jeansweste', 'Denim vest'),
    'g_pointy' => tr('Pfeil-Gitarre', 'Arrow guitar'),
    'g_double' => tr('Rock-Gitarre', 'Rock guitar'),
    'g_pointy_gold' => tr('Goldene Pfeil-Gitarre', 'Golden arrow guitar'),
    'g_double_black' => tr('Schwarze Rock-Gitarre', 'Black rock guitar'),
    'g_acoustic' => tr('Akustikgitarre', 'Acoustic guitar'),
    'g_star' => tr('Sternen-Gitarre', 'Star guitar'),
    'pedal_shield' => tr('Schild-Pedal', 'Shield pedal'),
    'pedal_capo' => tr('Kapodaster', 'Capo'),
    'pedal_tuner' => tr('Stimmgerät', 'Tuner'),
    _ => id,
  };

  /// Was ein Pedal im Abenteuer kann.
  String get help => switch (id) {
    'pedal_shield' => tr('Wehrt einen falschen Ton ab. Einmal pro Level.', 'Blocks one wrong note. Once per level.'),
    'pedal_capo' => tr(
      'Hält die Zeit für einen Ton an. Einmal pro Level.',
      'Stops the clock for one note. Once per level.',
    ),
    'pedal_tuner' => tr(
      'Streicht zwei falsche Namen weg oder zeigt die Saite. Einmal pro Level.',
      'Removes two wrong names or shows the string. Once per level.',
    ),
    _ => '',
  };
}

/// Alles, was es im Shop gibt.
class Shop {
  Shop._();

  static const items = [
    ShopItem('hat_bandana', ShopSlot.hat, 60),
    ShopItem('hat_beanie', ShopSlot.hat, 80),
    ShopItem('hat_headphones', ShopSlot.hat, 120),
    ShopItem('hat_crown', ShopSlot.hat, 600),
    ShopItem('glasses_sun', ShopSlot.glasses, 70),
    ShopItem('glasses_star', ShopSlot.glasses, 90),
    ShopItem('vest_jeans', ShopSlot.vest, 130),
    ShopItem('vest_leather', ShopSlot.vest, 150),
    ShopItem('g_pointy', ShopSlot.guitar, 0),
    ShopItem('g_double', ShopSlot.guitar, 0),
    ShopItem('g_acoustic', ShopSlot.guitar, 180),
    ShopItem('g_double_black', ShopSlot.guitar, 200),
    ShopItem('g_pointy_gold', ShopSlot.guitar, 250),
    ShopItem('g_star', ShopSlot.guitar, 350),
    ShopItem('pedal_shield', ShopSlot.pedal, 120),
    ShopItem('pedal_capo', ShopSlot.pedal, 150),
    ShopItem('pedal_tuner', ShopSlot.pedal, 150),
  ];

  static ShopItem? byId(String id) => items.where((i) => i.id == id).firstOrNull;

  static List<ShopItem> inSlot(ShopSlot slot) => items.where((i) => i.slot == slot).toList();

  static bool owns(Profile p, ShopItem item) => item.free || p.owned.contains(item.id);

  /// Kaufen: Münzen abziehen, Teil gehört dem Profil. Gibt false zurück,
  /// wenn es nicht reicht oder schon gekauft ist.
  static bool buy(Profile p, ShopItem item) {
    if (owns(p, item) || p.coins < item.price) return false;
    p.coins -= item.price;
    p.owned.add(item.id);
    return true;
  }

  /// Gekaufte Pedale (für das Abenteuer).
  static List<ShopItem> pedalsOf(Profile p) => inSlot(ShopSlot.pedal).where((i) => owns(p, i)).toList();
}
