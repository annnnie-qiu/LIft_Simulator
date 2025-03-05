
;
; p1.asm
;
; Created: 2023/7/30 16:25:38
; Author : ROG
;

; r16 -> currentFloor
; r17 -> secondChecker
; r19 -> direction

; Replace with your application code
.include "m2560def.inc"

.macro do_lcd_command
	ldi r17, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro
.macro do_lcd_data
	ldi r17, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro


.dseg
SecondCounter:				; indicate if the elevator moves for 2 seconds
	.byte 1
TempCounter:				; indicate the prescaler inside the timer0
	.byte 2
RequestQueue:
	.byte 10
UpdateInd: 
	.byte 1					; indicate is there a new input from the keypad

closeEnable: .byte 1		; closeEnable = 1 enable close, 0 disable

openEnable: .byte 1			; openEnable = 1 enable open, 0 disable

specialState:				; indicate to the keyboard input *
	.byte 1

holdingState:				; indicate to the keypad input # -> long time holding
	.byte 1

emergencyLight:				; indiacte the emergency reached to lv1
	.byte 1

.cseg
.org 0x0000
	jmp start
.org INT0addr
	jmp EXT_INT0
.org INT1addr
	jmp EXT_INT1

.org OVF0addr
	jmp Timer0OVF


start:
	/* --------- LCD Startup ---------------*/
	ser r16
	out DDRF, r16
	out DDRA, r16
	clr r16
	out PORTF, r16
	out PORTA, r16
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; 2x5x7
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00111000 ; 2x5x7
	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink
	/* --------- LCD Start END -------------*/


	/* --------- LED Startup ---------------*/
	ser r16
	out DDRG, r16
	out DDRC, r16
	/* --------- LED Start END -------------*/

	/* --------- Register & constant Definition ------*/
	.def currentFloor = r16
	.def direction = r19
	; temp use both for normal & keypad
	.def temp = r20
	; name use in keypad -> the defined name will only be used in the keypad functions
	.def row =r17
	.def col =r18
	.def mask =r22
	.def temp2 =r23
	.def input = r24
	.def haveUpdate = r21
	; end of name use in keypad
	clr currentFloor
	clr direction
	clr temp
	clr row
	clr col
	clr mask
	clr temp2
	clr input
	clr haveUpdate

	.equ PORTLDIR = 0xF0
	.equ INITCOLMASK = 0xEF
	.equ INITROWMASK = 0x01
	.equ ROWMASK = 0x0F
	.equ F_CPU = 16000000
	.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
	; 4 cycles per iteration - setup/call-return overhead

	ldi currentFloor, 1		; initialize the beginning floor
	ldi direction, 1		; direction: 1 for up, 0 for down
	/* --------- Register & constant Definition End ------*/

	/* --------- Stack initialize -------------*/
	ldi YL, low(RAMEND)
	ldi YH, high(RAMEND)
	out SPL, YL
	out SPH, YH
	/* --------- Stack initialize end -------------*/

	rcall initial_request_queue ; initialize the request queue
	
/* ------ initialize all data memory ------ */
	clr r17

	ldi Zh, high(closeEnable)
	ldi ZL, low(closeEnable)
	st Z, r17

	ldi ZH, high(openEnable)
	ldi ZL, low(openEnable)
	st Z, r17

	ldi ZH, high(specialState)
	ldi ZL, low(specialState)
	st Z, r17

	ldi ZH, high(emergencyLight)
	ldi ZL, low(emergencyLight)
	st Z, r17

	ldi ZH, high(holdingState)
	ldi ZL, low(holdingState)
	st Z, r17

	/* ------  set Port E as output (motor) ------ */
	ldi r17, 0xff
	out DDRE, r17			; set bit3 of PORTE (OC3B / PE4)

	clr r17
	sts OCR3BH, r17			; because we use 8bit register set high bits as 0

	ldi r17, (1<<CS30)		; turn the timer on with prescalar = 1
	sts TCCR3B, r17

	ldi r17, (1<<WGM30) | (1<<COM3B1)
	sts TCCR3A, r17
	/* ------  set motor end ------ */

	/* ------  keypad setup ------ */
	; initialize the input indicator
	ldi ZL, low(UpdateInd)
	ldi ZH, high(UpdateInd)
	clr temp
	st Z, temp
	; set the PORTL
	ldi temp, PORTLDIR		; columns are outputs, rows are inputs -> pull up registers
	STS DDRL, temp			; cannot use out
	/* ------  keypad setup end ------ */

	/* ------  set INT0 and INT1 as falling - edge triggered interrupt ------ */
	clr r17
	ldi r17, (2 << ISC00)
	ldi r18, (2 << ISC01)
	add r17, r18
	sts EICRA, r17

	/* ------  enable INT0 and INT1 ------ */
	ldi r17, 0x03
	out EIMSK, r17

	; display the currentFloor
	rcall LCD_display
	rcall pattern_display

	; initialze the data mem and registers for Timer0
	ldi r17, 0
	ldi ZL, low(SecondCounter)
	ldi ZH, high(SecondCounter)
	st Z, r17

	ldi ZL, low(TempCounter)
	ldi ZH, high(TempCounter)
	st Z, r17
	st Z+, r17

	; set the timer0 registers
	ldi temp, 0b00000000
	out TCCR0A, temp
	ldi temp, 0b00000010
	out TCCR0B, temp
	ldi temp, 1 << TOIE0
	sts TIMSK0, temp

	sei						; enable global interrupt

