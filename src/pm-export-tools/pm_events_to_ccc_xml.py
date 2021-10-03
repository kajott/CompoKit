#!/usr/bin/env python3
"""
Convert a PartyMeister 3 events list into a "Fahrplan" XML file
for C3VOC streaming.

Assumes that the event will take place in this computer's time zone.
"""
import argparse
import time
import uuid
import sys
import re

RootNamespaceUUID = uuid.UUID("22d1e322-e72b-4f28-80d1-9c1b7e2aebb1")

re_time = re.compile(r'(?P<dy>\d{4})-(?P<dm>\d{2})-(?P<dd>\d{2})(\s+|T)(?P<th>\d{2}):(?P<tm>\d{2})')

def canonicalize(x):
    return x.replace(' ', '').lower()

def map_item(name):
    pm_type, xml_type = name.split('=', 1)
    if ':' in xml_type:
        xml_type, room = xml_type.split(':', 1)
    else:
        room = None
    return (canonicalize(pm_type), xml_type, room)

DefaultMap = [
    "Event=generic",
    "Demoshow=generic",
    "Competition=generic",
    "Concert=liveset",
    "LiveAct=liveset",
    "Seminar=talk",
]

def xmltimestamp(t):
    t = time.localtime(t)
    tz = time.strftime("%z", t)
    return time.strftime("%Y-%m-%dT%H:%M:%S", t) + tz[:-2] + ":" + tz[-2:]


