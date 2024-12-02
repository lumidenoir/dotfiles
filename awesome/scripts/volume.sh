#!/bin/sh

mute=$(pamixer --get-mute)
vol=$(pamixer --get-volume)
if $mute;
then
    echo "M"
else
    echo $vol
fi