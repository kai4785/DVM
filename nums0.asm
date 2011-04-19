        SUB     R0,     R0
        ADI     R0,     0
        SUB     R1,     R1
        ADI     R1,     0
WHILE1  BRZ     R1,     ENDWH1
        ADI     R1,     -1
        TRP     1
        JMP     WHILE1
ENDWH1  SUB     R0,     R0
        ADI     R0,     10
        TRP     3
        TRP     0