loop:
	lds r17, SecondCounter	; load the SecondCounter into the register and check
	cpi r17, 1				; check if we reach 2s
	breq new_floor			; reach 2s -> we are at a new floor
	; check if there is a keypad input
	rcall keypad_input_to_request ; this function will handle the input and insert it into the requestQueue wich checking
	rjmp loop				; not reach 2s -> elevator still moving

new_floor:
; the elevator reach to a new floor

	; disable the timer0 interrupt
	clr temp
	sts TIMSK0, temp

	lds r17, specialState
	cpi r17, 1				; check if the emergency has been pressed when moving
	brne continue
	jmp emergency_mode		; if so, change to the emergency mode

continue:
	; update the floor
	rcall direction_add_regulate
	mov currentFloor, r24
	mov direction, r25
	
	; display the current floor on LED/LCD
	rcall LCD_display
	rcall pattern_display
	
	; clear the secondCounter
	ldi r17, 0
	ldi YL, low(SecondCounter)
	ldi YH, high(SecondCounter)
	st Y, r17
	
	; compare the current floor matches the first requesting floor
	rcall compare_floor_stop
	cpi r24, 1				; check if this floor match
	breq should_stop		; the floor match -> stop at this floor and open
	rjmp finish_this_floor	; this is not a floor that need to stop


should_stop:
	; we should stop at this floor
	; first remove the first entry of the queue and move others up by 1

	ldi temp, 0
	sts holdingState, temp	 ; clear the long time holding indicator -> the mode will only be activated when the lift is stopping

	rcall match_modify_queue ; floor matched -> should change the queue -> pop the first from the queue
	
	rcall LCD_display		 ; change the next stop displayed on the LCD
	; execute open
	
openDoorAgain:
	rcall pattern_display

	clr temp
	ldi temp, 0x4d
	sts OCR3BL, temp		; enable the motor 30%
	out PORTA, r22
	
	rcall OneSec			; spin for 1s

	clr temp
	sts OCR3BL, temp		; disable the motor

openDoor:
	lds temp, specialState	; check if we are in the emergency mode
	cpi temp, 1
	brne continueOpen		; not in emergency
	jmp direct_close		; in the emergency mode -> close the door immediately

continueOpen:
/* --------- Start normal holding stage ----------*/
	lds temp, closeEnable
	cpi temp, 1
	breq closeDoor			; press the button to close the door


	ldi temp, 0
	out PORTC, temp
	out PORTG, temp
	
	lds temp, specialState	; check if we are in the emergency mode
	cpi temp, 1
	breq direct_close

	lds temp, closeEnable
	cpi temp, 1
	breq closeDoor			; press the button to close the door


	rcall OneSec			; 1st second waiting
	
	lds temp, specialState	; check if we are in the emergency mode
	cpi temp, 1
	breq direct_close

	lds temp, closeEnable
	cpi temp, 1
	breq closeDoor			; press the button to close the door


	rcall pattern_display
	rcall OneSec			; 2nd second waiting

	lds temp, specialState	; check if we are in the emergency mode
	cpi temp, 1
	breq direct_close

	lds temp, closeEnable
	cpi temp, 1
	breq closeDoor			; press the button to close the door

	out PORTC, temp
	out PORTG, temp
	rcall OneSec			; 3rd second waiting
		
	lds temp, specialState	; check if we are in the emergency mode
	cpi temp, 1
	breq direct_close

	lds temp, closeEnable
	cpi temp, 1
	breq closeDoor			; press the button to close the door

	rcall pattern_display
/*----- End normal holding stage -----------*/

/* ------ if the open button is held ------ */
	In R17, PIND			; store the input data in temp
	sbrs R17, 1				; skip the next instruction if temp bit1 is clear
	rjmp openDoor

/*------ long time holding ------*/
	lds r17, holdingState
	cpi r17, 1				; check if the long time holding has been pressed when moving
	breq openDoor

closeDoor:

	rcall pattern_display
/* ------ check need to open the door ------ */
	clr r22
	lds r22, openEnable		

	clr temp
	sts openEnable, temp	; dsibale the openEnable

	cpi r22, 1
	brne direct_close		; open the door
	jmp openDoor
/* ------ automaticly to close the door ------ */
direct_close:
	clr temp
	ldi temp, 0xcc
	sts OCR3BL, temp		; enable the motor 80%

	rcall OneSec

	clr temp
	sts OCR3BL, temp		; disable the motor

	clr temp				; disable closeEnable
	sts closeEnable, temp
	
	lds temp, specialState
	cpi temp, 1
	breq emergency_mode

open_again:
/* ------ check need to open the door again ------ */
	clr r22
	lds r22, openEnable		

	clr temp
	sts openEnable, temp	; disbale the openEnable

	cpi r22, 1
	brne finish_this_floor	; open the door again
	jmp openDoorAgain

finish_this_floor:
	; enable the timer0 interrupt again
	ldi temp, 0
	sts holdingState, temp ; clear the long time holding indicator

	ldi temp, 1 << TOIE0
	sts TIMSK0, temp

	rjmp loop				; back to the loop


emergency_mode:
; logic of emergency mode:
; 1. when the mode is triggered when moving -> the lift will move to the closest floor and active the emergency mode
; 2. when the mode is triggered when stopping(open/hole/close) -> it will directly moving down (we do not discuss the action of the door at this stage)
; about situation 2: we only discussing on the movement here, the door's action is not associate with the movement at here

