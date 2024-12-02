#!/usr/bin/env sh

# customize these
WGET=/usr/bin/wget
ICS2ORG=/usr/bin/ical2org
ICSFILE=/home/krishna/basic.ics
ORGFILE=/home/krishna/org/calendar.org
URL=https://calendar.google.com/calendar/ical/viveksk21iitk%40gmail.com/public/basic.ics

# no customization needed below

$WGET -O $ICSFILE $URL
sudo $ICS2ORG < $ICSFILE > $ORGFILE
