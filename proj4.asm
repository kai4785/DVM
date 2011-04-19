PROVFL  .BYT    'O' ;0
        .BYT    'v'
        .BYT    'e'
        .BYT    'r'
        .BYT    'f'
        .BYT    'l' ;5
        .BYT    'o'
        .BYT    'w'
        .BYT    '!'
        .BYT    10  ;9
ARRSZ   .INT    30  ;Array size is 30
CNT     .INT    0   ;Count
ARRAY   .INT    0   ;ARRAY[0] ; 1250
        .INT    0
        .INT    0
        .INT    0
        .INT    0
        .INT    0   ;ARRAY[5]
        .INT    0
        .INT    0
        .INT    0
        .INT    0
        .INT    0   ;ARRAY[10]
        .INT    0
        .INT    0
        .INT    0
        .INT    0
        .INT    0   ;ARRAY[15]
        .INT    0
        .INT    0
        .INT    0
        .INT    0
        .INT    0   ;ARRAY[20]
        .INT    0
        .INT    0
        .INT    0
        .INT    0
        .INT    0   ;ARRAY[25]
        .INT    0
        .INT    0
        .INT    0
        .INT    0   ;ARRAY[29]
NL      .BYT    10  ;NL character
SPACE   .BYT    ' ' ;Space character
RUNNING .BYT    'T' ;0
        .BYT    'h'
        .BYT    'r'
        .BYT    'e'
        .BYT    'a'
        .BYT    'd' ;5
        .BYT    ' '
        .BYT    'c'
        .BYT    'o'
        .BYT    'u'
        .BYT    'n' ;10
        .BYT    't'
        .BYT    ':'
        .BYT    ' '
STRING  .BYT    'T' ;0
        .BYT    'h'
        .BYT    'r'
        .BYT    'e'
        .BYT    'a'
        .BYT    'd' ;5
        .BYT    ' '
        .BYT    'I'
        .BYT    'd'
        .BYT    ':'
        .BYT    ' ' ;10
DONE    .BYT    'D'
        .BYT    'o'
        .BYT    'n'
        .BYT    'e'
        .BYT    '!'
LCK     .INT    -1
ANDAG   .BYT    'A' ;0
        .BYT    'n'
        .BYT    'd'
        .BYT    ' '
        .BYT    'a'
        .BYT    'g' ;5
        .BYT    'a'
        .BYT    'i'
        .BYT    'n'
        .BYT    ' '
        .BYT    'w' ;10
        .BYT    'i'
        .BYT    't'
        .BYT    'h'
        .BYT    ' '
        .BYT    'S'
        .BYT    'T'
        .BYT    'D'
        .BYT    'O'
        .BYT    'U'
        .BYT    'T'
        .BYT    ' '
        .BYT    'l' ;15
        .BYT    'o'
        .BYT    'c'
        .BYT    'k'
        .BYT    'i'
        .BYT    'n' ;20
        .BYT    'g'
        .BYT    ':'
        .BYT    10

;Setup Activation record for MAIN, and jump
        MOV     R3,     FP      ;Save FP in R3, this will be the PFP
        ADI     SP,     -4      ;Adjust Stack Pointer for Return Address
        MOV     FP,     SP      ;Point at Current Activation Record     (FP = SP)       
        ADI     SP,     -4      ;Adjust Stack Pointer for PFP
        STR     R3,     SP      ;PFP to Top of Stack                    (PFP = FP)
        MOV     R4,     SP      ;Check for Stack Overflow
        CMP     R4,     SL      ;
        BLT     R4,     OVERFL  ;
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     32      ;Compute Return Address (always a fixed amount)
        STR     R1,     FP      ;Return Address to the Beginning of the Frame
        JMP     MAIN            ;Call Function MAIN
EOP     TRP     0
;END of MAIN Activation Record

;Stack Overflow function
;Exits the program
OVERFL  LDA     R3,     PROVFL  ;Print Overflow!
        SUB     R2,     R2      ;
        ADI     R2,     10
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     24      ;Compute Return Address (always a fixed amount)
        JMP     PRINTC      
        TRP     0

