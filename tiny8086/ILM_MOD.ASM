	;nasm -f bin ILM.ASM -o ILM.COM
	;NASM version 2.15.05 compiled on Aug 28 2020
	ORG	100H	;STANDARD MS-DOS START ADDR.
;==============================================================================
; Nasm directives
;==============================================================================
;[CPU 8086]
;[BITS 16]
;[ORG 0000h]

;==============================================================================
; Const section
;==============================================================================
STACK_SEG       EQU 1000h
STACK_OFF       EQU 0FFFFh

ROWS            EQU 25
COLS            EQU 80

FG_COLOR        EQU 0Fh
BG_COLOR        EQU 10h

DIRECT			EQU 0
RUN				EQU 1

MAX_STACK		EQU 128					

;==============================================================================
; MAIN PROGRAM
;==============================================================================
START:
		call	ILM_CLEAR				;clear screen

		mov		dx,offset STR_WELCOME			;print welcome string
		call	PRINT_STR

		call	ILM_INIT				;init function (clear all)
		call	ILM_NLINE				;new line

CO:     
		mov		sp,STACK_OFF			;clear SP (error could happened)

		mov		ax,PGM					;copy PGM address
		mov		[PGP],ax				;set PGP at beginning of program
		mov		[CURSOR],ax				;set CURSOR at beginning of line
		mov		[MODE],BYTE PTR 00h			;set mode 0 (direct)
              
		mov		al,3Eh					;set prompt '>'
		call	ILM_GETLINE				;get line in LBUF
		call	ILM_NLINE				;new line

		cmp		[LBUF],BYTE PTR 00h			;LBUF empty ?
		je		CO						;skip

		call	ILM_TSTL                ;test for line number
		cmp		al,-1					;number valid ?
		je		CO						;if not back to collection

		call	ILM_INSERT        		;insert line

		cmp		al,00h					;is direct ?
		jne		CO						;no, back to collection

XEC:    
		call	ILM_XINIT             	;clear AESTACK

STMT:   
		mov		dx,offset STR_REM				;"REM" (comment)
		call	ILM_TST
		cmp		al,00h
		je		S0

		call	ILM_NXT					;next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC 
		
S0:
		mov		dx,offset STR_LET				;"LET"
		call	ILM_TST
		cmp		al,00h
		je		S1

		call	ILM_TSTV				;there is a variable ? ?
		cmp		al,-1
		je		CO
		cmp		al,00h
		je		ERROR

		mov		dx,offset STR_ASSIGN			;there is "=" assignement symbol ?
		call	ILM_TST
		cmp		al,00h
		je		ERROR

		call	EXPR					;evaluate expression

		call	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO

		call	ILM_STORE				;store value into variable
		cmp		al,00h
		je		CO

		call	ILM_NXT					;next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC

S1:     
		mov		dx,offset STR_GOTO				;"GOTO"
		call	ILM_TST
		cmp		al,00h
		je		S2

		call	EXPR					;evaluate expression

		call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO

		call	ILM_XPER				;set PGP to new line, reset CURSOR
		cmp		al,0
		je		CO

		jmp		XEC

S2:     
		mov		dx,offset STR_GOSUB			;"GOSUB"
		call	ILM_TST
		cmp		al,00h
		je		S3

		call 	EXPR					;evaluate expression

		call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO             			

		call	ILM_SAV					;save current line on SBRSTACK
		cmp		al,00h
		je		CO

		call	ILM_XPER				;set PGP to new line, reset CURSOR
		cmp		al,0
		je		CO

S3:     
		mov		dx,offset STR_PRINT			;"PRINT"
		call	ILM_TST
		cmp		al,00h
		je		S8

S4:     
		mov		dx,offset STR_QUOTES			;chack for quotes
		call	ILM_TST
		cmp		al,00h
		je		S7

		call	ILM_PRS         		;print the string
		cmp		al,00h
		je		CO

S5:     
		mov		dx,offset STR_COMMA			;check comma for more
		call	ILM_TST
		cmp		al,00h
		je		S6

		call	ILM_SPC					;add single space

		jmp		S4

S6:     
		call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO             			

        call	ILM_NLINE				;new line

        call	ILM_NXT					;next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC

S7:     
		call    EXPR					;evaluate expression

		call	ILM_PRN					;print number
		cmp		al,00h
		je		CO

		jmp		S5

S8:     
		mov		dx,offset STR_IF				;"IF"
		call	ILM_TST
		cmp		al,00h
		je		S9

		call	EXPR					;evaluate expression

		call	RELOP					;set logical operator on AESTACK
		
		call	EXPR					;evaluate expression

        mov		dx,offset STR_THEN				;check "THEN"
		call	ILM_TST
		cmp		al,00h
		je		ERROR              

		call	ILM_CMPR				;perform compare
		cmp		al,-1
		je		CO
		cmp		al,00h
		jne		XEC						;match ok, execute "THEN" part

		call	ILM_NXT					;no match, next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC

S9:      
		mov		dx,offset STR_INPUT			;"INPUT"
		call	ILM_TST
		cmp		al,00h
		je		S12

S10:    
		call	ILM_TSTV				;check for Variable letter
		cmp		al,-1
		je		CO
		cmp		al,00h
		je		ERROR

		call	ILM_INNUM				;get number
		cmp		al,00h
		je		CO

        call	ILM_STORE				;store the number in the variable
		cmp		al,00h
		je		CO

        mov		dx,offset STR_COMMA			;check for more elements
		call	ILM_TST
		cmp		al,00h
		je		S11
		
        jmp		S10			

S11:    
		call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO             	

        call	ILM_NXT					;next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC

S12:    
		mov		dx,offset STR_RETURN			;"RETURN"
		call	ILM_TST
		cmp		al,00h
		je		S13

		call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO             	

		call	ILM_RSTR				;restore previous line
		cmp		al,00h
		je		CO

		call	ILM_NXT					;next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC

S13:    
		mov		dx,offset STR_END				;"END"
		call	ILM_TST
		cmp		al,00h
		je 		S14

		call	ILM_DONE				;no need to test DONE result
        jmp		CO						;always jump to collection routine

S14:    
		mov		dx,offset STR_LIST				;"LIST"
		call	ILM_TST
		cmp		al,00h
		je		S15

		call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO

		cmp		BYTE PTR [MODE],DIRECT		;im in DIRECT mode ?
		je		S14A

		mov		[ERROR_CODE], offset ERROR_MODE
		call	ILM_ERR					;no, print error and go back to CO
		jmp		CO

S14A:		
        call	ILM_LST					;print program
		jmp		CO

S15:    
		mov		dx,offset STR_RUN				;"RUN"
		call	ILM_TST
		cmp		al,00h
		je		S16

        call 	ILM_DONE				;EOL ? 
		cmp		al,00h
		je		CO

		cmp		BYTE PTR [MODE],DIRECT		;im in DIRECT mode ?
		je		S15A

		mov		[ERROR_CODE],offset ERROR_MODE
		call	ILM_ERR					;no, print error and go back to CO
		jmp		CO

S15A:
		mov		BYTE PTR [MODE],RUN			;set RUN mode

        call	ILM_NXT					;next line
		cmp		al,00h
		je		CO
		cmp		al,01h
		je		XEC

S16:    
		mov		dx,offset STR_RESET			;test "RESET"
		call	ILM_TST
		cmp		al,00h
		je		ERROR

		call 	ILM_DONE				;EOL ?
		cmp		al,00h
		je		CO

		cmp		BYTE PTR [MODE],DIRECT		;im in DIRECT mode ?
		je		S16A

		mov		[ERROR_CODE],offset ERROR_MODE
		call	ILM_ERR					;no, print error and go back to CO
		jmp		CO

