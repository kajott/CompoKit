#!/usr/bin/env python
"""
Assign EDID information for all inputs of an Extron DXP 88 DVI Pro
or DXP 88 HDMI video matrix switcher.
"""
from __future__ import print_function, unicode_literals
import argparse
import socket
import time
import sys
import re

DEFAULT_IP = "192.168.254.254"
DEFAULT_PORT = 23
CONFIG_FILE = "dvi_matrix_control.conf"

MAX_SLOT_ID = 40
USER_SLOT_BEGIN = 37
USER_SLOT_END = MAX_SLOT_ID
DEFAULT_USER_SLOT = USER_SLOT_BEGIN
DEFAULT_MODES = {
    "out1":1, "out2":2, "out3":3, "out4":4, "out5":5, "out6":6, "out7":7, "out8":8,
      "o1":1,   "o2":2,   "o3":3,   "o4":4,   "o5":5,   "o6":6,   "o7":7,   "o8":8,
     "640x480": 9,   "800x600":11,  "852x480":13, "1024x768":15,  "1024x852":17,
    "1280x768":19, "1280x1024":21, "1365x768":23, "1366x768":25, "1400x1050":27, "1600x1200":28,
     "480p":29,  "480p60":29,
     "576p":30,                "576p50":30,
     "720p":32,  "720p60":32,  "720p50":31,
    "1080i":34, "1080i60":34, "1080i30":34,
    "1080p":36, "1080p60":36, "1080p50":35,
    "user1":37, "user2":38, "user3":39, "user4":40,
       "u1":37,    "u2":38,    "u3":39,    "u4":40,
}

DEFAULT_TIMEOUT = 0.25

class Connection:
    def __init__(self, ip, port, timeout=DEFAULT_TIMEOUT, verbose=False):
        self.timeout = timeout
        self.verbose = verbose
        if self.verbose:
            print("connecting to {}:{} ...".format(ip, port))
        try:
            self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM, socket.IPPROTO_TCP)
            self.sock.settimeout(self.timeout)
            self.sock.connect((ip, port))
        except EnvironmentError as e:
            print("CONNECTION ERROR:", e, file=sys.stderr)
            sys.exit(1)
        if self.verbose:
            print("connection established.")

    def read_response(self, expect=None):
        end = time.time() + self.timeout
        data = b''
        while time.time() < end:
            try:
                data += self.sock.recv(4096)
            except socket.timeout:
                pass
            except EnvironmentError:
                break
        if self.verbose:
            print("received:", repr(data))

        if expect:
            edata = data.strip().decode(errors='replace')
            if not re.match(expect, edata):
                print("UNEXPECTED RESPONSE - expected /{}/, got {!r}".format(expect, edata), file=sys.stderr)
                sys.exit(1)

    def send(self, data):
        if not isinstance(data, bytes):
            data = data.encode()
        if self.verbose:
            print("SENDING: ", repr(data))
        try:
            self.sock.sendall(data)
        except EnvironmentError as e:
            print("CONNECTION ERROR:", e, file=sys.stderr)
            sys.exit(1)

    def close(self):
        try:
            self.sock.close()
        except EnvironmentError:
            pass

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-v", "--verbose", action='store_true',
                        help="print what's done (default: stay silent unless an error occurs)")
    parser.add_argument("-a", "--ip", metavar="A.B.C.D",
                        help="set IPv4 address of matrix (default: read from {} if present, else fall back to {})".format(CONFIG_FILE, DEFAULT_IP))
    parser.add_argument("-p", "--port", metavar="N", type=int,
                        help="set SIS control port (default: read from {} if present, else fall back to {})".format(CONFIG_FILE, DEFAULT_PORT))
    parser.add_argument("-t", "--timeout", metavar="SECONDS", type=float, default=DEFAULT_TIMEOUT,
                        help="set amount of time to wait for responses (default: %(default)s)")
    parser.add_argument("-f", "--edidfile", metavar="EDID.bin",
                        help="load EDID file (256-byte binary dump) into a user-defined EDID slot (37-40) and activate that")
    parser.add_argument("slot", metavar="MODE|SLOT", nargs='?',
                        help="""
                            set internal EDID "slot" number to assign to all outputs
                            (optional if -f is used, mandatory otherwise;
                            can be either a number 1-40 or one of the following
                            mnemonics: """ + ", ".join(sorted(DEFAULT_MODES)) + ")")
    args = parser.parse_args()
    slot = args.slot
    ip = args.ip
    port = args.port

    if slot:
        try:
            slot = int(slot)
        except ValueError:
            try:
                slot = DEFAULT_MODES[slot]
            except KeyError:
                parser.error("unrecognized mode/slot '{}'".format(slot))

    if not(args.edidfile) and not(slot):
        parser.error("neither EDID file nor desired video mode specified")

    if not ip:
        try:
            with open(CONFIG_FILE) as f:
                if args.verbose:
                    print("trying to auto-detect IP address from", CONFIG_FILE, "...")
                for line in f:
                    line = line.strip().replace(',', '.')
                    if line.startswith("//2."):
                        try:
                            line = list(map(int, line[4:].split('.')))
                        except ValueError:
                            line = []
                        if len(line) >= 4: ip   = '.'.join(map(str, line[:4]))
                        if len(line) >  4: port = line[4]
            if args.verbose:
                if ip:
                    print("detected IP address", ip)
                else:
                    print("no IP address configuration found")
        except EnvironmentError:
            pass
    ip = ip or DEFAULT_IP
    port = port or DEFAULT_PORT

    if args.edidfile:
        slot = slot or DEFAULT_USER_SLOT
        if args.verbose:
            print("loading EDID file '{}' into slot #{}".format(args.edidfile, slot))
        with open(args.edidfile, 'rb') as f:
            edid = f.read()
        if len(edid) != 256:
            print("ERROR: EDID file must be exactly 256 bytes long (not {})".format(len(edid)), file=sys.stderr)
            sys.exit(1)
    else:
        edid = None

    assert slot
    c = Connection(ip, port, timeout=args.timeout, verbose=args.verbose)
    c.read_response()

    if edid:
        c.send("\x1bI{}EDID\r\n".format(slot).encode() + edid)
        c.read_response(r'EdidI0*' + str(slot))

    if args.verbose:
        print("setting EDID to slot {}".format(slot))
    c.send("\x1bA{}*EDID\r\n".format(slot))
    c.read_response(r'EdidA0+\*' + str(slot))

    if args.verbose:
        print("done, closing connection.")
    c.close()
