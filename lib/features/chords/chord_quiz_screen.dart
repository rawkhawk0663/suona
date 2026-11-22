import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/audio/sounds.dart';
import '../../core/game/adventure.dart';
import '../../core/game/chord_adventure.dart';
import '../../core/game/rewards.dart';
import '../../core/music/chords.dart';
import '../../core/music/guitar.dart';
import '../../core/music/note_names.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/chord_board.dart';
import '../../widgets/game_parts.dart';
import '../../widgets/visuals.dart';
import '../../widgets/staff.dart';
import '../quiz/quiz_screen.dart' show LifePick, PedalButton;
import '../quiz/result_screen.dart';
import 'chord_launch.dart';

enum ChordQuizMode { practice, arcade }

/// Welches Level der Akkord-Tour gespielt wird.
class ChordAdventureRef {
  const ChordAdventureRef({
    required this.curriculumId,
    required this.station,
    required this.level,
    required this.crowdLoss,
    required this.crowdGain,
  });
  final String curriculumId;
  final int station;
  final int level;
  final double crowdLoss;
  final double crowdGain;
}

/// Einstellungen einer Akkord-Runde.
class ChordQuizConfig {
  const ChordQuizConfig({
    required this.mode,
    required this.tasks,
    required this.pool,
    required this.strings,
    this.focus = const {},
    this.length = 10,
    this.timeLimit,
    this.lives = 3,
    this.alternate = false,
    this.song = false,
    this.adventure,
    this.pedals = const [],
  });

  final ChordQuizMode mode;
  final List<ChordTask> tasks;
  final List<Chord> pool;
  final Set<Chord> focus;

  /// Saiten im Griffbild (3 = g, h, e … 6 = alle).
  final int strings;
  final int length;
  final Duration? timeLimit;
  final int lives;

  /// Wechsel-Training: zwei Akkorde abwechselnd.
  final bool alternate;

  /// Auftritt: ein Lied mit Takten begleiten.
  final bool song;
  final ChordAdventureRef? adventure;
  final List<String> pedals;

  static const recordKey = 'chords';
}

/// Eine Akkord-Runde: Griffbild erkennen, Griff bauen, Akkord aus den Noten.
class ChordQuizScreen extends StatefulWidget {
  const ChordQuizScreen({super.key, required this.profileId, required this.config});
  final String profileId;
  final ChordQuizConfig config;

  @override
  State<ChordQuizScreen> createState() => _ChordQuizScreenState();
}

enum _Phase { asking, correct, wrong }

class _ChordQuizScreenState extends State<ChordQuizScreen> with SingleTickerProviderStateMixin {
  late final SuonaState _state;
  late final Profile _profile;
  late final AnimationController _timer;
  late final List<Chord> _options;
  final _random = Random();
  final _combo = Combo();
  final _results = <bool>[];
  Song? _song;

  late Chord _chord;
  late ChordTask _task;
  Chord? _last;
  _Phase _phase = _Phase.asking;
  int _asked = 0;
  int _coins = 0;
  int _lastGain = 0;
  late int _lives;
  bool _finished = false;
  Timer? _next;

  // Griff bauen: Saite → Bund (nur gegriffene) und gedämpfte Saiten.
  final _placed = <int, int>{};
  final _muted = <int>{};
  Chord? _answered;

  // Abenteuer
  double _crowd = Adventure.crowdStart;
  final _usedPedals = <String>{};
  bool _shieldArmed = false;
  bool _shielded = false;
  bool _capoActive = false;
  final _hidden = <Chord>{};

  ChordQuizConfig get _cfg => widget.config;
  ChordAdventureRef? get _adv => _cfg.adventure;
  bool get _arcade => _cfg.mode == ChordQuizMode.arcade;
  int get _strings => _cfg.strings;
  NoteNaming get _naming => _state.naming;
  int get _total => _song?.bars.length ?? _cfg.length;