;Print Char Array Function
;R0 used for printing Chars
;R1 needs to be the return address
;R2 needs to be the count of characters
;R3 needs to be the location of the array
PRINTC  SUB     R0,     R0
WHILE1  BRZ     R2,     ENDWH1
        LDB     R0,     R3
        TRP     3
        ADI     R2,     -1
        ADI     R3,     1
        JMP     WHILE1
ENDWH1  JMR     R1

;Print Int Array Function
;R0 used for printing Chars
;R1 needs to be the return address
;R2 needs to be the count of characters
;R3 needs to be the location of the array
PRINTI  MOV     R4,     R3      ;R4 = &ARRAY
        SUB     R5,     R5      ;R5 = 0
        ADI     R5,     4       ;R5 = 4
        MUL     R5,     R2      ;R5 = 4 * Size of the array
        ADD     R4,     R5      ;R4 = &ARRAY[30] -- Out of Bounds. Done with R5
        ADI     R4,     -4      ;R4 = &ARRAY[29] -- Last element, yay
        SUB     R5,     R5      ;
        ADI     R5,     2       ;R5 = 2
        DIV     R2,     R5      ;R2 = size / 2
WHILE3  BRZ     R2,     ENDWH1
        LDR     R0,     R3
        TRP     1
        LDB     R0,     NL
        TRP     3
        LDR     R0,     R4
        TRP     1
        LDB     R0,     NL
        TRP     3

        ADI     R2,     -1
        ADI     R3,     4
        ADI     R4,     -4
        JMP     WHILE3
ENDWH3  JMR     R1
        



;Main Program
;;void main()
MAIN    SUB     R0,     R0
        ADI     SP,     -4      ;Move SP up to make room for local variable int i
        STR     R0,     SP      ;int i = 0
        ADI     SP,     -4      ;Move SP up to make room for local variable int x
        STR     R0,     SP      ;int x = 0
WHILE2  TRP     2               ;R0 = int n
        MOV     R1,     SP      ;&int x
        STR     R0,     R1      ;int x = value read in
        SUB     R2,     R2      ;R2 = 0
        CMP     R2,     R0      ;Compare R0 and R2
        BRZ     R2,     ENDWH2      
;Setup Activation record for FACT, and jump
        MOV     R3,     FP      ;Save FP in R3, this will be the PFP
        ADI     SP,     -4      ;Adjust Stack Pointer for Return Address
        MOV     FP,     SP      ;Point at Current Activation Record     (FP = SP)       
        ADI     SP,     -4      ;Adjust Stack Pointer for PFP
        STR     R3,     SP      ;PFP to Top of Stack                    (PFP = FP)
        ADI     SP,     -4      ;Make room for int n offset = -8
        STR     R0,     SP      ;Store int n on the stack
        MOV     R4,     SP      ;Check for Stack Overflow
        CMP     R4,     SL      ;
        BLT     R4,     OVERFL  ;
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     32      ;Compute Return Address (always a fixed amount)
        STR     R1,     FP      ;Return Address to the Beginning of the Frame
        JMP     FACT            ;Call Function FACT
