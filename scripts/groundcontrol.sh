#!/bin/bash
if pgrep -x "quickshell" > /dev/null; then
    if quickshell -p "$HOME/dotfiles/quickshell" ipc call qsIpc toggleGroundControl 2>/dev/null; then
        exit 0
    elif quickshell ipc call qsIpc toggleGroundControl 2>/dev/null; then
        exit 0
    fi
fi
