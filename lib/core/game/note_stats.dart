import 'dart:math';

import '../music/pitch.dart';

/// Wie gut ein Kind einen Ton kennt (Lernkartei mit 6 Fächern).
///
/// Richtig: ein Fach höher. Falsch: zurück auf Fach 0. Töne in tiefen
/// Fächern kommen öfter dran.
class NoteStat {
  NoteStat({this.seen = 0, this.correct = 0, this.box = 0});

  int seen;
  int correct;
  int box;

  static const maxBox = 5;

  Map<String, dynamic> toJson() => {'seen': seen, 'correct': correct, 'box': box};

  static NoteStat fromJson(Map<String, dynamic> j) => NoteStat(
    seen: (j['seen'] as num?)?.toInt() ?? 0,
    correct: (j['correct'] as num?)?.toInt() ?? 0,
    box: (j['box'] as num?)?.toInt() ?? 0,
  );
}

/// Lernstand aller Töne eines Profils.
class NoteStats {
  NoteStats([Map<String, NoteStat>? map]) : map = map ?? {};

  final Map<String, NoteStat> map;

  /// [prefix] trennt Wissensarten: '' = Notenlesen, 'G:' = Griffbrett.
  NoteStat of(Pitch p, {String prefix = ''}) => map['$prefix${p.key}'] ?? NoteStat();

  void record(Pitch p, {required bool correct, String prefix = ''}) {
    final s = map.putIfAbsent('$prefix${p.key}', NoteStat.new);
    s.seen++;
    if (correct) {
      s.correct++;
      s.box = min(NoteStat.maxBox, s.box + 1);
    } else {
      s.box = 0;
    }
  }

  /// Wie oft ein Ton drankommt: unsichere Töne öfter.
  double weightOf(Pitch p, {String prefix = ''}) {
    final s = map['$prefix${p.key}'];
    if (s == null) return 3.0; // noch nie gesehen: eher bald zeigen
    return 1.0 + (NoteStat.maxBox - s.box) * 1.2;
  }

  Map<String, dynamic> toJson() => {for (final e in map.entries) e.key: e.value.toJson()};

  static NoteStats fromJson(Map<String, dynamic>? j) =>
      NoteStats({for (final e in (j ?? const {}).entries) e.key: NoteStat.fromJson(e.value as Map<String, dynamic>)});
}

/// Wählt den nächsten Ton aus einem Vorrat.
class NotePicker {
  NotePicker({required this.pool, required this.stats, this.focus = const {}, this.prefix = '', Random? random})
    : _random = random ?? Random(),
      assert(pool.isNotEmpty);

  final List<Pitch> pool;
  final NoteStats stats;

  /// Neue Töne (aktueller Schritt im Lehrplan): kommen doppelt so oft.
  final Set<Pitch> focus;

  /// Welcher Teil der Lernkartei zählt ('' = Notenlesen, 'G:' = Griffbrett).
  final String prefix;
  final Random _random;
  Pitch? _last;

  /// Nächster Ton. [avoid]: zusätzlich nicht diesen (z. B. den letzten Ton
  /// einer anderen Fragenart, damit nie derselbe Ton zweimal hintereinander kommt).
  Pitch next({Pitch? avoid}) {
    var candidates = pool.where((p) => p != _last && p != avoid).toList();
    if (candidates.isEmpty) candidates = pool.where((p) => p != _last).toList();
    if (candidates.isEmpty) candidates = pool;
    final weights = [for (final p in candidates) stats.weightOf(p, prefix: prefix) * (focus.contains(p) ? 2.0 : 1.0)];
    final total = weights.fold<double>(0, (a, b) => a + b);
    var r = _random.nextDouble() * total;
    for (var i = 0; i < candidates.length; i++) {
      r -= weights[i];
      if (r <= 0) return _last = candidates[i];
    }
    return _last = candidates.last;
  }
}
