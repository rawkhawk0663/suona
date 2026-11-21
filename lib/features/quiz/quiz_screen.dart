import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/audio/mic_listener.dart';
import '../../core/audio/note_judge.dart';
import '../../core/audio/pitch_detector.dart';
import '../../core/audio/sounds.dart';
import '../../core/game/adventure.dart';
import '../../core/game/note_stats.dart';
import '../../core/game/question.dart';
import '../../core/game/rewards.dart';
import '../../core/game/shop.dart';
import '../../core/music/guitar.dart';
import '../../core/music/note_names.dart';
import '../../core/music/pitch.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/fretboard.dart';
import '../../widgets/game_parts.dart';
import '../../widgets/visuals.dart';
import '../../widgets/staff.dart';
import '../adventure/adventure_launch.dart';
import 'result_screen.dart';

enum QuizMode { practice, arcade }

/// Wie eine Runde läuft.
class QuizConfig {
  const QuizConfig({
    required this.mode,
    this.types = const [QuestionType.nameFromStaff],
    this.length = 10,
    this.timeLimit,
    this.pool,
    this.focus = const {},
    this.lives = 3,
    this.range,
    this.fixedString = false,
    this.recordKey = 'name',
    this.adventure,
    this.pedals = const [],
  });

  /// Übungsrunde „Noten lesen“: 10 Töne aus dem Lehrplan, ohne Zeitdruck.
  factory QuizConfig.practice() => const QuizConfig(mode: QuizMode.practice);

  /// Übungsrunde „Griffbrett“: abwechselnd Note → Griffbrett und Griffbrett → Name.
  factory QuizConfig.fretboardPractice() =>
      const QuizConfig(mode: QuizMode.practice, types: [QuestionType.fretFromStaff, QuestionType.nameFromFret]);

  final QuizMode mode;

  /// Fragearten, zufällig gemischt.
  final List<QuestionType> types;

  /// Anzahl Töne einer Übungsrunde.
  final int length;

  /// Zeit pro Ton (null = ohne Zeitdruck).
  final Duration? timeLimit;

  /// Eigener Notenvorrat (Arcade). Null = Lehrplan des Profils.
  final List<Pitch>? pool;
  final Set<Pitch> focus;

  /// Leben im Arcade-Modus.
  final int lives;

  /// Griffbrett-Ausschnitt (null = ganzes Griffbrett).
  final FretRange? range;

  /// Bei „Wo liegt die Note?“ eine Saite vorgeben.
  final bool fixedString;

  /// Unter welchem Namen der Arcade-Rekord gespeichert wird.
  final String recordKey;

  /// Gesetzt, wenn es ein Level im Abenteuer ist (mit Publikum und Pedalen).
  final AdventureRef? adventure;

  /// Gekaufte Pedale, im Abenteuer je einmal pro Level einsetzbar.
  final List<String> pedals;
}

