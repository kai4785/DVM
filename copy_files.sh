#!/bin/bash
set -e

source_dir=$(dirname $(readlink -f $0))
du_test_dir=${source_dir}/du_test

mkdir_p()
{
    if [ "$1" != "/" ]; then
        mkdir_p $(dirname $1)
        ./fs --disk DISK --mkdir $1
    fi
}

rm -f DISK
./fs --disk DISK --mkfs --size 1048576
mkdir_p ${du_test_dir}
for file in ${source_dir}/*.test ${du_test_dir}/*.zero; do
    ./fs --disk DISK --copy $file,$file
done
./fs --disk DISK --ll "${source_dir}"
./fs --disk DISK --ll "${du_test_dir}"
rm -f DISK
