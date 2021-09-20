# Video Mode Switcher

This directory contains tools to quickly switch the video mode
between 1080p50 and 1080p60. Its main purpose is adapting the video mode
of the computer displaying slides to the main video mode of the actual content
during a demoscene competition.

--------------------------------

## Windows Version

Use Visual Studio 2019 (any edition) to open the `.sln` file and build the `Release|x86` configuration. The resulting executable will automatically be copied into the `bin` directory of the CompoKit directory tree.

`vidmode.exe` runs in the background. After it has been started, the hotkeys
Ctrl+Win+Alt+5 and Ctrl+Win+Alt+6 select a 50 Hz or 60 Hz for the video output,
if these modes are available. It does **not** work in multi-monitor setups,
and the modes must be offered by the graphics driver; note that this is often
not the case by default, and a 50 Hz mode must be created manually!

To exit the program, just run `vidmode.exe` again.

--------------------------------

## X11 Version

The X11 version comes in form of a Bash script, `vidmode.sh`, that uses
the standard `xrandr` tool under the hood. It's just run with one
of two parameters:
- `./vidmode.sh 1080p50` sets all displays to 1080p50 mode
- `./vidmode.sh 1080p60` sets all displays to 1080p60 mode

There are numerous differences to the Windows version:
- It does not assign hotkeys or stay resident.
  To make it available with system-wide hotkeys like on Windows,
  use the desktop environment's built-in hotkey facilities and configure them
  to run `vidmode.sh` with the appropriate parameter when the key combo is pressed.
- It not just sets the refresh rate, but a fixed video resolution too.
- If 1080p50 is not a mode advertised by the monitor's EDID,
  it tries to set it nevertheless.
- It works with multi-monitor setups, and configures them to clone all displays.
