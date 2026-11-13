import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/audio/sounds.dart';
import '../../core/game/note_stats.dart';
import '../../core/game/question.dart';
import '../../core/game/rewards.dart';
import '../../core/music/guitar.dart';
import '../../core/music/note_names.dart';
import '../../core/music/pitch.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/fretboard.dart';
import '../../widgets/stage.dart';
import '../../widgets/staff.dart';
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
  }

  @override
  void dispose() {
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
      _tapped = null;
      _placedStep = null;
      _modifier = Accidental.natural;
    });
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
    _profile.stats.record(_note, correct: ok, prefix: _q.type.statsPrefix);
    _results.add(ok);
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
    final done = _arcade ? _lives <= 0 : _results.length >= widget.config.length;
    // Beim Griffbrett braucht das Anschauen der richtigen Stellen etwas länger.
    final wait = ok ? 900 : (_q.type == QuestionType.nameFromStaff ? 1700 : 2300);
    _next = Timer(Duration(milliseconds: wait), done ? _finish : _ask);
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
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
          config: widget.config,
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
        body: StageBackground(
          floor: false,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                children: [
                  _header(),
                  if (widget.config.timeLimit != null) ...[const SizedBox(height: 10), _timeBar()],
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
            _letterPad(),
          ],
        );
      case QuestionType.fretFromStaff:
        return Column(
          children: [
            Expanded(child: _withFeedback(_staffCard(maxWidth: 820, aspect: 2.1))),
            const SizedBox(height: 14),
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
    _Phase.asking => SuonaColors.ink,
    _Phase.correct => SuonaColors.okDeep,
    _Phase.wrong => SuonaColors.wrong,
  };

  Widget _paper({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: SuonaColors.paper,
      borderRadius: BorderRadius.circular(26),
      boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 8))],
    ),
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    child: child,
  );

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
        _Phase.asking => SuonaColors.spot,
        _Phase.correct => SuonaColors.ok,
        _Phase.wrong => SuonaColors.wrong,
      };
      marks.add(FretMark(_q.shown!, color: color, label: _phase == _Phase.asking ? '?' : pitchName(_note, _naming)));
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1160),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 12, 14, 6),
          decoration: BoxDecoration(color: SuonaColors.stageFloor, borderRadius: BorderRadius.circular(22)),
          child: Fretboard(
            key: ValueKey('fb$_asked'),
            marks: marks,
            naming: _naming,
            lowStringOnTop: _state.settings.lowStringOnTop,
            activeStrings: _q.onString != null ? {_q.onString!} : range?.strings,
            minFret: range?.minFret ?? 0,
            maxFret: range?.maxFret ?? Guitar.maxFret,
            highlightString: _q.onString,
            onTap: answer && _phase == _Phase.asking ? _answerFret : null,
          ),
        ),
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
      child: Text(tr('Auf der $s-Saite!', 'On the $s string!'), style: display(24, color: SuonaColors.spot)),
    );
  }

  Widget _staffInputCard() {
    final notes = <StaffNote>[];
    if (_placedStep != null) {
      final placed = pitchFromStaffStep(_placedStep!, _modifier);
      final color = switch (_phase) {
        _Phase.asking => SuonaColors.violet,
        _Phase.correct => SuonaColors.okDeep,
        _Phase.wrong => SuonaColors.wrong,
      };
      notes.add(StaffNote(placed, color: color));
    }
    if (_phase == _Phase.wrong) notes.add(StaffNote(_note, color: SuonaColors.okDeep));
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
                        style: display(22, color: SuonaColors.inkMuted, weight: FontWeight.w700),
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
        FilledButton.icon(
          onPressed: _phase == _Phase.asking && _placedStep != null ? _confirmStaff : null,
          icon: const Icon(Icons.check_rounded, size: 30),
          label: Text(tr('Fertig', 'Done')),
          style: FilledButton.styleFrom(
            backgroundColor: SuonaColors.spot,
            foregroundColor: SuonaColors.ink,
            disabledBackgroundColor: SuonaColors.stageFloor,
            textStyle: display(26),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _header() {
    return Row(
      children: [
        StageIconButton(
          icon: Icons.close_rounded,
          tooltip: tr('Beenden', 'Quit'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 14),
        Expanded(child: _arcade ? _livesRow() : _progressDots()),
        const SizedBox(width: 12),
        if (_combo.multiplier > 1)
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: SuonaColors.coral, borderRadius: BorderRadius.circular(20)),
            child: Text('Combo ×${_combo.multiplier}', style: display(18, color: Colors.white)),
          ),
        CoinCount(_coins, size: 26),
      ],
    );
  }

  Widget _progressDots() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (var i = 0; i < widget.config.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < _results.length
                  ? (_results[i] ? SuonaColors.ok : SuonaColors.wrong)
                  : (i == _results.length ? SuonaColors.onStage : SuonaColors.stageFloor),
              border: Border.all(color: SuonaColors.stageLine, width: 2),
            ),
          ),
      ],
    );
  }

  Widget _livesRow() {
    return Row(
      children: [
        for (var i = 0; i < widget.config.lives; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _Pick(filled: i < _lives),
          ),
        const SizedBox(width: 10),
        Text(
          tr('${_results.where((r) => r).length} richtig', '${_results.where((r) => r).length} right'),
          style: display(20, color: SuonaColors.onStageMuted, weight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _timeBar() {
    return AnimatedBuilder(
      animation: _timer,
      builder: (context, _) {
        final left = 1 - _timer.value;
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: left,
            minHeight: 12,
            backgroundColor: SuonaColors.stageFloor,
            color: left < 0.25 ? SuonaColors.coral : SuonaColors.spot,
          ),
        );
      },
    );
  }

  Widget _feedback() {
    final ok = _phase == _Phase.correct;
    // Mit der anderen Schreibweise richtig (Ges statt Fis): diese zeigen.
    final shownPitch = ok && _answeredLetter != null && _answeredLetter != _note.letter
        ? (_note.enharmonic ?? _note)
        : _note;
    final name = pitchName(shownPitch, _naming);
    final withOctave = pitchNameWithOctave(shownPitch, _naming);
    final timeout = !ok && _answeredLetter == null && _tapped == null && _placedStep == null;
    final text = switch (_q.type) {
      _ when ok => '$name!',
      QuestionType.fretFromStaff => tr('Hier liegt das $name', 'Here is $name'),
      QuestionType.staffFromFret => tr('So steht das $name', 'This is how $name looks'),
      _ => tr('Das ist $name', 'That’s $name'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: ok ? SuonaColors.ok : SuonaColors.wrong,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : (timeout ? Icons.timer_off_rounded : Icons.close_rounded),
            color: Colors.white,
            size: 30,
          ),
          const SizedBox(width: 8),
          Text(text, style: display(30, color: Colors.white)),
          if (withOctave != name) ...[
            const SizedBox(width: 8),
            Text(
              '($withOctave)',
              style: display(20, color: Colors.white70, weight: FontWeight.w700),
            ),
          ],
          if (ok) ...[
            const SizedBox(width: 12),
            const CoinIcon(size: 22),
            const SizedBox(width: 4),
            Text('+$_lastGain', style: display(24, color: Colors.white)),
          ],
        ],
      ),
    );
  }

  Widget _letterPad() {
    final enharmonic = _q.type == QuestionType.nameFromFret;
    return LayoutBuilder(
      builder: (context, c) {
        final size = min(96.0, (c.maxWidth - 6 * 10) / 7);
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final l in Letter.values)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _AnswerButton(
                      label: letterLabel(l, _naming),
                      size: size,
                      state: _answeredLetter == l
                          ? (_phase == _Phase.correct ? _ButtonState.right : _ButtonState.wrong)
                          : (_phase == _Phase.wrong && l == _note.letter ? _ButtonState.hint : _ButtonState.normal),
                      onTap: _phase == _Phase.asking ? () => _answerName(l) : null,
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
                style: const TextStyle(color: SuonaColors.onStageMuted, fontSize: 14),
              ),
            ],
          ],
        );
      },
    );
  }
}

