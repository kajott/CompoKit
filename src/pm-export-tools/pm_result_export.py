#!/usr/bin/env python3
"""
Generate a template for a results.txt file or a Demozoo-compliant .tsv file
based on a PartyMeister 3 vote list.
"""
import argparse
import textwrap
import html
import sys
import os
import io


def get_first_tag_text(x):
    x = x.split('>', 1)[-1]     # skip until after start tag
    x = x.split('<', 1)[0]      # cut off at end tag
    return html.unescape(x).strip()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-i", "--infile", metavar="HTML", default="votes.html",
                        help="""
                            input HTML file, saved as a single HTML file
                            (no MTHML!) from the vote list in PartyMeister's
                            backend
                        [default: %(default)s]""")
    parser.add_argument("-o", "--outfile", metavar="TXTFILE", default="raw_results.txt",
                        help="""
                            output file;
                            if ending with .tsv, export will be in Demozoo format
                        [default: %(default)s]""")
    parser.add_argument("-w", "--width", metavar="COLS", type=int, default=72,
                        help="""
                            number of columns to be used in the output
                        [default: %(default)s; ignored in Demozoo mode]""")
    parser.add_argument("-e", "--encoding", metavar="CHARSET", default="utf8",
                        help="""
                            output file encoding
                        [default: %(default)s; other useful values: cp437, cp1252]""")
    parser.add_argument("-v", "--verbose", action='count',
                        help="be more verbose")
    args = parser.parse_args()

    # open input file
    print("reading input from", args.infile)
    try:
        with open(args.infile, 'r', encoding='utf-8') as f:
            doc = f.read()
    except (IOError, UnicodeError) as e:
        print("FATAL: can not read input file:", e, file=sys.stderr)
        sys.exit(1)
    tsv = os.path.splitext(args.outfile)[-1].strip('.').lower() in ("tsv", "csv")

    # parse the input file (in a *very* hand-wavey way!) and generate output
    out = io.StringIO()
    doc = doc.split('</main>', 1)[0]
    for compo in doc.split('<h3')[1:]:
        if not("row" in compo):
            continue  # not a valid compo -- may be the "deadline at X o'clock" header
        print("---", get_first_tag_text(compo), file=out)

        count = 0
        last_place = 0
        last_score = 0
        for entry in compo.split('<div class="row')[1:]:
            row = list(map(get_first_tag_text, entry.split('<div class="col')[1:]))
            if (len(row) == 4) and row[0].startswith('#') and row[0][1:].isdigit() and row[1].isdigit():
                # new four-colunm format with explicit placing
                place = int(row[0][1:])
                score = int(row[1])
                title, author = row[2:]
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

            # build the entry
            if tsv:
                print(f"{place}\t{title}\t{author}\t{score}", file=out)
            else:
                prefix = f"{place:02d} {score:4d}  "
                prefixlen = len(prefix)
                title = f"{title} by {author}"
                for line in textwrap.wrap(title, width=args.width-prefixlen):
                    print(prefix + line, file=out)
                    prefix = " " * prefixlen
        print(file=out)

    if not out.getvalue():
        print(f"FATAL: no valid compos found", file=sys.stderr)
        sys.exit(1)

    # write output file
    print("writing", args.outfile)
    try:
        with open(args.outfile, 'w', encoding=args.encoding, errors='replace') as f:
            print(out.getvalue().strip(), file=f)
    except (IOError, UnicodeError) as e:
        print("FATAL: can not write output file:", e, file=sys.stderr)
        sys.exit(1)
