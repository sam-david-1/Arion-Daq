[Setup]
AppId={{8B1B8C50-84E3-4D93-9F6D-E5D57B439129}
AppName=Arion DAQ
AppVersion=1.0.0
AppPublisher=Arion
DefaultDirName={autopf}\Arion DAQ
DisableProgramGroupPage=yes
OutputDir=build\windows\installer
OutputBaseFilename=arion_daq_setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\arion_daq.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Arion DAQ"; Filename: "{app}\arion_daq.exe"
Name: "{autodesktop}\Arion DAQ"; Filename: "{app}\arion_daq.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\arion_daq.exe"; Description: "{cm:LaunchProgram,Arion DAQ}"; Flags: nowait postinstall skipifsilent
