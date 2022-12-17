
	********************************************************
	*
	*   Son Shu Shi 100% + Replicants revival
	*
	*   Cracktro Shell
	*
	*   This "shell" is a framework for cracktros.
	*   It provides system initialization/restoration routines,
	*   VBL handler support (for frame rendering), 50Hz timer
	*   handler support (for music playback), and mechanisms for
	*   exchanging information and synchronizing with the loader
	*   of the cracked game.
	*
	*   The cracktro is not "merged" with the loader but executed
	*   as an external program by the loader.
	*
	*   This shell is used by the two cracktros that come with
	*   the crack of Son Shu Shi:
	*   - The main cracktro coded by Kelly.X / HMD
	*   - The hidden cracktro coded by Fury / Replicants
	*
	*   Shell coded by Orion / Replicants
	*   v1.5 - 1 October 2022.
	*
	*   You should read CRACKTRO.S for an example of how to
	*   use this shell.
	*
	*   You should also read the comments at the beginning of
	*   LOADER1.S for a description of the organization and
	*   contents of the various source files of this crack.
	*
	********************************************************

	;
	; Caution:
	;
	; - Do not modify this file, just include it "as is"
	;   in the main source file of the cracktro.
	;
	; - This code uses periods (.) for local labels.
	;   So make sure that the U- option is set in the main
	;   source file (where this code is included).
	;

	;
	; The intro which includes this file is expected to define
	; the following constants:
	;
	; STACK_SIZE
	;   Size of the intro stack, allocated by the shell.
	;
	; SHELL_ENABLE_DEBUG
	;   If debugging under MonST is needed, just set it to 1.
	;
	; SHELL_MFP_AUTO_EOI
	;   Select the EOI mode of the MFP (required for sync-buzzer
	;   musics).
	;
	; SHELL_ANIM_DURATION
	;   Allows you to configure the minimum duration of the
	;   loading animation, regardless of the storage medium
	;   or the speed of the machine.
	;
	; The intro might also define the following optional constants:
	;
	; SHELL_BSS_IN_DATA
	;   Place the uninitialized data of the shell in the DATA
	;   section rather than in the BSS.
	;
	; SHELL_BSS_IN_TEXT
	;   Place the uninitialized data of the shell in the TEXT
	;   section rather than in the BSS.
	;

	; Size of the special stack used at exit.
SHELL_EXIT_STACK_SIZE      =	512

	;
	; Shell code.
	;
	section	text

	;
	; shell_entry()
	;
	; Program entry point.
	;
	; Initialize the system (HW & SW), execute the intro,
	; restore the system and exit (return to the parent
	; program).
	;
shell_entry:
	; Save the basepage.
	movea.l	4(a7),a0
	move.l	a0,shell_basepage

	; If "REPS" is passed in the command line by the parent
	; program, then the intro is executed by the loader and
	; the video controller is already configured.
	; In this case, the Shifter configuration is used "as is"
	; (as set by the loader), in order to be compatible with
	; special machines such as the Falcon or the TT.
	; In addition, if the letter before "REPS" is 'H' then
	; the current intro is the hidden screen and the loading
	; animation is still in progress.
	; In that case, the VBL and HBL routines are also used
	; "as is" to let the animation play.
	; Here, the command line is simply checked to determine
	; whether the intro is executed by the loader or by the
	; GEMDOS and the result is saved for later use.
	cmpi.b	#$05,128(a0)    ; Command line argument
	bne.s	.mshrnk
	cmpi.l	#'REPS',130(a0) ; Command line argument
	bne.s	.mshrnk
	; Save the letter indicating whether the current intro
	; is the main intro (letter 'M') or the hidden intro
	; (letter 'H').
	move.b	129(a0),shell_loader

	; Return unneeded memory to the TOS.
.mshrnk	lea	shell_stack_top,a7
	move.l	8(a0),d0
	add.l	$c(a0),d0
	add.l	$14(a0),d0
	add.l	$1c(a0),d0
	sub.l	a0,d0
	move.l	d0,-(a7)
	pea	(a0)
	move.l	#$4a0000,-(a7)
	trap	#1
	lea	12(a7),a7

	; Switch to Supervisor mode and set up a safe stack.
.super	clr.l	-(a7)
	move.w	#$20,-(a7)
	trap	#1
	addq.l	#6,a7
	move.l	d0,shell_ssp_saved

	; Initialize the system (HW & SW).
	bsr	shell_init

	; Execute the intro.
	movem.l	d0-a6,-(a7)
	bsr	intro_start
	; Exception handlers jump here in case of a CPU crash.
shell_longjmp:
	tst.b	shell_loader    ; If no loader, ignore
	beq.s	.regs           ;  the return value 
	move.w	d0,.retval+2    ; Patch Pterm return value
.regs	movem.l	(a7)+,d0-a6

	; Restore the system.
	bsr	shell_exit

	; Switch back to User mode and set up a special stack
	; used to exit (see below).
	move.l	shell_ssp_saved,-(a7)
	move.w	#$20,-(a7)
	trap	#1
	lea	shell_pterm+SHELL_EXIT_STACK_SIZE,a7

	; Before quitting the program, the program memory is
	; shrunk to the smallest possible size.
	; Indeed, when a program is launched from an emulated
	; GEMDOS drive on TOS 1.0 and 1.02, the program memory
	; is not freed on exit. So shrinking the program memory
	; before exiting allows to free most of this memory and
	; thus to work around the problem of the GEMDOS drive
	; emulation under Hatari when early TOSes are used.
	; The stack is set up (above) so that it is located in
	; the remaining allocated memory.
	movea.l	shell_basepage,a0

	; Patch the basepage to match the shrunk memory.
	move.l	#shell_pterm+SHELL_EXIT_STACK_SIZE-shell_entry,12(a0)
	move.l	a7,16(a0)
	clr.l	20(a0)
	move.l	a7,24(a0)
	clr.l	28(a0)

	; Shrink the program memory.
	move.l	a7,d0
	sub.l	a0,d0
	move.l	d0,-(a7)
	pea	(a0)
	move.l	#$4a0000,-(a7)
	trap	#1
	lea	12(a7),a7

	; Terminate (exit) the program and return an error code
	; to the parent program.
	; This error code is the one returned by the intro.
.retval	move.w	#0,-(a7)
	move.w	#$4c,-(a7)
