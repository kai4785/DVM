;Contiguous Data
A	.INT	1
	.INT	2
	.INT	3
	.INT	4
	.INT	5
	.INT	6
B	.INT	300
	.INT	150
	.INT	50
	.INT	20
	.INT	10
	.INT	5
C	.INT	500
	.INT	2
	.INT	5
	.INT	10
LNAME	.BYT	'M'
	.BYT	'e'
	.BYT	'y'
	.BYT	'e'
	.BYT	'r'
	.BYT	','
SPACE	.BYT	32
FNAME	.BYT	'K'
	.BYT	'a'
	.BYT	'i'
NL	.BYT	10	;ASCII New Line character
ST7	.BYT	0	;ASCII Space character

;Using R0 to print with TRP 3

;1) Print name
	LDA	R1,	LNAME	;Load Address of LNAME into R1
	LDB	R0,	R1	;Load Contents of LNAME into R0
	TRP	3		;Print (M)
	ADI	R1,	1	;Increment Memory address
	LDB	R0,	R1	;Load Contents of LNAME into R0
	TRP	3		;Print (e)
	ADI	R1,	1	;Increment Memory address
	LDB	R0,	R1	;Load Contents of LNAME into R0
	TRP	3		;Print (y)
	ADI	R1,	1	;Increment Memory address
	LDB	R0,	R1	;Load Contents of LNAME into R0
	TRP	3		;Print (e)
	ADI	R1,	1	;Increment Memory address
	LDB	R0,	R1	;Load Contents of LNAME into R0
	TRP	3		;Print (r)
	ADI	R1,	1	;Increment Memory address
	LDB	R0,	R1	;Load Contents of LNAME into R0
	TRP	3		;Print (,)
	ADI	R1,	1	;Increment Memory address
	LDB	R0,	R1	;Load Contents of LNAME into R0
	TRP	3		;Print ( )

	LDA	R1,	FNAME	;Load Address of FNAME into R1
	LDB	R0,	R1	;Load Contents of LNAME into R0
	TRP	3		;Print (K)
	ADI	R1,	1	;Increment Memory address
	LDB	R0,	R1	;Load Contents of LNAME into R0
	TRP	3		;Print (a)
	ADI	R1,	1	;Increment Memory address
	LDB	R0,	R1	;Load Contents of LNAME into R0
	TRP	3		;Print (i)

;2) Print blank line
	LDB	R0,	NL	;Load Value of symbol NL into R0
	TRP	3		;Print (\n)
	TRP	3		;Print (\n)

;3) Add all the elements of list B together; 
;   print each result (intermediate and final) on screen. 
;   Put 2 spaces between each result.
	SUB	R0,	R0	;Clear out R0
	LDA	R1,	B	;Load Addr of B into R1
	LDR	R0,	R1	;Contents of the Adress of R1 into R0

	ADI	R1,	4	;Increment R1
	LDR	R2,	R1	;Contents of the Adress of R1 into R2
	ADD	R0,	R2	;Add Contents of R0 and R2 and store result in R0
	TRP	1		;Print contents of R0
;Print 2 spaces
	MOV	R3,	R0	;Keep a copy of R0 in R1 so R0 can be used to print a space
	LDB	R0,	SPACE	;Put a space in the register
	TRP	3		;Print ( );
	TRP	3		;Print ( );
	MOV	R0,	R3	;Put the value back

	ADI	R1,	4	;Increment R1
	LDR	R2,	R1	;Contents of the Adress of R1 into R2
	ADD	R0,	R2	;Add Contents of R0 and R2 and store result in R0
	TRP	1		;Print contents of R0
;Print 2 spaces
	MOV	R3,	R0	;Keep a copy of R0 in R1 so R0 can be used to print a space
	LDB	R0,	SPACE	;Put a space in the register
	TRP	3		;Print ( );
	TRP	3		;Print ( );
	MOV	R0,	R3	;Put the value back

	ADI	R1,	4	;Increment R1
	LDR	R2,	R1	;Contents of the Adress of R1 into R2
	ADD	R0,	R2	;Add Contents of R0 and R2 and store result in R0
	TRP	1		;Print contents of R0
;Print 2 spaces
	MOV	R3,	R0	;Keep a copy of R0 in R1 so R0 can be used to print a space
	LDB	R0,	SPACE	;Put a space in the register
	TRP	3		;Print ( );
	TRP	3		;Print ( );
	MOV	R0,	R3	;Put the value back

	ADI	R1,	4	;Increment R1
	LDR	R2,	R1	;Contents of the Adress of R1 into R2
	ADD	R0,	R2	;Add Contents of R0 and R2 and store result in R0
	TRP	1		;Print contents of R0
;Print 2 spaces
	MOV	R3,	R0	;Keep a copy of R0 in R1 so R0 can be used to print a space
	LDB	R0,	SPACE	;Put a space in the register
	TRP	3		;Print ( );
	TRP	3		;Print ( );
	MOV	R0,	R3	;Put the value back

	ADI	R1,	4	;Increment R1
	LDR	R2,	R1	;Contents of the Adress of R1 into R2
	ADD	R0,	R2	;Add Contents of R0 and R2 and store result in R0
	TRP	1		;Print contents of R0
