@echo off
set url="%~f1"
if "%1" == "" set url="about:config?filter=security.fileuri.strict_origin_policy"
set firefox="%ProgramW6432%\Mozilla Firefox\firefox.exe"
if not exist %firefox% set firefox="%ProgramFiles(x86)%\Mozilla Firefox\firefox.exe"
start "" %firefox% -profile "%TEMP%\compokit_firefox_profile" %url%