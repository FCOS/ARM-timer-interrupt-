; Definitions  -- references to 'UM' are to the User Manual.

; Timer Stuff -- UM, Table 173

T0	equ	0xE0004000		; Timer 0 Base Address
T1	equ	0xE0008000

IR	equ	0			; Add this to a timer's base address (instead of defining all individually)
TCR	equ	4
MCR	equ	0x14
MR0	equ	0x18

TimerCommandReset	equ	2 ;same idea as above
TimerCommandRun	equ	1
TimerModeResetAndInterrupt	equ	3
TimerResetTimer0Interrupt	equ	1
TimerResetAllInterrupts	equ	0xFF

; VIC Stuff -- UM, Table 41
VIC	equ	0xFFFFF000		; VIC Base Address
IntEnable	equ	0x10	;  Interrupt Enable Register. This register controls which of the 32 interrupt requests and software interrupts are enabled to contribute to FIQ or IRQ.
VectAddr	equ	0x30    ; Vector Address Register. When an IRQ interrupt occurs, the IRQ service routine can read this register and jump to the value read.
VectAddr0	equ	0x100	; Vector address 0 register. Vector Address Registers 0-15 hold the addresses of the Interrupt Service routines (ISRs) for the 16 vectored IRQ slots.
VectCtrl0	equ	0x200	; Vector control 0 register. Vector Control Registers 0-15 each control one of the 16 vectored IRQ slots. Slot 0 has the highest priority and slot 15 the lowest.

Timer0ChannelNumber	equ	4				; UM, Table 63
Timer0Mask	equ	1<<Timer0ChannelNumber	; UM, Table 63
IRQslot_en	equ	5						; UM, Table 58


IO0DIR	EQU 0xE0028008
IO0CLR	EQU 0xE002800C
IO0SET	EQU 0xE0028004
I01PIN  EQU 0xE0028010
IO1DIR	EQU 0xE0028018 	
IO1CLR	EQU 0xE002801C
IO1SET	EQU 0xE0028014



	AREA	InitialisationAndMain, CODE, READONLY
	IMPORT	main

	EXPORT	start
start
; Set up for LED, VIC and timer

 	ldr	r8,=IO0DIR
	ldr	r9,=0x00260000	;select RGB LED pins (17, 18, 21)
	str	r9,[r8]			;make them outputs
	ldr	r8,=IO0SET
	str	r9,[r8]			;set them to turn the LEDs off
	ldr	r9,=IO0CLR

		;set up for input pins
	ldr	r1,=IO1DIR
	ldr	r2,=0x000f0000	;select P1.19--P1.16
	str	r2,[r1]		;make them outputs
	ldr	r1,=IO1SET
	str	r2,[r1]		;set them to turn the LEDs off
	ldr	r2,=IO1CLR
	;/set up

; Initialise the VIC
	ldr	r0,=VIC			

	ldr	r1,=interrupt_handler			 ;Irq handler
	str	r1,[r0,#VectAddr0] 	; associate our interrupt handler with Vectored Interrupt 0

	mov	r1,#Timer0ChannelNumber+(1<<IRQslot_en)
	str	r1,[r0,#VectCtrl0] 	; make Timer 0 interrupts the source of Vectored Interrupt 0

	mov	r1,#Timer0Mask
	str	r1,[r0,#IntEnable]	; enable Timer 0 interrupts to be recognised by the VIC

	mov	r1,#0
	str	r1,[r0,#VectAddr]   	; remove any pending interrupt (Just in case)

; Initialise Timer 0
	ldr	r0,=T0			

	mov	r1,#TimerCommandReset
	str	r1,[r0,#TCR]

	mov	r1,#TimerResetAllInterrupts
	str	r1,[r0,#IR]

	ldr	r1,=(14745600/200)-1	 ; 5 ms = 1/200 second = (14745600/200)-1 (basically, whenever the system timer equals this weird number, 5ms have passed)
	str	r1,[r0,#MR0]													   		

	mov	r1,#TimerModeResetAndInterrupt
	str	r1,[r0,#MCR]

	mov	r1,#TimerCommandRun
	str	r1,[r0,#TCR]


	ldr r2, =1	;up/down flag
	ldr r1, =1	;which light
	ldr r0, =0x00260000	;mask to turn off all LED

;from here, initialisation is finished, so it should be the main body of the main program

aloop 
	bl subroutine
	b	aloop  		; branch always
;main program execution will never drop below the statement above.

	AREA	InterruptStuff, CODE, READONLY
interrupt_handler	sub	lr,lr,#4
	stmfd	sp!,{r0-r3,lr}	; the lr will be restored to the pc	--> saving the workspace to the stack
	
	ldr r2, =counter
	ldr r3, [r2]
	add r3, r3, #1	 ;increment counter
	str r3, [r2] 		;Store new counter value
	
;this is where we stop the timer from making the interrupt request to the VIC
;i.e. we 'acknowledge' the interrupt
	ldr	r0,=T0
	mov	r1,#TimerResetTimer0Interrupt
	str	r1,[r0,#IR]	   	; remove MR0 interrupt request from timer

;here we stop the VIC from making the interrupt request to the CPU:
	ldr	r0,=VIC 
	mov	r1,#0
	str	r1,[r0,#VectAddr]	; reset VIC	  -->Clearing it		
	ldmfd	sp!,{r0-r3,pc}^	; return from interrupt, restoring previous state
							; and also restoring the CPSR

	AREA	Subroutines, CODE, READONLY
subroutine		

	
	
	ldr r7, =I01PIN			;Get button press
	ldr r4, [r7]
	ldr r7, =0x00f00000
	and r4, r4, r7
	eor r4, r4, r7
	cmp r4, #0x00000000
	BEQ nobutton

	cmp r2, #1
	BEQ reverse_zero
	ldr r2, =1
	B nobutton
reverse_zero
	ldr r2, =0

nobutton


	;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	;This happens every 0.25 seconds
	ldr r11, =counter
	ldr r12, [r11]
	cmp r12, #50	   				;Count to 50 --> 50*5ms = .25s
	bne subroutine

	
	str r0, [r8] ;clear LED

	cmp r1, #1
	BEQ red_on
	cmp r1, #2
	BEQ blue_on
	cmp r1, #3
	BEQ green_on
	
red_on
	ldr r3, =0x00020000
	B increment	
blue_on
	ldr r3, =0x00040000
	B increment
green_on
	ldr r3, =0x00200000
	B increment


increment

	cmp r2, #1		  ;R -> B -> G
	BNE down_loop	
	add r1, r1, #1
	cmp r1, #4
	BNE set_zero
	ldr r1, =1
set_zero
	B light


down_loop
	sub r1, r1, #1	   ;G -> B -> R
	cmp r1, #0
	BNE set_four
	ldr r1, =3
set_four

light	
	cmp r3, #0x00020000
	bne dont_need_to_turn_off_last
	ldr r6, =0x00260000
	str	r6,[r8]			;set the bit -> turn off the LED
	
dont_need_to_turn_off_last

	str	r3,[r9]	   		; clear the bit -> turn on the LED
	cmp	r3,r11			;If current value is same of mask value
	bne dontstartagain
	ldr r10, = shift_counter
	mov r12, #-1
	str r12, [r10]
	
dontstartagain
	mov r12, #0		;Restarting the counter to 1 second
	ldr r11, =counter
	str r12, [r11] 	;Stores zero value into counter
	
	bx lr

	AREA	Stuff, DATA, READWRITE
counter		 	dcd		0	 ;Set the value to 0
shift_counter 	dcd		-1	 ;Set the value to 0
	END