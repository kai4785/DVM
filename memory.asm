    SUB     R7,     R7      ;

    ADI     R7,     100     ;
    TRP     7,      R7      ;
    MOV     R1,     R0      ;
    TRP     9

    ADI     R7,     1000    ;
    TRP     7,      R7      ;
    MOV     R2,     R0      ;
    TRP     9

    ADI     R7,     1000    ;
    TRP     7,      R7      ;
    MOV     R3,     R0      ;
    TRP     9

    ADI     R7,     10000   ;
    TRP     7,      R7      ;
    MOV     R4,     R0      ;
    TRP     9

    TRP     8,      R2      ;
    TRP     9
    TRP     8,      R3      ;
    TRP     9
    TRP     8,      R1      ;
    TRP     9



    TRP     0;