enum _ButtonState { normal, right, wrong, hint }

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({required this.label, required this.size, required this.state, required this.onTap});
  final String label;
  final double size;
  final _ButtonState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (state) {
      _ButtonState.normal => (SuonaColors.onStage, SuonaColors.ink),
      _ButtonState.right => (SuonaColors.ok, Colors.white),
      _ButtonState.wrong => (SuonaColors.wrong, Colors.white),
      _ButtonState.hint => (SuonaColors.spot, SuonaColors.ink),
    };
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(size * 0.24),
        elevation: 3,
        shadowColor: Colors.black54,
        child: InkWell(
          borderRadius: BorderRadius.circular(size * 0.24),
          onTap: onTap,
          child: Center(
            child: Text(label, style: display(size * 0.5, color: fg)),
          ),
        ),
      ),
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
  Widget build(BuildContext context) {
    final glyph = accidental == Accidental.sharp ? Smufl.sharp : Smufl.flat;
    return SizedBox(
      width: height * 1.5,
      height: height,
      child: Material(
        color: selected ? SuonaColors.spot : SuonaColors.stageFloor,
        borderRadius: BorderRadius.circular(height * 0.3),
        child: InkWell(
          borderRadius: BorderRadius.circular(height * 0.3),
          onTap: onTap,
          child: Center(
            child: Text(
              glyph,
              style: TextStyle(
                fontFamily: 'Bravura',
                fontSize: height * 0.95,
                height: 1.25,
                color: selected ? SuonaColors.ink : SuonaColors.onStage,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ein Plektrum als Leben im Arcade-Modus.
class _Pick extends StatelessWidget {
  const _Pick({required this.filled});
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(28, 32), painter: _PickPainter(filled));
  }
}

class _PickPainter extends CustomPainter {
  _PickPainter(this.filled);
  final bool filled;

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width / 2, s.height)
      ..cubicTo(s.width * 0.1, s.height * 0.62, 0, s.height * 0.3, s.width * 0.08, s.height * 0.14)
      ..cubicTo(s.width * 0.2, 0, s.width * 0.8, 0, s.width * 0.92, s.height * 0.14)
      ..cubicTo(s.width, s.height * 0.3, s.width * 0.9, s.height * 0.62, s.width / 2, s.height)
      ..close();
    canvas.drawPath(path, Paint()..color = filled ? SuonaColors.coral : SuonaColors.stageFloor);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = filled ? Colors.white54 : SuonaColors.stageLine,
    );
  }

  @override
  bool shouldRepaint(_PickPainter old) => old.filled != filled;
}
