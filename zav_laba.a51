;* Copyright (c) 2018 Gleb aka illuser
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;* There are some moments, that can be removed, changed or modified, but i'm
;* too lazy for making edits. I'm leaving it for you, enjoy :D
;* * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * * *
;* Commands: enter code, left cycle shift and right cycle shift
;* Registers:	R0 - command counter; R1 - error counter; R2 - programm counter 
;*				R3 - buffer for DINIT funcrion; R4 - size of first string
;*				R5 - size of second string; R6 - input position counter
;*				R7 - second programm counter
;*			8150h - buf for strings
;* Messages:              	M_1: 8000h - 'Enter #'
;*				M_2: 8010h - 'Wrong input'
;*				M_3: 8020h - 'Enter command'
;*				M_4: 8030h - 'Input code'
;*				M_5: 8040h - 'Left shift'
;*				M_6: 8050h - 'Right shift'
;*				M_7: 8060h - 'Block'
;*				M_8: 8070h - 'Enter error:3-1,4-0,A-r,1A-e' (2 rows)
;*				M_9: 8090h - 'Enter ended: $NUM_STORE' (2 rows, in memory 1)
;*				M_10:80A0h - 'Enter error:55 +,66 -,B 1/2' (2 rows)
;*				M_11:80C0h - 'Shift left:[55,]?[66,]?B'
;*				M_12:80D0h - 'Shift right:[55,]?[66,]?'
;*				M_13:80E0h - 'Error:'
;* All strings are written in 'MyVDP.dmp' for put in external memory further 
;* Stack starts from [40H](4-th bank), is used only for saving DPTR


P4 EQU 0C0h						;port 4 (lights A and B)
INT1F EQU 00h					;INT1 my flag
T0F EQU 01h						;T1 my flag
BLKF EQU 02h					;block-programm flag
SECSTRF EQU 03h					;second string for print flag
DOUBL_SH EQU 04h					;flag of double shift
CUR_BIT EQU 08h					;current "editable" bit in input command,SIZE=BYTE
NUM_STORE EQU 09h				;number in memory, gained in input command	
SHIFT_PER EQU 0Ah				;period of shift
PERIOD EQU 0Bh
;ZNAK_PERIOD EQU 0Ch
ORG 8000h
	JMP start
;************************************************************
ORG 800Bh					;timer t1
	LCALL TIM_INT			;not used yet
	RETI
	
ORG 8013h					;keyboard
	LCALL KEY_INT				;call keyboard interrupt handler
	RETI
;** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** **

;***PROGRAMM START************************************************************

start:
	LJMP INIT
INIT:
	MOV IE, #86h				;allow INT1 and T1 interruption
	MOV TMOD, #10h				;T1 works as 16-bit counter
	CLR TF1						;set timer overflow at zero
	CLR TR1						;turn off timer
	CLR INT1F					;clear flag INT1F
	CLR T0F						;clear flag T1F
	CLR BLKF					;clear flag BLKF
	MOV DPTR,#7FFFh				;left enter on indicator
	MOV A,#01h
	MOVX @DPTR,A
	MOV DPTR,#7FFFh				;write in video-memory without incrementation
	MOV A,#80h
	MOVX @DPTR,A
	MOV SP, #40h				;init stack from 4-th bank
	MOV r0, #0h					;init comand counter
	MOV r1, #0h					;init error counter
	MOV r2, #0h					;init programm counter
	MOV NUM_STORE, #0h			;init memory for number
;---INIT DISPLAY--------------------------------------------------------------
	MOV A,#38H					;init 2 rows
	LCALL WAIT_FOR_DISPLAY 
	MOV A,#0CH  				;turn on display
	LCALL WAIT_FOR_DISPLAY
	MOV A,#06H 					;init cursor right shift
	LCALL WAIT_FOR_DISPLAY
	MOV A,#02H					;set video-counter on zero
	LCALL WAIT_FOR_DISPLAY					;	and save memory(probably can delete this part)
	MOV A,#01H					;clear display and set video-counter on zero
	LCALL WAIT_FOR_DISPLAY
;-----------------------------------------------------------------------------
BEGIN:
	MOV A, #1h					;print Message M_1
	LCALL MESSAGE_PRINT
	LCALL IND_CNT
	LCALL WAIT_FOR_SHARP
COMMAND_ENTER:					;cycle for command enter
	MOV A, #3h					;print Message M_3
	LCALL MESSAGE_PRINT
	LCALL CMD_CHOICE			;go to command choice
	JB BLKF, EXIT_PROG			;jump on Blocking function (now just for debug) 
	LJMP COMMAND_ENTER
