#!/usr/bin/env python2
"""
Minimal simulation of the SIS protocol as implemented by Extron DXP switches.
Really only supports enough of the protocol to talk to dvi_matrix_control.py.

NOTE: This script is just used for development.
      It is *not* required to use dvi_matrix_control with a real switch!
"""
from __future__ import print_function
import SocketServer

class ConnectionHandler(SocketServer.BaseRequestHandler):
    def handle(self):
        self.request.sendall("(c) Copyright 20nn, Extron Electronics DXP DVI-HDMI, Vn.nn, 60-nnnn-01\r\nDdd, DD Mmm YYYY HH:MM:SS\r\n")
        try:
            print("connected")
            buf = ""
            cmd = None
            wait = False
            while True:
                if cmd:
                    if pos > 0:
                        print("dummy data:", repr(buf[:pos]))
                    print(cmd + " command:", repr(buf[pos:]))
                    if response:
                        self.request.sendall(response)
                    buf = ""
                    wait = False
                cmd = pos = response = None
            
                c = self.request.recv(1)
                if not c:
                    print("disconnected")
                    return
                buf += c
                # print("\x1b[37m" + repr(buf) + "\x1b[0m")

                # detect multi-tie command
                if buf.endswith("\x1b+Q"):
                    wait = True
                    continue

                # detect single-tie command
                if not(wait) and (buf[-1] in "!&%$"):
                    pos = buf.rfind("*")
                    if pos < 1:
                        print("bogus command:", repr(buf))
                        buf = ""
                        continue
                    while pos and buf[pos-1].isdigit(): pos -= 1
                    cmd = "single tie"
                    response = "OutX InY All\r\n"
                    continue

                # detect status command
                if not(wait) and (buf in "XINQS"):
                    cmd = "info"
                    response = "whatever\r\n"
                    continue

                # check for end-of-line
                if buf[-1] != "\n":
                    continue
                
                # handle multi-tie command
                pos = buf.find("\x1b+Q")
                if pos >= 0:
                    cmd = "multi tie"
                    response = "Qik\r\n"
                    continue

                # handle ordinary end-of-line
                if buf.strip():
                    print("unrecognized command:", repr(buf))
                else:
                    print("whitespace:", repr(buf))
                buf = ""

        except EnvironmentError as e:
            print("connect error:", e)

class TCPServer(SocketServer.TCPServer):
    allow_reuse_address = True

if __name__ == "__main__":
    TCPServer(("localhost", 2323), ConnectionHandler).serve_forever()
