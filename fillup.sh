#!/bin/bash
set -e

mkdir -p fillup
for num in `seq 1 20`; do
    dd if=/dev/zero of=fillup/fillup$num.zero bs=1K count=50 >/dev/null 2>&1
done
./fs --disk DISK --mkfs --size 1048576 && \
./fs --disk DISK --mkdir /fillup && \
for file in fillup/*.zero; do
    ./fs --disk DISK --copy $file --to $file
done
rm -fr fillup
rm -f DISK