; when the emergency mode activated
	; display the emergency info
	rcall emergency_lcd
	
	ldi temp, 0
	sts specialState, temp		; clear the specialState
	ldi temp, 2
	sts emergencyLight, temp	; set the light up
	
	; clear the reqeust queue
	rcall initial_request_queue
	rjmp emergency_loop

waiting_down:
	lds r17, SecondCounter		; load the SecondCounter into the register and check
	cpi r17, 1
	brne waiting_down			; check if we reach the next floor -> 2s


emergency_loop:
	; disable the timer0
	clr temp
	sts TIMSK0, temp
	
	; check the strobe light
	lds temp, emergencyLight
	cpi temp, 2
	breq light_up
	
	; now emergencyLight is 0 -> close the strobe light and set the next time as light up
	out PORTA, temp
	ldi temp, 2
	sts emergencyLight, temp
	rjmp finish_light

light_up:
	; now the emergencyLight is 2 -> light the strobe and set the next time as close light
	out PORTA, temp
	ldi temp, 0
	sts emergencyLight, temp

finish_light:
	; load the second counter and check we reach 2s -> indicate the emergency mode triggered when moving or stopping
	ldi YL, low(SecondCounter)
	ldi YH, high(SecondCounter)
	ld r17, Y
	cpi r17, 1
	breq continue_light			; emergency mode triggered when moving
	rjmp timer_add				; emergency mode triggered when stopping
continue_light:
	; clear the second counter
	ldi r17, 0
	st Y, r17
	
	; update the floor and print out
	rcall direction_add_regulate
	mov currentFloor, r24
	ldi direction, 0			; set the direction to down
	rcall pattern_display

	cpi currentFloor, 1			; check if we reach the 1st floor
	breq first_floor_emergency	; if so, open-hold-close and then halt

	; enable the timer0 interrupt again
	ldi temp, 1 << TOIE0
	sts TIMSK0, temp

	rjmp waiting_down

timer_add:
; the emergency mode triggered when the list is stopping 
; -> skip calculating the level at this stage but change the direction
	ldi direction, 0
	rcall pattern_display
	ldi temp, 1 << TOIE0
	sts TIMSK0, temp

	rjmp waiting_down

first_floor_emergency:
	; we are at the first floor -> open the door and busy wait
	
	; open the door
	rcall pattern_display
	ldi temp, 2
	out PORTA, temp
	clr temp
	ldi temp, 0x4d
	sts OCR3BL, temp		; enable the motor 30%
	out PORTA, r22
	
	rcall OneSec

	clr temp
	sts OCR3BL, temp		; disable the motor, open door finished
	; end open

	; holding for 3s
	ldi temp, 0
	out PORTC, temp
	out PORTG, temp
	out PORTA, temp			; LED & strobe light close
	rcall OneSec			; 1st second hold

	rcall pattern_display
	ldi temp, 2
	out PORTA, temp			; LED & strobe light up
	rcall OneSec			; 2nd second hold

	ldi temp, 0
	out PORTC, temp
	out PORTG, temp
	out PORTA, temp			; LED & strobe light close
	rcall OneSec			; 3rd second hold

	rcall pattern_display
	ldi temp, 2
	out PORTA, temp			; LED & strobe light up

	; end holding, close the door
	clr temp
	ldi temp, 0xcc
	sts OCR3BL, temp		; enable the motor 80%
	rcall OneSec

	clr temp
	sts OCR3BL, temp		; disable the motor
	; finish closing
busy_wait_emergency:
	; now the elevator halt and wating for input * to end emergency state

	; blinking the strobe
	ldi temp, 2
	out PORTA, temp			
	rcall sleep_5ms
	rcall sleep_5ms
	ldi temp, 0
	out PORTA, temp
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms		


	rcall keypad_main		; continuously reading from the keypad
	lds temp, specialState	; only check if the emergency mode has been canceled
	cpi temp, 1
	brne busy_wait_emergency ; if not, just waiting
	jmp start				; if so then restart the system


;---------------------------------------------------------------------
; help functions
;---------------------------------------------------------------------

/*---------------------------------------------------------------------------------------*/
direction_add_regulate:
	; function for add the floor with the direction and regulare the floor number
	; and will change the direction if edge cases reaches
	; edge case 1: at lv1 and going down -> the next floor should be 2 and direction up
	; edge case 2: at lv10 and going on -> the next floor should be 9 and direction down
	; return value: r24: new floor with regulated
	;				r25: new direction with regulated


	rcall direction_add		; calculate the floor number with direction but without regulation
	cpi r24, 0
	breq zero_regulate		; regulate the floor number & direction-> case 1
	cpi r24, 11
	breq top_regulate		; regulate the floor number & direction-> case 2

	mov r25, direction		; direction not changed
	ret						; no edge cases reached -> just return the original 

zero_regulate:
	; nextFloor == 0 -> need to go up anyway
	ldi r24, 2				; next floor should be lv2
	ldi r25, 1				; direction will be up
	ret

top_regulate:
	; nextFloor == 11 -> need to go down anyway
	ldi r24, 9				; next floor should be lv9
	ldi r25, 0				; direction will be down
	ret
/*---------------------------------------------------------------------------------------*/



/*---------------------------------------------------------------------------------------*/
direction_add:
	; will be called in function "direction_add_regulate"
	; function for add the floor with the direction£º 1 for +, 0 for -
	; currentFloor: r16 -> param
	; directin: r19 -> param
	; return: r24 -> next floor (range from 0 - 11), 0 and 11 will be regulated
	push r16
	push r19

	cpi r19, 0
	breq down
	rjmp up
