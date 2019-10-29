# How to host ANSI/ASCII/PETSCII compos with Sahli

This document describes how to use [Sahli](https://github.com/m0qui/Sahli) to host ANSI/ASCII/PETSCII compos at demoparties.

Credits go to m0qui, who is not only a contributor to Sahli itself, but also wrote a very comprehensive manual for me to use at Deadline 2019. This document is basically his notes, translated into English and fleshed out a little.

## A word of warning

First of all, be aware that Sahli isn't exactly famous for its user-friendliness. It is a tool made for the purpose of hosting compos only, it's a bit cumbersome to set up and use (editing JSON files, remembering peculiar keyboard shortcuts), and it's not very forgiving when doing something wrong.

Now that we have that out of our way, let's get started, shall we?

## Installation and startup

Simply clone the GitHub repository https://github.com/m0qui/Sahli, or download [a ZIP archive](https://github.com/m0qui/Sahli/archive/master.zip) from it. If you're using CompoKit, this will already be set up for you by running `scripts/setup.cmd`.

Sahli runs in a browser; Firefox and Chrome have been tested and work fine. Simply double-clicking `index.html` may work, but only if JavaScript is allowed to access local files, which is normally isn't. If a message with the text "SAHLI READY TO GO" pops up when opening the page, everything  is fine; if it doesn't, open the `about:config` page in Firefox and set `security.fileuri.strict_origin_policy` to `false`, or run Chrome with the `--allow-file-access-from-files` option.

Again, CompoKit users are at an advantage here, because the CompoKit launcher is not only pre-configured to run Chrome with the appropriate options when double-clicking `index.html`, it also creates a `_run.cmd` file in the Sahli directory that does the same. In both cases, Chrome also runs fullscreen and with a separate profile, which forces a new instance instead of just opening a new tab in an existing Chrome window. If you prefer Firefox, just drag `Sahli/index.html` onto `bin/Firefox.cmd` to start it.

## Basic concepts

Sahli doesn't just view single entries, but whole compos. The list of files and their properties is configured in the central file `list.sahli`, using JSON syntax. It can show ANSI (`.ans`) and ASCII (`.asc`) entries directly with an internal renderer, or just display images in PNG or JPEG format. All these files are located in a single subdirectory.

The tool itself is entirely keyboard-controlled. The mouse just does nothing; hence, when running the compo, the first thing you do after starting Sahli is entering fullscreen mode (if not already done) and moving the mouse cursor to the right edge of the screen to make it invisible.

## Preparing entries and `list.sahli`

First, create a subdirectory named after your compo or party in the Sahli directory, e.g. `mycompo`. Make a backup of the `list.sahli` file that ships as an example (you might want to have a look at it later, as a point of reference) and create a new skeleton `list.sahli` file with the following contents:

    {
        "location": "mycompo",
        "filedata": [
        ]
    }

Next, you'll populate the `filedata` array in the JSON file with entries for the individual items to show. In most cases, you can use one of the following snippets. Whatever you do, make sure that the file is valid JSON! If you start Sahli and the "READY TO GO" message doesn't appear, you know that you did something wrong.

### Images

Apart from ANSI/ACSII, Sahli can show simple JPEG or PNG images. In principle, it can thus be used for graphics compos, but I wouldn't recommend that, especially since the zooming options don't work properly for images &ndash; there's basically just two zoom levels: "original size, but fit to height if too tall", and "fit to width".

        {
            "file": "SomeImage.png",
            "filetype": "image"
        }

### ANSI

For ANSI entries, Sahli can use [ansilove.js](http://ansilove.github.io/ansilove.js/) and its built-in fonts for rendering.

        {
            "file": "SomeANSIEntry.ans",
            "filetype": "ansi",
            "font": "80x25"
        }

The most useful fonts for PC entries are `80x25`, `80x25small` and `80x50`, and for Amiga entries `topaz`, `topaz500`, `microknight`, `mosoul` and `pot-noodle`. For a full list of supported fonts, see the [README file of ansilove.js](https://github.com/ansilove/ansilove.js/blob/master/README.md). Note that the font names are case-sensitive.

The ANSI renderer can of course also be used for ASCII entries.

### ASCII

For plain-text entries that don't need non-Latin characters, there's a simple HTML+CSS-based renderer. In comparison to the ANSI renderer, it supports wider canvases than 80 characters, and you can (and, in fact, you *must*) specify the foreground and background colors explicitly in RGBA format:

        {
            "file": "AmigaASCII.asc",
            "filetype": "plain",
            "font": "pcansifont",
            "color": [0,0,0,255],
            "bg": [255,255,255,255]
        }

The font options are slightly different: For PC, `pcansifont` is the only option; for Amiga, there's `topaz1200` (note the "1200"!), `topaz500`, `microknight`, `mosoul` and `pot-noodle`.

### PETSCII

Sahli doesn't support PETSCII entries directly, so these must be shown on original hardware if available, or by pre-rendering them into an image using an emulator. To show them in a pixel-perfect manner, it's highly recommended to upscale the images without interpolation by an integer factor so it fills the screen nicely.

Here's what to do specifically:

- Run the `.prg` file in a C64 emulator. The following steps are written for WinVICE <= 3.1, YMMV with other emulators.
  - If you're using CompoKit, just run the `.prg` file from the Launcher.
- Configure the VICE palette appropriately. By default, the brightness is set far too high, so the image looks fine with scanlines, but since you're going to export an image without scanlines, you need to compensate for that. Leaving everything at defaults except "Settings &rarr; Video settings &rarr; VICII Colors &rarr; Brightness = 0.750" seems to be a very good compromise to me.
  - Again, if you're using CompoKit, this has already been set up for you.
- Press Alt+C (or select "Snapshot &rarr; Save/stop media file" from the menu) and save a PNG screenshot into your compo directory. The resulting image file should have a resolution of 384x272.
- Upscale the image to 1536x1088 with "nearest neighbor" interpolation. In CompoKit, the steps are the following:
  - Start the `.png` file from the Launcher.
  - Press Enter to leave XnView's fullscreen mode.
  - Press Shift+S (or click "Image &rarr; Resize ...").
  - Set Width to 1536; Height should be automatically set to 1088 then.
  - Select "Resample &rarr; Nearest Neighbor".
  - Press Ctrl+S ("File &rarr; Save") and confirm the overwrite prompt.
- Enter the PNG file as an image into `sahli.list`.

## Controls

Now is the time to make yourself familiar with Sahli's controls. The built-in help function is very useful at this, but here are the keys you'll most likely use:

| Key | Function
|:---:|---------
| H | show help screen
| Space | go to next entry (wraps around at end)
| P | go to previous entry
| Z | toggle zoom between original size and fit-to-width
| T | go to the top of the entry and reset/toggle zoom
| B | go to the bottom of the entry
| E | zoom in
| R | zoom out
| S | start auto-scrolling in opposite direction of last auto-scroll (initial direction for each entry: downwards)
| W | start scrolling upwards
| X | start scrolling downwards
| A | stop auto-scrolling
| 1-5 | set scroll speed (1 = fastest, 5 = slowest = default)
| Cursor | scroll manually
| V | center small entry vertically
| C | toggle "panel mode": show tall entries in multiple columns

## Compo Preparation

For every entry, you will need a slightly different strategy to show it in an appropriate manner.

Entries that fit onto a single screen just need to be zoomed and panned appropriately before putting them onto the bigscreen, but the way to get there sometimes differs a bit. Usually, "Z V" or "T V" is a good way to start, but some entries may need additional manual scrolling.

To present taller entries, the auto-scroll feature should be used. The default recipe here is "Z S" or just "S", but some manual scrolling may be required before starting auto-scroll too. When the end of the entry has been reached, just press "S" again for another upwards pass over the entry. If it's a little longer and you've shown it in "fit-to-width" mode (as you should!), maybe press "Z" before to shorten the upwards pass a bit by having only 1:1 zoom. Regardless of how long the entry is: at the end, an overview of it should be presented. For shorter entries, just zooming out an appropriate number of times ("R R R ...") is sufficient; for really long, epic ANSIs (hi Blocktronics!), Sahli's "panel mode" (press "T C") is the weapon of choice.

It's next to impossible to remember all those recipes during the compo, so **make notes**! A good old-fashioned sheet of paper where you note the necessary keystrokes at begin (before and after the bigscreen input switch), middle and end for each entry is a worthwhile investment. And you should absolutely rehearse the compo again (with this "cheatsheet" on the table) before going live.

## The Compo itself

With everything being well-prepared and rehearsed, there should be no unpleasant surprises during the compo; the only additional element being that you now actually switch the bigscreen inputs. Take your time, don't rush through the compo too quickly; ANSI/ASCII art deserves no less respect than other graphics compos.
