#!/usr/bin/env python3
"""
Download entries from the Wuhu admin backend into a directory.
"""
import argparse
import base64
import getpass
import json
import html
import os
import re
import shutil
import sys
import time
import urllib.request

def fmt_header(s: str):
    return s.upper() if (s.lower() == "url") else s.title()

def wuhu_request(cache: dict, path: str):
    if not path.startswith('/'):
        path = '/' + path
    req = urllib.request.Request(cache['url'] + path)
    for k, v in cache.items():
        req.add_header(fmt_header(k), v)
    return req

def fmt_size(nbytes: int):
    if nbytes < 1000:       return f"{nbytes}b"
    if nbytes < 1000000:    return f"{nbytes/1000:.1f}k"
    if nbytes < 1000000000: return f"{nbytes/1000000:.1f}M"
    else:                   return f"{nbytes/1000000000:.1f}G"

def rm_f(x):
    try:
        os.unlink(x)
    except EnvironmentError:
        pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("url", metavar='SERVER_URL', nargs='?',
                        help="the Wuhu server's URL [default: last used; \"entry list\" plugin must be installed and activated]")
    parser.add_argument("-o", "--outdir", metavar="DIR",
                        help="output directory [default: 'entries' subdirectory of the script's directory]")
    parser.add_argument("-c", "--clean", action='store_true',
                        help="delete output directory before downloading (DANGEROUS!)")
    parser.add_argument("-n", "--dry-run", action='store_true',
                        help="don't download anything, only show what would be done")
    parser.add_argument("-y", "--yes", action='store_true',
                        help="don't confirm deleting old files")
    parser.add_argument("--no-cache", action='store_true',
                        help="don't store login credentials in a file")
    args = parser.parse_args()

    # handle -c and -o args
    mydir = os.path.dirname(sys.argv[0])
    basedir = args.outdir
    if not basedir:
        basedir = os.path.join(mydir, "entries")
    if args.clean and not(args.dry_run) and os.path.isdir(basedir):
        print("cleaning output directory", basedir, "...")
        shutil.rmtree(basedir, ignore_errors=True)

    # load the credentials cache file
    cache_file = None if args.no_cache else os.path.join(mydir, ".wuhu_login")
    cache = {}
    if cache_file:
        try:
            with open(cache_file, "r", encoding='utf-8', errors='replace') as f:
                for n, line in enumerate(f, start=1):
                    line = line.split('#', 1)[0].strip()
                    if not line: continue
                    if ':' in line:
                        k, v = map(str.strip, line.split(':', 1))
                        cache[k.lower()] = v
                    else:
                        print(f"WARNING: syntax error in {cache_file}:{n}", file=sys.stderr)
        except EnvironmentError:
            pass

    # get the server URL
    if not cache.get('url'):
        url = args.url
        if not url:
            try:
                url = input("Wuhu server URL? => ")
            except (EOFError, KeyboardInterrupt):
                print("Aborted.", file=sys.stderr)
                sys.exit(3)
        p = url.lower().find(".php")
        if p > 0:
            url = url[:p].rsplit('/', 1)[0]
        url = url.rstrip('/')
        if not url.lower().startswith(("http://", "https://")):
            print("FATAL: specified URL is not an HTTP(S) URL", file=sys.stderr)
            sys.exit(2)
        cache['url'] = url

    # try to fetch the entry list, handling login along the way
    while True:
        print("fetching entry list from", cache['url'], "...")
        try:
            with urllib.request.urlopen(wuhu_request(cache, '/plugins/entrylist/json.php')) as f:
                data = json.load(f)
            break
        except json.JSONDecodeError as e:
            print("FATAL: invalid JSON data from server -", e, file=sys.stderr)
            sys.exit(1)
        except urllib.error.HTTPError as e:
            if e.code in (401, 403):  # invalid credentials
                try:
                    user = input("Wuhu admin username => ")
                    passwd = getpass.getpass("Wuhu admin password => ")
                except (EOFError, KeyboardInterrupt):
                    print("Aborted.", file=sys.stderr)
                    sys.exit(3)
                if passwd:
                    cache['authorization'] = "Basic " + base64.b64encode((user + ':' + passwd).encode('utf-8')).decode()
                elif 'authorization' in cache:
                    del cache['authorization']
                continue
            else:
                print("FATAL: can't get entry list -", e, file=sys.stderr)
                sys.exit(1)
        except EnvironmentError as e:
            print("FATAL: can't get entry list -", e, file=sys.stderr)
            sys.exit(1)

    # after a successful fetch, store the credentials in the cache
    if cache_file:
        try:
            with open(cache_file, 'w') as f:
                for k, v in cache.items():
                    print(fmt_header(k) + ':', v, file=f)
        except EnvironmentError as e:
            print("WARNING: failed to store the credentials -", e, file=sys.stderr)
    #with open("abfall.json", 'wb') as f: f.write(doc)

    # parse the result
    print("parsing entry list ...")
    subdirs = {}
    if not isinstance(data, list):
        print("FATAL: invalid JSON data from server - expected a list, got something else")
        sys.exit(1)
    for item in data:
        if not isinstance(item, dict): continue
        dirname = item.get('compodir')
        filename = os.path.basename(item.get('filepath', "")) or item.get('filename')
        eid = item.get('id')
        if dirname and filename and eid and (item.get('status') != 'disqualified'):
            if not(dirname in subdirs):
                subdirs[dirname] = {}
            subdirs[dirname][filename] = (f"/compos_entry_edit.php?download={eid}", item.get('filemtime'))
    if not subdirs:
        print("FATAL: no valid entries found - is the entry list plugin installed and activated?", file=sys.stderr)
        sys.exit(1)
    print(sum(map(len, subdirs.values())), "valid entries found across", len(subdirs), "compos")

    # create directory structure
    if not args.dry_run:
        print("creating target directories ...")
        for subdir in subdirs:
            path = os.path.join(basedir, subdir)
            if not os.path.isdir(path):
                try:
                    os.makedirs(path)
                except EnvironmentError as e:
                    print(f"ERROR: could not create target directory '{path}' -", e, file=sys.stderr)

    # enable console codes on Win32 from here on
    if sys.platform == "win32":
        os.system("")

    # now for the main event ...
    new_list = []
    del_list = []
    total_dl = 0
    print("checking and downloading files ...")
    for subdir, files in sorted(subdirs.items()):
        dirpath = os.path.join(basedir, subdir)
        try:
            existing = {f for f in os.listdir(dirpath) if not f.startswith('.')}
        except EnvironmentError as e:
            if not args.dry_run:
                print(f"ERROR: can't list contents of directory '{dirpath}' -", e, file=sys.stderr)

        # handle target files
        for filename, (url, mtime) in sorted(files.items()):
            target = os.path.join(dirpath, filename)
            short_path = subdir + '/' + filename
            print(short_path, end=' ')
            exists = (filename in existing)
            try:
                e_mtime = os.path.getmtime(target)
            except EnvironmentError:
                e_mtime = None
            if exists and (not(mtime) or not(e_mtime) or (abs(mtime - e_mtime) <3)):
                print("\x1b[2m[no update]\x1b[0m")
                continue
            new_list.append(short_path)

            # handle new file
            if args.dry_run:
                if exists:
                    print("\x1b[32m[updated]\x1b[0m")
                else:
                    print("\x1b[32m[new]\x1b[0m")
            else:
                print("\x1b[32m[downloading..", end='')
                sys.stdout.flush()
                try:
                    size = 0
                    with urllib.request.urlopen(wuhu_request(cache, url)) as f_in, open(target, 'wb') as f_out:
                        while True:
                            block = f_in.read(1024*1024)
                            if not block: break
                            f_out.write(block)
                            sys.stdout.write('.')
                            sys.stdout.flush()
                            size += len(block)
                    if mtime:
                        os.utime(target, (mtime, mtime))
                    print(f" {fmt_size(size)} OK]\x1b[0m")
                    total_dl += size
                except EnvironmentError as e:
                    print("\x1b[31;1m - FAILED]\x1b[0m")
                    print(f"ERROR: could not download '{url}' => '{target}':", e, file=sys.stderr)
                    rm_f(target)
                except KeyboardInterrupt:
                    print("\x1b[0m^C")
                    print("Aborted by user.")
                    rm_f(target)
                    sys.exit(3)

        # handle deleted files
        for filename in sorted(existing - set(files)):
            short_path = subdir + '/' + filename
            del_list.append(short_path)
            if args.dry_run:
                print(short_path, "\x1b[33m[old]\x1b[0m")
                continue
            if args.yes:
                answer = "Y"
            else:
                answer = "X"
                while not(answer in ("Y", "N")):
                    print(short_path, "\x1b[33m[old]\x1b[0m delete? (y/n)", end= ' ')
                    sys.stdout.flush()
                    try:
                        answer = input().strip().upper()[:1]
                    except (EnvironmentError, KeyboardInterrupt):
                        print("Aborted by user.", file=sys.stderr)
                        sys.exit(3)
            if answer == "Y":
                print(f, "\x1b[33m[old - deleting]\x1b[0m")
                try:
                    os.unlink(os.path.join(dirpath, filename))
                except EnvironmentError as e:
                    print(f"WARNING: could not delete '{short_path}':", e, file=sys.stderr)
            else:
                print(f, "\x1b[33m[old - keeping]\x1b[0m")

    # print a summary
    if total_dl:
        print(f"Done. {fmt_size(total_dl)} downloaded.")
    else:
        print("Done.")
    if new_list:
        print()
        print(len(new_list), "new or updated file(s):")
        for f in sorted(new_list):
            print(f"    \x1b[32m{f}\x1b[0m")
    if del_list:
        print()
        print(len(del_list), "old or removed file(s):")
        for f in sorted(del_list):
            print(f"    \x1b[31m{f}\x1b[0m")