shell_pterm:
	trap	#1

	; Reached in case of a CPU crash (trap #1 is replaced
	; with a NOP. See shell_exception).
	illegal

	;
	; shell_hidemouse()
	;
	; Hide the mouse cursor.
	;
shell_hidemouse:
	movem.l	d0-d2/a0-a2,-(a7)

	dc.w	$a00a           ; Hide mouse

	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; shell_showmouse()
	;
	; Show the mouse cursor only if the number of "show mouse"
	; matches the number of "hide mouse".
	;
shell_showmouse:
	movem.l	d0-d2/a0-a2,-(a7)

	; Setting intin[0] to -1 makes sure the "hide" depth
	; is taken into account.
	dc.w	$a000           ; Line-A init
	move.l	8(a0),-(a7)     ; Save original intin
	move.l	a0,-(a7)        ; Save Line-A struct
	pea	-1.w            ; intin[0]=-1
	move.l	a7,8(a0)        ; Set new intin
	dc.w	$a009           ; Show mouse
	addq.l	#4,a7
	movea.l	(a7)+,a0        ; Line-A struct
	move.l	(a7)+,8(a0)     ; Restore intin

	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; shell_send_ikbd()
	;
	; Send a command to the IKBD.
	;
	; In:
	;   d0: IKBD command
	;
shell_send_ikbd:
	movem.l	d1-d2,-(a7)

	; Save the current interrupt mask.
	move	sr,d1
.poll	; Mask the interrupts.
	move	#$2700,sr
	; Check if the ACIA is ready to send data
	; (Tx data register empty).
	btst	#1,$fffffc00.w
	bne.s	.ready
	; ACIA is not ready yet.
	; Restore the interrupt mask and wait a bit.
	move	d1,sr
	move.w	#$600,d2
.wait	dbf	d2,.wait
	; Try again.
	bra.s	.poll
.ready	; ACIA is ready, send the command.
	move.b	d0,$fffffc02.w
	; Restore the interrupt mask.
	move	d1,sr
.flush	; Wait until the command has been actually sent.
	btst	#1,$fffffc00.w
	beq.s	.flush

	movem.l	(a7)+,d1-d2
	rts

	;
	; shell_flush_acia()
	;
	; Flush the ACIA receive buffer.
	;
	; Out:
	;   d0: 1 if the ACIA Rx was full and has been flushed,
	;       0 otherwise
	;
shell_flush_acia:
	moveq.l	#0,d0
.again	btst	#0,$fffffc00.w
	beq.s	.done
	tst.b	$fffffc02.w
	moveq.l	#1,d0
	bra.s	.again
.done	rts

	;
	; shell_read_acia()
	;
	; Read a byte from the IKBD/ACIA.
	;
	; Out:
	;   d0: the byte read from the ACIA if Rx was full,
	;       0 otherwise
	;
shell_read_acia:
	ifeq SHELL_ENABLE_DEBUG

	moveq.l	#0,d0
	btst	#0,$fffffc00.w
	beq.s	.empty
	move.b	$fffffc02.w,d0
.empty	rts

	elseif	; SHELL_ENABLE_DEBUG

	move.b	$fffffc02.w,d0
	rts

	endc	; SHELL_ENABLE_DEBUG

	;
	; shell_wait_ikbd()
	;
	; Wait until the IKBD is idle.
	; Make sure that all pending IKBD events are consumed
	; by the current IKBD interrupt handler.
	;
shell_wait_ikbd:
	movem.l	d0-d1/a0,-(a7)

	; Hook the IKBD interrupt vector.
	; Each time an IKBD interrupt is triggered, a flag is
	; set in shell_ikbd_flag.
	lea	.isr_hook(pc),a0
	move.l	$118.w,(.isr_orig+2-.isr_hook)(a0)
	move.l	a0,$118.w

	; Wait until the IKBD is idle: at least 20 milliseconds
	; (4 timer C interruptions) must elapse without any
	; IKBD interruptions.
.again	sf.b	shell_ikbd_flag ; Clear the flag
	move.l	$4ba.w,d0       ; Timer C counter (_hz_200)
	addq.l	#4,d0           ; 4 timer C periods = 20 ms
.wait	stop	#$2300          ; Wait for interrupt
	tst.b	shell_ikbd_flag ; Any IKBD interrupt?
	bne.s	.again          ; Yes, let's start over
	move.l	d0,d1
	sub.l	$4ba.w,d1       ; Wait for 20 ms
	bpl.s	.wait

	; Restore the original IKBD interrupt vector.
	move.l	(.isr_orig+2-.isr_hook)(a0),$118.w

	movem.l	(a7)+,d0-d1/a0
	rts

.isr_hook
	; Indicate that an IKBD interrupt has occurred.
	st	shell_ikbd_flag
.isr_orig
	; Call the original IKBD handler.
	jmp	$0.l

	;
	; shell_ikbd_off()
	;
	; Shut down the IKBD smoothly (making sure that all
	; pending IKBD events have been processed by the TOS).
	;
shell_ikbd_off:
	move.l	d0,-(a7)

	; Disable the mouse.
	moveq.l	#$12,d0
	bsr	shell_send_ikbd

	; Disable the joystick.
	moveq.l	#$15,d0
	bsr	shell_send_ikbd

	; Wait for the TOS to process IKBD events.
	bsr.s	shell_wait_ikbd

	; Pause IKBD transfers.
	moveq.l	#$13,d0
	bsr	shell_send_ikbd

	; Wait for the TOS to process IKBD events.
	bsr.s	shell_wait_ikbd

	move.l	(a7)+,d0
	rts

	;
	; shell_ikbd_on()
	;
	; Resume IKBD.
	;
shell_ikbd_on:
	move.l	d0,-(a7)

	; Flush the ACIA buffer.
	bsr	shell_flush_acia

	; Resume IKBD transfers.
	moveq.l	#$11,d0
	bsr	shell_send_ikbd

	move.l	(a7)+,d0
	rts

	;
	; shell_reset_bioskeys()
	;
	; Reset the internal TOS state of the key repeat and
	; special keys.
	;
	; Since the TOS IKBD/ACIA handler is disabled, the TOS
	; cannot be notified of the release of the key that was
	; pressed at the time the intro was launched.
	; This may result in the key being repeated after the
	; intro when the TOS handlers are reinstalled.
	; To avoid this, the internal TOS state of the key repeat
	; and special keys is reset.
	;
