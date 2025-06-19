#!/usr/bin/env python3
"""
Generate a template for a results.txt file, a Demozoo-compliant .tsv file, or an
HTML document based on a PartyMeister 3 vote list or Wuhu JSON results export.
"""
import argparse
import textwrap
import html as mod_html
import json
import sys
import os
import io

###############################################################################

def get_first_tag_text(x):
    x = x.split('>', 1)[-1]     # skip until after start tag
    x = x.split('<', 1)[0]      # cut off at end tag
    return mod_html.unescape(x).strip()

def H(x):
    return x.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')

###############################################################################

class CompoEntry:
    def __init__(self, title: str, author: str, score=0, rank=0, flags=[]):
        self.title  = title
        self.author = author
        self.score  = score
        self.rank   = rank
        self.flags  = set(flags or [])

class Compo:
    def __init__(self, name: str):
        self.name = name
        self.entries = []

    def __len__(self):
        return len(self.entries)

###############################################################################

def ParsePartymeisterHTML(doc: str):
    "PartyMeister HTML"
    # warning: this is a *very* hand-wavey and fragile parser!
    if not("<html>" in doc): raise ValueError("not an HTML document")
    if not("<main>" in doc): raise ValueError("<main> tag missing")
    doc = doc.split('</main>', 1)[0]
    for compo_html in doc.split('<h3')[1:]:
        if not("row" in compo_html):
            continue  # not a valid compo -- may be the "deadline at X o'clock" header
        title = get_first_tag_text(compo_html)
        compo = Compo(title)

        for entry in compo_html.split('<div class="row')[1:]:
            row = list(map(get_first_tag_text, entry.split('<div class="col')[1:]))
            flags = []
            if (len(row) in (4,5)) and row[0].startswith('#') and row[0][1:].isdigit() and row[1].isdigit():
                # new four/five-colunm format with explicit ranking and optional remote flag
                rank = int(row[0][1:])
                score = int(row[1])
                title, author = row[2:4]
                if len(row) > 4:
                    flags = row[4].lower().replace(',', ' ').split()
            elif (len(row) == 3) and row[0].isdigit():
                # old three-column format with only scores
                rank = 0
                score = int(row[0])
                title, author = row[1:]
            else:
                print(f"WARNING: unrecognized entry format {row}", file=sys.stderr)
                continue

            compo.entries.append(CompoEntry(title, author, score, rank, flags))
        yield compo

def ParseWuhuJSON(doc: str):
    "Wuhu JSON"
    for compo_struct in json.loads(doc)['compos']:
        compo = Compo(compo_struct['name'])
        for entry in compo_struct['results']:
            compo.entries.append(CompoEntry(
                title  = entry['title'],
                author = entry['author'],
                score  = entry['points'],
                rank   = entry['ranking']))
        yield compo

###############################################################################

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-i", "--infile", metavar="HTML", default="votes.html",
                        help="""
                            input HTML file, saved as a single HTML file
                            (no MTHML!) from the vote list in PartyMeister's
                            backend, or from Wuhu's results -> export as JSON option
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
    parser.add_argument("-n", "--max-rank", metavar="N", type=int,
                        help="only export first N places of the ranking")
    parser.add_argument("-f", "--no-flags", action='store_true',
                        help="omit remote entry flag")
    parser.add_argument("-r", "--reverse", action='store_true',
                        help="output compos in reverse order")
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

    # parse the input file
    errors = []
    compos = None
    for parser in (ParsePartymeisterHTML, ParseWuhuJSON):
        try:
            compos = list(parser(doc))
            print("input format:", parser.__doc__)
            break
        except Exception as e:
            errors.append((parser.__doc__, str(e)))
    if compos is None:
        print("FATAL: input file is invalid", file=sys.stderr)
        for p, e in errors:
            print("  -", p, "parser said:", e, file=sys.stderr)
        sys.exit(1)
    if not compos:
        print(f"FATAL: no valid compos found", file=sys.stderr)
        sys.exit(1)
    print("found", sum(map(len, compos)), "entries across", len(compos), "compos")
    if args.reverse:
        compos = compos[::-1]

    # generate output
    out = io.StringIO()
    if html:
        print('''<!DOCTYPE html>
<html><head>
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
    for compo in compos:
        if html:
            print('<tr class="head"><td colspan="5"><h3>', H(compo.name), "</h3></td></tr>", file=out)
        else:
            print("---", compo.name, file=out)

        count = 0
        prev_rank = 0
        prev_score = 0
        for entry in compo.entries:
            count += 1
            if not entry.rank:  # auto-generate rank based on score
                if entry.score != prev_score:
                    prev_rank = count
                    prev_score = entry.score
                entry.rank = prev_rank
            if args.max_rank and (entry.rank > args.max_rank):
                break
            flags_str = "" if args.no_flags else ", ".join(str(f).upper() for f in entry.flags)

            # build the entry
            if html:
                print('<tr><td class="r">', '#' + str(entry.rank), '</td>', file=out)
                print('<td class="r">', entry.score, '</td>', file=out)
                print('<td>', H(entry.title), '</td>', file=out)
                print('<td>', H(entry.author), '</td>', file=out)
                print('<td>', H(flags_str), '</td></tr>', file=out)
            elif tsv:
                print(f"{entry.rank}\t{entry.title}\t{entry.author}\t{entry.score}", file=out)
            else:
                prefix = f"{entry.rank:02d} {entry.score:4d}  "
                prefixlen = len(prefix)
                title = f"{entry.title} by {entry.author}"
                if flags_str: title = f"{title} [{flags_str}]"
                for line in textwrap.wrap(title, width=args.width-prefixlen):
                    line = prefix + line
                    if args.pad: line = line.ljust(args.width)
                    print(args.prefix + line + args.suffix, file=out)
                    prefix = " " * prefixlen
        print(file=out)

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
