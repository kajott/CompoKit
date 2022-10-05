# DVI Matrix Controller Script

`dvi_matrix_control.py` is a simple command-line based controller program for DVI/HDMI crossbar switches, with limited macro support, written in Python.

Supported matrix models / protocols:
- Lightware MX series (LW1 protocol) *(untested)*
- Extron DXP series (SIS protocol) *(tested with [DXP 88 DVI Pro](https://www.extron.com/product/dxpdvipro) and [DXP 88 HDMI](https://www.extron.com/product/dxphdmi))*

Connections to the matrices can be established via TCP/IP *(tested)* or serial port *(untested, requires [PySerial](https://pythonhosted.org/pyserial/) package)*.

The user interface is very minimalistic; it has been designed to work with only a simple numeric keypad attached to a Raspberry Pi or BeagleBone.


## Usage

Download `dvi_matrix_control.py` and run it with any recent version of Python (2.7, 3.5 or later) on any supported operating system. It will show a brief on-screen help and enter "interactive command mode".

Commands are entered on a line, followed by the Return key. To quit the program, press Ctrl+C or (on Unix-like systems) Ctrl+D.

### Connecting to a matrix

First, the connection to the matrix should be set up. Type the command "`//`" (without the quotes) to get a quick help about the connect command. For example, to connect to an Extron switch at IP address 10.0.2.12, the following command can be used:

    //2,10.0.2.12,23

The `2` is the protocol ID (2 = Extron), followed by the IP address, followed by the port number. Since 23 is the default port for the Extron protocol, it can also be omitted.

Furthermore, the parser doesn't discern between dots (`.`) and commas (`,`), so the following are synonymous with the command written above:

    //2,10,0,2,12
    //2.10.0.2.12

In other words: Whatever the key next to the zero on the numeric keypad produces in the configured locale, it'll do.

When the connection was successful, a message is printed on the console. If the connection gets interrupted later on, it will automatically be re-established as soon as the next command is to be sent to the matrix.

### Switching outputs

To connect an input (say, Input 4) to an output (say, Output 7), just type the input and output number, followed by Return:

    47

An input can be connected ("tied") to multiple outputs at once by writing more than one output number, for example:

    4387

This ties input 4 to outputs 3, 8 and 7 at once.

Multiple independent ties can be specified on the same line by separating them with a comma or dot. For example, to tie input 3 to output 4 and input 4 to output 3:

    34,43

When using switches with more than 9 inputs or outputs, the additional ports are accessible by using letters `a`-`z` (case-insensitive). Port 10 is `a`, port 11 is `b`, and so on.

### Using macros

To store frequently used ties as a macro, the following syntax can be used:

    *1*1238

This is a star (`*`), followed by the name of the macro, which must be a single alphanumeric character (`0`-`9`, `a`-`z`), followed by another star, and finally the tie command that shall be stored. Multiple commands are possible too:

    *0*15,26,37

After the macro has been stored, it can be recalled by simply using the macro name as a command, i.e. just typing

    1

in the example above will tie input 1 to outputs 2, 3 and 8.

### Saving settings

Whenever a connect or "store macro" command is executed, the configuration file `dvi_matrix_control.conf` is re-written with the new connection and macro settings. This file is also automatically reloaded every time the program starts up. Together, this means that quitting and restarting the program doesn't lose any configuration and macro information.


## EDID Control

There's also a second script, `extron_set_edit.py`, that can be used to configure EDID information on Extron switches specifically. The script generally sets the same EDID for all inputs, i.e. it acts as some kind of a global switch for the desired video mode (if the sources respect the EDID information, that is).

EDIDs can either be chosen from a pre-defined list, like this:

    ./extron_set_edid.py 1080p50

(Run `./extron_set_edid.py -h` to see the list of supported modes.)

Alternatively, a custom EDID file (a 256-byte binary file containing the raw EDID data) can be loaded into the matrix:

    ./extron_set_edid.py -f custom_edid.bin

In both cases, the IP address and port to connect to will be read from `dvi_matrix_control.conf` if that file exists and contains a connection line for an Extron switch ("`//2,`*`xxx`*").
