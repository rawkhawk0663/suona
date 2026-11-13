import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';
import '../../core/audio/sounds.dart';
import '../../core/game/note_stats.dart';
import '../../core/game/rewards.dart';
import '../../core/music/note_names.dart';
import '../../core/music/pitch.dart';
import '../../core/profiles/profile.dart';
import '../../core/suona_state.dart';
import '../../widgets/stage.dart';
import '../../widgets/staff.dart';
import 'result_screen.dart';

enum QuizMode { practice, arcade }

/// Wie eine Runde läuft.
class QuizConfig {
  const QuizConfig({
    required this.mode,
    this.length = 10,
    this.timeLimit,
    this.pool,
    this.focus = const {},
    this.lives = 3,
    this.label,
  });

  /// Übungsrunde: 10 Töne aus dem Lehrplan, ohne Zeitdruck.
  factory QuizConfig.practice() => const QuizConfig(mode: QuizMode.practice);

  final QuizMode mode;

  /// Anzahl Töne einer Übungsrunde.
  final int length;

  /// Zeit pro Ton (null = ohne Zeitdruck).
  final Duration? timeLimit;

  /// Eigener Notenvorrat (Arcade). Null = Lehrplan des Profils.
  final List<Pitch>? pool;
  final Set<Pitch> focus;

  /// Leben im Arcade-Modus.
  final int lives;

  /// Beschreibung des Vorrats für die Ergebnisseite.
  final String? label;
}

/// „Wie heisst die Note?“ – eine Note erscheint, das Kind tippt den Namen.
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
  late final NotePicker _picker;
  late final bool _hasAccidentals;
  late final AnimationController _timer;
  final _combo = Combo();
  final _results = <bool>[];
  final _focusNode = FocusNode();

  late Pitch _note;
  Accidental _modifier = Accidental.natural;
  _Phase _phase = _Phase.asking;
  Letter? _answered;
  int _coins = 0;
  int _lives = 3;
  int _lastGain = 0;

  /// Zählt die gestellten Fragen: Nur eine neue Frage lässt die Note hereinrutschen.
  int _asked = 0;
  bool _finished = false;
  Timer? _next;

  bool get _arcade => widget.config.mode == QuizMode.arcade;
  NoteNaming get _naming => _state.naming;

  @override
  void initState() {
    super.initState();
    _state = SuonaScope.read(context);
    _profile = _state.profiles.firstWhere((p) => p.id == widget.profileId);
    final pool = widget.config.pool ?? _state.practicePool(_profile);
    final focus = widget.config.pool == null ? _state.practiceFocus(_profile) : widget.config.focus;
    _picker = NotePicker(pool: pool, stats: _profile.stats, focus: focus);
    _hasAccidentals = pool.any((p) => p.hasAccidental);
    _lives = widget.config.lives;
    _timer = AnimationController(vsync: this, duration: widget.config.timeLimit ?? const Duration(seconds: 1))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && _phase == _Phase.asking) _answer(null);
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

  void _ask() {
    setState(() {
      _note = _picker.next();
      _asked++;
      _phase = _Phase.asking;
      _answered = null;
      _modifier = Accidental.natural;
    });
    if (widget.config.timeLimit != null) _timer.forward(from: 0);
  }

  /// Antwort auswerten. [letter] null = Zeit abgelaufen.
  void _answer(Letter? letter) {
    if (_phase != _Phase.asking || _finished) return;
    _timer.stop();
    final ok = letter == _note.letter && _modifier == _note.accidental;
    _profile.stats.record(_note, correct: ok);
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
    setState(() {
      _answered = letter;
      _phase = ok ? _Phase.correct : _Phase.wrong;
    });
    final done = _arcade ? _lives <= 0 : _results.length >= widget.config.length;
    _next = Timer(Duration(milliseconds: ok ? 900 : 1700), done ? _finish : _ask);
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
    final newRecord = _arcade && _coins > _profile.arcadeBest;
    if (newRecord) _profile.arcadeBest = _coins;
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
    if (ch == '#' && _hasAccidentals) {
      setState(() => _modifier = _modifier == Accidental.sharp ? Accidental.natural : Accidental.sharp);
      return KeyEventResult.handled;
    }
    if (ch == '-' && _hasAccidentals) {
      setState(() => _modifier = _modifier == Accidental.flat ? Accidental.natural : Accidental.flat);
      return KeyEventResult.handled;
    }
    final l = map[ch];
    if (l == null) return KeyEventResult.ignored;
    _answer(l);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final noteColor = switch (_phase) {
      _Phase.asking => SuonaColors.ink,
      _Phase.correct => SuonaColors.okDeep,
      _Phase.wrong => SuonaColors.wrong,
    };
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
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 980),
                        child: AspectRatio(
                          aspectRatio: 1.75,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: SuonaColors.paper,
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x55000000), blurRadius: 24, offset: Offset(0, 8)),
                                  ],
                                ),
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
                                        notes: [StaffNote(_note, color: noteColor)],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_phase != _Phase.asking) Positioned(top: -18, right: 18, child: _feedback()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _answerPad(),
                ],
              ),
            ),
          ),
        ),
      ),
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
    final name = pitchName(_note, _naming);
    final withOctave = pitchNameWithOctave(_note, _naming);
    final timeout = !ok && _answered == null;
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
          Text(ok ? '$name!' : tr('Das ist $name', 'That’s $name'), style: display(30, color: Colors.white)),
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

  Widget _answerPad() {
    return LayoutBuilder(
      builder: (context, c) {
        final size = min(96.0, (c.maxWidth - 6 * 10) / 7);
        final letters = Letter.values;
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final l in letters)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _AnswerButton(
                      label: letterLabel(l, _naming),
                      size: size,
                      state: _answered == l
                          ? (_phase == _Phase.correct ? _ButtonState.right : _ButtonState.wrong)
                          : (_phase == _Phase.wrong && l == _note.letter ? _ButtonState.hint : _ButtonState.normal),
                      onTap: _phase == _Phase.asking ? () => _answer(l) : null,
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
                tr('Vorzeichen zuerst wählen, dann den Ton', 'Pick ♯ or ♭ first, then the note'),
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
