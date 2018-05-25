#!/bin/bash
set -ex

mkdir -p fillup
for num in `seq 1 20`; do
    dd if=/dev/zero of=fillup/fillup$num.zero bs=512 count=60 >/dev/null 2>&1 &
done
wait
rm -f fillup.DISK
./fs --disk fillup.DISK --mkfs --size 1048576
./fs --disk fillup.DISK --mkdir /fillup
for file in fillup/*.zero; do
    ./fs --disk fillup.DISK --copy $file,/afile
done
rm -fr fillup
rm -f fillup.DISK
