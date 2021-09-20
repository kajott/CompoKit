#!/bin/bash

export LC_ALL="C"       # required for sort
export LC_MESSAGES="C"  # required for xrandr
me="$(basename "$0")"

# check mode parameter
Mode="$1"
if [ -z "$Mode" -o "$1" == "-h" -o "$1" == "--help" ] ; then
    echo "usage: $me MODE"
    echo "sets the specified MODE (1080p50 or 1080p60) to all currently connected"
    echo "displays, and sets them to mirror mode if not already done so"
    [ -z "$Mode" ] && exit 2
    exit 0
fi

# compile a list of display outputs, with HDMI being prioritized
Outputs="$(
    xrandr |  # get the mode list
    grep -Ei '^[a-z0-9_-]+ connected' |  # extract headers of connected outputs
    cut -d' ' -f1 |  # extract output names
    sed -r 's/^HDMI-/  \0/;s/^DP-/ \0/' |  # indent [=prioritize] HDMI
    sort  # apply prioritization
)"
if [ -z "$Outputs" ] ; then
    echo "$me: FATAL: no connected outputs reported by xrandr" >&2
    exit 1
fi
echo "$me: detected outputs:" $Outputs

# look up the modeline for the desired mode
case "$Mode" in
    1080p50) Modeline="148.5 1920 2448 2492 2640 1080 1084 1089 1125 +HSync +VSync" ;;
    1080p60) Modeline="148.5 1920 2008 2052 2200 1080 1084 1089 1125 +HSync +VSync" ;;
    *)
        echo "$me: FATAL: unsupported mode '$Mode'" >&2
        exit 2
        ;;
esac

# add the mode (this will fail if the mode already exists; that's fine)
xrandr --newmode $Mode $Modeline 2>/dev/null

# build the final commandline; add the mode for the affected outputs as we go
cmd="xrandr"
primary=""
for out in $Outputs ; do
    cmd="$cmd --output $out --mode $Mode"
    if [ -z "$primary" ] ; then
        cmd="$cmd --primary"
        primary="$out"
    else
        cmd="$cmd --same-as $primary"
    fi
    xrandr --addmode $out $Mode || exit 1
done
echo "$me: running '$cmd'"
exec $cmd