shell_reset_bioskeys:
	movem.l	d0-d2/a0-a2,-(a7)

	; Reset the current state of the keyboard 'special' keys.
	clr.w	-(a7)
	move.w	#$b,-(a7)
	trap	#13
	addq.l	#4,a7

	; Reset the current state of the key repeat.
	; The key repeat state is not accessible through a public
	; interface, so locate the internal TOS variable that
	; contains the last key pressed (candidate to be repeated)
	; to reset it.
	; The key repeat is handled by the timer C handler. The
	; code of this handler is similar on all legacy TOSes and
	; the address of the internal variable we are looking for
	; is in the first instructions, after bit 1 of the system
	; variable $484 is tested.
	; This heuristic works on all TOS versions but EmuTOS.
	move.l	$114.w,d0
	btst	#0,d0
	bne.s	.ret
	cmp.l	$4f2.w,d0
	blo.s	.ret
	movea.l	d0,a0
	move.w	#127,d0
.srch	addq.l	#2,a0
	cmpi.l	#$00010484,(a0)
	dbeq	d0,.srch
	tst.w	d0
	bmi.s	.ret
	cmpi.b	#$08,-2(a0)
	bne.s	.ret
	cmpi.b	#$4a,6(a0)
	bne.s	.ret
	moveq.l	#0,d0
	move.w	8(a0),d0
	movea.l	d0,a0
	clr.b	(a0)

.ret	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; shell_save_mfp()
	;
	; Save the MFP configuration.
	;
shell_save_mfp:
	move.l	a0,-(a7)

	lea	shell_mfp_saved,a0
	move.b	$fffffa17.w,(a0)+   ; Vector register
	move.b	$fffffa13.w,(a0)+   ; Mask A
	move.b	$fffffa15.w,(a0)+   ; Mask B
	move.b	$fffffa07.w,(a0)+   ; Enable A
	move.b	$fffffa09.w,(a0)+   ; Enable B

	; Clear the timer B channel if it was set for the
	; loading animation.
	cmpi.b	#'H',shell_loader
	bne.s	.ret
	bclr.b	#0,-5(a0)
	bclr.b	#0,-3(a0)

.ret	movea.l	(a7)+,a0
	rts

	;
	; shell_stop_mfp()
	;
	; Shut down the MFP.
	;
shell_stop_mfp:
	; Stop all timers.
	clr.b	$fffffa19.w         ; Timer A
	clr.b	$fffffa1b.w         ; Timer B
	clr.b	$fffffa1d.w         ; Timers C & D

	; Disable MFP A & B channels.
	clr.b	$fffffa07.w         ; Enable A
	clr.b	$fffffa13.w         ; Mask A
	clr.b	$fffffa09.w         ; Enable B
	clr.b	$fffffa15.w         ; Mask B

	; Clear pending interrupts.
	clr.b	$fffffa0b.w         ; Pending A
	clr.b	$fffffa0f.w         ; In-service A
	clr.b	$fffffa0d.w         ; Pending B
	clr.b	$fffffa11.w         ; In-service B
	rts

	;
	; shell_stop_mfp_anim()
	;
	; Shut down the MFP when executed by the loader and the
	; loading animation is in progress.
	; Keep only the timer B channel enabled, so that
	; the loading animation can continue.
	;
shell_stop_mfp_anim:
	; Stop all timers, keep timer B.
	clr.b	$fffffa19.w         ; Timer A
	clr.b	$fffffa1d.w         ; Timers C & D

	; Disable MFP A & B channels, keep timer B.
	andi.b	#1,$fffffa07.w      ; Enable A
	andi.b	#1,$fffffa13.w      ; Mask A
	clr.b	$fffffa09.w         ; Enable B
	clr.b	$fffffa15.w         ; Mask B

	; Clear pending interrupts, keep timer B.
	andi.b	#1,$fffffa0b.w      ; Pending A
	andi.b	#1,$fffffa0f.w      ; In-service A
	clr.b	$fffffa0d.w         ; Pending B
	clr.b	$fffffa11.w         ; In-service B
	rts

	;
	; shell_restore_mfp()
	;
	; Restore the MFP configuration.
	;
shell_restore_mfp:
	move.l	a0,-(a7)

	bsr.s	shell_stop_mfp      ; Disable MFP ints

	; Restore MFP A & B.
	lea	shell_mfp_saved,a0
	move.b	(a0)+,$fffffa17.w   ; Vector register
	move.b	(a0)+,$fffffa13.w   ; Mask A
	move.b	(a0)+,$fffffa15.w   ; Mask B
	move.b	(a0)+,$fffffa07.w   ; Enable A
	move.b	(a0)+,$fffffa09.w   ; Enable B

	bsr.s	shell_setup_timerc  ; Enable timer C

	movea.l	(a7)+,a0
	rts

	;
	; shell_setup_timerc()
	;
	; Set up and enable timer C.
	; Timer C Frequency = 2457600 / 64 / 192 = 200Hz.
	;
shell_setup_timerc:
	clr.b	$fffffa1d.w         ; Timer C/D Ctrl = stop
	bset.b	#5,$fffffa15.w      ; Timer C Int Mask
	bset.b	#5,$fffffa09.w      ; Timer C Enable
	bclr.b	#5,$fffffa11.w      ; Timer C In-service
	move.b	#192,$fffffa23.w    ; Timer C Data = 192
	move.b	#$50,$fffffa1d.w    ; Timer C Ctrl = div by 64
	rts

	;
	; shell_save_vectors()
	;
	; Save CPU exception & interrupt vectors.
	;
