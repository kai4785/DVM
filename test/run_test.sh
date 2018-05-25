#!/bin/bash

load1="${os_string}load proj1.hex\n"
load2="${os_string}load proj2.hex\n"
load3="${os_string}load proj3.hex\n"
load4="${os_string}load proj4.hex\n"
run4="${os_string}run proj4.hex\n"
run3="${os_string}run proj3.hex\n"
run2="${os_string}run proj2.hex\n"
run1="${os_string}run proj1.hex\n"
exit1="${os_string}exit\n"

[ ! -f nums0.asm  ] && bash write_nums.sh
for file in memory.asm  new_del.asm  nums0.asm  nums1.asm  nums2.asm  nums3.asm  nums4.asm  nums5.asm  nums6.asm  nums7.asm  nums8.asm  nums9.asm  proj1.asm  proj2.asm  proj3.asm  proj4.asm; do
    [ ! -f ${file/asm/hex}  ] && ./as $file ${file/asm/hex}
done

# echo "Program 1"           && \
# ./vm proj1.hex             && \
# echo "Program 2"           && \
# ./vm proj2.hex             && \
# echo "Program 3"           && \
# ./vm proj3.hex <proj3.test && \
# echo "Program 4"           && \
# ./vm proj4.hex --vm_threads 10 <proj4.test && \