EXIT_PROG:					;Looping
	MOV IE, #0h					;block all interruptions
	MOV A, #9h					;print Message M_9
	LCALL MESSAGE_PRINT
	LJMP $						;TODO - add print 'BLOCK' message
;** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** ** **

;***SECONDARY FUNCTIONS*******************************************************
WAIT_FOR_SHARP:
	JNB INT1F, $				;wait for keyboard
	CLR INT1F
	CJNE A, #11011010B, WAIT_FOR_SHARP	;is it '#'?
	JNB INT1F, $				;wait for keyboard
	CLR INT1F
	CJNE A, #11011010B, WAIT_FOR_SHARP	;is it '#'?
	RET
	
;---Command choice (keys handler)---------------------------------------------
CMD_CHOICE:
	JNB INT1F, $					;wait key
	CLR INT1F
KEY_C:
	CJNE A, #11010011B, KEY_8		;is it key 'C'
	MOV r1, #0h						;clear error counter
	MOV A, #3h						;print Message M_3
	LCALL MESSAGE_PRINT
	LCALL KEY8_ANALYZE				;analyze key '8'
	JB BLKF, CMD_CHOICE_EXIT		;is it BLOCK
	LCALL KEY2_ANALYZE				;analyze key '2'
	JB BLKF, CMD_CHOICE_EXIT		;is it BLOCK
	LCALL LSHIFT_COMMAND			;call command Left Shift
	INC r0							;increase command counter
	LCALL IND_CNT					;print command counter on indicator
	LJMP BEGIN                         ;exit from command BEGIN                         
	
	
	
	
	
KEY_8:

	CJNE A, #11010001B, KEY_ERROR		;is it key '8'
	MOV r1, #0h						;next is simmilar to KEY_1
	MOV A, #3h			
	LCALL MESSAGE_PRINT




	KEY_9:	
	      JNB INT1F, $
	      CLR INT1F

	      CJNE A, #11010010B, KEY_C2		;is it key '9'
	      MOV r1, #0h						;next is simmilar to KEY_1
	      MOV A, #3h						
	      LCALL MESSAGE_PRINT
		  LCALL INPUT_COMMAND			;call command input
	      INC r0						;increase command counter
	      LCALL IND_CNT					;print command counter on indicator
	      LJMP BEGIN                         ;exit from command BEGIN    
		  
	        
		






	
	 	
    KEY_C2:	
	        CJNE A, #11010011B, KEYC2_ERR             ;is it key 'C'
		MOV r1, #0h						
	        MOV A, #3h						
	        LCALL MESSAGE_PRINT  	
	        LCALL KEY3_ANALYZE				;analyze key '3'
	        JB BLKF, CMD_CHOICE_EXIT		;is it BLOCK
        	LCALL OUTPUT_COMMAND			;call command output
        	INC r0							;increase command counter
        	LCALL IND_CNT					;print command counter on indicator
        	LJMP BEGIN                         ;exit from command BEGIN    


    KEYC2_ERR:
                LCALL IT_IS_ERROR				;call error handler
	        LCALL CHECK_ERR_LIMIT			;are we going to block
	        JNB BLKF, KEY_9





			
									
									
KEY_ERROR:							;no 'C', '8'
;    MOV P4, #00H
;	LJMP $
	LCALL IT_IS_ERROR				;call error handler
	LCALL CHECK_ERR_LIMIT			;are we going to block
	JNB BLKF, CMD_CHOICE			;return to begin of command choice if not block
CMD_CHOICE_EXIT:
;    MOV P4,#66h
;	LJMP $
    MOV A, #7h		                ;bkoking				
	LCALL MESSAGE_PRINT        
;	RET
	LJMP $
	;-----------------------------------------------------------------------------
	
;---Analyze key '3'-----------------------------------------------------------
KEY3_ANALYZE:						;similar to KEY1_ANALYZE
 
	JNB INT1F, $
	CLR INT1F
	CJNE A, #11000010B, KEY2_ERR	;is it key '3'
	MOV r1, #0h
	MOV A, #3h						
	LCALL MESSAGE_PRINT
	LJMP KEY3_EXIT
KEY3_ERR:
    MOV P4, #44H
	LJMP $
	LCALL IT_IS_ERROR				;call error handler
	LCALL CHECK_ERR_LIMIT			;are we going to block
	JNB BLKF, KEY3_ANALYZE
KEY3_EXIT:
	RET



;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
	
