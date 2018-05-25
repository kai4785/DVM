;const int  SIZE = 7;
SIZE    .INT    7
;int  cnt;
cnt     .INT    0
;int  tenth;
tenth   .INT    0
;char c[7];
c       .INT    0
        .INT    0
        .INT    0
        .INT    0
        .INT    0
        .INT    0
        .INT    0
;int  data;
data    .INT    0
;int  flag;
flag    .INT    0
;int  opdv;
opdv    .INT    0
NL      .BYT    10      ;15
AT      .BYT    '@'
PLUS    .BYT    '+'
MINUS   .BYT    '-'

;Setup Activation record for Main, and jump
        MOV     R3,     FP      ;Save FP in R3, this will be the PFP
        ADI     SP,     -4      ;Adjust Stack Pointer for Return Address
        MOV     FP,     SP      ;Point at Current Activation Record     (FP = SP)
        ADI     SP,     -4      ;Adjust Stack Pointer for PFP
        STR     R3,     SP      ;PFP to Top of Stack                    (PFP = FP)
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     32      ;Compute Return Address (always a fixed amount)
        STR     R1,     FP      ;Return Address to the Beginning of the Frame
        JMP     MAIN            ;Call Function MAIN
        TRP     0
;END of MAIN Activation Record

;;void reset(int w, int x, int y, int z)
RESET   SUB     R0,     R0
        ADI     SP,     -4      ;Add room for 'int k' to the stack
        MOV     R1,     SP      ;Add 'int k' local variable
;;for (k= 0; k < SIZE; k++)
;;int k == R1
;;k = 0
        STR     R2,     R1      ;k = 0
;;k < SIZE
FOR1    LDR     R2,     R1      ;R2 = k
        LDR     R3,     SIZE    ;R3 = SIZE
        CMP     R3,     R2      ;R3 = SIZE - k
        BRZ     R3,     ENDFOR1 ;End of For loop if (SIZE - k) == 0
        BLT     R3,     ENDFOR1 ;End of For loop if (SIZE - k) > 0, might not need this one
        LDA     R3,     c       ;
        ADD     R3,     R2      ;c[k]
        SUB     R4,     R4      ;
        STR     R4,     R3      ;c[k] = 0
;;k++
        LDR     R2,     R1      ;
        ADI     R2,     1
        STR     R2,     R1
        JMP     FOR1            ;Back to top of for loop
ENDFOR1 SUB     R0,     R0      ;END OF FORLOOP
;; data = w;
        MOV     R1,     FP      ;Fetch Address of int w
        ADI     R1,     -8      ;
        LDR     R2,     R1      ;
        STR     R2,     data    ;Store w into data
;; opdv = x;
        MOV     R1,     FP      ;Fetch Address of int x
        ADI     R1,     -12     ;
        LDR     R2,     R1      ;
        STR     R2,     opdv    ;Store w into opdv
;; cnt  = y;
        MOV     R1,     FP      ;Fetch Address of int y
        ADI     R1,     -16     ;
        LDR     R2,     R1      ;
        STR     R2,     cnt     ;Store w into cnt
;; flag = z;
        MOV     R1,     FP      ;Fetch Address of int z
        ADI     R1,     -20     ;
        LDR     R2,     R1      ;
        STR     R2,     flag    ;Store w into flag
;Return from RESET
        MOV     SP,     FP
        ADI     SP,     4       ;De-allocate FP
        LDR     R4,     FP      ;Keep a copy of FP to jump to
        MOV     R6,     FP      ;Grab another copy of FP
        ADI     R6,     -4      ;Move the pointer to PFP
        LDR     FP,     R6      ;Store PFP in FP
        JMR     R4              ;Return
;END of RESET

