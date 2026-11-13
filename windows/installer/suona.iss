; Installationsprogramm für Suona (Inno Setup). Wird beim Build erzeugt:
;   iscc /DAppVersion=0.1.50 windows\installer\suona.iss
; Suona wird nur für den eigenen Benutzer installiert (keine Admin-Rechte nötig),
; in %LOCALAPPDATA%\Programs\Suona. Dort darf sich Suona selbst aktualisieren.
; Die Spielstände liegen woanders (%APPDATA%\Suona\Suona) und bleiben beim Deinstallieren.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{C4E1A7B2-9D35-4F86-A2E0-7B5D1C9F3E64}
AppName=Suona
AppVersion={#AppVersion}
AppVerName=Suona {#AppVersion}
AppPublisher=Suona
DefaultDirName={localappdata}\Programs\Suona
DisableDirPage=yes
DefaultGroupName=Suona
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\build\installer
OutputBaseFilename=Suona-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\Suona.exe
UninstallDisplayName=Suona
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
WizardStyle=modern
ShowLanguageDialog=no
LanguageDetectionMethod=uilanguage
CloseApplications=force
RestartApplications=no

[Languages]
; Sprache nach Windows: Deutsch (Schweizer Schreibweise) oder Englisch.
Name: "de"; MessagesFile: "German-CH.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Suona"; Filename: "{app}\Suona.exe"
Name: "{autodesktop}\Suona"; Filename: "{app}\Suona.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\Suona.exe"; Description: "{cm:LaunchProgram,Suona}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Programmordner ganz wegräumen (auch alte Dateien von Updates). Die Spielstände
; liegen nicht hier und bleiben erhalten.
Type: filesandordirs; Name: "{app}"
