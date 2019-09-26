# CompoKit

CompoKit is an all-inclusive environment with (almost) all tools required for hosting PC demoscene competitions.

## Contents

A CompoKit installation mainly consists of third-party tools:

- **File Manager:** [Total Commander](https://www.ghisler.com/index.htm), [7-Zip](https://www.7-zip.org/) and [CKLaunch](src/cklaunch), a custom launcher tailored for running compos
- **Video Player:** [MPC-HC](https://mpc-hc.org/)
- **Audio Player:** [XMPlay](https://www.un4seen.com/xmplay.html) with [OpenMPT Plugin](https://lib.openmpt.org/libopenmpt/) and additional plugins for SID, AHX and YM
- **Image Viewer:** [XnView](https://www.xnview.com/en/), [CompoView](https://www.pouet.net/prod.php?which=56934), [GLISS](http://svn.emphy.de/scripts/trunk/gliss.cpp)
- **ANSI Viewer:** [ACiDView](https://sourceforge.net/projects/acidview6-win32/) and [Sahli](https://github.com/m0qui/Sahli)
- **DOS Emulator:** [DOSBox](https://www.dosbox.com/) and [DOSBox-X](https://dosbox-x.com/)
- **Text Editor:** [Notepad++](https://notepad-plus-plus.org/)
- **PDF Viewer:** [SumatraPDF](https://www.sumatrapdfreader.org/)
- Graphics compo background music
  - a selection of nice, not too bombastic demoscene music *(not included in the repository)*
  - a script ("`play_shuffled.cmd`") to generate shuffled playlists of whole directories and play them back, using the [Balanced Shuffle](https://keyj.emphy.de/balanced-shuffle/) algorithm
- an installation of Google Chrome is required for some features, but **not** included
  - there is, however, a script that calls Chrome with `--allow-file-access-from-files` where JavaScript demos can simply be dragged and dropped onto

## Features

- Most programs and their configuration files are contained in a single directory, `bin`.
- As far as possible, the programs are set up in a "portable" mode that eliminates or minimizes interference with possible pre-existing system-wide installations of the same programs.
- All tools are automatically downloaded and unpacked using a PowerShell script. No special software needs to be pre-installed.

## Installation

Just run `scripts/setup.cmd`. This will download and unpack everything.

## Special Configuration Options

Some of the tools are pre-configured in non-standard ways:

- CKLaunch
  - medium-contrast "dark" color scheme with Segoe UI font
  - file associations pre-configured to use all the tools CompoKit provides
- Total Commander
  - medium-contrast "dark" color scheme with Segoe UI font
  - search files in the current directory by simply typing letters (no Ctrl or Alt required)
  - F2 key renames files
  - Passive FTP by default
  - single-instance mode
- MPC-HC
  - starts in fullscreen mode
  - starts paused (press Space to start playback)
  - doesn't leave fullscreen mode when playback is complete
  - Q key quits (instead of Alt+X)
  - uses the Sync Renderer to minimize framedrops and judder
- XMPlay
  - OpenMPT plugin is used by default for MOD, XM and IT formats
  - OpenMPT pattern visualization is configured with maximum font size
  - interpolation and stereo separation is **not** configured; you need to switch to mono without filtering manually when playing proper MOD files!
  - SID is configured for Mono output with 8580 digi boost enabled
  - single-instance mode
- XnView
  - medium-contrast "dark" color scheme
  - shows only image files in browser, nothing else
  - all toolbars except menu and status bar disabled
  - Enter key goes directly to fullscreen mode
  - no image info overlays on thumbnails or in fullscreen mode
- Sahli
  - a little script `_run.cmd` is put into the Sahli directory that launches Sahli in Chrome
- SumatraPDF
  - English language
  - page layout set to "single page, don't save for every document"
- DOSBox
  - provided config file `dosbox.conf` sets fullscreen with correct aspect ratio, maximum speed (`cycles=max`) and 48000 Hz sample rate from all audio sources (including GUS and Covox)
