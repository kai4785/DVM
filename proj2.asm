SIZE	.INT	10
ARR	.INT	10
	.INT	2
	.INT	3
	.INT	4
	.INT	15
	.INT	-6
	.INT	7
	.INT	8
	.INT	9
	.INT	10
I	.INT	0
SUM	.INT	0
TEMP	.INT	0
RESULT	.INT	0
SPACE	.BYT	32	;ASCII Space Character
NL	.BYT	10	;ASCII New Line character
EVEN	.BYT	32
	.BYT	'i'
	.BYT	's'
	.BYT	32
	.BYT	'e'
	.BYT	'v'
	.BYT	'e'
	.BYT	'n'
	.BYT	10
ODD	.BYT	32
	.BYT	'i'
	.BYT	's'
	.BYT	32
	.BYT	'o'
	.BYT	'd'
	.BYT	'd'
	.BYT	10

; while (i < SIZE) {
; 	sum += arr[i];
; 	result = arr[i] % 2;
; 	if (result == 0)
; 		printf("%d is even\n", arr[i]);
; 	else
; 		printf("%d is odd\n", arr[i]);
; i++;
; }
	LDR	R1,	SIZE	;Get the SIZE of the array into a Register

; while(i < SIZE) {
WHILE1	LDR	R2,	I	;Get I into the comparison register
	LDR	R3,	SIZE	;Get SIZE into the comparison register
	CMP	R3,	R2	;Get the difference of SIZE - I into the comparison register
      	BRZ	R3,	END1	;While R3 is not zero

; 	sum += arr[i];
	LDR	R5,	SUM	;Get SUM into the Register
	LDA	R4,	ARR	;Load Address of ARR into the array
	SUB	R7,	R7	;
	ADI	R7,	4	;Size of int is 4, so I need to offset by 4
	MUL	R7,	R2	;
	ADD	R4,	R7	;Offset into the Array
;	//arr[i]
	LDR	R6,	R4	;Get the value of the I'th value in ARR
	ADD	R5,	R6	;ADD the SUM up
	STR	R5,	SUM	;Shove SUM back into memory

; 	result = arr[i] % 2;
;	// mod = arr[i] - (arr[i] / 2 \* 2)
	MOV	R5,	R6	;Get a copy of arr[i] into R7
	SUB	R7,	R7	;
	ADI	R7,	2	;
	DIV	R5,	R7	;
	MUL	R5,	R7	;R5 now has an even number in it
	CMP	R5,	R6	;Compare R5 and R6

; 	if (result == 0)
IF1	BNZ	R5,	ELSE1	;If false branch

; 		printf("%d is even\n", arr[i]);
	MOV	R0,	R6	;Print arr[i]
	TRP	1
        LDA     R1,     EVEN	;Load Address of EVEN into R1
        LDB     R0,     R1      ;Load Contents of EVEN into R0
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               

; 	else
	JMP	ENDIF1
ELSE1	MOV	R0,	R6	;Print arr[i]
; 		printf("%d is odd\n", arr[i]);
	TRP	1
        LDA     R1,     ODD	;Load Address of ODD into R1
        LDB     R0,     R1      ;Load Contents of ODD into R0
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               
        ADI     R1,     1       
        LDB     R0,     R1      
        TRP     3               

ENDIF1	SUB	R0,	R0	;


; i++;
	ADI	R2,	1	;Increment 1
	STR	R2,	I	;Get I back into memory
	JMP	WHILE1		;Back to WHILE1

; }
END1	LDB	R0,	NL	;Unecessary, but harmless, end of WHILE
;	TRP	3

; printf("Sum is %d\n", sum);
SUM1	.BYT	'S'
	.BYT	'u'
	.BYT	'm'
	.BYT	' '
	.BYT	'i'
	.BYT	's'
	.BYT	' '

	LDA	R1,	SUM1
	LDB	R0,	R1
	TRP	3
	ADI	R1,	1
	LDB	R0,	R1
	TRP	3
	ADI	R1,	1
	LDB	R0,	R1
	TRP	3
	ADI	R1,	1
	LDB	R0,	R1
	TRP	3
	ADI	R1,	1
	LDB	R0,	R1
	TRP	3
	ADI	R1,	1
	LDB	R0,	R1
	TRP	3
	ADI	R1,	1
	LDB	R0,	R1
	TRP	3

	LDR	R0,	SUM	;
	TRP	1
	LDB	R0,	NL	;
	TRP	3


;Place “CATS” into continuous memory on an integer boundry: ‘C’, ‘A’, ‘T’, ‘S’.
CATS	.BYT	'C'
	.BYT	'A'
	.BYT	'T'
	.BYT	'S'
;Print the char data (e.g., CATS), followed by the integer value for “CATS” to the screen.
	LDA	R1,	CATS	;Get Address into R1
	LDB	R0,	R1	;Get 'C' into R0
	TRP	3
	ADI	R1,	1
	LDB	R0,	R1	;Get 'A' into R0
	TRP	3
	ADI	R1,	1
	LDB	R0,	R1	;Get 'T' into R0
	TRP	3
	ADI	R1,	1
	LDB	R0,	R1	;Get 'S' into R0
	TRP	3
	LDB	R0,	SPACE
	TRP	3
	TRP	3


	LDR	R0,	CATS	;
	MOV	R7,	R0	;Keep a Copy of the Integer Value for CATS
	TRP	1
	LDB	R0,	NL
	TRP	3
;Access the location in memory were “CATS” is stored as an integer. 
;Swap the ‘C’ and the ‘T’ in memory and access the location in memory again as an integer.  
	LDA	R1,	CATS	;Get Address of C
	LDB	R2,	R1	;Store C
	ADI	R1,	2	;Get Address of T
	LDB	R3,	R1	;Store T
	STB	R2,	R1	;Store C in the address of T
	LDA	R1,	CATS	;Get Address of C
	STB	R3,	R1	;Store T in the address of C

;Print the data (e.g., TACS), followed by the integer value for “TACS”.
	LDA	R1,	CATS	;Get Address into R1
	LDB	R0,	R1	;Get 'C' into R0
	TRP	3
	ADI	R1,	1
	LDB	R0,	R1	;Get 'A' into R0
	TRP	3
	ADI	R1,	1
	LDB	R0,	R1	;Get 'T' into R0
	TRP	3
	ADI	R1,	1
	LDB	R0,	R1	;Get 'S' into R0
	TRP	3
	LDB	R0,	SPACE
	TRP	3
	TRP	3

	LDR	R0,	CATS	;
	TRP	1
	LDB	R0,	NL
	TRP	3
;Subtract the two integers together (TACS - CATS) and print the value of this integer.
	LDR	R0,	CATS	;
	SUB	R0,	R7	;R7 has the old integer value of CATS
	TRP	1
	LDB	R0,	NL
	TRP	3









	TRP	0