S16A:
        jmp		START					;back to beginning

ERROR:    
		mov		[ERROR_CODE],offset ERROR_SYNTAX
		call	ILM_ERR             	
		jmp		CO						;back to collection routine

EXPR:   
		mov		dx,offset STR_MINUS			;"-" (unary)
		call	ILM_TST
		cmp		al,00h
		je		E0

		call	TERM					;evaluate term

		call	ILM_NEG					;negate it
		cmp		al,00h
		je		CO

		jmp		E1

E0:     
		mov		dx,offset STR_PLUS				;"+"  (unary)
		call	ILM_TST
		cmp		al,00h
		je		E1A

E1A:   
		call	TERM   					;evaluate term

E1:     
		mov		dx,offset STR_PLUS				;"+"
		call	ILM_TST
		cmp		al,00h
		je		E2

		call	TERM					;evaluate term

		call	ILM_ADD					;addition
		cmp		al,00h
		je		CO

		jmp		E1

E2:     
		mov		dx,offset STR_MINUS			;test "-"
		call	ILM_TST
		cmp		al,00h
		je		E3

		call	TERM					;evaluate term

		call	ILM_SUB					;subtraction
		cmp		al,00h
		je 		CO

		jmp		E1

E3:
		ret

TERM:   
		call	FACT					;evaluate factorial

T0:     
		mov		dx,offset STR_MUL				;"*"
		call	ILM_TST
		cmp		al,00h
		je		T1

		call	FACT					;evaluate factorial

		call 	ILM_MUL					;multiply
		cmp		al,00h
		je		CO

		jmp		T0

T1:     
		mov		dx,offset STR_DIV				;"/"
		call	ILM_TST
		cmp		al,00h
		je		T2

		call    FACT					;evaluate factorial

        call	ILM_DIV					;division
		cmp		al,00h
		je		CO

        jmp   	T0

T2:  
		ret

FACT:  
		call	ILM_TSTV				;is Variable ?
		cmp		al,-1
		je		CO
		cmp		al,00h
		je		F0
		
        call	ILM_IND                 ;swap top AESTACK with value of Variable index
        cmp		al,00h
		je		CO

		ret

F0:     
		call	ILM_TSTN				;is Number ?
		cmp		al,-1					
		je		CO
		cmp		al,00h					
		je		F1
					
		ret

F1:    
		mov		dx,offset STR_LPAREN			;"("
		call	ILM_TST
		cmp		al,00h
		je		F2

		call	EXPR					;evaluate expression

		mov		dx,offset STR_RPAREN			;")"
		call	ILM_TST
		cmp		al,00h
		je		F2

        ret

F2:     
		mov		[ERROR_CODE],offset ERROR_SYNTAX
		call	ILM_ERR                 
		jmp		CO						;back to collection routine

; RELOP/CODE :
; == 0
; != 1
; <= 2
; >= 3
;  < 4
;  > 5

RELOP:  
		mov		dx,offset STR_OP_E				;test "=="
		call	ILM_TST
		cmp		al,00h
		je		R0

		mov		dx,0
		jmp		R5

R0:  
		mov		dx,offset STR_OP_NE			;test "!="
		call	ILM_TST
		cmp		al,00h
		je		R1

		mov		dx,1
		jmp		R5

R1:     
		mov		dx,offset STR_OP_LE			;test "<="
		call	ILM_TST
		cmp		al,00h
		je		R2

		mov		dx,2
		jmp		R5

R2: 
		mov		dx,offset STR_OP_GE			;test ">="
		call	ILM_TST
		cmp		al,00h
		je		R3

		mov		dx,3
		jmp		R5

R3:   
		mov		dx,offset STR_OP_L				;test "<"
		call	ILM_TST
		cmp		al,00h
		je		R4

		mov		dx,4
		jmp		R5        

R4:     
		mov		dx,offset STR_OP_G				;test ">"
		call	ILM_TST
		cmp		al,00h
		je		R6

		mov		dx,5

R5:	
		call	ILM_LIT					;push DX on Aestack
		cmp		al,00h
		je		CO

		ret								;done success !

R6:     
        mov		[ERROR_CODE],offset ERROR_OPERATOR
		call	ILM_ERR
		jmp		CO

END:									;this point should never be reached
		cli                             ;disable interrupts
        hlt                             ;halt system

;==============================================================================
; Include section
;==============================================================================
;%INCLUDE "SRC/UTILS.ASM"					;required to use core functions
;==============================================================================
; Expect in DX the beginning of the string
;==============================================================================
PRINT_STR:                       

        mov     si,dx                   ;copy the start of string in SI
        mov     ah,0Eh                  ;interrupt 10h code (teletype print)
        mov     bh,00h                  ;interrupt 10h page 0

    PRINT_STR_next: 
        mov     al,[si]                 ;copy in al the current byte to print
        cmp     al,00h                  ;compare al with 0x00 (string end)
        jz      PRINT_STR_done                  	;if zero, go to finish
        int     10h                     ;call interrupt
        inc     si                      ;move forward
        jmp     PRINT_STR_next                  	;repeat

    PRINT_STR_done:
        ret

;==============================================================================
; Expect in DX the word to print (NOTE : we "consume" DX from the head)
;==============================================================================
PRINT_WORD:                     

        mov     ch,04h                  ;use CH as nibble counter
        mov     cl,04h                  ;use CL for 4 bit shift
        mov     ah,0Eh                  ;write characters in teletype mode
        mov     bh,00h                  ;write at page 0

    PRINT_WORD_cycle:
        mov     al,dh                   ;copy in al the high byte of DX
        and     al,0F0h                 ;get the left nibble
        shr     al,cl                   ;shift it to right
        
        add     al,30h                  ;add 48 to get the printable char
        cmp     al,39h                  ;is number or letter ?
        jbe     PRINT_WORD_print                 	;if less is a number, go to print it
        add     al,07h                  ;is a letter, add 7 more

    PRINT_WORD_print:
        int     10h                     ;call interrupt

        dec     ch                      ;decrease the counter
        jz      PRINT_WORD_done                  	;if zero we have done
        shl     dx,cl                   ;advance next nibble
        jmp     PRINT_WORD_cycle                 	;repeat

    PRINT_WORD_done:
        ret