;;void getdata()
GETDATA SUB     R0,     R0
;Return from GETDATA
;;  if (cnt < SIZE) { // Get data if there is room
        LDR     R1,     cnt     ;Get cnt
        LDR     R2,     SIZE    ;Get SIZE
;       MOV     R0,     R2
;       TRP     1
        CMP     R2,     R1      ;SIZE - cnt
        BGT     R2,     IF1
        JMP     ELSE1
;;    c[cnt] = getchar();
IF1     LDA     R2,     c       ;&c[0]
        ADD     R2,     R1      ;&c[cnt]
        TRP     4
        STB     R0,     R2      ;c[cnt] = getchar();
;;    cnt++;
        ADI     R1,     1       ;
        STR     R1,     cnt     ;
        JMP     ENDIF1
;;  } else {
;;    printf("Number too Big\n");
PRINTF1 .BYT    'N'     ;0
        .BYT    'u'
        .BYT    'm'
        .BYT    'b'
        .BYT    'e'
        .BYT    'r'     ;5
        .BYT    ' '
        .BYT    't'
        .BYT    'o'
        .BYT    'o'
        .BYT    ' '     ;10
        .BYT    'B'
        .BYT    'i'
        .BYT    'g'
ELSE1   LDA     R1,     PRINTF1 ;
        LDB     R0,     R1      ;N
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;u
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;m
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;b
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;e
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;r
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;' '
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;t
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;o
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;o
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;' '
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;B
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;i
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;g
        TRP     3
        LDB     R0,     NL      ;\n
        TRP     3
;;    flush();
;;  data = 0;
        SUB     R0,     R0
        STR     R0,     data
;;  c[0] = getchar();
        LDA     R1,     c
        TRP     4
        STR     R0,     R1
        SUB     R3,     R3      ;Setup R3 = \n
        ADI     R3,     10      ;Setup R3 = \n
;;  while (c[0] != '\n')
;Call Flush
WHILE2  LDB     R2,     R1
        CMP     R2,     R3
        BRZ     R2,     ENDWH2
;;    c[0] = getchar();
        LDA     R1,     c
        TRP     4
        STR     R0,     R1
        JMP     WHILE2
ENDWH2  SUB     R0,     R0
ENDFLSH SUB     R0,     R0
;;  }
ENDIF1  SUB     R0,     R0
        MOV     SP,     FP
        ADI     SP,     4       ;De-allocate FP
        LDR     R4,     FP      ;Keep a copy of FP to jump to
        MOV     R6,     FP      ;Grab another copy of FP
        ADI     R6,     -4      ;Move the pointer to PFP
        LDR     FP,     R6      ;Store PFP in FP
        JMR     R4              ;Return
;END of GETDATA

;opd Function definition
;;void opd(char s, int k, char j)
OPD     SUB     R0,     R0
;;  int t = 0;  // Local var
        SUB     R4,     R4      ;R[4] = 0 ; Used to ADI the appropriate amount to store in t
        SUB     R1,     R1      ;R[1] = 0
        ADI     SP,     -4      ;Allocate room for int t
        MOV     R2,     SP      ;R[2] = &t offset -14
        STR     R1,     R2      ;int 4 = 0 offset -14
;                               ; At this point, char s = FP-5
;                               ;                int k  = FP-9
;                               ;                char j = FP-10
;                               ;                int t  = FP-14
;;
        MOV     R1,     FP      ;
        ADI     R1,     -10     ;&j
        LDB     R3,     R1      ;R[3] = j
ZERO    .BYT    '0'             ;
ONE     .BYT    '1'             ;
TWO     .BYT    '2'             ;
THREE   .BYT    '3'             ;
FOUR    .BYT    '4'             ;
FIVE    .BYT    '5'             ;
SIX     .BYT    '6'             ;
SEVEN   .BYT    '7'             ;
EIGHT   .BYT    '8'             ;
NINE    .BYT    '9'             ;
;;  if (j == '0')      // Convert
        LDB     R1,     ZERO
        CMP     R1,     R3
        BNZ     R1,     ELIF1
;;    t = 0;
        ADI     R4,     0       ;
        STR     R4,     R2      ;
        JMP     ENDIF5          ;
;;  else if (j == '1')
ELIF1   LDB     R1,     ONE
        CMP     R1,     R3
        BNZ     R1,     ELIF2
;;    t = 1;
        ADI     R4,     1       ;
        STR     R4,     R2      ;
        JMP     ENDIF5          ;
;;  else if (j == '2')
ELIF2   LDB     R1,     TWO
        CMP     R1,     R3
        BNZ     R1,     ELIF3
;;    t = 2;
        ADI     R4,     2       ;
        STR     R4,     R2      ;
        JMP     ENDIF5          ;
;;  else if (j == '3')
ELIF3   LDB     R1,     THREE
        CMP     R1,     R3
        BNZ     R1,     ELIF4
;;    t = 3;
        ADI     R4,     3       ;
        STR     R4,     R2      ;
        JMP     ENDIF5          ;