shell_save_vectors:
	move.l	a0,-(a7)

	lea	shell_vectors_saved,a0

	; Save CPU exception handlers.
	move.l	$08.w,(a0)+     ; Bus error
	move.l	$0c.w,(a0)+     ; Address error
	move.l	$10.w,(a0)+     ; Illegal instruction
	move.l	$18.w,(a0)+     ; CHK, CHK2 instruction
	move.l	$1c.w,(a0)+     ; cpTRAPcc, TRAPcc, TRAPV
	move.l	$20.w,(a0)+     ; Privilege violation
	move.l	$28.w,(a0)+     ; Line-A
	move.l	$2c.w,(a0)+     ; Line-F

	; Save Auto-Vector interrupt handlers.
	move.l	$68.w,(a0)+     ; HBL
	move.l	$70.w,(a0)+     ; VBL
	move.l	$78.w,(a0)+     ; MFP

	; Save User-assigned interrupt handlers.
	move.l	$100.w,(a0)+    ; Centronics Busy
	move.l	$104.w,(a0)+    ; RS-232 DCD
	move.l	$108.w,(a0)+    ; RS-232 CTS
	move.l	$10c.w,(a0)+    ; Blitter
	move.l	$110.w,(a0)+    ; Timer D
	move.l	$114.w,(a0)+    ; Timer C
	move.l	$118.w,(a0)+    ; IKBD/ACIA
	move.l	$11c.w,(a0)+    ; FDC
	move.l	$120.w,(a0)+    ; Timer B (HBL)
	move.l	$124.w,(a0)+    ; RS-232 TX Error
	move.l	$128.w,(a0)+    ; RS-232 TX Empty
	move.l	$12c.w,(a0)+    ; RS-232 RX Error
	move.l	$130.w,(a0)+    ; RS-232 RX Full
	move.l	$134.w,(a0)+    ; Timer A
	move.l	$138.w,(a0)+    ; RS-232 Ring Detect
	move.l	$13c.w,(a0)+    ; MFP-15: Monochrome Detect

	; Original VBL and timer B handlers were saved in $90 and
	; $94 respectively if the loading animation is playing.
	cmpi.b	#'H',shell_loader
	bne.s	.ret
	move.l	$90.w,(-4*18)(a0) ; Actual VBL
	move.l	$94.w,(-4*8)(a0)  ; Actual Timer B (HBL)

.ret	movea.l	(a7)+,a0
	rts

	;
	; shell_restore_vectors()
	;
	; Restore CPU exception & interrupt vectors.
	;
shell_restore_vectors:
	move.l	a0,-(a7)

	lea	shell_vectors_saved,a0

	; Restore CPU exception handlers.
	move.l	(a0)+,$08.w     ; Bus error
	move.l	(a0)+,$0c.w     ; Address error
	move.l	(a0)+,$10.w     ; Illegal instruction
	move.l	(a0)+,$18.w     ; CHK, CHK2 instruction
	move.l	(a0)+,$1c.w     ; cpTRAPcc, TRAPcc, TRAPV
	move.l	(a0)+,$20.w     ; Privilege violation
	move.l	(a0)+,$28.w     ; Line-A
	move.l	(a0)+,$2c.w     ; Line-F

	; Restore Auto-Vector interrupt handlers.
	move.l	(a0)+,$68.w     ; HBL
	move.l	(a0)+,$70.w     ; VBL
	move.l	(a0)+,$78.w     ; MFP

	; Restore User-assigned interrupt handlers.
	move.l	(a0)+,$100.w    ; Centronics Busy
	move.l	(a0)+,$104.w    ; RS-232 DCD
	move.l	(a0)+,$108.w    ; RS-232 CTS
	move.l	(a0)+,$10c.w    ; Blitter
	move.l	(a0)+,$110.w    ; Timer D
	move.l	(a0)+,$114.w    ; Timer C
	move.l	(a0)+,$118.w    ; IKBD/ACIA
	move.l	(a0)+,$11c.w    ; FDC
	move.l	(a0)+,$120.w    ; Timer B (HBL)
	move.l	(a0)+,$124.w    ; RS-232 TX Error
	move.l	(a0)+,$128.w    ; RS-232 TX Empty
	move.l	(a0)+,$12c.w    ; RS-232 RX Error
	move.l	(a0)+,$130.w    ; RS-232 RX Full
	move.l	(a0)+,$134.w    ; Timer A
	move.l	(a0)+,$138.w    ; RS-232 Ring Detect
	move.l	(a0)+,$13c.w    ; MFP-15: Monochrome Detect

	movea.l	(a7)+,a0
	rts

	;
	; shell_catch_exceptions()
	;
	; Catch CPU exceptions so that a safe context can be
	; restored in case of a CPU crash.
	;
shell_catch_exceptions:
	move.l	a0,-(a7)

	lea	shell_exception(pc),a0

	; Install a handler for all CPU exceptions.
	move.l	a0,$08.w        ; Bus error
	move.l	a0,$0c.w        ; Address error
	move.l	a0,$10.w        ; Illegal instruction
	move.l	a0,$18.w        ; CHK, CHK2 instruction
	move.l	a0,$1c.w        ; cpTRAPcc, TRAPcc, TRAPV
	move.l	a0,$20.w        ; Privilege violation
	move.l	a0,$28.w        ; Line-A
	move.l	a0,$2c.w        ; Line-F

	movea.l	(a7)+,a0
	rts

	;
	; shell_exception()
	;
	; Restore a safe context in case of a CPU crash.
	;
shell_exception:
	; Mask interrupts and restore the stack.
	move.w	#$2700,sr
	lea	shell_stack_top-(15*4),a7
	; Do not execute pterm, but an illegal instruction instead.
	move.w	#$4e71,shell_pterm
	; Resume the execution as if the intro had returned.
	moveq.l	#1,d0
	bra	shell_longjmp

	;
	; shell_ints_safe()
	;
	; Disable all interrupts and install the VBL handler of
	; the shell. By default, this handler only updates
	; _frclock ($466).
	;
	; - Auto-Vector interrupts are disabled by installing
	;   a dummy handler (which just returns).
	; - MFP interrupts (User-assigned) are disabled on the
	;   MFP. A dummy handler is also installed for each of
	;   them.
	; - If the loading animation is currently playing, the
	;   timer B (HBL) is not touched and the VBL routine
	;   of the animation is called by the new VBL handler.
	; - The End-Of-Interrupt mode of the MFP is configured.
	;
	; In:
	;   d0: if d0='H', the loading animation is currently
	;       playing and must be kept.
	;
