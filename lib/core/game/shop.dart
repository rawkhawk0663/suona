import '../../app/l10n.dart';
import '../profiles/profile.dart';

/// Fächer im Shop. Pedale sind Fähigkeiten im Abenteuer, keine Kleidung.
enum ShopSlot {
  hat,
  glasses,
  neck,
  vest,
  guitar,
  amp,
  pedal;

  String get label => switch (this) {
    ShopSlot.hat => tr('Kopf', 'Headwear'),
    ShopSlot.glasses => tr('Brillen', 'Glasses'),
    ShopSlot.neck => tr('Hals', 'Neck'),
    ShopSlot.vest => tr('Westen', 'Vests'),
    ShopSlot.guitar => tr('Gitarren', 'Guitars'),
    ShopSlot.amp => tr('Amps', 'Amps'),
    ShopSlot.pedal => tr('Pedale', 'Pedals'),
  };

  /// Lässt sich ausziehen (Gitarren nicht, Pedale sind keine Kleidung).
  bool get removable => this != ShopSlot.guitar && this != ShopSlot.pedal;
}

/// Ein Teil im Shop. Bezahlt wird nur mit Münzen aus dem Spiel, nie mit Geld.
class ShopItem {
  const ShopItem(this.id, this.slot, this.price);

  final String id;
  final ShopSlot slot;
  final int price;

  bool get free => price == 0;

  bool get acoustic => Shop.acousticGuitars.contains(id);

  String get name => switch (id) {
    'hat_bandana' => tr('Bandana', 'Bandana'),
    'hat_cap' => tr('Kappe', 'Cap'),
    'hat_beanie' => tr('Mütze', 'Beanie'),
    'hat_straw' => tr('Strohhut', 'Straw hat'),
    'hat_flowers' => tr('Blumenkranz', 'Flower crown'),
    'hat_headphones' => tr('Kopfhörer', 'Headphones'),
    'hat_cowboy' => tr('Cowboyhut', 'Cowboy hat'),
    'hat_tophat' => tr('Zylinder', 'Top hat'),
    'hat_viking' => tr('Wikingerhelm', 'Viking helmet'),
    'hat_crown' => tr('Rockstar-Krone', 'Rock star crown'),
    'glasses_nerd' => tr('Grosse Brille', 'Big glasses'),
    'glasses_sun' => tr('Sonnenbrille', 'Sunglasses'),
    'glasses_round' => tr('Runde Brille', 'Round glasses'),
    'glasses_heart' => tr('Herzbrille', 'Heart glasses'),
    'glasses_star' => tr('Sternenbrille', 'Star glasses'),
    'glasses_visor' => tr('Weltraum-Visier', 'Space visor'),
    'neck_scarf' => tr('Halstuch', 'Neckerchief'),
    'neck_peace' => tr('Peace-Kette', 'Peace necklace'),
    'neck_bowtie' => tr('Fliege', 'Bow tie'),
    'neck_lei' => tr('Blumenkette', 'Flower garland'),
    'neck_chain' => tr('Rock-Kette', 'Rock chain'),
    'vest_jeans' => tr('Jeansweste', 'Denim vest'),
    'vest_hawaii' => tr('Hawaiihemd', 'Hawaiian shirt'),
    'vest_leather' => tr('Lederweste', 'Leather vest'),
    'vest_fringe' => tr('Fransenweste', 'Fringe vest'),
    'vest_studded' => tr('Nietenweste', 'Studded vest'),
    'vest_tux' => tr('Gala-Jacke', 'Gala jacket'),
    'vest_space' => tr('Weltraum-Weste', 'Space vest'),
    'g_classic' => tr('Konzertgitarre', 'Classical guitar'),
    'g_pointy' => tr('Pfeil-Gitarre', 'Arrow guitar'),
    'g_double' => tr('Rock-Gitarre', 'Rock guitar'),
    'g_acoustic' => tr('Westerngitarre', 'Western guitar'),
    'g_double_blue' => tr('Himmelblaue Rock-Gitarre', 'Sky-blue rock guitar'),
    'g_pointy_pink' => tr('Pinke Pfeil-Gitarre', 'Pink arrow guitar'),
    'g_double_black' => tr('Schwarze Rock-Gitarre', 'Black rock guitar'),
    'g_acoustic_black' => tr('Schwarze Westerngitarre', 'Black western guitar'),
    'g_pointy_gold' => tr('Goldene Pfeil-Gitarre', 'Golden arrow guitar'),
    'g_jumbo' => tr('Country-Gitarre', 'Country guitar'),
    'g_flower' => tr('Blumen-Gitarre', 'Flower guitar'),
    'g_flame' => tr('Flammen-Gitarre', 'Flame guitar'),
    'g_archtop' => tr('Jazzgitarre', 'Jazz guitar'),
    'g_star' => tr('Sternen-Gitarre', 'Star guitar'),
    'g_vshape' => tr('V-Gitarre', 'V guitar'),
    'g_galaxy' => tr('Galaxie-Gitarre', 'Galaxy guitar'),
    'amp_mini' => tr('Übungs-Amp', 'Practice amp'),
    'amp_retro' => tr('Retro-Amp', 'Retro amp'),
    'amp_combo' => tr('Vintage-Amp', 'Vintage amp'),
    'amp_stack' => tr('Amp-Turm', 'Amp stack'),
    'amp_space' => tr('Weltraum-Amp', 'Space amp'),
    'pedal_shield' => tr('Schild-Pedal', 'Shield pedal'),
    'pedal_capo' => tr('Kapodaster', 'Capo'),
    'pedal_tuner' => tr('Stimmgerät', 'Tuner'),
    _ => id,
  };

