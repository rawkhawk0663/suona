import '../character/look.dart';

export '../character/look.dart' show Character, CharacterLook;
import '../game/note_stats.dart';
import '../game/rewards.dart';
import '../music/curriculum.dart';

/// Ein Spielprofil. Bewusst ohne echten Namen, Alter oder Foto:
/// nur Spitzname und Figur (Kinderschutz).
class Profile {
  Profile({
    required this.id,
    required this.nickname,
    required this.character,
    this.curriculumId = BuiltInCurricula.guitarTalksId,
    this.step = 0,
    this.coins = 0,
    DailyStreak? streak,
    NoteStats? stats,
    int arcadeBest = 0,
    Map<String, int>? arcadeBests,
    this.totalCorrect = 0,
    this.roundsPlayed = 0,
    CharacterLook? look,
    Set<String>? owned,
    Map<String, List<List<int>>>? adventure,
    DateTime? created,
  }) : _look = look, // ignore: prefer_initializing_formals
       owned = owned ?? {},
       adventure = adventure ?? {},
       streak = streak ?? DailyStreak(),
       stats = stats ?? NoteStats(),
       arcadeBests = (arcadeBests == null || arcadeBests.isEmpty)
           ? {if (arcadeBest > 0) 'name': arcadeBest}
           : arcadeBests,
       created = created ?? DateTime.now();

  final String id;
  String nickname;
  Character character;

  /// Lehrplan und wie weit das Kind darin ist (Schritt, 0-basiert, inklusive).
  String curriculumId;
  int step;

  int coins;
  final DailyStreak streak;
  final NoteStats stats;

  /// Arcade-Rekorde pro Spielart (Schlüssel wie `ArcadeAnswer.name`).
  final Map<String, int> arcadeBests;

  /// Bester Rekord über alle Arcade-Arten.
  int get arcadeBest => arcadeBests.values.fold(0, (a, b) => a > b ? a : b);

  int totalCorrect;
  int roundsPlayed;
  final DateTime created;

  /// Gekaufte Shop-Teile (IDs wie `hat_beanie`, `g_star`, `pedal_shield`).
  final Set<String> owned;

  /// Sterne im Abenteuer pro Lehrplan: 8 Stationen × 6 Level, 0 = noch nicht geschafft.
  final Map<String, List<List<int>>> adventure;

  CharacterLook? _look;

  /// Aussehen. Passt es nicht zur Figur (Figur gewechselt), gilt der Grund-Look.
  CharacterLook get look {
    final l = _look;
    return l != null && l.character == character ? l : CharacterLook.defaults(character);
  }

  set look(CharacterLook value) => _look = value;

  Map<String, dynamic> toJson() => {
    'format': 'suona-profil',
    'version': 1,
    'id': id,
    'nickname': nickname,
    'character': character.name,
    'curriculum': curriculumId,
    'step': step,
    'coins': coins,
    'streak': streak.toJson(),
    'stats': stats.toJson(),
    'arcadeBests': arcadeBests,
    'totalCorrect': totalCorrect,
    'roundsPlayed': roundsPlayed,
    'look': look.toJson(),
    'owned': owned.toList()..sort(),
    'adventure': adventure,
    'created': created.toIso8601String(),
  };

  static Profile fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String,
    nickname: j['nickname'] as String? ?? '?',
    character: Character.values.asNameMap()[j['character']] ?? Character.luna,
    curriculumId: j['curriculum'] as String? ?? BuiltInCurricula.guitarTalksId,
    step: (j['step'] as num?)?.toInt() ?? 0,
    coins: (j['coins'] as num?)?.toInt() ?? 0,
    streak: DailyStreak.fromJson(j['streak'] as Map<String, dynamic>?),
    stats: NoteStats.fromJson(j['stats'] as Map<String, dynamic>?),
    arcadeBest: (j['arcadeBest'] as num?)?.toInt() ?? 0,
    arcadeBests: {
      for (final e in ((j['arcadeBests'] as Map<String, dynamic>?) ?? const {}).entries)
        e.key: (e.value as num).toInt(),
    },
    totalCorrect: (j['totalCorrect'] as num?)?.toInt() ?? 0,
    roundsPlayed: (j['roundsPlayed'] as num?)?.toInt() ?? 0,
    look: j['look'] is Map<String, dynamic>
        ? CharacterLook.fromJson(
            j['look'] as Map<String, dynamic>,
            Character.values.asNameMap()[j['character']] ?? Character.luna,
          )
        : null,
    owned: {for (final x in (j['owned'] as List<dynamic>? ?? const [])) x.toString()},
    adventure: {
      for (final e in ((j['adventure'] as Map<String, dynamic>?) ?? const {}).entries)
        e.key: [
          for (final st in (e.value as List<dynamic>)) [for (final v in (st as List<dynamic>)) (v as num).toInt()],
        ],
    },
    created: DateTime.tryParse(j['created'] as String? ?? ''),
  );
}