;---Analyze key '8'-----------------------------------------------------------
KEY8_ANALYZE:						;similar to KEY8_ANALYZE
	JNB INT1F, $
	CLR INT1F
	CJNE A, #11010001B, KEY8_ERR	;is it key '8'
	MOV r1, #0h
	MOV A, #3h						
	LCALL MESSAGE_PRINT
	LJMP KEY8_EXIT
KEY8_ERR:
	LCALL IT_IS_ERROR				;call error handler
	LCALL CHECK_ERR_LIMIT			;are we going to block
	JNB BLKF, KEY8_ANALYZE
KEY8_EXIT:
	RET



;-----------------------------------------------------------------------------
	
	

;---Analyze key '2'-----------------------------------------------------------	
KEY2_ANALYZE:						;similar to KEY1_ANALYZE
	JNB INT1F, $
	CLR INT1F
	CJNE A, #11000001B, KEY2_ERR	;is it key '2'
	MOV r1, #0h
	MOV A, #3h						
	LCALL MESSAGE_PRINT
	LJMP KEY2_EXIT
KEY2_ERR:
	LCALL IT_IS_ERROR				;call error handler
	LCALL CHECK_ERR_LIMIT			;are we going to block
	JNB BLKF, KEY2_ANALYZE
KEY2_EXIT:
	RET
;-----------------------------------------------------------------------------

;---Error analyzer------------------------------------------------------------
IT_IS_ERROR:
   
	INC r1							;increase error counter
	MOV A, #2h						;print Message M_2
	LCALL MESSAGE_PRINT
	RET

CHECK_ERR_LIMIT:
	CJNE r1, #4h, EXIT_FROM_ERR	;compare error counter with 4
	SETB BLKF						;so, we are coming to BLOCK
EXIT_FROM_ERR:
	RET
;-----------------------------------------------------------------------------

;---Command INPUT-------------------------------------------------------------
INPUT_COMMAND:
    
	MOV CUR_BIT, #00000001B			;init masc for current bit for edit
	MOV r6, #0h						;number of current bit
	MOV A, NUM_STORE				;mov to acc. Num from memory (0 or entered before)
	SWAP A
	MOV P4, A						;print on A and B lamps
	LCALL IND_POSITION				;print position of cur. bit on indicator
INPUT_KEY:
    MOV A, #4h						;print Message M_4
	LCALL MESSAGE_PRINT
INPUT_KEY_WHEN_ERR:
	JNB INT1F, $
	CLR INT1F
INPUT_0:
	CJNE A, #11011001B, INPUT_1		;is it '0'
	MOV CUR_BIT, #00000001b  ;mask for carrent bit
	MOV A, NUM_STORE
	XRL A, CUR_BIT
	MOV NUM_STORE, A
	MOV r6, #0h
	SWAP A
	MOV P4, A
	LCALL IND_POSITION  ;print current bit
	LJMP INPUT_KEY
INPUT_1:
	CJNE A, #11000000B, INPUT_2		;is it '1'
	MOV CUR_BIT, #00000010b  ;mask for carrent bit
	MOV A, NUM_STORE
	XRL A, CUR_BIT
	MOV NUM_STORE, A
	MOV r6, #1h
	SWAP A
	MOV P4, A
	LCALL IND_POSITION  ;print current bit
	LJMP INPUT_KEY
	
INPUT_2:
	CJNE A, #11000001B, INPUT_3		;is it '2'
	MOV CUR_BIT, #00000100b  ;mask for carrent bit
	MOV A, NUM_STORE
	XRL A, CUR_BIT
	MOV NUM_STORE, A
	MOV r6, #2h
	SWAP A
	MOV P4, A
	LCALL IND_POSITION  ;print current bit
	LJMP INPUT_KEY
			
INPUT_3:
	CJNE A, #11000010B, INPUT_4		;is it '3'
	MOV CUR_BIT, #00001000b  ;mask for carrent bit
	MOV A, NUM_STORE
	XRL A, CUR_BIT
	MOV NUM_STORE, A
	MOV r6, #3h
	SWAP A
	MOV P4, A
	LCALL IND_POSITION  ;print current bit
	LJMP INPUT_KEY
INPUT_4:
	CJNE A, #11001000B, INPUT_5		;is it '4'
	MOV CUR_BIT, #00010000b  ;mask for carrent bit
	MOV A, NUM_STORE
	XRL A, CUR_BIT
	MOV NUM_STORE, A
	MOV r6, #4h
	SWAP A
	MOV P4, A
	LCALL IND_POSITION  ;print current bit
	LJMP INPUT_KEY
