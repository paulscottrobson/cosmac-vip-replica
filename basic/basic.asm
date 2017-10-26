
r2 = 2
r3 = 3
r4 = 4

	cpu 	1802

	org 	8000h

	ldi 	080h
	phi 	r2
	ldi 	008h
	plo 	r2
	sex 	r2
	sep 	r2
	out 	4
	idl

	sex 	r2
	ldi 	s1/256
	phi	 	r4
	ldi 	s1&255
	plo 	r4
	sep 	r4

s1:
	ldi 	01
	phi 	r2
	ldi 	00
	plo 	r2

Variables = 0D00h

return macro 															; allows subroutine returns to disable/enable interrupts as you want.
	dis 																; this program uses MARK-subroutines
		endm

;
;	$80-$8F 	Operators : $80:@  $81:?  $82:~  $83:!
;				(Unary)
; 	$90-$9F 	Operators : $90:== $91:!= $92:<  $93: >= $94:<= $95:> $96:- $97:+ 
;				(Binary)	$98:*  $99:/  $9A:%  $9B: &  $9C:|  $9D:^ 
;							
;	$A0-$BE 	Variable. Value is 2 * offset + Variables, type is 16 bit address
;
;	$BF 		A string constant. String constants are ended by bit 7 being set to '1'.
;
;	$C0-$FE 	Represents constant values from -2 to 60
;
;	$FF hh ll 	Constant value outside the C0..FE range
;

;
;	r15 :	current value on the top of the stack.
; 	r14	:	.0 type of value in r15 : 0=constant 1=address of 16 bit LL:HH 2=address of 8 bit.
;			.1 temporary register
;	r13 : 	RPN calculation stack. Starts with lower 4 bits zero ; one dummy value at start
;			(r13) points to the LSB of the 2nd stack value, (r13+1) is the MSB. Expands down.
;	r12 : 	Code being evaluated

rxCode = 12
rxRPNStack = 13 
rxType = 14
rxTOS = 15


Setup:
	ldi 	000h
	phi 	rxRPNStack
	ldi 	010h
	plo 	rxRPNStack

	ldi 	TestCode/256
	phi	 	rxCode
	ldi 	TestCode&255
	plo 	rxCode

	ldi 	Evaluate/256
	phi 	r3
	ldi 	Evaluate&255
	plo 	r3

	mark
	sep 	r3
	dec 	r2

end1:br 	end1

TestCode: 	
	db		0C4h
	db 		000h

	org 	8100h

; ************************************************************************************************
;
;	Set up the 'dummy' stack top value, constant zero.
;
; ************************************************************************************************

Evaluate:
	ldi 	0 										; First up, put a dummy value in for the current TOS
	plo 	rxTOS									; which is zero, constant type zero.
	phi 	rxTOS
	plo 	rxType

; ************************************************************************************************
;
;	Main Loop Here. If the following item is not part of an expression, we return, but
; 	possibly with a L-Expression in rxTOS/rxType. If we want an r-expr we can re-enter.
;
; ************************************************************************************************

__EVMainLoop:
	sex 	r2 										; use R2 as index for this bit.

	ldn 	rxCode 									; look at next item
	ani 	080h 									; is it an expression part token ($80-$FF)
	bnz 	__EVNoExit1 							; if so skip this exit

	inc 	r2 										; at this point we may have an l-expression
	return 											; so we reenter to make sure it's an r-expression.

; ************************************************************************************************
;
;	If the current value in the TOS registers is an 8 or 16 bit indirection, do that look up.
;
; ************************************************************************************************

__EVNoExit1:
	glo 	rxType 									; if type is zero, no indirection required.
	bz 		__EVIsRExpr
	xri 	2 										; if type is one, it's an 8 bit indirection.
	bz 		__EV8BitIndirection

	lda 	rxTOS 									; read the low byte. 
	plo 	rxType
	ldn 	rxTOS 									; read high
	phi 	rxTOS 									; copy into rTOS
	glo 	rxType
	plo 	rxTOS
	ldi 	0
	plo 	rxType
	br 		__EVIsRExpr

__EV8BitIndirection:
	ldn 	rxTOS 									; byte read
	plo 	rxTOS 									; put in low byte
	ldi 	0
	phi 	rxTOS 									; zero high byte and type.
	plo 	rxType

; ************************************************************************************************
;
;	We now have an R-Expr in the TOS registers. If we've reached the end of the expression
; 	tokens, we can now exit with that.
;
; ************************************************************************************************

__EVIsRExpr:
	ldn 	rxCode 									; look at next item
	ani 	080h 									; is it an expression part token ($80-$FF)
	bnz 	__EVNoExit2 							; if so skip this exit

	inc 	r2 										; at this point, we *know* we have an r-expr
	return 											; so we can make it re-entrant
	br 		Evaluate

; ************************************************************************************************
;
;	Now we have either operators or values. Firstly we do values. We have a new value, so we
;	push the old TOS value, now an r-expr definitely, on the stack, and get a new value in the
; 	TOS *registers*.
;
;	There are four values : a variable, a short constant, a long constant, and a bit7 string.
;
; ************************************************************************************************

__EVNoExit2:
	ldn 	rxCode 									; look at next item
	adi 	060h 									; DF will be set for A0-FF which are values.
	bnf 	__EVIsOperator

	dec 	rxRPNStack 								; push current TOS value onto the stack
	ghi 	rxTOS 									
	str 	rxRPNStack 								; high first, then low.
	dec 	rxRPNStack
	glo 	rxTOS 									; the new value can go in the registers.
	str 	rxRPNStack

	ldi 	0 										; zero the type - most of the values are constants
	plo 	rxType 									; the exception being variables which are l-exprs.

	; TODO: Handle short constants
	; TODO: Handle long constants
	; TODO: Handle variables
	; TODO: Handle strings.

__EVIsOperator:
	br 		__EVIsOperator

	; TODO: Operators.
	; TODO: Check number of values on stack
	; TODO: Precalculate subtraction.
	
;	lrx 	rUtilPC,ASCIIToInteger 										; call the atoi() routine.
;	mark
;	sep 	rUtilPC
;	dec 	r2 		

;  	sex 	r2
;	inc 	r2
; 	return

;
;
;return macro 															; allows subroutine returns to disable/enable interrupts as you want.
;	dis 																; this program uses MARK-subroutines
;	endm
