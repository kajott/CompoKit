@echo off
if "x%1x" == "xx" goto fail

set ckroot="%~dp0\.."
if not exist "%ckroot%\temp" mkdir "%ckroot%\temp"
rmdir /s /q "%ckroot%\temp\dh0" >nul
mkdir "%ckroot%\temp\dh0"
copy /b "%1" "%ckroot%\temp\dh0\autorun" >nul
mkdir "%ckroot%\temp\dh0\s"
echo dh0:autorun >"%ckroot%\temp\dh0\s\startup-sequence"

cd "%~dp0"
winuae64 -f a500.uae -s filesystem2=rw,dh0:dh0:..\temp\dh0,0

goto end
:fail
echo No file to run specified.
pause
:end