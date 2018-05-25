set echo 1
sched FirstComeFirstServe
load proj1.hex
mem
run 0
load proj2.hex
mem
run 0
# TODO: proj3 and proj4 fail to execute
#load proj3.hex < proj3.test
#mem
#run 0
#load --vm_threads 10 proj4.hex < proj4.test
#mem
#run 0
metrics
exit