;==============================================================================
; Print a number in decimal format, expect in DX the number to print
; NOTE : we use the stack to "decompose" the number
;==============================================================================
PRINT_NUMBER:

        mov     ax,dx                   ;copy the number in AX
        cmp     ax,00h                  ;it is zero ?
        je      PRINT_NUMBER_zero                   ;jmp to special case

        or 		ax,ax                   ;check if negative
		jns 	PRINT_NUMBER_positive               ;no, continue
	
    PRINT_NUMBER_negative:                             
                                        
        mov     ah,0EH                  ;print the minus sign          
        mov     al,2Dh                  
        mov     bh,00h    
        int     10h
                                        
        mov     ax,dx                   ;put in AX the absolute value
    	not 	ax                     
		inc 	ax                      

    PRINT_NUMBER_positive:
        
        mov     bx,10                   ;we use base 10
        xor     cx,cx                   ;will be counter for stack
        xor     dx,dx                   ;will hold remainder of division

    PRINT_NUMBER_pusher:                            ;loop to push numbers on stack
            
        cmp     ax,0                    ;if here finished
        je      PRINT_NUMBER_popper                 ;go to loop that print the numbers
            
        div     bx                      ;divide AX by 10
            
        push    dx                      ;push the remainder of division on stack             
            
        inc     cx                      ;increase the stack counter
            
        xor     dx,dx                   ;clear DX for next division
        
        jmp     PRINT_NUMBER_pusher                 ;repeat popper cycle
    
    PRINT_NUMBER_popper:                            ;cycle to pop elements and print them
            
        cmp     cx,00h                  ;still have elements on stack ?
        je      PRINT_NUMBER_done                   ;no, exit
            
        pop     ax                      ;get the number from the stack
            
        mov     ah,0EH                  ;set ah for teletype print
        add     al,30h                  ;make the number an ascii value
        mov     bh,00h                  ;page 00h
        int     10h                     ;call interrupt

        dec     cx                      ;decrease the counter

        jmp     PRINT_NUMBER_popper                 ;repeat pop items
    
    PRINT_NUMBER_zero:                              ;special case for 0
        mov     ah,0EH
        mov     al,30h
        mov     bh,00h    
        int     10h

    PRINT_NUMBER_done:
        ret


;==============================================================================
; Wait for a key press
;==============================================================================
WAIT_KEY:  
        xor     ax,ax                   ;keyboard read function
        int     16h                     ;interrupt for keyboard I/O services
        ret
        


;%INCLUDE "SRC/ILM/ILM_ADD.ASM"				;ILM functions
;==============================================================================
; ADD	
; Replace top two elements of AESTK by their sum.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_ADD:
        xor     bx,bx                   ;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,02h					;not enough elements
        jb     	ILM_ADD_stack_err

        dec     bl						;get top stack
		shl		bl,1					;mult by 2
		add		bx,offset AESTACK_BASE			;add stack base address

		mov		ax,[bx]					;get second element in AX

		dec		bx						;decrease address by 2
		dec		bx

		add		[bx],ax					;store result of sum
		jo		ILM_ADD_number_err

		dec		BYTE PTR [AESTACK_POINTER]	;decrease stack pointer

		mov		al,1					;exit success

		ret

    ILM_ADD_stack_err:
		mov		[ERROR_CODE],offset ERROR_AESTACK_UNDERFLOW
		jmp		ILM_ADD_err

	ILM_ADD_number_err:
		mov		[ERROR_CODE],offset ERROR_NUMBER_OVERFLOW
		
	ILM_ADD_err:		
		call	ILM_ERR						;return 0 on fail
		xor		al,al
		ret


;%INCLUDE "SRC/ILM/ILM_CLEAR.ASM"
;==============================================================================
; CLEAR
; clear the entire scren using ILM values
;==============================================================================
ILM_CLEAR:
        mov     ah,06h                  ;clear screen service
        mov     al,00h                  ;lines to scroll (if 0 all)
        mov     bh,BG_COLOR|FG_COLOR    ;background/foreground colors
        mov     ch,00h                  ;Row number of upper left corner
        mov     cl,00h                  ;Column number of upper left corner
        mov     dh,ROWS-1               ;Row number of lower right corner
        mov     dl,COLS-1               ;Column number of lower right corner
        int     10h                     

        mov     ah,02h                  ;int to reset cursor position
        mov     bh,00h                  ;page number
        mov     dx,000h                 ;row/col
        int     10h

        ret
        
;%INCLUDE "SRC/ILM/ILM_CMPR.ASM"
;==============================================================================
; CMPR
; Compare AESTK(SP), the top of the stack, with AESTK(SP-2)
; as per the relations indicated by AESTK(SP-1). 
; Delete all from stack.
; If the condition specified did not match, then perform NXT action.
;
; Return:
; AL = -1 error
; AL = 0 false
; AL = 1 true
;==============================================================================
ILM_CMPR:
		xor		ax,ax					;clear AX
        xor     si,si                   ;clear SI

        add     si,WORD PTR [AESTACK_POINTER]    ;get stack pointer

		cmp     si,03h					;not enough elements
        jb     	ILM_CMPR_stack_err

        dec     si						;get top stack
		shl		si,1					;mult by 2
		add		si,offset AESTACK_BASE			;add stack base address

		mov		dx,[si]					;get second operand

		dec		si						;decrease address by 2
		dec		si

		mov		cx,[si]					;get operator index
		
		dec		si						;decrease address by 2
		dec		si

		mov		bx,[si]					;get first operand

		sub		[AESTACK_POINTER],BYTE PTR 03h   ;remove 3 elements

	ILM_CMPR_switch:
		cmp		cx,00h
		je		ILM_CMPR_e
		cmp		cx,01h
		je		ILM_CMPR_ne
		cmp		cx,02h
		je		ILM_CMPR_le
		cmp		cx,03h
		je		ILM_CMPR_ge
		cmp		cx,04h
		je		ILM_CMPR_l
		cmp		cx,05h
		je		ILM_CMPR_g

	ILM_CMPR_e:
		cmp		bx,dx
		je		ILM_CMPR_done_true
		ret

	ILM_CMPR_ne:
		cmp		bx,dx
		jne		ILM_CMPR_done_true
		ret

	ILM_CMPR_le:
		cmp		bx,dx
		jle		ILM_CMPR_done_true
		ret

	ILM_CMPR_ge:
		cmp		bx,dx
		jge		ILM_CMPR_done_true
		ret

	ILM_CMPR_l:
		cmp		bx,dx
		jl		ILM_CMPR_done_true
		ret

	ILM_CMPR_g:
		cmp		bx,dx
		jg		ILM_CMPR_done_true
		ret

	ILM_CMPR_done_true:
		mov		al,1					;exit true
		ret

    ILM_CMPR_stack_err:
		mov		[ERROR_CODE],offset ERROR_AESTACK_UNDERFLOW		
		call	ILM_ERR						
		mov		al,-1					;return -1 on fail
		ret
		
;%INCLUDE "SRC/ILM/ILM_DIV.ASM"
;==============================================================================
; DIV	
; Replace top two elements of AESTK by their quotient.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_DIV:
        xor     bx,bx                   ;clear BX

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,02h					;not enough elements
        jb     	ILM_DIV_stack_err

        dec     bl						;get top stack
		shl		bl,1					;mult by 2
		add		bx,offset AESTACK_BASE			;add stack base address

		mov		cx,[bx]					;get second element in CX

		cmp		cx,0					;divide by 0 error
		je		ILM_DIV_div_zero_err

		dec		bx						;decrease address by 2
		dec		bx

		mov		ax,[bx]					;get first element in AX
		cwd								;NOTE: extends sign bit of AX in DX

		idiv	cx						;divide by cx

		mov		[bx],ax					;store result
		
		dec		BYTE PTR [AESTACK_POINTER]	;decrease stack pointer

		mov		al,01h					;exit success

		ret

    ILM_DIV_stack_err:
		mov		[ERROR_CODE],offset ERROR_AESTACK_UNDERFLOW
		jmp		ILM_DIV_err

	ILM_DIV_div_zero_err:
		mov		[ERROR_CODE],offset ERROR_DIVIDE_ZERO

	ILM_DIV_err:
		call	ILM_ERR
		xor		al,al
		ret


