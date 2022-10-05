#!/usr/bin/env python3
"""
Download entries from the PartyMeister backend into a directory.
"""
import urllib.request
import urllib.parse
import argparse
import shutil
import html as mod_html
import time
import sys
import ssl
import os
import re

def remove_tags(x):
    return re.sub(r'<[^>]+>', '', x).strip()
def canonicalize(x):
    return re.sub(r'[^a-z0-9]+', '_', x.lower()).strip('_')
def rm_f(x):
    try:
        os.unlink(x)
    except EnvironmentError:
        pass

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
                        help="output directory [default: 'entries' subdirectory of the script's directory]")
    parser.add_argument("-c", "--clean", action='store_true',
                        help="delete output directory before downloading (DANGEROUS!)")
    parser.add_argument("-n", "--dry-run", action='store_true',
                        help="don't download anything, only show what would be done")
    parser.add_argument("-y", "--yes", action='store_true',
                        help="don't confirm deleting old files")
    args = parser.parse_args()

    # handle -c and -o args
    basedir = args.outdir
    if not basedir:
        basedir = os.path.join(os.path.dirname(sys.argv[0]), "entries")
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
    # step 1: decode column headings
    head, html = html.split("<tbody", 1)
    idx_compo = idx_urls = idx_mtime = idx_status = idx_id = -1
    for i, (tag, attrs, th) in enumerate(re.findall(r'<(td|th)([^>]*)>(.*?)</\1>', head.rsplit("<thead", 1)[-1], flags=re.I+re.S)):
        th = th.split('<', 1)[0].strip().lower()
        if th == "id":            idx_id     = i
        if th.startswith("comp"): idx_compo  = i
        if th.startswith("name"): idx_urls   = i
        if "upload" in th:        idx_mtime  = i
        if "status" in th:        idx_status = i
    if min(idx_compo, idx_urls, idx_mtime, idx_status) < 0:
        print("ERROR: didn't find all required columns (compo/URLs/mtime/status)", file=sys.stderr)
        sys.exit(1)

    # step 2: list the entries themselves
    for attrs, tr in re.findall(r'<tr([^>]*)>(.*?)</tr>', html.split("</tbody", 1)[0], flags=re.I+re.S):
        row = [td for attrs, td in re.findall(r'<td([^>]*)>(.*?)</td>', tr, flags=re.I+re.S)]

        # parse the row
        eid = remove_tags(row[idx_id]) if (idx_id >= 0) else "<unknown_id>"
        compo = canonicalize(remove_tags(row[idx_compo]))
        mtime = remove_tags(row[idx_mtime])
        if mtime:
            try:
                mtime = time.mktime(tuple(list(map(int, mtime.replace('-', ' ').replace(':', ' ').split())) + [-1, -1, -1]))
            except ValueError:
                print(f"WARNING: can't parse timestamp {mtime!r} for entry #{eid}", file=sys.stderr)
        else:
            mtime = 0
        urls = [mod_html.unescape(url).strip() for url in \
               re.findall(r'<a\s+[^>]*?href="([^"]+)"', row[idx_urls], flags=re.I+re.S)]
        status = ''.join(st.upper() for cls, st in \
            re.findall(r'<button[^>]*?\s+class="([^"]*)"[^>]*>([^<]*)</button', row[idx_status], flags=re.I+re.S)
            if (len(st) == 1) and not("outline-" in cls))
        if len(status) != 1:
            print(f"WARNING: unclear status {status!r} for entry #{eid}", file=sys.stderr)

        # make sense of the presented information
        if not urls:
            continue  # this entry doesn't have any downloads, no need to bother
        filenames = [os.path.join(os.path.join(basedir, compo), url.rsplit('/', 1)[-1]) for url in urls]
        if status in "DP":  # disqualified/preselected?
            # if D/P, mark all files as old and don't download anything new
            old_files = set(filenames)
            url, target = None, None
        else:
            # valid entry: download first (latest) URL, mark all others as old
            old_files = set(filenames[1:]) - set(filenames[:1])
            url = urls[0]
            target = filenames[0]

        # download new file
        if url and target:
            url_dir, url_base = url.rsplit('/', 1)
            url = url_dir + '/' + urllib.parse.quote(url_base)  # make Python not trip over non-ASCII characters in URLs
            print(target, end=' ')
            try:
                e_mtime = os.path.getmtime(target)
            except EnvironmentError:
                e_mtime = 0
            if abs(mtime - e_mtime) <= 2:
                print("[no update]")
            elif args.dry_run:
                print("[new]")
            else:
                print("[downloading..", end='')
                sys.stdout.flush()
                try:
                    outdir = os.path.dirname(target)
                    if not os.path.isdir(outdir):
                        os.makedirs(outdir)
                    size = 0
                    with urllib.request.urlopen(url, context=ssl_ctx) as f_in, open(target, 'wb') as f_out:
                        while True:
                            block = f_in.read(1024*1024)
                            if not block: break
                            f_out.write(block)
                            sys.stdout.write('.')
                            sys.stdout.flush()
                            size += len(block)
                    os.utime(target, (mtime, mtime))
                    if   size < 1000:       size = f"{size}b"
                    elif size < 1000000:    size = f"{size/1000:.1f}k"
                    elif size < 1000000000: size = f"{size/1000000:.1f}M"
                    else:                   size = f"{size/1000000000:.1f}G"
                    print(f" {size} OK]")
                except EnvironmentError as e:
                    print(" FAILED]")
                    print(f"ERROR: could not download '{url}' => '{target}':", e, file=sys.stderr)
                    rm_f(target)
                except KeyboardInterrupt:
                    print("^C")
                    print("Aborted by user.")
                    rm_f(target)
                    sys.exit(1)

        # remove old file(s)
        for f in old_files:
            if os.path.exists(f):
                if args.dry_run:
                    print(f, "[old]")
                    continue
                if args.yes:
                    answer = "Y"
                else:
                    answer = "X"
                    while not(answer in ("Y", "N")):
                        print(f, "[old] delete? (y/n)", end= ' ')
                        sys.stdout.flush()
                        try:
                            answer = input().strip().upper()[:1]
                        except (EnvironmentError, KeyboardInterrupt):
                            print("^C")
                            print("Aborted by user.")
                            sys.exit(1)
                if answer == "Y":
                    print(f, "[old - deleting]")
                    try:
                        os.unlink(f)
                    except EnvironmentError as e:
                        print(f"WARNING: could not delete '{f}':", e, file=sys.stderr)
                else:
                    print(f, "[old - keeping]")
