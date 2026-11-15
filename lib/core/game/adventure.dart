import 'dart:math';

import '../../app/l10n.dart';
import '../music/curriculum.dart';
import '../music/note_names.dart';
import '../music/pitch.dart';
import '../profiles/profile.dart';
import '../suona_state.dart';
import 'difficulty.dart';
import 'question.dart';

/// Ein Level im Abenteuer, fertig zum Spielen.
class LevelPlan {
  const LevelPlan({
    required this.station,
    required this.level,
    required this.pool,
    required this.focus,
    required this.types,
    required this.length,
    required this.timeLimit,
    required this.crowdLoss,
    required this.crowdGain,
  });

  final int station;
  final int level;
  final List<Pitch> pool;
  final Set<Pitch> focus;
  final List<QuestionType> types;
  final int length;
  final Duration? timeLimit;

  /// Wie viel Stimmung ein Fehler kostet.
  final double crowdLoss;

  /// Wie viel Stimmung ein richtiger Ton bringt.
  final double crowdGain;

  bool get isConcert => level == Adventure.concertLevel;
}

/// Die Reise vom Kinderzimmer ins Stadion.
///
/// Acht Stationen, jede mit fünf Levels und einem Auftritt. Welche Töne eine
/// Station bringt, bestimmt der Lehrplan des Profils: Die Schritte werden
/// gleichmässig auf die Stationen verteilt. Eine Station öffnet sich, wenn der
/// Auftritt der vorigen geschafft ist und die Lehrperson das Kind im Lehrplan
/// bis dorthin gesetzt hat (die neuen Töne kommen zuerst im Unterricht).
class Adventure {
  Adventure._();

  static const stationCount = 8;
  static const levelsPerStation = 6;
  static const concertLevel = 5;

  /// Stimmung des Publikums am Anfang.
  static const crowdStart = 0.6;

  static String stationName(int s) => switch (s) {
    0 => tr('Kinderzimmer', 'Bedroom'),
    1 => tr('Garage', 'Garage'),
    2 => tr('Schulaula', 'School hall'),
    3 => tr('Jugendclub', 'Youth club'),
    4 => tr('Stadtfest', 'Town fair'),
    5 => tr('Tonstudio', 'Recording studio'),
    6 => tr('Festival', 'Festival'),
    _ => tr('Stadion', 'Stadium'),
  };

  static String levelName(int l) => switch (l) {
    0 => tr('Aufwärmen', 'Warm-up'),
    1 => tr('Probe', 'Rehearsal'),
    2 => tr('Griffbrett', 'Fretboard'),
    3 => tr('Welcher Ton?', 'Which note?'),
    4 => tr('Generalprobe', 'Dress rehearsal'),
    _ => tr('Auftritt', 'Concert'),
  };

  /// Welche Lehrplan-Schritte (von, bis, inklusive) zu einer Station gehören.
  static (int, int) stepsOf(int station, int stepCount) {
    final n = max(1, stepCount);
    final from = (station * n / stationCount).floor().clamp(0, n - 1);
    final to = max(from, ((station + 1) * n / stationCount).floor() - 1).clamp(0, n - 1);
    return (from, to);
  }

  /// Sterne aller Level dieses Lehrplans (8 × 6, 0 = noch nicht geschafft).
  static List<List<int>> progressOf(Profile p, String curriculumId) {
    final list = p.adventure.putIfAbsent(curriculumId, () => []);
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

  /// Warum eine Station (noch) zu ist; null = offen.
  static StationLock? lockOf(Profile p, Curriculum c, int station) {
    if (station == 0) return null;
    if (!stationDone(p, c.id, station - 1)) return StationLock.previous;
    final (from, _) = stepsOf(station, c.steps.length);
    if (p.step < from) return StationLock.teacher;
    return null;
  }

  static bool levelOpen(Profile p, Curriculum c, int station, int level) {
    if (lockOf(p, c, station) != null) return false;
    return level == 0 || stars(p, c.id, station, level - 1) > 0;
  }

  /// Sterne im Abenteuer: strenger als beim Üben, damit der Weg zählt.
  static int starsForRound(int correct, int total) {
    if (total == 0) return 0;
    final q = correct / total;
    if (q >= 0.9) return 3;
    if (q >= 0.75) return 2;
    if (q >= 0.6) return 1;
    return 0;
  }

  /// Ergebnis eintragen (es zählt das beste). Gibt true zurück, wenn das
  /// Level zum ersten Mal geschafft wurde.
  static bool record(Profile p, String cid, int station, int level, int stars) {
    final row = progressOf(p, cid)[station];
    final first = row[level] == 0 && stars > 0;
    row[level] = max(row[level], stars);
    return first;
  }

  /// Zusatzmünzen beim ersten Schaffen: Auftritte geben mehr.
  static int firstClearBonus(int level) => level == concertLevel ? 50 : 15;

  /// Sekunden pro Ton: wird mit jeder Station knapper (Grundzeit 12 s bis
  /// 5 s), angepasst an die Stufe. Die Jüngsten haben länger ganz ohne Zeit.
  static Duration? timeFor(int station, int level, [Difficulty d = Difficulty.teen]) {
    final secs = 12 - station;
    final base = switch (level) {
      0 => null,
      1 => station < d.untimedRehearsal ? null : secs,
      2 || 3 => station < d.untimedFretboard ? null : secs + 2,
      4 => secs,
      _ => max(4, secs - 1),
    };
    if (base == null) return null;
    return Duration(seconds: max(3, (base * d.timeFactor).round()));
  }

  /// Wie viele Töne ein Level hat.
  static int lengthOf(int level, [Difficulty d = Difficulty.teen]) => switch (level) {
    0 => d.shorter ? 6 : 8,
    concertLevel => d.shorter ? 12 : 15,
    _ => d.shorter ? 8 : 10,
  };

  static LevelPlan plan(
    Curriculum c,
    AccidentalStyle style,
    int station,
    int level, [
    Difficulty d = Difficulty.teen,
  ]) {
    final (from, to) = stepsOf(station, c.steps.length);
    final fresh = <Pitch>{for (var i = from; i <= to; i++) ...c.steps[i].notes};
    final freshStyled = applyAccidentalStyle(fresh.toList(), style);
    final all = applyAccidentalStyle(c.notesUpTo(to), style);
    final types = switch (level) {
      0 || 1 => const [QuestionType.nameFromStaff],
      2 => const [QuestionType.fretFromStaff],
      3 => const [QuestionType.nameFromFret],
      _ => QuestionType.values,
    };
    // Aufwärmen nur mit den neuen Tönen (wenn es genug sind).
    final pool = level == 0 && freshStyled.length >= 2 ? freshStyled : all;
    return LevelPlan(
      station: station,
      level: level,
      pool: pool,
      focus: freshStyled.toSet(),
      types: types,
      length: lengthOf(level, d),
      timeLimit: timeFor(station, level, d),
      // Am Anfang verzeiht das Publikum mehr, später weniger. Die Stufe
      // macht es geduldiger oder strenger.
      crowdLoss: (0.14 + station * 0.01 + (level == concertLevel ? 0.04 : 0)) * d.lossFactor,
      crowdGain: d.gain,
    );
  }
}

enum StationLock {
  /// Zuerst den Auftritt der vorigen Station schaffen.
  previous,

  /// Die Lehrperson schaltet die nächsten Töne frei (Lehrplan-Schritt).
  teacher,
}