  /// Kurze Erklärung unter dem Namen (Pedale, Gitarren, Amps).
  String get help => switch (slot) {
    ShopSlot.pedal => switch (id) {
      'pedal_shield' => tr('Wehrt einen falschen Ton ab. Einmal pro Level.', 'Blocks one wrong note. Once per level.'),
      'pedal_capo' => tr('Hält die Zeit für einen Ton an. Einmal pro Level.', 'Stops the clock for one note. Once per level.'),
      _ => tr(
        'Streicht zwei falsche Namen weg oder zeigt die Saite. Einmal pro Level.',
        'Removes two wrong names or shows the string. Once per level.',
      ),
    },
    ShopSlot.guitar => acoustic ? tr('Akustisch', 'Acoustic') : tr('E-Gitarre', 'Electric'),
    ShopSlot.amp => tr('Steht neben dir, wenn du E-Gitarre spielst.', 'Stands next to you when you play electric.'),
    _ => '',
  };
}

/// Ein Set zum Sammeln: mehrere Teile, die zusammenpassen. Wer alle hat,
/// bekommt ein Abzeichen und kann das ganze Set auf einmal anziehen.
class OutfitSet {
  const OutfitSet(this.id, this.items);

  final String id;
  final List<String> items;

  String get name => switch (id) {
    'rockstar' => tr('Rockstar', 'Rock star'),
    'country' => tr('Country', 'Country'),
    'flower' => tr('Flower-Power', 'Flower power'),
    'space' => tr('Weltall', 'Outer space'),
    'gala' => tr('Jazz-Gala', 'Jazz gala'),
    'metal' => tr('Heavy Metal', 'Heavy metal'),
    'beach' => tr('Strand', 'Beach'),
    _ => tr('Strasse', 'Street'),
  };

  List<ShopItem> get parts => [for (final i in items) Shop.byId(i)!];

  int ownedBy(Profile p) => parts.where((i) => Shop.owns(p, i)).length;

  bool completeFor(Profile p) => ownedBy(p) == items.length;

  /// Was alle noch fehlenden Teile zusammen kosten.
  int missingCost(Profile p) => parts.where((i) => !Shop.owns(p, i)).fold(0, (a, i) => a + i.price);
}

/// Alles, was es im Shop gibt.
class Shop {
  Shop._();

  /// Startgitarren: gratis, eine davon wählt man beim neuen Profil.
  static const starterAcoustic = 'g_classic';

  /// Akustische Gitarren (wie ACOUSTIC_GUITARS in tool/make_characters.py).
  static const acousticGuitars = {'g_classic', 'g_acoustic', 'g_acoustic_black', 'g_jumbo', 'g_flower'};

