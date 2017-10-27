
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
;	$FF ll hh 	Constant value outside the C0..FE range
;
;	TODO: $80-$9E nn Short array access e.g. CC4 (unsigned)
;
;	r15 :	current value on the top of the stack.
; 	r14	:	.0 type of value in r15 : 0=constant 1=address of 16 bit LL:HH 2=address of 8 bit.
;			.1 temporary register
;	r13 : 	RPN calculation stack. Starts with lower 4 bits zero ; one dummy value at start
;			(r13) points to the LSB of the 2nd stack value, (r13+1) is the MSB. Expands down.
;	r12 : 	Code being evaluated
; 	r11 : 	Code routine address for evaluation.

rxRoutine = 11
rxCode = 12
rxRPNStack = 13 
rxType = 14
rxTOS = 15

ERR_Underflow = 081h								; Underflow of stack.

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
	db 		0FFh,081h,4
	db		0FFh,082h,1
	db 		096h
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
	shl 		 									; is it an expression part token ($80-$FF)
	bdf 	__EVNoExit1 							; if so skip this exit

	ldi 	0 										; return code 0 (no error)
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
	shl 											; is it an expression part token ($80-$FF)
	bdf 	__EVNoExit2 							; if so skip this exit

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
	phi 	rxTOS 									; zero TOS.1
;
;	Check for short constant C0-FE and long constant FF low high
;
	lda 	rxCode 									; read and advance the code pointer.
	adi 	40h 									; DF set if C0-FF, D is 00-3F
	bnf 	__EVNotConstant

	plo 	rxTOS 									; save as top of stack
	dec 	rxTOS 									; fix up as C0 is -2
	dec 	rxTOS
	xri 	3Fh 									; check it was 3F, which is the long constant
	bnz 	__EVMainLoop

	lda 	rxCode 									; read LSB/MSB in
	plo 	rxTOS
	lda 	rxCode
	phi 	rxTOS
	br 		__EVMainLoop
;
;	It must now be in the range A0-BF. Variable handler.
;
__EVNotConstant:
	adi 	20h										; put into range 00-1F
	xri 	1Fh 									; if the value was BF it's a string
	bz 		__EVIsString
	xri 	1Fh 									; fix back.
	shl 											; double A
	plo 	rxTOS 									; point to variable.
	ldi 	Variables/256
	phi 	rxTOS
	inc 	rxType 									; set type to 1 (16 bit indirect)
	br 		__EVMainLoop
;
;	String BF <string> terminated by bit 7 high
;
__EVIsString:
	glo	 	rxCode 									; code pointer = string address
	plo 	rxTOS
	ghi 	rxCode
	phi 	rxTOS
__EVSkipString:
	lda 	rxCode
	shl
	bnf 	__EVSkipString
	br 		__EVMainLoop

; ************************************************************************************************
;
;			  We have found a Unary Operator (80-8F) or Binary Operator (90-9F)
;
; ************************************************************************************************

__EVIsOperator:
	ldn 	rxCode 									; get the code.
	adi 	70h 									; set DF if it is a binary operator.
	glo 	rxRPNStack 	 							; look at LS Nibble of RPN Stack
	ani 	0Fh
	bz 		__EVStackUnderflow  					; there's not at least one entry.
	bnf 	__EVDispatch 							; if unary operator, go to dispatch.

	xri 	0Eh 									; binary operator, so 0E is a bad value
	bz 		__EVStackUnderflow

	ldn 	rxCode 									; get code.
	adi 	0FFh - 096h 							; values >= 097 will produce a DF
	bdf 	__EVDispatch 							; $90-$96 (compares and subtract) all start
													; with subtraction so we precalculate that.
	sex 	rxRPNStack 								; now do the subtraction throwing the stack value.
	glo 	rxTOS
	sd 															
	plo 	rxTOS
	inc 	rxRPNStack
	ghi 	rxTOS
	sdb 															
	phi 	rxTOS
	inc 	rxRPNStack 	

	ldi 	0 										; put DF into D
	rshl 
	phi 	rxType 									; and save in rxType.1 (for comparisons)
	br 		__EVDispatch 							; go to the dispatcher
