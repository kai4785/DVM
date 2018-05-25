#!/bin/bash
set -e
fs=$1

du_test_dir=$(pwd)/du_test
mkdir -p ${du_test_dir}
for size in $(seq 0 128 1024); do
    dd if=/dev/zero of=${du_test_dir}/$size.zero bs=1 count=0 >/dev/null 2>&1 &
done
wait

mkdir_p()
{
    if [ "$1" != "/" ]; then
        mkdir_p $(dirname $1)
        ${fs} --disk DISK --mkdir $1
    fi
}

rm -f DISK
${fs} --disk DISK --mkfs --size 1048576
mkdir_p ${du_test_dir}
for file in ${du_test_dir}/*.zero; do
    ${fs} --disk DISK --copy $file,$file
done
${fs} --disk DISK --ll "${du_test_dir}"
rm -f DISK
