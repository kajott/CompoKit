# PartyMeister export tools

This directory contains tools to export data from the PartyMeister demoparty
management system into various formats.


## Timetable to C3VOC Event Schedule XML file

The tool `pm_events_to_ccc_xml` exports the timetable ("event" list) from
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
