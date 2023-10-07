#!/usr/bin/env python3
"""
Generate a template for a results.txt file, a Demozoo-compliant .tsv file,
or an HTML document based on a PartyMeister 3 vote list.
"""
import argparse
import textwrap
import html as mod_html
import sys
import os
import io


def get_first_tag_text(x):
    x = x.split('>', 1)[-1]     # skip until after start tag
    x = x.split('<', 1)[0]      # cut off at end tag
    return mod_html.unescape(x).strip()

def H(x):
    return x.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-i", "--infile", metavar="HTML", default="votes.html",
                        help="""
                            input HTML file, saved as a single HTML file
                            (no MTHML!) from the vote list in PartyMeister's
                            backend
                        [default: %(default)s]""")
    parser.add_argument("-o", "--outfile", metavar="FILE", default="raw_results.txt",
                        help="""
                            output file;
                            if ending with .tsv, export will be in Demozoo format;
                            if ending with .html, export will be in HTML format
                        [default: %(default)s]""")
    parser.add_argument("-w", "--width", metavar="COLS", type=int, default=72,
                        help="""
                            number of columns to be used in text output
                        [default: %(default)s; not including --prefix/--suffix]""")
    parser.add_argument("-p", "--pad", action='store_true',
                        help="""pad to specified width with spaces
                                [text output only]""")
    parser.add_argument("--prefix", metavar="STR", default="",
                        help="text output line prefix")
    parser.add_argument("--suffix", metavar="STR", default="",
                        help="text output line suffix")
    parser.add_argument("-e", "--encoding", metavar="CHARSET", default="utf8",
                        help="""
                            output file encoding
                        [default: %(default)s; other useful values: cp437, cp1252]""")
    parser.add_argument("-n", "--max-place", metavar="N", type=int,
                        help="only export first N places")
    parser.add_argument("-f", "--no-flags", action='store_true',
                        help="omit remote entry flag")
    args = parser.parse_args()

    # open input file
    print("reading input from", args.infile)
    try:
        with open(args.infile, 'r', encoding='utf-8') as f:
            doc = f.read()
    except (IOError, UnicodeError) as e:
        print("FATAL: can not read input file:", e, file=sys.stderr)
        sys.exit(1)
    ext = os.path.splitext(args.outfile)[-1].strip('.').lower()
    tsv = (ext in ("tsv", "csv"))
    html = (ext in ("htm", "html"))

    # parse the input file (in a *very* hand-wavey way!) and generate output
    out = io.StringIO()
    if html:
        print('''<!DOCTYPE html>
<head>
<meta charset="XXXCHARSETXXX">
<title>Votesheet Export</title>
<style type="text/css">
body { font-family: "Segoe UI", Roboto, Helvetica, sans-serif, Arial; }
h3 { margin: 1em 0 0 0; padding: 0; border-bottom: solid 0.75pt black; }
td { padding: 0.1em 0.5em 0.1em 0; vertical-align: top; }
tr, td { break-before: avoid; break-inside: avoid; }
.head, .head td { break-before: auto; }
.r { text-align: right; }
</style>
</head><body>
<table>''', file=out)
    doc = doc.split('</main>', 1)[0]
    valid = False
    for compo in doc.split('<h3')[1:]:
        if not("row" in compo):
            continue  # not a valid compo -- may be the "deadline at X o'clock" header
        title = get_first_tag_text(compo)
        if html:
            print('<tr class="head"><td colspan="5"><h3>', H(title), "</h3></td></tr>", file=out)
        else:
            print("---", title, file=out)

        count = 0
        last_place = 0
        last_score = 0
        for entry in compo.split('<div class="row')[1:]:
            row = list(map(get_first_tag_text, entry.split('<div class="col')[1:]))
            rawflags = ""
            if (len(row) in (4,5)) and row[0].startswith('#') and row[0][1:].isdigit() and row[1].isdigit():
                # new four/five-colunm format with explicit placing and optional remote flag
                place = int(row[0][1:])
                score = int(row[1])
                title, author = row[2:4]
                if len(row) > 4: rawflags = row[4]
            elif (len(row) == 3) and row[0].isdigit():
                # old three-column format with only scores
                place = 0
                score = int(row[0])
                title, author = row[1:]
            else:
                print(f"WARNING: unrecognized entry format {row}", file=sys.stderr)
                continue

            count += 1
            if not place:  # auto-generate placement number based on score
                if score != last_score:
                    last_place = count
                    last_score = score
                place = last_place
            if args.max_place and (place > args.max_place):
                break

            # resolve flags
            flags = []
            if not args.no_flags:
                if "remote" in rawflags.lower(): flags += ["REMOTE"]
            flags_str = ", ".join(flags)

            # build the entry
            if html:
                print('<tr><td class="r">', '#' + str(place), '</td>', file=out)
                print('<td class="r">', score, '</td>', file=out)
                print('<td>', H(title), '</td>', file=out)
                print('<td>', H(author), '</td>', file=out)
                print('<td>', H(flags_str), '</td></tr>', file=out)
            elif tsv:
                print(f"{place}\t{title}\t{author}\t{score}", file=out)
            else:
                prefix = f"{place:02d} {score:4d}  "
                prefixlen = len(prefix)
                title = f"{title} by {author}"
                if flags_str: title = f"{title} [{flags_str}]"
                for line in textwrap.wrap(title, width=args.width-prefixlen):
                    line = prefix + line
                    if args.pad: line = line.ljust(args.width)
                    print(args.prefix + line + args.suffix, file=out)
                    prefix = " " * prefixlen
        print(file=out)
        valid = True

    if not valid:
        print(f"FATAL: no valid compos found", file=sys.stderr)
        sys.exit(1)

    if html:
        print('</table></body></html>', file=out)
    out = out.getvalue().strip()
    if html:
        out = out.replace("XXXCHARSETXXX", args.encoding)

    # write output file
    print("writing", args.outfile)
    try:
        with open(args.outfile, 'w', encoding=args.encoding, errors='replace') as f:
            print(out, file=f)
    except (IOError, UnicodeError) as e:
        print("FATAL: can not write output file:", e, file=sys.stderr)
        sys.exit(1)
