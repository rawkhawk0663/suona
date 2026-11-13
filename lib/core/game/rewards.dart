import 'dart:math';

/// Münzen für eine richtige Antwort, abhängig von der Serie richtiger
/// Antworten in Folge (Combo).
class Combo {
  int streak = 0;

  /// Faktor: ×1, ab 5 in Folge ×2, ab 10 in Folge ×3.
  int get multiplier => streak >= 10 ? 3 : (streak >= 5 ? 2 : 1);

  static const baseCoins = 5;

  /// Richtige Antwort: gibt die verdienten Münzen zurück.
  int hit() {
    streak++;
    return baseCoins * multiplier;
  }

  void miss() => streak = 0;
}

/// Sterne für eine Übungsrunde nach dem Anteil richtiger Antworten.
int starsFor(int correct, int total) {
  if (total == 0) return 0;
  final q = correct / total;
  if (q >= 0.9) return 3;
  if (q >= 0.7) return 2;
  if (q >= 0.4) return 1;
  return 0;
}

/// Zusatzmünzen für Sterne am Ende einer Runde.
int bonusForStars(int stars) => const [0, 5, 10, 20][stars.clamp(0, 3)];

/// Was beim Eintragen eines Übungstags passiert ist.
enum StreakEvent {
  /// Heute wurde schon geübt.
  alreadyToday,

  /// Erster Tag oder Neustart nach einer Pause.
  started,

  /// Gestern geübt, heute wieder: weiter.
  continued,

  /// Ein Tag fehlte, der Streak-Schutz hat die Serie gerettet.
  savedByShield,
}

/// Tages-Streak: an wie vielen Tagen in Folge geübt wurde.
///
/// Wer einen Tag verpasst, verliert nichts ausser der Zählung. Ein
/// Streak-Schutz (alle 7 Tage einer, höchstens 2) rettet einen verpassten
/// Tag automatisch. So entsteht kein Druck.
class DailyStreak {
  DailyStreak({this.days = 0, this.lastDay, this.shields = 0, this.best = 0});

  int days;

  /// Letzter Übungstag als „JJJJ-MM-TT“.
  String? lastDay;
  int shields;
  int best;

  static const maxShields = 2;
  static const shieldEvery = 7;

  /// Zählt die Serie heute noch (zuletzt heute oder gestern geübt, oder
  /// genug Schutz für die Lücke)?
  int currentDays(DateTime now) {
    final last = _parse(lastDay);
    if (last == null) return 0;
    final gap = _dayIndex(now) - _dayIndex(last);
    if (gap <= 1) return days;
    if (gap - 1 <= shields) return days;
    return 0;
  }

  bool practicedOn(DateTime now) => lastDay == dayKey(now);

  StreakEvent registerPractice(DateTime now) {
    final today = dayKey(now);
    if (lastDay == today) return StreakEvent.alreadyToday;
    final last = _parse(lastDay);
    StreakEvent event;
    if (last == null) {
      days = 1;
      event = StreakEvent.started;
    } else {
      final gap = _dayIndex(now) - _dayIndex(last);
      final missed = gap - 1;
      if (gap == 1) {
        days++;
        event = StreakEvent.continued;
      } else if (missed >= 1 && missed <= shields) {
        shields -= missed;
        days++;
        event = StreakEvent.savedByShield;
      } else {
        days = 1;
        event = StreakEvent.started;
      }
    }
    if (days % shieldEvery == 0) shields = min(maxShields, shields + 1);
    best = max(best, days);
    lastDay = today;
    return event;
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parse(String? key) {
    if (key == null) return null;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]), m = int.tryParse(parts[1]), d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Tage seit 1970, unabhängig von Sommerzeit.
  static int _dayIndex(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  Map<String, dynamic> toJson() => {'days': days, 'lastDay': lastDay, 'shields': shields, 'best': best};

  static DailyStreak fromJson(Map<String, dynamic>? j) => DailyStreak(
    days: (j?['days'] as num?)?.toInt() ?? 0,
    lastDay: j?['lastDay'] as String?,
    shields: (j?['shields'] as num?)?.toInt() ?? 0,
    best: (j?['best'] as num?)?.toInt() ?? 0,
  );
}