;%INCLUDE "SRC/ILM/ILM_DONE.ASM"
;==============================================================================
; DONE
; Report a syntax error if after deletion leading blanks the cursor is not 
; positioned to road a carriage return.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_DONE:

		mov		si,[CURSOR]

	ILM_DONE_skip_blanks:

		cmp		[si],BYTE PTR 00h				;is EOL ?
		je		ILM_DONE_done						;ok done

		cmp		[si],BYTE PTR 20h				;is a blank ?
		ja		ILM_DONE_err						;no, error
		
		inc		si							;increase cursor
		jmp		ILM_DONE_skip_blanks				;check next char

	ILM_DONE_err:
		mov		[ERROR_CODE],offset ERROR_SYNTAX
		call	ILM_ERR
		xor		al,al
		ret

	ILM_DONE_done:
		mov		al,01h
		ret
		
;%INCLUDE "SRC/ILM/ILM_ERR.ASM"
;==============================================================================
; ERR
; Report syntax error am return to line collect routine.
;
; Expect:
; [ERROR_CODE] == the error line to print
;
; NOTE : insert JMP CO after calling this function
;==============================================================================
ILM_ERR:									
		
		call	ILM_NLINE				;new line

	ILM_ERR_mode:
		cmp		[MODE],BYTE PTR 00h			;direct mode ?
		je		ILM_ERR_err_direct				;skip line number

	ILM_ERR_err_at_line:
		mov		dx,offset ERROR_STR_AT_LINE	;
		call	PRINT_STR

	ILM_ERR_line:
		mov		ax,[PGP]				;convert line address to line number
		sub		ax,PGM					
		mov		bl,COLS
		div		bl

	ILM_ERR_num:								;print line number
		mov		dx,ax
		call	PRINT_NUMBER
		
		jmp		ILM_ERR_err_code

	ILM_ERR_err_direct:
		mov		dx,offset ERROR_STR
		call	PRINT_STR

	ILM_ERR_err_code:								
		mov		dx,[ERROR_CODE]			;print code error
		call	PRINT_STR

		call	ILM_NLINE

		ret
		
;%INCLUDE "SRC/ILM/ILM_GETLINE.ASM"
;==============================================================================
; GETLINE
; Input a line to LBUF.
;
; Expect :
; AL = the ascii symbol for the prompt
;==============================================================================
ILM_GETLINE:

	ILM_GETLINE_prompt:							
		mov     ah,0Eh                  ;teletype print interupt
        mov     bh,00h                  ;page
        int     10h 

	ILM_GETLINE_init:
		mov     al,00h            		;the value to initialize the buffer
        mov		di,offset LBUF       			;clear LBUF
        mov     cx,COLS		          	;size of bufffer to copy
		rep		stosb                   ;repeat

		mov		si,00h					;reset SI (index)

	ILM_GETLINE_cycle:
		xor     ax,ax                   ;keyboard read function
        int     16h						;ah scancode, al ascii code

		cmp		al,0Dh					;is enter pressed ?
		je		ILM_GETLINE_done					;ok finished

		cmp		al,08h 					;is backspace ?
		je		ILM_GETLINE_backspace

		cmp		si,COLS-2               ;do we have any space left ?
		jge		ILM_GETLINE_cycle                  ;if not skip insertion

		cmp		al,20h					;is printable ?
		jb		ILM_GETLINE_cycle
		cmp		al,7Eh
		ja		ILM_GETLINE_cycle

		mov		bx,offset LBUF
		mov		[bx+si],al				;store character 
		inc		si

		mov     ah,0Eh                  ;teletype print interupt
        mov     bh,00h                  ;page
        int     10h 

		jmp		ILM_GETLINE_cycle

	ILM_GETLINE_backspace:

		cmp		si,0					;we are at beginning of LBUF
		jle		ILM_GETLINE_cycle					;skip backspace

		dec		si						;dec DI and store a blank in LBUF
		mov		bx,offset LBUF
		mov		[bx+si],BYTE PTR 00h
		
		mov		bh,00h      			;set page number for all operations

		mov		ah,03h					;get cursor position in DH,DL (row/col)
		int		10h

		dec		dl						;dec the col
		mov		ah,02h					;set cur pos
		int		10h

		mov     ah,0Ah                  ;write character at current cursor pos
		mov		al,20h					;we use empty space
        int     10h

		jmp		ILM_GETLINE_cycle
		
	ILM_GETLINE_done:
		ret
		
;%INCLUDE "SRC/ILM/ILM_IND.ASM"
;==============================================================================
; IND
; Replace top of AEstack by variable value it indexes.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_IND:
        xor     bx,bx                  	;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,00h					;if zero stack empty
        jbe     ILM_IND_stack_err

        dec     bl						;go to first element

		shl		bl,1					;mult by 2

		add		bx,offset AESTACK_BASE			;add stack base

		mov 	si,[bx]					;copy the var index from [BX] to SI
		shl		si,1					;mult by2
		add 	si,offset VARIABLES			;add VARIABLES BASE

		mov		ax,[si] 				;copy the value in ax

		mov		[bx],ax					;store it at top of stack

		mov		al,01h

		ret

    ILM_IND_stack_err:
		mov		[ERROR_CODE],offset ERROR_AESTACK_UNDERFLOW
		call	ILM_ERR
		xor		al,al
		ret
		
;%INCLUDE "SRC/ILM/ILM_INIT.ASM"
;==============================================================================
; INIT
; Perform global initilization.
; Clears program area, empties GOSUB stack, etc.
;==============================================================================
ILM_INIT:
		mov		[MODE],BYTE PTR 00h			;mode 0 = direct

		mov     al,00h            		;the byte to initialize the buffer
        mov		di,offset PGM       			;clear PGM
        mov     cx,256*COLS		        ;size of bufffer
		rep		stosb                   ;repeat

		mov     ax,0000h            	;the word to initialize the buffer
        mov		di,offset VARIABLES   			;clear VARIABLES
        mov     cx,26		        	;size of bufffer
		rep		stosw                   ;repeat

		mov		[PGP],offset PGM			;clear the PGP

		mov		[CURSOR],offset PGM		;clear the CURSOR

		mov		[AESTACK_POINTER], BYTE PTR 00h 	;clear AESTACK pointer
		mov		[SBRSTACK_POINTER], BYTE PTR 00h 	;clear AESTACK pointer

		ret
		
