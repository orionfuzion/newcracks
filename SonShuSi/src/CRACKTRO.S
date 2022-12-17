
	***********************************************************
	*
	*   Son Shu Shi 100% + Replicants revival
	*
	*   Cracktro Skeleton
	*
	*   This source code is an example of how to use the cracktro
	*   shell (SHELL.S) that provides a framework for cracktros.
	*
	*   The source code of the real cracktros that come with the
	*   crack of Son Shu Shi is not provided.
	*
	*   By Orion of The Replicants
	*   v1.3 - 5 October 2022.
	*
	*   You should read SHELL.S for the fully commented
	*   implementation of the cracktro shell.
	*
	*   You should also read the comments at the beginning of
	*   LOADER1.S for a description of the organization and
	*   contents of the various source files of this crack.
	*
	***********************************************************

	;----------------------------------------------------------
	; - The stack is setup by the shell.
	;   You can configure its size here.
	; - If debugging under MonST is needed, just set
	;   SHELL_ENABLE_DEBUG to 1.
	; - The MFP *must* now work in automatic EOI mode because
	;   the music expects the timer D to work in auto EOI.
	; - SHELL_ANIM_DURATION allows you to configure the minimum
	;   duration of the loading animation, regardless of the
	;   storage medium or the speed of the machine.
	; - SHELL uninitialized data are placed in the BSS by default.
	;   Define SHELL_BSS_IN_DATA to place them in the DATA,
	;   or SHELL_BSS_IN_TEXT to place them in the TEXT section.
	;----------------------------------------------------------

STACK_SIZE           =  1024            ; 1 KB
SHELL_ENABLE_DEBUG   =     0            ; 0 or 1
SHELL_MFP_AUTO_EOI   =     1            ; 1 is mandatory
SHELL_ANIM_DURATION  =    10            ; seconds

ZIK_AVAILABLE        =     0

	;----------------------------------------------------------
	; GenST options must be placed here, before including
	; the shell.
	; Make sure that U- is set (required by the shell).
	;----------------------------------------------------------

	opt	o-              ; Turn all optimizations off
	opt	c+              ; Case sensitive labels
	opt	U-              ; Use periods (.) for local labels

	;----------------------------------------------------------
	; Include the shell here, before your code.
	;----------------------------------------------------------

	include	"SHELL.S"

	;----------------------------------------------------------
	; Entry point of your intro.
	; Place your code here, after the inclusion of the shell.
	; The intro_start() routine is called by the shell and must
	; return (rts) to the shell.
	; The 16-bit error code that is returned in d0 to the shell
	; will be returned to the parent program (the loader).
	; This feature is used by the main intro to indicate to
	; the loader whether the hidden intro must be executed.
	;----------------------------------------------------------