;;  else if (j == '4')
ELIF4   LDB     R1,     FOUR
        CMP     R1,     R3
        BNZ     R1,     ELIF5
;;    t = 4;
        ADI     R4,     4       ;
        STR     R4,     R2      ;
        JMP     ENDIF5          ;
;;  else if (j == '5')
ELIF5   LDB     R1,     FIVE
        CMP     R1,     R3
        BNZ     R1,     ELIF6
;;    t = 5;
        ADI     R4,     5       ;
        STR     R4,     R2      ;
        JMP     ENDIF5          ;
;;  else if (j == '6')
ELIF6   LDB     R1,     SIX
        CMP     R1,     R3
        BNZ     R1,     ELIF7
;;    t = 6;
        ADI     R4,     6       ;
        STR     R4,     R2      ;
        JMP     ENDIF5          ;
;;  else if (j == '7')
ELIF7   LDB     R1,     SEVEN
        CMP     R1,     R3
        BNZ     R1,     ELIF8
;;    t = 7;
        ADI     R4,     7       ;
        STR     R4,     R2      ;
        JMP     ENDIF5          ;
;;  else if (j == '8')
ELIF8   LDB     R1,     EIGHT
        CMP     R1,     R3
        BNZ     R1,     ELIF9
;;    t = 8;
        ADI     R4,     8       ;
        STR     R4,     R2      ;
        JMP     ENDIF5          ;
;;  else if (j == '9')
ELIF9   LDB     R1,     NINE
        CMP     R1,     R3
        BNZ     R1,     ELSE5
;;    t = 9;
        ADI     R4,     9       ;
        STR     R4,     R2      ;
        JMP     ENDIF5          ;
;;  else {
ELSE5   SUB     R0,     R0      ;
;;    printf("%c is not a number\n", j);
        MOV     R0,     R3      ;j
        TRP     3
PRINTF2 .BYT    ' '     ;0
        .BYT    'i'
        .BYT    's'
        .BYT    ' '
        .BYT    'n'
        .BYT    'o'     ;5
        .BYT    't'
        .BYT    ' '
        .BYT    'a'
        .BYT    ' '
        .BYT    'n'     ;10
        .BYT    'u'
        .BYT    'm'
        .BYT    'b'
        .BYT    'e'
        .BYT    'r'     ;15
        LDA     R1,     PRINTF2 ;
        LDB     R0,     R1      ;
        TRP     3               ;' '
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;i
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;s
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;' '
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;n
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;o
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;t
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;' '
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;a
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;' '
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;n
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;u
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;m
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;b
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;e
        ADI     R1,     1       ;
        LDB     R0,     R1      ;
        TRP     3               ;r

        LDB     R0,     NL
        TRP     3               ;\n

;;    flag = 1;
        SUB     R3,     R3      ;
        ADI     R3,     1
        STR     R3,     flag    ;
;;  }
ENDIF5  SUB     R0,     R0
;;
;;  if (!flag) {
        LDR     R1,     flag    ;
        BRZ     R1,     IF6
        JMP     ENDIF6
IF6     SUB     R0,     R0      ;
;;    if (s == '+')
        MOV     R1,     FP      ;
        ADI     R1,     -5      ;&char s
        LDB     R5,     R1      ;R[5] = s
        LDB     R3,     PLUS    ;R[3] = '+' or '-'
        CMP     R3,     R5      ;
        BRZ     R3,     IF7
        JMP     ELSE7
;;      t *= k;
IF7     MOV     R1,     FP      ;
        ADI     R1,     -14     ;R1 = &t
        LDR     R3,     R1      ;R[3] = t
        MOV     R2,     FP      ;
        ADI     R2,     -9      ;R2 = & k
        LDR     R4,     R2      ;R[4] = k
        MUL     R3,     R4      ;R[3] = t * k
        STR     R3,     R1      ;t = R[3]
        JMP     ENDIF7
;;    else
;;      t *= -k;
ELSE7   MOV     R1,     FP      ;
        ADI     R1,     -14     ;R1 = &t
        LDR     R3,     R1      ;R[3] = t
        MOV     R2,     FP      ;
        ADI     R2,     -9      ;R2 = & k
        LDR     R4,     R2      ;R[4] = k
        SUB     R5,     R5      ;R[5] = 0
        ADI     R5,     -1      ;R[5] = -1
        MUL     R4,     R5      ;k = k * -1
        MUL     R3,     R4      ;R[3] = t * -k
        STR     R3,     R1      ;t = R[3]
;;    opdv += t;
ENDIF7  LDR     R6,     opdv    ;R[6] = opdv
        LDR     R7,     R1      ;R[7] = t
        ADD     R6,     R7      ;R[6] = opdv + t
        STR     R6,     opdv    ;opdv = R[6]
;;  }
ENDIF6  SUB     R0,     R0      ;
;;}
;Return from OPD
        MOV     SP,     FP
        ADI     SP,     4       ;De-allocate FP
        LDR     R4,     FP      ;Keep a copy of FP to jump to
        MOV     R6,     FP      ;Grab another copy of FP
        ADI     R6,     -4      ;Move the pointer to PFP
        LDR     FP,     R6      ;Store PFP in FP
        JMR     R4              ;Return
