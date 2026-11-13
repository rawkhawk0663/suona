import 'dart:math';
import 'dart:typed_data';

/// Ergebnis einer Tonerkennung.
class PitchReading {
  const PitchReading({required this.frequency, required this.clarity, required this.level});

  /// Grundfrequenz in Hz (0 = kein Ton erkannt).
  final double frequency;

  /// Wie eindeutig der Ton ist (0..1, ab etwa 0.85 verlässlich).
  final double clarity;

  /// Lautstärke (RMS, 0..1).
  final double level;

  bool get hasPitch => frequency > 0;

  /// Genaue MIDI-Zahl mit Nachkommastellen (69.0 = A4).
  double get midiExact => 69 + 12 * log(frequency / 440) / ln2;

  /// Nächster Halbton.
  int get midi => midiExact.round();

  /// Abweichung vom nächsten Halbton in Cent (-50..50).
  double get cents => (midiExact - midi) * 100;

  static const silent = PitchReading(frequency: 0, clarity: 0, level: 0);
}

/// Erkennt die Grundfrequenz eines einzelnen Tons (YIN-Verfahren, de
/// Cheveigné & Kawahara 2002). Gut für einzelne Gitarrensaiten: Es findet
/// den Grundton auch dann, wenn Obertöne lauter sind.
class PitchDetector {
  PitchDetector({required this.sampleRate, this.minFrequency = 70, this.maxFrequency = 1400, this.threshold = 0.15});

  final int sampleRate;
  final double minFrequency;
  final double maxFrequency;
  final double threshold;

  /// Mindestlautstärke, darunter gilt es als Stille.
  double silenceLevel = 0.01;

  /// Wie viele Werte [detect] mindestens braucht (zwei Perioden des tiefsten Tons).
  int get windowSize => (sampleRate / minFrequency * 2).ceil();

  PitchReading detect(Float32List x) {
    var sum = 0.0;
    for (final v in x) {
      sum += v * v;
    }
    final level = sqrt(sum / max(1, x.length));
    if (level < silenceLevel) return PitchReading(frequency: 0, clarity: 0, level: level);

    final maxTau = min(x.length ~/ 2, (sampleRate / minFrequency).ceil());
    final minTau = max(2, (sampleRate / maxFrequency).floor());
    final w = x.length - maxTau;
    if (w <= 0 || maxTau <= minTau) return PitchReading(frequency: 0, clarity: 0, level: level);

    // Differenzfunktion
    final d = Float64List(maxTau + 1);
    for (var tau = 1; tau <= maxTau; tau++) {
      var s = 0.0;
      for (var i = 0; i < w; i++) {
        final diff = x[i] - x[i + tau];
        s += diff * diff;
      }
      d[tau] = s;
    }
    // Normierte, kumulierte Differenz
    final cmnd = Float64List(maxTau + 1)..[0] = 1;
    var running = 0.0;
    for (var tau = 1; tau <= maxTau; tau++) {
      running += d[tau];
      cmnd[tau] = running == 0 ? 1 : d[tau] * tau / running;
    }
    // Erstes Tal unter der Schwelle
    var tau = -1;
    for (var t = minTau; t <= maxTau; t++) {
      if (cmnd[t] < threshold) {
        while (t + 1 <= maxTau && cmnd[t + 1] < cmnd[t]) {
          t++;
        }
        tau = t;
        break;
      }
    }
    if (tau < 0) {
      // Kein klares Tal: bestes Minimum nehmen, aber als unsicher melden.
      var best = minTau;
      for (var t = minTau; t <= maxTau; t++) {
        if (cmnd[t] < cmnd[best]) best = t;
      }
      if (cmnd[best] > 0.35) return PitchReading(frequency: 0, clarity: 1 - cmnd[best], level: level);
      tau = best;
    }
    // Feiner zwischen den Abtastwerten (Parabel durch drei Punkte)
    var better = tau.toDouble();
    if (tau > 1 && tau < maxTau) {
      final a = cmnd[tau - 1], b = cmnd[tau], c = cmnd[tau + 1];
      final denom = a - 2 * b + c;
      if (denom.abs() > 1e-12) better = tau + 0.5 * (a - c) / denom;
    }
    return PitchReading(frequency: sampleRate / better, clarity: (1 - cmnd[tau]).clamp(0.0, 1.0), level: level);
  }
}