shell_ints_safe:
	move.l	a0,-(a7)

	lea	shell_handler_void(pc),a0

	; Install the dummy handler for Auto-Vector interrupts.
	move.l	a0,$68.w        ; HBL
	move.l	a0,$78.w        ; MFP

	; Install the dummy handler for User-assigned interrupts.
	move.l	a0,$100.w       ; Centronics Busy
	move.l	a0,$104.w       ; RS-232 DCD
	move.l	a0,$108.w       ; RS-232 CTS
	move.l	a0,$10c.w       ; Blitter
	move.l	a0,$110.w       ; Timer D
	move.l	a0,$114.w       ; Timer C
	move.l	a0,$118.w       ; IKBD/ACIA
	move.l	a0,$11c.w       ; FDC
	move.l	a0,$124.w       ; RS-232 TX Error
	move.l	a0,$128.w       ; RS-232 TX Empty
	move.l	a0,$12c.w       ; RS-232 RX Error
	move.l	a0,$130.w       ; RS-232 RX Full
	move.l	a0,$134.w       ; Timer A
	move.l	a0,$138.w       ; RS-232 Ring Detect
	move.l	a0,$13c.w       ; MFP-15: Monochrome Detect

	; Check if the loading animation is playing.
	cmpi.b	#'H',d0
	beq.s	.anim

	; Standalone mode, no loading animation.

	move.l	a0,$120.w       ; Timer B (HBL)

	; Disable MFP interrupts (on the MFP).
	bsr	shell_stop_mfp

	; Install the VBL handler of the shell, as well as an
	; empty user-defined VBL routine.
	lea	shell_user_func_void(pc),a0
	bra.s	.vbl

.anim	; The loading animation is playing and must be kept.

	; Do not touch the timer B vector ($120).

	; Disable MFP interrupts (on the MFP), but keep timer B.
	bsr	shell_stop_mfp_anim

	; The original VBL handler of the TOS is saved in $90 to
	; be called by the VBL routine of the loading animation
	; during file loading.
	; Here, we disable the VBL handler of the TOS by
	; installing the dummy handler.
	move.l	a0,$90.w

	; Install the VBL handler of the shell and make it call
	; the VBL routine of the loading animation.
	; The call graph is the following:
	; - The VBL handler of the shell calls the VBL routine
	;   of the loading animation that was registered in $98.
	; - The VBL routine of the loading animation calls the
	;   dummy handler registered in $90 (formerly the TOS
	;   handler).
	movea.l	$98.w,a0

.vbl	bsr	shell_setup_vbl

	; Set up the End-Of-Interrupt mode (software/auto).
	ifne	SHELL_MFP_AUTO_EOI
	bclr.b	#3,$fffffa17.w  ; Auto EOI
	nop
	bclr.b	#0,$fffffa0f.w  ; Clear timer B In-Service
	elseif
	bset	#3,$fffffa17.w  ; Software EOI
	endc

	movea.l	(a7)+,a0
	rts

	;
	; shell_handler_void()
	;
	; Dummy handler used to disable interrupts.
	;
shell_handler_void:
	rte

	;
	; shell_vsync()
	;
	; Wait for the next vsync signal (VBL interrupt).
	;
shell_vsync:
	move.l	d0,-(a7)

	move.w	#$2700,sr
	move.w	$468.w,d0
.wait	stop	#$2300
	cmp.w	$468.w,d0
	beq.s	.wait

	move.l	(a7)+,d0
	rts

	;
	; shell_save_screen()
	;
	; Save the video/screen configuration.
	;
shell_save_screen:
	movem.l	d0-d7/a0-a2,-(a7)

	; Save the physical start address of the video memory.
	move.w	#2,-(a7)        ; Physbase
	trap	#14             ; XBios
	addq.l	#2,a7
	move.l	d0,shell_physbase_saved

	; Save the Shifter resolution & sync mode.
	; This is done only if the intro runs as a standalone.
	tst.b	shell_loader
	bne.s	.pal
	move.b	$ffff8260.w,shell_rez_saved
	move.b	$ffff820a.w,shell_sync_saved

	; Save the video palette.
.pal	movem.l	$ffff8240.w,d0-d7
	movem.l	d0-d7,shell_pal_saved

	movem.l	(a7)+,d0-d7/a0-a2
	rts

	;
	; shell_clear_screen()
	;
	; Clear the screen.
	;
shell_clear_screen:
	movem.l	d0/a0,-(a7)

	movea.l	shell_physbase_saved,a0
	move.l	#($7d00/8)-1,d0
.cls	clr.l	(a0)+
	clr.l	(a0)+
	dbf	d0,.cls

	movem.l	(a7)+,d0/a0
	rts

	;
	; shell_restore_screen()
	;
	; Restore the video/screen configuration.
	;
shell_restore_screen:
	movem.l	d0-d7/a0,-(a7)

	; Clear the screen.
	bsr.s	shell_clear_screen

	; Restore the physical start address of the video memory.
	lea	shell_physbase_saved+1,a0
	move.b	(a0)+,$ffff8201.w
	move.b	(a0)+,$ffff8203.w
	move.b	(a0)+,$ffff820d.w

	bsr	shell_vsync

	; Restore the Shifter resolution & sync mode.
	; This is done only if the intro runs as a standalone.
	tst.b	shell_loader
	bne.s	.pal
	move.b	shell_rez_saved,$ffff8260.w
	bsr	shell_vsync
	move.b	shell_sync_saved,$ffff820a.w

	; Restore the video palette.
.pal	movem.l	shell_pal_saved,d0-d7
	movem.l	d0-d7,$ffff8240.w

	bsr	shell_vsync

	movem.l	(a7)+,d0-d7/a0
	rts

	;
	; shell_setup_screen()
	;
	; Set up the video/screen.
	;
shell_setup_screen:
	; Clear the screen.
	bsr.s	shell_clear_screen

	; Set the Shifter resolution to 320x200x4 bitplanes
	; and a 50Hz refresh rate.
	; This is done only if the intro runs as a standalone.
	tst.b	shell_loader
	bne.s	.vsync
	bsr	shell_vsync
	clr.b	$ffff8260.w
	bsr	shell_vsync
	move.b	#2,$ffff820a.w

.vsync	bsr	shell_vsync

	rts

	;
	; shell_cls_pal()
	;
	; Set all colors to the value of the background color
	; as defined by the parent program.
	; This is used to quickly clear the screen.
	;
shell_cls_pal:
	movem.l	d0-d1/a0,-(a7)

	moveq.l	#15,d0
	lea	$ffff8240.w,a0
	move.w	shell_pal_saved,d1