;%INCLUDE "SRC/ILM/ILM_INNUM.ASM"
;==============================================================================
; INNUM
; Read a number from the terminal and push its value onto the AESTK.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;
; NOTE : we use LBUF to read the number
;==============================================================================
ILM_INNUM:

		mov		al,23h					;set prompt	'#'
		call	ILM_GETLINE				;read a line in LBUF

	ILM_INNUM_init:
		mov		si,offset LBUF					;set SI at LBUF
		xor		ax,ax					;AX will store the result
		mov		bx,10					;BX will be multiplier by 10
		xor		di,di					;set DL for positive sign
		xor		ch,ch					;clear high part of CX
		
	ILM_INNUM_skip_blanks:
		cmp		[si],BYTE PTR 00h			;is EOL ?
		je		ILM_INNUM_empty_line				;possible error

		cmp		[si],BYTE PTR 20h			;is a blank ?
		jg		ILM_INNUM_check_sign				;no, check if sign present
		
		inc		si						;increase position

		jmp		ILM_INNUM_skip_blanks			;check next char

	ILM_INNUM_check_sign:
		cmp		[si],BYTE PTR 2Bh			;check '+'
		je		ILM_INNUM_skip_sign

		cmp		[si],BYTE PTR 2Dh			;check '-'
		jne		ILM_INNUM_get_number
	
		mov		di,1					;set DL for sign change

	ILM_INNUM_skip_sign:
		inc		si
		
	ILM_INNUM_get_number:						

		mov		cl,[si]					;get in cl the current char

		cmp		cl,00h					;ok done, go to fix sign if needed
		je		ILM_INNUM_fix_sign

		cmp 	cl,30h					;is less than 0 ?
		jl		ILM_INNUM_not_number

		cmp 	cl,39h					;is greater than 9 ?
		jg		ILM_INNUM_not_number

		sub 	cl,30h					;convert CL ascii to a number 0..9

		mul 	bx						;multiply the content of AL for 10
		jo		ILM_INNUM_big_number				;if overflow error

		add		ax,cx					;add the the CL value
		jo		ILM_INNUM_big_number				;if overflow error
		
		inc 	si						;next char
		jmp		ILM_INNUM_get_number 			;repeat

	ILM_INNUM_fix_sign:
		cmp		di,00h					;was negative ?
		je		ILM_INNUM_done					;nope
		neg		ax						;yes, negate it
	
	ILM_INNUM_done:
		mov		dx,ax
		call	ILM_LIT
		cmp		al,00h
		jne		ILM_INNUM_done_ok
		ret								;AL already set to 0 from ILM_LIT

	ILM_INNUM_done_ok:
		call	ILM_NLINE
		mov		al,01h					;exit success
		ret
	
	ILM_INNUM_empty_line:
		mov		[ERROR_CODE],offset ERROR_EMPTY_LINE
		jmp		ILM_INNUM_err

	ILM_INNUM_not_number:
		mov		[ERROR_CODE],offset ERROR_NOT_NUMBER
		jmp		ILM_INNUM_err

	ILM_INNUM_big_number:
		mov		[ERROR_CODE],offset ERROR_NUMBER_OVERFLOW

	ILM_INNUM_err:
		call	ILM_ERR
		xor		al,al
		ret
		
;%INCLUDE "SRC/ILM/ILM_INSERT.ASM"
;==============================================================================
; INSRT
; Insert line after deleting any line with same line number.
;
; Expect:
; AL == line number
; SI == first element after line number
;
; Return :
; AL == line number inserted
;==============================================================================
ILM_INSERT:
		mov		dl,al					;bkup the line number

		mov		cx,COLS					;how many to copy
		sub		cx,si

		add		si,offset LBUF					;prepare source data index

		mov		bl,COLS					;prepare dest data index (PGM+LINE_NUM*COLS)
		mul		bl
		mov		di,ax					
		add		di,PGM

        rep     movsb           		;copy

		mov		al,dl					;restore line number inserted

		ret
		
;%INCLUDE "SRC/ILM/ILM_LIT.ASM"
;==============================================================================
; LIT num
; Push the number num onto the AESTK (Originally omitted)
;
; Expect:
; DX == the number to push on the Aestack
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_LIT:
		xor		bx,bx					;clear bx

        mov		bl,[AESTACK_POINTER] 	;get current stack pointer
		cmp		bl,MAX_STACK			;greatest of max elements ?
		jae		ILM_LIT_stack_err				;if yes error

		shl		bl,1					;multiply pointer by 2

		add		bx,offset AESTACK_BASE			;add the base of stack

		mov		[bx],dx					;store the number

		inc		BYTE PTR [AESTACK_POINTER]	;store the new pointer value

		mov		al,01h

		ret

	ILM_LIT_stack_err:
		mov		[ERROR_CODE],offset ERROR_AESTACK_OVERFLOW
		call	ILM_ERR
		xor		al,al
		ret
        
        
;%INCLUDE "SRC/ILM/ILM_LST.ASM"
;==============================================================================
; LST
; List the contents of the program area.
;==============================================================================
LINE_COUNTER	db 00h					;line counter
PAGE_BREAK		db 00h					;page break
;------------------------------------------------------------------------------
ILM_LST:
		mov		[PAGE_BREAK],BYTE PTR 00h	;keep track of how many lines printed
		mov		[LINE_COUNTER],BYTE PTR 01h	;reset counter variable
		mov		di,PGM+COLS				;init DI at the line number 1
		
	ILM_LST_cycle:
		cmp		di,PGM+256*80			;is this the last line ?
		jge		ILM_LST_done					;if yes exit

		cmp		[di],BYTE PTR 00h			;is an empty line ?
		je		ILM_LST_next					;skip it

		xor		dx,dx					;clear dx
		mov		dl,[LINE_COUNTER]		;get the line counter
		call	PRINT_NUMBER			;print the line number

		mov		dx,di					;copy the start of the line
		call	PRINT_STR				;call print line
		call	ILM_NLINE				;add a new line

		inc		BYTE PTR [PAGE_BREAK]		;increase line printed
		cmp		BYTE PTR [PAGE_BREAK],ROWS-1;less than screen row ? (-1 cause CRLF)
		jb		ILM_LST_next					;yep, continue

		call	WAIT_KEY				;wait for key press
		mov		BYTE PTR [PAGE_BREAK],00h	;reset counter

	ILM_LST_next:

		add		di,COLS					;move to the next line
		inc		BYTE PTR [LINE_COUNTER]		;increase line counter
		jmp		ILM_LST_cycle					;repeat

	ILM_LST_done:
		ret


;%INCLUDE "SRC/ILM/ILM_MUL.ASM"
;==============================================================================
; MUL
; Replace top two elements of AESTK by their product.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_MUL:
        xor     bx,bx                   ;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,02h					;not enough elements
        jb     	ILM_MUL_stack_err

        dec     bl						;get top stack
		shl		bl,1					;mult by 2
		add		bx,offset AESTACK_BASE			;add stack base address

		mov		ax,[bx]					;get second element in AX

		dec		bx						;decrease address by 2
		dec		bx

		imul	word [bx]				;multiply
		jo		ILM_MUL_number_err

		mov		[bx],ax					;store result

		dec		BYTE PTR [AESTACK_POINTER]	;decrease stack pointer

		mov		al,01h

		ret

    ILM_MUL_stack_err:
		mov		[ERROR_CODE],offset ERROR_AESTACK_UNDERFLOW
		jmp		ILM_MUL_err

	ILM_MUL_number_err:
		mov		[ERROR_CODE],offset ERROR_NUMBER_OVERFLOW
		
	ILM_MUL_err:
		call 	ILM_ERR
		xor		al,al
		ret
		
;%INCLUDE "SRC/ILM/ILM_NEG.ASM"
;==============================================================================
; NEG
; Replace top of AESTK with its negative.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_NEG:

        xor     bx,bx                   ;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,00h					;if zero stack empty
        jbe     ILM_NEG_stack_err

        dec     bl						;go to first element

		shl		bl,1					;mult by 2

		add		bx,offset AESTACK_BASE			;add stack base

		neg		word [bx]				;negate it

		mov		al,01h

		ret

    ILM_NEG_stack_err:
		mov		[ERROR_CODE],offset ERROR_AESTACK_UNDERFLOW
		call	ILM_ERR
		xor		al,al
		ret
    
    
;%INCLUDE "SRC/ILM/ILM_NLINE.ASM"
;==============================================================================
; NLINE
; Output CRLF to Printer.
;==============================================================================
ILM_NLINE:
		mov     ah,0Eh                  ;teletype print interupt
        mov 	al,0Dh                 	;CR
        mov     bh,00h                  ;page
        int     10h                     ;call interrupt
		
		mov		al,0Ah					;LF
		int     10h 					;call interrupt

		ret
		