  @override
  void initState() {
    super.initState();
    _state = SuonaScope.read(context);
    _profile = _state.profiles.firstWhere((p) => p.id == widget.profileId);
    _lives = _cfg.lives;
    if (_cfg.song) _song = Song.generate(_cfg.pool, _cfg.focus, _cfg.length, _random);
    // Antwortknöpfe: alle Akkorde der Runde, mindestens drei.
    _options = [..._cfg.pool];
    for (final c in ChordLibrary.all) {
      if (_options.length >= 3) break;
      if (!_options.contains(c)) _options.add(c);
    }
    _timer = AnimationController(vsync: this, duration: _cfg.timeLimit ?? const Duration(seconds: 1))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && _phase == _Phase.asking) _evaluate(false);
      });
    _ask();
  }

  @override
  void dispose() {
    _timer.dispose();
    _next?.cancel();
    if (!_finished) unawaited(_state.saveProfile(_profile));
    super.dispose();
  }

  String _key(Chord c, ChordTask t) => '${t.statsPrefix}${c.id}';

  /// Nächster Akkord: unsichere und neue öfter, nie zweimal derselbe.
  Chord _pick(ChordTask task) {
    final song = _song;
    if (song != null) return song.bars[_results.length % song.bars.length];
    final pool = _cfg.pool;
    if (_cfg.alternate && pool.length >= 2) return pool[_asked % 2];
    var candidates = pool.where((c) => c != _last).toList();
    if (candidates.isEmpty) candidates = pool;
    final weights = [
      for (final c in candidates) _profile.stats.weightOfKey(_key(c, task)) * (_cfg.focus.contains(c) ? 2.0 : 1.0),
    ];
    var r = _random.nextDouble() * weights.fold<double>(0, (a, b) => a + b);
    for (var i = 0; i < candidates.length; i++) {
      r -= weights[i];
      if (r <= 0) return candidates[i];
    }
    return candidates.last;
  }

  void _ask() {
    if (!mounted) return;
    final task = _cfg.tasks[_random.nextInt(_cfg.tasks.length)];
    final chord = _pick(task);
    setState(() {
      _task = task;
      _chord = chord;
      _last = chord;
      _phase = _Phase.asking;
      _placed.clear();
      _muted.clear();
      _answered = null;
      _shielded = false;
      _capoActive = false;
      _hidden.clear();
      _asked++;
    });
    // Neue Akkorde beim Erkennen gleich hören.
    if (task == ChordTask.name && _cfg.focus.contains(chord) && !_arcade) {
      unawaited(Sounds.instance.strum(chord.midis(_strings)));
    }
    if (_cfg.timeLimit != null) _timer.forward(from: 0);
  }

  // ---------- Antworten ----------

  void _answerName(Chord c) {
    if (_phase != _Phase.asking) return;
    _answered = c;
    // Sehen zwei Akkorde auf diesen Saiten gleich aus, zählen beide.
    _evaluate(c == _chord || c.sameShape(_chord, _strings));
  }

  void _tapBoard(FretPosition p) {
    if (_phase != _Phase.asking || _task != ChordTask.build) return;
    setState(() {
      if (p.fret == 0) {
        // Links: Punkt weg (leer anschlagen) oder „x“ ein/aus (ab vier Saiten).
        if (_placed.containsKey(p.string)) {
          _placed.remove(p.string);
        } else if (_strings >= 4) {
          if (!_muted.remove(p.string)) _muted.add(p.string);
        }
      } else if (_placed[p.string] == p.fret) {
        _placed.remove(p.string);
      } else {
        _placed[p.string] = p.fret;
        _muted.remove(p.string);
      }
    });
  }

  bool get _builtRight {
    final target = {for (final d in _chord.dots(_strings)) d.string: d.fret};
    if (target.length != _placed.length) return false;
    for (final e in target.entries) {
      if (_placed[e.key] != e.value) return false;
    }
    final muted = _chord.muted(_strings);
    return muted.length == _muted.length && muted.containsAll(_muted);
  }

  void _evaluate(bool ok) {
    if (_phase != _Phase.asking || _finished) return;
    _timer.stop();
    _profile.stats.recordKey(_key(_chord, _task), correct: ok);
    final sound = _chord.midis(_strings);
    // Schild-Pedal: Der Fehler zählt nicht.
    if (!ok && _shieldArmed) {
      _shieldArmed = false;
      unawaited(Sounds.instance.wrong());
      _next = Timer(const Duration(milliseconds: 450), () => Sounds.instance.strum(sound));
      setState(() {
        _phase = _Phase.wrong;
        _shielded = true;
      });
      _next = Timer(const Duration(milliseconds: 2400), _ask);
      return;
    }
    _results.add(ok);
    if (_adv != null) _crowd = (ok ? _crowd + _adv!.crowdGain : _crowd - _adv!.crowdLoss).clamp(0.0, 1.0);
    if (ok) {
      _lastGain = _combo.hit();
      _coins += _lastGain;
      _profile
        ..coins += _lastGain
        ..totalCorrect += 1;
      unawaited(Sounds.instance.strum(sound));
      unawaited(Sounds.instance.coins());
    } else {
      _combo.miss();
      if (_arcade) _lives--;
      unawaited(Sounds.instance.wrong());
      _next = Timer(const Duration(milliseconds: 450), () => Sounds.instance.strum(sound));
    }
    setState(() => _phase = ok ? _Phase.correct : _Phase.wrong);
    final done = _arcade ? _lives <= 0 : (_results.length >= _total || (_adv != null && _crowd <= 0));
    final wait = ok ? 1100 : 2800;
    _next = Timer(Duration(milliseconds: wait), done ? _finish : _ask);
  }

  // ---------- Pedale ----------

  void _usePedal(String id) {
    if (_phase != _Phase.asking || _usedPedals.contains(id)) return;
    setState(() {
      _usedPedals.add(id);
      switch (id) {
        case 'pedal_shield':
          _shieldArmed = true;
        case 'pedal_capo':
          _capoActive = true;
          _timer.stop();
        case 'pedal_tuner':
          if (_task == ChordTask.build) {
            // Einen fehlenden Punkt richtig setzen.
            for (final d in _chord.dots(_strings)) {
              if (_placed[d.string] != d.fret) {
                _placed[d.string] = d.fret;
                _muted.remove(d.string);
                break;
              }
            }
          } else {
            final wrong = _options.where((c) => c != _chord).toList()..shuffle(_random);
            _hidden.addAll(wrong.take(2));
          }
      }
    });
  }

  bool _pedalUseful(String id) => switch (id) {
    'pedal_capo' => _cfg.timeLimit != null,
    'pedal_tuner' => _task == ChordTask.build || _options.length > 3,
    _ => true,
  };

  // ---------- Ende ----------

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    final correct = _results.where((r) => r).length;
    final adv = _adv;
    var stars = 0, bonus = 0;
    AdventureOutcome? outcome;
    var newRecord = false;
    if (adv != null) {
      final crowdGone = _crowd <= 0;
      stars = crowdGone ? 0 : Adventure.starsForRound(correct, _total);
      final first = ChordTour.record(_profile, adv.curriculumId, adv.station, adv.level, stars);
      bonus = first ? Adventure.firstClearBonus(adv.level) : 0;
      outcome = AdventureOutcome(passed: stars > 0, crowdGone: crowdGone, firstClear: first);
    } else if (_arcade) {
      newRecord = _coins > (_profile.arcadeBests[ChordQuizConfig.recordKey] ?? 0);
      if (newRecord) _profile.arcadeBests[ChordQuizConfig.recordKey] = _coins;
    } else {
      stars = starsFor(correct, _results.length);
      bonus = bonusForStars(stars);
    }
    _profile
      ..coins += bonus
      ..roundsPlayed += 1;
    StreakEvent? streak;
    if (_results.length >= (adv != null ? 8 : 10)) streak = _profile.streak.registerPractice(DateTime.now());
    await _state.saveProfile(_profile);
    if ((outcome?.passed ?? false) || stars == 3 || newRecord) unawaited(Sounds.instance.fanfare());
    if (!mounted) return;
    final cfg = _cfg;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          profileId: _profile.id,
          arcade: _arcade,
          concert: adv?.level == ChordTour.concertLevel,
          again: (_) => ChordQuizScreen(profileId: _profile.id, config: cfg),
          next: adv == null ? null : (context, state, p) => chordNextLevelButton(context, state, p, adv),
          correct: correct,
          total: _results.length,
          coins: _coins + bonus,
          bonus: bonus,
          stars: stars,
          newRecord: newRecord,
          streakEvent: streak,
          adventure: outcome,
        ),
      ),
    );
  }

  // ---------- Aufbau ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: context.screenPadding,
            child: Column(
              children: [
                _header(),
                if (_cfg.timeLimit != null) ...[SizedBox(height: context.compact ? 6 : 10), _timeBar()],
                if (_adv != null) ...[SizedBox(height: context.compact ? 6 : 10), _crowdAndPedals()],
                if (_song != null) ...[SizedBox(height: context.compact ? 6 : 10), _songSheet()],
                SizedBox(height: context.compact ? 8 : 12),
                Expanded(child: LayoutBuilder(builder: (context, c) => _body(c))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(BoxConstraints c) {
    if (context.compact && c.maxWidth >= 600) {
      // Handy quer: Griffbild bzw. Noten links, Antwort rechts.
      final side = min(330.0, c.maxWidth * 0.38);
      final left = _task == ChordTask.staff ? _withFeedback(_staffCard()) : _withFeedback(_boardCard());
      final right = switch (_task) {
        ChordTask.build => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [_buildPrompt(), const SizedBox(height: 12), _buildControls(stacked: true)],
        ),
        _ => Center(child: SingleChildScrollView(child: _namePad())),
      };
      return Row(
        children: [
          Expanded(child: left),
          const SizedBox(width: 14),
          SizedBox(width: side, child: right),
        ],
      );
    }
    final boardHeight = (c.maxHeight * 0.55).clamp(200.0, 380.0);
    switch (_task) {
      case ChordTask.name:
        return Column(
          children: [
            Expanded(child: _withFeedback(Center(child: SizedBox(height: boardHeight, child: _boardCard())))),
            const SizedBox(height: 14),
            _namePad(),
          ],
        );
      case ChordTask.staff:
        return Column(
          children: [
            Expanded(child: _withFeedback(_staffCard())),
            const SizedBox(height: 14),
            _namePad(),
          ],
        );
      case ChordTask.build:
        return Column(
          children: [
            _buildPrompt(),
            const SizedBox(height: 10),
            Expanded(child: _withFeedback(Center(child: SizedBox(height: boardHeight, child: _boardCard())))),
            const SizedBox(height: 12),
            _buildControls(),
          ],
        );
    }
  }

  Widget _withFeedback(Widget child) => Stack(
    clipBehavior: Clip.none,
    alignment: Alignment.center,
    children: [
      child,
      if (_phase != _Phase.asking)
        Positioned(top: context.compact ? -8 : -14, right: context.compact ? 8 : 18, child: _feedback()),
    ],
  );

  /// Griffbild: beim Erkennen zeigt es den Akkord, beim Bauen nimmt es Punkte an.
  Widget _boardCard() {
    final dots = <ChordDot>[];
    final marks = <int, OpenMark>{};
    final markColors = <int, Color>{};
    final target = _chord.dots(_strings);
    final targetMuted = _chord.muted(_strings);
    final showSolution = _task != ChordTask.build || _phase != _Phase.asking;
    if (_task == ChordTask.build) {
      // Was das Kind gesetzt hat
      for (final e in _placed.entries) {
        final p = FretPosition(e.key, e.value);
        final right = target.contains(p);
        final color = switch (_phase) {
          _Phase.asking => SuonaColors.accent,
          _Phase.correct => SuonaColors.ok,
          _Phase.wrong => right ? SuonaColors.ok : SuonaColors.wrong,
        };
        dots.add(ChordDot(p, color: color, label: _phase != _Phase.asking && right ? '${_chord.fingerOn(p.string)}' : null));
      }
      if (_phase == _Phase.wrong) {
        // Fehlende Punkte als grüne Ringe mit Fingernummer
        for (final p in target) {
          if (_placed[p.string] == p.fret) continue;
          dots.add(ChordDot(p, color: SuonaColors.ok, filled: false, label: '${_chord.fingerOn(p.string)}'));
        }
      }
      for (var s = 1; s <= _strings; s++) {
        // Ein Punkt auf einer Saite, die leer klingen sollte: dort zeigt das „o“, wie es richtig ist.
        final wrongDot = _phase == _Phase.wrong && _placed.containsKey(s) && !target.any((p) => p.string == s);
        if (_placed.containsKey(s) && !wrongDot) continue;
        if (wrongDot) markColors[s] = SuonaColors.ok;
        if (showSolution) {
          marks[s] = targetMuted.contains(s) ? OpenMark.muted : OpenMark.open;
          final mine = _muted.contains(s);
          if (_phase == _Phase.wrong && mine != targetMuted.contains(s)) markColors[s] = SuonaColors.gold;
        } else {
          marks[s] = _muted.contains(s) ? OpenMark.muted : OpenMark.open;
        }
      }
    } else {
      final color = switch (_phase) {
        _Phase.asking => SuonaColors.accent,
        _Phase.correct => SuonaColors.ok,
        _Phase.wrong => SuonaColors.wrong,
      };
      for (final p in target) {
        dots.add(ChordDot(p, color: color, label: '${_chord.fingerOn(p.string)}'));
      }
      for (var s = 1; s <= _strings; s++) {
        if (!target.any((p) => p.string == s)) marks[s] = targetMuted.contains(s) ? OpenMark.muted : OpenMark.open;
      }
    }
    return BoardCard(
        maxWidth: 980,
        child: ChordBoard(
          key: ValueKey('cb$_asked'),
          strings: _strings,
          dots: dots,
          openMarks: marks,
          openColors: markColors,
          naming: _naming,
          lowStringOnTop: _state.settings.lowStringOnTop,
          onTap: _task == ChordTask.build && _phase == _Phase.asking ? _tapBoard : null,
        ),
    );
  }

  Widget _staffCard() {
    final color = switch (_phase) {
      _Phase.asking => SuonaColors.paperInk,
      _Phase.correct => SuonaColors.paperOk,
      _Phase.wrong => SuonaColors.paperWrong,
    };
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: AspectRatio(
          aspectRatio: 1.9,
          child: PaperCard(
            child: StaffView(
              key: ValueKey('st$_asked'),
              chord: true,
              notes: [for (final p in _chord.pitches(_strings)) StaffNote(p, color: color)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(tr('Baue', 'Build'), style: display(context.compact ? 20 : 26, color: SuonaColors.muted, weight: FontWeight.w600)),
        const SizedBox(width: 14),
        Container(
          padding: EdgeInsets.symmetric(horizontal: context.compact ? 16 : 24, vertical: 4),
          decoration: BoxDecoration(
            gradient: gradientOf(SuonaColors.brand, horizontal: true),
            borderRadius: BorderRadius.circular(20),
            boxShadow: glowOf(SuonaColors.brand, strength: 0.3),
          ),
          child: Text(chordName(_chord, _naming), style: display(context.compact ? 30 : 40, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildControls({bool stacked = false}) {
    final hint = _strings >= 4
        ? tr('Tippe die Punkte. Links: „x“ = nicht spielen.', 'Tap the dots. On the left: “x” = don’t play.')
        : tr('Tippe die Punkte, dann „Fertig“.', 'Tap the dots, then “Done”.');
    return Column(
      children: [
        Text(hint, textAlign: TextAlign.center, style: body(context.compact ? 13 : 15, color: SuonaColors.muted)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 12,
          runSpacing: 10,
          direction: stacked ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GradientButton(
              label: tr('Leeren', 'Clear'),
              icon: Icons.backspace_rounded,
              secondary: true,
              height: 60,
              fontSize: 20,
              onPressed: _phase == _Phase.asking && (_placed.isNotEmpty || _muted.isNotEmpty)
                  ? () => setState(() {
                      _placed.clear();
                      _muted.clear();
                    })
                  : null,
            ),
            GradientButton(
              label: tr('Fertig', 'Done'),
              icon: Icons.check_rounded,
              height: 60,
              fontSize: 22,
              onPressed: _phase == _Phase.asking ? () => _evaluate(_builtRight) : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _namePad() {
    return LayoutBuilder(
      builder: (context, c) {
        final perRow = context.compact ? min(_options.length, 3) : min(_options.length, 7);
        final size = min(context.compact ? 96.0 : 110.0, (c.maxWidth - (perRow - 1) * 10) / perRow);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: WrapAlignment.center,
          children: [
            for (final o in _options)
              AnswerButton(
                label: chordName(o, _naming),
                width: size,
                height: min(92.0, size * 0.84),
                state: _answered == o
                    ? (_phase == _Phase.correct ? AnswerState.right : AnswerState.wrong)
                    : (_phase == _Phase.wrong && o == _chord ? AnswerState.hint : AnswerState.normal),
                hidden: _hidden.contains(o),
                onTap: _phase == _Phase.asking && !_hidden.contains(o) ? () => _answerName(o) : null,
              ),
          ],
        );
      },
    );
  }

  Widget _feedback() {
    final ok = _phase == _Phase.correct;
    final name = chordName(_chord, _naming);
    final timeout = !ok && _answered == null && _task != ChordTask.build;
    final text = _shielded
        ? tr('Schild! Das war $name', 'Shield! That was $name')
        : ok
        ? '$name!'
        : (_task == ChordTask.build ? tr('So geht $name', 'This is $name') : tr('Das ist $name', 'That’s $name'));
    return FeedbackBadge(
      kind: _shielded ? FeedbackKind.shield : (ok ? FeedbackKind.right : FeedbackKind.wrong),
      icon: _shielded
          ? Icons.shield_rounded
          : (ok ? Icons.check_rounded : (timeout ? Icons.timer_off_rounded : Icons.close_rounded)),
      text: text,
      gain: ok ? _lastGain : null,
    );
  }

  /// Das Liedblatt beim Auftritt: alle Takte, der aktuelle leuchtet.
  Widget _songSheet() {
    final song = _song!;
    final small = context.compact;
    final bars = [
      for (var i = 0; i < song.bars.length; i++)
        Container(
          width: small ? 54 : 66,
          height: small ? 34 : 42,
          margin: const EdgeInsets.only(right: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: i == _results.length ? gradientOf(SuonaColors.brand) : null,
            color: i < _results.length
                ? (_results[i] ? SuonaColors.ok.withValues(alpha: 0.22) : SuonaColors.wrong.withValues(alpha: 0.25))
                : (i == _results.length ? null : SuonaColors.cardHigh),
          ),
          child: Text(
            chordName(song.bars[i], _naming),
            style: display(small ? 15 : 19, color: i == _results.length ? Colors.white : SuonaColors.ink),
          ),
        ),
    ];
    if (small) {
      // Handy quer: eine Zeile zum Wischen, der aktuelle Takt bleibt sichtbar.
      return SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          controller: ScrollController(initialScrollOffset: max(0, (_results.length - 3) * 60.0)),
          children: [
            Center(child: Icon(Icons.queue_music_rounded, color: SuonaColors.accent)),
            const SizedBox(width: 8),
            ...bars,
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: SuonaColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: SuonaColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.queue_music_rounded, color: SuonaColors.accent),
              const SizedBox(width: 8),
              Text(song.title, style: display(20)),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 0, runSpacing: 6, children: bars),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        RoundIconButton(
          icon: Icons.close_rounded,
          tooltip: tr('Beenden', 'Quit'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 14),
        Expanded(child: _arcade ? _livesRow() : (_song != null ? _songTitle() : _progressDots())),
        const SizedBox(width: 12),
        if (_combo.multiplier > 1) ...[ComboBadge(_combo.multiplier), const SizedBox(width: 10)],
        InfoPill(child: CoinCount(_coins, size: context.compact ? 18 : 21)),
      ],
    );
  }

  Widget _songTitle() => Text(
    tr('Lied begleiten', 'Play along'),
    style: display(context.compact ? 18 : 24),
  );

  Widget _progressDots() => ProgressDots(total: _total, results: _results, size: context.compact ? 14 : 22);

  Widget _livesRow() {
    return Row(
      children: [
        for (var i = 0; i < _cfg.lives; i++)
          Padding(padding: const EdgeInsets.only(right: 6), child: LifePick(filled: i < _lives)),
        const SizedBox(width: 10),
        Text(
          tr('${_results.where((r) => r).length} richtig', '${_results.where((r) => r).length} right'),
          style: display(19, color: SuonaColors.muted, weight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _timeBar() => TimeBar(timer: _timer);

  Widget _crowdAndPedals() {
    return CrowdBar(
      mood: _crowd,
      pedals: [
        for (final id in _cfg.pedals)
          PedalButton(
            id: id,
            used: _usedPedals.contains(id),
            active: (id == 'pedal_shield' && _shieldArmed) || (id == 'pedal_capo' && _capoActive),
            enabled: _phase == _Phase.asking && !_usedPedals.contains(id) && _pedalUseful(id),
            onTap: () => _usePedal(id),
          ),
      ],
    );
  }
}