INPUT_5:
	CJNE A, #11001001B, INPUT_6		;is it '5'
	MOV CUR_BIT, #00100000b  ;mask for carrent bit
	MOV A, NUM_STORE
	XRL A, CUR_BIT
	MOV NUM_STORE, A
	MOV r6, #5h
	SWAP A
	MOV P4, A
	LCALL IND_POSITION  ;print current bit
	LJMP INPUT_KEY
INPUT_6:
	CJNE A, #11001010B, INPUT_7		;is it '6'
	MOV CUR_BIT, #01000000b  ;mask for carrent bit
	MOV A, NUM_STORE
	XRL A, CUR_BIT
	MOV NUM_STORE, A
	MOV r6, #6h
	SWAP A
	MOV P4, A
	LCALL IND_POSITION  ;print current bit
	LJMP INPUT_KEY
INPUT_7:
	CJNE A, #11010000B, INPUT_D		;is it '7'
	MOV CUR_BIT, #10000000b  ;mask for carrent bit
	MOV A, NUM_STORE
	XRL A, CUR_BIT
	MOV NUM_STORE, A
	MOV r6, #7h
	SWAP A
	MOV P4, A
	LCALL IND_POSITION  ;print current bit
	LJMP INPUT_KEY	
INPUT_D:
	CJNE A, #11011011B, INPUT_ERROR		;is it 'D'	
	JNB INT1F, $
	CLR INT1F
	CJNE A, #11011011B, INPUT_ERROR		;is it 'D'	
	SWAP A
	MOV P4, A
	LJMP INPUT_EXIT
INPUT_ERROR:
	MOV A, #0Ah						;call error message
	LCALL MESSAGE_PRINT			
	MOV A, NUM_STORE
	LJMP INPUT_KEY_WHEN_ERR
INPUT_EXIT:
	
;	CLR TR0									;turn off T0 counter
;	CLR T0F									;clear my flag
;	CLR ET0									;turn off T0 interruptions
	MOV A, #09h								;print Message M_1
	LCALL MESSAGE_PRINT						
	MOV P4, A     ;print num							;print result on Display
	LCALL WAIT_FOR_SHARP					;wait for '#'
	RET	
	
	