intro_start:
	;----------------------------------------------------------
	; When intro_start() is called, the system is in the
	; following state:
	;
	; - The CPU runs in Supervisor mode.
	; - A safe stack is setup.
	; - All MFP interrupts are disabled on the MFP, except:
	;   . The timer B channel, used by the loading animation.
	;   . The timer C channel, used to play the music at 50Hz.
	; - Timers A and D are stopped.
	; - Timer B is configured in event count mode (HBL) if
	;   the loading animation is playing. Otherwise it is
	;   stopped.
	; - Timer C is configured to run at 50Hz.
	; - The MFP Vector register ($fffa17) is configured in
	;   Automatic End-Of-Interrupt mode (auto EOI).
	; - A dummy handler (which simply executes 'RTE') is
	;   installed for all vectors, except:
	;   . The VBL (see below).
	;   . The timer B (HBL), used by the loading animation.
	;   . The timer C, used to play the music at 50Hz.
	; - A special VBL handler is installed. It updates _frclock
	;   ($466) and handles deferred execution of the 50Hz timer
	;   handler. It provides a vsync service through the
	;   shell_vsync() routine.
	; - The interrupts are enabled on the CPU (sr=$23xx).
	; - All CPU exceptions are caught in order to restore a
	;   safe execution environment in case of a CPU crash.
	; - The screen is setup in low-rez.
	; - The screen physical base address is the one setup by
	;   the TOS.
	; - The mouse and joystick are disabled on the IKBD,
	;   only the keyboard is enabled.
	; - The mouse pointer is hidden, Conterm is cleared.
	; - The memory from the end of the BSS section to the
	;   end of the physical RAM ($42e) is allocated to the
	;   intro (and thus available for precalc & screens).
	;
	; You can install your own handlers, setup the MFPs as
	; you need, but you must:
	; - Use the VBL handler of the shell and register your
	;   own VBL routine using shell_setup_vbl().
	; - Use the 50Hz timer to play the music. Just register
	;   your own routine using shell_setup_timer50hz().
	; - Use the auto EOI mode of the MFP (as set up by the
	;   shell).
	;
	; In order to be compatible with the Falcon or TT, the
	; following limitations apply:
	; - Do not touch $ff8260!
	; - Do not touch $ff820a!
	; - Do not use sync techniques ($ff8209) as the intro will
	;   work an different CPUs and different Video controllers!
	; - Do not implement overscan techniques (for the same
	;   reason)!
	; - Do not invoke the TOS (no Trap)!
	; - Do not "hack" exception stack frames! For instance,
	;   the following hack is forbidden:
	;       move.l    <addr>,-(a7)
	;       move.w    <sr>,-(a7)
	;       rte
	; - Do not use the movep instruction on a 68060 CPU (this
	;   instruction is not supported)!
	; - Do not use PSG shadow registers (which is not a problem
	;   as you don't write your own music or sample replay
	;   routine)!
	;
	; The shell provides the following services that should be
	; used by the intro:
	;
	; - shell_setup_vbl:
	;   Allows you to register your own VBL routine.
	;
	; - shell_setup_timer50hz:
	;   Allows you to register your own 50Hz timer routine
	;   for the music.
	;
	; - shell_vsync:
	;   Waits for the next VBLANK signal (works with the VBL
	;   handler of the shell).
	;
	; - shell_wait_anim:
	;   Makes sure the loading animation plays for a minimum
	;   duration.
	;
	; - shell_get_current_palette:
	;   Gets the address of the current palette.
	;   If the loading animation is playing, it is the address
	;   of the "ghosts" palette that is currently used by the
	;   timer B (HBL). Otherwise, it is the base address of the
	;   video palette registers.
	;
	; - shell_stop_anim()
	;   Stops the loading animation.
	;
	; - shell_movep_supported:
	;   Returns 1 if movep is supported.
	;
	; - shell_read_acia:
	;   Returns the scancode of the key pressed.
	;
	; /!\ Note about the 50Hz timer used for the music:
	;     If the VBL handler is preempted by the 50Hz timer,
	;     the execution of the 50Hz timer handler is deferred
	;     at the end of the VBL.
	;     Preemption detection is achieved by checking the
	;     preempted IPL.
	;     => Do not change the IPL in your code!
	;     You can temporarily switch to IPL 7 to mask interrupts
	;     and then restore the previous IPL.
	;     But you cannot set an IPL that is not consistent with
	;     the current execution context, or it might break the
	;     VBL preemption detection!
	;
	;----------------------------------------------------------

	;
	; This skeleton shows a possible transition from the
	; loading animation to the intro.
	;
	; When this code starts, the loading animation is playing
	; in the background and the HW has been set up for the
	; intro.
	;
	; The transition is the following:
	; - Initialize the music.
	; - Make sure the loading animation plays for a minimum
	;   duration.
	; - Start the music.
	; - Fade from the ghosts palette to a black palette.
	; - Stop the loading animation.
	; - Start the VBL of the intro.
	; - Execute the main loop of the intro.
	;

	; Initialize the muzik.
	ifne	ZIK_AVAILABLE
	moveq.l	#1,d0           ; Choice of the music (1 is default)
	jsr	music+0         ; Init SNDH music
	endc

	;
	; You can add your own inits/precalc here.
	;

	; Make sure the loading animation plays for a minimum
	; duration if the intro has been loaded faster than
	; expected (if the intro runs as a standalone, it does
	; nothing).
	bsr	shell_wait_anim

	; Play the music using a 50Hz timer.
	lea	timer50hz(pc),a0
	bsr	shell_setup_timer50hz

	; Get the address of the current palette.
	; If the loading animation is playing, it is the address
	; of the "ghosts" palette that is currently used by the
	; timer B (HBL). Otherwise, it is the base address of the
	; video palette registers.
	bsr	shell_get_current_palette

	; Fade from the ghosts palette to a black palette
	; while the animation is still playing in the background.
	; - or -
	; Fade from the current HW palette to a black palette
	; if the intro is running as a standalone.
	lea	pal_black,a1
	bsr	pal_fade

	; Stop the loading animation (if any).
	bsr	shell_stop_anim

	; Print a pattern on the screen, just to verify that
	; the screen has been correctly set up.
	bsr	print_pattern

	; Install the VBL of the intro (but keep the handler of 
	; the shell).
	lea	vbl(pc),a0
	bsr	shell_setup_vbl

	;
	; Main loop.
	;
	; /!\ The IPL must not be changed (it should remain 3,
	;     i.e. SR=$23xx).
	;