down:
	; the lift moving down, substact the current floor by 1
	subi r16, 1
	rjmp add_end
up:
	; the lift moving up, add the current floor by 1
	add r16, r19
	rjmp add_end
add_end:
	mov r24, r16
	pop r19
	pop r16
	ret
/*---------------------------------------------------------------------------------------*/



/*---------------------------------------------------------------------------------------*/
pattern_shift:
	; function for shift the given number for given times -> used in pattern_display
	; this function change the input floor number into the LED bar state(1 -> 1/ 2 -> 11/ 3 -> 111 etc)
	; pattern: r17
	; times: r18
	; returnValue: r24
	; iterator : r16
	push r17
	push r18
	push r16
loop_start:
	ldi r16, 0
loop_cond:
	cpi r18, 0
	breq inputZero
	cp r16, r18
	breq loop_end
loop_body:
	lsl r17
	inc r17
	mov r24, r17
	inc r16
	rjmp loop_cond
; inputZero was added for the situation that we want to print 0 out
inputZero:
	ldi r24, 0
loop_end:
	pop r16
	pop r18
	pop r17
	ret
/*---------------------------------------------------------------------------------------*/



/*---------------------------------------------------------------------------------------*/
pattern_display:
	; function for displaying current floor with the given number on the LED
	; will use function pattern_shift
	; current_floor: r16 -> param
	; pattern_for_calculate: r17 (register uses in the function -> pattern that need to be shifted)
	; floor_for_calculate: r18 (register uses in the function -> time need to be shifted)
	; display_pattern: r24 -> (register uses in the function -> receive the paattern to display)
	push r16
	push r17
	push r18
	push r24

	ldi r17, 0
	out PORTC, r17
	out PORTG, r17
	; check if current floor <= 8
	cpi currentFloor, 9
	brlo lower8
	rjmp great8

lower8:
	; the floor <= 8 -> only consider PORTC
	mov r18, currentFloor
	rcall pattern_shift
	out PORTC, r24
	rjmp display_end

great8:	
	; the floor > 8 -> consider PORTC & PORTG
	; firstly print out the lower 8 levels
	ldi r18, 8
	rcall pattern_shift
	out PORTC, r24
	; then print the upper level(s)
	subi currentFloor, 8
	mov r18, currentFloor
	rcall pattern_shift
	out PORTG, r24
	rjmp display_end

display_end:
	pop r24
	pop r18
	pop r17
	pop r16
	ret
/*---------------------------------------------------------------------------------------*/



/*---------------------------------------------------------------------------------------*/
OneSec:
	; function for busy wait for a second, during the waiting time
	; continuously reading from the keypad -> add the input with checking
	; used registers: r24
	;				  r25
	;				  temp
	push r24
	push r25
	push temp
delay_loop_start:
    ldi r24, 0
    ldi r25, 0
    ldi temp, high(5000)
delay_loop_cond:
    cpi r24, low(5000)
    cpc r25, temp
    breq delay_loop_end
delay_loop_body:
    rcall keypad_input_to_request ; reading from the keypad
    adiw r25:r24, 1
    rjmp delay_loop_cond
delay_loop_end:
    ; end the delay
    ;pop all and return
	pop temp
	pop r25
	pop r24
	ret
/*---------------------------------------------------------------------------------------*/



/*---------------------------------------------------------------------------------------*/
compare_floor_stop:
	; function for checking the current level in the list for stopping or not
	; currentFloor: r16 -> param
	; temp : r20 -> store the first value in the request queue
	; return: r24 -> indicator for match -> 1 for match, 0 for not
	push temp
	push ZH
	push ZL

	ldi ZH, high(RequestQueue)
	ldi ZL, low(RequestQueue)
	ld temp, Z				; load the first value in the queue
	cp currentFloor, temp	; check if match
	breq match 
	; not match -> return 0
	ldi r24, 0
	rjmp compare_floor_end
match:
	; match -> return 1
	ldi r24, 1
compare_floor_end:
	pop ZL
	pop ZH
	pop temp
	ret
/*---------------------------------------------------------------------------------------*/



/*---------------------------------------------------------------------------------------*/
match_modify_queue:
	; function for remove the 1st entry from the queue and move the following in front by 1
	push r18
	push r17
	push temp
	push ZL
	push ZH
	push YL
	push YH

	ldi ZH, high(RequestQueue)	; load the pointer of the queue -> for store
	ldi ZL, low(RequestQueue)

	ldi YH, high(RequestQueue)	; load the pointer of the queue -> for read the next one
	ldi YL, low(RequestQueue)

modify_loop_start:
	ldi r17, 0					; use r17 as a loopCounter
	ld temp, Y+					; load the 1st entry in the array, useless but let Y be the next entry
modify_loop_cond:
	cpi r17, 10					; the shift should occur 10 times
	breq modify_end
modify_loop_body:
	clr temp
	ld temp, Y+					; load the next entry
	mov r18, temp
	st Z+, r18					; store it to the previous entry
	inc r17
	rjmp modify_loop_cond
modify_end:
	; should load the current Z's position to 0 -> last entry
	clr temp
	st Z, temp

	pop YH
	pop YL
	pop ZH
	pop ZL
	pop temp
	pop r17
	pop r18
	ret
/*---------------------------------------------------------------------------------------*/



/*---------------------------------------------------------------------------------------*/
initial_request_queue:
	; function for initialize the request queue by setting the 10 entries to 0
	push r18
	push r19
	push ZH
	push ZL
	push YH
	push YL

	ldi YH, high(RequestQueue)
	ldi YL, low(RequestQueue)
