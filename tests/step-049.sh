#!/bin/sh
# Test:
#   Do not reenable automatic update checks in non-interactive mode

git config --global githooks.autoupdate.enabled N || exit 1
sh /var/lib/githooks/install.sh --non-interactive || exit 1

if [ "$(git config --global --get githooks.autoupdate.enabled)" != "N" ]; then
    echo "! Automatic update checks were unexpectedly enabled"
    exit 1
fi
