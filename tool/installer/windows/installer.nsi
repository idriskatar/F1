; F1 Tracker — NSIS kurulum betiği (kullanıcı bazında, yönetici izni gerekmez)
!define APPNAME "F1 Tracker"
!define VERSION "1.6.9"
!define EXE "f1_tracker.exe"

Name "${APPNAME} v${VERSION}"
OutFile "F1-Tracker-Setup-v${VERSION}.exe"
InstallDir "$LOCALAPPDATA\${APPNAME}"
InstallDirRegKey HKCU "Software\F1Tracker" "InstallDir"
RequestExecutionLevel user
ShowInstDetails show

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Install"
  SetOutPath "$INSTDIR"
  File /r "app\*.*"
  CreateDirectory "$SMPROGRAMS\${APPNAME}"
  CreateShortcut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\${EXE}"
  CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${EXE}"
  WriteRegStr HKCU "Software\F1Tracker" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "Software\F1Tracker" "Version" "${VERSION}"
  WriteUninstaller "$INSTDIR\uninstall.exe"
SectionEnd

Section "Uninstall"
  Delete "$INSTDIR\uninstall.exe"
  Delete "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk"
  Delete "$DESKTOP\${APPNAME}.lnk"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "Software\F1Tracker"
SectionEnd
