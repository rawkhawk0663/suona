import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_recorder/flutter_recorder.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../app/error_log.dart';
import 'pitch_detector.dart';

/// Hört über das Mikrofon zu und meldet laufend den erkannten Ton.
///
/// Kinderschutz: Der Ton wird nur im Speicher ausgewertet, nie aufgenommen
/// oder gespeichert. Das Mikrofon ist nur an, solange [start] läuft.
class MicListener {
  MicListener({this.sampleRate = 22050});

  final int sampleRate;
  late final detector = PitchDetector(sampleRate: sampleRate);

  final _readings = StreamController<PitchReading>.broadcast();
  Stream<PitchReading> get readings => _readings.stream;

  StreamSubscription<AudioDataContainer>? _sub;
  Float32List _buffer = Float32List(0);
  int _sinceLast = 0;
  bool running = false;

  /// Mikrofon einschalten. Gibt eine Fehlermeldung zurück (null = läuft).
  Future<String?> start() async {
    if (running) return null;
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) return 'permission';
      }
      final rec = Recorder.instance;
      await rec.init(format: PCMFormat.s16le, sampleRate: sampleRate, channels: RecorderChannels.mono);
      rec.start();
      _sub = rec.uint8ListStream.listen(_onData);
      rec.startStreamingData();
      running = true;
      return null;
    } catch (e, st) {
      ErrorLog.record(e, st, where: 'Mikrofon starten');
      await stop();
      return e.toString();
    }
  }

  void _onData(AudioDataContainer data) {
    final s16 = data.toS16List(from: PCMFormat.s16le);
    final window = detector.windowSize;
    // Neue Werte hinten anhängen, nur das letzte Fenster behalten.
    final merged = Float32List(_buffer.length + s16.length);
    merged.setAll(0, _buffer);
    for (var i = 0; i < s16.length; i++) {
      merged[_buffer.length + i] = s16[i] / 32768.0;
    }
    _buffer = merged.length > window ? Float32List.sublistView(merged, merged.length - window) : merged;
    _sinceLast += s16.length;
    // Etwa 20-mal pro Sekunde auswerten.
    if (_buffer.length >= window && _sinceLast >= sampleRate ~/ 20) {
      _sinceLast = 0;
      _readings.add(detector.detect(Float32List.fromList(_buffer)));
    }
  }

  Future<void> stop() async {
    running = false;
    await _sub?.cancel();
    _sub = null;
    _buffer = Float32List(0);
    try {
      final rec = Recorder.instance;
      if (rec.isInitialized) {
        rec.stopStreamingData();
        rec.deinit();
      }
    } catch (e, st) {
      ErrorLog.record(e, st, where: 'Mikrofon stoppen');
    }
  }

  Future<void> dispose() async {
    await stop();
    await _readings.close();
  }
}