.col	move.w	d1,(a0)+
	dbf	d0,.col

	movem.l	(a7)+,d0-d1/a0
	rts

	;
	; shell_sound_off().
	;
	; Turn the sound off.
	;
shell_sound_off:
	move.l	a0,-(a7)

	; Tell the PSG to shut up.
	lea	$ffff8800.w,a0
	move.b	#$08,(a0)
	clr.b	2(a0)
	move.b	#$09,(a0)
	clr.b	2(a0)
	move.b	#$0a,(a0)
	clr.b	2(a0)

	movea.l	(a7)+,a0
	rts

	;
	; shell_bss_csum()
	;
	; Compute a checksum on the shell data (BSS).
	;
	; Out:
	;   d0: resulting 16-bit checksum value
	;
shell_bss_csum:
	movem.l	d1/a0,-(a7)

	lea	shell_bss_csum_start,a0
	move.w	#(shell_bss_csum_end-shell_bss_csum_start)/2-1,d1
	moveq.l	#0,d0
.csum	add.w	(a0)+,d0
	dbf	d1,.csum

	movem.l	(a7)+,d1/a0
	rts

	;
	; shell_init()
	;
	; Save and initialize the system (HW & SW).
	;
shell_init:
	movem.l	d0-d2/a0-a2,-(a7)

	; Hide the mouse.
	bsr	shell_hidemouse

	; Save and set up Conterm (disable key click & repeat).
	move.b	$484.w,shell_conterm_saved
	clr.b	$484.w

	; Save the screen configuration.
	bsr	shell_save_screen

	ifeq	SHELL_ENABLE_DEBUG

	cmpi.b	#'H',shell_loader
	beq.s	.kboff
	; Clear the screen (using the palette).
	bsr	shell_vsync
	bsr	shell_cls_pal

	; Shut down the IKBD smoothly.
.kboff	bsr	shell_ikbd_off

	; Reset the internal TOS state of the key repeat and
	; special keys.
	bsr	shell_reset_bioskeys

	endc	; SHELL_ENABLE_DEBUG

	; Sync next inits with VBLANK to be less intrusive
	; when masking interrupts.
	bsr	shell_vsync

	; Save the MFP configuration.
	move.w	#$2700,sr
	bsr	shell_save_mfp
	move.w	#$2300,sr

	; Save CPU exception & interrupt vectors.
	bsr	shell_save_vectors

	ifeq	SHELL_ENABLE_DEBUG

	; Disable all interrupts and install the VBL handler
	; of the shell. Let the loading animation run
	; if applicable.
	move.b	shell_loader,d0
	move.w	#$2700,sr
	bsr	shell_ints_safe
	move.w	#$2300,sr

	; Catch CPU exceptions.
	bsr	shell_catch_exceptions

	; Set up the 50Hz timer.
	lea	shell_user_func_void(pc),a0
	move.w	#$2700,sr
	bsr	shell_setup_timer50hz
	move.w	#$2300,sr

	; Resume IKBD.
	bsr	shell_ikbd_on

	endc	; SHELL_ENABLE_DEBUG

	; Set up the screen configuration.
	cmpi.b	#'H',shell_loader
	beq.s	.csum
	bsr	shell_setup_screen

	; Compute and save the checksum on the shell data.
.csum	bsr	shell_bss_csum
	neg.w	d0
	move.w	d0,shell_bss_csum_start

	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; shell_exit()
	;
	; Restore the system.
	;
shell_exit:
	movem.l	d0-d2/a0-a2,-(a7)

	; Mask interrupts on the CPU.
	move.w	#$2700,sr

	; Turn off the sound.
	bsr	shell_sound_off

	ifeq	SHELL_ENABLE_DEBUG

	; Clear the screen (using the palette).
	bsr	shell_cls_pal

	; Disable all interrupts and keep a basic VBL handler
	; that only updates _frclock ($466).
	moveq.l	#0,d0
	bsr	shell_ints_safe

	endc	; SHELL_ENABLE_DEBUG

	; Re-enable interrupts on the CPU.
	move.w	#$2300,sr

	; Check the integrity of the shell data (in case it was
	; corrupted by the intro).
	bsr	shell_bss_csum
	tst.w	d0
	bne.s	.fatal

	ifeq	SHELL_ENABLE_DEBUG

	; Pause IKBD transfers.
	moveq.l	#$13,d0
	bsr	shell_send_ikbd

	; Flush the ACIA buffer until the IKBD is idle.
	bsr	shell_flush_acia
.wait_ikbd
	bsr	shell_vsync
	bsr	shell_flush_acia
	tst.b	d0
	bne.s	.wait_ikbd

	endc	; SHELL_ENABLE_DEBUG

	; Restore the screen configuration.
	bsr	shell_restore_screen

	; Mask interrupts on the CPU.
	move.w	#$2700,sr

	; Restore CPU exception & interrupt vectors.
	bsr	shell_restore_vectors

	; Restore the MFP configuration.
	bsr	shell_restore_mfp

	ifeq	SHELL_ENABLE_DEBUG
	; Resume IKBD.
	bsr	shell_ikbd_on
	endc	; SHELL_ENABLE_DEBUG

	; Re-enable interrupts on the CPU.
	move.w	#$2300,sr

	ifeq	SHELL_ENABLE_DEBUG
	; Re-enable the mouse.
	moveq.l	#$8,d0
	bsr	shell_send_ikbd
	endc	; SHELL_ENABLE_DEBUG

	; Restore Conterm.
	move.b	shell_conterm_saved,$484.w

	; Show the mouse again.
	bsr	shell_showmouse

	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; fatal()
	;
	; Halt the CPU if the shell data was corrupted.
	;
.fatal:
	move.w	#$700,$ffff8240.w
.dead	bra.s	.dead

	;
	; shell_movep_supported()
	;
	; Detect if the CPU supports the movep instruction.
	;
	; Out:
	;   d0: 1 if movep is supported, 0 otherwise
	;
shell_movep_supported:
	movem.l	a0-a1,-(a7)

	; Mask interrupts.
	move.w	sr,-(a7)
	ori.w	#$700,sr

	; On 68060, movep generates an Unimplemented Integer
	; Instruction exception ($f4).
	move.l	$f4.w,-(a7)
	lea	shell_movep_except(pc),a1
	move.l	a1,$f4.w

	movea.l	a7,a0
	lea	.cont(pc),a1
	move.l	#$00000100,-(a7)

	moveq.l	#0,d0
	; d0 = 1 if CPU <= 68040 (movep has been executed),
	; d0 = 0 otherwise (movep caused an exception).
	movep.w	0(a7),d0
