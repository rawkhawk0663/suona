import 'dart:math';

import '../../app/l10n.dart';
import '../music/chords.dart';
import '../profiles/profile.dart';
import 'adventure.dart';
import 'difficulty.dart';

/// Was bei einer Akkord-Frage verlangt ist.
enum ChordTask {
  /// Griffbild sehen, Namen tippen.
  name,

  /// Namen sehen, Griff ins Griffbild tippen.
  build,

  /// Akkord als Notenstapel sehen, Namen tippen.
  staff;

  /// Teil der Lernkartei: Erkennen ('A:') oder Griff bauen ('AG:').
  String get statsPrefix => this == ChordTask.build ? 'AG:' : 'A:';

  String get label => switch (this) {
    ChordTask.name => tr('Welcher Akkord?', 'Which chord?'),
    ChordTask.build => tr('Griff bauen', 'Build the shape'),
    ChordTask.staff => tr('Aus den Noten', 'From the notes'),
  };
}

/// Ein Level der Akkord-Tour, fertig zum Spielen.
class ChordLevelPlan {
  const ChordLevelPlan({
    required this.station,
    required this.level,
    required this.pool,
    required this.focus,
    required this.tasks,
    required this.length,
    required this.timeLimit,
    required this.crowdLoss,
    required this.crowdGain,
    required this.strings,
    this.alternate = false,
    this.song = false,
  });

  final int station;
  final int level;
  final List<Chord> pool;
  final Set<Chord> focus;
  final List<ChordTask> tasks;
  final int length;
  final Duration? timeLimit;
  final double crowdLoss;
  final double crowdGain;

  /// Saiten im Griffbild.
  final int strings;

  /// Wechsel-Training: zwei Akkorde immer abwechselnd.
  final bool alternate;

  /// Auftritt: ein erfundenes Lied mit Takten begleiten.
  final bool song;

  bool get isConcert => level == ChordTour.concertLevel;
}

/// Die Akkord-Tour: mit dem Tourbus vom Lagerfeuer bis zum grossen Finale.
///
/// Gleich aufgebaut wie das Noten-Abenteuer ([Adventure]): acht Etappen mit
/// je fünf Levels und einem Auftritt. Die Schritte des Akkord-Lehrplans werden
/// auf die Etappen verteilt, eine Etappe öffnet sich erst, wenn die Lehrperson
/// das Kind im Akkord-Lehrplan so weit gesetzt hat.
class ChordTour {
  ChordTour._();

  static const stationCount = Adventure.stationCount;
  static const levelsPerStation = Adventure.levelsPerStation;
  static const concertLevel = Adventure.concertLevel;

  static String stationName(int s) => switch (s) {
    0 => tr('Lagerfeuer', 'Campfire'),
    1 => tr('Pausenplatz', 'Playground'),
    2 => tr('Strassenmusik', 'Busking'),
    3 => tr('Zeltlager', 'Summer camp'),
    4 => tr('Strandparty', 'Beach party'),
    5 => tr('Musical-Bühne', 'Musical stage'),
    6 => tr('Open-Air', 'Open air'),
    _ => tr('Grosses Finale', 'Grand finale'),
  };

  static String levelName(int l) => switch (l) {
    0 => tr('Aufwärmen', 'Warm-up'),
    1 => tr('Griff bauen', 'Build the shape'),
    2 => tr('Aus den Noten', 'From the notes'),
    3 => tr('Wechsel', 'Changes'),
    4 => tr('Generalprobe', 'Dress rehearsal'),
    _ => tr('Lied begleiten', 'Play along'),
  };

  /// Sterne aller Level dieses Lehrplans (8 × 6, 0 = noch nicht geschafft).
  static List<List<int>> progressOf(Profile p, String curriculumId) {
    final list = p.chordAdventure.putIfAbsent(curriculumId, () => []);
    while (list.length < stationCount) {
      list.add(List.filled(levelsPerStation, 0));
    }
    for (var i = 0; i < list.length; i++) {
      if (list[i].length < levelsPerStation) {
        list[i] = [...list[i], ...List.filled(levelsPerStation - list[i].length, 0)];
      }
    }
    return list;
  }

  static int stars(Profile p, String cid, int station, int level) => progressOf(p, cid)[station][level];

  static bool stationDone(Profile p, String cid, int station) => stars(p, cid, station, concertLevel) > 0;

  /// Warum eine Etappe (noch) zu ist; null = offen.
  static StationLock? lockOf(Profile p, ChordCurriculum c, int station) {
    if (station == 0) return null;
    if (!stationDone(p, c.id, station - 1)) return StationLock.previous;
    final (from, _) = Adventure.stepsOf(station, c.steps.length);
    if (p.chordStep < from) return StationLock.teacher;
    return null;
  }

  static bool levelOpen(Profile p, ChordCurriculum c, int station, int level) {
    if (lockOf(p, c, station) != null) return false;
    return level == 0 || stars(p, c.id, station, level - 1) > 0;
  }

  /// Ergebnis eintragen (das beste zählt). True beim ersten Schaffen.
  static bool record(Profile p, String cid, int station, int level, int stars) {
    final row = progressOf(p, cid)[station];
    final first = row[level] == 0 && stars > 0;
    row[level] = max(row[level], stars);
    return first;
  }

