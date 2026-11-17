import '../../app/l10n.dart';
import '../profiles/profile.dart';
import 'adventure.dart';
import 'chord_adventure.dart';
import 'shop.dart';

/// Ein Abzeichen. Wird aus dem Spielstand berechnet, nicht gespeichert.
class Badge {
  const Badge(this.id, this.name, this.help, this.earned);
  final String id;
  final String name;
  final String help;
  final bool earned;
}

/// Alle Abzeichen eines Profils (für seinen aktuellen Lehrplan).
List<Badge> badgesOf(Profile p) {
  final cid = p.curriculumId;
  final progress = Adventure.progressOf(p, cid);
  bool stationDone(int s) => progress[s][Adventure.concertLevel] > 0;
  final anyPerfect = progress.any((row) => row.every((s) => s == 3));
  return [
    Badge(
      'first',
      tr('Erste Runde', 'First round'),
      tr('Eine Runde fertig gespielt', 'Finished a round'),
      p.roundsPlayed >= 1,
    ),
    Badge('notes100', tr('100 Töne', '100 notes'), tr('100 Töne richtig', '100 notes right'), p.totalCorrect >= 100),
    Badge('notes500', tr('500 Töne', '500 notes'), tr('500 Töne richtig', '500 notes right'), p.totalCorrect >= 500),
    Badge(
      'notes1000',
      tr('1000 Töne', '1000 notes'),
      tr('1000 Töne richtig', '1000 notes right'),
      p.totalCorrect >= 1000,
    ),
    Badge(
      'streak7',
      tr('Eine Woche', 'One week'),
      tr('7 Tage in Folge geübt', 'Practised 7 days in a row'),
      p.streak.best >= 7,
    ),
    Badge(
      'streak30',
      tr('Ein Monat', 'One month'),
      tr('30 Tage in Folge geübt', 'Practised 30 days in a row'),
      p.streak.best >= 30,
    ),
    Badge(
      'arcade200',
      tr('Arcade-Profi', 'Arcade pro'),
      tr('200 Münzen in einer Arcade-Runde', '200 coins in one arcade game'),
      p.arcadeBest >= 200,
    ),
    Badge(
      'perfect',
      tr('Alle Sterne', 'All stars'),
      tr('Eine Station mit lauter 3 Sternen', 'A station with all 3 stars'),
      anyPerfect,
    ),
    for (var s = 0; s < Adventure.stationCount; s++)
      Badge(
        'station$s',
        Adventure.stationName(s),
        tr(
          'Auftritt in „${Adventure.stationName(s)}“ geschafft',
          'Played the concert at “${Adventure.stationName(s)}”',
        ),
        stationDone(s),
      ),
    for (var s = 0; s < ChordTour.stationCount; s++)
      Badge(
        'chord$s',
        tr('Tour: ${ChordTour.stationName(s)}', 'Tour: ${ChordTour.stationName(s)}'),
        tr(
          'Akkord-Tour: „${ChordTour.stationName(s)}“ begleitet',
          'Chord tour: played along at “${ChordTour.stationName(s)}”',
        ),
        ChordTour.stationDone(p, p.chordCurriculumId, s),
      ),
    for (final set in Shop.sets)
      Badge(
        'set_${set.id}',
        tr('Set ${set.name}', '${set.name} set'),
        tr('Alle Teile vom Set „${set.name}“ gesammelt', 'Collected every part of the “${set.name}” set'),
        set.completeFor(p),
      ),
  ];
}
