#!/bin/sh
# Test:
#   Run an install including the intro README files for one repo

mkdir -p /tmp/test044/001 && cd /tmp/test044/001 && git init || exit 1
mkdir -p /tmp/test044/002 && cd /tmp/test044/002 && git init || exit 1

cd /tmp/test044 || exit 1

echo "n
y
/tmp/test044
n
y
" | sh /var/lib/githooks/install.sh || exit 1

find /tmp/test044

if ! grep "github.com/rycus86/githooks" /tmp/test044/001/.git/hooks/pre-commit; then
    echo "! Hooks were not installed into 001"
    exit 1
fi

if grep "github.com/rycus86/githooks" /tmp/test044/001/.githooks/README.md; then
    echo "! README was unexpectedly installed into 001"
    exit 1
fi

if ! grep "github.com/rycus86/githooks" /tmp/test044/002/.git/hooks/pre-commit; then
    echo "! Hooks were not installed into 002"
    exit 1
fi

if ! grep "github.com/rycus86/githooks" /tmp/test044/002/.githooks/README.md; then
    echo "! README was not installed into 002"
    exit 1
fi
