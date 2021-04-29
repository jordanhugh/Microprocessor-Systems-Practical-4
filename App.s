; Definitions  -- references to 'UM' are to the User Manual.

; Timer Stuff -- UM, Table 173
T0	equ	0xE0004000					; Timer 0 Base Address
T1	equ	0xE0008000

IR	equ	0						; Interrupt Register. The IR can be written to clear
								; interrupts. The IR can be read to identify which of
								; eight possible interrupt sources are pending. 
TCR	equ	4						; Timer Control Register. The TCR is used to control
								; the Timer Counter functions. The Timer Counter can
								; be disabled or reset through the TCR. 
MCR	equ	0x14					; Match Control Register. The MCR is used to control
								; if an interrupt is generated and if the TC is reset
								; when a Match occurs.
MR0	equ	0x18					; Match Register 0. MR0 can be enabled through the
								; MCR to reset the TC, stop both the TC and PC,
								; and/or generate an interrupt every time MR0
								; matches the TC. 

TimerCommandReset 		equ 2
TimerCommandRun	 		equ 1
TimerModeResetAndInterrupt 	equ 3
TimerResetTimer0Interrupt 	equ 1
TimerResetAllInterrupts		equ 0xFF

; VIC Stuff -- UM, Table 41
VIC		equ	0xFFFFF000				; VIC Base Address
IntEnable	equ	0x10					; Interrupt Enable Register. This register controls which of the
								; 32 interrupt requests and software interrupts are enabled to
								; contribute to FIQ or IRQ.
VectAddr	equ	0x30					; Vector Address Register. When an IRQ interrupt occurs, the
								; IRQ service routine can read this register and jump to the
								; value read.
VectAddr0	equ	0x100					; Vector address 0 register. Vector Address Registers 0-15
								; hold the addresses of the Interrupt Service routines (ISRs)
								; for the 16 vectored IRQ slots
VectCtrl0	equ	0x200					; Vector control 0 register. Vector Control Registers 0-15 each
								; control one of the 16 vectored IRQ slots. Slot 0 has the
								; highest priority and slot 15 the lowest.

Timer0ChannelNumber 	equ	4				; UM, Table 63
Timer0Mask		equ	1 <<Timer0ChannelNumber		; UM, Table 63
IRQslot_en		equ	5				; UM, Table 58

		AREA	InitialisationAndMain, CODE, READONLY
		IMPORT	main
		EXPORT	start
start