;
__EVStackUnderflow:
	ldi 	ERR_Underflow							; fail evaluaition on stack underflow.
	inc 	r2
	return 

; ************************************************************************************************
;
;							Actually execute a unary/binary operand
;
; ************************************************************************************************

__EVDispatch:
	lda 	rxCode 									; get the code again, and skip it.
	shl 											; double it, also losing bit 7.
	adi 	__EVDispatchTable&255
	plo 	rxRoutine 								; make rxRoutine point into the table
	ldi 	__EVDispatchTable/256 	
	phi 	rxRoutine
	lda 	rxRoutine 								; read high byte
	phi 	rxType
	ldn 	rxRoutine 								; read low byte and fix up
	plo 	rxRoutine
	ghi 	rxType
	phi	 	rxRoutine

	sex 	r2 										; call the routine
	mark
	sep 	rxRoutine
	dec 	r2	
	br 		__EVMainLoop 							; go round again.

; ************************************************************************************************
;
;	Vectors for operators. Note that the ASL assembler outputs this data in
;	high/low order.
;
; ************************************************************************************************

__EVDispatchTable:
	dw 		0 										; $80 @
	dw 		0 										; $81 ?
	dw 		0 										; $82 ~
	dw 		0 										; $83 !
	dw 		0,0,0,0,0,0,0,0,0,0,0,0 				; $84-$8F are unused.
	dw 		0 										; $90 == (these are precalculated)
	dw 		0 										; $91 !=
	dw 		0 										; $92 <
	dw 		0 										; $93 >=
	dw 		0 										; $94 <=
	dw 		0 										; $95 >
	dw 		__EVSubtract 							; $96 - (which is already done)
	dw 		__EVAdd 								; $97 +
	dw 		0 										; $98 *
	dw 		0 										; $99 /
	dw 		0 										; $9A %
	dw 		__EVAnd 								; $9B &
	dw 		__EVOr 									; $9C |
	dw 		__EVXor 								; $9D ^
	dw 		0,0										; $9E-$9F are unused.

; ************************************************************************************************
;
;	16 bit Addition
;
; ************************************************************************************************

__EVAdd:
	sex 	rxRPNStack 								; Addition of TOS + (stack)
	glo 	rxTOS
	add
	plo 	rxTOS
	inc 	rxRPNStack
	ghi 	rxTOS
	adc
	phi 	rxTOS
	inc  	rxRPNStack 								; and fall through, subtraction precalculated

; ************************************************************************************************
;
;	16 bit Subtraction
;
; ************************************************************************************************

__EVOpExit1:		
__EVSubtract: 										; Subtraction is precalculated so do nothing.
	sex 	r2
	inc 	r2
	return

; ************************************************************************************************
;
;	16 bit Bitwise AND
;
; ************************************************************************************************

__EVAnd:
	sex 	rxRPNStack 								; Addition of TOS + (stack)
	glo 	rxTOS
	and
	plo 	rxTOS
	inc 	rxRPNStack
	ghi 	rxTOS
	and
	phi 	rxTOS
	inc  	rxRPNStack 						
	br 		__EVOpExit1

; ************************************************************************************************
;
;	16 bit Bitwise OR
;
; ************************************************************************************************

__EVOr:
	sex 	rxRPNStack 								; Addition of TOS + (stack)
	glo 	rxTOS
	or
	plo 	rxTOS
	inc 	rxRPNStack
	ghi 	rxTOS
	or
	phi 	rxTOS
	inc  	rxRPNStack 						
__EVOpExit2:
	sex 	r2
	inc 	r2
	return

; ************************************************************************************************
;
;	16 bit Bitwise XOR
;
; ************************************************************************************************

__EVXor:
	sex 	rxRPNStack 								; Addition of TOS + (stack)
	glo 	rxTOS
	xor
	plo 	rxTOS
	inc 	rxRPNStack
	ghi 	rxTOS
	xor
	phi 	rxTOS
	inc  	rxRPNStack 						
	br 		__EVOpExit2