class Event:
    day_split_hour = 6

    def __init__(self, title, start, pm_type, xml_type, room, eid=None):
        self.title = title
        self.start = start
        self.end = None
        self.type = xml_type
        self.room = room
        t = time.localtime(start)
        if t.tm_hour < self.day_split_hour:
            # if the event is before the "day split" point, count it to the previous day
            t = time.localtime(start - 86400)
        self.day = tuple(t[:3])
        self.eid = eid
        if room == pm_type:
            self.slug = room + "-"
        else:
            self.slug = f"{room}-{pm_type}-"
        # note: slug is incomplete at this point; a unique ID is added later
        self.uuid = None

    def __str__(self):
        return str(self.eid).rjust(4) + ": <{:04d}-{:02d}-{:02d}> ".format(*self.day) \
            + time.strftime("%Y-%m-%d %H:%M", time.localtime(self.start)) + " - " \
            + (time.strftime("%Y-%m-%d %H:%M", time.localtime(self.end)) if self.end else "????-??-?? ??:??") \
            + f" [{self.slug}] {self.title} {{{self.uuid}}}"


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-i", "--infile", metavar="HTML", default="events.html",
                        help="""
                            input HTML file, saved as a single HTML file
                            (no MTHML!) from the event list in PartyMeister's
                            backend with pagination disabled (i.e. "events per
                            page" set to maximum)
                        [default: %(default)s]""")
    parser.add_argument("-o", "--outfile", metavar="XML", default="schedule.xml",
                        help="output XML file [default: %(default)s]")
    parser.add_argument("-r", "--room", metavar="NAME",
                        help="default room name [default: infer from page title]")
    parser.add_argument("-t", "--title", metavar="NAME",
                        help="party title [default: infer from room name and year]")
    parser.add_argument("-a", "--acronym", metavar="NAME",
                        help="""
                            party 'acronym' (the event name in the
                            streaming site's URL)
                            [default: infer from title]
                        """)
    parser.add_argument("-m", "--map", metavar="TYPE=TYPE[:ROOM]", type=map_item, action='append', default=[],
                        help="""
                            map a PM event type (e.g. "Competition", case-insenstive, spaces are ignored)
                            to an XML event type (e.g. "general")
                            and (optionally) a specific room;
                            can be used multiple times;
                            unmapped types (e.g. deadlines) and PM types
                            with empty XML type are ignored
                            [default: {}]
                        """.format(", ".join(DefaultMap)))
    parser.add_argument("-d", "--max-duration", metavar="H:MM", default="2:00",
                        help="""
                            maximum duration of events in a room
                        [default: %(default)s]""")
    parser.add_argument("-s", "--day-split", metavar="HOUR", type=int, default=6,
                        help="""
                            hour at which events are split into days
                        [default: %(default)s]""")
    parser.add_argument("-x", "--exclude", metavar="TEXT", action='append', type=canonicalize, default=[],
                        help="""
                            exclude items that have TEXT in their description;
                            can be used multiple times
                            [default: no exclusions]
                        """)
    parser.add_argument("-n", "--version", metavar="STR", default="1.0",
                        help="""
                            value of the <version> tag
                        [default: %(default)s]""")
    parser.add_argument("--include-last", action='store_true',
                        help="""
                            include the very last event in the schedule
                            (which is typically "end of party");
                            by default, this will be omitted and used to
                            determine the second-to-last event's duration
                        """)
    parser.add_argument("-v", "--verbose", action='count',
                        help="be more verbose")
    args = parser.parse_args()
    try:
        h, m = map(int, args.max_duration.split(':'))
    except ValueError:
        parser.error("invalid maximum duration")
    max_duration = (60 * h + m) * 60
    Event.day_split_hour = args.day_split

    # open input file
    print("reading input from", args.infile)
    try:
        with open(args.infile, 'r', encoding='utf-8') as f:
            html = f.read()
    except (IOError, UnicodeError) as e:
        print("FATAL: can not read input file:", e, file=sys.stderr)
        sys.exit(1)

    # auto-detect default room name, title and acronym
    default_room = args.room
    title = args.title
    acronym = args.acronym
    if not default_room:
        # auto-detect strategy: analyze the title tag, split it into words,
        # and remove the words that are always there; if only one word remains,
        # use that (in lowercase) as the default room name
        m = re.search(r'<title>(.*?)</title>', html, flags=re.I+re.S)
        if m:
            words = set(m.group(1).lower().split()) \
                  - {"partymeister", "backend", "home", "-", "event", "events", "schedule", "timetable"}
            if len(words) == 1:
                default_room = words.pop()
        if not default_room:
            print("FATAL: no default room name specified and auto-detection failed", file=sys.stderr)
            sys.exit(1)
        print(f"default room name auto-detected as '{default_room}'")

    # resolve type map
    type_map = {}
    for pm_type, xml_type, room in list(map(map_item, DefaultMap)) + args.map:
        type_map[pm_type] = (xml_type, room)

    # prepare data structures
    used_pm_types = set()
    events = []

    # our super-simplistic, very special-cased parser
    html = html.split("<tbody", 1)[-1]
    for attrs, tr in re.findall(r'<tr([^>]*)>(.*?)</tr>', html, flags=re.I+re.S):
        row = [re.sub(r'<[^>]+>', '', td).strip()
               for attrs, td
               in re.findall(r'<td([^>]*)>(.*?)</td>', tr, flags=re.I+re.S)]

        # parse time
        t = re_time.match(row[2])
        if not t:
            print("WARNING: invalid event {row[:3]}", file=sys.stderr)
            continue
        t = time.mktime((int(t.group('dy')), int(t.group('dm')), int(t.group('dd')),
                         int(t.group('th')), int(t.group('tm')), 0,
                         -1, -1, -1))

        # check for exclusion
        title_l = canonicalize(row[0])
        if any((excl in title_l) for excl in args.exclude):
            continue

        # resolve type
        pm_type = canonicalize(row[1])
        used_pm_types.add(pm_type)
        xml_type, room = type_map.get(pm_type, (None, None))
        if not xml_type:
            continue  # ignored event

        # extract ID (if present)
        m = re.search(r'data-record-id="(\d+)"', tr)
        eid = int(m.group(1)) if m else None

        # enter event
        events.append(Event(row[0], t, pm_type, xml_type, room or default_room, eid))

    # summarize data
    if not events:
        print("FATAL: no valid events found in input file", file=sys.stderr)
        sys.exit(1)
    events.sort(key=lambda e: e.start)
    if args.include_last:
        end_of_party = events[-1].start + max_duration
    else:
        end_of_party = events.pop().start
    rooms = set(e.room for e in events)
    days = set(e.day for e in events)
    print(f"found {len(events)} event(s) across {len(days)} day(s) and {len(rooms)} room(s)")

    # now that we have events, auto-detect the title and acronym
    if not title:
        title = default_room.capitalize() + " " + str(min(days)[0])
        print(f"party title auto-detected as '{title}'")
    if not acronym:
        acronym = canonicalize(title)
        print(f"party acronym auto-detected as '{acronym}'")
    party_uuid = uuid.uuid5(RootNamespaceUUID, acronym)

    # fill in end times for all events
    for room in rooms:
        t = end_of_party
        for e in reversed(events):
            if e.room != room: continue
            e.end = min(t, e.start + max_duration)
            t = e.start

    # assign IDs, slugs and UUIDs
    next_id = max((e.eid or 0) for e in events) + 100
    slugs = {}
    for e in events:
        if not e.eid:
            e.eid = next_id
            next_id += 1
        slug_base = e.slug
        slug_id = slugs.get(slug_base, 0) + 1
        e.slug += str(slug_id)
        slugs[slug_base] = slug_id
        e.uuid = str(uuid.uuid5(party_uuid, canonicalize(e.title)))

    # dump (in verbose mode)
    if args.verbose:
        print("event list:")
        for e in events:
            print("  -", e)

    # produce output
    print("writing output to", args.outfile)
    try:
        with open(args.outfile, 'w', encoding='utf-8') as f:
            f.write( "<?xml version='1.0' encoding='utf-8' ?>\n")
            f.write( '<schedule>\n')
            f.write( '  <generator name="pm_events_to_ccc_xml" />\n')
            f.write(f'  <version>{args.version}</version>\n')
            f.write( '  <conference>\n')
            f.write(f'    <title>{title}</title>\n')
            f.write(f'    <acronym>{acronym}</acronym>\n')
            f.write(f'    <days>{len(days)}</days>\n')
            f.write( '    <start>{}</start>\n'.format('-'.join(f"{x:02d}" for x in min(days))))
            f.write( '    <end>{}</end>\n'.format('-'.join(f"{x:02d}" for x in max(days))))
            f.write( '    <timeslot_duration>00:10</timeslot_duration>\n')
            f.write( '  </conference>\n')
            for nday, day in enumerate(sorted(days)):
                dstart = min(e.start for e in events if e.day == day)
                dend = max(e.end for e in events if e.day == day)
                if args.verbose:
                    print(f"day {nday+1}:",
                          time.strftime("%Y-%m-%d %H:%M", time.localtime(dstart)), "-",
                          time.strftime("%Y-%m-%d %H:%M", time.localtime(dend)))
                f.write(f'  <day index="{nday+1}" date="{day[0]:04d}-{day[1]:02d}-{day[2]:02d}" start="{xmltimestamp(dstart)}" end="{xmltimestamp(dend)}">\n')
                for room in sorted({e.room for e in events if e.day == day}):
                    f.write(f'    <room name="{room}">\n')
                    for e in events:
                        if (e.day != day) or (e.room != room): continue
                        start = time.localtime(e.start)
                        minutes = int((e.end - e.start) / 60 + 0.5)
                        f.write(f'      <event id="{e.eid}" guid="{e.uuid}">\n')
                        f.write(f'        <date>{xmltimestamp(e.start)}</date>\n')
                        f.write(f'        <start>{start.tm_hour:02d}:{start.tm_min:02d}</start>\n')
                        f.write(f'        <duration>{minutes//60}:{minutes%60:02d}</duration>\n')
                        f.write(f'        <room>{e.room}</room>\n')
                        f.write(f'        <slug>{e.slug}</slug>\n')
                        f.write(f'        <title>{e.title}</title>\n')
                        f.write(f'        <type>{e.type}</type>\n')
                        f.write( '        <language>en</language>\n')
                        f.write( '        <subtitle/><track/><abstract/><description/><logo/><links/><attachments/>\n')
                        f.write( '      </event>\n')
                    f.write( '    </room>\n')
                f.write( '  </day>\n')
            f.write( '</schedule>\n')
    except IOError as e:
        print("FATAL: can not write output file:", e, file=sys.stderr)
        sys.exit(1)
