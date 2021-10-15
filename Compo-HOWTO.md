# KeyJ's Compo Manual

This document describes one possible way how compos at a demoparty can be prepared and executed. I'm not going to say that it's the best way of doing things, but I think it's rather efficient and certainly worked quite well during the compos I hosted at the Deadline demoparty.

-------------------------------------------------------------------------------

## Setup

### Party Network and PMS

The main prerequisites are a working party network and a Party Management System like Assembly's [PMS](https://github.com/compocrew/PMS), Function's [Wuhu](http://wuhu.function.hu/) or Revision's [PartyMeister](http://www.partymeister.org/) *(warning: hopelessly outdated website!)*. I will focus on PartyMeister here, because that's what I know best (or rather, at all).

The party network should have a dedicated organizer network that's not accessible from the visitor tables or WiFi; we don't want visitors to mess with our compo PCs, after all! The PMS will of course run in a DMZ to which both visitors and organizers have access.

### Compo PCs and CompoKit

The most important machine is, of course, the compo PC, i.e. a powerful box with a fast CPU and a top-of-the-line GPU. On that PC, create a directory for all the data of the party. Put a CompoKit checkout into a subdirectory of that. It may make sense to download everything (i.e. run `setup.cmd` and `download_music.cmd`) before the party already, as the Internet connection may be too slow to do that in an acceptable amount of time.

Ideally, there are two compo PCs, with identical or slightly different hardware; one nVidia and one AMD GPU may be handy, for example. In this case, I tend to make one of them the "main" or "primary" compo PC, i.e. the one where most of the preparations are done and most of the compos are presented from. The other one is the "secondary" PC, which is used to play entries that don't work properly on the main compo PC, play background music, run the typer (see below) or prepare compos while the main PC is used for other stuff.

The party directory should be shared between the PCs; the easiest way to do this is to share the directory on the main PC and mount it on the compo PC. Bonus points for making sure that the paths are identical on both PCs; this way, anything that stores absolute paths (like CKLaunch's state file) will work on both machines. Since the party directory typically isn't the root of a drive, simply mapping a network drive doesn't suffice; instead, something like `mklink /d C:\MyParty \\Compo1\MyParty` is required. On the main PC, the network connection must be set to "Private Network" (otherwise file sharing isn't possible), and the logged-in user needs to have a &ndash; however trivial &ndash; password (otherwise Windows won't allow remote connections).
(Oh, and while we're at it: don't start CKLaunch on both PCs at the same time &ndash; the two instances will clobber each other's state file where the default file marks are stored!)

Two directories should be added to the anti-virus software's exception list: The compo directory and the web browser's download directory. We don't want any 64k or 4k intros taken into quarantine while preparing compos, just because anti-virus vendors think that every kkrunchy-packed executable is evil.

Another nice touch is a custom party wallpaper that also includes the machine name ("Compo 1" / "Compo 2").

### Slides PC

There needs to be a dedicated PC or notebook for displaying the PMS slides. Current Wuhu and PartyMeister versions only need a web browser for displaying the slides (not sure about the Assembly PMS), so it can be any platform, as long as the machine is moderately powerful. In fact, it can even run on the same box as the PMS itself.

The keyboard of the slides PC must be accessible at all times from the compo organizer's desk. It can be in the second row though, as we won't type any amount of text on it &ndash; basically we just need the cursor keys and the spacebar.

During 50-Hz-heavy compos (like oldschool executable compos), a nice touch would be if we can temporarily set the slides PC's output to 1080p50, so the main projector (often a DLP-based model) doesn't need to re-sync between the the slides' 60p and the entries' 50p framerate all the time. If the slide client software has something like that built-in, that's perfect; if it doesn't, CompoKit's [vidmode](src/vidmode) tool may prove useful.

We may want to include [Mercury's calibration slide](http://mercury.sexy/calibration02.png) in the main rotation, so people get a feeling of how badly the projector crushes blacks and whites. However, please note that the gamma calibration part of that slide is absolutely useless if the projector applies any kind of scaling or interpolation, e.g. because its native resolution is different from what the party picked as the default, or because it can't do optical keystone correction. In that case, better leave out the slide &ndash; don't confuse the hell out of people who want to calibrate their entries with a broken gamma chart then.

### Typer

Depending on the PMS used, creating new slides can be more or less cumbersome. To inform the audience about things in a more "ad-hoc" manner, a way to type text-only slides "live" is really useful. A dedicated PC for that would be great, but using the "secondary" compo PC (if it exists) is usually fine as well.

Again, the keyboard should be accessible at all times (at least as long as the typer is in use), and in a way that allows comfortable typing, especially since we're using it more or less "blindly" (i.e. without a cursor).

### Audio

In terms of audio, we want to ensure two things: first, while preparing compos, we absolutely need a possibility to listen to the compo PC's output with headphones. Second, at the same time we must make sure that the headphone output is always active *in addition to* the main audio that goes to the mixing desk. Switching between the outputs is unacceptable because we **will** forget to switch to main audio before a compo at some point, inadvertantly playing entries without sound.

There are various ways to fulfill these requirements: A carefully-chosen configuration of the on-board audio codec may work; the mixing console may have a dedicated headphone output for that; or use an external audio interface that has a built-in headphone amplifier, mapped to the same audio channels as the main Cinch / TRS / XLR output. The latter setup is the most comfortable, as we can have good access to the box's volume knob, at the expense of being subject to USB-related issues like flaky cables. If the box doesn't require any fancy drivers and just works with Windows' (and Linux's, for that matter) standard USB audio class drivers, that's a big plus.

If using an external interface, disabling the on-board audio device in the BIOS setup or Device Manager might be a good idea to make sure that no program can use the wrong audio output by accident. But then again, I've never seen this becoming a problem, and even if on-board audio is neutered, the HDMI output's audio devices would still be present (and can't easily be deactivated), so this might be overkill after all. Just make sure that the interface is selected as the system's primary output, and we're set.

### Control Monitors

These should be at least three control monitors available at the compo desk. Most of the time, they will show the video from their dedicated "default" source (usually Compo PC 1, Compo PC 2 or Typer, Slides), but at least two of them should be connected to the video matrix to be able to preview other sources.

### Video &ndash; The DVI/HDMI Matrix

The centerpiece of the video chain is the video matrix or "crossbar switch", i.e. a device that can assign any of N DVI/HDMI inputs to any of M DVI/HDMI outputs. It's rather important that this is a "dumb" switch, and not something that contains a scaler or similar, because these devices may have stupid ideas like force-converting 50 Hz content (i.e. anything oldschool) to 60 Hz, causing unacceptable jerky motion.

The following **inputs** are typically attached to the matrix:
- Main Compo PC
- Secondary Compo PC
- Typer
- Slides
- Oldschool
- Jingle
- HDMI Extender from the stage (for on-stage VJs, or seminar presenters)
- spare HDMI cable on the compo desk, for whatever may be useful at the moment (off-stage VJ, compo entry being presented off a notebook, ...)

The following **outputs** are typically attached to the matrix:
- Main Bigscreen
- Second Bigscreen (smaller screen at the side)
- main input for video streaming team
- Control Monitors, lots of them; any output we can spare should go to a monitor :)

So, an 8x8 matrix is generally sufficient (at least for a smaller party; Revision or Assembly may have a different view on this). The vendor and model *should* not matter, but we had some very unpleasant surprises with a LightWare MX8x8DVI-HDCP-Pro at Deadline 2018; the Extron DXP 88 HDMI we got at Deadline 2019 and 2021 worked without a hitch.

Operating the matrix directly from the front panel is workable, but cumbersome. During compos, we frequently end up assigning one input to three outputs (both bigscreens and the stream) at the same time, requiring five careful keystrokes each time. Fortunately, there's a better way: use the [dvi_matrix_control](src/dvi_matrix_control) script that's part of the CompoKit repository.

- Attach the matrix to the organizer network via its Ethernet port.
- Configure the matrix for DHCP or a static IP address.
- Get a cheap Linux single-board computer (SBC) with at least one Ethernet and USB port (a first-generation Raspberry Pi is totally fine), or use an old notebook.
- Attach a simple USB numerical keypad to the SBC. Make sure that NumLock is on.
- Put the SBC into the organizer network too.
- Temporarily attach the SBC to a free HDMI input and a full keyboard. (Logging into the box via SSH isn't sufficient, as we're going to run a program that relies on input from the numpad.)
- Copy [dvi_matrix_control.py](src/dvi_matrix_control/dvi_matrix_control.py) there, `chmod +x` it and run it.
- Enter the magic connection command on the keypad or keyboard. For example, to connect to an Extron matrix at IP 10.0.2.12, type `//2.10.0.2.12` (the first `2` is the internal code for the Extron protocol). Ensure that a `connection established` message is shown.
- Set up macros. For example, if the two main screens are outputs 1 and 2 and the stream is 3, we may want to configure `*1*1123`, `*2*2123`, `*3*3123` and so on to generate macros `1`, `2`, `3` etc. that switch one input to the three main outputs. Another good idea is to set up a macro (say, `0`) that resets the compo desk monitors to their default inputs.

From then on, switching all main outputs between inputs is a two-keystroke affair: `1`, `Enter`. A nice side effect is that compo intros, the prizegiving and even some compos can be performed while standing instead of sitting; I like this because of the better overview, easier access to the various keyboards scattered across the desk that need to be operated in parallel, and because it's easier to communicate with the other involved people (specifically, the audio and oldschool compo organizers).

### Advanced Video &ndash; The Video Mixer

Thanks to the prevalence of YouTube streamers, the industry produced a lot of relatively inexpensive video mixers in recent years. While we can't solely rely on such a device because it doesn't have nearly enough outputs as we'd need, and because there things kinda _have to_ force-convert everything (including oldschool 50 Hz content) to a fixed output framerate of 60 Hz, it still is a useful addition to the video chain for two reasons: First, we can have smooth crossfades between the slides and the compo PC at the beginning and end of each entry; and second, while we generally want to preserve 50 Hz content for the main screen, the streaming team really prefers having a steady 60 Hz stream.

Keep in mind, though, that having a video mixer doesn't make things easier; quite the contrary! It's one more device to work with during compos, and cabling too becomes more involved:

- There should be two, better three matrix outputs going straight into the mixer. One of those is (almost) permanently assigned to the slides PC, one is assigned to the main compo PC most of the time, and the third one would be for a secondary source of compo material, e.g. the retro desk.

- The jingle and VJ inputs can usually go straight into the mixer.

- The main program output of the mixer (which *must* be HDMI, not just a USB webcam output!) goes back into the matrix, in order to be distributed to the bigscreens and stream desk from there.

- If the mixer has a multi-view HDMI output (e.g. Blackmagic ATEM Mini Extreme), it makes a lot of sense to have a dedicated monitor for that. In fact, _not_ having a multi-view preview (like all "smaller" ATEM Mini models) is a little dangerous, as we can't see what's currently routed into the mixer's inputs, and we'll only notice that the wrong input has been assigned in the matrix after fading over to it.

With those connections in place, most of the compos are really easy to do: Just press one button to fade from the slides to the compo PC and vice-versa. It's only when 50 Hz content is involved that things get nasty &ndash; because remember, we want to have the verbatim 50 Hz signal on the bigscreen, but still have it go through the mixer's 60 Hz conversion for the stream!

To go **into** 50 Hz mode:
- Have the 50 Hz source (e.g. oldschool desk) routed to one of the mixer's inputs. Make sure that it's always the same input, so that matrix controller macros can be used for the things that come next.
- Fade or cut to the 50 Hz source as usual. The bigscreen will still show the 60 Hz converted signal from the mixer; we'll fix that in a second.
- As quickly as possible, re-configure the video matrix (e.g. by having an appropriate macro in the matrix controller):
  - Assign the 50 Hz source to the bigscreens and that one special mixer input we elected in step one.
  - Assign the mixer's output to the stream desk, and _only_ there.
- As a result of this, the bigscreens will get 50 Hz content from now on. DLP projectors may show wrong colors for a second; that's fine. If it's known that the entry that is about to be played as a black or white screen at the beginning, it makes sense to wait with the matrix re-configuration step until that screen comes up.
- While the first entry plays, configure the slides PC to 50 Hz, if possible (otherwise the projector is going to re-sync between 50 Hz and 60 Hz each time we switch from entry to slide or vice-versa; not really bad, but not ideal either).

After that, **in** 50 Hz mode, use the _matrix_ (not the mixer) and its macros to switch inputs: Alternatingly assign the 50 Hz source or the slides PC to the bigscreen and the special mixer input, but *not* the stream output. We're not going to have those smooth cross-fades this way, but that's still way better than having to tolerate jerky scrollers in oldschool demos.

**Leaving** 50 Hz mode is an equally hectic procedure:
- While the last entry 50 Hz plays, switch the slides PC back to 60 Hz output.
- At the end of the last entry, use the mixer to fade back to the slides (which should still be assigned to one mixer input).
- _Immediately_ after that, configure the video matrix back (again with macros, if available): Assign the mixer's output to the stream *and* the bigscreens again.

As can be seen, I really meant it when I said that a video matrix doesn't make life easier! But the creative possibilites are undeniably cool &ndash; Since crossfades can be stopped halfway, we can essentially overlay one source upon another, which is a nice touch in a few scenarios:
- Announcements from the Typer can be displayed over any other content.
- While the VJ plays, we can permanently show the music act's name.
- Music entries that have some kind of visualization (e.g. rasterbars in the oldschool music compo) can be overlaid on the entry's slide.

### Force 50 Hz Output from a PC

The video matrix tells the attached input devices which resolutions and refresh rates it accepts ("EDID"). Typically, there's a simple option to set a single resolution for each input, and 1080p60 is the obvious choice there. We want to output 50p as well though &ndash; specfically, every time an entry is delivered as a video file with a 25 or 50 Hz frame rate. However, Windows only offers to select video modes that are advertised in the EDID. While it's theoretically possible to craft an EDID block that contains both 1080p50 and 1080p60, most video matrices require the user to do this manually, which is quite cumbersome.

An alternative is to simply force a 50 Hz video mode. At least on nVidia GPUs, the driver offers this possibility, with a little manual configuration:
- right-click the desktop, select "NVIDIA Control Panel"
- navigate to "Display", "Change resolution"
- click the "Customize ..." button below the resolution list to open the "Customize" window
- check the "[X] Enable resolutions not exposed by the display" option
- click "Create Custom Resolution"
- set the following values:
  - Horizontal Pixels: 1920
  - Vertical Pixels: 1080
  - Refresh rate (Hz): 50
  - Color depth (bpp): 32
  - Scan type: Progressive
  - Timing Standard: Manual
  - Active Pixels: 1920 (Horizontal) / 1080 (Vertical)
  - Front Porch (pixels): 528 / 4
  - Sync width (pixels): 44 / 5
  - Total pixels: 2640 / 1125
  - Polarity: both Positive (+)
  - Refresh rate: vertical = 50.000 Hz
  - Hint: Entering these values can be sped up by setting 60(!) Hz and timing standard "DMT" first, then switching to Manual timing and changing back to 50 Hz. This way, some of the numbers in the detailed timing pane are already set correctly.
- verify that horizontal refresh rate = 67.50 kHz and Pixel clock = 148.5000 MHz
- click "Test", wait until the display settles, and click "OK"
- the "Custom Resolutions" list in the "Customize" window should now list a new mode: "[X] 1920 x 1080 at 50 Hz (32-bit), progressive"
- click "OK" to close the "Customize" window
- a new resolution "1920 x 1080" should now pop up in the "Custom" section of the main resolution chooser now, with a 50 Hz refresh rate

To switch between 50 Hz and 60 Hz modes, nVidia Control Panel can be used, or of course [vidmode](src/vidmode).

### Oldschool

In addition to the main compo desk, there's the oldschool desk where all the C64s, Amigas, game consoles etc. live. To get the video signal of these converted to standard-compliant HDMI, a more or less complex chain of devices like [RetroTINK-5X](http://www.retrotink.com/) or [OSSC](http://junkerhq.net/xrgb/index.php?title=OSSC) and/or professional scalers like an [Extron DSC 301 HD](https://www.extron.com/product/dsc301hd) may be used. I won't go into more details here, as it would fill whole pages alone and I'm not very experienced with that stuff anyway. At Deadline, I had the pleasure to work with a very well-prepared oldschool compo team &ndash; whatever happened at their desk with all those devices, I only ever saw an HDMI cable with crystal-clear video and a pair of XLRs with nice audio coming out of it :)

### Video Jingles

A final source of video and audio is the lighting desk. As introductions to major events like compos, the lighting guy typically prepares a choreography of stage lights, synchronized to a video jingle that plays on the bigscreen. While it's theoretically possible to play the jingle from the compo PC and synchronize the jingle video and its light show manually by counting down to three and pushing the appropriate buttons at the same time, this isn't the recommended way of doing things. Instead, have the light controller PC play the jingle video and run an HDMI cable from there into the matrix. If the jingles are just audio, CompoKit's [Jingle Player](jingle) tool may be useful.

A nice touch is switching from the "Coming Up" to the "Now" slide in the background while the jingle runs.

-------------------------------------------------------------------------------

## The Compos

### Compo Preparation

In general, preparation for all compos works in the same way: Search for new entries in the PMS, download them, review them, prepare them to be shown in the compo, and mark them as "prepared" in the PMS. In theory, it's sufficient to do this once for all entries of a compo after its deadline has passed, but I highly recommend to prepare entries as early as possible, for two reasons: First, to reduce the workload in the time between deadline and compo, and second, to have more time to contact the authors in case of problems.

My recommendation is to create two subdirectories under the party directory: One for the raw release files, and one for the prepared entries. The first one is a direct image of what is going to be uploaded to scene.org later; the second one is the directory from which we will show the compos. Each of these directories get subdirectories for each compo (e.g. `oldschool_graphics`, `pc_demo`, `streaming_music`).

In most cases, the workflow for preparing a single entry is as follows:
- download the release file from the PMS
  - Make sure that the latest version is downloaded! PartyMeister, for example, archives _all_ entry uploads, but highlights the most recent one. A slip with the mouse in the wrong moment may cause an older version of an entry to be played, making its creators very unhappy.
- move the file into the compo's subdirectory of the scene.org mirror directory
- create a new subdirectory in the compo's subdirectory of the compo work directory and copy (*not* move!) or unpack the entry there
  - Yes, we create a directory even for single-file entries.
- read the readme files (**including the information the author wrote in the PMS submission**, really, don't forget that!) and make sense of the entry
- prepare the entry for execution, if necessary: rename files, create wrapper `.cmd` files, create emulator configuration files
  - see the sections below for details
- mark the main file to be run as default in CKLaunch (select it and press Space so a star appears right of the filename)
- test-run it! (from CKLaunch too &ndash; we don't want any nasty surprises later, just because we used a different method of running the entry during preparation!)
- watch the entry all the way to the end; sometimes there may be "fake endings" in demos, and we don't want to exit an entry prematurely during the compo
- for graphics and music compos where entries are delivered in executable format (notably oldschool and executable graphics/music compos), it's OK to use the author's screenshot or MP3/WAV file, if provided; however, it should nevertheless be checked that the executable is actually running and producing the same output

For example, this is a possible directory structure of a hypothetical party with a single entry in a single compo:

- `C:\MyParty\`
  - `CompoKit\`
    - `bin\`
    - etc.
  - `upload\` (the scene.org mirror directory)
    - `pc_4k_intro\` (compo directory)
      - `my_intro.zip` (entry file)
  - `compos\` (the compo preparation directory)
    - `pc_4k_intro\` (compo directory)
      - `my_intro\` (entry directory)
        - `my_intro_720p.exe`
        - `my_intro_1080p.exe`
        - `readme.txt`
        - `screenshot.jpg`

Since the work of preparing entries is done half in CKLaunch and half in a normal file manager, this is a good time to learn that pressing Ctrl+Enter in CKLaunch opens the currently selected file or directory in Explorer, and Shift+Enter opens it in Total Commander. In the other direction, simply dragging an item from a file manager into CKLaunch's window will navigate to that file or directory.

While preparing entries for PC demo and intro compos, it may be a good idea to have [Capturinha](https://github.com/kebby/Capturinha) running in the background. (It can be installed in CompoKit by running `setup.cmd capturinha`.) Select the "only record when fullscreen" option and start it; then minimize all windows except CKLaunch before running an entry (important!). When the entry is subsequently run, Capturinha generates a nice video capture in the background as soon as fullscreen mode is entered, and stops capturing when fullscreen mode is left again. This way, we end up with a directory full of high-quality captures of the demos we've shown &ndash; useful for post-party YouTube uploads! Just remember to stop Capturinha again, otherwise it will happily continue to capture *everything* that runs fullscreen &ndash; including video players and browser windows ...

If the party allows remote entries, the Inbox where these entries are sent to needs to be monitored as well, and entries need to be added into the PMS. Having a single organizer (*not* necessarily the compo organizer!) take care of this is **really** useful &ndash; we didn't have one at Deadline 2018, and it was a mess, but we did have one at later Deadlines, and everything "just worked".

If there are not enough entries in a compo, a decision has to be made about with which other compo it shall be merged. In many cases, it's a welcome gesture towards the compo participants to ask them what they would like best: Merge the 64k compo into 4k (producing a "combined intro" compo), or into "demo"? Or maybe move an entry from another, well-staffed compo into a starving one, if there's enough overlap with the target compo's topic?

After all entries of a compo have been prepared, the compo itself can be finalized. In particular, the playing order of the entries has to be determined (I call this process "choreographing" a compo) and set up in the PMS. Then visit the compo directory and rename the entry's subdirectories to `01`, `02` and so on. (See, *that's* why each entry got its own subdirectory!) Do this directly in CKLaunch (F2 key), because only then, the default file marks are preserved. If some entries of the compo are played from the oldschool desk, leave them out or create an empty directory for them.

Finally, mark the compo as prepared in the PMS, and generate slides for the compos.

### Compo Presentation

For any compo or event that requires showing screen contents from the compo PCs, make sure that all other windows are closed. In other words, during a compo, while no entry runs, only the background image and possibly the CompoKit Launcher should be visible. There can always be short flashes of the desktop before or after an entry runs fullscreen, and we don't want the audience to see the list of compo entries if it happened to be still open in a browser window!

Since at this point, all the entries are located in numbered subdirectories of the compo directory and have their main files marked, running the compo becomes nearly trivial with CKLaunch: Just navigate to the first entries' directory; the main file should be auto-selected when entering the directory, so just pressing Enter will run the entry. To navigate to the next entry, **don't** go through the parent directory &ndash; just press the right cursor key to switch directly into the next entry's directory! Again, the main file should be pre-selected, so it's only a matter of pressing Enter again to start it.

When using PartyMeister, make sure to start the compo playlist in "with callbacks" mode to enable live voting. When the compo is done, immediately mark the compo as open for voting. (Standard voting is handled differently from live voting, that's why we need to enable it explicitly. **Don't forget to do that.**)

The total process of running a compo is then as follows (assuming some example values for the video matrix controller assignments):
- (PartyMeister) start the compo playlist &rarr; the "Coming Up" slide is shown
- start the jingle
- (Matrix Controller) `8`, Enter &rarr; switch to jingle video output
- (Slides) Cursor Right &rarr; switch to "Now" slide
- wait until jingle is over
- (Matrix Controller) `3`, Enter &rarr; bring the to "Now" slide onto the bigscreen
- wait a few seconds; double-check that CKLaunch (and *only* CKLaunch) is open, and it's at the default file of the `01` entry directory
- (Slides) Cursor Right &rarr; switch to first entry's slide
- *\<loop begins here\>*
- slowly read the whole slide text
- (Compo PC) Enter &rarr; run the entry
- (Matrix Controller) `1`, Enter &rarr; bring the Compo PC to the bigscreen
- wait until the entry is over
- (Matrix Controller) `3`, Enter &rarr; switch the bigscreen back to the slide
- read the slide text *again*
- (Slides) Cursor Right &rarr; switch to the next entry's slide
- (Compo PC) Cursor Right &rarr; switch to the entry `02`'s directory
- loop again until arrived at the "End of Compo" slide
- (PartyMeister) enable voting for the compo

For a setup with a video mixer, instead of switching between inputs `1` and `3`, those are statically assigned to two inputs of the mixer and switching is done using the mixer's auto-fade button after that.

I've seen an entry kill CKLaunch once, for whatever reason. That's unfortunate, but not really a problem: CKLaunch saves its state every time before an item is run, so it can be restarted at any time. Ideally, place a shortcut to CKLaunch on the desktop, directly under the location where the CKLaunch program window is shown.

### Test Compos

Many parties have a demoshow as an event before the first compos. For people who think that this is just a nice service from the organizers to get the audience into the proper mood, I've got some bad news: The main reason for these demoshows is that they make a good "test compo" where the whole system &ndash; PMS, slides, compo PC, audio, video, bigscreen &ndash; can be verified. Well, that and ... OK, the organizers love to watch their favorite demos on the bigscreen too, I can't deny that :)

### Executable Compos

Standard PC executable compos are quite trivial: Find the proper `.exe` file (if there are multiple) and run it. Make a mental note as to which settings should be selected in the configuration dialog (if there is any), but in most cases, the defaults are fine anyway.

Browser demos (i.e. the variant that does *not* come with its own copy of Electron) are usually easy, too: CKLaunch is configured to run `.html` files fullscreen in Chrome (with `--allow-file-access-from-files`) by default, and this just works in most cases. <br>
If not, the best idea is to create a small `.bat`/`.cmd` file in the entry's directory that runs the preferred browser with the appropriate parameters. The `Chrome.cmd` and `Firefox.cmd` scripts in CompoKit's `bin` directory can be used as a template; just replace the `"%~f1"` parameter at the end by `"%~dp0\index.html"` (or whatever the main HTML file is called). <br>
For Firefox, some caveats apply: There's no "launch fullscreen" mode, and to make 90% of all demos work, the `security.fileuri.strict_origin_policy` option must be disabled in `about:config`. To do this, just run `bin/Firefox.cmd` once without parameters; it'll show the option in question straight away.

DOS demos that run with DOSBox can often be run with CKLaunch's standard `.com` file association and its default `dosbox.conf` file. If the demo comes in `.exe` format (which would be run through Windows when clicked, and thus fail), or if the author provided a custom `dosbox.conf` file, CKLaunch's `.dosbox` file association can be used: Create a copy of the `dosbox.conf` file (either the author's, or CompoKit's), name it e.g. `_run.dosbox`, and edit it. Two things need to be changed: First, fullscreen mode needs to be set with appropriate options, and second, the `[autoexec]` section needs to be set up so that the demo starts automatically. In summary, the following things should be in the `.dosbox` file, overriding what the entry's author may have specified:

    [sdl]
    fullscreen=true
    fullresolution=desktop
    output=ddraw

    [render]
    aspect=true

    [autoexec]
    mount C: .
    C:
    the_demo.exe

DOS demos that require significantly more computing power than DOSBox can offer need another way of presentation. Ideally, there's an oldschool PC setup with a late Pentium III or Athlon XP CPU, an ISA soundcard and a [Covox](https://www.serdashop.com/CVX4) plug at the oldschool desk. If this is not available and the entry doesn't have any peculiar requirements regarding sound (except PC speaker via PIT and SoundBlaster digitized audio via DMA), a VM will do too. Use [VirtualBox](https://www.virtualbox.org/) or [VMware Player](https://www.vmware.com/products/workstation-player.html); Windows' built-in Hyper-V may sound tempting, but its VGA emulation is *extremely* slow, to the point where even DOSBox is faster. For entries that fit onto a floppy, a full DOS installation on a virtual hard disk isn't needed; just use a [FreeDOS boot disk](https://github.com/codercowboy/freedosbootdisks/tree/master/bootdisks), copy the entry onto it using [mtools](http://reboot.pro/files/file/267-mtools/) (`mcopy -i MyDiskImage.img the_demo.exe ::/`) and boot from that.

### Video Compos

The MPC-HC player contained in CompoKit should have no issues playing the videos we're likely to encounter nowadays. Remember that in CompoKit's default configuration, playback doesn't start automatically: The video is paused at the first frame until the Space bar is pressed. This gives us plenty time to switch the video source and wait for the bigscreen projector to settle before starting the entry. Similarly, at the end of the video, the player doesn't simply quit, but pauses at the last frame. Quit it with the Q, Alt+X or just Alt+F4 keyboard shortcuts.

Some special planning is needed for video compos with regard to frame rate: While basically all other compos run at the default 1080p60 resolution, entries that are delivered as 25 fps or 50 fps videos need 1080p50, or they will judder unacceptably. It's a good idea to have the graphics driver's video mode selection window already open during such a compo, so that these mode switches can be performed swiftly between releases. Prepare a (hand-written) list of switch points before the compo, and don't forget to revert to 1080p60 again when it's over. To find out a video's frame rate, just play it in MPC-HC, press Esc (to quit fullscreen mode) and Shift+F10 to open the file's "Properties" dialog with detailed information (e.g. "Video: MPEG4 Video (H264) 1920x1080 **29.97fps**"). If the compo choreography allows, it's recommended to sort entries by frame rate to minimize the number of mid-compo mode switches.

### Graphics Compos

Entries that come as single files (such as photos) are simply put into their directory as-is. For entries with work stages, it's recommended to rename the main image so that it's lexicographically *after* all the work stage images, e.g. `zzzzz.png`. This way, showing the image and its work stages always works the same way: Start with the main image, press Home to get to the first image in the folder, then cycle though all images with Space or Page Down until the main image is reached again. Finally, exit the viewer with Esc.

Note that the image viewer in CompoKit, XnView, is *not* configured to zoom into images that are smaller than the screen. This is deliberate, because XnView lacks a "fill screen, integer zoom only" option, only "fill screen with interpolation", which is absolutely not what we want when viewing oldschool graphics. So, there's no other way but to press the + (plus) key an appropriate number of times when the entry comes up, or upscale the entry with Nearest Neighbor (non-)interpolation before the compo.

ANSI/ASCII compos require some special treatment. While we theoretically could show them as images (exporting them out of ACiDView if necessary), this would be quite lame. Instead, we use a proper ANSI/ASCII compo tool: Sahli. Unfortunately, it's quite hard to use, so it has its own manual: [Sahli-HOWTO.md](Sahli-HOWTO.md).

### Music Compos

CompoKit's default music player, XMPlay, is preconfigured for all sorts of streaming music (MP3, Ogg Vorbis, FLAC, `.m4a` AAC, even Opus) and the most common module file formats (MOD, XM, S3M, IT). For MOD, different settings are applied than for the other formats (mainly an Amiga-like filter and much less stereo separation). If a file needs super-specific options, make use of XMPlay's "saved settings" feature to store the specific configuration.

Like MPC-HC, XMPlay is configured to start in paused mode. Playback starts when pressing the P key. (The Space key, somewhat counter-intuitively, does *not* start playback, but it won't do any harm either.) For tracked music compos, double-click into the pattern visualization window to make it fullscreen, and move the mouse cursor out of the way before switching video inputs and starting playback.

During preparation, make notes which entries are too long and need to be faded out and at which point.

### Oldschool, Mixed and Interactive Compos

In a way, these are the most stressful compos, because they require a lot of mental and physical switching, and for interactive compos, there are a lot of additional people at the compo area.

As far as oldschool is concerned, most of the interesting stuff happens at the oldschool desk. Some communication is needed as to when the video input switch is to happen precisely, and the audio desk needs to be informed about when to switch to which input, or fade stuff in or out.

If the oldschool compo team has a means of digitally recording entries at pristine quality, and the resulting file format can be played back with a software player on the compo PC (ideally CompoKit's MPC-HC), oldschool compos degrade to specialized video compos with mostly 50 Hz content.

CompoKit also ships with some emulators for oldschool platforms, but as we all know, emulation is lame. Thus, the emulators should only be used if everything else fails.

-------------------------------------------------------------------------------

## Aftermath

After the last compo finished and the late-night DJ sets or concerts begin, the compo organizers are done with their job. Or are they?

### Upload to scene.org

Here's why we collected all the releases in a nicely laid-out directory structure during the party: Because this way, we can upload the stuff to the scene.org FTP's  `incoming` directory right there! Doing this at night is not only a good idea because of Internet bandwith reasons (with most visitors either dancing, socializing, or sleeping, and only few still sitting at their tables), but also because it saves all the hassle of having to boot up the compo PC again at the main organizer's home to salvage the data from there.

Before starting the actual upload though, double-check that all entries from the PMS are present in the upload directory too. Adding them later on may be hard to do, especially after the scene.org administrators moved the party data from `incoming` into `pub/parties` already. (And they can be very quick at that! Think hours, not days.)

### Voting Result Finalization

After the voting deadline, the results need to be reviewed. Are there any obvious signs of vote fraud? Are there any ties that need to be broken in order to guarantee a smooth prizegiving? (The PMS' prizegiving visualization might not deal well with ties within the top three entries of a compo, and depending on how long before the prizegiving the trophies are made, it might not be possible to hand out two "2nd place" trophies, for example.)

Depending on the PMS used, the order of the compo in the prizegiving may need to be specified explicitly. Now is a good time to do that!

After the compo results have been finalized, a hardcopy can be printed out so the presenters of the prizegiving have a way to read out the winners without having to stare at the bigscreen all the time. At the same time, the results can be [exported](src/pm-export-tools) in a raw format that an ASCII artist then turns into the final `results.txt` file. Depending on the type or artwork present in `results.txt`, one of three output encodings need to be chosen: If there's no or only minimal artwork, UTF-8 is fine; if the artwork is ASCII and looks best with the Amiga Topaz font, it should be exported as ISO-8859-1; and if the artwork uses DOS block graphics, the encoding to use is codepage 437 ("`cp437`"). If the output isn't UTF-8, some international characters may need to be replaced by the closest-looking equivalent in the target character set.

In addition to the `results.txt` file, there should also be an export in TSV (tab-separated value) format for Demozoo, with columns for rank, title, author and score, in that order, and in UTF-8 encoding. Whoever is going to enter the results into Demozoo, they will be very happy if they don't need to extract the data from a line-wrapped ASCII art opus and can instead just copy/paste everything from that TSV file.

Finally, rehearse the prizegiving at the compo desk before actually holding it. The prizegiving isn't a moment where we want to fuck anything up that could have been detected in advance.

### Prizegiving

The prizegiving slides themselves are usually automated, so apart from pressing the wrong buttons (like "next slide" instead of "start running the suspense bars", very common and mildly embarrassing) there's not much that can go wrong.

The more interesting aspect is that we may want to show or play the winning entry on the bigscreen briefly, so people don't need to remember it. To do so, prepare the prizegiving like a compo: Copy the directories of the winning entries and number the directories in the prizegiving order. We don't need full fidelity here: For example, don't fiddle with Sahli for ANSI/ASCII compo winners again, just show an image instead.

Playback of videos, demos and music entries can be started right when the winners are announced: They will take a minute to arrive at the stage and receive their trophies, and in the meantime, the intro of the entry will be over, just in time for a short switch over to the big screen. For the main demo or intro compos, where the winning entry is to be shown in full length, this doesn't apply &ndash; we will show them from start to end, of course, like in the compo the day before. Please coordinate and make notes beforehand which entries to show in full, to avoid any misunderstandings between the compo team and the presenter on stage.

After the prizegiving, there's only two things left to do: Put the `results.txt` file into the scene.org FTP's `incoming` directory and send the results TSV file to a Demozoo orga, and we can pull the plugs. (Literally, if needed.)