initial_loop_start:
	ldi r19, 0
initial_loop_cond:
	cpi r19, 10
	breq initial_loop_end
initial_loop_body:
	clr r18
	st Y+, r18				; set 0 to all the entries in the queue
	inc r19
	rjmp initial_loop_cond

initial_loop_end:

initial_all_end:
	pop YL
	pop YH
	pop ZL
	pop ZH
	pop r19
	pop r18
	ret
/*---------------------------------------------------------------------------------------*/



/*---------------------------------------------------------------------------------------*/
; Keypad ------------------------------------------------------
keypad_main:
	; special return values:
	; A -> 0xA -> blocked
	; B -> 0xB -> blocked
	; C -> 0xC -> blocked
	; D -> 0xD -> blocked
	; * -> 0xE -> specialState -> 1
	; # -> 0xF -> specialState -> 2
	; push the used registers into the stack
	; the input from the keypad will be returned in r24(input)
	; default return value: 0xff (when no input)
	push temp
	push row
	push col
	push mask
	push temp2
	in temp, SREG
	push temp
	
main:
	ldi input, 0xff			; set the default return value as 255
	ldi mask, INITCOLMASK	; initial column mask
	clr col					; initial column

colloop:
	STS PORTL, mask			; set column to mask value
							; (sets column 0 off)
	ldi temp, 0xFF			; implement a delay so the
							; hardware can stabilize
	
delay:
	dec temp
	brne delay
	LDS temp, PINL			; read PORTL. Cannot use in 
	andi temp, ROWMASK		; read only the row bits
	cpi temp, 0xF			; check if any rows are grounded
	breq nextcol			; if not go to the next column
	ldi mask, INITROWMASK	; initialise row check
	clr row					; initial row
	
rowloop:      
	mov temp2, temp
	and temp2, mask			; check masked bit
	brne skipconv			; if the result is non-zero,
							; we need to look again
	rcall convert			; if bit is clear, convert the bitcode into number/symbol/letter
	mov input, temp			; if there is an input -> return the real input
	jmp keypad_end			; and start again
	
skipconv:
	inc row					; else move to the next row
	lsl mask				; shift the mask to the next bit
	jmp rowloop          

nextcol:     
	cpi col, 3				; check if we are on the last column
	breq keypad_end			; if so, no buttons were pushed,
							; so start again.
							; else shift the column mask:
	sec						; We must set the carry bit
	rol mask				; and then rotate left by a bit,
	; shifting the carry into
	; bit zero. We need this to make
	; sure all the rows have
	; pull-up resistors
	inc col					; increment column value
	jmp colloop				; and check the next column
	; convert function converts the row and column given to a
	; binary number and also outputs the value to PORTC.
	; Inputs come from registers row and col and output is in
	; temp.
	
convert:
	; we have an input from the keyboard
	ldi temp, 1
	sts UpdateInd, temp		; set the indiactor as 1 -> new input
	cpi col, 3				; if column is 3 we have a letter
	breq letters
	cpi row, 3				; if row is 3 we have a symbol or 0
	breq symbols
	mov temp, row			; otherwise we have a number (1-9)
	lsl temp				; temp = row * 2
	add temp, row			; temp = row * 3
	add temp, col			; add the column address
							; to get the offset from 1
	inc temp				; add 1. Value of switch is
							; row*3 + col + 1.
	jmp convert_end
	
letters:
	ldi temp, 0xA
	add temp, row			; increment from 0xA by the row value
	jmp convert_end
	
symbols:
	cpi col, 0				; check if we have a star
	breq star
	cpi col, 1				; or if we have zero
	breq zero
							; # as 1 in holdingState
	ldi temp, 1
	sts holdingState, temp

	ldi temp, 0xF			; we'll output 0xF for hash
	jmp convert_end
	
star:
							; * as 1 in specialState
	ldi temp, 1
	sts specialState, temp

	ldi temp, 0xE			; we'll output 0xE for star

	jmp convert_end
	
zero:
	clr temp				; set to zero
	ldi temp, 0				
	
convert_end:
	ret						; return to caller

keypad_end:
	pop temp
	out SREG, temp
	pop temp2
	pop mask
	pop col
	pop row
	pop temp
	ret
/*---------------------------------------------------------------------------------------*/



/*---------------------------------------------------------------------------------------*/
; keypad input to request Array
keypad_input_to_request:
	; this function read the input from the keypad and check validation then insert to the request queue (also with validation)

	push haveUpdate
	push input
	push temp
	in temp, SREG
	push temp

	clr input
	rcall keypad_main
	; check if we receive an input
	lds haveUpdate, UpdateInd

	ldi temp, 0 
	sts UpdateInd, temp					; clear the indicator

	cpi haveUpdate, 1
	brne keypad_input_to_request_end

	cpi input, 10						; check if it's a valid
	brlo valid
	rjmp keypad_input_to_request_end

valid:
	ldi temp, 0
	sts UpdateInd, temp					; clear the indicator
newInput:
	; have a input from the keypad
	; check if we can insert to the current queue
	rcall insert_order_queue


keypad_input_to_request_end:
	pop temp
	out SREG, temp
	pop temp
	pop input
	pop haveUpdate
	ret
/*---------------------------------------------------------------------------------------*/



