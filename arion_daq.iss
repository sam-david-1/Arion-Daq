[Setup]
AppId={{5E9E15B5-D182-4B11-8AC5-19AC4D0DE24A}
AppName=ARION DAQ
AppVersion=2.0
AppPublisher=Arion Racing
DefaultDirName={autopf}\ARION DAQ
DisableProgramGroupPage=yes
OutputBaseFilename=Arion_DAQ_Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "c:\Users\SamDa\arion_daq\build\windows\x64\runner\Release\arion_daq.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "c:\Users\SamDa\arion_daq\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\ARION DAQ"; Filename: "{app}\arion_daq.exe"
Name: "{autodesktop}\ARION DAQ"; Filename: "{app}\arion_daq.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\arion_daq.exe"; Description: "{cm:LaunchProgram,ARION DAQ}"; Flags: nowait postinstall skipifsilent