.cont	movea.l	a0,a7

	move.l	(a7)+,$f4.w
	move.w	(a7)+,sr

	movem.l	(a7)+,a0-a1
	rts

	;
	; shell_movep_except()
	;
	; Catch exceptions triggered by unsupported instructions.
	; Restore SP and resume execution at the address specified
	; in a1.
	;
	; In:
	;   a0: saved SP
	;   a1: return address
	;
shell_movep_except:
	movea.l	a0,a7
	jmp	(a1)

	;
	; shell_user_func_void()
	;
	; Default user-defined routine called by the VBL
	; and 50Hz timer handlers.
	;
shell_user_func_void:
	rts

	;
	; shell_vbl()
	;
	; VBL handler of the shell.
	;
	; - Increment _frclock.
	; - Call the user-defined VBL routine.
	; - Handle 50Hz timer deferred execution.
	;
shell_vbl:
	addq.l	#1,$466.w       ; _frclock
	movem.l	d0-a6,-(a7)
shell_vbl_user:
	jsr	$0.l            ; User-defined routine

	move.w	sr,d0
	clr.b	d0
	cmpi.w	#$2400,d0       ; Sanity check
	bne.s	shell_timer50hz_intr_err

	movem.l	(a7)+,d0-a6
shell_vbl_rte:
	; This 'rte' is replaced by a 'nop' in case of deferred
	; execution of the 50Hz timer handler.
	rte
	; Fall-through

	; If the VBL handler has been preempted by the 50Hz timer,
	; the execution of the 50Hz timer handler is deferred at
	; the end of the VBL.
	move.l	a0,-(a7)
	lea	shell_vbl_rte(pc),a0
	move.w	#$4e73,(a0)     ; Restore the 'rte' instr
	movea.l	(a7)+,a0
	bra.s	shell_timer50hz_deferred	

	;
	; shell_timer50hz()
	;
	; 50Hz timer handler (timer C).
	;
	; - Increment the internal 50Hz counter.
	; - Call the user-defined 50Hz timer routine.
	;
	; Ensure that the execution of the VBL handler is never
	; delayed. To this end, if the VBL handler is preempted
	; by the 50Hz timer, the execution of the 50Hz timer
	; handler is deferred at the end of the VBL.
	;
shell_timer50hz:
	; First, mask the timer C interrupt at MFP level to
	; prevent reentrancy once the IPL is lowered.
	; Indeed, we want to avoid the situation where the timer C
	; has to handle self-preemption.
	bclr.b	#5,$fffffa15.w
	; Trigger End-Of-Interrupt if necessary.
	ifeq	SHELL_MFP_AUTO_EOI
	bclr.b	#5,$fffffa11.w
	endc
	; Lower the IPL to 5 to enable preemption by other timers
	; (e.g. timer D/music sync-buzzer, timer B/HBL).
.ipl	move.w	#$2500,sr

	; Use the IPL saved at exception time to determine which
	; interrupt handler was preempted (if any).
	; If an interrupt handler was preempted, immediately resume
	; its execution.
	; The control will then be returned here after the preempted
	; handler has run completely.
	; The same operation is performed in loop until there is
	; no more preempted handler.
	; 
shell_timer50hz_deferred:
	; IPL 4 means the VBL handler has been preempted.
	cmpi.b	#$24,(a7)
	beq.s	shell_timer50hz_intr_vbl
	; IPL 5 means an MFP interrupt handler has been
	; preempted, which is not supposed to happen.
	cmpi.b	#$23,(a7)
	bne.s	shell_timer50hz_intr_err

	; It is now guaranteed that the preempted code runs
	; at base level (IPL 3).
	; Lower the IPL to 3 to enable preemption by the VBL.
	move.w	#$2300,sr

	; Increment the internal 50Hz counter.
	addq.l	#1,shell_count50Hz

	movem.l	d0-a6,-(a7)

	; Execute the user-defined routine.
shell_timer50hz_user:
	jsr	$0.l

	move.w	sr,d0
	clr.b	d0
	cmpi.w	#$2300,d0       ; Sanity check
	bne.s	shell_timer50hz_intr_err

	movem.l	(a7)+,d0-a6

	; Reenable the timer C at MFP level and return from
	; exception.
	; The IPL is raised to 6 to avoid reentrancy once the
	; timer C interrupt is reenabled.
	move.w	#$2600,sr
	bset	#5,$fffffa15.w
	rte

	;
	; shell_timer50hz_intr_vbl() is called by the timer C
	; handler above when it detects that the VBL handler
	; has been preempted and should be resumed.
	;
	; In that case, the execution of the 50Hz timer handler
	; is deferred at the end of the VBL.
	;
	; The "rte" instruction of the VBL handler is replaced
	; with a "nop", so that control can be resumed to
	; shell_timer50hz_deferred() after the VBL handler
	; has run.
	;
shell_timer50hz_intr_vbl:
	move.l	a0,-(a7)
	lea	shell_vbl_rte(pc),a0
	move.w	#$4e71,(a0)     ; 'nop'
	movea.l	(a7)+,a0
	rte

	;
	; shell_timer50hz_intr_err() is called in case of
	; unexpected errors, like invalid preemption cases.
	;
shell_timer50hz_intr_err:
	illegal

	;
	; shell_setup_vbl()
	;
	; Set up the VBL handler of the shell and install
	; the user-defined VBL routine.
	;
	; In:
	;   a0: user-defined routine
	;
shell_setup_vbl:
	ifeq	SHELL_ENABLE_DEBUG
	move.l	a1,-(a7)

	; Save the user-defined routine.
	lea	shell_vbl_user(pc),a1
	move.l	a0,2(a1)

	; Set up the VBL vector.
	lea	shell_vbl(pc),a1
	move.l	a1,$70.w

	movea.l	(a7)+,a1
	endc	; SHELL_ENABLE_DEBUG
	rts

	;
	; shell_setup_timer50hz()
	;
	; Set up the 50Hz timer and install the user-defined
	; timer routine.
	;
	; In:
	;   a0: user-defined routine
	;
