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
    parser.add_argument("-H", "--html", action='store_true',
                        help="export HTML preview instead of PNG")
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
    docs = {}
    for attrs, tr in re.findall(r'<tr([^>]*)>(.*?)</tr>', html, flags=re.I+re.S):
        row = [re.sub(r'<[^>]+>', '', td).strip()
               for attrs, td
               in re.findall(r'<td([^>]*)>(.*?)</td>', tr, flags=re.I+re.S)]
        re_ext = "html?" if args.html else "png|jpe?g"
        url = re.search(r'href="(https?://.*?\.(' + re_ext + '))"', tr, flags=re.I)
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
            if (("coming" in stype) or ("now" in stype)) and (("coming" in name) or ("now" in name)):
                name = "00_" + name
            if digits_at_end and (("competition" in stype) or ("compo_entry" in stype)):
                name = digits_at_end.group(1).rjust(2, '0')
            if ("end" in name) and ("end" in stype):
                name = "99_end"

        # download PNG
        if not args.html:
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

        # handle HTML
        if args.html:
            if not folder in docs:
                docs[folder] = {}
            if args.dry_run:
                print(f"{folder}/{name} <= {url}")
            else:
                print(f"<= {folder}/{name}", end=' ')
                try:
                    with urllib.request.urlopen(url, context=ssl_ctx) as f_in:
                        docs[folder][name] = f_in.read().decode('utf-8', 'replace')
                    print("[OK]")
                except EnvironmentError as e:
                    print(e)
            
    # create HTML output
    if args.html and not(args.dry_run):
        if not os.path.isdir(basedir):
            try:
                os.makedirs(basedir)
            except EnvironmentError as e:
                print(f"ERROR: can't create directory '{basedir}':", e, file=sys.stderr)
                sys.exit(1)

        domain = url[:10] + url[10:].split('/', 1)[0] + '/'

        for compo, cdata in docs.items():
            outfile = os.path.join(basedir, compo + ".html")
            print("=>", outfile, end=' ')

            doc = list(cdata.values())[0]
            header, doc = doc.split('<div id="slidemeister">', 1)
            footer = '<script>' + doc.split('<script>', 1)[-1]

            header = header.replace('href="/', 'href="' + domain)

            doc = header.replace('</style>', """
                .exported_off { display:none !important; }
            </style>""")

            if os.path.exists(os.path.join(basedir, "patch.js")):
                doc += """
                    <canvas id="glcanvas" width="100vw" height="100vh" tabindex="1"></canvas>
                    <script type="text/javascript" src="patch.js" async></script>
                    <script>
                            function showError(errId, errMsg)
                            {
                                console.log("Cables error", errId, ":", errMsg);
                            }
                            document.addEventListener("CABLES.jsLoaded", function (event)
                            {
                                CABLES.patch = new CABLES.Patch({
                                    patch: CABLES.exportedPatch,
                                    "prefixAssetPath": "",
                                    "assetPath": "assets/",
                                    "jsPath": "",
                                    "glCanvasId": "glcanvas",
                                    "glCanvasResizeToWindow": true,
                                    "onError": showError,
                                    "canvas": {"alpha":true, "premultipliedAlpha":true } // make canvas transparent
                                });
                            });
                    </script>
                """

            div_attrs = 'class="exported_slide" id="slidemeister"'
            for name, subdoc in sorted(cdata.items()):
                subdoc = subdoc.split('<div id="slidemeister">', 1)[-1]
                if name.isdigit():
                    stype = "compo"
                else:
                    stype = ''.join(c for c in name if c.isalpha())
                div_attrs += f' data-slide-type="{stype}"'
                doc += f"<div {div_attrs}>" + subdoc.split('<script>', 1)[0]
                div_attrs = 'class="exported_slide exported_off"'
            
            doc += footer.replace('</script>', """
                var transitionFrom = null;
                var transitionTo = null;
                const transitionDuration = 1.0;  // seconds
                const opacityStep = 2.0 / (60 * transitionDuration);
                var fadeOpacity = null;

                function fadeInHandler() {
                    fadeOpacity += opacityStep;
                    if (fadeOpacity >= 1.0) { fadeOpacity = 1.0; }
                    transitionTo.style.opacity = fadeOpacity;
                    if (fadeOpacity >= 1.0) {
                        console.log("transition finished");
                    } else {
                        window.requestAnimationFrame(fadeInHandler);
                    }
                }

                function fadeOutHandler() {
                    fadeOpacity -= opacityStep;
                    if (fadeOpacity <= 0.0) { fadeOpacity = 0.0; }
                    transitionFrom.style.opacity = fadeOpacity;
                    if (fadeOpacity <= 0.0) {
                        transitionFrom.classList.add("exported_off");
                        transitionFrom.id = "noid";
                        transitionTo.style.opacity = 0.0;
                        transitionTo.id = "slidemeister";
                        transitionTo.classList.remove("exported_off");
                        CABLES.patch.setVariable("SLIDETYPE", transitionTo.dataset.slideType);
                        window.requestAnimationFrame(fadeInHandler);
                    } else {
                        window.requestAnimationFrame(fadeOutHandler);
                    }
                }

                function startTransition(from, to) {
                    transitionFrom = from;
                    transitionTo = to;
                    if (!from || !to) {
                        console.log("no transition possible");
                        return;
                    }
                    transitionFrom.style.opacity = fadeOpacity = 1.0;
                    window.requestAnimationFrame(fadeOutHandler);
                }

                window.addEventListener('keydown', (event) => {
                    var prevSlide = null;
                    var currentSlide = null;
                    var nextSlide = null;
                    const slides = document.querySelectorAll(".exported_slide");
                    for (var i = 0;  i < slides.length;  ++i) {
                        const slide = slides[i];
                        if (currentSlide && !nextSlide) { nextSlide = slide; }
                        if (slide.id == "slidemeister") { currentSlide = slide; }
                        if (!currentSlide) { prevSlide = slide; }
                    }
                    if (event.code == "ArrowLeft")  startTransition(currentSlide, prevSlide);
                    if (event.code == "ArrowRight") startTransition(currentSlide, nextSlide);
                });                
            </script>""")

            with open(outfile, 'w', encoding='utf-8') as f:
                f.write(doc)
                print("[OK]")