; Initialisation code
; Initialise the VIC
		ldr 	r0, =VIC				; looking at you, VIC!

		ldr 	r1, =irqhan
		str 	r1, [r0, #VectAddr0] 			; associate our interrupt handler with Vectored Interrupt 0

		mov 	r1, #Timer0ChannelNumber+(1<<IRQslot_en)
		str 	r1, [r0, #VectCtrl0] 			; make Timer 0 interrupts the source of Vectored Interrupt 0

		mov 	r1, #Timer0Mask
		str 	r1, [r0, #IntEnable]			; enable Timer 0 interrupts to be recognised by the VIC

		mov 	r1, #0
		str 	r1, [r0, #VectAddr]   			; remove any pending interrupt (may not be needed)

; Initialise Timer 0
		ldr 	r0, =T0					; looking at you, Timer 0!

		mov 	r1, #TimerCommandReset
		str 	r1, [r0, #TCR]

		mov 	r1, #TimerResetAllInterrupts
		str 	r1, [r0, #IR]

		ldr 	r1, =(14745600/200) - 1	 		; 5 ms = 1/200 second
		str 	r1, [r0, #MR0]

		mov 	r1, #TimerModeResetAndInterrupt
		str 	r1, [r0, #MCR]

		mov 	r1, #TimerCommandRun
		str 	r1, [r0, #TCR]

; Setup GPIO
IO0DIR		equ	0xE0028008
IO0SET		equ	0xE0028004
IO0CLR		equ	0xE002800C
IO0PIN  	equ 0xE0028000
	
		ldr 	r0, =IO0DIR
		ldr 	r1, =0x00260000				; Select P0.17, P0.18, P0.21
		str 	r1, [r0]				; Make them outputs
		ldr 	r0, =IO0SET
		str 	r1, [r0]				; Set them to turn the LEDs off
		ldr 	r1, =IO0CLR
		
; From here, initialisation is finished, so it should be the main body of the main program
wh1		ldr	r2, =leds
		mov	r4, #8
		ldr	r3, [r2], #4
		str 	r3, [r1]
dowh1		ldr	r5, =timer
		ldr	r6, [r5]
		cmp	r6, #200
		bne	endif1
		mov	r6, #0
		str	r6, [r5]
		sub	r4, r4, #1
		str	r3, [r0]
		ldr	r3, [r2], #4
		str 	r3, [r1]
endif1		cmp	r4, #0
		bne	dowh1
		b	wh1					; branch always

;main program execution will never drop below the statement above.
stop		B	stop

		AREA	InterruptStuff, CODE, READONLY	
irqhan	sub		lr, lr, #4
		stmfd 	sp!, {r0-r1, lr}			; the lr will be restored to the pc

;this is the body of the interrupt handler
		
;here you'd put the unique part of your interrupt handler
;all the other stuff is "housekeeping" to save registers and acknowledge interrupts
		ldr	r0, =timer
		ldr	r1, [r0]
		add	r1, r1, #1
		str	r1, [r0]
		
;this is where we stop the timer from making the interrupt request to the VIC
;i.e. we 'acknowledge' the interrupt

		ldr	r0, =T0
		mov	r1, #TimerResetTimer0Interrupt
		str	r1, [r0, #IR]	   			; remove MR0 interrupt request from timer

;here we stop the VIC from making the interrupt request to the CPU:
		ldr	r0, =VIC
		mov	r1, #0
		str	r1, [r0, #VectAddr]			; reset VIC
		ldmfd 	sp!, {r0-r1, pc}^			; return from interrupt, restoring pc from lr
								; and also restoring the CPSR
			


		AREA	LEDS, DATA, READONLY
leds	dcd 	0x00000000	;BLACK
		dcd 	0x00020000	;RED
		dcd 	0x00200000	;GREEN
		dcd 	0x00040000	;BLUE
		dcd 	0x00240000	;CYAN
		dcd 	0x00060000	;MAGENTA
		dcd 	0x00220000	;YELLOW
		dcd 	0x00260000	;WHITE
			
		AREA	TIMER, DATA, READWRITE
timer	dcd	0x00000000



		END
		
		

; Testbenches		
; Setup GPIO0
/*
IO1DIR		equ	0xE0028018
IO1SET		equ	0xE0028014
IO1CLR		equ	0xE002801C
	
		ldr 	r2, =IO1DIR
		ldr 	r3, =0x000f0000				; Select P1.16 - P1.19
		str 	r3, [r2]				; Make them outputs
		ldr 	r2, =IO1SET
		str 	r3, [r2]				; Set them to turn the LEDs off
		ldr 	r3, =IO1CLR
*/	



; Test RGB LEDS
/*		ldr 	r7, =0x00200000
wloop		ldr 	r4, =leds
floop		ldr 	r5, [r4], #4
		str 	r5, [r3]				; Clear the bit -> turn on the LED

		ldr 	r6, =4000000		
dowh2		subs 	r6, r6, #1				; Delay for about a second
		bne 	dowh2
		
		str 	r5, [r2]				; Set the bit -> turn off the LED
		
		ldr 	r6, =4000000	
dowh3		subs 	r6, r6, #1				; Delay for about a second
		bne 	dowh3
		
		cmp 	r5, r7
		bne 	floop
		b 	wloop  					; branch always
*/		



; Test Interrupt
/*
		ldr	r0, =timer
		ldr	r1, [r0]
		add	r1, r1, #1
		
		mov	r1, r1, lsl #16
		str 	r1, [r3]
		
		ldr 	r5, =4000000  	;new time variable added to show that the code is unique.
dloop		subs 	r5, r5, #1
		bne	dloop
		
		str	r1, [r2]
		mov	r1, r1, lsr #16
		
		str	r1, [r0]
*/
*/