import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app/error_log.dart';
import 'app/l10n.dart';
import 'app/theme.dart';
import 'app/updater.dart';
import 'core/audio/sounds.dart';
import 'core/suona_state.dart';
import 'features/start/start_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Alle Spielstände liegen nur hier, auf diesem Gerät.
  final support = (await getApplicationSupportDirectory()).path;
  ErrorLog.install(support);
  _registerFontLicenses();
  await _prepareWindow();
  final state = SuonaState(support);
  await state.load();
  Sounds.instance.enabled = state.settings.sound;
  state.addListener(() => Sounds.instance.enabled = state.settings.sound);
  // Nach einem Update: alte, beiseitegeschobene Programmdateien wegräumen.
  // Gesucht wird nach Updates nie von selbst, nur auf Knopfdruck im Lehrerbereich.
  Future<void>.delayed(const Duration(seconds: 5), Updater.cleanUp);
  runApp(SuonaApp(state: state));
}

/// Windows: maximiert öffnen, mit dem Namen der App im Titel.
Future<void> _prepareWindow() async {
  if (kIsWeb || !Platform.isWindows) return;
  try {
    await windowManager.ensureInitialized();
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(title: 'Suona', minimumSize: Size(800, 560)),
      () async {
        await windowManager.maximize();
        await windowManager.show();
        await windowManager.focus();
      },
    );
  } catch (e, st) {
    ErrorLog.record(e, st, where: 'Fenster vorbereiten');
  }
}

void _registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in const [
      ('Bravura', 'OFL-Bravura.txt'),
      ('Baloo 2', 'OFL-Baloo2.txt'),
      ('Atkinson Hyperlegible', 'OFL-AtkinsonHyperlegible.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
}

class SuonaApp extends StatelessWidget {
  const SuonaApp({super.key, required this.state});
  final SuonaState state;

  @override
  Widget build(BuildContext context) {
    return SuonaScope(
      state: state,
      child: ValueListenableBuilder(
        valueListenable: L10n.language,
        builder: (context, language, _) => MaterialApp(
          title: 'Suona',
          debugShowCheckedModeBanner: false,
          theme: buildSuonaTheme(),
          locale: language.locale,
          supportedLocales: const [Locale('de', 'CH'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const StartScreen(),
        ),
      ),
    );
  }
}
