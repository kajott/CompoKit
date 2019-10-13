#!/usr/bin/env python
"""
Simple command-line based controller application for Lightware and Extron
DVI or HDMI crossbar video switches. Supports up to 10 macros.
"""
from __future__ import print_function
import sys, os, time, threading, socket

DEFAULT_CONFIGFILE = "dvi_matrix_control.conf"

MAX_CONNECT_TIMEOUT = 1.0
MAX_COMMAND_TIMEOUT = 0.1
POLL_INTERVAL = 0.05

try: # Python 2/3 compatibility
    input = raw_input
except:
    pass

###############################################################################

class ProtocolBase(object):
    default_ip = [192, 168, 254, 254]
    default_port = 0
    default_baud = 9600
    default_bits = 801
    def __init__(self):  self.result = None
    def connect(self): pass
    def receive(self, line): pass
    def switch_single(self, pin, pout): pass
    def switch_multi(self, ties):
        for pin, pout in ties:
            self.switch_single(pin, pout)
    def notify_success(self): self.result = True
    def notify_error(self): self.result = False
    def clear_status(self): self.result = None

class LightwareProtocol(ProtocolBase):
    "Lightware LW1 Protocol"
    default_port = 10001

    def connect(self):
        self.notify_success()

    def receive(self, line):
        if line.startswith(b'(') and line.endswith(b')'):
            self.notify_success()

    def switch_single(self, pin, pout):
        return b'{%d@%d}\r\n' % (pin, pout)

class ExtronProtocol(ProtocolBase):
    "Extron DXP SIS Protocol"
    default_port = 23

    def connect(self):
        self.notify_success()

    def receive(self, line):
        if line.lower().startswith((b"login ", b"qik", b"out")):
            self.notify_success()

    def switch_single(self, pin, pout):
        return b'%d*%d!' % (pin, pout)

    def switch_multi(self, ties):
        return b'\x1b+Q' + b''.join(b'%d*%d!' % (pin, pout) for pin, pout in ties) + b'\r\n'

Protocols = {
    1: LightwareProtocol,
    2: ExtronProtocol,
}

###############################################################################

class UnsuitableConnectionParameters(ValueError):
    pass

class ConnectionBase(object):
    def __init__(self, proto_id):
        try:
            proto = Protocols[proto_id]
        except KeyError:
            raise UnsuitableConnectionParameters("invalid protocol")
        self.proto = proto()
        self.conn = None
        self.receiver = None
        self.cancel = False

    def receiver_thread(self):
        buf = b''
        while not self.cancel:
            try:
                buf += self.do_receive(self.conn).replace(b'\r', b'\n')
            except EnvironmentError:
                pass
            while b'\n' in buf:
                line, buf = buf.split(b'\n', 1)
                if line:
                    self.proto.receive(line)

    def connect(self):
        if self.conn:
            return
        t1 = time.time() + MAX_CONNECT_TIMEOUT
        try:
            self.conn = self.do_connect(MAX_CONNECT_TIMEOUT)
        except EnvironmentError:
            self.conn = None
            return
        self.cancel = False
        self.receiver = threading.Thread(target=self.receiver_thread, name="Receiver")
        self.receiver.daemon = True
        self.receiver.start()
        self.proto.clear_status()
        self.proto.connect()
        while (self.proto.result is None) and (time.time() < t1):
            time.sleep(POLL_INTERVAL)
        return self.proto.result

    def disconnect(self):
        if not self.conn:
            return
        self.cancel = True
        self.do_disconnect(self.conn)
        self.receiver.join(MAX_CONNECT_TIMEOUT)
        self.receiver = None
        self.conn = None

    def send(self, data, allow_reconnect=True, wait=True):
        if not(self.conn):
            res = self.connect()
            if self.conn and not res:
                print("! reconnect didn't succeed, trying to send anyway")
            if not self.conn:
                print("! reconnect attempt failed, can't send command")
                return
        self.proto.clear_status()
        try:
            part = data
            while part:
                n = self.do_send(self.conn, part)
                part = part[n:]
            self.do_flush(self.conn)
        except EnvironmentError:
            if allow_reconnect:
                print("! connection lost, reconnecting and retrying")
                self.disconnect()
                return self.send(data, allow_reconnect=False, wait=wait)
        if wait:
            t1 = time.time() + MAX_COMMAND_TIMEOUT
            while (self.proto.result is None) and (time.time() < t1):
                time.sleep(POLL_INTERVAL)
            if self.proto.result is None:
                print("! no reaction from device, reconnecting and retrying")
                self.disconnect()
                return self.send(data, allow_reconnect=False, wait=wait)
            if not self.proto.result:
                print("! device reports error")

    def do_flush(self, conn):
        pass


