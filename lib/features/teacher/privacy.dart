import 'package:flutter/material.dart';

import '../../app/l10n.dart';
import '../../app/theme.dart';

/// Datenschutz-Erklärung in zwei Fassungen: für Kinder und für Eltern.
Future<void> showPrivacyDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (c) => DefaultTabController(
      length: 2,
      child: AlertDialog(
        title: Text(tr('Datenschutz', 'Privacy')),
        content: SizedBox(
          width: 640,
          height: 460,
          child: Column(
            children: [
              TabBar(
                labelColor: SuonaColors.ink,
                tabs: [
                  Tab(text: tr('Für Kinder', 'For children')),
                  Tab(text: tr('Für Eltern', 'For parents')),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _Text(
                      tr(
                        'Suona merkt sich nur deinen Spitznamen, deine Figur und wie sie aussieht, deine Münzen, was du im Shop gekauft hast, wie weit du im Abenteuer bist und welche Töne du schon gut kannst.\n\n'
                            'Das bleibt alles auf diesem Gerät. Suona schickt nichts davon weg.\n\n'
                            'Wenn du „Echt spielen“ benutzt, hört Suona deiner Gitarre zu. Dabei wird nichts aufgenommen und nichts gespeichert.\n\n'
                            'Es gibt keine Werbung, nichts zu kaufen und keinen Chat.',
                        'Suona only remembers your nickname, your character and how it looks, your coins, what you bought in the shop, how far you are in the adventure and which notes you already know well.\n\n'
                            'All of it stays on this device. Suona doesn’t send any of it anywhere.\n\n'
                            'When you use “Play for real”, Suona listens to your guitar. Nothing is recorded and nothing is stored.\n\n'
                            'There are no ads, nothing to buy and no chat.',
                      ),
                    ),
                    _Text(
                      tr(
                        'Welche Daten: Pro Profil ein frei gewählter Spitzname, die gewählte Figur und ihr Aussehen, Münzen, im Spiel gekaufte Teile, Sterne im Abenteuer, Übungstage und der Lernstand pro Ton. Kein echter Name, kein Alter, keine Fotos, keine E-Mail, kein Konto.\n\n'
                            'Wo: Nur lokal im Datenordner der App auf diesem Gerät. Es gibt keinen Server und keinen Abgleich.\n\n'
                            'Internet: Das Spiel braucht kein Internet. Einzige Ausnahme ist „Nach Updates suchen“ im gesperrten Lehrerbereich. Erst auf Knopfdruck fragt die App bei GitHub (github.com) nach einer neuen Version. Dabei werden keine Daten über die Kinder übertragen, GitHub sieht nur die übliche Anfrage eines Geräts.\n\n'
                            'Mikrofon: Nur im Modus „Echt spielen“ und im Mikrofon-Test. Der Ton wird laufend im Speicher ausgewertet und sofort verworfen, nie aufgenommen oder gespeichert. Ein Symbol zeigt, wann das Mikrofon an ist.\n\n'
                            'Keine Werbung, keine In-App-Käufe, keine Analyse- oder Tracking-Dienste, keine Absturzberichte nach aussen, keine Links nach aussen.\n\n'
                            'Löschen: Im Lehrerbereich lässt sich jedes Profil löschen. Damit sind alle seine Daten von diesem Gerät entfernt. Beim Deinstallieren werden die Spielstände unter Android mitgelöscht, unter Windows bleiben sie im Ordner „AppData“ und lassen sich dort von Hand löschen.\n\n'
                            'Die App folgt den Grundsätzen der DSGVO (EU) und des DSG (Schweiz): Es werden so wenige Daten wie möglich erhoben, und keine verlässt das Gerät.',
                        'What data: per profile a freely chosen nickname, the chosen character and its looks, coins, items bought in the game, adventure stars, practice days and the progress per note. No real name, no age, no photos, no e-mail, no account.\n\n'
                            'Where: only locally in the app’s data folder on this device. There is no server and no syncing.\n\n'
                            'Internet: the game doesn’t need the internet. The only exception is “Check for updates” in the locked teacher area. Only when pressed does the app ask GitHub (github.com) for a new version. No data about the children is sent; GitHub only sees an ordinary request from a device.\n\n'
                            'Microphone: only in “Play for real” mode and in the mic test. The sound is analysed in memory and discarded immediately, never recorded or stored. An icon shows when the microphone is on.\n\n'
                            'No ads, no in-app purchases, no analytics or tracking, no crash reports sent anywhere, no external links.\n\n'
                            'Deleting: every profile can be deleted in the teacher area, which removes all of its data from this device. When uninstalling, Android removes the game data too; on Windows it stays in the “AppData” folder and can be deleted there by hand.\n\n'
                            'The app follows the principles of the GDPR (EU) and the Swiss FADP: as little data as possible is collected, and none leaves the device.',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(c), child: Text(tr('Schliessen', 'Close')))],
      ),
    ),
  );
}

class _Text extends StatelessWidget {
  const _Text(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(child: Text(text, style: const TextStyle(fontSize: 16, height: 1.45)));
}