  static const items = [
    ShopItem('hat_bandana', ShopSlot.hat, 60),
    ShopItem('hat_cap', ShopSlot.hat, 70),
    ShopItem('hat_beanie', ShopSlot.hat, 80),
    ShopItem('hat_straw', ShopSlot.hat, 80),
    ShopItem('hat_flowers', ShopSlot.hat, 90),
    ShopItem('hat_headphones', ShopSlot.hat, 120),
    ShopItem('hat_cowboy', ShopSlot.hat, 120),
    ShopItem('hat_tophat', ShopSlot.hat, 140),
    ShopItem('hat_viking', ShopSlot.hat, 160),
    ShopItem('hat_crown', ShopSlot.hat, 600),
    ShopItem('glasses_nerd', ShopSlot.glasses, 60),
    ShopItem('glasses_sun', ShopSlot.glasses, 70),
    ShopItem('glasses_round', ShopSlot.glasses, 80),
    ShopItem('glasses_heart', ShopSlot.glasses, 80),
    ShopItem('glasses_star', ShopSlot.glasses, 90),
    ShopItem('glasses_visor', ShopSlot.glasses, 120),
    ShopItem('neck_scarf', ShopSlot.neck, 50),
    ShopItem('neck_peace', ShopSlot.neck, 60),
    ShopItem('neck_bowtie', ShopSlot.neck, 60),
    ShopItem('neck_lei', ShopSlot.neck, 70),
    ShopItem('neck_chain', ShopSlot.neck, 90),
    ShopItem('vest_jeans', ShopSlot.vest, 130),
    ShopItem('vest_hawaii', ShopSlot.vest, 140),
    ShopItem('vest_leather', ShopSlot.vest, 150),
    ShopItem('vest_fringe', ShopSlot.vest, 160),
    ShopItem('vest_studded', ShopSlot.vest, 170),
    ShopItem('vest_tux', ShopSlot.vest, 180),
    ShopItem('vest_space', ShopSlot.vest, 200),
    ShopItem('g_classic', ShopSlot.guitar, 0),
    ShopItem('g_pointy', ShopSlot.guitar, 0),
    ShopItem('g_double', ShopSlot.guitar, 0),
    ShopItem('g_acoustic', ShopSlot.guitar, 180),
    ShopItem('g_double_blue', ShopSlot.guitar, 180),
    ShopItem('g_pointy_pink', ShopSlot.guitar, 180),
    ShopItem('g_double_black', ShopSlot.guitar, 200),
    ShopItem('g_acoustic_black', ShopSlot.guitar, 200),
    ShopItem('g_pointy_gold', ShopSlot.guitar, 250),
    ShopItem('g_jumbo', ShopSlot.guitar, 260),
    ShopItem('g_flower', ShopSlot.guitar, 280),
    ShopItem('g_flame', ShopSlot.guitar, 300),
    ShopItem('g_archtop', ShopSlot.guitar, 320),
    ShopItem('g_star', ShopSlot.guitar, 350),
    ShopItem('g_vshape', ShopSlot.guitar, 380),
    ShopItem('g_galaxy', ShopSlot.guitar, 450),
    ShopItem('amp_mini', ShopSlot.amp, 100),
    ShopItem('amp_retro', ShopSlot.amp, 180),
    ShopItem('amp_combo', ShopSlot.amp, 220),
    ShopItem('amp_stack', ShopSlot.amp, 400),
    ShopItem('amp_space', ShopSlot.amp, 450),
    ShopItem('pedal_shield', ShopSlot.pedal, 120),
    ShopItem('pedal_capo', ShopSlot.pedal, 150),
    ShopItem('pedal_tuner', ShopSlot.pedal, 150),
  ];

  static const sets = [
    OutfitSet('street', ['hat_cap', 'glasses_nerd', 'vest_jeans', 'amp_retro']),
    OutfitSet('beach', ['hat_straw', 'glasses_heart', 'neck_lei', 'vest_hawaii']),
    OutfitSet('flower', ['hat_flowers', 'glasses_round', 'neck_peace', 'g_flower']),
    OutfitSet('country', ['hat_cowboy', 'neck_scarf', 'vest_fringe', 'g_jumbo']),
    OutfitSet('gala', ['hat_tophat', 'neck_bowtie', 'vest_tux', 'g_archtop']),
    OutfitSet('metal', ['hat_viking', 'neck_chain', 'vest_studded', 'g_vshape', 'amp_stack']),
    OutfitSet('space', ['glasses_visor', 'vest_space', 'g_galaxy', 'amp_space']),
    OutfitSet('rockstar', ['hat_crown', 'glasses_star', 'vest_leather', 'g_star']),
  ];

  static ShopItem? byId(String id) => items.where((i) => i.id == id).firstOrNull;

  static List<ShopItem> inSlot(ShopSlot slot) => items.where((i) => i.slot == slot).toList();

  /// Zu welchem Set ein Teil gehört (oder null).
  static OutfitSet? setOf(String itemId) => sets.where((s) => s.items.contains(itemId)).firstOrNull;

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

  /// Ein Set anziehen: nur die Teile, die schon gehören.
  static CharacterLook wearSet(Profile p, OutfitSet set, {bool all = false}) {
    var look = p.look;
    for (final i in set.parts) {
      if (all || owns(p, i)) look = look.wear(i.slot.name, i.id);
    }
    return look;
  }
}
