# PartyMeister / Wuhu export tools

This directory contains tools to export data from the PartyMeister and/or Wuhu
demoparty management systems into various formats.


## Entry File Download (PartyMeister)

The tool `pm_entry_download.py` downloads the released files for all entries
and nicely sorts them into a directory structure with one subdirectory per
compo, suitable for almost direct upload to scene.org.

Input is a saved copy of PartyMeister's `/backend/entries` HTML page in plain
HTML format (i.e. no MHTML).


## Entry File Download (Wuhu)

The tool `wuhu_entry_download.py` does exactly the same, but for Wuhu.
It requires a valid login to the admin backend of the Wuhu installation.


## Voting Result Export (PartyMeister + Wuhu)

The tool `pm_result_export.py` exports the voting results into a text file
that can be used by the ASCII artist to produce the final `results.txt` file,
or HTML for a handout for the presenters of the prizegiving ceremony.

Input is a saved copy of PartyMeister's `/backend/votes` HTML page in plain
HTML format (i.e. no MHTML), or Wuhu's JSON result export (`/results.php?export=json`).

The output will automatically wrap the title and author line to a specified
width in columns. This can be set with the `-w` option.

Output encoding defaults to UTF-8, but other encodings can be set using
the `-e` option.


## Slide Image Export (PartyMeister)

The tool `pm_slide_export.py` exports slides in PNG format into a directory structure.
The main purpose of this is to have a backup of the compo slides in case
the cloud-based PartyMeister is used and the internet connection dies before
or during the compo.

Input is a saved copy of PartyMeister's `/backend/slides` HTML page (plain
HTML, not MHTML!), or a clipboard copy of that page's source code.
Filtering can be done (e.g. to restrict the export to a single competition),
and pagination shall be disabled by selecting a sufficiently high number
of items per page bevore saving or copy-pasting the output.

The slides will be downloaded into a common "base" directory. By default,
that's a subdirectory called `slides` in the directory where the script resides.
Inside that base directory, subdirectories are created for each slide category
(i.e. compo). The file names of the images themselves are derived
from the slide name, except for competition slides, which are renamed to
follow the progression of a compo: `00_coming_up` -> `00_now` - > `01` -> `02`
-> ... -> `99_end`.


## Timetable to C3VOC Event Schedule XML File (PartyMeister)

The tool `pm_events_to_ccc_xml.py` exports the timetable ("event" list) from
PartyMeister into an XML file for C3VOC livestreams (a "Fahrplan" XML file).

It takes a saved copy of the PartyMeister's `/backend/events` HTML page as
an input. Before saving the input, make sure that (a) you're disabling
pagination (by having PartyMeister display more items per page than there
are events), and that (b) plain HTML output is selected when saving.

The tool tries to guess all other FahrplanXML-specific settings from the
timetable HTML file, but this may fail; you need to check the generated file
in any case! In particular, the automatic detection makes the assumptions that
the party name is a single word, that the stream name ("room" in C3VOC parlance)
is the same name in lowercase, and that the overall event name (the URL part
that leads to the specific party) is that name, followed by the year, without
dashes inbetween.

If the party has a separate seminar stream, the seminars can be moved to
the secondary stream by specifying an option like this:

    -m seminar=talk:seminar

This makes PartyMeister events of type "seminar" map the the FahrplanXML event
type "talk" running in the room "seminar".
