set echo 1
sched FirstComeFirstServe
load proj1.hex
load proj2.hex
load proj3.hex < proj3.test
load --vm_threads 10 proj4.hex < proj4.test
ps
mem
runall
metrics
exit