;Print 2 spaces
	MOV	R3,	R0	;Keep a copy of R0 in R1 so R0 can be used to print a space
	LDB	R0,	SPACE	;Put a space in the register
	TRP	3		;Print ( );
	TRP	3		;Print ( );
	MOV	R4,	R3	;Put the value in R4 so it can be used for step 7

;4) Print a blank line.
	LDB	R0,	NL	;Load Value of symbol NL into R0
	TRP	3		;Print (\n)
	TRP	3		;Print (\n)

;5) Multiply all the elements of list A together; 
;   print each result (intermediate and final) on screen. 
;   Put 2 spaces between each result.
        SUB     R0,     R0      ;Clear out R0
        LDA     R1,     A       ;Load Addr of A into R1
        LDR     R0,     R1      ;Contents of the Adress of R1 into R0

        ADI     R1,     4       ;Increment R1
        LDR     R2,     R1      ;Contents of the Adress of R1 into R2
        MUL     R0,     R2      ;Multiply Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );
        MOV     R0,     R3      ;Put the value back

        ADI     R1,     4       ;Increment R1
        LDR     R2,     R1      ;Contents of the Adress of R1 into R2
        MUL     R0,     R2      ;Multiply Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );
        MOV     R0,     R3      ;Put the value back

        ADI     R1,     4       ;Increment R1
        LDR     R2,     R1      ;Contents of the Adress of R1 into R2
        MUL     R0,     R2      ;Multiply Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );
        MOV     R0,     R3      ;Put the value back

        ADI     R1,     4       ;Increment R1
        LDR     R2,     R1      ;Contents of the Adress of R1 into R2
        MUL     R0,     R2      ;Multiply Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );
        MOV     R0,     R3      ;Put the value back

        ADI     R1,     4       ;Increment R1
        LDR     R2,     R1      ;Contents of the Adress of R1 into R2
        MUL     R0,     R2      ;Multiply Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );
        MOV     R5,     R3      ;Put the value in R5 for use in step 9


;6) Print a blank line.
	LDB	R0,	NL	;Load Address of NL into R1
	TRP	3		;Print (\n)
	TRP	3		;Print (\n)

;7) Divide the final result from part 3, by each element in list B (the results are not cumulative). 
;   Put 2 spaces between each result.
        LDA     R1,     B       ;Load Addr of B into R1

        MOV     R0,     R4      ;Retrieve final result from part 3
        LDR      R2,     R1      ;Contents of the Adress of R1 into R2
        DIV     R0,     R2      ;Divide Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );
        ADI     R1,     4       ;Increment R1

        MOV     R0,     R4      ;Retrieve final result from part 3
        LDR      R2,     R1      ;Contents of the Adress of R1 into R2
        DIV     R0,     R2      ;Divide Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );
        ADI     R1,     4       ;Increment R1

        MOV     R0,     R4      ;Retrieve final result from part 3
        LDR      R2,     R1      ;Contents of the Adress of R1 into R2
        DIV     R0,     R2      ;Divide Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );
        ADI     R1,     4       ;Increment R1

        MOV     R0,     R4      ;Retrieve final result from part 3
        LDR      R2,     R1      ;Contents of the Adress of R1 into R2
        DIV     R0,     R2      ;Divide Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );
        ADI     R1,     4       ;Increment R1

        MOV     R0,     R4      ;Retrieve final result from part 3
        LDR      R2,     R1      ;Contents of the Adress of R1 into R2
        DIV     R0,     R2      ;Divide Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );
        ADI     R1,     4       ;Increment R1

        MOV     R0,     R4      ;Retrieve final result from part 3
        LDR      R2,     R1      ;Contents of the Adress of R1 into R2
        DIV     R0,     R2      ;Divide Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );

;8) Print a blank line.
	LDB	R0,	NL	;Load Address of NL into R1
	TRP	3		;Print (\n)
	TRP	3		;Print (\n)

;9) Subtract from the final result of part 5 each element of list C (the results are not cumulative). 
;   Put 2 spaces between each result.
        LDA     R1,     C       ;Load Addr of B into R1

        MOV     R0,     R5      ;Recover the value from part 5
        LDR      R2,     R1      ;Contents of the Adress of R1 into R2
        SUB     R0,     R2      ;Subtract Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );
        ADI     R1,     4       ;Increment R1

        MOV     R0,     R5      ;Recover the value from part 5
        LDR      R2,     R1      ;Contents of the Adress of R1 into R2
        SUB     R0,     R2      ;Subtract Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );
        ADI     R1,     4       ;Increment R1

        MOV     R0,     R5      ;Recover the value from part 5
        LDR      R2,     R1      ;Contents of the Adress of R1 into R2
        SUB     R0,     R2      ;Subtract Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );
        ADI     R1,     4       ;Increment R1

        MOV     R0,     R5      ;Recover the value from part 5
        LDR      R2,     R1      ;Contents of the Adress of R1 into R2
        SUB     R0,     R2      ;Subtract Contents of R0 and R2 and store result in R0
        TRP     1               ;Print contents of R0
;Print 2 spaces
        MOV     R3,     R0      ;Keep a copy of R0 in R1 so R0 can be used to print a space
        LDB     R0,     SPACE   ;Put a space in the register
        TRP     3               ;Print ( );
        TRP     3               ;Print ( );







	LDB	R0,	NL	;Load Address of NL into R1
	TRP	3		;Print (\n)
	TRP	0