/// Welches Level im Abenteuer gespielt wird.
class AdventureRef {
  const AdventureRef({
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

/// Eine Runde: Noten lesen, Griffbrett finden, Töne benennen oder setzen.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.profileId, required this.config});
  final String profileId;
  final QuizConfig config;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

enum _Phase { asking, correct, wrong }

class _QuizScreenState extends State<QuizScreen> with SingleTickerProviderStateMixin {
  late final SuonaState _state;
  late final Profile _profile;
  late final List<Pitch> _pool;
  late final Set<Pitch> _focus;
  late final QuestionFactory _factory;
  late final bool _hasAccidentals;
  late final AnimationController _timer;
  final _pickers = <String, NotePicker>{};
  final _random = Random();
  final _combo = Combo();
  final _results = <bool>[];
  final _focusNode = FocusNode();

  late Question _q;
  Accidental _modifier = Accidental.natural;
  _Phase _phase = _Phase.asking;

  // Antworten
  Letter? _answeredLetter;
  FretPosition? _tapped;
  int? _placedStep;

  int _coins = 0;
  int _lives = 3;
  int _lastGain = 0;

  /// Zählt die gestellten Fragen: Nur eine neue Frage lässt die Note hereinrutschen.
  int _asked = 0;
  bool _finished = false;
  Timer? _next;

  bool get _arcade => widget.config.mode == QuizMode.arcade;
  AdventureRef? get _adv => widget.config.adventure;

  // Abenteuer: Stimmung des Publikums und Pedale
  double _crowd = Adventure.crowdStart;
  final _usedPedals = <String>{};
  bool _shieldArmed = false;
  bool _shielded = false;
  bool _capoActive = false;
  final _hiddenLetters = <Letter>{};
  int? _tunerString;

  // Echt spielen: Antworten mit der Gitarre über das Mikrofon. Der Ton wird
  // nur im Speicher ausgewertet, nie aufgenommen oder gespeichert.
  MicListener? _mic;
  StreamSubscription<PitchReading>? _micSub;
  final _judge = NoteJudge();
  final _live = ValueNotifier<PitchReading>(PitchReading.silent);
  String? _micError;
  bool _micStarting = false;

  /// Gehörter Ton bei der letzten Antwort (falsch gespielt).
  int? _heardMidi;

  bool get _playMode => _profile.playWithGuitar;

  /// Gespielt wird nur, wo das Spielen etwas übt: Note lesen und spielen,
  /// Note auf der Gitarre finden. Bei „Welcher Ton ist das?“ müsste man nur
  /// den gezeigten Punkt nachspielen, bei „Note setzen“ wird geschrieben.
  bool get _micQuestion => _q.type == QuestionType.nameFromStaff || _q.type == QuestionType.fretFromStaff;
  NoteNaming get _naming => _state.naming;
  Pitch get _note => _q.pitch;

  @override
  void initState() {
    super.initState();
    _state = SuonaScope.read(context);
    _profile = _state.profiles.firstWhere((p) => p.id == widget.profileId);
    _pool = widget.config.pool ?? _state.practicePool(_profile);
    _focus = widget.config.pool == null ? _state.practiceFocus(_profile) : widget.config.focus;
    _factory = QuestionFactory(range: widget.config.range, fixedString: widget.config.fixedString);
    _hasAccidentals = _pool.any((p) => p.hasAccidental);
    _lives = widget.config.lives;
    _timer = AnimationController(vsync: this, duration: widget.config.timeLimit ?? const Duration(seconds: 1))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && _phase == _Phase.asking) _evaluate(false);
      });
    _ask();
    if (_playMode) unawaited(_startMic());
  }

  Future<void> _startMic() async {
    if (_mic != null || _micStarting) return;
    _micStarting = true;
    final mic = MicListener();
    final error = await mic.start();
    _micStarting = false;
    if (!mounted || !_playMode) {
      await mic.dispose();
      return;
    }
    if (error != null) {
      await mic.dispose();
      setState(() => _micError = error);
      return;
    }
    _micSub = mic.readings.listen(_onReading);
    setState(() {
      _mic = mic;
      _micError = null;
    });
    _judge.expect(_note.midi);
  }

  Future<void> _stopMic() async {
    await _micSub?.cancel();
    _micSub = null;
    final mic = _mic;
    _mic = null;
    _live.value = PitchReading.silent;
    await mic?.dispose();
  }

  Future<void> _setPlayMode(bool on) async {
    setState(() {
      _profile.playWithGuitar = on;
      _micError = null;
    });
    unawaited(_state.saveProfile(_profile));
    on ? await _startMic() : await _stopMic();
  }

  void _onReading(PitchReading r) {
    _live.value = r;
    final d = _judge.add(r);
    if (d == null || _phase != _Phase.asking || !_micQuestion) return;
    _heardMidi = d.correct ? null : d.midi;
    _evaluate(d.correct);
  }

  @override
  void dispose() {
    unawaited(_stopMic());
    _live.dispose();
    _next?.cancel();
    _timer.dispose();
    _focusNode.dispose();
    // Was bis hierher verdient wurde, bleibt (auch beim vorzeitigen Verlassen).
    if (!_finished) unawaited(_state.saveProfile(_profile));
    super.dispose();
  }

  NotePicker _pickerFor(QuestionType t) => _pickers.putIfAbsent(
    t.statsPrefix,
    () => NotePicker(pool: _pool, stats: _profile.stats, focus: _focus, prefix: t.statsPrefix),
  );

