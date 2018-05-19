set echo 1
load nums3.hex > race.txt
load nums2.hex > race.txt
load nums1.hex > race.txt
runall
ls
cat race.txt
rm race.txt
exit
