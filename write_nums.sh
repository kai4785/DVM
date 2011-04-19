#!/bin/bash

for num in `seq 0 9`; do
cat <<_EOF > nums$num.asm
        SUB     R0,     R0
        ADI     R0,     $num
        SUB     R1,     R1
        ADI     R1,     `expr $num \* 100`
WHILE1  BRZ     R1,     ENDWH1
        ADI     R1,     -1
        TRP     1
        JMP     WHILE1
ENDWH1  SUB     R0,     R0
        ADI     R0,     10
        TRP     3
        TRP     0
_EOF
done;
