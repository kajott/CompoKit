# CompoKit

CompoKit is an all-inclusive environment with (almost) all tools required for hosting PC demoscene competitions.

## Contents

A CompoKit installation mainly consists of third-party tools:

- File Management: [Total Commander](https://www.ghisler.com/index.htm), [7-Zip](https://www.7-zip.org/)
- Video Player: [MPC-HC](https://mpc-hc.org/)
- Audio Player: [XMPlayer](https://www.un4seen.com/xmplay.html) with [OpenMPT Plugin](https://support.xmplay.com/files_view.php?file_id=660) **(TODO)**
- Image Viewer: [XnView](https://www.xnview.com/en/), [CompoView](https://www.pouet.net/prod.php?which=56934), [GLISS](http://svn.emphy.de/scripts/trunk/gliss.cpp) **(TODO)**
- ANSI Viewer: [ACiDView](https://sourceforge.net/projects/acidview6-win32/) and [Sahli](https://github.com/m0qui/Sahli) **(TODO)**
- DOS Emulator: [DOSBox](https://www.dosbox.com/) and [DOSBox-X](https://dosbox-x.com/) **(TODO)**
- Graphics compo background music: a selection of nice, not too "aggressive" demoscene music **(TODO)**
- Launcher: `CKLaunch`, a custom launcher tailored for running compos **(TODO)**
- an installation of Google Chrome or Mozilla Firefox is required, but **not** included

## Features

- Most programs and their configuration files are contained in a single directory, `bin`.
- As far as possible, the programs are set up in a "portable" mode that eliminates or minimizes interference with possible pre-existing system-wide installations of the same programs.
- All tools are automatically downloaded and unpacked using a PowerShell script. No special software needs to be pre-installed.

## Special Configuration Options

Some of the tools are pre-configured in non-standard ways:

- Total Commander
  - medium-contrast "dark" color scheme
  - Fixedsys font
  - search files in the current directory by simply typing letters (no Ctrl or Alt required)
  - F2 key renames files
  - Passive FTP by default
- MPC-HC
  - starts in fullscreen mode
  - starts paused (press Space to start playback)
  - doesn't leave fullscreen mode when playback is complete
  - Q key quits (instead of Alt+X)
  - uses the Sync Renderer to minimize framedrops and judder
