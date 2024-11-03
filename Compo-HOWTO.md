# KeyJ's Compo Manual

This document describes one possible way how compos at a demoparty can be prepared and executed. I'm not going to say that it's the best way of doing things, but I think it's rather efficient and certainly worked quite well during the compos I hosted at the Deadline demoparty.

-------------------------------------------------------------------------------

## Setup

### Party Network and PMS

The main prerequisites are a working party network and a Party Management System like Assembly's [PMS](https://github.com/compocrew/PMS), Function's [Wuhu](http://wuhu.function.hu/), Evoke's [Granola](https://gitlab.com/granola-compo/granola) or Revision's [PartyMeister](http://www.partymeister.org/) *(warning: hopelessly outdated website!)*. I will focus on PartyMeister here, because that's what I know best (or rather, at all).

The party network should have a dedicated organizer network that's not accessible from the visitor tables or WiFi; we definitely don't want visitors to mess with our compo PCs! The PMS will of course run in a DMZ to which both visitors and organizers have access, or it may even run "in the cloud", i.e. in the public internet. The cloud configuration has benefits and drawbacks: The nice thing is that remote entries are much easier to manage this way &ndash; just give those who want to hand in a remote entry a PMS login, and they can do the rest themselves, with exactly the same interface as the other party visitors, and no additional rounds of "playing telephone". On the other hand, up- and downloads of entries will both tax the external internet connection (which may not be the fastest) and, of course, if the internet connection fails, we're just utterly f*cked. Out of my personal experience with multiple years of Deadline with and without a cloud-based PMS, I'd say that the benefits outweigh the drawbacks **if** (and only if) there's a very high confidence that the connection is going to be stable, e.g. because it uses bonding of multiple physical lines (DSLs, fiber, LTE/5G) and has a decent QoS setup that prioritizes the organizer network over the visitor network in case of congestion.

### Compo PCs and CompoKit

The most important machine is, of course, the compo PC, i.e. a powerful box with a fast CPU and a top-of-the-line GPU. On that PC, create a directory for all the data of the party. Put a CompoKit checkout into a subdirectory of that. It may make sense to download everything (i.e. run `setup.cmd` and `download_music.cmd`) before the party already, as the Internet connection may be too slow to do that in an acceptable amount of time at the party place.

Ideally, there are two compo PCs, with identical or slightly different hardware; one nVidia and one AMD GPU may be handy, for example. In this case, I tend to make one of them the "main" or "primary" compo PC, i.e. the one where most of the preparations are done and most of the compos are presented from. The other one is the "secondary" PC, which is used to play entries that don't work properly on the main compo PC or use different operating systems, play background music, run the typer (see below), or prepare compos while the main PC is used for other stuff.

The party directory should be shared between the PCs; the easiest way to do this is to share the directory on the main PC and mount it on the compo PC. Bonus points for making sure that the paths are identical on both PCs; this way, anything that stores absolute paths (like CKLaunch's state file) will work on both machines. Since the party directory is typically not the root of a drive, simply mapping a network drive doesn't suffice; instead, something like `mklink /d C:\MyParty \\Compo1\MyParty` is required. On the main PC, the network connection must be set to "Private Network" (otherwise file sharing isn't possible), and the logged-in user needs to have a &ndash; however trivial &ndash; password (otherwise Windows won't allow remote connections).
(Oh, and while we're at it: don't start CKLaunch on both PCs at the same time &ndash; the two instances will clobber each other's state file where the default file marks are stored!)

Two directories should be added to the anti-virus software's exception list: The compo directory and the web browser's download directory. We don't want any 64k or 4k intros taken into quarantine while preparing compos, just because anti-virus vendors think that every Crinkler-packed executable is evil.

It is highly recommended to create regular backups of the compo directories on an external SSD, e.g. using Total Commander's [directory synchronization](https://www.ghisler.com/advanced.htm#tutorial_synchronize) feature or Windows' [RoboCopy](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy) tool. In either case, make sure to set the tool to "asymmetric" or "mirror" mode so that updates are only propagated from the main copy to the backup and never in the opposite direction. I accidentally released an old file once because I wasn't paying attention to that, so be warned!

Another nice touch is a custom party wallpaper that also includes the machine name ("Compo 1" / "Compo 2").

### Slides PC

There needs to be a dedicated PC or notebook for displaying the PMS slides. Current Wuhu and PartyMeister versions only need a web browser for displaying the slides (not sure about the Assembly PMS), so it can be any platform, as long as the machine is moderately powerful. In fact, it can even run on the same box as the PMS itself.

The keyboard of the slides PC must be accessible at all times from the compo organizer's desk. It can be in the second row though, as we won't type any amount of text on it &ndash; basically we just need the cursor keys and the spacebar.

During 50-Hz-heavy compos (like oldschool executable compos), a nice touch would be if we can temporarily set the slides PC's output to 1080p50, so the main projector (often a DLP-based model) doesn't need to re-sync between the the slides' 60p and the entries' 50p framerate all the time. If the slide client software has something like that built-in, that's perfect; if it doesn't, CompoKit's [vidmode](src/vidmode) tool may prove useful.

We may want to include [Mercury's calibration slide](http://mercury.sexy/calibration02.png) in the main rotation, so people get a feeling of how badly the projector crushes blacks and whites. However, please note that the gamma calibration part of that slide is absolutely useless if the projector applies any kind of scaling or interpolation, e.g. because its native resolution is different from what the party picked as the default, or because it can't do optical keystone correction. In that case, better leave the slide out &ndash; don't confuse the hell out of people who want to calibrate their entries with a broken gamma chart! However, the reverse applies too: If the projector is able to produce an image with an acceptable amount of remaining geometric distortion using only optical corrections, don't use any digital keystone tricks to make the geometry perfect; we'd rather have a pixel-perfect image and tolerate some mild trapezoid distortion in return. A perfect rectangle filled with a mushy interpolated pixel mess isn't what we want.

### Typer

Depending on the PMS used, creating new slides can be more or less cumbersome. To inform the audience about things in a more "ad-hoc" manner, a way to type text-only slides "live" is really useful. A dedicated PC for that would be great, but using the "secondary" compo PC (if it exists) is usually fine as well.

Again, the keyboard should be accessible at all times (at least as long as the typer is in use), and in a way that allows comfortable typing, especially since we're using it more or less "blindly" (i.e. without a cursor).

### Audio

In terms of audio, we want to ensure two things: first, while preparing compos, we absolutely need a possibility to listen to the compo PC's output with headphones. Second, at the same time we must make sure that the headphone output is always active *in addition to* the main audio that goes to the mixing desk. Switching between the outputs is unacceptable because we **will** forget to switch to main audio before a compo at some point, inadvertently playing entries without sound.

There are various ways to fulfill these requirements: A carefully-chosen configuration of the on-board audio codec may work; the mixing console may have a dedicated headphone output for that; or use an external audio interface that has a built-in headphone amplifier, mapped to the same audio channels as the main Cinch / TRS / XLR output. The latter setup is the most comfortable, as we can have good access to the box's volume knob, at the expense of being subject to USB-related issues like flaky cables. If the box doesn't require any fancy drivers and just works with Windows' (and Linux's, for that matter) standard USB audio class drivers, that's a big plus.

Another point in favor of an external interface is that those often have a volume knob not only for the headphone output, but also for the main output. This allows the compo presenter to fade out entries that need it directly from their own desk, without the mixing desk's involvement. With great power comes great responsibility though: After fading out and closing the application that played the sound, always *immediately* reset the volume to its nominal value, otherwise the next entry will start without sound.

If using an external interface, disabling the on-board audio device in the BIOS setup or Device Manager might be a good idea to make sure that no program can use the wrong audio output by accident. But then again, I've never seen this becoming a problem, and even if on-board audio is neutered, the HDMI output's audio devices would still be present (and can't be deactivated easily), so this might be overkill after all. Just make sure that the interface is selected as the system's primary output, and we're set.

### Control Monitors

There should be at least three control monitors available at the compo desk. Most of the time, they will show the video from their dedicated "default" source (usually Compo PC 1; Compo PC 2 or Typer; Slides), but at least two of them should be connected to the video matrix to be able to preview other sources.

### Video &ndash; The DVI/HDMI Matrix

The centerpiece of the video chain is the video matrix or "crossbar switch", i.e. a device that can assign any of _n_ DVI/HDMI inputs to any of _m_ DVI/HDMI outputs. It's rather important that this is a "dumb" switch, and not something that contains a scaler or similar, because these devices may have stupid ideas like force-converting 50 Hz content (i.e. anything oldschool) to 60 Hz, causing unacceptable jerky motion.

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

So, an 8x8 matrix is generally sufficient (at least for a smaller party; Revision or Assembly may have a different view on this). The vendor and model *should* not matter, but we had some very unpleasant surprises with a LightWare MX8x8DVI-HDCP-Pro at Deadline 2018; since 2019, we have been using Extron DXP 88s (HDMI or DVI, doesn't matter), and those worked without a hitch.

Operating the matrix directly from the front panel is workable, but cumbersome. During compos, we frequently end up assigning one input to three outputs (both bigscreens and the stream) at the same time, requiring five careful keystrokes each time. Fortunately, there are better ways: All decent video matrices can be controlled via a serial interface, Ethernet, or both. An external gadget like a cheap single-board computer (SBC) connected to the matrix and an appropriate input device can facilitate things a lot. In case of an Ethernet connection, it makes sense to assign the video matrix a static IP address, either on the device itself, or via the DHCP server; for a serial connection, typically a USB-to-serial converter is used.

CompoKit itself ships with one such advanced video matrix control option: the [dvi_matrix_control](src/dvi_matrix_control) Python script. It runs on any Linux SBC (a first-generation Raspberry Pi is totally fine), connects via Ethernet, and uses a simple USB numerical keypad as the input method. It can be used to control the matrix as usual, e.g. by typing `4`, `2`, `Enter` to assign input 4 to output 2, but it can also store and use macros: for example, the process of sending input 1 to outputs 5, 7 and 8, and input 8 to output 6 (which is an actually useful real-world example, by the way) can be automated by storing the macro once with `*1*1578,86` and from there on, it's just `1`, `Enter`.

An even more refined method is using [ctrlpad](https://github.com/kajott/ctrlpad), which is not part of CompoKit, but adjacent to it. This runs on a slightly more powerful SBC (a Raspberry Pi 4 is fine, and probably even a 3B+ will do) with a graphical touchscreen and provides a customizable button-oriented interface, similar to an Elgato Stream Deck. It's admittedly harder to set up, but significantly easier to use &ndash; basic video matrix control usually needs no user introduction whatsoever, as the input/output buttons can be individually labelled. In addition to that, it can also control MPD, the Music Player Daemon, to play background music.

### Advanced Video &ndash; The Video Mixer

Thanks to the prevalence of YouTube streamers, the industry produced a lot of relatively inexpensive video mixers in recent years. While we can't solely rely on such a device because it doesn't have nearly enough outputs as we'd need, and because there things kinda _have to_ force-convert everything (including oldschool 50 Hz content) to a fixed output framerate of 60 Hz, it still is a useful addition to the video chain for two reasons: First, we can have smooth crossfades between the slides and the compo PC at the beginning and end of each entry; and second, while we generally want to preserve 50 Hz content for the main screen, the streaming team really prefers having a steady 60 Hz input.

Keep in mind, though, that having a video mixer doesn't make things easier; quite the contrary! It's one more device to work with during compos, and cabling too becomes more involved:

- There should be at least two, better three matrix outputs going straight into the mixer. One of those is (almost) permanently assigned to the slides PC, one is assigned to the main compo PC most of the time, and the third one would be for a secondary source of compo material, e.g. the oldschool desk.

- The jingle and VJ inputs can usually go straight into the mixer.

- The main program output of the mixer (which *must* be HDMI, not just a USB webcam output!) goes back into the matrix, in order to be distributed to the bigscreens and stream desk from there.

- If the mixer has a multi-view HDMI output (e.g. Blackmagic ATEM Mini Extreme), it makes a lot of sense to have a dedicated monitor for that. In fact, _not_ having a multi-view preview (like all "smaller" ATEM Mini models) is very dangerous, as we can't see what's currently routed into the mixer's inputs, and we'll only notice that the wrong input has been assigned in the matrix after fading over to it.

The entire video setup at recent Deadlines (2022 to 2024, with only small changes inbetween) looks like this:

[![Deadline 2024 Video Setup](https://keyj.emphy.de/photos/deadline2024/dl24_videosetup.png)](https://drive.google.com/file/d/15pS_tZ9DpqH8v3E0swW98QkgoOnsg0sr/view)

_(Note that inputs 1 and 2 of the ATEM are not used. That's deliberate: These inputs have severe issues with 50/60 Hz switches and are best avoided.)_

With those connections in place, most of the compos are really easy to do: Just press one button to fade from the slides to the compo PC and vice-versa. Things get a bit more complicated when another compo PC is involved, as the correct input on the video mixer needs to be selected at appropriate times, but it's still manageable. It's only when 50 Hz content is involved that things get really nasty &ndash; because remember, we want to have the verbatim 50 Hz signal on the bigscreen, but still have it go through the mixer's 60 Hz conversion for the stream!

Some kind of "protocol" is needed for doing these switches. After using quite elaborate schemes for a few years, I settled on something simple but effective at Deadline 2024. It works under two assumptions: First, the slides are always mapped to a fixed input on the video mixer, and second, 50/60 Hz switching only ever happens when going from a slide to showing an entry or vice-versa. With these two basic tenets in mind, switching becomes relatively straightforward:

To go into 50 Hz mode, assign the desired 50 Hz source (e.g. the oldschool desk) to the big screens _and_ the video mixer input that normally shows the slides, but _not_ the stream output. This replaces the slides signal with the 50 Hz source at the video mixer's input, but since the video mixer hasn't been touched, it will still forward this one to the stream output, converting it to 60 Hz in the process. Meanwhile, the main screens get the unmodified 50 Hz feed from the source.

From that point on, the most important thing to keep it mind is: _don't touch the video mixer_ while still in 50 Hz mode. The mixer will continue converting what it thinks is the slides to 60 Hz, but in reality, we're going to switch inputs using the video _matrix_ &ndash; just send them to the screens and the video mixer's slides input, same as when initially entering 50 Hz mode. This way, we're not getting the video mixer's nice crossfades, but that's way better than having to tolerate jerky scrollers in oldschool demos.

While in 50 Hz mode, it can be a nice touch to temporarily switch the slides PC to 50 Hz as well, so the (usually DLP-based) projectors don't have to re-sync the frame rate when toggling between the 60 Hz slides and the 50 Hz compo material. Just son't forget to set it back to 60 Hz while the last entry plays!

At the end of the last 50 Hz entry, we go back into 60 Hz mode by sending the slides to their usual input on the mixer again, but routing the video mixer's output to the big screens this time. From that point on, normal crossfading using the video mixer is available again.

As can be seen, I really meant it when I said that a video matrix doesn't make life easier! But the creative possibilites are undeniably cool &ndash; since crossfades can also be stopped halfway, we can essentially overlay one source upon another, which is a nice touch in a few scenarios:
- Announcements from the Typer can be displayed over any other content.
- While the VJ plays, we can permanently show the music act's name via Typer or slides.
- Music entries that have some kind of visualization (e.g. rasterbars in the oldschool music compo, or pattern display in tracked music) can be overlaid on the entry's slide.

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

### Linux and DOS

To run Linux-only entries on one of the compo PCs (usually the secondary compo PC, as the primary is the one with the full CompoKit installation and files on it), it needs to be installed there first. If there's enough time before the party to set up the compo PC from a "clean slate" (i.e. empty SSD) state, it makes a lot of sense to just install a dual-boot Windows/Linux system; however, more often than not, the compo PCs are rented from some other demoscene organization and arrive shortly before the party, so we'll neither have the time nor the courage to mess with the OS installation(s) in a major way. That's why it's very recommended to prepare a USB thumb stick with a Linux installation beforehand; this way, we can just plug the stick in, boot from that, run the entry, and reboot back into Windows.

As for the Linux distribution that's going to be installed on the stick, that's a [contentious topic](https://www.pouet.net/topic.php?which=12295). My personal stance is to just use the latest version of the most commonly and widely used distribution, which, at the time of this writing, clearly is [Ubuntu](https://ubuntu.com/download/desktop). But it's also absolutely fine to use another common distro like [Fedora](https://getfedora.org/en/workstation/); just don't use anything that's even remotely exotic. Whatever you choose, **announce it** on the party's website in due time, so people can test their entries beforehand.

Having settled the distribution question, please note that a simple "live" stick isn't going to cut it. We're going to need a full installation of the OS on the stick, if only to install the proprietary nVidia drivers in the (very probable) case that the target compo PC has an nVidia GPU in it. That ultimately means that we need *two* sticks: One with the installation medium, and one to install the system onto. (But keep in mind that this is really only needed for *preparing* the Linux boot stick, which can be easily done a week before the party on any somewhat modern PC; we're not going to do this kind of juggling during the party!) During the stick-to-stick installation process, it's *extremely* advisable to temporarily disable the computer's built-in SATA or NVMe devices in the firmware setup or using appropriate kernel parameters (`module_blacklist=nvme,ahci`), and unplug every other external drive too &ndash; the Ubuntu installer, in particular, tends to install the bootloader on the internal drives if it can, thus rendering both the newly-created Linux stick *and* the host system unbootable. (Ask me how I know...) After the base installation, boot from the stick and install updates, drivers etc. as needed. Don't change too much though, as we want to have a mostly "vanilla" installation.

Similarily, a boot stick with FreeDOS may come in handy if a 256-byte intro compo entry requires lots of CPU power, but doesn't need sound. Creating the stick is really straightforward with [Rufus](https://rufus.ie/en/), which has an option to do exactly that. Just copy the `.com` file on the stick as well and that's it, as far as preparation goes. The harder part is actually booting from that stick, and chances to do so successfully are getting slimmer by the year. The compo PC's UEFI firmware needs to have a CSM ("Compatibility Support Module") that emulates the old BIOS which, in turn, is required by DOS to boot. Recent PCs typically have the CSM disabled by default, so it needs to be activated in the PC's firmware setup, usually along with disabling Secure Boot (because the firmware refuses to enable the CSM while Secure Boot is enabled). Very new PCs may even be lacking the CSM altogether; those can't boot DOS at all, and there's nothing we can do about that.

Entries for other alternative "newschool" platforms (macOS, modern consoles, what have you) are rare enough that it's usually not worth the hassle of providing a pre-configured system. Just have the creators of the entry plug in a compatible machine (ideally not their own, to avoid cheating) via HDMI and probably some USB audio interface and play the entry from there.

### Oldschool

There are two fundamental ways to handle demo compos on oldschool hardware from the 80s to early 2000s like C64, Amiga or game consoles. On larger parties, these compos are usually pre-recorded, i.e. all the oldschool devices are set up in a separate room and each entry is captured as a video file that's then transferred to the Compo PCs in some way (Ethernet or "sneakernet", whatever works). During the compo, these video files are then played back as usual. At Deadline, however, we take pride in showing everything "live", which means that the oldschool desk is right next to the main compo desk and we get a dedicated HDMI cable with video and pair of XLRs with audio from there.

In both cases, the analog video signals from the source devices need to be converted into HDMI somehow, and this is where the dark magic comes in. There have been countless options to perform this step, but in recent years, three options emerged as the recommended go-to solutions: The [RetroTINK-4K](https://www.retrotink.com/product-page/retrotink-4k) and its predecessor [RetroTINK-5X](https://www.retrotink.com/product-page/5x-pro) are excellent one-size-fits all scalers, but kinda expensive; [OSSC](https://videogameperfection.com/products/open-source-scan-converter/) is cheaper and also quite capable, but lacks composite and Y/C input, which makes it unusable with devices that don't output RGB; and finally, [RGB2HDMI](https://github.com/hoglet67/RGBtoHDMI/wiki) is the cheapest option of all, but platform-specific and with neither composite and Y/C input nor HDMI audio output. All of those can deliver excellent video quality if configured properly, and all of those have an option that needs thorough consideration: **Frame Locking**.

This warrants some explanation: While the HDMI standard timing for 1080p50 (CEA-861 mode 31) delivers _exactly_ 50.0 frames per second, oldschool hardware generally doesn't: PAL C64s run at 50.124573... frames per second, Amigas in non-interlaced mode usually do 49.92 frames per second etc. Most scalers for oldschool hardware have two ways to deal with this disparity. The more compatible option is usually called "Triple Buffering"; it runs the HDMI output at the standard frame rate and drops or duplicates frames once in a while to compensate &ndash; in the case of the C64, this happens every ~8 seconds, for example. This is not ideal, so there's the aforementioned "Frame Locking" or "Genlock" option as an alternative. In this mode, the scaler slightly adjusts the video timing to produce output the exact same frame rate as the input, resulting in a perfectly smooth and glitch-free ouput. The caveat: This produces a non-standard video timing, and the further processing steps down the chain (video mixer, video matrix, projector, capture devices etc.) might not like it. Thus, it's imperative to check compatibility before using the Frame Locking option; but if it works, it's absolutely worth it!

An alternative to using a true oldschool machine plus a separate scaler might be to use FPGA-based replicas like the [MiSTer](https://github.com/MiSTer-devel/Wiki_MiSTer/wiki), the [Ultimate64](https://ultimate64.com), the [ZX Spectrum Next](https://www.specnext.com) or anything from [Analogue](https://www.analogue.co/products). Those have native HDMI interfaces, obsoleting any fiddling with scalers and generating pixel-perfect output by design (and in some cases with the same video timing issues as the originals). They are, however, partly or fully based on _emulation_ and should thus be avoided. They might be fine for graphics compos or music compos (except for the C64, where you absolutely want to use real hardware SIDs!) or maybe the occasional tiny intro or joke prod, but running proper demos on them is doing the creators and the scene a disservice.

If a device does produce HDMI output that looks fine on a display, but it's not accepted by the video chain no matter what you adjust, there's another device that's good to have in your toolbox: the [Extron DSC 301 HD](https://www.extron.com/product/dsc301hd) scales even the dirtiest HDMI signals to standards-compliant 1080p. This nullifies any attempts to use Frame Locking, as the DSC 301 HD enforces Triple Buffering internally and does so with considerably more latency than any of the aforementioned scalers do, but if that's required to get a working signal, so be it!

If the party is going to show oldschool compos in realtime, a separate audio output is required in addition to video. If the oldschool video chain is based on HDMI as outlined so far, the easiest way to handle this is to have the initial HDMI-producing source embed the audio into the data stream and extract it at the very end of the internal processing chain on the oldschool desk. This has the added benefit that even if the scalers introduce latency, this doesn't affect A/V sync, as they normally delay audio as well. Suitable HDMI audio extractors can be had for ~20€ nowadays. Since it may also be convenient to have a small N-to-1 video switcher on the oldschool desk as well, it makes a lot of sense to get a HDMI switch with a built-in audio extractor, killing two birds with one stone for little extra money (the cheapest option at the time of writing was 25€). Alternatively, just get a small audio mixer to do the job in a purely analog way; be aware of the A/V sync issues and probable user error (switching video, but not audio or vice-versa) in this case. <br>
But even if the HDMI option is used, it's highly recommended to get a simple audio mixer like the [Behringer Xenyx 802S](https://www.behringer.com/product.html?modelCode=0601-AHU) or [1204USB](https://www.behringer.com/product.html?modelCode=0601-ACM), for two reasons: First, it's good to be able to momentarily fade out the audio while switching input devices to avoid plopping sounds due to DC bias differences; and second, a mixer with pairs of line-level inputs with panning knobs (as opposed to a stereo pair with balance knob) is useful to reduce stereo separation for platforms that require it: Just turn the panning knobs towards the center to turn an Amiga's hard-panned stereo signal continuously to mono, and set them to 100% L / 100% R again to allow full stereo to pass through.

### Video Jingles

A final source of video and audio is the lighting desk. As introductions to major events like compos, the lighting guy typically prepares a choreography of stage lights, synchronized to a video jingle that plays on the bigscreen. While it's theoretically possible to play the jingle from the compo PC and synchronize the jingle video and its light show manually by counting down to three and pushing the appropriate buttons at the same time, this isn't the recommended way of doing things. Instead, have the light controller PC play the jingle video and run an HDMI cable from there into the matrix. If the jingles are just audio, CompoKit's [Jingle Player](jingle) tool may be useful.

A nice touch is switching from the "Coming Up" to the "Now" slide in the background while the jingle runs.

-------------------------------------------------------------------------------

## The Compos

### Compo Preparation

In general, preparation for all compos works in the same way: Search for new entries in the PMS, download them, review them, prepare them to be shown in the compo, and mark them as "prepared" in the PMS. In theory, it's sufficient to do this once for all entries of a compo after its deadline has passed, but I highly recommend to prepare entries as early as possible, for two reasons: First, to reduce the workload in the time between deadline and compo, and second, to have more time to contact the authors in case of problems.

My recommendation is to create two subdirectories under the party directory: One for the raw release files, and one for the prepared entries. The first one is a direct image of what is going to be uploaded to scene.org later; the second one is the directory from which we will show the compos. Each of these directories get subdirectories for each compo (e.g. `oldschool_graphics`, `pc_demo`, `streaming_music`). CompoKit's [PartyMeister release downloader script](src/pm-export-tools/) can be used to automate the process of maintaining the scene.org mirror directory structure.

In most cases, the workflow for preparing a single entry is as follows:
- Download the release file from the PMS.
  - Make sure that the latest version is downloaded! PartyMeister, for example, archives _all_ entry uploads, but highlights the most recent one. A slip with the mouse in the wrong moment may cause an older version of an entry to be played, making its creators very unhappy.
- Move the file into the compo's subdirectory of the scene.org mirror directory.
  - CompoKit's downloader takes care of this point and the one before.
- Create a new subdirectory in the compo's subdirectory of the compo work directory and copy (*not* move!) or unpack the entry there.
  - Yes, we create a directory even for single-file entries.
- Read the readme files (**including the information the author wrote in the PMS submission**, really, don't forget that!) and make sense of the entry.
- Prepare the entry for execution, if necessary: rename files, create wrapper `.cmd` files, create emulator configuration files.
  - see the sections below for details
- Mark the main file to be run as default in CKLaunch (select it and press Space so a star appears right of the filename).
- Test-run it! (from CKLaunch too &ndash; we don't want any nasty surprises later, just because we used a different method of running the entry during preparation!)
- Watch the entry all the way to the end.
  - Sometimes there may be "fake endings" in demos, or 256-byte intros seem to run forever even though they do, in fact, have an end or some kind of variation after a while. We don't want to exit an entry prematurely during the compo! So make notes (written, if possible) about when to stop an entry if it's not obvious.
- For graphics and music compos where entries are delivered in executable format (notably oldschool and executable graphics/music compos), it's OK to use the author's screenshot or MP3/WAV file, if provided; however, it should nevertheless be checked that the executable is actually running and producing the same output.

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

Since the work of preparing entries is done half in CKLaunch and half in a normal file manager, this is a good time to learn that pressing `Ctrl+Enter` in CKLaunch opens the currently selected file or directory in Explorer, and `Shift+Enter` opens it in Total Commander. In the other direction, simply dragging an item from a file manager into CKLaunch's window will navigate to that file or directory.

While preparing entries for PC demo and intro compos, it may be a good idea to have [Capturinha](https://github.com/kebby/Capturinha) running in the background. Select the "only record when fullscreen" option and start it; then minimize all windows except CKLaunch before running an entry (important!). When the entry is subsequently run, Capturinha generates a nice video capture in the background as soon as fullscreen mode is entered, and stops capturing when fullscreen mode is left again. This way, we end up with a directory full of high-quality captures of the demos we've shown &ndash; useful for post-party YouTube uploads! Just remember to stop Capturinha again, otherwise it will happily continue to capture *everything* that runs fullscreen &ndash; including video players and browser windows ...

If the party allows remote entries, the Inbox where these entries are sent to needs to be monitored as well, and entries need to be added into the PMS, or, if a cloud-based PMS is used, new applicants for remote entries need to be given login credentials. Having a dedicated organizer (*not* necessarily the compo organizer!) take care of this is **really** useful &ndash; we didn't have one at Deadline 2018, and it was a mess, but we did have one at later Deadlines, and everything "just worked".

If there are not enough entries in a compo, a decision has to be made about with which other compo it shall be merged. In many cases, it's a welcome gesture towards the compo participants to ask them what they would like best: Merge the 64k compo into 4k (producing a "combined intro" compo), or into "demo"? Or maybe move an entry from another, well-staffed compo into a starving one, if there's enough overlap with the target compo's topic?

After all entries of a compo have been prepared, the compo itself can be finalized. In particular, the playing order of the entries has to be determined (I call this process "choreographing" a compo) and set up in the PMS. Then visit the compo directory and prefix the entries' subdirectory names with `01_`, `02_` and so on. (See, *that's* why each entry got its own subdirectory!) Do this directly in CKLaunch (`F2` key), because only then, the default file marks are preserved. If some entries of the compo are played from the oldschool desk, leave them out or create an empty directory for them.

Finally, mark the compo as prepared in the PMS, and generate slides for the compos.

### Compo Presentation

For any compo or event that requires showing screen contents from the compo PCs, make sure that all other windows are closed. In other words, during a compo, while no entry runs, only the background image and possibly the CompoKit Launcher should be visible. There can always be short flashes of the desktop before or after an entry runs fullscreen, and we don't want the audience to see the list of compo entries if it happened to be still open in a browser window!

Since at this point, all the entries are located in numbered subdirectories of the compo directory and have their main files marked, running the compo becomes nearly trivial with CKLaunch: Just navigate to the first entries' directory; the main file should be auto-selected when entering the directory, so just pressing `Enter` will run the entry. To navigate to the next entry, **don't** go through the parent directory &ndash; just press the `Right` cursor key to switch directly into the next entry's directory! Again, the main file should be pre-selected, so it's only a matter of pressing `Enter` again to start it.

When using PartyMeister, make sure to start the compo playlist in "with callbacks" mode to enable live voting. When the compo is done, immediately mark the compo as open for voting. (Standard voting is handled differently from live voting, that's why we need to enable it explicitly. **Don't forget to do that.**)

The total process of running a compo is then as follows (assuming some example values for the video matrix controller assignments, and absence of a video mixer):
- (PartyMeister) start the compo playlist &rarr; the "Coming Up" slide is shown
- start the jingle
- (Matrix Controller) `8`, `Enter` &rarr; switch to jingle video output
- (Slides) Cursor `Right` &rarr; switch to "Now" slide
- wait until jingle is over
- (Matrix Controller) `3`, `Enter` &rarr; bring the to "Now" slide onto the bigscreen
- wait a few seconds; double-check that CKLaunch (and *only* CKLaunch) is open, and it's at the default file of the `01` entry directory
- (Slides) Cursor `Right` &rarr; switch to first entry's slide
- *\<loop begins here\>*
- slowly read the whole slide text in your head (to give the audience sufficient time to do the same before the entry starts)
- (Compo PC) `Enter` &rarr; run the entry
- (Matrix Controller) `1`, `Enter` &rarr; bring the Compo PC to the bigscreen
- wait until the entry is over
- (Matrix Controller) `3`, `Enter` &rarr; switch the bigscreen back to the slide
- read the slide text *again*
- (Slides) Cursor `Right` &rarr; switch to the next entry's slide
- (Compo PC) Cursor `Right` &rarr; switch to the entry `02`'s directory
  - I usually make these two keypresses at the exact same time with both hands.
- loop again until arrived at the "End of Compo" slide
- (PartyMeister) enable voting for the compo

For a setup with a video mixer, instead of switching between inputs `1` and `3`, those are statically assigned to two inputs of the mixer at the very beginning, and switching is then done using the mixer's auto-fade button.

I've seen an entry kill CKLaunch once, for whatever reason. That's unfortunate, but not really a problem: CKLaunch saves its state every time before an item is run, so it can be restarted at any time. Ideally, place a shortcut to CKLaunch on the desktop, directly under the location where the CKLaunch program window normally resides.

### Test Compos

Many parties have a demoshow as an event before the first compos. For people who think that this is just a nice service from the organizers to get the audience into the proper mood, I've got some disappointing news: The main reason for these demoshows is that they make a good "test compo" where the whole system &ndash; PMS, slides, compo PC, audio, video, bigscreen &ndash; can be verified. Well, that and ... OK, the organizers love to watch their favorite demos on the bigscreen too, I can't deny that :)

### Executable Compos

Standard PC executable compos are quite trivial: Find the proper `.exe` file (if there are multiple) and run it. Make a mental note as to which settings should be selected in the configuration dialog (if there is any), but in most cases, the defaults are fine anyway.

Browser demos (i.e. the variant that does *not* come with its own copy of Electron or has a WebView2 `.exe` wrapper) are usually easy, too: CKLaunch is configured to run `.html` files fullscreen in Chrome (with `--allow-file-access-from-files`) by default, and this just works in most cases. <br>
If not, the best idea is to create a small `.bat`/`.cmd` file in the entry's directory that runs the preferred browser with the appropriate parameters. The `Chrome.cmd` and `Firefox.cmd` scripts in CompoKit's `bin` directory can be used as a template; just replace the `"%~f1"` parameter at the end by `"%~dp0\index.html"` (or whatever the main HTML file is called). <br>
For Firefox, some caveats apply: There's no "launch fullscreen" mode, and to make 90% of all demos work, the `security.fileuri.strict_origin_policy` option must be disabled in `about:config`. To do this, just run `bin/Firefox.cmd` once without parameters; it'll show the option in question straight away.

DOS demos that run with DOSBox can often be run with CKLaunch's standard `.com` file association and its default `dosbox.conf` file. If the demo comes in `.exe` format (which would be run through Windows when clicked, and thus fail), or if the author provided a custom `dosbox.conf` file, CKLaunch's default `.dosbox` or `.dosbox-staging` file associations can be used: Create a copy of the `dosbox.conf` file (either the author's, or CompoKit's), name it e.g. `_run.dosbox`, and edit it. Two things need to be changed: First, fullscreen mode needs to be set with appropriate options, and second, the `[autoexec]` section needs to be set up so that the demo starts automatically. In summary, the following things should be in the `.dosbox` file for DOSBox 0.74, overriding what the entry's author may have specified:

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

### Video Compos

The MPC-HC player contained in CompoKit should have no issues playing the videos we're likely to encounter nowadays. Remember that in CompoKit's default configuration, playback doesn't start automatically: The video is paused at the first frame until the Space bar is pressed. This gives us plenty time to switch the video source and wait for the bigscreen projector to settle before starting the entry. Similarly, at the end of the video, the player doesn't simply quit, but pauses at the last frame. Quit it with the `Q`, `Alt+X` or just `Alt+F4` keyboard shortcuts.

Some special planning is needed for video compos with regard to frame rate: While basically all other compos run at the default 1080p60 resolution, entries that are delivered as 25 fps or 50 fps videos need 1080p50, or they will judder unacceptably. It's a good idea to have [vidmode](src/vidmode) running, or at least have the graphics driver's video mode selection window already open during such a compo, so that these mode switches can be performed swiftly between releases. Prepare a (written) list of switch points before the compo, and don't forget to revert to 1080p60 again when it's over. To find out a video's frame rate, just play it in MPC-HC, press `Esc` (to quit fullscreen mode) and `Shift+F10` to open the file's "Properties" dialog with detailed information (e.g. "Video: MPEG4 Video (H264) 1920x1080 <u>29.97fps</u>"). If the compo choreography allows, it's recommended to sort entries by frame rate to minimize the number of mid-compo mode switches.

### Graphics Compos

Entries that come as single files (such as photos) are simply put into their directory as-is. For entries with work stages, it's recommended to copy and/or rename the main image so that it's lexicographically *first*, followed by all the work stage images, and another copy at the end, e.g. `zzzzz.png`. This way, showing the image and its work stages always works the same way: Start with the main image, then cycle though all images with `Page Down` until the main image is reached again. Finally, exit the viewer with `Alt+F4`.

Note that the image viewer in CompoKit, XnView, is *not* configured to zoom into images that are smaller than the screen. This is deliberate, because XnView lacks a "fill screen, integer zoom only" option, only "fill screen with interpolation", which is absolutely not what we want when viewing oldschool graphics. For these competitions in particular, CompoKit ships with another viewer that has been custom-made for this purpose: [PixelView](https://github.com/kajott/PixelView). It can be started by pressing `Alt+Enter` on an image file in CKLaunch's default configuration; it defaults to showing images in a "fit to screen" scaling mode, but with antialiased blocky filtering, which is ideal for pixel graphics. It also has an integer scaling mode, giving even better results if the image height is almost, but not quite, a multiple of 1080 pixels. (Press `I` to enable that.) When done, press `Ctrl+S` to save the current view settings. This produces a small `.pxv` file next to the original image; when selecting this as the directory's default file in CKlaunch (using the `Space` key), PixelView will effectively be selected as the viewer for this entry.

### ANSI/ASCII ("Textmode Graphics") Compos

ANSI/ASCII compos require some special treatment, but handling them has become substantially easier now that [PixelView](https://github.com/kajott/PixelView) has direct support for them &ndash; in general, showing an `.ans` file means just throwing it at PixelView (which is also CKLauch's default association for this file type) and maybe adjusting a few options if the author didn't bother to provide a good [SAUCE record](https://www.acid.org/info/sauce/sauce.htm) in the file. To do so, press the `Tab` or `F2` keys in PixelView to show the configuration UI. Also note that PixelView currently only supports ANSIs with up to 2048 lines on nVidia GPUs or 1024 on AMD/Intel; while longer entries are quite rare, it's still very much recommended to mention that limit in the compo rules before the party.

However, that's just the technical part; the other half of the equation is coming up with a strategy to present these works adequately, and this requires a bit of consideration.

Simple one-screener ANSI/ASCII entries work like normal graphics entries &ndash; open them in PixelView, decide on a suitable viewing mode, press `Ctrl+S` to produce a `.pxv` file, and that's it. <br>
For taller ANSIs, PixelView offers a few specific tools that may come in handy. Scrolling across them is usually a good idea:
- Press `T` to quickly scroll to the top with 1:1 zoom. Maybe even press `T` twice to have the entry fill the entire width of the screen, and if that is too wide, enable integer scaling (`I` key) before to constrain the size a bit.
- Press `S` to have PixelView scroll smoothly across the entry. 
  - The scroll speed should be chosen such that the content of the entry can be followed, but it shouldn't be boring either. If there's text to read, choose a lower speed; if there's just large graphics, faster scrolling is appropriate.
- After reaching the bottom, various strategies are possible:
  - Just zoom out to reveal the entire entry (`F` key).
  - Scroll back to the top by just pressing `S` again. (This is good for entries which are just 2-3 screens tall.)
  - Combine both: zoom out a bit (`Numpad-`) or to 1:1 pixel view (`Z`) to make the display a bit smaller, and press `S` (or `1`...`9`) again to scroll back to the top of the entry at a quicker speed.
- If it's a _very_ tall entry, giving the audience another overwiew in PixelView's "panel mode" (`P` key) might be a good idea.

The important part is to make written notes of the keyboard commands you're going to use when presenting the entry. The recipes will vary a bit for each entry, so writing them down really is key here.

PETSCII and ATASCII entries are typically just shown as images with an appropriate zoom factor in PixelView. The source images _can_ be the ones the author provided (after briefly checking that they match the submitted `.prg` or `.xex` file, of course), or emulator captures. In case of PETSCII, VICE (which ships with CompoKit) has an option to save a snapshot directly as PNG using the `Alt+C` keyboard shortcut.

### Music Compos

CompoKit's default music player, XMPlay, is preconfigured for all sorts of streaming music (MP3, Ogg Vorbis, FLAC, `.m4a` AAC, even Opus). For tracked music formats (MOD, XM, S3M, IT), the compo-oriented player [TrackMeister](https://github.com/kajott/TrackMeister) is included in CompoKit.

Like MPC-HC, XMPlay and TrackMeister are configured to start in paused mode within CompoKit. Playback starts when pressing the `P` key in XMPlay or the `Space` key in TrackMeister. (In XMPlay, the `Space` key, somewhat counter-intuitively, does *not* start playback, but it won't do any harm either.)

For Executable Music, render the track into a `.wav` file and just play that in the compo, skipping the pre-calculation process. Of course, check if the rendered result matches the real-time playback while preparing the entries.

Music compos are the exception from the "one directory per entry" rule; since the audience won't be able to see anything, and TrackMeister runs fullscreen and allows switching to the next track with the `PageDown` key, we can just put all entries into a directory and play that. Naming the files with numbers is still recommended or, in case of TrackMeister, even required. TrackMeister in particular has a few extra amenities: First, it's recommended to have it normalize the volume of all tracks by pressing `Ctrl+Shift+L` once on the first track; second, it's possible to skin it to the party theme by providing a custom `tm.ini` file in the compo directory.

During preparation, make notes which entries are too long and need to be faded out and at which point.

### Oldschool, Mixed and Interactive Compos

In a way, these are the most stressful compos, because they require a lot of mental and physical switching, and for interactive compos, there are a lot of additional people at the compo area.

As far as oldschool is concerned, most of the interesting stuff happens at the oldschool desk. Some communication is needed as to when the video input switch is to happen precisely, and the audio desk needs to be informed about when to switch to which input, or fade stuff in or out.

If the oldschool compo team has a means of digitally recording entries at pristine quality, and the resulting file format can be played back with a software player on the compo PC (ideally CompoKit's MPC-HC), oldschool compos degrade to specialized video compos with mostly 50 Hz content.

CompoKit also ships with some emulators for oldschool platforms, but as we all know, emulation is lame. Thus, the emulators should only be used if everything else fails.

-------------------------------------------------------------------------------

## Aftermath

After the last compo finished and the late-night DJ sets or concerts begin, the compo organizers are supposedly done with their job.

But are they really?

### Upload to scene.org

Here's why we collected all the releases in a nicely laid-out directory structure during the party: Because this way, we can upload the stuff to the scene.org FTP's `incoming` directory right there! Doing this at night is not only a good idea because of Internet bandwith reasons (with most visitors either dancing, socializing, or sleeping, and only few still sitting at their tables), but also because it saves all the hassle of having to boot up the compo PC again at the main organizer's home to salvage the data from there.

Before starting the actual upload though, double-check that all entries from the PMS are present in the upload directory too. Adding them later on may be hard to do, especially after the scene.org administrators moved the party data from `incoming` into `pub/parties` already. (And they can be very quick at that! Think hours, not days.)

### Voting Result Finalization

After the voting deadline, the results need to be reviewed. Are there any obvious signs of vote fraud? Are there any ties that need to be broken in order to guarantee a smooth prizegiving? (The PMS' prizegiving visualization might not deal well with ties within the top three entries of a compo, and depending on how long before the prizegiving the trophies are made, it might not be possible to hand out two "2nd place" trophies, for example.)

Depending on the PMS used, the order of the compo in the prizegiving may need to be specified explicitly. Now is a good time to do that!

After the compo results have been finalized, a hardcopy can be printed out so the presenters of the prizegiving have a way to read out the winners without having to stare at the bigscreen all the time. At the same time, the results can be [exported](src/pm-export-tools) in a raw format that an ASCII artist then turns into the final `results.txt` file. Depending on the type or artwork present in `results.txt`, one of three output encodings need to be chosen: If there's no or only minimal artwork, UTF-8 is fine; if the artwork is ASCII and looks best with the Amiga Topaz font, it should be exported as ISO-8859-1; and if the artwork uses DOS block graphics, the encoding to use is codepage 437 ("`cp437`"). If the output isn't UTF-8, some international characters may need to be replaced by the closest-looking equivalent in the target character set.

In addition to the `results.txt` file, there should also be an export in TSV (tab-separated value) format for Demozoo, with columns for rank, title, author and score, in that order, and in UTF-8 encoding. (CompoKit's [exporter](src/pm-export-tools) can do that too.) Whoever is going to enter the results into Demozoo, they will be very happy if they don't need to extract the data from a line-wrapped ASCII art opus and can instead just copy/paste everything from that TSV file.

Finally, rehearse the prizegiving at the compo desk before actually holding it. The prizegiving isn't a moment where we want to fuck anything up that could have been detected in advance.

### Prizegiving

The prizegiving slides themselves are usually automated, so apart from pressing the wrong buttons (like "next slide" instead of "start running the suspense bars", very common and mildly embarrassing) there's not much that can go wrong.

The more interesting aspect is that we may want to show or play the winning entry on the bigscreen briefly, so people don't need to remember it. To do so, prepare the prizegiving like a compo: Copy the subdirectories of the winning entries from their compo directories into the prizegiving directory, and renumber them to match the prizegiving order while doing so. We don't need full fidelity for playback: for an oldschool entry of which only a few-second excerpt is shown, an emulator or video capture will be fine.

Playback of videos, demos and music entries can be started right when the winners are announced: They will take a minute to arrive at the stage and receive their trophies, and in the meantime, the intro of the entry will be over, just in time for a short switch over to the big screen. For the main demo or intro compos, where the winning entry is to be shown in full length, this doesn't apply &ndash; we will show them from start to end, of course, like in the compo the day before, and without any compromises (read: no emulators allowed). Please coordinate and make notes beforehand which entries to show in full, to avoid any misunderstandings between the compo team and the presenter(s) on stage.

After the prizegiving, there's only two things left to do: Put the `results.txt` file into the scene.org FTP's `incoming` directory and send the results TSV file to a Demozoo organizer, and we can pull the plugs. Literally, if needed.
