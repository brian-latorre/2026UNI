; ============================================
; 2026UNI Modpack â€” Instalador (Inno Setup)
; ============================================
; Requiere Inno Setup 6.0+
; Compilar con: Inno Setup Compiler (ISCC.exe o GUI)
;
; Este instalador:
;   1. Extrae Prism Launcher (portable) + JRE 21 a la carpeta de instalaciÃ³n
;   2. Instala VC++ Redist 2022 si falta
;   3. Crea la instancia "2026UNI" preconfigurada (RAM, Java, JVM args, IP del server)
;   4. Configura packwiz-installer-bootstrap como pre-launch command
;   5. Crea acceso directo en el escritorio
;   6. Registra un desinstalador limpio

[Setup]
AppName=2026UNI Modpack
AppVersion=1.3.0
AppVerName=2026UNI Modpack v1.3.0
AppPublisher=Brian
AppPublisherURL=https://github.com/brian-latorre/2026UNI
AppSupportURL=https://github.com/brian-latorre/2026UNI/issues

; Instalar en AppData\Local del usuario (no requiere admin)
DefaultDirName={userappdata}\.minecraft\2026UNI_Launcher
DefaultGroupName=2026UNI
DisableProgramGroupPage=yes

; Salida
OutputDir=Output
OutputBaseFilename=pineconemc
Compression=lzma2/ultra64
SolidCompression=yes
LZMANumBlockThreads=4

; Requiere solo privilegios de usuario (no admin para la instalaciÃ³n principal)
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

; Visual
; SetupIconFile=assets\icon.ico
; WizardImageFile=assets\wizard.bmp
; WizardSmallImageFile=assets\wizard-small.bmp
WizardStyle=modern
WindowVisible=no

; DesinstalaciÃ³n
UninstallDisplayName=2026UNI Modpack
; UninstallDisplayIcon={app}\PineconeMC\elyprismlauncher.exe

; Misc
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
AllowNoIcons=yes
CloseApplications=force
RestartApplications=no

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
spanish.BeveledLabel=2026UNI Modpack
english.BeveledLabel=2026UNI Modpack

[CustomMessages]
spanish.InstallingVCRedist=Instalando Visual C++ Redistributable...
spanish.LaunchAfterInstall=Abrir 2026UNI ahora
spanish.DesktopShortcut=Crear acceso directo en el escritorio
english.InstallingVCRedist=Installing Visual C++ Redistributable...
english.LaunchAfterInstall=Launch 2026UNI now
english.DesktopShortcut=Create desktop shortcut

; ============================================
; ARCHIVOS
; ============================================

[Files]
; --- Prism Launcher (portable) ---
Source: "redist\PineconeMC\*"; DestDir: "{app}\PineconeMC"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

; --- JRE 21 ---
Source: "redist\jre21\*"; DestDir: "{app}\jre21"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

; --- VC++ Redistributable (se ejecuta si hace falta, se borra despuÃƒÂ©s) ---
Source: "redist\vc_redist.x64.exe"; DestDir: "{tmp}"; \
    Flags: deleteafterinstall; Check: NeedsVCRedist

; --- Instance template: mmc-pack.json ---
Source: "..\instance-template\mmc-pack.json"; \
    DestDir: "{app}\PineconeMC\instances\2026UNI"; \
    Flags: ignoreversion

; --- Instance template: enviar-logs.ps1 ---
Source: "..\instance-template\enviar-logs.ps1"; \
    DestDir: "{app}\PineconeMC\instances\2026UNI"; \
    Flags: ignoreversion

; --- Instance template: enviar-logs.bat ---
Source: "..\instance-template\enviar-logs.bat"; \
    DestDir: "{app}\PineconeMC\instances\2026UNI"; \
    Flags: ignoreversion

; --- Instance template: pre-launch.bat ---
Source: "..\instance-template\pre-launch.bat"; \
    DestDir: "{app}\PineconeMC\instances\2026UNI"; \
    Flags: ignoreversion

; --- Instance template: .minecraft contents ---
Source: "..\instance-template\.minecraft\*"; \
    DestDir: "{app}\PineconeMC\instances\2026UNI\.minecraft"; \
    Flags: ignoreversion recursesubdirs createallsubdirs

; --- Repair script ---
Source: "..\Reparar Juego.bat"; DestDir: "{app}"; Flags: ignoreversion

; --- App Icon ---
Source: "..\icon-round.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\server-icon-round.ico"; DestDir: "{app}"; Flags: ignoreversion

