@echo off

@rem "This little script sets a few useful settings in Windows 10/11 that may"
@rem "be useful for demoscene compo PCs."

@rem "It is a stripped-down and less opionionated version of this script:"
@rem "    https://gist.github.com/kajott/05b84fb630b4bc6c90337131f320a5c9"

@rem "Usage:"
@rem "Just run this file with Administrator privileges."

@echo ***** checking administrator privileges
net file >nul 2>nul
@if errorlevel 1 (
    @echo This script should be run with administrator privileges.
    @echo Press ^^C and Y now or close this window to exit,
    @echo or press Enter to continue without administrator privileges.
    @pause
)
@echo.

@echo ***** show hidden files in Explorer
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v Hidden /t REG_DWORD /d 1 /f /reg:32
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v Hidden /t REG_DWORD /d 1 /f /reg:64
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v ShowSuperHidden /t REG_DWORD /d 1 /f /reg:32
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v ShowSuperHidden /t REG_DWORD /d 1 /f /reg:64
@echo.

@echo ***** show file extensions in Explorer
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v HideFileExt /t REG_DWORD /d 0 /f /reg:32
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v HideFileExt /t REG_DWORD /d 0 /f /reg:64
@echo.

@echo ***** open Explorer windows in separate processes
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v SeparateProcess /t REG_DWORD /d 0 /f /reg:32
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v SeparateProcess /t REG_DWORD /d 0 /f /reg:64
@echo.

@echo ***** enable compact mode in Win11 Explorer
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v UseCompactMode /t REG_DWORD /d 1 /f /reg:32
reg add HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced /v UseCompactMode /t REG_DWORD /d 1 /f /reg:64
@echo.

@echo ***** use standard context menus in Win11 Explorer
reg add HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32 /ve /d "" /f /reg:32
reg add HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32 /ve /d "" /f /reg:64
@echo.

@echo ***** remove desktop.ini from Desktop
del /ah /f %USERPROFILE%\Desktop\desktop.ini %PUBLIC%\Desktop\desktop.ini
@echo.

@echo ***** disable automatic driver download
reg add HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching /v SearchOrderConfig /t REG_DWORD /d 0 /f
@echo.

@echo ***** disable reboot on automatic updates
@rem cf. https://docs.microsoft.com/en-us/windows/deployment/update/waas-restart
reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU /v AUOptions /t REG_DWORD /d 4 /f
reg add HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU /v NoAutoRebootWithLoggedOnUsers /t REG_DWORD /d 1 /f
@echo.

@echo ***** disable Virtualization Based Security / Core Isolation
reg add HKLM\SOFTWARE\CurrentControlSet\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity /v Enabled /t REG_DWORD /d 0 /f
@echo.

@echo ***** disable Hybrid Shutdown
reg add "HKLM\System\CurrentControlSet\Control\Session Manager\Power" /v HiberbootEnabled /t REG_DWORD /d 0 /f
@rem "or manually: Win+X -> Power Options -> Related Settings -> Additional Power Settings"
@rem "             -> Choose what the power button does [Sidebar]"
@rem "             -> Change settings that are currently unavailable [Shield]"
@rem "             -> disable 'Turn on fast startup (recommended)'"
@echo.

@echo ***** disable display change animation
reg add HKLM\SOFTWARE\Microsoft\Windows\Dwm /v ForceDisableModeChangeAnimation /t REG_DWORD /d 1 /f
@echo.

@echo.
@echo Will now close all Explorer windows and restart Explorer.
@echo Press ^^C and Y now or close this window to avoid that.
@pause
taskkill /f /im explorer.exe
start explorer.exe
:end