class TCPConnection(ConnectionBase):
    "[192.168.x.y[,port]] - TCP connection"
    def __init__(self, proto, *params):
        ConnectionBase.__init__(self, proto)
        if not(len(params) in (0, 4, 5)) \
        or ((len(params) >= 4) and not(all(0 <= p < 256 for p in params[:4]))) \
        or ((len(params) == 5) and not(0 < params[4] < 65536)):
            raise UnsuitableConnectionParameters()
        self.ip = '.'.join(map(str, (self.proto.default_ip if (len(params) < 4) else tuple(params[:4]))))
        self.port = self.proto.default_port if (len(params) < 5) else params[4]
        print("* connecting to {}:{}".format(self.ip, self.port))
    def do_connect(self, timeout):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM, socket.IPPROTO_TCP)
        s.settimeout(timeout)
        s.connect((self.ip, self.port))
        return s
    def do_disconnect(self, s):
        try:
            s.shutdown(socket.SHUT_RDWR)
        except EnvironmentError as e:
            pass
        s.close()
    def do_receive(self, s):
        return s.recv(1024)
    def do_send(self, s, data):
        return s.send(data)

class SerialConnection(ConnectionBase):
    "port[,baud[,<bits><parity><stop>]] - serial connection"
    def __init__(self, proto, *params):
        ConnectionBase.__init__(self, proto)
        if not(len(params) in (1, 2, 3, 5)) \
        or ((len(params) >= 2) and (params[1] < 300)) \
        or ((len(params) == 3) and not(700 < params[2] < 822)) \
        or ((len(params) >  3) and not(7 <= params[2] <= 8)) \
        or ((len(params) >  3) and not(0 <= params[3] <= 2)) \
        or ((len(params) >  3) and not(0 <= params[4] <= 2)):
            raise UnsuitableConnectionParameters()
        self.port = params[0]
        self.baud = self.proto.default_baud if (len(params) < 2) else params[1]
        if len(params) > 3:
            self.bits, self.parity, self.stop = params[2:5]
        else:
            bits = self.proto.default_bits if (len(params) < 3) else params[2]
            self.bits   = (bits / 100) % 10
            self.parity = (bits /  10) % 10
            self.stop   =  bits        % 10

Connections = [TCPConnection]
try:
    import serial
    Connections.append(SerialConnection)
except ImportError:
    pass

###############################################################################