  void _ask() {
    final types = widget.config.types;
    final type = types[_random.nextInt(types.length)];
    final last = _asked == 0 ? null : _q.pitch;
    final pitch = _pickerFor(type).next(avoid: last);
    setState(() {
      _q = _factory.build(type, pitch);
      _asked++;
      _phase = _Phase.asking;
      _answeredLetter = null;
      _shielded = false;
      _capoActive = false;
      _hiddenLetters.clear();
      _tunerString = null;
      _tapped = null;
      _placedStep = null;
      _heardMidi = null;
      _modifier = Accidental.natural;
    });
    // Beim Spielen auf den neuen Ton warten; der alte darf noch ausklingen.
    if (_mic != null) _judge.expect(_note.midi, previous: last?.midi);
    if (widget.config.timeLimit != null) _timer.forward(from: 0);
  }

  // ---------- Antworten ----------

  void _answerName(Letter l) {
    if (_phase != _Phase.asking) return;
    _answeredLetter = l;
    // Vom Griffbrett aus ist die Schreibweise offen: Fis und Ges zählen beide.
    _evaluate(isRightName(_note, l, _modifier, enharmonicOk: _q.type == QuestionType.nameFromFret));
  }

  void _answerFret(FretPosition p) {
    if (_phase != _Phase.asking) return;
    _tapped = p;
    _evaluate(_q.accepted.contains(p));
  }

  void _placeNote(int step) {
    if (_phase != _Phase.asking) return;
    setState(() => _placedStep = step);
  }

  void _confirmStaff() {
    if (_phase != _Phase.asking || _placedStep == null) return;
    _evaluate(pitchFromStaffStep(_placedStep!, _modifier).midi == _note.midi);
  }

