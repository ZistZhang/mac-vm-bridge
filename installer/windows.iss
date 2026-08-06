#define MyAppName "MinerU Flow"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "ZistZhang"
#define MyAppExeName "MinerUFlow.exe"

[Setup]
AppId={{97C3D79A-7A31-4E3E-A28C-5F317189C215}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\MinerU Flow
DefaultGroupName=MinerU Flow
DisableProgramGroupPage=yes
OutputDir=..\dist
OutputBaseFilename=MinerU-Flow-Setup-0.1.0
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "chinesesimp"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\MinerU Flow"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\MinerU Flow"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加图标："; Flags: unchecked

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "启动 MinerU Flow"; Flags: nowait postinstall skipifsilent
