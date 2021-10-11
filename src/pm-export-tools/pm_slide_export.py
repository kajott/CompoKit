#!/usr/bin/env python3
"""
Export slides from PartyMeister 3 into a directory with .png files.
"""
import urllib.request
import argparse
import shutil
import sys
import ssl
import os
import re

def canonicalize(x):
    return re.sub(r'[^a-z0-9]+', '_', x.lower()).strip('_')

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-i", "--infile", metavar="HTML",
                        help="""
                            input HTML file, saved as a single HTML file
                            (no MTHML!) from the event list in PartyMeister's
                            backend with pagination disabled (i.e. "items per
                            page" set to maximum)
                        [default: read from stdin]""")
    parser.add_argument("-o", "--outdir", metavar="DIR",
                        help="output directory [default: 'slides' subdirectory of the script's directory]")
    parser.add_argument("-c", "--clean", action='store_true',
                        help="delete output directory before downloading (DANGEROUS!)")
    parser.add_argument("-n", "--dry-run", action='store_true',
                        help="don't download anything, only show what would be done")
    parser.add_argument("-v", "--verbose", action='count',
                        help="be more verbose")
    args = parser.parse_args()

    # handle -c and -o args
    basedir = args.outdir
    if not basedir:
        basedir = os.path.join(os.path.dirname(sys.argv[0]), "slides")
    if args.clean and not(args.dry_run) and os.path.isdir(basedir):
        print("cleaning output directory", basedir, "...")
        shutil.rmtree(basedir, ignore_errors=True)

    # open input file
    if not args.infile:
        if sys.platform == "win32":
            print("reading input from stdin -- paste here and press ^Z and Enter when done:")
        else:
            print("reading input from stdin -- paste here and press ^D when done:")
        html = sys.stdin.read()
    else:
        print("reading input from", args.infile)
        try:
            with open(args.infile, 'r', encoding='utf-8') as f:
                html = f.read()
        except (IOError, UnicodeError) as e:
            print("FATAL: can not read input file:", e, file=sys.stderr)
            sys.exit(1)

    # disable SSL certificate validation: some Python versions don't trust
    # more recent Let's Encrypt certificates :(
    ssl_ctx = ssl.create_default_context()
    ssl_ctx.check_hostname = False
    ssl_ctx.verify_mode = ssl.CERT_NONE

    # our super-simplistic, very special-cased parser
    html = html.split("<tbody", 1)[-1]
    for attrs, tr in re.findall(r'<tr([^>]*)>(.*?)</tr>', html, flags=re.I+re.S):
        row = [re.sub(r'<[^>]+>', '', td).strip()
               for attrs, td
               in re.findall(r'<td([^>]*)>(.*?)</td>', tr, flags=re.I+re.S)]
        url = re.search(r'href="(https?://.*?\.(png|jpe?g))"', tr, flags=re.I)
        if url: url = url.group(1)
        if not(url) or (len(row) < 5):
            print(f"WARNING: invalid slide {row[:5]}", file=sys.stderr)
            continue
        name = canonicalize(row[2])
        stype = canonicalize(row[3])
        folder = canonicalize(row[4])

        # extract and "beautify" file name
        ext = os.path.splitext(url.rsplit('/', 1)[-1])[-1]
        pg_slide = re.match(r'competition_(\d+)_(now|bars|winners)', name)
        if pg_slide:
            name = pg_slide.group(1).rjust(2, '0') \
                 + {"now":"a", "bars": "b", "winners": "c"}.get(pg_slide.group(2), "") \
                 + "_" + pg_slide.group(2)
        else:
            digits_at_end = re.search(r'(\d+)$', name)
            if ("coming" in stype) and (("coming" in name) or ("now" in name)):
                name = "00_" + name
            if digits_at_end and ("competition" in stype):
                name = digits_at_end.group(1).rjust(2, '0')
            if ("end" in name) and ("end" in stype):
                name = "99_end"

        # download
        outdir = os.path.join(basedir, folder)
        if not(os.path.isdir(outdir)) and not(args.dry_run):
            try:
                os.makedirs(outdir)
            except EnvironmentError as e:
                print(f"ERROR: can't create directory '{outdir}':", e, file=sys.stderr)
                continue
        outfile = os.path.join(outdir, name + ext)
        if args.verbose:
            print(url)
        if args.dry_run:
            print("=>", outfile)
        else:
            print("=>", outfile, end=' ')
            sys.stdout.flush()
            try:
                with urllib.request.urlopen(url, context=ssl_ctx) as f_in, open(outfile, 'wb') as f_out:
                    f_out.write(f_in.read())
                print("[OK]")
            except EnvironmentError as e:
                print(e)