/*---------------------------------------------------------------------------------------*/
insert_order_queue:
	; this function add the given input number into the queue
	; situations:
	; 1. input greater than currentFloor
	; 1.1 elevator moving up -> great_and_up
	; 1.2 elevator moving down -> great_and_down
	; 2. input less than currentFloor
	; 2.1 elevator moving up -> less_and_up
	; 2.2 elevator moving down -> less_and_down
	; 3. input equal to the currentFloor -> return
	; input -> r24 -> param
	; currentFloor -> r16 -> param
	push input
	push currentFloor
	push temp
	in temp, SREG
	push temp
	push ZH
	push ZL
	push YH
	push YL
	push direction
	push r17

	cpi input, 0xA; check the input is from 0-9
	brlo check_valid
	rjmp insert_order_queue_end

check_valid:
	cpi input, 0
	brne no_trans
	ldi input, 10
no_trans:
	cp input, currentFloor ; check the input value and the currentFloor
	;breq insert_order_queue_end 
	breq jumpToInsertOrderQueueEnd	; if are the same then just return
	rjmp notJumpToInsertOrderQueueEnd

jumpToInsertOrderQueueEnd:
	
	rjmp insert_order_queue_end

notJumpToInsertOrderQueueEnd:

	brlo less_than_current ; less than the currentFloor
	rjmp great_than_current ; great than the currentFloor

great_than_current:
	; input greater than the currentFloor -> check the direction then
	cpi direction, 1
	breq great_and_up ; the lift is moving up
	rjmp great_and_down ; the lift is moving down

great_and_up:
; lift moving up and the input is greater than the currentFloor
; the insert logic is to loop around the "RequestQueue" and find the first value
; greater than the input value, then insert the value into the place and shift the backward by 1
; special case:
; 1. if the value == input -> return (do not accept repeat value)
; 2. if the value < currentFloor -> this is the place we should insert -> the input is the greatest one in the queue so far
great_and_up_loop_start:
	; load the first value in the queue to the temp
	ldi YH, high(RequestQueue)
	ldi YL, low(RequestQueue)
	ld temp, Y
	ldi r17, 0					; set r17 as the counter
great_and_up_loop_cond:
	cpi r17, 9					; check if we reach the end of the loop
	breq great_and_up_loop_end
great_and_up_loop_body:
	cp input, temp
	brlo insert_and_swap1		; the value is greater than the input value -> insert
	;breq insert_order_queue_end 
	breq goToInsertOrderQueueEnd	;the input is the same as a value already in the queue
	rjmp notGoToInsertOrderQueueEnd

goToInsertOrderQueueEnd:

	rjmp insert_order_queue_end

notGoToInsertOrderQueueEnd:

	cp temp, currentFloor
	brlo insert_and_swap1		; the value is smaller than the currentFloor -> special case 2

	; this value not match all the cases, check the next
	adiw YH:YL, 1				; move the Y register to the next value
	ld temp, Y					; update the read value
	inc r17						; increment the counter
	rjmp great_and_up_loop_cond

great_and_up_loop_end:
	rjmp insert_and_swap1



great_and_down:
; lift moving down and the input is greater than the currentFloor
; the insert logic is to loop around the "RequestQueue" and find the first value
; greater than the input value, then insert the value into the place and shift the backward by 1
; special case:
; 1. if the value == input -> return (do not accept repeat value)
; 2. if the value == 0 -> just replace the value -> since it's the last and the greatest in the list
great_and_down_loop_start:
	ldi YH, high(RequestQueue)
	ldi YL, low(RequestQueue)
	ld temp, Y
	ldi r17, 0					; set r17 as the counter
great_and_down_loop_cond:
	cpi r17, 9					; check if we reach the end of the loop
	breq great_and_up_loop_end
great_and_down_loop_body:
	cp input, temp
	brlo insert_and_swap1		; the value is greater than the input value -> insert
	breq insert_order_queue_end ; the input is the same as a value already in the queue
	cpi temp, 0					; check if it's the last value
	breq direct_modify

	adiw YH:YL, 1				; move the Y register to the next value
	ld temp, Y					; update the read value
	inc r17						; increment the counter
	rjmp great_and_down_loop_cond

great_and_down_loop_end:
	rjmp insert_and_swap1


insert_and_swap1:
; insert the input value in this entry and move the following backward by 1
insert_and_swap1_loop_cond:
	cpi r17, 9
	breq insert_and_swap1_loop_end
insert_and_swap1_loop_body:
	st Y+, input
	mov input, temp
	ld temp, Y
	inc r17
	rjmp insert_and_swap1_loop_cond

insert_and_swap1_loop_end:
	; finish the insert
	; update the info on the LCD -> the first stop might change
	rcall LCD_display
	rjmp insert_order_queue_end

less_than_current:
; input less than the currentFloor -> check the direction then
	cpi direction, 1
	breq less_and_up			; the lift is moving up
	rjmp less_and_down			; the lift is moving down

less_and_up:
; lift moving up and the input is less than the currentFloor
; the insert logic is to loop around the "RequestQueue" and find the first value
; smaller than the input value, then insert the value into the place and shift the backward by 1
; special case:
; 1. if the value == input -> return (do not accept repeat value)
; 2. if the value == 0 -> just replace the value -> the last in the queue and is the smallest
less_and_up_loop_start:
	ldi YH, high(RequestQueue)
	ldi YL, low(RequestQueue)
	ld temp, Y
	ldi r17, 0					; set r17 as the counter
less_and_up_loop_cond:
	cpi r17, 9					; check if we reach the end of the loop
	breq less_and_up_loop_end