shell_setup_timer50hz:
	ifeq	SHELL_ENABLE_DEBUG
	movem.l	d0/a1,-(a7)

	; Save the user-defined routine.
	lea	shell_timer50hz_user(pc),a1
	move.l	2(a1),d0
	move.l	a0,2(a1)

	; Set up the MFP and timer C vector only once.
	tst.l	d0
	bne.s	.ret

	cmpi.b	#'H',shell_loader
	bne.s	.mfp

	; Case where the loading animation is playing:
	; Convert the _hz_200 counter that was saved at the start
	; of the animation to a 50Hz counter and save it as the
	; initial value of our internal 50Hz counter.
	move.l	$4ba.w,d0
	sub.l	$9c.w,d0
	asr.l	#2,d0
	move.l	d0,shell_count50Hz

.mfp
	; Set up the timer C to run at 50Hz.
	lea	shell_timer50hz(pc),a1
	andi.b	#%111,$fffffa1d.w   ; Stop timer C
	move.l	a1,$114.w           ; Install handler
	bset	#5,$fffffa15.w      ; Unmask timer C chan
	bset	#5,$fffffa09.w      ; Enable timer C chan
	move.b	#245,$fffffa23.w    ; Timer C counter
	ori.b	#(7<<4),$fffffa1d.w ; Start 50Hz timer C

.ret	movem.l	(a7)+,d0/a1
	endc	; SHELL_ENABLE_DEBUG
	rts

	;
	; shell_wait_anim()
	;
	; Wait for the loading animation to play for a minimum
	; duration.
	;
	; The loading time may vary depending on the storage
	; medium (floppy disk, hard disk) or the speed of the
	; machine, but we make sure that the animation always
	; has the same duration.
	;
	; Therefore, this routine makes sure that the animation
	; lasts at least SHELL_ANIM_DURATION seconds.
	;
shell_wait_anim:
	ifeq	SHELL_ENABLE_DEBUG
	ifne	SHELL_ANIM_DURATION

	; This is only applicable if the animation is currently
	; playing.
	cmpi.b	#'H',shell_loader
	bne.s	.ret

	; Wait until the desired time has elapsed.
.wait	stop	#$2300
	cmpi.l	#50*SHELL_ANIM_DURATION,shell_count50Hz
	blo.s	.wait

	; Wait until the color fade of the ghosts halo is finished.
	tst.w	$a4.w
	beq.s	.ret
	move.w	#$1,$a4.w
.fade	stop	#$2300
	tst.w	$a4.w
	bne.s	.fade

	endc	; SHELL_ANIM_DURATION
	endc	; SHELL_ENABLE_DEBUG
.ret	rts

	;
	; shell_stop_anim()
	;
	; Stop the loading animation.
	;
shell_stop_anim:
	move.l	a0,-(a7)

	; Do nothing if the intro runs as a standalone.
	cmpi.b	#'H',shell_loader
	bne.s	.ret

	ifeq	SHELL_ENABLE_DEBUG

	move.w	sr,-(a7)
	move.w	#$2700,sr

	; Stop timer B.
	clr.b	$fffffa1b.w     ; Timer B ctrl
	bclr.b	#0,$fffffa07.w  ; Enable A
	bclr.b	#0,$fffffa13.w  ; Mask A
	bclr.b	#0,$fffffa0b.w  ; Pending A
	bclr.b	#0,$fffffa0f.w  ; In-service A

	lea	shell_handler_void(pc),a0
	move.l	a0,$120.w       ; Timer B (HBL)

	; Unregister the VBL routine of the loader.
	lea	shell_user_func_void(pc),a0
	bsr	shell_setup_vbl

	move.w	(a7)+,sr

	; Flush the ACIA buffer until the IKBD is idle.
	bsr	shell_flush_acia
.wait_ikbd
	bsr	shell_vsync
	bsr	shell_flush_acia
	tst.b	d0
	bne.s	.wait_ikbd

	endc	; SHELL_ENABLE_DEBUG

	; The palette is no longer updated by the HBL.
	lea	$ffff8240.w,a0
	move.l	a0,$a0.w

.ret	movea.l	(a7)+,a0
	rts

	;
	; shell_get_current_palette()
	;
	; Get the address of the current palette.
	;
	; If the loading animation is playing, this function
	; returns the address of the "ghosts" palette that is
	; currently used by the timer B (HBL).
	; Otherwise, the base address of the video palette
	; registers is returned.
	;
shell_get_current_palette
	lea	$ffff8240.w,a0
	cmpi.b	#'H',shell_loader
	bne.s	.ret
	; The address of the "ghosts" palette is saved in $a0
	; by the loader.
	movea.l	$a0.w,a0
.ret	rts

	;
	; Shell uninitialized data.
	;
	ifnd	SHELL_BSS_IN_TEXT
	ifd	SHELL_BSS_IN_DATA
	section	data
	elseif
	section	bss
	endc
	endc

	; Checksum on the shell data.
shell_bss_csum_start:
	ds.w	1

	; Program basepage.
shell_basepage:
	ds.l	1

	; 0 if the intro runs as a standalone,
	; 'M' if the intro is the main screen run by the loader,
	; 'H' if the intro is the hidden screen run by the loader.
shell_loader:
	ds.b	1
	even

	; Original Supervisor Stack Pointer.
shell_ssp_saved:
	ds.l	1

	; Original Conterm ($484 system variable).
shell_conterm_saved:
	ds.b	1
	even

	; Original MFP configuration.
shell_mfp_saved:
	ds.b	5
	even

	; Original CPU exception & interrupt vectors.
shell_vectors_saved:
	ds.l	27

	; Original screen physical base address.
shell_physbase_saved:
	ds.l	1

	; Original Shifter resolution & sync mode.
shell_rez_saved:
	ds.b	1
shell_sync_saved:
	ds.b	1
	even

	; Original video palette.
shell_pal_saved:
	ds.w	16

	; Indicate that an IKBD interrupt has occurred.
	; (used by the shell_wait_ikbd() routine).
shell_ikbd_flag:
	ds.w	1

shell_bss_csum_end:

	; 50Hz counter.
shell_count50Hz:
	ds.l	1

	; Program stack.
shell_stack_bottom:
	ds.b	STACK_SIZE
shell_stack_top:
	even

	section	text
