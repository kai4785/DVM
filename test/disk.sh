#!/bin/bash
set -ex
fs=$1

rm -f DISK.test
${fs} --mkfs --size 1048576 --disk DISK.test
ls -lh DISK.test
${fs} --disk DISK.test --ll "/"
${fs} --disk DISK.test --mkdir "/home"
${fs} --disk DISK.test --mkdir "/home/kai"
${fs} --disk DISK.test --touch "/home/kai/file1.txt"
${fs} --disk DISK.test --touch "/home/kai/file2.txt"
${fs} --disk DISK.test --touch "/home/kai/file3.txt"
${fs} --disk DISK.test --ll "/"
${fs} --disk DISK.test --ll "/home"
${fs} --disk DISK.test --ll "/home/kai"
${fs} --disk DISK.test --copy nums1.hex,/home/kai/nums1.hex
${fs} --disk DISK.test --copy nums1.hex,/nums1.hex
${fs} --disk DISK.test --ll "/home/kai"
rm -f DISK.test