less_and_up_loop_body:
	cp temp, input
	brlo insert_and_swap1		; the value is smaller than the input value
	breq insert_order_queue_end ; value is the same as the input, abort

	cpi temp, 0
	breq direct_modify

	adiw YH:YL, 1				; move the Y register to the next value
	ld temp, Y					; update the read value
	inc r17						; increment the counter
	rjmp less_and_up_loop_cond

less_and_up_loop_end:
	rjmp insert_and_swap1


less_and_down:
; lift moving down and the input is less than the currentFloor
; the insert logic is to loop around the "RequestQueue" and find the first value
; smaller than the input value, then insert the value into the place and shift the backward by 1
; spcial case:
; 1. if the value == input -> return (do not accept repeat value)
; 2. if the value > currentFloor -> this is the place we should insert -> the input is the smallest one in the queue so far
less_and_down_loop_start:
	ldi YH, high(RequestQueue)
	ldi YL, low(RequestQueue)
	ld temp, Y
	ldi r17, 0					; set r17 as the counter
less_and_down_loop_cond:
	cpi r17, 9					; check if we reach the end of the loop
	breq less_and_down_loop_end
less_and_down_loop_body:
	cp temp, input
	brlo insert_and_swap1		; the value is smaller than the input value
	breq insert_order_queue_end ; value is the same as the input, abort

	cp currentFloor, temp
	brlo insert_and_swap1 
	; special case 2

	adiw YH:YL, 1				; move the Y register to the next value
	ld temp, Y					; update the read value
	inc r17						; increment the counter
	rjmp less_and_down_loop_cond

less_and_down_loop_end:
	rjmp insert_and_swap1

direct_modify:
	; directly modify the number in the certain position
	st Y, input
	; update the info on the LCD
	rcall LCD_display
	rjmp insert_order_queue_end

insert_order_queue_end:
; TO BE NOTICE: the less than currentFloor situations are below this section
	pop r17
	pop direction
	pop YL
	pop YH
	pop ZL
	pop ZH
	pop temp
	out SREG, temp
	pop temp
	pop currentFloor
	pop input
	ret
/*---------------------------------------------------------------------------------------*/



/*---------------------------------------------------------------------------------------*/
;------------------------------------------------------------------------
; LCD
;
; Send a command to the LCD (r17)
;

lcd_command:
	out PORTF, r17
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
	out PORTF, r17
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	push r17
	clr r17
	out DDRF, r17
	out PORTF, r17
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in r17, PINF
	lcd_clr LCD_E
	sbrc r17, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r17
	out DDRF, r17
	pop r17
	ret

sleep_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret

/*---------------------------------------------------------------------------------------*/
LCD_display:
	; this function print the ordinary info on the LCD
	; 1st line: currentFloor
	; 2nd line: next stop + direction (U for up, D for down)
	; should be used after get a new request/ get to a new floor
	; temp: r20 -> used register
	; r17 -> used register for loading LCD data/command
	; ZH -> used register for high 8 bits of the address of the request queue
	; ZL -> used register for low 8 bits of the address of the request queue
	
	push temp
	push r17
	push ZH
	push ZL

	do_lcd_command 0b00000001 ; clear display -> always clear the existing before display new
	rcall sleep_5ms

	; print "Current floor " in the first line
	do_lcd_data 'C'
	do_lcd_data 'u'
	do_lcd_data 'r'
	do_lcd_data 'r'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 'f'
	do_lcd_data 'l'
	do_lcd_data 'o'
	do_lcd_data 'o'
	do_lcd_data 'r'
	do_lcd_data ' '

	; print the floor number in the following space
	cpi currentFloor, 10
	breq two_digits
	rjmp one_digit

two_digits:
	; "10" as a special case
	do_lcd_data '1'
	do_lcd_data '0'				; print "10"
	rjmp print_next_stop

one_digit:
	ldi r17, 48
	add r17, currentFloor
	rcall lcd_data				; print the currentFloor number's ascii letter on the LCD and wait for a while to stablize
	rcall lcd_wait
	rjmp print_next_stop

print_next_stop:
	; after finish printing the current floor and the direction, we should print the next request
	do_lcd_command 0b11000000	; move to the 2nd line
	do_lcd_data 'N'
	do_lcd_data 'e'
	do_lcd_data 'x'
	do_lcd_data 't'
	do_lcd_data ' '
	do_lcd_data 's'
	do_lcd_data 't'
	do_lcd_data 'o'
	do_lcd_data 'p'
	do_lcd_data ' '
	; now check the request queue
	ldi ZH, high(RequestQueue)
	ldi ZL, low(RequestQueue)
	ld temp, Z					; get the first value from the request queue
	
	cpi temp, 0					; check if the number is zero -> if zero -> not print
	breq request_zero
	cpi temp, 10				; check if the number is 10 -> we should print two digits
	breq request_two_digit

	; else just one digit -> directly print
	ldi r17, 48
	add r17, temp
	rcall lcd_data				; print the ascii number on the LCD and wait for a while to stablize
	rcall lcd_wait
	do_lcd_data ' '
	
	rjmp print_direction

request_zero:
	do_lcd_data ' '				; for zero, just print an empty space
	rjmp print_direction

request_two_digit:
	; the request floor is lv10
	do_lcd_data '1'
	do_lcd_data '0'
	do_lcd_data ' '
	rjmp print_direction

