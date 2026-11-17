import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

import '../../app/error_log.dart';

/// Klänge des Spiels. Alles wird beim ersten Gebrauch im Speicher erzeugt
/// (keine Tondateien nötig): gezupfte Gitarrentöne, „richtig“, „falsch“
/// und das Klimpern der Münzen.
class Sounds {
  Sounds._();
  static final instance = Sounds._();

  bool enabled = true;
  bool _initFailed = false;
  final _cache = <String, AudioSource>{};

  static const _rate = 44100;

  Future<bool> _ready() async {
    if (_initFailed) return false;
    try {
      final s = SoLoud.instance;
      if (!s.isInitialized) await s.init(bufferSize: 1024);
      return true;
    } catch (e, st) {
      _initFailed = true;
      ErrorLog.record(e, st, where: 'Ton starten');
      return false;
    }
  }

  Future<void> _play(String key, Float32List Function() build, {double volume = 1}) async {
    if (!enabled || !await _ready()) return;
    try {
      var src = _cache[key];
      if (src == null) {
        src = await SoLoud.instance.loadMem('$key.wav', wavFromSamples(build()));
        _cache[key] = src;
      }
      SoLoud.instance.play(src, volume: volume);
    } catch (e, st) {
      ErrorLog.record(e, st, where: 'Ton abspielen');
    }
  }

  /// Gezupfter Gitarrenton (klingende MIDI-Nummer).
  Future<void> pluck(int midi) => _play('pluck-$midi', () => pluckSamples(midi), volume: 0.9);

  /// Akkord anschlagen: die Saiten kurz nacheinander von tief nach hoch.
  Future<void> strum(List<int> midis) =>
      _play('strum-${midis.join('-')}', () => strumSamples(midis), volume: 0.9);

  Future<void> correct() => _play('richtig', _chime, volume: 0.55);

  Future<void> wrong() => _play('falsch', _buzz, volume: 0.45);

  Future<void> coins() => _play('muenzen', _coins, volume: 0.45);

  Future<void> fanfare() => _play('fanfare', _fanfare, volume: 0.55);

  // ---------- Klangerzeugung ----------

  /// Gezupfte Saite nach Karplus-Strong: ein kurzes Rauschen läuft durch
  /// eine Verzögerung und wird dabei immer weicher, wie eine echte Saite.
  static Float32List pluckSamples(int midi, {double seconds = 1.6}) {
    final freq = 440.0 * pow(2, (midi - 69) / 12.0);
    final n = (_rate * seconds).round();
    final period = _rate / freq;
    final len = period.floor();
    final frac = period - len;
    final rnd = Random(midi);
    final buf = Float32List(len + 2);
    for (var i = 0; i < buf.length; i++) {
      buf[i] = rnd.nextDouble() * 2 - 1;
    }
    // Weicher Anschlag: Rauschen leicht glätten.
    for (var i = 1; i < buf.length; i++) {
      buf[i] = 0.6 * buf[i] + 0.4 * buf[i - 1];
    }
    final out = Float32List(n);
    var idx = 0;
    final decay = 0.996 - (midi - 40) * 0.00004;
    for (var i = 0; i < n; i++) {
      final a = buf[idx % buf.length];
      final b = buf[(idx + 1) % buf.length];
      final sample = a * (1 - frac) + b * frac;
      out[i] = sample;
      buf[idx % buf.length] = decay * 0.5 * (a + b);
      idx++;
    }
    // Sanft ein- und ausblenden.
    for (var i = 0; i < 64 && i < n; i++) {
      out[i] *= i / 64;
    }
    final fade = (_rate * 0.25).round();
    for (var i = 0; i < fade && i < n; i++) {
      out[n - 1 - i] *= i / fade;
    }
    return _normalize(out, 0.8);
  }

  /// Mehrere gezupfte Saiten, je 35 ms versetzt (wie ein Anschlag mit dem Daumen).
  static Float32List strumSamples(List<int> midis, {double seconds = 2.2}) {
    final out = Float32List((_rate * seconds).round());
    for (var i = 0; i < midis.length; i++) {
      final s = pluckSamples(midis[i], seconds: seconds - 0.2);
      final start = (i * 0.035 * _rate).round();
      for (var k = 0; k < s.length && start + k < out.length; k++) {
        out[start + k] += s[k];
      }
    }
    return _normalize(out, 0.85);
  }

  static Float32List _tone(
    List<(double freq, double start, double dur)> notes, {
    double total = 0.6,
    double bright = 0.3,
  }) {
    final n = (_rate * total).round();
    final out = Float32List(n);
    for (final (f, start, dur) in notes) {
      final s0 = (start * _rate).round();
      final len = (dur * _rate).round();
      for (var i = 0; i < len && s0 + i < n; i++) {
        final t = i / _rate;
        final env = exp(-t * 6 / dur) * min(1.0, i / 120);
        out[s0 + i] += (sin(2 * pi * f * t) + bright * sin(4 * pi * f * t)) * env;
      }
    }
    return _normalize(out, 0.7);
  }

  static Float32List _chime() => _tone([(880, 0, 0.35), (1318.5, 0.08, 0.45)], total: 0.6);

  static Float32List _buzz() {
    final n = (_rate * 0.32).round();
    final out = Float32List(n);
    for (var i = 0; i < n; i++) {
      final t = i / _rate;
      final env = exp(-t * 7) * min(1.0, i / 200);
      // Weiches, tiefes „Bwomp“ statt eines harten Summers.
      final f = 196 - 60 * t;
      out[i] = (sin(2 * pi * f * t) + 0.25 * sin(6 * pi * f * t)) * env;
    }
    return _normalize(out, 0.6);
  }

  static Float32List _coins() => _tone([(1975.5, 0, 0.12), (2637, 0.07, 0.25)], total: 0.4, bright: 0.15);

  static Float32List _fanfare() =>
      _tone([(523.25, 0, 0.3), (659.25, 0.12, 0.3), (783.99, 0.24, 0.3), (1046.5, 0.36, 0.7)], total: 1.2);

  static Float32List _normalize(Float32List s, double peak) {
    var m = 0.0;
    for (final v in s) {
      m = max(m, v.abs());
    }
    if (m == 0) return s;
    final k = peak / m;
    for (var i = 0; i < s.length; i++) {
      s[i] *= k;
    }
    return s;
  }

  /// WAV-Datei (16 Bit, mono) aus Werten zwischen -1 und 1.
  static Uint8List wavFromSamples(Float32List samples, {int rate = _rate}) {
    final dataLen = samples.length * 2;
    final b = ByteData(44 + dataLen);
    void str(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        b.setUint8(o + i, s.codeUnitAt(i));
      }
    }

    str(0, 'RIFF');
    b.setUint32(4, 36 + dataLen, Endian.little);
    str(8, 'WAVE');
    str(12, 'fmt ');
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little);
    b.setUint16(22, 1, Endian.little);
    b.setUint32(24, rate, Endian.little);
    b.setUint32(28, rate * 2, Endian.little);
    b.setUint16(32, 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    str(36, 'data');
    b.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      b.setInt16(44 + i * 2, (samples[i].clamp(-1.0, 1.0) * 32767).round(), Endian.little);
    }
    return b.buffer.asUint8List();
  }
}