.wkey	bsr	shell_vsync

	bsr	shell_read_acia

	cmpi.b	#$13,d0         ; 'R' (magic) key pressed?
	beq.s	.hidden
.space	cmpi.b	#$39,d0         ; Space key pressed?
	bne.s	.wkey
	move.w	#'!H',d1
	bra.s	.ret
.hidden	move.w	#'H!',d1
.ret
	; Sync the system cleanup with the VBL for a clean stop
	; of the current animation.
	bsr	shell_vsync

	;----------------------------------------------------------
	; When your intro returns, it can leave the system in any
	; state. The shell will stop everything and restore the
	; system.
	;
	; Value returned in d0 to the shell:
	; For the Main cracktro:
	;   - '!H' ......... Indicate not to load the hidden intro
	;   - 'H!' ......... Indicate to load the hidden intro
	;   - Other ........ Error
	; For the Hidden cracktro:
	;   - 0 ............ Default value
	;----------------------------------------------------------

	move.w	d1,d0           ; 16-bit return value
	rts	                ; Return to the shell

	;----------------------------------------------------------
	; VBL routine.
	;
	; - It is called by the VBL handler of the shell.
	; - All registers and saved and restored by the caller.
	; - The VBL routine should be as short/quick as possible
	;   so as not to delay too much the execution of the
	;   50Hz timer handler.
	; - /!\ The IPL must not be changed (it should remain 4,
	;       i.e. SR=$24xx).
	;----------------------------------------------------------
vbl:
	bsr	shell_movep_supported
	move.w	#$070,d1        ; Green in movep is supported
	tst.b	d0
	bne.s	.col
	move.w	#$007,d1        ; Blue otherwise

.col	move.w	d1,$ffff8240.w

	; Fake activity.
	move.w	#$800,d0
.busy	dbf	d0,.busy	

	clr.w	$ffff8240.w
	rts

	;----------------------------------------------------------
	; 50Hz timer routine.
	;
	; - It is called by the 50Hz timer handler of the shell.
	; - All registers and saved and restored by the caller.
	; - /!\ The IPL must not be changed (it should remain 3,
	;       i.e. SR=$23xx).
	;----------------------------------------------------------
timer50hz:
	ifne	ZIK_AVAILABLE
	; Just play the music.
	jsr	music+8
	endc
	rts

	;
	; print_pattern()
	;
	; Print a patten on the screen and set up the
	; color palette.
	;