  /// Sekunden pro Akkord. Einen Griff zu bauen braucht länger als ihn zu
  /// erkennen (Grundzeit 12 s bis 8,5 s); mit jeder Etappe wird es knapper,
  /// angepasst an die Stufe.
  static Duration? timeFor(int station, int level, [Difficulty d = Difficulty.teen]) {
    final recognise = 10 - station * 0.75;
    final build = 12 - station * 0.5;
    final double? base = switch (level) {
      0 => null,
      1 => station < d.untimedRehearsal ? null : build,
      2 => station < d.untimedFretboard ? null : recognise + 2,
      3 => build - 2,
      4 => build - 1,
      _ => build - 1,
    };
    if (base == null) return null;
    return Duration(seconds: max(4, (base * d.timeFactor).round()));
  }

  static ChordLevelPlan plan(ChordCurriculum c, int station, int level, [Difficulty d = Difficulty.teen]) {
    if (c.steps.isEmpty) {
      return ChordLevelPlan(
        station: station,
        level: level,
        pool: const [],
        focus: const {},
        tasks: const [ChordTask.name],
        length: 0,
        timeLimit: null,
        crowdLoss: 0.2,
        crowdGain: 0.08,
        strings: 3,
      );
    }
    final (from, to) = Adventure.stepsOf(station, c.steps.length);
    final fresh = <Chord>{
      for (var i = from; i <= to; i++)
        for (final ch in c.steps[i].chordList) ch,
    };
    final all = c.chordsUpTo(to);
    final tasks = switch (level) {
      0 => const [ChordTask.name],
      1 || 3 => const [ChordTask.build],
      2 => const [ChordTask.staff],
      4 => ChordTask.values,
      _ => const [ChordTask.build],
    };
    // Aufwärmen nur mit den neuen Akkorden (wenn es genug sind), Wechsel mit zwei.
    var pool = all;
    if (level == 0 && fresh.length >= 2) pool = fresh.toList();
    if (level == 3) pool = _pairFor(fresh.toList(), all);
    return ChordLevelPlan(
      station: station,
      level: level,
      pool: pool,
      focus: fresh,
      tasks: tasks,
      length: Adventure.lengthOf(level, d),
      timeLimit: timeFor(station, level, d),
      crowdLoss: (0.14 + station * 0.01 + (level == concertLevel ? 0.04 : 0)) * d.lossFactor,
      crowdGain: d.gain,
      strings: c.stringsAt(to),
      alternate: level == 3,
      song: level == concertLevel,
    );
  }

  /// Zwei Akkorde für das Wechsel-Training: die neuesten, sonst ein neuer
  /// und der zuletzt gelernte davor.
  static List<Chord> _pairFor(List<Chord> fresh, List<Chord> all) {
    if (fresh.length >= 2) return fresh.sublist(fresh.length - 2);
    final older = all.where((c) => !fresh.contains(c)).toList();
    if (fresh.length == 1 && older.isNotEmpty) return [older.last, fresh.first];
    return all.length >= 2 ? all.sublist(all.length - 2) : all;
  }
}

/// Ein erfundenes Lied zum Begleiten: Titel und Akkorde pro Takt.
/// Nur eigene Akkordfolgen, keine echten Lieder und keine Texte (Urheberrecht).
class Song {
  const Song(this.title, this.bars);

  final String title;
  final List<Chord> bars;

  static List<String> get _titles => [
    tr('Lagerfeuer-Blues', 'Campfire Blues'),
    tr('Tourbus-Boogie', 'Tour Bus Boogie'),
    tr('Sonnenschein-Song', 'Sunshine Song'),
    tr('Sternschnuppen-Lied', 'Shooting Star Song'),
    tr('Pausenglocke', 'School Bell Song'),
    tr('Regenbogen-Rock', 'Rainbow Rock'),
    tr('Marshmallow-Walzer', 'Marshmallow Waltz'),
    tr('Strand-Ballade', 'Beach Ballad'),
    tr('Mondschein-Melodie', 'Moonlight Melody'),
    tr('Ferien-Hymne', 'Holiday Anthem'),
  ];

  /// Ein Lied mit [length] Takten aus dem Vorrat, die neuen Akkorde kommen
  /// öfter vor. Zwei gleiche Takte folgen nie aufeinander: Es geht ums Wechseln.
  static Song generate(List<Chord> pool, Set<Chord> focus, int length, [Random? random]) {
    final r = random ?? Random();
    final title = _titles[r.nextInt(_titles.length)];
    if (pool.isEmpty) return Song(title, const []);
    if (pool.length == 1) return Song(title, List.filled(length, pool.first));
    // Bis zu vier Akkorde fürs Lied: neue zuerst, dann bekannte.
    final chosen = <Chord>[...focus.where(pool.contains)]..shuffle(r);
    final rest = pool.where((c) => !chosen.contains(c)).toList()..shuffle(r);
    chosen.addAll(rest);
    final used = chosen.take(4).toList();
    if (used.length == 1) used.add(rest.isNotEmpty ? rest.first : pool.first);
    // Strophe aus Vierer-Phrasen wie A B A C, damit es nach einem Lied klingt.
    final a = used[0], b = used[1], c = used.length > 2 ? used[2] : used[0], d = used.length > 3 ? used[3] : used[1];
    final patterns = [
      [a, b, a, b],
      [a, c, b, a],
      [b, a, d, b],
      [a, b, c, d],
      [c, a, b, a],
    ];
    final bars = <Chord>[];
    while (bars.length < length) {
      for (final ch in patterns[r.nextInt(patterns.length)]) {
        if (bars.length >= length) break;
        // Nie zweimal derselbe Akkord hintereinander.
        if (bars.isNotEmpty && bars.last == ch) {
          bars.add(used.firstWhere((x) => x != ch));
        } else {
          bars.add(ch);
        }
      }
    }
    return Song(title, bars);
  }
}