compat () 
{
    function="compat"
    ( 
        echo -ne "set echo 1\n";
        echo -ne "sched FirstComeFirstServe\n";
        echo -ne "load proj1.hex\n";
        echo -ne "mem\n";
        echo -ne "run 0\n";
        echo -ne "load proj2.hex\n";
        echo -ne "mem\n";
        echo -ne "run 0\n";
        echo -ne "load proj3.hex < proj3.test\n";
        echo -ne "mem\n";
        echo -ne "run 0\n";
        echo -ne "load --vm_threads 10 proj4.hex < proj4.test\n";
        echo -ne "mem\n";
        echo -ne "run 0\n";
        echo -ne "metrics\n";
        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
}

compat_runall () 
{
    function="compat_runall"
    ( 
        echo -ne "set echo 1\n";
        echo -ne "sched FirstComeFirstServe\n";
        echo -ne "load proj1.hex\n";
        echo -ne "load proj2.hex\n";
        echo -ne "load proj3.hex < proj3.test\n";
        echo -ne "load --vm_threads 10 proj4.hex < proj4.test\n";
        echo -ne "ps\n";
        echo -ne "mem\n";
        echo -ne "runall\n";
        echo -ne "metrics\n";
        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
}

memory () 
{
    function="memory"
    ( 
        echo -ne "set echo 1\n";
        echo -ne "load memory.hex\n";
        echo -ne "mem\n";

        echo -ne "ps\n";
        echo -ne "mem 0\n";
        echo -ne "run 0\n";

        echo -ne "ps\n";
        echo -ne "mem 0\n";
        echo -ne "run 0\n";

        echo -ne "ps\n";
        echo -ne "mem 0\n";
        echo -ne "run 0\n";

        echo -ne "ps\n";
        echo -ne "mem 0\n";
        echo -ne "run 0\n";

        echo -ne "ps\n";
        echo -ne "mem 0\n";
        echo -ne "run 0\n";

        echo -ne "ps\n";
        echo -ne "mem 0\n";
        echo -ne "run 0\n";

        echo -ne "ps\n";
        echo -ne "mem 0\n";
        echo -ne "run 0\n";

        echo -ne "ps\n";
        echo -ne "mem 0\n";
        echo -ne "metrics\n";
        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
}
runall ()
{
    function="runall"
    ( 
        echo -ne "set echo 1\n";
        echo -ne "sched Priority\n";
        echo -ne "load nums0.hex\n";
        echo -ne "load nums1.hex\n";
        echo -ne "load nums2.hex\n";
        echo -ne "load nums3.hex\n";
        echo -ne "load nums4.hex\n";
        echo -ne "load nums5.hex\n";
        echo -ne "load nums6.hex\n";
        echo -ne "load nums7.hex\n";
        echo -ne "load nums8.hex\n";
        echo -ne "load nums9.hex\n";
        echo -ne "ps\n";
        echo -ne "priority 0 0\n";
        echo -ne "priority 1 0\n";
        echo -ne "priority 2 1\n";
        echo -ne "priority 3 1\n";
        echo -ne "priority 4 2\n";
        echo -ne "priority 5 2\n";
        echo -ne "priority 6 3\n";
        echo -ne "priority 7 3\n";
        echo -ne "priority 8 4\n";
        echo -ne "priority 9 4\n";
        echo -ne "ps\n";
        echo -ne "runall\n";
        echo -ne "ps\n";
        echo -ne "help sched\n";
        echo -ne "sched RoundRobin\n";
        echo -ne "load nums0.hex\n";
        echo -ne "load nums1.hex\n";
        echo -ne "load nums2.hex\n";
        echo -ne "load nums3.hex\n";
        echo -ne "load nums4.hex\n";
        echo -ne "load nums5.hex\n";
        echo -ne "load nums6.hex\n";
        echo -ne "load nums7.hex\n";
        echo -ne "load nums8.hex\n";
        echo -ne "load nums9.hex\n";
        echo -ne "runall\n";
        echo -ne "ps\n";
        echo -ne "sched FirstComeFirstServe\n";
        echo -ne "load nums0.hex\n";
        echo -ne "load nums1.hex\n";
        echo -ne "load nums2.hex\n";
        echo -ne "load nums3.hex\n";
        echo -ne "load nums4.hex\n";
        echo -ne "load nums5.hex\n";
        echo -ne "load nums6.hex\n";
        echo -ne "load nums7.hex\n";
        echo -ne "load nums8.hex\n";
        echo -ne "load nums9.hex\n";
        echo -ne "runall\n";
        echo -ne "metrics\n";
        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
}

metrics() 
{
    function="metrics"
    (
        echo -ne "set echo 1\n";
        echo -ne "sched RoundRobin\n";
        echo -ne "load nums0.hex\n";
        echo -ne "load nums1.hex\n";
        echo -ne "load nums2.hex\n";
        echo -ne "load nums3.hex\n";
        echo -ne "load nums4.hex\n";
        echo -ne "load nums5.hex\n";
        echo -ne "load nums6.hex\n";
        echo -ne "load nums7.hex\n";
        echo -ne "load nums8.hex\n";
        echo -ne "load nums9.hex\n";
        echo -ne "runall\n";
        echo -ne "metrics\n";

        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?

    (
        echo -ne "set echo 1\n";
        echo -ne "sched FirstComeFirstServe\n";
        echo -ne "load nums0.hex\n";
        echo -ne "load nums1.hex\n";
        echo -ne "load nums2.hex\n";
        echo -ne "load nums3.hex\n";
        echo -ne "load nums4.hex\n";
        echo -ne "load nums5.hex\n";
        echo -ne "load nums6.hex\n";
        echo -ne "load nums7.hex\n";
        echo -ne "load nums8.hex\n";
        echo -ne "load nums9.hex\n";
        echo -ne "runall\n";
        echo -ne "metrics\n";

        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?

    (
        echo -ne "set echo 1\n";
        echo -ne "sched FirstComeFirstServe\n";
        echo -ne "load nums9.hex\n";
        echo -ne "load nums8.hex\n";
        echo -ne "load nums7.hex\n";
        echo -ne "load nums6.hex\n";
        echo -ne "load nums4.hex\n";
        echo -ne "load nums4.hex\n";
        echo -ne "load nums3.hex\n";
        echo -ne "load nums2.hex\n";
        echo -ne "load nums1.hex\n";
        echo -ne "load nums0.hex\n";
        echo -ne "runall\n";
        echo -ne "metrics\n";

        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?

    (
        echo -ne "set echo 1\n";
        echo -ne "sched Priority\n";
        echo -ne "load nums0.hex\n";
        echo -ne "load nums1.hex\n";
        echo -ne "load nums2.hex\n";
        echo -ne "load nums3.hex\n";
        echo -ne "load nums4.hex\n";
        echo -ne "load nums5.hex\n";
        echo -ne "load nums6.hex\n";
        echo -ne "load nums7.hex\n";
        echo -ne "load nums8.hex\n";
        echo -ne "load nums9.hex\n";
        echo -ne "priority 0 0\n";
        echo -ne "priority 1 0\n";
        echo -ne "priority 2 1\n";
        echo -ne "priority 3 1\n";
        echo -ne "priority 4 2\n";
        echo -ne "priority 5 2\n";
        echo -ne "priority 6 3\n";
        echo -ne "priority 7 3\n";
        echo -ne "priority 8 3\n";
        echo -ne "priority 9 3\n";
        echo -ne "runall\n";
        echo -ne "metrics\n";

        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
}

io ()
{
    function="io"
    (
        echo -ne "set echo 1\n";
        echo -ne "sched RoundRobin\n";
        echo -ne "mkdir run\n";
        #echo -ne "load proj3.hex < proj3.test\n";
        echo -ne "load nums1.hex > run/nums1.txt\n";
        echo -ne "load nums2.hex > `pwd`/run/nums2.txt\n";
        echo -ne "load nums1.hex > run/nums1.txt\n";
        echo -ne "load nums2.hex > `pwd`/run/nums2.txt\n";
        echo -ne "load nums3.hex > run/nums3.txt\n";
        echo -ne "load nums4.hex > `pwd`/run/nums4.txt\n";
        echo -ne "load nums5.hex > run/nums5.txt\n";
        echo -ne "load nums6.hex > `pwd`/run/nums6.txt\n";
        echo -ne "load nums7.hex > run/nums7.txt\n";
        echo -ne "load nums8.hex > `pwd`/run/nums8.txt\n";
        echo -ne "ps\n";
        echo -ne "runall\n";
        echo -ne "metrics\n";
        echo -ne "ls run\n";
        echo -ne "ls `pwd`/run/\n";
        echo -ne "cat `pwd`/run/nums1.txt\n";
        echo -ne "cat run/nums2.txt\n";
        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
}

io_race()
{
    function="io_race"
    (
        echo -ne "set echo 1\n";
        echo -ne "load nums3.hex > race.txt\n";
        echo -ne "load nums2.hex > race.txt\n";
        echo -ne "load nums1.hex > race.txt\n";
        echo -ne "runall\n";
        echo -ne "ls\n";
        echo -ne "cat race.txt\n";
        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
}

disk () 
{
    function="disk"
    ./fs --mkfs --size 1048576 --disk DISK.test && \
    ls -lh DISK.test && \
    ./fs --disk DISK.test --ll "/" && \
    ./fs --disk DISK.test --mkdir "/home" && \
    ./fs --disk DISK.test --mkdir "/home/kai" && \
    ./fs --disk DISK.test --touch "/home/kai/file1.txt" && \
    ./fs --disk DISK.test --touch "/home/kai/file2.txt" && \
    ./fs --disk DISK.test --touch "/home/kai/file3.txt" && \
    ./fs --disk DISK.test --ll "/" && \
    ./fs --disk DISK.test --ll "/home" && \
    ./fs --disk DISK.test --ll "/home/kai" && \
    ./fs --disk DISK.test --copy nums1.hex --to /home/kai/nums1.hex && \
    ./fs --disk DISK.test --copy nums1.hex --to /nums1.hex && \
    ./fs --disk DISK.test --ll "/home/kai" && \
    rm -f DISK.test
    result $function $?
}

copy_files () 
{
    function="copy_files"
    rm -f DISK && \
    ./fs --disk DISK --mkfs --size 1048576 && \
    ./fs --disk DISK --mkdir /home && \
    ./fs --disk DISK --mkdir /home/kai && \
    ./fs --disk DISK --mkdir /home/kai/school && \
    ./fs --disk DISK --mkdir /home/kai/school/VM && \
    ./fs --disk DISK --mkdir /home/kai/school/VM/du_test && \
    for file in *.hex *.test du_test/*.zero; do
        ./fs --disk DISK --copy $file --to /home/kai/school/VM/$file
        if [ $? != 0 ]; then
            return $?
        fi
    done 
    ./fs --disk DISK --ll "/home/kai" && \
    ./fs --disk DISK --ll "/home"
    result $function $?
}

fillup () 
{
    function="fillup"
    mkdir fillup
    for num in `seq 1 20`; do
        dd if=/dev/zero of=fillup/fillup$num.zero bs=1K count=50 >/dev/null 2>&1
    done
    ./fs --disk DISK --mkdir /home/kai/school/VM/fillup && \
    for file in fillup/*.zero; do
        ./fs --disk DISK --copy $file --to /home/kai/school/VM/$file
        if [ $? != 0 ]; then
            return $?
        fi
    done 
    rm -fr fillup
    result $function $?
}

file_size () 
{
    function="file_size"
    mkdir file_size
    for num in `seq 1 5`; do
        dd if=/dev/zero of=file_size/file_size$num.zero bs=1K count=62
    done
    ./fs --disk DISK --mkdir /home/kai/school/VM/file_size && \
    for file in file_size/*.zero; do
        ./fs --disk DISK --copy $file --to /home/kai/school/VM/$file
        if [ $? != 0 ]; then
            return $?
        fi
    done 
    rm -fr file_size
    result $function $?
}

du_test ()
{
    function="du_test"
    (
        echo -ne "set echo 1\n";
        echo -ne "ls du_test\n";
        echo -ne "du du_test\n";
        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
}

rm_test ()
{
    function="rm_test"
    (
        echo -ne "set echo 1\n";
        echo -ne "touch file.txt\n";
        echo -ne "ls file.txt\n";
        echo -ne "df\n";
        echo -ne "rm file.txt\n";
        echo -ne "ls file.txt\n";
        echo -ne "df\n";
        echo -ne "rm du_test/896.zero\n";
        echo -ne "df\n";
        echo -ne "ls du_test\n";
        echo -ne "rm du_test/\n";
        echo -ne "mkdir rm_test\n";
        echo -ne "ls rm_test\n";
        echo -ne "rm rm_test/\n";
        echo -ne "ls rm_test\n";
        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
}

ln_test ()
{
    function="ln_test"
    (
        echo -ne "set echo 1\n";
        echo -ne "mkdir link\n";
        echo -ne "load nums1.hex > link/nums.txt\n";
        echo -ne "runall\n";
        echo -ne "cat link/nums.txt\n";
        echo -ne "ln link/nums.txt link/link.txt\n";
        echo -ne "load nums2.hex >> link/nums.txt\n";
        echo -ne "runall\n";
        echo -ne "cat link/nums.txt\n";
        echo -ne "cat link/link.txt\n";
        echo -ne "load nums3.hex >> link/nums.txt\n";
        echo -ne "runall\n";
        echo -ne "cat link/nums.txt\n";
        echo -ne "cat link/link.txt\n";
        echo -ne "rm link/link.txt\n";
        echo -ne "cat link/nums.txt\n";
        echo -ne "rm link/nums.txt\n";
        echo -ne "rm link\n";
        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
}

cht ()
{
    function="cht"
    (
        echo -ne "set echo 1\n";
        echo -ne "cat head_tail.test\n";
        echo -ne "head head_tail.test\n";
        echo -ne "tail head_tail.test\n";
        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
}

mem_test()
{
    function="mem_test"
    (
        echo -ne "set echo 1\n";
        #echo -ne "load nums1.hex\n";
        #echo -ne "mem\n";
        #echo -ne "load nums1.hex\n";
        #echo -ne "mem\n";
        #echo -ne "load nums1.hex\n";
        #echo -ne "mem\n";
        #echo -ne "load nums1.hex\n";
        #echo -ne "mem\n";
        #echo -ne "load nums1.hex\n";
        #echo -ne "mem\n";
        #echo -ne "load nums1.hex\n";
        #echo -ne "mem\n";
        #echo -ne "load nums1.hex\n";
        #echo -ne "mem\n";
        #echo -ne "load nums1.hex\n";
        #echo -ne "mem\n";
        #echo -ne "load nums1.hex\n";
        #echo -ne "mem\n";
        #echo -ne "load nums1.hex\n";
        #echo -ne "mem\n";
        #echo -ne "load nums1.hex\n";
        #echo -ne "mem\n";
        #echo -ne "load nums1.hex\n";
        #echo -ne "mem\n";
        #echo -ne "load nums1.hex\n";
        #echo -ne "mem\n";
        echo -ne "load nums1.hex\n";
        echo -ne "mem\n";
        echo -ne "load nums1.hex\n";
        echo -ne "mem\n";
        echo -ne "load nums1.hex\n";
        echo -ne "mem\n";
        echo -ne "load nums1.hex\n";
        echo -ne "mem\n";
        echo -ne "load nums1.hex\n";
        echo -ne "mem\n";
        echo -ne "load nums1.hex\n";
        echo -ne "mem\n";
        echo -ne "load nums1.hex\n";
        echo -ne "mem\n";
        echo -ne "ps\n";
        echo -ne "runall\n";
        echo -ne "mem\n";
        echo -ne "metrics\n";
        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
}

all () 
{
    compat && \
    memory && \
    runall && \
    metrics && \
    io && \
    disk;
    result "all" $?
}

result()
{
    function=$1;
    retval=$2;
    if [ $retval == 0 ]; then
        echo -e "\033[1;32m$function Test Passed\033[0m"
        return 0;
    else
        echo -e "\033[1;31m$function Test Failed\033[0m"
        return 1;
    fi
}

file_system_test()
{
    function="file_system_test"
    (
        echo -ne "set echo 1\n";
        echo -ne "ls\n";
        echo -ne "mkdir create_dir\n";
        echo -ne "ls\n";
        echo -ne "cp head_tail.test create_dir/head_tail.copy\n";
        echo -ne "ln head_tail.test create_dir/head_tail.link\n";
        echo -ne "ls create_dir\n";
        echo -ne "rm head_tail.test\n";
        echo -ne "ls\n";
        echo -ne "cat create_dir/head_tail.link\n";
        echo -ne "tail create_dir/head_tail.link\n";
        echo -ne "cat create_dir/head_tail.copy\n";
        echo -ne "cp create_dir/head_tail.copy /home/kai/head_tail.copy1\n";
        echo -ne "ls /home/kai\n";
        echo -ne "cp /home/kai/head_tail.copy1 /head_tail.copy2\n";
        echo -ne "ls /\n";
        echo -ne "touch file.txt\n";
        echo -ne "ls\n";
        echo -ne "load proj9.hex >> file.txt\n";
        echo -ne "load proj9.hex >> file.txt\n";
        echo -ne "load proj9.hex >> file.txt\n";
        echo -ne "load proj9.hex >> file.txt\n";
        echo -ne "load proj9.hex >> file.txt\n";
        echo -ne "runall\n";
        echo -ne "ls\n";
        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
    fillup
    (
        echo -ne "set echo 1\n";
        echo -ne "df\n";
        echo -ne "rm /home/kai/school/VM/fillup/fillup7.zero\n";
        echo -ne "rm /home/kai/school/VM/fillup/fillup8.zero\n";
        echo -ne "rm /home/kai/school/VM/fillup/fillup9.zero\n";
        echo -ne "df\n";
        echo -ne "load proj9.hex >> fillup/proj9.txt\n";
        echo -ne "runall\n";
        echo -ne "ls fillup\n";
        echo -ne "mkdir del_me\n";
        echo -ne "touch del_me/delme.txt\n";
        echo -ne "rm del_me\n";
        echo -ne "rm del_me/delme.txt\n";
        echo -ne "rm del_me\n";
        echo -ne "exit\n";
    ) | ./os && \
    echo
    result $function $?
}

compile () 
{
    function="compile"
    make debug && \
    ./cm $2.kxi $2.asm && \
    ./as $2.asm $2.hex && \
    printf "set echo 1\nload $2.hex < $2.test\nrun 0\nexit\n" | \
    ./os 
    result $function $?
    echo $2
}

virtualmemory () 
{
    function="virtualmemory"
    printf "set echo 1
    load nums1.hex
    load nums1.hex
    load nums1.hex
    load nums2.hex
    load nums3.hex
    load nums4.hex
    mem
    runall
    mem
    exit\n" | \
    ./os 
    result $function $?
    echo $2
}

touch DISK
[[ $1 == "all" ]] || [[ -z "$1" ]] && all
[[ $1 == "compat" ]] && compat
[[ $1 == "compat_runall" ]] && compat_runall
[[ $1 == "memory" ]] && memory
[[ $1 == "runall" ]] && runall
[[ $1 == "metrics" ]] && metrics
[[ $1 == "io" ]] && io
[[ $1 == "io_race" ]] && io_race
[[ $1 == "disk" ]] && disk
[[ $1 == "copy_files" ]] && copy_files
[[ $1 == "du_test" ]] && du_test
[[ $1 == "rm_test" ]] && rm_test
[[ $1 == "ln_test" ]] && ln_test
[[ $1 == "cht" ]] && cht
[[ $1 == "fillup" ]] && fillup
[[ $1 == "file_size" ]] && file_size
[[ $1 == "file_system_test" ]] && file_system_test
[[ $1 == "compile" ]] && compile $@
[[ $1 == "virtualmemory" ]] && virtualmemory $@

exit 0;
