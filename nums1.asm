        SUB     R0,     R0
        ADI     R0,     1
        SUB     R1,     R1
        ADI     R1,     100
WHILE1  BRZ     R1,     ENDWH1
        ADI     R1,     -1
        TRP     1
        MOV     R5,     SB
        ADI     R5,     -1
        LDB     R4,     R5
        ADI     R5,     -512
        LDB     R4,     R5
        ADI     R5,     -512
        LDB     R4,     R5
        JMP     WHILE1
ENDWH1  SUB     R0,     R0
        ADI     R0,     10
        TRP     3
        TRP     0