;%INCLUDE "SRC/ILM/ILM_NXT.ASM"
;==============================================================================
; NXT	
; If the present mode is direct (line number zero), return to line collection. 
; Otherwise, select the next line and begin interpretation.
;
; Return:
; AL == 0 must jump to CO, 1 must jump to XEC
;==============================================================================
ILM_NXT:
        
        cmp		[MODE],BYTE PTR 00h			;is direct ?
		je		ILM_NXT_collection				;return to collect 

		mov		bx,[PGP]				;get the PGP
	
	ILM_NXT_cycle:
		add		bx,COLS

		cmp		bx,PGM+(256*80)			;is this the last line ?
		jge		ILM_NXT_err					;err, we are outside of program

		cmp		[bx],BYTE PTR 00h			;is empty line ?
		je		ILM_NXT_cycle

	ILM_NXT_done:	
		mov		[PGP],bx				;next line
		mov		[CURSOR],bx				;set cursor to beginning of the line
		mov		al,01h					;set return to STMT
		ret

	ILM_NXT_err:
		sub		bx,COLS					;get last valid line
		mov		[PGP],bx				;copy it in PGP

		mov		[ERROR_CODE],offset ERROR_PGP
		call	ILM_ERR

	ILM_NXT_collection:
		xor		al,al					;set for return to collection
		ret


;%INCLUDE "SRC/ILM/ILM_PRN.ASM"
;==============================================================================
; PRN
; Print number obtained by popping the top of the expression stack.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_PRN:
        xor     bx,bx                   ;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,01h					;at least one element
        jl     	ILM_PRN_stack_err

        dec     bl						;get top stack
		shl		bl,1					;mult by 2
		add		bx,offset AESTACK_BASE			;add stack base address

		mov		dx,[bx]					;top of stack

		call	PRINT_NUMBER

		dec		BYTE PTR [AESTACK_POINTER]	;decrease stack pointer

		mov		al,1					;exit success

		ret

    ILM_PRN_stack_err:
		mov		[ERROR_CODE],offset ERROR_AESTACK_UNDERFLOW
		call	ILM_ERR
		xor		al,al
		ret


;%INCLUDE "SRC/ILM/ILM_PRS.ASM"
;==============================================================================
; PRS
; Print characters from the BASIC text up to but not including the
; closing quote mark. 
; If a cr is found in the program text, report an error. 
; Move the cursor to the point following the closing quote.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_PRS:
        mov		si,[CURSOR]

	ILM_PRS_cycle:
		cmp		[si],BYTE PTR 00h			;EOL ?
		je		ILM_PRS_err					;error

		cmp		[si],BYTE PTR 22h			;double quotes found ?
		je		ILM_PRS_done					;done

		mov		al,[si]
		mov     ah,0Eh                  ;interrupt 10h code (teletype print)
        mov     bh,00h                  ;interrupt 10h page 0
		int		10h

		inc 	si						;advance to next char

		jmp		ILM_PRS_cycle

	ILM_PRS_err:
		mov		[ERROR_CODE],offset ERROR_QUOTES
		call	ILM_ERR
		xor		al,al
		ret

	ILM_PRS_done:
		inc		si						;move one pos after double quotes
		mov		[CURSOR],si				;save cursor
		mov		al,01h
        ret
        
;%INCLUDE "SRC/ILM/ILM_RSTR.ASM"
;==============================================================================
; RSTR
; Replace current line number with value on SBRSTK.
; If stack is empty, report error.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;
;NOTE : we push the address of line
;==============================================================================
ILM_RSTR:
        xor     bx,bx                  	;clear bx

        mov     bl,[SBRSTACK_POINTER]   ;get stack pointer

		cmp     bl,00h					;if zero stack empty
        jbe     ILM_RSTR_stack_err

        dec     bl						;go to first element

		add		bx,offset SBRSTACK_BASE		;add stack base

		xor		ax,ax					;clear DX

		mov 	al,[bx]					;copy line number in DL

		mov		cl,COLS					;set CL as line multiplier

		mul		cl						;multiply by cols

		add		ax,PGM					;add PGM base

		mov		[PGP],ax				;store it in PGP

		dec		BYTE PTR [SBRSTACK_POINTER]	;store the new pointer value

		mov		al,01h

		ret

    ILM_RSTR_stack_err:
		mov		[ERROR_CODE],offset ERROR_SBRSTACK_UNDERFLOW
		call	ILM_ERR
		xor		al,al
		ret
		
;%INCLUDE "SRC/ILM/ILM_SAV.ASM"
;==============================================================================
; SAV
; Push present line number on SBRSTK. Report overflow as error.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_SAV:
		
		xor		bx,bx					;clear bx

        mov		bl,[SBRSTACK_POINTER] 	;get current stack pointer
		cmp		bl,MAX_STACK			;greatest of max elements ?
		jae		ILM_SAV_stack_err				;if yes error

		add		bx,offset SBRSTACK_BASE		;add the base of stack

		mov		ax,[PGP]				;get the current line address

		sub		ax,PGM					;subtract the base stack address

		mov		cl,COLS					;we use CL as divider

		div		cl						;divide AX by CL

		xor		ah,ah					;clear remainder

		mov		[bx],ax					;store the line address

		inc		BYTE PTR [SBRSTACK_POINTER]	;store the new pointer value

		mov		al,01h

		ret

	ILM_SAV_stack_err:
		mov		[ERROR_CODE],offset ERROR_SBRSTACK_OVERFLOW
		call	ILM_ERR
		xor		al,al
		ret
		
;%INCLUDE "SRC/ILM/ILM_SPC.ASM"
;==============================================================================
; SPC
; Insert spaces, to move the print head to next zone.
;==============================================================================
ILM_SPC:
        mov		al,20h					;space
		mov     ah,0Eh                  ;interrupt 10h code (teletype print)
        mov     bh,00h                  ;interrupt 10h page 0
		int		10h
		
        ret
        
;%INCLUDE "SRC/ILM/ILM_STORE.ASM"
;==============================================================================
; STORE
; Place the value at the top of the AESTK 
; into the variable designated by the index specified by the value immediately 
; below it. Delete both from the stack.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_STORE:

        xor     bx,bx                   ;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,02h					;not enough elements
        jb     	ILM_STORE_stack_err

        dec     bl						;get top stack
		shl		bl,1					;mult by 2
		add		bx,offset AESTACK_BASE			;add stack base address

		mov		ax,[bx]					;get the value in AX

		dec		bx						;decrease address by 2
		dec		bx

		mov		di,[bx]					;get in DI the variable index

		shl		di,1					;mult by 2

		add		di,offset VARIABLES			;add base address for variables

		mov		[di],ax					;store the value

		dec		BYTE PTR [AESTACK_POINTER]	;decrease stack pointer
		dec		BYTE PTR [AESTACK_POINTER]

		mov		al,1					;exit success

		ret

    ILM_STORE_stack_err:
		mov		[ERROR_CODE],offset ERROR_AESTACK_UNDERFLOW
		call	ILM_ERR					;return 0 on fail
		xor		al,al
		ret
		
;%INCLUDE "SRC/ILM/ILM_SUB.ASM"
;==============================================================================
; SUB
; Replace top two elements of AESTK by their difference.
;
; Return:
; AL = 0 if fail, 1 on success (if fail, main must jump back to collection)
;==============================================================================
ILM_SUB:
        xor     bx,bx                   ;clear bx

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,02h					;not enough elements
        jb     	ILM_SUB_stack_err

        dec     bl						;get top stack
		shl		bl,1					;mult by 2
		add		bx,offset AESTACK_BASE			;add stack base address

		mov		ax,[bx]					;get second element in DX

		dec		bx						;decrease address by 2
		dec		bx

		sub		[bx],ax					;store result of sub

		dec		BYTE PTR [AESTACK_POINTER]	;decrease stack pointer

		mov		al,01h
		ret

    ILM_SUB_stack_err:
		mov		[ERROR_CODE],offset ERROR_AESTACK_UNDERFLOW
		call	ILM_ERR
		xor		al,al
		ret
		