; ============================================
; EJECUCIÃƒâ€œN POST-INSTALACIÃƒâ€œN
; ============================================

[Tasks]
Name: "desktopicon"; Description: "{cm:DesktopShortcut}"; GroupDescription: "{cm:AdditionalIcons}"

[Run]
; Instalar VC++ Redist si es necesario (requiere admin, se pide elevaciÃ³n solo para esto)
Filename: "{tmp}\vc_redist.x64.exe"; \
    Parameters: "/install /quiet /norestart"; \
    StatusMsg: "{cm:InstallingVCRedist}"; \
    Flags: waituntilterminated; \
    Check: NeedsVCRedist

; OpciÃ³n de abrir Prism Launcher despuÃƒÂ©s de instalar
Filename: "{app}\PineconeMC\elyprismlauncher.exe"; \
    Parameters: "-l ""2026UNI"""; \
    Description: "{cm:LaunchAfterInstall}"; \
    Flags: nowait postinstall skipifsilent unchecked

; ============================================
; ACCESOS DIRECTOS
; ============================================

[Icons]
; Acceso directo en escritorio
Name: "{userdesktop}\2026UNI"; \
    Filename: "{app}\PineconeMC\elyprismlauncher.exe"; \
    Parameters: "-l ""2026UNI"""; \
    IconFilename: "{app}\server-icon-round.ico"; \
    WorkingDir: "{app}\PineconeMC"; \
    Comment: "Jugar 2026UNI 🚀 Minecraft 1.20.1"; \
    Tasks: desktopicon

; Herramienta de reparacion en escritorio
Name: "{userdesktop}\Reparar 2026UNI"; \
    Filename: "{app}\Reparar Juego.bat"; \
    IconFilename: "{app}\icon-round.ico"; \
    WorkingDir: "{app}"; \
    Comment: "Herramienta para solucionar crasheos de 2026UNI"; \
    Tasks: desktopicon

; Acceso directo en menÃº inicio
Name: "{group}\2026UNI"; \
    Filename: "{app}\PineconeMC\elyprismlauncher.exe"; \
    Parameters: "-l ""2026UNI"""; \
    IconFilename: "{app}\server-icon-round.ico"; \
    WorkingDir: "{app}\PineconeMC"; \
    Comment: "Jugar 2026UNI â€” Minecraft 1.20.1"

; Desinstalar en menÃº inicio
Name: "{group}\Desinstalar 2026UNI"; \
    Filename: "{uninstallexe}"; \
    Comment: "Desinstalar 2026UNI Modpack"

; ============================================
; DESINSTALACIÃƒâ€œN
; ============================================

[UninstallDelete]
; Limpiar archivos generados en runtime
Type: filesandordirs; Name: "{app}\PineconeMC\instances\2026UNI\.minecraft\mods"
Type: filesandordirs; Name: "{app}\PineconeMC\instances\2026UNI\.minecraft\config"
Type: filesandordirs; Name: "{app}\PineconeMC\instances\2026UNI\.minecraft\logs"
Type: filesandordirs; Name: "{app}\PineconeMC\instances\2026UNI\.minecraft\cache"
Type: filesandordirs; Name: "{app}\PineconeMC\instances\2026UNI\.minecraft\.cache"
Type: filesandordirs; Name: "{app}\PineconeMC\libraries"
Type: filesandordirs; Name: "{app}\PineconeMC\meta"
Type: filesandordirs; Name: "{app}\PineconeMC\logs"

; ============================================
; CÃƒâ€œDIGO PASCAL (post-instalaciÃ³n)
; ============================================

[Code]

// Verifica si VC++ Redistributable 2015-2022 (x64) estÃƒÂ¡ instalado
function NeedsVCRedist: Boolean;
var
  Version: String;
begin
  Result := True;
  // VC++ 2015-2022 Redist registra su versiÃ³n aquÃ­
  if RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Version', Version) then
  begin
    // Si existe la clave, ya estÃƒÂ¡ instalado
    Result := False;
  end
  else if RegQueryStringValue(HKLM, 'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\X64', 'Version', Version) then
  begin
    Result := False;
  end;
end;

// Se ejecuta despuÃƒÂ©s de que todos los archivos se copiaron
procedure CurStepChanged(CurStep: TSetupStep);
var
  PortablePath: String;
  InstanceCfgPath: String;
  PrismCfgPath: String;
  JavaPath: String;
  PackUrl: String;
  CfgContent: String;
  PrismContent: String;
