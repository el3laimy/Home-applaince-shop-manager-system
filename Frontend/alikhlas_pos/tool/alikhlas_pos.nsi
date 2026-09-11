; Builds a per-user Windows installer from Flutter's Release directory.
; CI supplies SOURCE_DIR, OUTPUT_DIR, and APP_VERSION.
Unicode true
RequestExecutionLevel user
SetCompressor /SOLID lzma

!ifndef SOURCE_DIR
  !error "SOURCE_DIR must point to the Flutter Windows Release directory"
!endif
!ifndef OUTPUT_DIR
  !error "OUTPUT_DIR must point to the installer output directory"
!endif
!ifndef APP_VERSION
  !error "APP_VERSION must be the three-part application version"
!endif
!ifndef ICON_FILE
  !error "ICON_FILE must point to a valid Windows .ico file"
!endif

!define APP_NAME "إخلاص POS"
!define APP_ID "ALIkhlasPOS-v2-5B7C2A10-59F8-4BB7-ACDA-7E3207B2A2A4"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_ID}"

Name "${APP_NAME}"
OutFile "${OUTPUT_DIR}\ALIkhlasPOS-Setup-${APP_VERSION}-x64.exe"
InstallDir "$LOCALAPPDATA\Programs\ALIkhlas POS"
InstallDirRegKey HKCU "Software\${APP_ID}" "InstallDir"
Icon "${ICON_FILE}"
UninstallIcon "${ICON_FILE}"
VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey /LANG=1033 "ProductName" "ALIkhlas POS"
VIAddVersionKey /LANG=1033 "ProductVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1033 "FileDescription" "ALIkhlas POS installer"
VIAddVersionKey /LANG=1033 "CompanyName" "ALIkhlasPOS"

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Section "Install ${APP_NAME}" SEC_MAIN
  SetOutPath "$INSTDIR"
  File /r "${SOURCE_DIR}\*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortcut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\alikhlas_pos.exe"
  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\alikhlas_pos.exe"

  WriteRegStr HKCU "Software\${APP_ID}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\alikhlas_pos.exe"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1
SectionEnd

Section "Uninstall"
  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  DeleteRegKey HKCU "Software\${APP_ID}"
  RMDir /r "$INSTDIR"
SectionEnd