print_direction:
	; print the direction after the next stop -> "U" for going up, "D" for going down
	cpi currentFloor, 1			; the direction at lv1 is always up
	breq first_floor
	cpi currentFloor, 10		; the direction at lv10 is always down
	breq top_floor
	cpi direction, 1			; check if going up/down
	breq direction_up
	; now the direction is down
	do_lcd_data 'D'
	rjmp LCD_display_end


first_floor:
	do_lcd_data 'U'				; the direction at lv1 is always up
	rjmp LCD_display_end

top_floor:
	do_lcd_data 'D'				; the direction at lv10 is always down
	rjmp LCD_display_end

direction_up:
	; print the up direction
	do_lcd_data 'U'
	rjmp LCD_display_end

LCD_display_end:

	pop ZL
	pop ZH
	pop r17
	pop temp
	ret
/*---------------------------------------------------------------------------------------*/



/*---------------------------------------------------------------------------------------*/
emergency_lcd:
	push r17
	
	; print "Emergency" at the first line
	do_lcd_command 0b00000001	; clear display -> always clear the existing before display new
	do_lcd_data 'E'
	do_lcd_data 'm'
	do_lcd_data 'e'
	do_lcd_data 'r'
	do_lcd_data 'g'
	do_lcd_data 'e'
	do_lcd_data 'n'
	do_lcd_data 'c'
	do_lcd_data 'y'

	; print the "Call 000" at the second line
	do_lcd_command 0b11000000	; move to the 2nd line
	do_lcd_data 'C'
	do_lcd_data 'a'
	do_lcd_data 'l'
	do_lcd_data 'l'
	do_lcd_data ' '
	do_lcd_data '0'
	do_lcd_data '0'
	do_lcd_data '0'
	pop r17
	ret
/*---------------------------------------------------------------------------------------*/

;------------------------------------------------------------------------
; Interrupts:

/* ------ interrupt service Routine (INT0) closing ------ */
EXT_INT0:	
	cli				
	push temp				; save register
	in temp, SREG			; save SREG
	push temp
	push r15
	push r14

	in r15, PinD			; read PORTD
	rcall sleep_5ms
	rcall sleep_5ms
	in r14, PinD			; read PORTD after delay
	cp r15, r14
	brne notClose
	
	clr temp
	ldi temp, 1				; enable the closeEnable
	sts closeEnable, temp

	sbi EIFR, INT0
notClose:
	sei
	pop r14
	pop r15
	pop temp				; restore SREG
	out SREG, temp
	pop temp				; restore register
	reti

/* ------ interrupt service Routine (INT1) opening ------ */
EXT_INT1:					; increment
	cli
	push temp				; save register
	in temp, SREG			; save SREG
	push temp
	push r15
	push r14

	in r15, PinD			; read PORTD
	rcall sleep_5ms
	rcall sleep_5ms
	in r14, PinD			; read PORTD after delay
	cp r15, r14
	brne notOpen

	clr temp
	ldi temp, 1				; enable the openEnable
	sts openEnable, temp
	
	sbi EIFR, INT1

notOpen:
	sei
	pop r14
	pop r15
	pop temp				; restore SREG
	out SREG, temp
	pop temp				; restore register
	reti

/*------------------ Timer0 ---------------------*/

Timer0OVF:
	push temp
	in temp, SREG
	push temp
	push r26
	push r27
	push YH
	push YL
	push r18
	push r17
	push r24

	; load the prescaler counter and add by 1 then store back to the data mem
	lds r26, TempCounter
	lds r27, TempCounter + 1
	
	adiw r27:r26, 1
	sts TempCounter, r26
	sts TempCounter + 1, r27

	ldi temp, high(3906)
	cpi r26, low(3906)
	cpc r27, temp
	breq compare_light

	ldi temp, high(7812)
	cpi r26, low(7812)
	cpc r27, temp
	brne no_light
	
	ldi temp, 0
	out PORTC, temp
	out PORTG, temp			; close the LED
	rcall pattern_display	; show the LED
	rjmp no_light

compare_light:
	ldi temp, 0
	out PORTC, temp
	out PORTG, temp			; close the LED
	rcall pattern_display	; show the LED

	cpi currentFloor, 10
	breq down_light
	cpi currentFloor, 1
	breq up_light


	cpi direction, 1		; check if going up
	breq up_light

down_light:
	clr r17
	cpi currentFloor, 9
	brlo low8				; floor from 1-8
	; floor over 8 ; only apply 8 to shift
	ldi r18, 8
	rjmp get_pattern

low8:
	mov r18, currentFloor

get_pattern:
	rcall pattern_shift
	subi r24, 1
	out PORTC, r24

	rjmp no_light
	
up_light:
	cpi currentFloor, 9
	brne only_ten
	ldi temp,3				; current floor is lv9 -> lv10 : should light all light at this stage
	out PORTG, temp
	rjmp no_light

only_ten:
	ldi temp, 2
	out PORTG, temp			; light up the 10th floor

no_light:
	ldi temp, high(15625)
	cpi r26, low(15625)
	cpc r27, temp			; check if the timer counts to 2 seconds
	brlo timer0_end			; not enough 2 seconds
	rjmp add_second 

add_second:
	; we reach to 2 seconds
	ldi temp, 1
	sts SecondCounter, temp

	; clear the prescaler counter
	ldi temp, 0
	ldi YL, low(TempCounter)
	ldi YH, high(TempCounter)
	st Y+, temp
	st Y, temp

timer0_end:
	pop r24
	pop r17
	pop r18
	pop YL
	pop YH
	pop r27
	pop r26
	pop temp
	out SREG, temp
	pop temp
	reti