begin
  if CurStep = ssPostInstall then
  begin
    // ========================================
    // 1. Crear portable.txt (activa modo portÃƒÂ¡til de Prism)
    // ========================================
    PortablePath := ExpandConstant('{app}\PineconeMC\portable.txt');
    SaveStringToFile(PortablePath, '', False);

    // ========================================
    // 2. Escribir instance.cfg con la ruta real de Java
    // ========================================
    JavaPath := ExpandConstant('{app}\jre21\bin\javaw.exe');
    // Convertir backslashes a forward slashes para compatibilidad
    StringChangeEx(JavaPath, '\', '/', True);
    
    PackUrl := 'https://brian-latorre.github.io/2026UNI/pack.toml';
    InstanceCfgPath := ExpandConstant('{app}\PineconeMC\instances\2026UNI\instance.cfg');

    CfgContent := '[General]' + #13#10;
    CfgContent := CfgContent + 'ConfigVersion=1.2' + #13#10;
    CfgContent := CfgContent + 'iconKey=default' + #13#10;
    CfgContent := CfgContent + 'name=2026UNI' + #13#10;
    CfgContent := CfgContent + 'notes=Modpack privado del servidor 2026UNI.\nMinecraft 1.20.1 + Forge 47.4.16\n\nLas actualizaciones se descargan autom\u00e1ticamente al darle Play.' + #13#10;
    CfgContent := CfgContent + #13#10;
    CfgContent := CfgContent + 'OverrideCommands=true' + #13#10;
    CfgContent := CfgContent + 'PreLaunchCommand=cmd.exe /c "$INST_DIR/pre-launch.bat"' + #13#10;
    CfgContent := CfgContent + 'PostExitCommand=cmd.exe /c "$INST_DIR/enviar-logs.bat"' + #13#10;
    CfgContent := CfgContent + #13#10;
    CfgContent := CfgContent + 'OverrideJavaLocation=true' + #13#10;
    CfgContent := CfgContent + 'IgnoreJavaCompatibility=true' + #13#10;
    CfgContent := CfgContent + 'JavaPath=' + JavaPath + #13#10;
    CfgContent := CfgContent + #13#10;
    CfgContent := CfgContent + 'OverrideMemory=true' + #13#10;
    CfgContent := CfgContent + 'MinMemAlloc=3072' + #13#10;
    CfgContent := CfgContent + 'MaxMemAlloc=5120' + #13#10;
    CfgContent := CfgContent + 'LowMemWarning=false' + #13#10;
    CfgContent := CfgContent + #13#10;
    CfgContent := CfgContent + 'OverrideJavaArgs=true' + #13#10;
    CfgContent := CfgContent + 'GarbageCollectorPreset=None' + #13#10;
    CfgContent := CfgContent + 'UseOptimizedJvmArgs=false' + #13#10;
    CfgContent := CfgContent + 'JvmArgs=-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dfml.ignorePatchDiscrepancies=true -Dfml.ignoreInvalidMinecraftCertificates=true' + #13#10;

    SaveStringToFile(InstanceCfgPath, CfgContent, False);

    // ========================================
    // 3. ConfiguraciÃ³n global de Prism (saltar wizard)
    // ========================================
    PrismCfgPath := ExpandConstant('{app}\PineconeMC\elyprismlauncher.cfg');
    
    PrismContent := '[General]' + #13#10;
    PrismContent := PrismContent + 'ApplicationTheme=system' + #13#10;
    PrismContent := PrismContent + 'HasDoneInitialSetup=true' + #13#10;
    PrismContent := PrismContent + 'JavaPath=' + JavaPath + #13#10;
    PrismContent := PrismContent + 'Language=es_ES' + #13#10;
    PrismContent := PrismContent + 'MaxMemAlloc=5120' + #13#10;
    PrismContent := PrismContent + 'MinMemAlloc=3072' + #13#10;
    PrismContent := PrismContent + 'LastHostname=2026UNI' + #13#10;
    PrismContent := PrismContent + 'GarbageCollectorPreset=None' + #13#10;
    PrismContent := PrismContent + 'UseOptimizedJvmArgs=false' + #13#10;
    PrismContent := PrismContent + 'LowMemWarning=false' + #13#10;

    // Siempre sobreescribir para garantizar que no queden configuraciones rotas
    SaveStringToFile(PrismCfgPath, PrismContent, False);
  end;
end;
