@echo off
set url="%~f1"
if "%1" == "" set url="about:config?filter=security.fileuri.strict_origin_policy"
"%ProgramFiles%\Mozilla Firefox\firefox.exe" -profile "%TEMP%\compokit_firefox_profile" %url%