;END of OPD

;Main Program
;;void main()
MAIN    SUB     R0,     R0
;;reset(1, 0, 0, 0); // Reset globals
;Setup Activation record for reset, and jump
        MOV     R3,     FP      ;Save FP in R3, this will be the PFP
        ADI     SP,     -4      ;Adjust Stack Pointer for Return Address
        MOV     FP,     SP      ;Point at Current Activation Record     (FP = SP)
        ADI     SP,     -4      ;Adjust Stack Pointer for PFP
        STR     R3,     SP      ;PFP to Top of Stack                    (PFP = FP)
;Adding Parameters for reset(int w, int x, int y, int z)
        SUB     R4,     R4
        ADI     R4,     1       ;w = 1
        ADI     SP,     -4      ;Adjust Stack Pointer for int w
        STR     R4,     SP      ;int w offset -8
        SUB     R4,     R4      ;x,y,z = 0
        ADI     SP,     -4      ;Adjust Stack Pointer for int x
        STR     R4,     SP      ;int x offset -12
        ADI     SP,     -4      ;Adjust Stack Pointer for int y
        STR     R4,     SP      ;int y offset -16
        ADI     SP,     -4      ;Adjust Stack Pointer for int z
        STR     R4,     SP      ;int z offset -20
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     32      ;Compute Return Address (always a fixed amount)
        STR     R1,     FP      ;Return Address to the Beginning of the Frame
        JMP     RESET           ;Call Function MAIN
;END RESET Activation
;;getdata();         // Get data
;Setup Activation record for getdata, and jump
        MOV     R3,     FP      ;Save FP in R3, this will be the PFP
        ADI     SP,     -4      ;Adjust Stack Pointer for Return Address
        MOV     FP,     SP      ;Point at Current Activation Record     (FP = SP)
        ADI     SP,     -4      ;Adjust Stack Pointer for PFP
        STR     R3,     SP      ;PFP to Top of Stack                    (PFP = FP)
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     32      ;Compute Return Address (always a fixed amount)
        STR     R1,     FP      ;Return Address to the Beginning of the Frame
        JMP     GETDATA         ;Call Function MAIN
