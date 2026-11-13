/// Version dieser Suona-Ausgabe, z. B. „v0.1.42“ – dieselbe Nummer wie beim
/// Download auf GitHub. Wird beim Bauen gesetzt (`--dart-define=SUONA_VERSION`).
const suonaVersion = String.fromEnvironment('SUONA_VERSION', defaultValue: 'Testversion');