;END of FACT Activation Record
        MOV     R1,     SP      ;R1 = &int x -- Get Stack Pointer currently at int x and should be 4 away from the retval of FACT
        LDR     R2,     R1      ;R2 = int x
        ADI     R1,     -4      ;R1 = &Return Value -- Adjust to be pointing at the Return Value (I'm expecting an INT)
        LDR     R3,     R1      ;R3 = Return Value
;Print out the return value
;        MOV     R0,     R2
;        TRP     1               ;Should be printing the return value of FACT
;        LDB     R0,     SPACE   ;
;        TRP     3
;        MOV     R0,     R3
;        TRP     1               ;Should be printing the return value of FACT
;        LDB     R0,     NL      ;
;        TRP     3
;Store int x and return value into ARRAY
;   Get ARRAY pointers
        LDA     R4,     ARRAY   ;R4 = &ARRAY
        LDA     R5,     ARRAY   ;R5 = &ARRAY
;   Adjust them for size of int i
        MOV     R1,     SP      ;
        ADI     R1,     4       ;R1 = &int i
        LDR     R6,     R1      ;R6 = int i
        ADD     R4,     R6      ;R4 = &ARRAY[i/4]
        ADI     R6,     4       ;R6 = int i + 4
        ADD     R5,     R6      ;R4 = &ARRAY[i/4 + 4]
        ADI     R6,     4       ;R6 = int i + 8
;;   Increment i
        STR     R6,     R1      ;int i = int i + 8 -- Done with R6
;;   Store values in the array
        STR     R2,     R4      ;ARRAY[i/4] = int x -- Done with R2, R4
        STR     R3,     R5      ;ARRAY[i/4 + 4] = Return Value -- Done with R3, R5
        JMP     WHILE2
ENDWH2  SUB     R0,     R0

;Print Int Array Function
;R0 used for printing Chars
;R1 needs to be the return address
;R2 needs to be the count of characters
;R3 needs to be the location of the array
        LDA     R3,     ARRAY   ;Print Array
        ;LDR     R2,     ARRSZ
        MOV     R1,     SP      ;
        ADI     R1,     4       ;R1 = &int i
        LDR     R2,     R1      ;R2 = int i
        SUB     R7,     R7      ;
        ADI     R7,     4       ;
        DIV     R2,     R7      ;R2 = position of last number inserted
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     24      ;Compute Return Address (always a fixed amount)
        JMP     PRINTI          ;Call Function MAIN
THREAD1 LDA     R3,     RUNNING ;Print RUNNING
        SUB     R2,     R2      ;Zero
        ADI     R2,     14      ;Number of chars to print
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     24      ;Compute Return Address (always a fixed amount)
        JMP     PRINTC          ;Call Function MAIN
        SUB     R2,     R2      ;R2 = 0
        ADI     R2,     10      ;R1 = 10 : Number of threads to run
        MOV     R0,     R2
        TRP     1
        LDB     R0,     NL
        TRP     3
WHILE4  BRZ     R2,     ENDWH4
        RUN     R7,     PSTR
        ADI     R2,     -1
        JMP     WHILE4
ENDWH4  SUB     R0,     R0
        BLK     0
PSTR    LDA     R3,     STRING  ;Print String
        SUB     R2,     R2      ;
        ADI     R2,     10
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     24      ;Compute Return Address (always a fixed amount)
        JMP     PRINTC          ;Call Function MAIN
        MOV     R0,     R7      ;
        TRP     1               ;Print ID
        LDB     R0,     NL
        TRP     3
        END     0
        LDA     R3,     DONE    ;Print DONE
        SUB     R2,     R2      ;
        ADI     R2,     5
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     24      ;Compute Return Address (always a fixed amount)
        JMP     PRINTC          ;Call Function MAIN
        LDB     R0,     NL
        TRP     3

        LDA     R3,     ANDAG   ;Print And again
        SUB     R2,     R2      ;
        ADI     R2,     31
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     24      ;Compute Return Address (always a fixed amount)
        JMP     PRINTC          ;Call Function MAIN

THREAD2 LDA     R3,     RUNNING ;Print RUNNING
        SUB     R2,     R2      ;Zero
        ADI     R2,     14      ;Number of chars to print
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     24      ;Compute Return Address (always a fixed amount)
        JMP     PRINTC          ;Call Function MAIN
        SUB     R2,     R2      ;R2 = 0
        ADI     R2,     10      ;R1 = 10 : Number of threads to run
        MOV     R0,     R2
        TRP     1
        LDB     R0,     NL
        TRP     3
WHILE5  BRZ     R2,     ENDWH5
        RUN     R7,     PSTR2
        ADI     R2,     -1
        JMP     WHILE5
ENDWH5  SUB     R0,     R0
        BLK     0
PSTR2   LDA     R3,     STRING  ;Print String
        LCK     0,      LCK
        SUB     R2,     R2      ;
        ADI     R2,     10
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     24      ;Compute Return Address (always a fixed amount)
        JMP     PRINTC          ;Call Function MAIN
        MOV     R0,     R7      ;
        TRP     1               ;Print ID
        LDB     R0,     NL
        TRP     3
        ULK     0,      LCK
        END     0
        LDA     R3,     DONE    ;Print DONE
        SUB     R2,     R2      ;
        ADI     R2,     5
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     24      ;Compute Return Address (always a fixed amount)
        JMP     PRINTC          ;Call Function MAIN
        LDB     R0,     NL
        TRP     3
;Return from MAIN
        MOV     SP,     FP
        ADI     SP,     4       ;De-allocate FP
        LDR     R4,     FP      ;Keep a copy of FP to jump to
        MOV     R6,     FP      ;Grab another copy of FP
        ADI     R6,     -4      ;Move the pointer to PFP
        LDR     FP,     R6      ;Store PFP in FP
        JMR     R4              ;Return
;END of MAIN


;int fact(int n) {
FACT    SUB     R0,     R0
;       if (n == 0)
        MOV     R1,     FP      ;Get FP
        ADI     R1,     -8      ;Address of int n
        LDR     R2,     R1      ;R[2] = n
        SUB     R3,     R3      ;R[3] = 0
        CMP     R3,     R2
        BRZ     R3,     IF1
        JMP     ELSE1
IF1     SUB     R1,     R1
;       return 1;
        SUB     R7,     R7      ;R[7] = 1
        ADI     R7,     1       ;
;Return from FACT
        MOV     SP,     FP
        ADI     SP,     4       ;De-allocate FP
        LDR     R4,     FP      ;Keep a copy of FP to jump to
        MOV     R6,     FP      ;Grab another copy of FP
        ADI     R6,     -4      ;Move the pointer to PFP
        STR     R7,     FP      ;Store Return value
        LDR     FP,     R6      ;Store PFP in FP
        JMR     R4              ;Return
        JMP     ENDIF1      ;
;       else
ELSE1   MOV     R5,     R2      ;copy of int n
        ADI     R5,     -1      ;R[5] = int n - 1
;Setup Activation record for FACT, and jump
        MOV     R3,     FP      ;Save FP in R3, this will be the PFP
        ADI     SP,     -4      ;Adjust Stack Pointer for Return Address
        MOV     FP,     SP      ;Point at Current Activation Record     (FP = SP)       
        ADI     SP,     -4      ;Adjust Stack Pointer for PFP
        STR     R3,     SP      ;PFP to Top of Stack                    (PFP = FP)
        ADI     SP,     -4      ;Make room for int n offset = -8
        STR     R5,     SP      ;Store int n - 1 on the stack
        MOV     R4,     SP      ;Check for Stack Overflow
        CMP     R4,     SL      ;
        BLT     R4,     OVERFL      ;
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     32      ;Compute Return Address (always a fixed amount)
        STR     R1,     FP      ;Return Address to the Beginning of the Frame
        JMP     FACT            ;Call Function FACT
;END of FACT Activation Record
;       return n * fact(n – 1);
        MOV     R3,     FP      ;Get Frame Pointer
        ADI     R3,     -8      ;Get int n
        LDR     R7,     R3      ;R[7] = n
        MOV     R3,     SP      ;Get Stack Pointer, should be 4 away from the retval of FACT
        ADI     R3,     -4      ;Adjust to be pointing at the Return Value (I'm expecting an INT)
        LDR     R2,     R3      ;R[2] = return value of FACT
        MUL     R7,     R2      ;R[7] *= R[2] (n)
;}
ENDIF1  SUB     R5,     R5      ;Place holder, NULLop
;Ensure that R7 contains the return value
;Return from FACT
        MOV     SP,     FP
        ADI     SP,     4       ;De-allocate FP
        LDR     R4,     FP      ;Keep a copy of FP to jump to
        MOV     R6,     FP      ;Grab another copy of FP
        ADI     R6,     -4      ;Move the pointer to PFP
        STR     R7,     FP      ;Store Return value
        LDR     FP,     R6      ;Store PFP in FP
        JMR     R4              ;Return
;END of FACT
