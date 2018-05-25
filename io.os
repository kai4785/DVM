
set echo 1
sched RoundRobin
mkdir io_test
load nums1.hex > io_test/nums1.txt
load nums2.hex > io_test/nums2.txt
load nums1.hex > io_test/nums1.txt
load nums2.hex > io_test/nums2.txt
load nums3.hex > io_test/nums3.txt
load nums4.hex > io_test/nums4.txt
load nums5.hex > io_test/nums5.txt
load nums6.hex > io_test/nums6.txt
load nums7.hex > io_test/nums7.txt
load nums8.hex > io_test/nums8.txt
ps
runall
metrics
ls io_test
ls io_test/
cat io_test/nums1.txt
cat io_test/nums2.txt
rm io_test/nums1.txt
rm io_test/nums2.txt
rm io_test/nums3.txt
rm io_test/nums4.txt
rm io_test/nums5.txt
rm io_test/nums6.txt
rm io_test/nums7.txt
rm io_test/nums8.txt
rm io_test
exit
