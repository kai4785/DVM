set echo 1
sched RoundRobin
load nums0.hex
load nums1.hex
load nums2.hex
load nums3.hex
load nums4.hex
load nums5.hex
load nums6.hex
load nums7.hex
load nums8.hex
load nums9.hex
runall
metrics

set echo 1
sched FirstComeFirstServe
load nums0.hex
load nums1.hex
load nums2.hex
load nums3.hex
load nums4.hex
load nums5.hex
load nums6.hex
load nums7.hex
load nums8.hex
load nums9.hex
runall
metrics

set echo 1
sched FirstComeFirstServe
load nums9.hex
load nums8.hex
load nums7.hex
load nums6.hex
load nums4.hex
load nums4.hex
load nums3.hex
load nums2.hex
load nums1.hex
load nums0.hex
runall
metrics

set echo 1
sched Priority
load nums0.hex
load nums1.hex
load nums2.hex
load nums3.hex
load nums4.hex
load nums5.hex
load nums6.hex
load nums7.hex
load nums8.hex
load nums9.hex
priority 0 0
priority 1 0
priority 2 1
priority 3 1
priority 4 2
priority 5 2
priority 6 3
priority 7 3
priority 8 3
priority 9 3
runall
metrics

exit
