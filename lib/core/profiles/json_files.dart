import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../../app/error_log.dart';

/// Ein Ordner mit JSON-Dateien (eine pro Eintrag). Geschrieben wird erst in
/// eine Zwischendatei, die dann umbenannt wird. So bleibt bei einem Absturz
/// nie eine halbe Datei zurück.
class JsonFolder {
  JsonFolder(this.path);

  final String path;

  File _file(String id) => File(p.join(path, '$id.json'));

  Future<List<Map<String, dynamic>>> readAll() async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];
    final out = <Map<String, dynamic>>[];
    await for (final e in dir.list()) {
      if (e is! File || !e.path.endsWith('.json')) continue;
      try {
        final j = jsonDecode(await e.readAsString());
        if (j is Map<String, dynamic>) out.add(j);
      } catch (err, st) {
        ErrorLog.record(err, st, where: 'Lesen ${p.basename(e.path)}');
      }
    }
    return out;
  }

  Future<void> write(String id, Map<String, dynamic> json) async {
    await Directory(path).create(recursive: true);
    final target = _file(id);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent(' ').convert(json), flush: true);
    await tmp.rename(target.path);
  }

  Future<void> delete(String id) async {
    final f = _file(id);
    if (await f.exists()) await f.delete();
  }
}

/// Eine einzelne JSON-Datei (z. B. Einstellungen).
class JsonFile {
  JsonFile(this.path);

  final String path;

  Future<Map<String, dynamic>> read() async {
    try {
      final f = File(path);
      if (!await f.exists()) return {};
      final j = jsonDecode(await f.readAsString());
      return j is Map<String, dynamic> ? j : {};
    } catch (err, st) {
      ErrorLog.record(err, st, where: 'Lesen ${p.basename(path)}');
      return {};
    }
  }

  Future<void> write(Map<String, dynamic> json) async {
    await File(path).parent.create(recursive: true);
    final tmp = File('$path.tmp');
    await tmp.writeAsString(const JsonEncoder.withIndent(' ').convert(json), flush: true);
    await tmp.rename(path);
  }
}