;%INCLUDE "SRC/ILM/ILM_TST.ASM"
;==============================================================================
; TST lbl,'string'
; Delete leading blanks 
; If string matches the BASIC line, advance cursor over the 
; matched string and execute the next IL instruction.
; If a match fails, execute the IL instruction at the labled lbl.
;
; Expect :
; DX == the string to compare
;
; Return :
; AL == 0 no match, 1 match success
;
; NOTE: if match, [CURSOR] point to first element after matched string
;==============================================================================	
ILM_TST:
		mov		ax,[CURSOR]				;use AX as cursor bkup
		mov		si,ax					;we use SI as byte pointer of string

	ILM_TST_skip_blanks:
		cmp		[si],BYTE PTR 00h			;is EOL ?
		je		ILM_TST_nomatch				;possible error

		cmp		[si],BYTE PTR 20h			;is a blank ?
		ja		ILM_TST_compare				;no, check the string
		
		inc		si						;increase position

		jmp		ILM_TST_skip_blanks			;check next char

	ILM_TST_compare:
		xor		cx,cx					;clear CX (counter of strlen)
		mov		bx,dx					;copy in BX the start of the string

	ILM_TST_strlen:							;calculate the len of the string
		cmp		[bx],BYTE PTR 00h
		je		ILM_TST_strcmp
		inc 	bx
		inc		cx
		jmp		ILM_TST_strlen

	ILM_TST_strcmp:
		mov     di,dx     				;DX is the start of the str to compare
        repe    cmpsb           		;equals ?
        jne     ILM_TST_nomatch        		;nope

	ILM_TST_match: 							;if here strings are equals
		mov		[CURSOR],si				;update the cursor position
		mov		al,01h
		ret

	ILM_TST_nomatch:
		mov		[CURSOR],ax				;restore cursor position
		xor		al,al
		ret
		
;%INCLUDE "SRC/ILM/ILM_TSTL.ASM"
;==============================================================================
; TSTL lbl 	
; After editing leading blanks, look for a line number. 
; Report error if invalid.
; Transfer to lbl if not present.
;
; Return :
; AL == line number, -1 on error
; SI == index of first element after the line number
;==============================================================================
ILM_TSTL:
		xor		ax,ax					;clear AX
		mov		ch,10					;set CH as multiplier

		mov		bx,offset LBUF					;get the base address of buffer
		mov		si,00h					;we use SI as index

	ILM_TSTL_skip_blanks:						;skip leading blanks
		mov		cl,[bx+si]				;get in CL the current char
		cmp		cl,00h					;is EOL ?
		je		ILM_TSTL_done

		cmp 	cl,BYTE PTR 20h				;is a BLANK ?
		jg		ILM_TSTL_get_number				;no go to check if number is present
		inc		si						;next char
		jmp		ILM_TSTL_skip_blanks			;repeat skip blanks loop

	ILM_TSTL_get_number:						;check if we have line number

		mov		cl,[bx+si]				;get in cl the current char

		cmp 	cl,30h					;is less than 0 ?
		jl		ILM_TSTL_done

		cmp 	cl,39h					;is greater than 9 ?
		jg		ILM_TSTL_done

		sub 	cl,30h					;convert CL ascii to a number 0..9

		mul 	ch						;multiply the content of AL for 10
		jc		ILM_TSTL_err					;if carry error

		add		al,cl					;add the the CL value
		jc		ILM_TSTL_err					;if carry error
		
		inc 	si						;next char
		jmp		ILM_TSTL_get_number 			;repeat

	ILM_TSTL_done:												
		cmp		ax,00h					;do we have a line number ?
		jne		ILM_TSTL_blank					;if yes verify we are on blank
		ret

	ILM_TSTL_blank:
		cmp		[bx+si],BYTE PTR 20h		;we should have a blank after line num
		jg		ILM_TSTL_err					;if not error
		ret

	ILM_TSTL_err:
		mov		[ERROR_CODE],offset ERROR_LINE_NUMBER 
		call	ILM_ERR
		mov		al,-1
		ret


;%INCLUDE "SRC/ILM/ILM_TSTN.ASM"
;==============================================================================
; TSTN lbl
; Test for number. 
; If present, place its value onto the AESTK and continue execution 
; at next suggested location. Otherwise continue at lbl.
;
; Return:
; AL == -1 on error ( should return to CO )
; AL == 0 if no match
; AL == 1 on success 
;
; NOTE: if match, [CURSOR] point to first element after the number
;==============================================================================
ILM_TSTN:
		xor		ch,ch					;clear high part of CX
		xor		ax,ax					;clear AX
		mov		bx,10					;set BX as multiplyer
		mov		di,0					;set DI for positive sign

		mov		si,[CURSOR]				;init SI with current cursor position

    ILM_TSTN_skip_blanks:						;skip leading blanks
		cmp		[si],BYTE PTR 00h			;is EOL ?
		je		ILM_TSTN_not_found

		cmp 	[si],BYTE PTR 20h			;is a BLANK ?
		ja		ILM_TSTN_check_sign				;no go to check if is a sign
		
		inc		si						;next char
		jmp		ILM_TSTN_skip_blanks			;repeat skip blanks loop
        
	ILM_TSTN_check_sign:
		cmp		[si],BYTE PTR 2Bh			;check '+'
		je		ILM_TSTN_skip_sign

		cmp		[si],BYTE PTR 2Dh			;check '-'
		jne		ILM_TSTN_get_number
	
		mov		di,1					;set DI for sign change

	ILM_TSTN_skip_sign:
		inc		si

	ILM_TSTN_check_number:						;if not number exit
		cmp 	[si],BYTE PTR 30h
		jl		ILM_TSTN_not_found
		cmp 	[si],BYTE PTR 39h
		jg		ILM_TSTN_not_found

	ILM_TSTN_get_number:
		
		mov		cl,[si]					;get in CL the current char

		cmp 	cl,30h					;is less than 0 ?
		jl		ILM_TSTN_fix_sign

		cmp 	cl,39h					;is greater than 9 ?
		jg		ILM_TSTN_fix_sign

		sub 	cl,30h					;convert CL ascii to a number 0..9

		mul 	bx						;multiply the content of AX for 10
		jo		ILM_TSTN_number_err				;if overflow error

		add		ax,cx					;add the the CX value
		jo		ILM_TSTN_number_err				;if overflow error
		
		inc 	si						;next char
	
		jmp		ILM_TSTN_get_number 			;repeat

	ILM_TSTN_fix_sign:
		cmp		di,00h					;was negative ?
		je		ILM_TSTN_done					;nope
		neg		ax						;yes, negate it
						
	ILM_TSTN_done:
		mov		dx,ax
		call	ILM_LIT
		cmp		al,00h
		jne		ILM_TSTN_done_ok
		mov		al,-1					;err
		ret								

	ILM_TSTN_done_ok:
		mov		[CURSOR],si				;update cursor
		mov		al,01h					;exit success
		ret

	ILM_TSTN_number_err:
		mov		[ERROR_CODE],offset ERROR_NUMBER_OVERFLOW
		call	ILM_ERR
		mov		al,-1
		ret

	ILM_TSTN_not_found:
		xor		al,al
		ret


