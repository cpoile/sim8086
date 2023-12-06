#!/usr/bin/env sh
set -o xtrace

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 listing_number"
    exit 1
fi

odin run main.odin -file -- $1 my${1}.asm
if [ $? -eq 1 ]; then
    exit 1
fi

nasm my${1}.asm
xxd $1 > ${1}.hex
xxd my${1} > my${1}.hex
diff ${1}.hex my${1}.hex
