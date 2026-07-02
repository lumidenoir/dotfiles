#!/bin/bash
# Sync emails and index them with mu

# Run mbsync for all accounts
if /usr/bin/mbsync -a; then
    echo "Mail sync completed successfully."
else
    echo "Mail sync encountered issues."
fi

# Index with mu
/usr/bin/mu index