print_pattern:
	movem.l	d0/a0-a1,-(a7)

	movea.l	shell_physbase_saved,a0
	move.w	#(320*200)/16-1,d0
.pix	move.w	#%0101010101010101,(a0)+
	move.w	#%0011001100110011,(a0)+
	move.w	#%0000111100001111,(a0)+
	move.w	#%0000000011111111,(a0)+
	dbf	d0,.pix

	lea	$ffff8240.w,a0
	lea	pal_pattern,a1
	bsr	pal_fade

	movem.l	(a7)+,d0/a0-a1
	rts

	;
	; pal_fade()
	;
	; Fade colors from an initial palette to a target palette.
	; Each color in the initial palette is gradually transformed
	; to match the corresponding color in the target palette.
	; At each vsync (a color fade iteration), only 1 component
	; at a time (R, G or B) is modified in all colors.
	;
	; In:
	;   a0: initial/current color palette [modified]
	;   a1: target color palette
	;
pal_fade:
	movem.l	d0-d7/a0-a1,-(a7)

	; R/G/B masks are rotated in d1 to indicate the color
	; component (R,G,B) to be modified during the current
	; fade iteration.
	move.w	#$0f00,d1
	move.w	#$00f0,d2
	move.w	#$000f,d3

.fade	bsr	shell_vsync
	moveq.l	#15,d0          ; 16 colors
	move.w	#$111,d4
	and.w	d1,d4           ; Color component increment
	moveq.l	#0,d7           ; >0 if fade is not finished

	; A single fade iteration.

.level1	move.w	(a0)+,d5        ; Current color
	move.w	(a1)+,d6        ; Target color

	andi.w	#$777,d5        ; STf/STe compat
	andi.w	#$777,d6
	cmp.w	d5,d6           ; Same colors?
	dbne	d0,.level1      ; Yes => next color
	beq.s	.again          ; No more color?

	addq.w	#1,d7           ; Fade is not finished

	; Change a single component (R, G or B) in the
	; current color to get closer to the target color.

	and.w	d1,d5           ; Keep a single color component
	and.w	d1,d6
	cmp.w	d5,d6           ; Color components are equal?
	beq.s	.next           ; Yes => next color
	bhs.s	.add            ; No, target component is brighter?

.sub	sub.w	d4,-2(a0)       ; Target component is darker
	bra.s	.next

.add	add.w	d4,-2(a0)       ; Target component is brighter

.next	dbf	d0,.level1      ; Next color

.again	lea	-16*2(a0),a0
	lea	-16*2(a1),a1

	exg	d1,d2           ; Rotate the R/G/B masks
	exg	d2,d3

	tst.w	d7              ; Fade finished?
	bne.s	.fade

	movem.l	(a7)+,d0-d7/a0-a1
	rts

	ifne	ZIK_AVAILABLE
	;
	; Music "Lost" by Dma-Sc.
	;
music:	incbin	LOST0109.SND
	endc

	; Initialized data.
	section	data

	; Pattern palette.
pal_pattern:
	dc.w	$0000,$0011,$0012,$0022,$0122,$0123,$0133,$0134
	dc.w	$0144,$0145,$0155,$0156,$0166,$0167,$0177,$0277

	;----------------------------------------------------------
	; IMPORTANT: 
	; If you generate code or data in the memory after the
	; intro (outside the program sections), you must declare
	; a BSS section and generate your data starting from the
	; end of this section.
	; This is because the shell stores its data in the BSS
	; section. So if you generate your data from the end of
	; the text or data section, you will corrupt the BSS and
	; therefore the shell data.
	; After the intro returns to the shell, the shell checks
	; the integrity of its data and displays a red screen in
	; case of memory corruption.
	;----------------------------------------------------------

	; Uninitialized data.
	section	bss

	; Black palette.
pal_black:
	ds.w	16

	; Code/data can be generated starting from the last label
	; of the BSS section.
free_area:
	end