;END GETDATA Activation
;;while (c[0] != '@') { // Check for stop symbol '@'
WHILE1  SUB     R0,     R0
        LDB     R1,     c       ;R1 = c[0]
        LDB     R2,     AT      ;R2 = '@'
        CMP     R2,     R1      ;'@' - c[0]
        BRZ     R2,     ENDWH1  ;Branch out if they are the same
;;  if (c[0] == '+' || c[0] == '-') { // Determine sign
        LDB     R2,     PLUS    ;R[2] = '+'
        CMP     R2,     R1      ;'+' - c[0]
        BRZ     R2,     IF2     ;Need to Run getdata
        LDB     R2,     MINUS   ;get '-'
        CMP     R2,     R1      ;'-' - c[0]
        BRZ     R2,     IF2     ;Run getdata
        JMP     ELSE2
IF2     SUB     R0,     R0
;;    getdata(); // Get most significant byte
;Setup Activation record for getdata, and jump
        MOV     R3,     FP      ;Save FP in R3, this will be the PFP
        ADI     SP,     -4      ;Adjust Stack Pointer for Return Address
        MOV     FP,     SP      ;Point at Current Activation Record     (FP = SP)
        ADI     SP,     -4      ;Adjust Stack Pointer for PFP
        STR     R3,     SP      ;PFP to Top of Stack                    (PFP = FP)
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     32      ;Compute Return Address (always a fixed amount)
        STR     R1,     FP      ;Return Address to the Beginning of the Frame
        JMP     GETDATA         ;Call Function MAIN
        JMP     ENDIF2
;;  } else {  // Default sign is '+'
ELSE2   SUB     R0,     R0
;;    c[1] = c[0]; // Make room for the sign
        LDA     R1,     c       ;&c[0]
        LDB     R2,     R1      ;c[0]
        ADI     R1,     1       ;&c[1]
        STR     R2,     R1      ;c[1] = c[0]
;;    c[0] = '+';
        ADI     R1,     -1      ;
        LDB     R2,     PLUS    ;
        STB     R2,     R1      ;
;;    cnt++;
        LDR     R1,     cnt     ;
        ADI     R1,     1       ;
        STR     R1,     cnt     ;cnt++
;;  }
ENDIF2  SUB     R0,     R0
;;  while(data) {  // Loop while there is data to process
WHILE3  LDR     R1,     data
        BRZ     R1,     ENDWH3
;;    if (c[cnt-1] == '\n') { // Process data now
        LDA     R1,     c       ;get &c[0]
        LDR     R2,     cnt     ;Get cnt
        ADI     R2,     -1      ;cnt -1
        ADD     R1,     R2      ;R1 = &c[cnt - 1]
        LDB     R3,     R1      ;R3 = c[cnt - 1]
        LDB     R4,     NL      ;Get \n
        CMP     R4,     R3      ;
        BRZ     R4,     IF3
        JMP ELSE3
;;      data = 0;
IF3     SUB     R0,     R0
        SUB     R2,     R2      ;R2 = 0
        STR     R2,     data    ;data = 0
;;      tenth = 1;
        ADI     R2,     1       ;R2 = 1
        STR     R2,     tenth   ;
;;      cnt = cnt - 2;
        LDR     R1,     cnt     ;
        ADI     R1,     -2      ;
        STR     R1,     cnt     ;cnt = cnt - 2
;;
;;      while (!flag && cnt != 0) { // Compute a number
WHILE4  LDR     R1,     flag
        BNZ     R1,     ENDWH4
        LDR     R1,     cnt
        BRZ     R1,     ENDWH4
;;        opd(c[0], tenth, c[cnt]);
;Setup Activation record for opd, and jump
        MOV     R3,     FP      ;Save FP in R3, this will be the PFP
        ADI     SP,     -4      ;Adjust Stack Pointer for Return Address
        MOV     FP,     SP      ;Point at Current Activation Record     (FP = SP)
        ADI     SP,     -4      ;Adjust Stack Pointer for PFP
        STR     R3,     SP      ;PFP to Top of Stack                    (PFP = FP)
        LDA     R1,     c       ;R1 = &c[0]
        LDB     R4,     R1      ;R1 = c[0]
        ADI     SP,     -1      ;Adjust Stack Pointer for char s
        STB     R4,     SP      ;char s = c[0] offset FP-8
        LDR     R4,     tenth   ;R4 = tenth
        ADI     SP,     -4      ;Adjust Stack Pointer for int k
        STR     R4,     SP      ;int k = tenth offset FP-9
        LDR     R5,     cnt     ;R5 = cnt
        ADD     R1,     R5      ;R1 = &c[cnt]
        LDB     R4,     R1      ;R4 = c[cnt]
        ADI     SP,     -1      ;Adjust Stack Pointer for int k
        STB     R4,     SP      ;char j = c[cnt] offset FP-13
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     32      ;Compute Return Address (always a fixed amount)
        STR     R1,     FP      ;Return Address to the Beginning of the Frame
        JMP     OPD             ;Call Function MAIN
;END OPD Activation
;;        cnt--;
        LDR     R1,     cnt     ;
        ADI     R1,     -1      ;
        STR     R1,     cnt     ;
;;        tenth *= 10;
        LDR     R1,     tenth   ;
        SUB     R2,     R2      ;
        ADI     R2,     10      ;
        MUL     R1,     R2      ;
        STR     R1,     tenth   ;
        JMP     WHILE4
;;      }
ENDWH4  SUB     R0,     R0
;;      if (!flag)  //  Good number entered
        LDR     R1,     flag    ;
        BNZ     R1,     ENDIF4
;;        printf("Operand is %d\n", opdv);
OPERAND .BYT    'O'     ;0
        .BYT    'p'
        .BYT    'e'
        .BYT    'r'
        .BYT    'a'
        .BYT    'n'     ;5
        .BYT    'd'
        .BYT    ' '
        .BYT    'i'
        .BYT    's'
        .BYT    ' '     ;10
        LDA     R1,     OPERAND ;
        LDB     R0,     R1      ;O
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;p
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;e
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;r
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;a
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;n
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;d
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;' '
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;i
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;s
        TRP     3
        ADI     R1,     1       ;
        LDB     R0,     R1      ;' '
        TRP     3

        LDR     R0,     opdv
        TRP     1
        LDB     R0,     NL
        TRP     3
ENDIF4  SUB     R0,     R0
;;    }
        JMP     ENDIF3
;;    else
ELSE3   SUB     R0,     R0
;;      getdata(); // Get next byte of data
;Setup Activation record for getdata, and jump
        MOV     R3,     FP      ;Save FP in R3, this will be the PFP
        ADI     SP,     -4      ;Adjust Stack Pointer for Return Address
        MOV     FP,     SP      ;Point at Current Activation Record     (FP = SP)
        ADI     SP,     -4      ;Adjust Stack Pointer for PFP
        STR     R3,     SP      ;PFP to Top of Stack                    (PFP = FP)
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     32      ;Compute Return Address (always a fixed amount)
        STR     R1,     FP      ;Return Address to the Beginning of the Frame
        JMP     GETDATA         ;Call Function MAIN
;;  }
ENDIF3  SUB     R0,     R0
        JMP     WHILE3
ENDWH3  SUB     R0,     R0
;;  reset(1, 0, 0, 0);  // Reset globals
;Setup Activation record for reset, and jump
        MOV     R3,     FP      ;Save FP in R3, this will be the PFP
        ADI     SP,     -4      ;Adjust Stack Pointer for Return Address
        MOV     FP,     SP      ;Point at Current Activation Record     (FP = SP)
        ADI     SP,     -4      ;Adjust Stack Pointer for PFP
        STR     R3,     SP      ;PFP to Top of Stack                    (PFP = FP)
;Adding Parameters for reset(int w, int x, int y, int z)
        SUB     R4,     R4
        ADI     R4,     1       ;w = 1
        ADI     SP,     -4      ;Adjust Stack Pointer for int w
        STR     R4,     SP      ;int w offset -8
        SUB     R4,     R4      ;x,y,z = 0
        ADI     SP,     -4      ;Adjust Stack Pointer for int x
        STR     R4,     SP      ;int x offset -12
        ADI     SP,     -4      ;Adjust Stack Pointer for int y
        STR     R4,     SP      ;int y offset -16
        ADI     SP,     -4      ;Adjust Stack Pointer for int z
        STR     R4,     SP      ;int z offset -20
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     32      ;Compute Return Address (always a fixed amount)
        STR     R1,     FP      ;Return Address to the Beginning of the Frame
        JMP     RESET           ;Call Function MAIN
;END RESET Activation
;;  getdata();          // Get data
;Setup Activation record for getdata, and jump
        MOV     R3,     FP      ;Save FP in R3, this will be the PFP
        ADI     SP,     -4      ;Adjust Stack Pointer for Return Address
        MOV     FP,     SP      ;Point at Current Activation Record     (FP = SP)
        ADI     SP,     -4      ;Adjust Stack Pointer for PFP
        STR     R3,     SP      ;PFP to Top of Stack                    (PFP = FP)
        MOV     R1,     PC      ;PC incremented by 1 instruction
        ADI     R1,     32      ;Compute Return Address (always a fixed amount)
        STR     R1,     FP      ;Return Address to the Beginning of the Frame
        JMP     GETDATA         ;Call Function MAIN
        JMP     WHILE1
;;}
ENDWH1  SUB     R0,     R0


;Return from MAIN
        MOV     SP,     FP
        ADI     SP,     4       ;De-allocate FP
        LDR     R4,     FP      ;Keep a copy of FP to jump to
        MOV     R6,     FP      ;Grab another copy of FP
        ADI     R6,     -4      ;Move the pointer to PFP
        LDR     FP,     R6      ;Store PFP in FP
        JMR     R4              ;Return
;END of MAIN