class DVIMatrixController(object):
    def __init__(self, configfile=None):
        self.configfile = configfile or DEFAULT_CONFIGFILE
        self.macros = {}
        self.connection_config = []
        self.config_lock = False
        self.conn = None

    def save_config(self):
        if self.config_lock:
            return
        try:
            with open(self.configfile, "w") as f:
                print("//" + '.'.join(map(str, self.connection_config)), file=f)
                for k in sorted(self.macros):
                    print("*{}*{}".format(k, ','.join(self.macros[k])), file=f)
        except EnvironmentError as e:
            print("error: failed to write configuration file '{}':".format(self.configfile, e))

    def load_config(self):
        self.config_lock = True
        try:
            with open(self.configfile) as f:
                print("----- loading and executing configuration file ('{}') -----".format(self.configfile))
                for cmd in f:
                    self.handle_cmd(cmd, echo="+ ", verbose=False)
                print("----- configuration file loaded -----")
        except EnvironmentError as e:
            pass  # no error if config file doesn't exist
        self.config_lock = False

    def handle_cmd(self, cmd, echo=None, verbose=True):
        cmd = cmd.split('#', 1)[0].strip().replace(',', '.').lower()
        if not cmd:
            return
        if echo:
            print(echo + cmd)
        if False:
            pass  # elif chain follows

        # handle assignment command
        elif cmd.replace('.', '').isalnum():
            # step 1: resolve macros
            subcmds = []
            for subcmd in cmd.split('.'):
                subcmd = subcmd
                if subcmd in self.macros:
                    subcmds.extend(self.macros[subcmd])
                else:
                    subcmds.append(subcmd)
            # step 2: resolve output assignments
            assign = {}
            for subcmd in subcmds:
                if len(subcmd) < 2:
                    print("warning: ignoring incomplete subcommand '{}'".format(subcmd))
                    continue
                subcmd = [int(c, 36) for c in subcmd]
                for out in subcmd[1:]:
                    assign[out] = subcmd[0]
            assign = [(i,o) for o,i in assign.items()]
            # step 3: send command
            if self.conn and assign:
                if len(assign) > 1:
                    self.conn.send(self.conn.proto.switch_multi(assign))
                else:
                    self.conn.send(self.conn.proto.switch_single(*assign[0]))

        # handle "store macro" command, e.g. *1*34,56
        elif (len(cmd) > 2) \
        and (cmd[0] == '*') \
        and cmd[1].isalnum() \
        and (cmd[2] == '*') \
        and ((len(cmd) <= 3) or cmd[3:].replace('.', '').isalnum()):
            name = cmd[1]
            value = cmd[3:].split('.')
            if value and value[0]:
                self.macros[name] = value
                if verbose: print("stored macro '{}':".format(name), ','.join(value))
            elif name in self.macros:
                del self.macros[name]
                if verbose: print("deleted macro '{}'".format(name))
            else:
                if verbose: print("macro '{}' is not defined".format(name))
            self.save_config()

        # handle "set connection" command, e.g. //192.168.1.2.10001 or //0.9600.801
        elif cmd.startswith('//') \
        and ((len(cmd) < 3) or cmd[2:].replace('.', '').isdigit()):
            params = cmd[2:].split('.')
            if params and params[0]:
                params = list(map(int, params))
            else:
                params = []
            if params:
                self.connection_config = params
                self.save_config()
                if self.conn:
                    self.conn.disconnect()
                self.conn = None
                for c in Connections:
                    try:
                        self.conn = c(*params)
                    except UnsuitableConnectionParameters:
                        pass
                need_help = not(self.conn)
                if self.conn:
                    res = self.conn.connect()
                    if res:
                        print("! connection established")
                    else:
                        print("! connection failed")
            else:
                need_help = True
            if need_help:
                print("connection types:")
                for c in Connections:
                    print("  - //proto," + c.__doc__)
                print("protocols:")
                for k in sorted(Protocols):
                    print("  -", k, "-", Protocols[k].__doc__)

        # invalid command
        else:
            print("invalid command", repr(cmd))

    def interactive(self):
        print("----- entering interactive command mode -----")
        print("""
Quick tutorial:
  - 12           = tie input 1 to output 2
  - 345          = tie input 3 to outputs 4 and 5
  - 12,345       = do both above commands at once
  - *7*12,345    = store these commands as macro '7'
  - 7            = recall macro '7'
  - //           = show help about connect command
  - //2,10.0.1.2 = connect to Extron switch at IP 10.0.1.2 (default port)
Hints:
  - dots ('.') and commas (',') can be used interchangeably, even in IP addrs.
  - config file is saved after every "store macro" and "connect" command
        """.strip())
        while True:
            try:
                self.handle_cmd(input("> "))
            except (IOError, EOFError, KeyboardInterrupt) as e:
                print(type(e).__name__)
                print("----- leaving interactive command mode -----")
                return

###############################################################################

if __name__ == "__main__":
    ctl = DVIMatrixController()
    ctl.load_config()
    ctl.interactive()