;%INCLUDE "SRC/ILM/ILM_TSTV.ASM"
;==============================================================================
; TSTV lbl
; Test for variable (i.e letter) if present.
; Place its index value onto the AESTK and continue execution at next suggested
; location. 
; Otherwise continue at lbl.
;
; Return:
; AL == -1 on error ( should return to CO )
; AL == 0 if no match
; AL == 1 on success 
;
; NOTE: if match, [CURSOR] point to first element after matched string
;==============================================================================
ILM_TSTV:
        mov     si,[CURSOR]

    ILM_TSTV_skip_blanks:
		cmp		[si],BYTE PTR 00h			;is EOL ?
		je		ILM_TSTV_nomatch				;possible error

		cmp		[si],BYTE PTR 20h			;is a blank ?
		ja		ILM_TSTV_check					;no, check for var
		
		inc		si						;increase position

		jmp		ILM_TSTV_skip_blanks			;check next char

	ILM_TSTV_check:
		cmp		[si],BYTE PTR 41h			;less than 'A' ?
		jb		ILM_TSTV_nomatch

		cmp		[si],BYTE PTR 5Ah			;greater than 'Z' ?
		ja		ILM_TSTV_nomatch

		xor		dh,dh
		mov		dl,BYTE PTR [si]			;convert ascii char to index
		sub		dl,41h

	ILM_TSTV_done:
		call	ILM_LIT					;dx already contains tha val
		cmp		al,00h
		jne		ILM_TSTV_done_ok
		mov		al,-1					;err
		ret								

	ILM_TSTV_done_ok:
		inc 	si						;advance SI to element after letter
		mov		[CURSOR],si				;update CURSOR

		mov		al,1					;exit success
		ret

	ILM_TSTV_nomatch:							;match fail
		xor		al,al
		ret
		
;%INCLUDE "SRC/ILM/ILM_XPER.ASM"
;==============================================================================
; XPER
; Test value at the top of the AE stack to be within range.
; If not,report an error.
; If in range, attempt to position cursor at that line. 
; If it exists, begin interpretation there.
; If not report an error.
;
; Return:
; AL = 0 on error should jump back to CO
; AL = 1 on success should jump to XEC
;==============================================================================
ILM_XPER:

		mov		dl,COLS					;set DL as line multiplier

        xor     bx,bx                   ;clear BX

        mov     bl,[AESTACK_POINTER]    ;get stack pointer

		cmp     bl,00h					;if zero stack empty
        jbe     ILM_XPER_stack_err

        dec     bl						;go to first element

		shl		bl,1					;mult by 2

		add		bx,offset AESTACK_BASE			;add stack base

		mov		ax,[bx]					;in AX line number index

		cmp		ax,00h					;less than 1?
		jle		ILM_XPER_pgp_err

		cmp		ax,0FFh					;greater than 255 ?
		jg		ILM_XPER_pgp_err

		xor		ah,ah					;clear high part of ax
		mul		dl

		add		ax,PGM					;add PGM base

		mov		si,ax					;check for empty line
		cmp		[si],BYTE PTR 00h
        je      ILM_XPER_empty_err

		mov		[PGP],si				;set line
		mov		[CURSOR],si				;reset cursor

		mov		al,01h

		ret

	ILM_XPER_stack_err:
		mov		[ERROR_CODE],offset ERROR_AESTACK_UNDERFLOW
		jmp		ILM_XPER_err

	ILM_XPER_pgp_err:
		mov		[ERROR_CODE],offset ERROR_PGP
		jmp		ILM_XPER_err

	ILM_XPER_empty_err:
		mov		[ERROR_CODE],offset ERROR_EMPTY_LINE

	ILM_XPER_err:
		call	ILM_ERR
		xor		al,al
		ret
		
;%INCLUDE "SRC/ILM/ILM_XINIT.ASM"
;==============================================================================
; XINIT
; Perform initialization for each stated execution. 
; Empties AEXP stack.
;==============================================================================
ILM_XINIT:
		mov		[AESTACK_POINTER],BYTE PTR 00h
		ret
		
;==============================================================================
; Vars section
;==============================================================================
;welcome string
STR_WELCOME		db "TINY BASIC 8086",0Ah,0Dh,"Vers.2023 by Honny",00h	

;list of language keywords
STR_REM			db "REM",00h
STR_LET			db "LET",00h
STR_GOTO		db "GOTO",00h	
STR_GOSUB		db "GOSUB",00h	
STR_END			db "END",00h	
STR_PRINT		db "PRINT",00h				
STR_LIST		db "LIST",00h				
STR_RUN			db "RUN",00h
STR_RESET		db "RESET",00h
STR_RETURN		db "RETURN",00h
STR_INPUT		db "INPUT",00h
STR_IF			db "IF",00h
STR_THEN		db "THEN",00h

STR_COMMA		db ',',00h
STR_QUOTES		db '"',00h
STR_ASSIGN		db '=',00h
STR_MINUS		db '-',00h
STR_PLUS		db '+',00h
STR_MUL			db '*',00h
STR_DIV			db '/',00h
STR_LPAREN		db '(',00h
STR_RPAREN		db ')',00h

;list of logic operators
STR_OP_E		db "==",00h
STR_OP_NE		db "!=",00h
STR_OP_LE		db "<=",00h
STR_OP_GE		db ">=",00h
STR_OP_L		db "<",00h
STR_OP_G		db ">",00h

;error flag and list of available errors
ERROR_CODE					dw 0000h

ERROR_STR					db "ERROR",00h
ERROR_STR_AT_LINE			db "ERROR at line ",00h
ERROR_SYNTAX				db ":Syntax error",00h					
ERROR_LINE_NUMBER			db ":Invalid line number",00h
ERROR_EMPTY_LINE			db ":Empty line",00h
ERROR_PGP 					db ":PGP out of range",00h
ERROR_QUOTES				db ":Missing quotes",00h
ERROR_INVALID_NUMBER		db ":Number invalid",00h
ERROR_NOT_NUMBER			db ":Not a number",00h
ERROR_NUMBER_OVERFLOW		db ":Number out of range",00h
ERROR_AESTACK_OVERFLOW		db ":Arithmetic stack overflow",00h
ERROR_AESTACK_UNDERFLOW		db ":Arithmetic stack underflow",00h
ERROR_SBRSTACK_OVERFLOW		db ":Subroutines stack overflow",00h
ERROR_SBRSTACK_UNDERFLOW	db ":Subroutines stack underflow",00h
ERROR_DIVIDE_ZERO			db ":Divide by zero",00h
ERROR_OPERATOR				db ":Invalid operator",00h
ERROR_MODE					db ":Unavailable for current mode",00h

;ILM variables
MODE			db 00h						;0==direct, 1==run

VARIABLES		dw 26 dup(0000h)			;Variables A,B,C...Z 

AESTACK_BASE	dw MAX_STACK dup(0000h)	;Arithmetic Expression stack
AESTACK_POINTER db 00h

SBRSTACK_BASE	db MAX_STACK dup(00h)		;Subroutines stack
SBRSTACK_POINTER db 00h

LBUF 			db COLS dup(00h)			;the reading buffer
CURSOR			dw	0000h					;Cursor (byte pointer)
PGP				dw	0000h					;PGP (line pointer)
PGM				dw	0000h
;PGM				times 256 * COLS db 00h		;the PGM area (256 lines * 80 byte)

