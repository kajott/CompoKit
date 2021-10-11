@echo off
set chrome="%ProgramW6432%\Google\Chrome\Application\chrome.exe"
if not exist %chrome% set chrome="%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe"
start "" %chrome% ^
--user-data-dir="%TEMP%\compokit_chrome_profile" ^
--allow-file-access-from-files ^
--start-fullscreen ^
"%~f1"