  void _evaluate(bool ok) {
    if (_phase != _Phase.asking || _finished) return;
    _timer.stop();
    _judge.pause();
    _profile.stats.record(_note, correct: ok, prefix: _q.type.statsPrefix);
    // Schild-Pedal: Der Fehler zählt nicht, das Publikum merkt nichts.
    if (!ok && _shieldArmed) {
      _shieldArmed = false;
      unawaited(Sounds.instance.wrong());
      _next = Timer(const Duration(milliseconds: 450), () => Sounds.instance.pluck(_note.midi));
      setState(() {
        _phase = _Phase.wrong;
        _shielded = true;
      });
      _next = Timer(const Duration(milliseconds: 2000), _ask);
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
      unawaited(Sounds.instance.pluck(_note.midi));
      unawaited(Sounds.instance.coins());
    } else {
      _combo.miss();
      if (_arcade) _lives--;
      unawaited(Sounds.instance.wrong());
      _next = Timer(const Duration(milliseconds: 450), () => Sounds.instance.pluck(_note.midi));
    }
    setState(() => _phase = ok ? _Phase.correct : _Phase.wrong);
    final done = _arcade ? _lives <= 0 : (_results.length >= widget.config.length || (_adv != null && _crowd <= 0));
    // Beim Griffbrett braucht das Anschauen der richtigen Stellen etwas länger.
    final wait = ok ? 900 : (_q.type == QuestionType.nameFromStaff ? 1700 : 2300);
    _next = Timer(Duration(milliseconds: wait), done ? _finish : _ask);
  }

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
          if (_q.type.answersWithName) {
            final wrong = Letter.values.where((l) => l != _note.letter).toList()..shuffle();
            _hiddenLetters.addAll(wrong.take(2));
          } else if (_q.accepted.isNotEmpty) {
            _tunerString = _q.accepted.first.string;
          }
      }
    });
  }

  /// Kann ein Pedal gerade helfen?
  bool _pedalUseful(String id) => switch (id) {
    'pedal_capo' => widget.config.timeLimit != null,
    'pedal_tuner' => _q.type != QuestionType.staffFromFret,
    _ => true,
  };

  Future<void> _finishAdventure(AdventureRef adv) async {
    final correct = _results.where((r) => r).length;
    final crowdGone = _crowd <= 0;
    final stars = crowdGone ? 0 : Adventure.starsForRound(correct, widget.config.length);
    final passed = stars > 0;
    final first = Adventure.record(_profile, adv.curriculumId, adv.station, adv.level, stars);
    final bonus = first ? Adventure.firstClearBonus(adv.level) : 0;
    _profile
      ..coins += bonus
      ..roundsPlayed += 1;
    StreakEvent? streak;
    if (_results.length >= 8) streak = _profile.streak.registerPractice(DateTime.now());
    await _state.saveProfile(_profile);
    if (passed) unawaited(Sounds.instance.fanfare());
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          profileId: _profile.id,
          arcade: _arcade,
          concert: adv.level == Adventure.concertLevel,
          again: (_) => QuizScreen(profileId: _profile.id, config: widget.config),
          next: (context, state, p) => nextLevelButton(context, state, p, adv),
          correct: correct,
          total: _results.length,
          coins: _coins + bonus,
          bonus: bonus,
          stars: stars,
          newRecord: false,
          streakEvent: streak,
          adventure: AdventureOutcome(passed: passed, crowdGone: crowdGone, firstClear: first),
        ),
      ),
    );
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    if (_adv != null) return _finishAdventure(_adv!);
    final correct = _results.where((r) => r).length;
    final stars = _arcade ? 0 : starsFor(correct, _results.length);
    final bonus = bonusForStars(stars);
    _profile
      ..coins += bonus
      ..roundsPlayed += 1;
    final key = widget.config.recordKey;
    final newRecord = _arcade && _coins > (_profile.arcadeBests[key] ?? 0);
    if (newRecord) _profile.arcadeBests[key] = _coins;
    // Ein Übungstag zählt nach einer ganzen Runde (Arcade: ab 10 Tönen).
    StreakEvent? streak;
    if (!_arcade || _results.length >= 10) streak = _profile.streak.registerPractice(DateTime.now());
    await _state.saveProfile(_profile);
    if (stars == 3 || newRecord) unawaited(Sounds.instance.fanfare());
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ResultScreen(
          profileId: _profile.id,
          arcade: _arcade,
          again: (_) => QuizScreen(profileId: _profile.id, config: widget.config),
          correct: correct,
          total: _results.length,
          coins: _coins + bonus,
          bonus: bonus,
          stars: stars,
          newRecord: newRecord,
          streakEvent: streak,
        ),
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ch = e.character?.toLowerCase();
    if (ch == '#' && _hasAccidentals) {
      setState(() => _modifier = _modifier == Accidental.sharp ? Accidental.natural : Accidental.sharp);
      return KeyEventResult.handled;
    }
    if (ch == '-' && _hasAccidentals) {
      setState(() => _modifier = _modifier == Accidental.flat ? Accidental.natural : Accidental.flat);
      return KeyEventResult.handled;
    }
    if (_q.type == QuestionType.staffFromFret && e.logicalKey == LogicalKeyboardKey.enter) {
      _confirmStaff();
      return KeyEventResult.handled;
    }
    if (!_q.type.answersWithName) return KeyEventResult.ignored;
    final map = {
      'c': Letter.c,
      'd': Letter.d,
      'e': Letter.e,
      'f': Letter.f,
      'g': Letter.g,
      'a': Letter.a,
      'h': Letter.b,
      if (_naming == NoteNaming.international) 'b': Letter.b,
    };
    final l = map[ch];
    if (l == null) return KeyEventResult.ignored;
    _answerName(l);
    return KeyEventResult.handled;
  }

  // ---------- Aufbau ----------

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: AppBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
              child: Column(
                children: [
                  _header(),
                  if (widget.config.timeLimit != null) ...[const SizedBox(height: 10), _timeBar()],
                  if (_adv != null) ...[const SizedBox(height: 10), _crowdAndPedals()],
                  const SizedBox(height: 14),
                  Expanded(child: LayoutBuilder(builder: (context, c) => _body(c))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Aufbau je nach Frageart.
  Widget _body(BoxConstraints c) {
    final fretHeight = (c.maxHeight * 0.38).clamp(190.0, 320.0);
    switch (_q.type) {
      case QuestionType.nameFromStaff:
        return Column(
          children: [
            Expanded(child: _withFeedback(_staffCard(maxWidth: 980, aspect: 1.75))),
            const SizedBox(height: 18),
            if (_playMode) _listenPanel() else _letterPad(),
          ],
        );
      case QuestionType.fretFromStaff:
        return Column(
          children: [
            Expanded(child: _withFeedback(_staffCard(maxWidth: 820, aspect: 2.1))),
            const SizedBox(height: 14),
            if (_playMode) ...[_listenPanel(compact: true), const SizedBox(height: 10)],
            if (_q.onString != null) _stringHint(),
            SizedBox(height: fretHeight, child: _fretboardCard(answer: true)),
          ],
        );
      case QuestionType.nameFromFret:
        return Column(
          children: [
            Expanded(
              child: Center(
                child: _withFeedback(SizedBox(height: fretHeight, child: _fretboardCard())),
              ),
            ),
            const SizedBox(height: 18),
            _letterPad(),
          ],
        );
      case QuestionType.staffFromFret:
        return Column(
          children: [
            SizedBox(height: fretHeight * 0.9, child: _fretboardCard()),
            const SizedBox(height: 12),
            Expanded(child: _withFeedback(_staffInputCard())),
            const SizedBox(height: 10),
            _staffInputControls(),
          ],
        );
    }
  }

  /// Rückmeldung oben rechts über dem Inhalt.
  Widget _withFeedback(Widget child) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        child,
        if (_phase != _Phase.asking) Positioned(top: -18, right: 18, child: _feedback()),
      ],
    );
  }

  Color get _noteColor => switch (_phase) {
    _Phase.asking => SuonaColors.paperInk,
    _Phase.correct => SuonaColors.paperOk,
    _Phase.wrong => SuonaColors.paperWrong,
  };

  Widget _paper({required Widget child}) => PaperCard(child: child);

  Widget _staffCard({required double maxWidth, required double aspect}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: AspectRatio(
          aspectRatio: aspect,
          child: _paper(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Linien und Schlüssel bleiben stehen, nur die Note wechselt.
                const StaffView(notes: [], drawNotes: false),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(a),
                      child: child,
                    ),
                  ),
                  child: StaffView(
                    key: ValueKey(_asked),
                    drawStaff: false,
                    notes: [StaffNote(_note, color: _noteColor)],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Griffbrett als Frage (leuchtender Punkt) oder als Antwort (antippen).
  Widget _fretboardCard({bool answer = false}) {
    final range = widget.config.range;
    final marks = <FretMark>[];
    if (answer) {
      if (_phase != _Phase.asking) {
        final name = pitchName(_note, _naming);
        for (final p in _q.accepted) {
          if (p == _tapped) continue;
          marks.add(FretMark(p, color: SuonaColors.ok, filled: _phase == _Phase.wrong, label: name));
        }
        if (_tapped != null) {
          // Ein falsch angetippter Punkt zeigt, welcher Ton dort wirklich liegt.
          final tappedName = _phase == _Phase.correct ? name : pitchName(_spell(Guitar.midiAt(_tapped!)), _naming);
          marks.add(
            FretMark(_tapped!, color: _phase == _Phase.correct ? SuonaColors.ok : SuonaColors.wrong, label: tappedName),
          );
        }
      }
    } else if (_q.shown != null) {
      final color = switch (_phase) {
        _Phase.asking => SuonaColors.teal,
        _Phase.correct => SuonaColors.ok,
        _Phase.wrong => SuonaColors.wrong,
      };
      marks.add(FretMark(_q.shown!, color: color, label: _phase == _Phase.asking ? '?' : pitchName(_note, _naming)));
    }
    return BoardCard(
          child: Fretboard(
            key: ValueKey('fb$_asked'),
            marks: marks,
            naming: _naming,
            lowStringOnTop: _state.settings.lowStringOnTop,
            activeStrings: _q.onString != null ? {_q.onString!} : range?.strings,
            minFret: range?.minFret ?? 0,
            maxFret: range?.maxFret ?? Guitar.maxFret,
            highlightString: _q.onString ?? (answer ? _tunerString : null),
            onTap: answer && _phase == _Phase.asking ? _answerFret : null,
          ),
    );
  }

  /// Ton zu einer MIDI-Zahl, geschrieben wie in den Einstellungen (♯ oder ♭).
  Pitch _spell(int midi) {
    final flats = _state.settings.accidentals == AccidentalStyle.flats;
    return Pitch.range(midi, midi, sharps: !flats, flats: flats).first;
  }

  Widget _stringHint() {
    final names = _naming == NoteNaming.german ? Guitar.stringNamesGerman : Guitar.stringNamesInternational;
    final s = names[_q.onString! - 1];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GradientTint(
        colors: SuonaColors.sky,
        child: Text(tr('Auf der $s-Saite!', 'On the $s string!'), style: display(24, color: Colors.white)),
      ),
    );
  }

  Widget _staffInputCard() {
    final notes = <StaffNote>[];
    if (_placedStep != null) {
      final placed = pitchFromStaffStep(_placedStep!, _modifier);
      final color = switch (_phase) {
        _Phase.asking => SuonaColors.paperHint,
        _Phase.correct => SuonaColors.paperOk,
        _Phase.wrong => SuonaColors.paperWrong,
      };
      notes.add(StaffNote(placed, color: color));
    }
    if (_phase == _Phase.wrong) notes.add(StaffNote(_note, color: SuonaColors.paperOk));
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: AspectRatio(
          aspectRatio: 2.1,
          child: _paper(
            child: StaffTapArea(
              onStep: _phase == _Phase.asking ? _placeNote : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  StaffView(notes: notes),
                  if (_placedStep == null && _phase == _Phase.asking)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        tr('Tippe, wo die Note hingehört', 'Tap where the note belongs'),
                        style: display(20, color: SuonaColors.paperMuted, weight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _staffInputControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_hasAccidentals)
          for (final a in const [Accidental.sharp, Accidental.flat])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: _ModifierButton(
                accidental: a,
                selected: _modifier == a,
                height: 62,
                onTap: _phase == _Phase.asking
                    ? () => setState(() => _modifier = _modifier == a ? Accidental.natural : a)
                    : null,
              ),
            ),
        const SizedBox(width: 18),
        GradientButton(
          label: tr('Fertig', 'Done'),
          icon: Icons.check_rounded,
          height: 62,
          fontSize: 22,
          onPressed: _phase == _Phase.asking && _placedStep != null ? _confirmStaff : null,
        ),
      ],
    );
  }

  Widget _crowdAndPedals() {
    return CrowdBar(
      mood: _crowd,
      pedals: [
        for (final id in widget.config.pedals)
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

  Widget _header() {
    return Row(
      children: [
        RoundIconButton(
          icon: Icons.close_rounded,
          tooltip: tr('Beenden', 'Quit'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 14),
        Expanded(child: _arcade ? _livesRow() : _progressDots()),
        const SizedBox(width: 12),
        if (_combo.multiplier > 1) ...[ComboBadge(_combo.multiplier), const SizedBox(width: 12)],
        _PlayToggle(on: _playMode, onTap: () => _setPlayMode(!_playMode)),
        const SizedBox(width: 12),
        InfoPill(child: CoinCount(_coins, size: 21)),
      ],
    );
  }

  /// Statt der Knöpfe: Suona hört zu. Zeigt, dass das Mikrofon an ist,
  /// wie laut es ankommt und welchen Ton Suona gerade hört.
  Widget _listenPanel({bool compact = false}) {
    if (_micError != null) {
      return _MicMessage(
        text: _micError == 'permission'
            ? tr(
                'Suona darf das Mikrofon nicht benutzen. Erlaube es in den Einstellungen des Geräts, oder tippe die Antworten.',
                'Suona may not use the microphone. Allow it in the device settings, or tap your answers.',
              )
            : tr(
                'Das Mikrofon geht gerade nicht. Probier den Mikrofon-Test im Lehrerbereich, oder tippe die Antworten.',
                'The microphone isn’t working right now. Try the mic test in the teacher area, or tap your answers.',
              ),
        onTap: () => _setPlayMode(false),
      );
    }
    final prompt = switch (_q.type) {
      QuestionType.fretFromStaff => tr('Spiel die Note auf deiner Gitarre (oder tippe die Stelle)', 'Play the note on your guitar (or tap the spot)'),
      _ => tr('Spiel die Note auf deiner Gitarre!', 'Play the note on your guitar!'),
    };
    return ValueListenableBuilder<PitchReading>(
      valueListenable: _live,
      builder: (context, r, _) {
        final level = (r.level * 8).clamp(0.0, 1.0);
        final heard = _judge.heard;
        return Container(
          constraints: const BoxConstraints(maxWidth: 820),
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: compact ? 8 : 14),
          decoration: BoxDecoration(
            color: SuonaColors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: SuonaColors.line),
          ),
          child: Row(
            children: [
              // Sichtbar: Das Mikrofon ist an.
              Container(
                width: compact ? 46 : 64,
                height: compact ? 46 : 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _mic == null ? SuonaColors.cardHigh : null,
                  // Rot heisst: Das Mikrofon hört zu.
                  gradient: _mic == null ? null : gradientOf([SuonaColors.wrong, SuonaColors.pink]),
                  boxShadow: [
                    if (_mic != null)
                      BoxShadow(color: SuonaColors.wrong.withValues(alpha: 0.55), blurRadius: 6 + 24 * level),
                  ],
                ),
                child: Icon(Icons.mic_rounded, color: Colors.white, size: compact ? 28 : 38),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _mic == null ? tr('Mikrofon startet …', 'Starting microphone …') : prompt,
                      style: display(compact ? 19 : 22),
                    ),
                    const SizedBox(height: 8),
                    GradientBar(value: level, height: 10),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: compact ? 110 : 140,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr('Ich höre', 'I hear'), style: body(14, color: SuonaColors.muted)),
                    GradientTint(
                      colors: SuonaColors.sky,
                      child: Text(
                        heard == null ? '–' : pitchNameWithOctave(_spell(heard), _naming),
                        style: display(compact ? 28 : 36, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _progressDots() => ProgressDots(total: widget.config.length, results: _results);

  Widget _livesRow() {
    return Row(
      children: [
        for (var i = 0; i < widget.config.lives; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: LifePick(filled: i < _lives),
          ),
        const SizedBox(width: 10),
        Text(
          tr('${_results.where((r) => r).length} richtig', '${_results.where((r) => r).length} right'),
          style: display(19, color: SuonaColors.muted, weight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _timeBar() => TimeBar(timer: _timer);

  Widget _feedback() {
    final ok = _phase == _Phase.correct;
    // Mit der anderen Schreibweise richtig (Ges statt Fis): diese zeigen.
    final shownPitch = ok && _answeredLetter != null && _answeredLetter != _note.letter
        ? (_note.enharmonic ?? _note)
        : _note;
    final name = pitchName(shownPitch, _naming);
    final withOctave = pitchNameWithOctave(shownPitch, _naming);
    final timeout = !ok && _answeredLetter == null && _tapped == null && _placedStep == null && _heardMidi == null;
    if (_shielded) {
      return FeedbackBadge(
        kind: FeedbackKind.shield,
        icon: Icons.shield_rounded,
        text: tr('Schild! Das war $name', 'Shield! That was $name'),
      );
    }
    final heard = _heardMidi == null ? null : _spell(_heardMidi!);
    final octaveOff = heard != null && (_heardMidi! - _note.midi) % 12 == 0;
    final text = switch (_q.type) {
      _ when ok => '$name!',
      _ when octaveOff => _heardMidi! > _note.midi
          ? tr('Richtiger Ton, eine Oktave zu hoch', 'Right note, one octave too high')
          : tr('Richtiger Ton, eine Oktave zu tief', 'Right note, one octave too low'),
      _ when heard != null => tr(
        'Du hast ${pitchName(heard, _naming)} gespielt, gesucht war $name',
        'You played ${pitchName(heard, _naming)}, we wanted $name',
      ),
      QuestionType.fretFromStaff => tr('Hier liegt das $name', 'Here is $name'),
      QuestionType.staffFromFret => tr('So steht das $name', 'This is how $name looks'),
      _ => tr('Das ist $name', 'That’s $name'),
    };
    return FeedbackBadge(
      kind: ok ? FeedbackKind.right : FeedbackKind.wrong,
      icon: ok ? Icons.check_rounded : (timeout ? Icons.timer_off_rounded : Icons.close_rounded),
      text: text,
      extra: withOctave != name ? '($withOctave)' : null,
      gain: ok ? _lastGain : null,
    );
  }

  Widget _letterPad() {
    final enharmonic = _q.type == QuestionType.nameFromFret;
    return LayoutBuilder(
      builder: (context, c) {
        final size = min(104.0, (c.maxWidth - 6 * 12) / 7);
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final l in Letter.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnswerButton(
                      label: letterLabel(l, _naming),
                      width: size,
                      height: size,
                      state: _answeredLetter == l
                          ? (_phase == _Phase.correct ? AnswerState.right : AnswerState.wrong)
                          : (_phase == _Phase.wrong && l == _note.letter ? AnswerState.hint : AnswerState.normal),
                      hidden: _hiddenLetters.contains(l),
                      onTap: _phase == _Phase.asking && !_hiddenLetters.contains(l) ? () => _answerName(l) : null,
                    ),
                  ),
              ],
            ),
            if (_hasAccidentals) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final a in const [Accidental.sharp, Accidental.flat])
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: _ModifierButton(
                        accidental: a,
                        // Nach einem Fehler zeigt Gelb das richtige Vorzeichen.
                        selected: _modifier == a || (_phase == _Phase.wrong && _note.accidental == a),
                        height: size * 0.72,
                        onTap: _phase == _Phase.asking
                            ? () => setState(() => _modifier = _modifier == a ? Accidental.natural : a)
                            : null,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                enharmonic
                    ? tr(
                        'Vorzeichen zuerst wählen, dann den Ton. Fis und Ges zählen beide.',
                        'Pick ♯ or ♭ first, then the note. F♯ and G♭ both count.',
                      )
                    : tr('Vorzeichen zuerst wählen, dann den Ton', 'Pick ♯ or ♭ first, then the note'),
                style: body(14, color: SuonaColors.muted),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ModifierButton extends StatelessWidget {
  const _ModifierButton({required this.accidental, required this.selected, required this.height, required this.onTap});
  final Accidental accidental;
  final bool selected;
  final double height;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => AccidentalKey(
    glyph: accidental == Accidental.sharp ? Smufl.sharp : Smufl.flat,
    selected: selected,
    height: height,
    onTap: onTap,
  );
}

/// Ein Plektrum als Leben im Arcade-Modus.
class LifePick extends StatelessWidget {
  const LifePick({super.key, required this.filled});
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(28, 32), painter: _LifePickPainter(filled));
  }
}

class _LifePickPainter extends CustomPainter {
  _LifePickPainter(this.filled);
  final bool filled;

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width / 2, s.height)
      ..cubicTo(s.width * 0.1, s.height * 0.62, 0, s.height * 0.3, s.width * 0.08, s.height * 0.14)
      ..cubicTo(s.width * 0.2, 0, s.width * 0.8, 0, s.width * 0.92, s.height * 0.14)
      ..cubicTo(s.width, s.height * 0.3, s.width * 0.9, s.height * 0.62, s.width / 2, s.height)
      ..close();
    final fill = Paint();
    if (filled) {
      fill.shader = gradientOf(SuonaColors.brand).createShader(Offset.zero & s);
    } else {
      fill.color = SuonaColors.cardHigh;
    }
    canvas.drawPath(path, fill);
    if (!filled) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = SuonaColors.line,
      );
    }
  }

  @override
  bool shouldRepaint(_LifePickPainter old) => old.filled != filled;
}

/// Ein Pedal im Abenteuer: einmal pro Level antippen.
class PedalButton extends StatelessWidget {
  const PedalButton({
    super.key,
    required this.id,
    required this.used,
    required this.active,
    required this.enabled,
    required this.onTap,
  });
  final String id;
  final bool used;
  final bool active;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final item = Shop.byId(id);
    final icon = switch (id) {
      'pedal_shield' => Icons.shield_rounded,
      'pedal_capo' => Icons.pause_circle_rounded,
      _ => Icons.tune_rounded,
    };
    final lit = enabled || active;
    final colors = active ? SuonaColors.brand : SuonaColors.sun;
    return Tooltip(
      message: item == null ? id : '${item.name}: ${item.help}',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: lit ? gradientOf(colors, horizontal: true) : null,
          color: lit ? null : SuonaColors.card,
          border: lit ? null : Border.all(color: SuonaColors.line),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24, color: lit ? Colors.white : SuonaColors.muted),
                  const SizedBox(width: 6),
                  Text(
                    item?.name ?? id,
                    style: display(15, color: lit ? Colors.white : SuonaColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Schalter oben: mit der Gitarre antworten (Mikrofon) oder antippen.
class _PlayToggle extends StatelessWidget {
  const _PlayToggle({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: on
          ? tr('Mit der Gitarre antworten: an', 'Answer with your guitar: on')
          : tr('Mit der Gitarre antworten', 'Answer with your guitar'),
      child: InfoPill(
        color: on ? SuonaColors.cardHigh : null,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                on ? Icons.mic_rounded : Icons.mic_none_rounded,
                color: on ? SuonaColors.wrong : SuonaColors.ink,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(tr('Gitarre', 'Guitar'), style: body(16, weight: FontWeight.w600)),
              if (on) ...[
                const SizedBox(width: 8),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: SuonaColors.wrong),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MicMessage extends StatelessWidget {
  const _MicMessage({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 820),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SuonaColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SuonaColors.line),
      ),
      child: Row(
        children: [
          Icon(Icons.mic_off_rounded, color: SuonaColors.rose, size: 40),
          const SizedBox(width: 14),
          Expanded(child: Text(text, style: body(17))),
          const SizedBox(width: 12),
          GradientButton(label: tr('Antippen', 'Tap instead'), height: 48, fontSize: 16, onPressed: onTap),
        ],
      ),
    );
  }
}