IND_POSITION:	
MOV A,#90h 			;'write in memory' command
MOV DPTR,#7FFFh
MOVX @DPTR, A
MOV A, r6
MOV B, #08h	;position can be more than 7 or less then 0, so
DIV AB			;we take (position mod 8)
MOV A, B
MOV r6, A	;rewrite position
LCALL IND_PRINT			;print changed num on indicator
MOV A, NUM_STORE
RET
NUM_PRINT:
	MOV A, #0A8h							;choose next stroke on Display
	LCALL WAIT_FOR_DISPLAY
	MOV CUR_BIT, #10000000B					;set masc to left bit
	MOV r5, #8h								;amount of numbers	
	MOV B, #30h								;base cod of symbol code
	MOV A, NUM_STORE
	MOV r4, A								;buf for NUM_STORE
	PRINT_CIFR:								;cifr = 'cifra' in russian, it's my mistake
		MOV DPTR, #8150h					;set buf-place in outter memory
		MOV B, #30h							;reinit B
		MOV A, r4						
		RLC A								;shift A through bit C
		MOV r4, A							
		MOV SECSTRF, C						;just buffer flag, we can just use JNC
		JNB SECSTRF, CIFR_ZERO 				;if it is '1' we print '1' in Display (code #31h)
		INC B								;B := #31h
		CIFR_ZERO:
		MOV A, B							;print number
		MOVX @DPTR, A
		LCALL PRINT_LETTER
		DJNZ r5, PRINT_CIFR					;compare with end of whole number
	RET

	
	
	
	
;-----------------------------------------------------------------------------

;---Left Shift----------------------------------------------------------------
LSHIFT_COMMAND:
    MOV A, #5h								;print Message M_5
	LCALL MESSAGE_PRINT		
    CLR DOUBL_SH
	MOV A, NUM_STORE
	SWAP A
    MOV P4, A	
	MOV SHIFT_PER, #1dh						;shift period := 30 (30 * 0.1 sec = 3 sec)
	MOV r7, SHIFT_PER						;mov in programm counter shift period
	SETB ET0								;turn on T0 interruptions
	SETB TR0								;turn on T0 counter
	CLR T0F									;clear my flag
;	MOV PERIOD, #00h
	LCALL PRINT_PERIOD

LSH_FLAG_REVIEW:
	JB INT1F, INPUT_LSH_KEY					;wait for key
	JNB T0F, LSH_FLAG_REVIEW				;wait for timer
	LSH_NUM:
		CLR T0F								;clear my flag
		DJNZ r7, LSH_FLAG_REVIEW			;decrease and compare with zero
		MOV r7, SHIFT_PER					;reinit programm counter
		MOV A, NUM_STORE
		RL A								;1 shift 
		MOV NUM_STORE, A
		SWAP A
		MOV P4, A							;print on lamps changed Num
		LCALL PRINT_PERIOD
		LJMP LSH_FLAG_REVIEW				;return to Flag review
	INPUT_LSH_KEY:
		CLR INT1F								;clear my flag
		LSH_INPUT_65:
			CJNE A, #11001010B, LSH_INPUT_56	;is it '6'?
			JNB INT1F, $
			CLR INT1F
			CJNE A, #11001001B, LSH_INPUT_ERROR	;is it second '6'?
			MOV A, SHIFT_PER
			CJNE A, #14h, MUST_DEC				;compare period with minimum
			LJMP NOT_DEC						;not decrease if it is minimum
			MUST_DEC:
			DEC SHIFT_PER						;decrease period
	
			NOT_DEC:
			LCALL PRINT_PERIOD
			LJMP LSH_FLAG_REVIEW
		LSH_INPUT_56:
			CJNE A, #11001001B, LSH_INPUT_B		;is it '5'?
			JNB INT1F, $
			CLR INT1F
			CJNE A, #11001010B, LSH_INPUT_ERROR	;is it second '5'?
			MOV A, SHIFT_PER
			CJNE A, #28h, MUST_INC				;compare with maximum
			LJMP NOT_INC						;not increase if it is maximum
			MUST_INC:
			INC SHIFT_PER						;increase period
	
			NOT_INC:
			LCALL PRINT_PERIOD
			LJMP LSH_FLAG_REVIEW
		LSH_INPUT_B:
			CJNE A, #11010000B, LSH_INPUT_SHARP	;is it '7'?
			CPL ET0								 
			CPL TR0	
			CPL T0F	

			LJMP LSH_FLAG_REVIEW
		LSH_INPUT_SHARP:
			CJNE A, #11011010B, LSH_INPUT_ERROR	;is it '#'?
			JNB INT1F, $
			CLR INT1F
			CJNE A, #11011010B, LSH_INPUT_ERROR	;is it '#'?
			MOV P4, #00h
			CLR ET0								;turn off T0 interruptions
			CLR TR0								;turn off T0 counter
			RET
		LSH_INPUT_ERROR:
			MOV A, #0Bh							;print error messages
			LCALL MESSAGE_PRINT
			LCALL PRINT_PERIOD
			LJMP LSH_FLAG_REVIEW
			



	
PRINT_PERIOD:
    MOV A, #0A8h			;choose next stroke
	LCALL WAIT_FOR_DISPLAY
	MOV DPTR, #8150h
	MOV A, SHIFT_PER

	
PERIOD_0:                        ;if period=0
	CJNE A, #1dh, PERIOD_LITTLE                   ;if period=0
	MOV A, #4Fh
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	RET
PERIOD_LITTLE:	
    MOV A, SHIFT_PER
	MOV B,#10
	DIV AB
	CJNE A, #2, PERIOD_LITTLE
    MOV A, #2Dh							;'-'
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	MOV A, #1dh                    ;A=30
	SUBB A, SHIFT_PER              ;A=30-SHIFT_PER
	LCALL WHAT_SIMBOL_GKI
	RET
PERIOD_BIG:	
    MOV A, #2Bh							;'+'
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	MOV A, SHIFT_PER                 ;A=SHIFT_PER
	SUBB A,#1dh                      ;A=SHIFT_PER-30
	LCALL WHAT_SIMBOL_GKI
	RET

	
WHAT_SIMBOL_GKI:
	CJNE A, #0,WHAT_SIMBOL_GKI_1                 ; it is 0	
	MOV A, #4Fh
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	RET
WHAT_SIMBOL_GKI_1:
	CJNE A, #1,WHAT_SIMBOL_GKI_2                 ; it is 1	
	MOV A, #31h
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	RET
WHAT_SIMBOL_GKI_2:
	CJNE A, #2,WHAT_SIMBOL_GKI_3                 ; it is 2	
	MOV A, #32h
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	RET
WHAT_SIMBOL_GKI_3:
	CJNE A, #3,WHAT_SIMBOL_GKI_4                 ; it is 3	
	MOV A, #33h
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	RET
WHAT_SIMBOL_GKI_4:
	CJNE A, #4,WHAT_SIMBOL_GKI_5                 ; it is 4	
	MOV A, #34h
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	RET
WHAT_SIMBOL_GKI_5:
	CJNE A, #5,WHAT_SIMBOL_GKI_6                 ; it is 5	
	MOV A, #35h
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	RET
WHAT_SIMBOL_GKI_6:
	CJNE A, #6,WHAT_SIMBOL_GKI_7                 ; it is 6	
	MOV A, #36h
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	RET
WHAT_SIMBOL_GKI_7:
	CJNE A, #7,WHAT_SIMBOL_GKI_8                 ; it is 7	
	MOV A, #37h
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	RET
WHAT_SIMBOL_GKI_8:
	CJNE A, #8,WHAT_SIMBOL_GKI_9                 ; it is 8	
	MOV A, #38h
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	RET
WHAT_SIMBOL_GKI_9:
	CJNE A, #9,PERIOD_BIG                 ; it is 9	
	MOV A, #39h
	MOVX @DPTR, A
	LCALL PRINT_LETTER
	RET
WHAT_SIMBOL_GKI_10:
	CJNE A, #10,PERIOD_BIG                 ; it is 10	
	MOV A, #31h  
	MOVX @DPTR, A
	LCALL PRINT_LETTER                     ;print 1
	MOV A, #4Fh
	MOVX @DPTR, A
	LCALL PRINT_LETTER                     ;print 0
	RET
		
		

;----------------------------------------------------------------------------- 

;---Output Shift----------------------------------------------------------------
OUTPUT_COMMAND:
	MOV A, #6h								;print Message M_5
	LCALL MESSAGE_PRINT		
	CLR DOUBL_SH
	MOV A, NUM_STORE
	SWAP A
    MOV P4, A	
	MOV SHIFT_PER,#14h						;shift period := 20 (20 * 0.1 sec = 2 sec)
	MOV r7, SHIFT_PER						;mov in programm counter shift period
	SETB ET0								;turn on T0 interruptions
	SETB TR0								;turn on T0 counter
	CLR T0F	
	MOV PERIOD, #03h                       ;flag 3 or 1 you mast now, so if you input 67 period must stay =3
	OUT_FLAG_REVIEW:
	JB INT1F, INPUT_OUT_KEY					;wait for key
	JNB T0F, OUT_FLAG_REVIEW				;wait for timer
	OUT_NUM:
		CLR T0F								;clear my flag
		DJNZ r7, OUT_FLAG_REVIEW			;decrease and compare with zero
		MOV r7, SHIFT_PER					;reinit programm counter
		MOV A, NUM_STORE
		SWAP A
		MOV P4, A							;print on lamps changed Num
		LJMP OUT_FLAG_REVIEW				;return to Flag review
	INPUT_OUT_KEY:
		CLR INT1F								;clear my flag
		CJNE A, #11001010B, OUT_INPUT_SHARP	;is it '6'?
		JNB INT1F, $
		CLR INT1F
		CJNE A, #11010000B, OUT_INPUT_ERROR	;is it '7'?
		JNB INT1F, $
		CLR INT1F
		MOV A, SHIFT_PER
		
		
		CJNE A, #11001010B, PERIOD_13	;SHIFT_PER is 2?
		MOV A, PERIOD
	    CJNE A, #03h, PERIOD_1          ; you must be 3?
		MOV SHIFT_PER, #1Eh             ;  SHIFT_PER MUST BE 3
		MOV PERIOD, #01h
		LJMP OUT_FLAG_REVIEW
		PERIOD_1:
		    MOV SHIFT_PER, #0Ah             ;  SHIFT_PER MUST BE 1
		    MOV PERIOD, #03h
		    LJMP OUT_FLAG_REVIEW
	PERIOD_13:                          ;SHIFT_PER is 3 OR 2
	    MOV SHIFT_PER, #14h             ;  SHIFT_PER MUST BE 2
		LJMP OUT_FLAG_REVIEW
				
	OUT_INPUT_SHARP:
	    CJNE A, #11011010B, OUT_INPUT_ERROR	;is it '#'?
		JNB INT1F, $
		CLR INT1F
		CJNE A, #11011010B, OUT_INPUT_ERROR	;is it '#'?
		MOV P4, #00h
		CLR ET0								;turn off T0 interruptions
		CLR TR0								;turn off T0 counter
		RET
	OUT_INPUT_ERROR:
		MOV A, #0Ah							;print error messages
		LCALL MESSAGE_PRINT
		LCALL PRINT_PERIOD
		LJMP OUT_FLAG_REVIEW	
;-----------------------------------------------------------------------------

;---Key Interrupt handler-----------------------------------------------------
KEY_INT:
	SETB INT1F
	MOV DPTR,#7FFFh				;allow keyboard FIFO read
	MOV A,#40h				
	MOVX @DPTR,A
	MOV DPTR,#7FFEh				;read key into a
	MOVX A,@DPTR
	CJNE A,	#11011000B, KEY_INT_EXIT	;compare with '*'
	MOV r0, #0h					;clear command counter
	MOV r1, #0h					;clear error counter
	CLR INT1F					;clear INT1F flag
	LCALL IND_CNT
KEY_INT_EXIT:
	RET
;-----------------------------------------------------------------------------
;---Timer Interrupt handler---------------------------------------------------
TIM_INT:
	CLR TF0
	INC r2
	CJNE r2, #0Ch, TIM_INT_EXIT	;0.1 second
	SETB T0F
	MOV r2, #0h					;reinit r2
	TIM_INT_EXIT:
	RET
;-----------------------------------------------------------------------------
	
;---Show counter on Indicator-------------------------------------------------

PRINT:					;Show-on-Display
	PUSH dpl					;save DPTR in stack
	PUSH dph
	MOV A,#01H					;clear display
	LCALL WAIT_FOR_DISPLAY
	POP dph						;return DPTR from stack
	POP dpl
	LCALL PRINT_STRING			;call Put-String-in-Memory function
	JNB SECSTRF, EXIT_FROM_PRINT	;is there second string?
	MOV A, r5					;move size of second string at R4
	MOV r4, A
	PUSH dpl					;save DPTR in stack
	PUSH dph
	MOV A, #0A8h
	LCALL WAIT_FOR_DISPLAY
	POP dph						;return DPTR from stack
	POP dpl
	LCALL PRINT_STRING			;print second string
	EXIT_FROM_PRINT:
	RET

WAIT_FOR_DISPLAY:				;wait display and write in video-memory
	MOV R3,A					;save A in R3
	MOV DPTR,#7FF6H 
	BF:
		MOVX A,@DPTR			;compare ready-flag
		ANL A,#80H
		JNZ BF
	MOV DPTR,#7FF4H 			;write in video-memory
	MOV A,R3					;return A from R3
	MOVX @DPTR,A				
	RET

PRINT_STRING:					;Put-String-in-Memory
	LCALL PRINT_LETTER
	INC DPTR					;increase DPTR for next Letter
	DJNZ r4, PRINT_STRING		;'is it end of string?'
	RET
	
PRINT_LETTER:
	PUSH dpl					;save DPTR in stack
	PUSH dph					
	MOV DPTR,#7FF6H				;wait display
	WAIT_LAST:
		MOVX A,@DPTR			;compare ready-flag
		ANL A,#80H
		JNZ WAIT_LAST
	POP dph						;return DPTR from stack
	POP dpl
	movx A, @DPTR				;take Letter from memory
	PUSH dpl					;save DPTR in stack
	PUSH dph
	MOV DPTR,#7FF5H 			;write Letter in video-memory
	MOVX @DPTR,A
	POP dph						;return DPTR from stack
	POP dpl
	RET




IND_CNT:	
	MOV A,#92h 					;'write in memory' command
	MOV DPTR,#7FFFh
	MOVX @DPTR,A				
	MOV DPTR,#7FFEh
	MOV A, r0	
	MOV B, #100
	DIV AB						;take `r0 mod 100`
	JZ NOT_OVERFLOW
	MOV r0, B					;if r0 > 100, mov V to R0
		NOT_OVERFLOW:
	MOV A, B
	MOV B, #10
	DIV AB						;calculate '10' (`desatki`)	
	LCALL IND_PRINT				;write '10'
	MOV A, B
	LCALL IND_PRINT				;write '1' (`edinici`)
	MOV A, #0h					;not show oteher positions
	MOVX @DPTR,A
	MOVX @DPTR,A
	RET
	
IND_PRINT:						;just associate num with code
		MOV DPTR,#7FFEh
		CJNE A,#00h,CH1
		MOV A,#0F3h
		MOVX @DPTR,A
		LJMP EXIT_IND_PRINT
	CH1:
		CJNE A,#01h,CH2
		MOV A,#60h
		MOVX @DPTR,A
		LJMP EXIT_IND_PRINT
	CH2:
		CJNE A,#02h,CH3
		MOV A,#0B5h
		MOVX @DPTR,A
		LJMP EXIT_IND_PRINT
	CH3:
		CJNE A,#03h,CH4
		MOV A,#0F4h
		MOVX @DPTR,A
		LJMP EXIT_IND_PRINT
	CH4:
		CJNE A,#04h,CH5
		MOV A,#66h
		MOVX @DPTR,A
		LJMP EXIT_IND_PRINT
	CH5:
		CJNE A,#05h,CH6
		MOV A,#0D6h
		MOVX @DPTR,A
		LJMP EXIT_IND_PRINT
	CH6:
		CJNE A,#06h,CH7
		MOV A,#0D7h
		MOVX @DPTR,A
		LJMP EXIT_IND_PRINT
	CH7:
		CJNE A,#07h,CH8
		MOV A,#70h
		MOVX @DPTR,A
		LJMP EXIT_IND_PRINT
	CH8:
		CJNE A,#08h,CH9
		MOV A,#0F7h
		MOVX @DPTR,A
		LJMP EXIT_IND_PRINT
	CH9:
		MOV A,#0F6h
		MOVX @DPTR,A	
	EXIT_IND_PRINT:
		RET
;-----------------------------------------------------------------------------

;---Print Message according code----------------------------------------------
MESSAGE_PRINT:


	M_1:
		CJNE A, #01h, M_2
		MOV DPTR, #8000h				;'Enter #'
		MOV r4, #09h	
		CLR SECSTRF
		LCALL PRINT
		LJMP EXIT_TO_PRINT
	M_2:
		CJNE A, #02h, M_3
		MOV DPTR, #8010h				;'Wrong input'
		MOV r4, #0Eh	
		CLR SECSTRF
		LCALL PRINT
		LJMP EXIT_TO_PRINT
	M_3:
		CJNE A, #03h, M_4
		MOV DPTR, #8020h				;'Enter command'
		MOV r4, #0Fh	
		CLR SECSTRF
		LCALL PRINT
		LJMP EXIT_TO_PRINT
	M_4:
		CJNE A, #04h, M_5
		MOV DPTR, #8030h				;'Input code'
		MOV r4, #0Bh	
		CLR SECSTRF
		LCALL PRINT
		LJMP EXIT_TO_PRINT
	M_5:
		CJNE A, #05h, M_6
		MOV DPTR, #8040h				;'Code introduced'
		MOV r4, #0Bh	
		CLR SECSTRF
		LCALL PRINT
		LJMP EXIT_TO_PRINT
	M_6:
		CJNE A, #06h, M_7
		MOV DPTR, #8050h				;'Left shift'
		MOV r4, #0Ch	
		CLR SECSTRF
		LCALL PRINT
		LJMP EXIT_TO_PRINT
	M_7:
		CJNE A, #07h, M_8
		MOV DPTR, #8060h				;'Discontinuous output'
		MOV r4, #0Ah	
		CLR SECSTRF
		LCALL PRINT
		LJMP EXIT_TO_PRINT
	M_8:
		CJNE A, #08h, M_9
		MOV DPTR, #8070h				;'Repeat input'
		MOV r4, #10h
		MOV r5, #10h
		CLR SECSTRF
		LCALL PRINT
		LJMP EXIT_TO_PRINT
	M_9:
		CJNE A, #09h, M_10
		MOV DPTR, #8090h				;'Lock:'
		MOV r4, #0Eh
		CLR SECSTRF
		LCALL PRINT
		LJMP EXIT_TO_PRINT
	M_10:
		CJNE A, #0Ah, M_11
		MOV DPTR, #80A0h				;'Error input'
		MOV r4, #10h
		MOV r5, #0Fh
		SETB SECSTRF
		LCALL PRINT
		LJMP EXIT_TO_PRINT
	M_11:
		CJNE A, #0Bh, M_12
		MOV DPTR, #80C0h				;'Shift left: 56+, 65, 7, C'
		MOV r4, #09h
		CLR SECSTRF
		LCALL PRINT
		LJMP EXIT_TO_PRINT
	M_12:
		CJNE A, #0Ch, M_13
		MOV DPTR, #80D0h				;'Input: D'
		MOV r4, #0Ah
		CLR SECSTRF
		LCALL PRINT
		LJMP EXIT_TO_PRINT
	M_13:
		CJNE A, #0Dh, EXIT_TO_PRINT
		MOV DPTR, #80E0h				;'Output:67'
		MOV r4, #07h
		CLR SECSTRF
		LCALL PRINT
		LJMP EXIT_TO_PRINT
	EXIT_TO_PRINT:
	RET	
;-----------------------------------------------------------------------------
END
