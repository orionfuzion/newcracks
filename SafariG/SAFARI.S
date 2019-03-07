***************************************************************************
*
* Safari Guns 100% - with game intro & multi-languages support
*
* Cracked, mega-trained, partly-filed, packed, linked, ramdisk, bug-fixed.
* 512KB, hard-drive and Falcon/CT60/TT support.
*
* December 25, 2018 - Orion of The Replicants.
* 
* This code is the main driver in charge of executing the Xmas cracktro
* and the loader of the game (actually providing the trainer mode and
* on-the-fly depacking of game files).
*
* Please see LOADER.S for full explanations and comments about this crack.
*
* This 'SAFARI.S' ASM source file should be built (assembled) using Devpac
* as an executable program named 'SAFARI.PRG' and placed into the AUTO
* folder.
*
***************************************************************************

CONFIG_INTINTRO	=	1
CONFIG_PROG1	=	2
CONFIG_PROG2	=	3
CONFIG_RAMDISK	=	4
CONFIG_WAIT	=	5
CONFIG_NODEINIT	=	6
CONFIG_ERROR	=	7

_CFG1_1	=	(1<<CONFIG_INTINTRO)
_CFG1_2	=	(1<<CONFIG_WAIT)!_CFG1_1
_CFG1_3	=	(1<<CONFIG_PROG1)!_CFG1_2
CONFIG1	=	(1<<CONFIG_NODEINIT)!_CFG1_3

_CFG2_1	=	(1<<CONFIG_WAIT)
_CFG2_2	=	(1<<CONFIG_PROG2)!_CFG2_1
_CFG2_3	=	(1<<CONFIG_RAMDISK)!_CFG2_2
CONFIG2	=	(1<<CONFIG_NODEINIT)!_CFG2_3

STACK_SIZE	=	512

	opt	o+,p+,c-

	; Main entry point
pt_base
	bra.s	start
magic           ; Magic for child process.
	dc.l	'REPS'
config_p        ; Pointer to loader config.
	dc.l	0
mach_conf_p     ; Pointer to saved machine state.
	dc.l	0
trainer_info_p  ; Pointer to trainer information.
	dc.l	0

start
	; Setup references to be used by the loader
	; (our child program).
	lea	mach_conf_p(pc),a0
	lea	mach_conf(pc),a1
	move.l	a1,(a0)
	lea	trainer_info_p(pc),a0
	lea	trainer_info(pc),a1
	move.l	a1,(a0)
	lea	config_p(pc),a0
	lea	config(pc),a1
	move.l	a1,(a0)

	; Machine backup & setup.
	lea	mach_setup(pc),a0
	bsr	supexec

	; Check if screen resolution is valid.
	movea.l	mach_conf_p(pc),a0
	tst	MACH2SCREEN+REZ_INVALID(a0)
	beq.s	setup_resid
	lea	txt_rez(pc),a0
	bsr	print
	bsr	readchar
	bra.s	quit

	; Resident program setup (mshrink).
setup_resid
	movea.l	4(a7),a0
	move.l	#$100+STACK_SIZE+resident_end-pt_base,d0
	move.l	d0,d1
	add.l	a0,d1
	movea.l	d1,a7
	bsr	mshrink

	; Run external intro.
run_extintro
	lea	extintro_pre(pc),a0
	bsr	supexec
	;movea.l	mach_conf_p(pc),a0
	;move.w	MACH2CPU+MCH_TYPE(a0),d0
	;cmp.b	#MCH_TT,d0
	;bhs.s	skip_intro
	lea	extintro_name(pc),a0
	bsr	pexec
skip_intro
	lea	extintro_post(pc),a0
	bsr.s	supexec

	; Run the loader for the game intro.
	move.l	#CONFIG1,(a1)
	lea	loader(pc),a0
	bsr	pexec
	tst.l	d0
	bmi.s	quit

	; Check if an error occurred.
	move.l	(a1),d0
	btst	#CONFIG_ERROR,d0
	bne.s	quit

	; Run the loader for the game.
	move.l	#CONFIG2,(a1)
	bsr	pexec
quit
	; Restore machine config.
	lea	mach_restore(pc),a0
	bsr.s	supexec

	; Exit.
	clr.w	-(a7)
	trap	#1

	; cols_black()
	; Set low rez colors to black.
cols_black
	movem.l	d0/a0,-(a7)
	moveq.l	#7,d0
	lea	$ffff8240.w,a0
.lp	clr.l	(a0)+
	dbf	d0,.lp
	movem.l	(a7)+,d0/a0
	rts

	; extintro_pre()
	; Routine executed right before to the external intro.
	; Set all colors to black.
	; Called from supexec.
	; Out:
	;   d0: return value
extintro_pre
	bsr.s	vsync
	bsr.s	cols_black

	moveq.l	#0,d0
	rts

	; extintro_post()
	; Routine executed right after to the external intro.
	; Restore screen phys/log base addresses and
	; set all colors to black again.
	; Called from supexec.
	; Out:
	;   d0: return value
	; Scratch: d1-d2/a0-a2
extintro_post
	bsr.s	vsync
	bsr.s	cols_black

	movea.l	mach_conf_p(pc),a0
	lea	MACH2SCREEN(a0),a0
	move.w	#-1,-(a7)
	move.l	PHYSBASE(a0),-(a7)
	move.l	LOGBASE(a0),-(a7)
	move.w	#5,-(a7)
	trap	#14
	lea	12(a7),a7

	bsr.s	vsync

	moveq.l	#0,d0
	rts

***************************************************************************
* XBIOS Routines
***************************************************************************

	; supexec()
	; Execute a routine in supervisor mode.
	; in
	;   a0: routine address
	; out
	;   d0: returned value of the routine
supexec
	movem.l	d1-d2/a0-a2,-(a7)

	pea	(a0)
	move.w	#$26,-(sp)
	trap	#14
	addq.l	#6,sp

  	movem.l	(a7)+,d1-d2/a0-a2
  	rts

	; vsync()
	; Wait for the next vertical sync signal.
vsync
	movem.l	d0-d2/a0-a2,-(a7)

	move.w	#$25,-(sp)
	trap	#14
	addq.l	#2,sp

	movem.l	(a7)+,d0-d2/a0-a2
	rts

***************************************************************************
* GEMDOS Routines
***************************************************************************

	; mshrink()
	; Reduce already reserved memory.
	; in
	;   d0: new size
	;   a0: start address
	; out
	;   d0: GEMDOS error
mshrink
	movem.l	d1-d2/a0-a2,-(a7)

	move.l	d0,-(a7)
	pea	(a0)
	move.l	#$4a0000,-(a7)
	trap	#1
	lea	$c(a7),a7

  	movem.l	(a7)+,d1-d2/a0-a2
	rts

	; print()
	; Write a string to the standard output device (Cconws).
	; in
	;   a0: string address
print
	movem.l	d0-d2/a0-a2,-(a7)

	pea	(a0)
	move.w	#9,-(sp)
	trap	#1
	addq.l	#6,sp	

  	movem.l	(a7)+,d0-d2/a0-a2
	rts

	; readchar()
	; Read a character from the standard input device (Crawcin).
	; out
	;   d0: key ASCII code
readchar
	movem.l	d1-d2/a0-a2,-(a7)

	move.w	#7,-(sp)
	trap	#1
	addq.l	#2,sp

  	movem.l	(a7)+,d1-d2/a0-a2
	rts

	; pexec()
	; Load and execute a program.
	; in
	;   a0: program filename
	; out
	;   d0: exit code of child program or GEMDOS error
pexec
	movem.l	d1-d2/a0-a2,-(a7)

	clr.l	-(a7)
	pea	cmdline(pc)
	pea	(a0)
	pea	$4b0000
	trap	#1
	lea	16(sp),sp

  	movem.l	(a7)+,d1-d2/a0-a2
  	rts

***************************************************************************
* Machine restoring
***************************************************************************

	;
	; mach_restore()
	; Restore machine state: CPU caches & freq, bus config,
	; screen, palette...
	; Called from supexec.
	; Out:
	;   d0: return value
	; Scratch: a0-a1
	;
mach_restore
	movea.l	mach_conf_p(pc),a1

	; Check if machine configuration has been saved.
	tst.w	CONF_DONE(a1)
	beq.s	mach_restore_ret

	; Restore CPU state.
	lea	MACH2CPU(a1),a0
	bsr.s	cpu_restore

	; Restore screen config.
	lea	MACH2SCREEN(a1),a0
	bsr	screen_restore

	; Restore misc. peripherals/system config.
	lea	MACH2MISC(a1),a0
	bsr	misc_restore

	; Reset saved machine config status.
	clr.w	CONF_DONE(a1)
mach_restore_ret
	moveq.l	#0,d0
	rts

	;
	; cpu_restore()
	; Restore CPU state: caches & freq, bus config.
	; in:
	;   a0: cpu_conf
	;
cpu_restore
	movem.l	d0-d2/a0-a2,-(a7)
	movea.l	a0,a2

	;
	; Restore cache config saved by cpu_setup().
	;

	;
	; Save SR and mask all interrupts.
	;
	move.w	sr,-(a7)
	or.w	#$700,sr

	;
	; Save exception vectors that will be modified.
	;
	move.l	$10.w,-(a7)	; Illegal
	move.l	$2c.w,-(a7)	; Line F
	move.l	$f4.w,-(a7)	; Unimp Int Instr

	;
	; Install our own handlers to catch exceptions triggered
	; by unsupported cache maintenance instructions.
	;
	lea	cache_except(pc),a1
	move.l	a1,$10.w
	move.l	a1,$2c.w
	move.l	a1,$f4.w
	nop                	; Flush write pipeline

	movea.l	a7,a0      	; Save SP
	move.l	CACR(a2),d0	; Original cacr

	;
	; Invalidate instr/data/branch/ATC caches on 68040/68060.
	;
	lea	cache_rest_68x(pc),a1
	nop	           	; Stall pipeline
	dc.w	$f4d8      	; cinva bc
	dc.w	$f518      	; pflusha
	nop	           	; Stall pipeline

	;
	; Restore original cacr value on 68020+ CPUs.
	;
cache_rest_68x
	lea	cache_rest_done(pc),a1
	dc.w	$4e7b,$0002	; movec d0,cacr
	nop	           	; Stall pipeline

	;
	; Restore exception vectors and SR.
	;
cache_rest_done
	move.l	(a7)+,$f4.w
	move.l	(a7)+,$2c.w
	move.l	(a7)+,$10.w
	move.w	(a7)+,sr

	move.w	MCH_TYPE(a2),d0

	;
	; Restore MegaSTe cache/freq.
	;
	cmp.b	#MCH_MEGASTE,d0
	bne.s	bus_rest_falcon
	move.b	CACHE_MEGASTE(a2),$ffff8e21.w
	bra.s	cpu_rest_ret

	;
	; Restore Falcon bus control.
	;
bus_rest_falcon
	; Use word comparison to skip this on CT60.
	cmp.w	#MCH_FALCON,d0
	bne.s	cpu_rest_ret
	move.b	BUS_FALCON(a2),$ffff8007.w
cpu_rest_ret
	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; Catch exceptions triggered by unsupported
	; cache maintenance instructions.
	; Restore SP and resume execution at the address
	; specified in a1.
	;
cache_except
	move.l	a0,a7
	jmp	(a1)

	;
	; misc_restore()
	; Restore misc. peripherals/system config,
	; including conterm, internal speaker.
	; in:
	;   a0: misc_conf
	;
misc_restore
	movem.l	d0-d2/a0-a2,-(a7)

	; Save & disable interrupts.
	move.w	sr,-(a7)
	or.w	#$700,sr

	; Restore conterm.
	move.b	CONTERM(a0),$484.w

	; Restore internal speaker state.
	lea	$ffff8800.w,a1
	move.b	#14,(a1)      	; select Port A register
	move.b	(a1),d0      	; get current value
	bclr	#6,d0         	; internal speaker off
	or.b	SPEAKER(a0),d0	; original speaker bit
	move.b	d0,2(a1)      	; write new value

	; Restore interrupts.
	move.w	(a7)+,sr

	; Show mouse.
	dc.w	$a009

	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; screen_restore()
	; Restore screen state: resolution, palette.
	; in:
	;   a0: screen_conf
	;
screen_restore
	movem.l	d0-d7/a0-a4,-(a7)
	movea.l	a0,a4

	; Clear the screen.
	lea	cls(pc),a0
	bsr	print

	bsr	vsync

	; Restore ST palette.
	movem.l	PALETTE(a4),d0-d7
	movem.l	d0-d7,$ffff8240.w

	; Restore screen config.
	move.l	REZ_V(a4),-(a7)
	move.l	PHYSBASE(a4),-(a7)
	move.l	LOGBASE(a4),-(a7)
	move.w	#5,-(a7)
	trap	#14
	lea	14(a7),a7

	; Wait for the update of the screen configuration
	; to take effect.
	bsr	vsync

	; Clear the screen.
	lea	cls(pc),a0
	bsr	print

	movem.l	(a7)+,d0-d7/a0-a4
	rts

***************************************************************************
* Data
***************************************************************************

	; Loader config.
config
	ds.l	1

	; Machine types.
MCH_ST     	=	$1
MCH_STE    	=	$2
MCH_MEGASTE	=	$3
MCH_TT     	=	$4
MCH_FALCON 	=	$5
MCH_CT60   	=	$100

	; Saved machine config [mach_conf - mach_conf_end].
mach_conf
mach_conf_done 	; Machine config has been setup.
	dc.w	0

CONF_DONE	=	(mach_conf_done-mach_conf)

	; Saved CPU configuration [cpu_conf - cpu_conf_end].
cpu_conf
cc_mch_type    	; Machine type (ST/STe/MegaSTe/TT/Falcon).
	ds.w	1
cc_cacr        	; cacr register.
	ds.l	1
cc_cache_mste  	; MegaSTe cache ($ffff8e21).
	ds.w	1
cc_bus_falcon  	; Falcon bus control ($ffff8007).
	ds.w	1
cpu_conf_end

MCH_TYPE     	=	(cc_mch_type-cpu_conf)
CACR         	=	(cc_cacr-cpu_conf)
CACHE_MEGASTE	=	(cc_cache_mste-cpu_conf)
BUS_FALCON   	=	(cc_bus_falcon-cpu_conf)

	; Saved screen config [screen_conf - screen_conf_end].
screen_conf
sc_rez_v        ; ST/Falcon initial rez param (VSetscreen).
sc_rez         	; Initial screen resolution.
	ds.w	1
sc_videomode   	; Initial video mode.
	ds.w	1
sc_rez_invalid 	; Set if resolution is invalid.
	ds.w	1
sc_lowrez_v     ; ST/Falcon low rez param (VSetscreen).
	ds.l	1
sc_physbase    	; Physical start address of the video memory.
	ds.l	1
sc_logbase     	; Logical start address of the video memory.
	ds.l	1
sc_palette     	; Initial ST palette.
	ds.w	16
screen_conf_end

REZ_V           =	(sc_rez_v-screen_conf)
REZ        	=	(sc_rez-screen_conf)
VIDEOMODE  	=	(sc_videomode-screen_conf)
REZ_INVALID	=	(sc_rez_invalid-screen_conf)
LOWREZ_V	=	(sc_lowrez_v-screen_conf)
PHYSBASE   	=	(sc_physbase-screen_conf)
LOGBASE    	=	(sc_logbase-screen_conf)
PALETTE    	=	(sc_palette-screen_conf)

	; Saved misc. config.
misc_conf
mc_conterm      ; Console output config (conterm).
	ds.w	1
mc_speaker      ; Internal speaker on/off.
	ds.w	1
misc_conf_end

CONTERM    	=	(mc_conterm-misc_conf)
SPEAKER    	=	(mc_speaker-misc_conf)

mach_conf_end

MACH2CPU   	=	(cpu_conf-mach_conf)
MACH2SCREEN	=	(screen_conf-mach_conf)
MACH2MISC  	=	(misc_conf-mach_conf)
CPU2SCREEN 	=	(screen_conf-cpu_conf)

	; Trainer information.
trainer_info
	ds.l	2

	; Clear screen + cursor off.
cls
	dc.b	27,"E",27,"f",0
	even

	; For Falcon only.
txt_rez
	dc.b	27,"E"
	dc.b	"INCOMPATIBLE SCREEN RESOLUTION!"
	dc.b	0
	even

	; External intro filename.
extintro_name
	dc.b	"cracktro.68k",0
	even

	; Dummy command line.
cmdline
	dc.b	1," ",0
	even

	; Loader filename.
loader
	dc.b	"loader.68k",0
	even
resident_end

***************************************************************************
* Machine backup & setup (non-resident code)
***************************************************************************

	;
	; mach_setup()
	; Save the machine configuration and setup a
	; ST-compatible CPU & screen configuration.
	; Called from supexec.
	; Out:
	;   d0: return value
	; Scratch: a0-a1
	;
mach_setup
	movea.l	mach_conf_p(pc),a1

	; Ensure machine configuration is setup once.
	tst.w	CONF_DONE(a1)
	bne.s	mach_setup_ret

	; Determine the machine type (ST/STe/MegaSTe/TT/Falcon).
	bsr.s	get_mch_type

	; Save the machine type.
	lea	MACH2CPU(a1),a0
	move.w	d0,MCH_TYPE(a0)

	; Save and setup CPU state: caches & freq, bus config.
	bsr	cpu_setup

	; Save and setup misc. peripherals/system config.
	lea	MACH2MISC(a1),a0
	bsr	misc_setup

	; Save and setup screen config: resolution, palette.
	lea	MACH2SCREEN(a1),a0
	bsr	screen_setup

	; Indicate machine config has been setup.
	st	CONF_DONE(a1)
mach_setup_ret
	moveq.l	#0,d0
	rts

	;
	; get_mch_type()
	; Walk through the cookie jar table to determine the
	; current machine type: ST/STe/MegaSTe/TT/Falcon/CT60.
	; out:
	;   d0: machine type
	;
get_mch_type
	movem.l	d1/a0,-(a7)

	moveq.l	#0,d0

	; Get a pointer to the OSHEADER (SYSHDR) structure.
	movea.l	$4f2.w,a0

	; Get TOS version number.
	move.w	2(a0),d1
	; Old TOSes don't provide the cookie jar,
	; assume machine is ST in that case.
	cmp.w	#$106,d1
	blo.s	mch_default

	; Get a pointer to the cookie jar table.
	move.l	$5a0.w,d1
	beq.s	mch_default
	movea.l	d1,a0
mch_loop
	move.l	(a0)+,d1
	beq.s	mch_default
	cmp.l	#'_MCH',d1
	beq.s	mch_found
	cmp.l	#'CT60',d1	; CT60
	bne.s	mch_next
	or.w	#MCH_CT60,d0
mch_next
	addq.l	#4,a0
	bra.s	mch_loop
mch_found
	move.w	(a0)+,d1
	cmpi.w	#1,d1     	; STe
	bne.s	mch_tst_tt
	btst.b	#4,1(a0)  	; MegaSTe
	bne.s	mch_is_megaste
	move.b	#MCH_STE,d0
	bra.s	mch_end
mch_is_megaste
	move.b	#MCH_MEGASTE,d0
	bra.s	mch_end
mch_tst_tt
	cmpi.w	#2,d1     	; TT
	bne.s	mch_tst_falcon
	move.b	#MCH_TT,d0
	bra.s	mch_end
mch_tst_falcon
	cmpi.w	#3,d1     	; Falcon
	bne.s	mch_default
	move.b	#MCH_FALCON,d0
	bra.s	mch_end
mch_default
	move.b	#MCH_ST,d0	; Default/ST
mch_end
	; Force the CT60 flag is the CPU is a 68060,
	; this is needed on emulators.
	bsr.s	fix_mch_ct60

	movem.l	(a7)+,d1/a0
	rts

	;
	; fix_mch_ct60()
	; Force the CT60 flag if the CPU is a 68060.
	; The 68060 does not implement the movep instruction,
	; this feature is used for the CPU detection.
	; in:
	;   d0: machine type
	; out:
	;   d0: updated machine type
	;
fix_mch_ct60
	movem.l	d1/a0-a1,-(a7)

	; Mask interrupts.
	move.w	sr,-(a7)
	or.w	#$700,sr

	; On 68060, movep generates an Unimplemented Integer
	; Instruction exception ($f4).
	move.l	$f4.w,-(a7)
	lea	cache_except(pc),a1
	move.l	a1,$f4.w

	movea.l	a7,a0
	lea	mch_68060(pc),a1
	clr.l	-(a7)

	move.w	#MCH_CT60,d1
	; d1.w = 0 if CPU <= 68040, d1.w = MCH_CT60 otherwise.
	movep.w	0(a7),d1
mch_68060
	movea.l	a0,a7

	move.l	(a7)+,$f4.w
	move.w	(a7)+,sr

	; Update the machine type.
	or.w	d1,d0

	movem.l	(a7)+,d1/a0-a1
	rts

	;
	; cpu_setup()
	; Save CPU state: caches & freq, bus config.
	; Setup a ST-compatible CPU configuration.
	; in:
	;   a0: cpu_conf
	;
cpu_setup
	movem.l	d0-d2/a0-a2,-(a7)
	move.l	a0,a2

	;
	; Get current cache config and disable all caches.
	; Handle the 3 following m68k families:
	; - 68000/68010: no cache
	; - 68020/68030: basic cache mngt through cacr
	; - 68040/68060: richer cache mngt through cacr
	;                and cpush/cinv instructions
	;

	;
	; Save SR and mask all interrupts.
	;
	move.w	sr,-(a7)
	or.w	#$700,sr

	;
	; Save exception vectors that will be modified.
	;
	move.l	$10.w,-(a7)	; Illegal
	move.l	$2c.w,-(a7)	; Line F
	move.l	$f4.w,-(a7)	; Unimp Int Instr

	;
	; Install our own handlers to catch exceptions triggered
	; by unsupported cache maintenance instructions.
	;
	lea	cache_except(pc),a1
	move.l	a1,$10.w
	move.l	a1,$2c.w
	move.l	a1,$f4.w
	nop                	; Flush write pipeline

	movea.l	a7,a0      	; Save SP

	;
	; Get current cache config.
	;
	lea	cache_dis_done(pc),a1
	moveq.l	#0,d0      	; cacr value if error
	dc.w	$4e7a,$0002	; movec cacr,d0

	;
	; Disable caches on 68040/68060.
	;
cache_dis_6040
	lea	cache_dis_6030(pc),a1
	nop	           	; Stall pipeline
	dc.w	$f4f8      	; cpusha bc
	moveq.l	#0,d1      	; Disable I/D caches
	dc.w	$4e7b,$1002	; movec d1,cacr
	nop	           	; Stall pipeline
	bra.s	cache_dis_done

	;
	; Disable caches on 68020/68030.
	;
cache_dis_6030
	lea	cache_dis_done(pc),a1
	move.w	d0,d1
	and.w	#$0101,d1
	asl.w	#3,d1
	or.w	d1,d0      	; Flush enabled caches
	dc.w	$4e7b,$0002	; movec d0,cacr
	moveq.l	#0,d1      	; Disable I/D caches
	dc.w	$4e7b,$1002	; movec d1,cacr
	nop	           	; Stall pipeline

	;
	; Restore exception vectors and SR.
	;
cache_dis_done
	move.l	(a7)+,$f4.w
	move.l	(a7)+,$2c.w
	move.l	(a7)+,$10.w
	move.w	(a7)+,sr

	;
	; Save original cacr register.
	;
	move.l	d0,CACR(a2)

	move.w	MCH_TYPE(a2),d0

	;
	; Save MegaSTe freq/cache config,
	; setup 8Mhz uncached MegaSTe CPU.
	;
	cmp.b	#MCH_MEGASTE,d0
	bne.s	bus_compat_falcon
	move.b	$ffff8e21.w,CACHE_MEGASTE(a2)
	clr.b	$ffff8e21.w	; 8Mhz uncached CPU
	bra.s	cpu_setup_ret

	;
	; Save Falcon bus control,
	; setup 16Mhz Falcon CPU and STe bus emulation.
	;
bus_compat_falcon
	; Use word comparison on purpose, so that the Falcon
	; bus control is not configured on a CT60.
	cmp.w	#MCH_FALCON,d0
	bne.s	cpu_setup_ret
	move.b	$ffff8007.w,d0
	move.b	d0,BUS_FALCON(a2)
	bclr	#5,d0      	; STe bus emulation
	bset	#0,d0      	; 16Mhz CPU
	move.b	d0,$ffff8007.w

cpu_setup_ret
	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; misc_setup()
	; Save and setup misc. peripherals/system config,
	; including conterm, internal speaker.
	; in:
	;   a0: misc_conf
	;
misc_setup
	movem.l	d0-d2/a0-a2,-(a7)

	; Save & disable interrupts.
	move.w	sr,-(a7)
	or.w	#$700,sr

	; Save and clear conterm.
	move.b	$484.w,CONTERM(a0)
	clr.b	$484.w

	; Switch the internal speaker off.
	lea	$ffff8800.w,a1
	move.b	#14,(a1)      	; select Port A register
	move.b	(a1),d0      	; get current value
	move.b	d0,d1
	and.b	#$40,d1       	; keep int. speaker bit
	move.b	d1,SPEAKER(a0)	; and save it
	bclr	#6,d0         	; internal speaker off
	move.b	d0,2(a1)      	; write new value

	; Restore interrupts.
	move.w	(a7)+,sr

	; Hide mouse.
	dc.w	$a00a

	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; screen_setup()
	; Save screen state: resolution, palette.
	; Setup a ST-compatible low screen resolution.
	; in:
	;   a0: screen_conf
	;
screen_setup
	movem.l	d0-d7/a0-a4,-(a7)
	movea.l	a0,a4

	; Clear the screen.
	bsr	vsync
	lea	cls(pc),a0
	bsr	print

	; Save current physical start address of the video memory.
	move.w	#2,-(a7)
	trap	#14
	addq.l	#2,a7
	move.l	d0,PHYSBASE(a4)

	; Save current logical start address of the video memory.
	move.w	#3,-(a7)
	trap	#14
	addq.l	#2,a7
	move.l	d0,LOGBASE(a4)

	; ST Shifter or Falcon VIDEL video chip?
	move.w	MCH_TYPE-CPU2SCREEN(a4),d0
	cmp.b	#MCH_FALCON,d0
	bne.s	scr_set_st

	;
	; Falcon ST-compatible low rez setup.
	;

	; Get current video mode.
	move.w	#-1,-(a7)
	move.w	#88,-(a7)
	trap	#14
	addq.l	#4,a7

	; Save current screen resolution in the VSetscreen
	; format (rez=3 + modecode).
	move.w	#3,REZ(a4)
	move.w	d0,VIDEOMODE(a4)

	; Determine current screen size and check if it is
	; compatible with ST low rez (size must be >= $7d00).
	move.w	d0,-(a7)
	move.w	#91,-(a7)
	trap	#14
	addq.l	#4,a7
	cmp.l	#$7d00,d0
	bhs.s	scr_set_falcon
	st	REZ_INVALID(a4)
	bra.s	scr_set_cont

	; Compute ST-compatible low rez param in the
	; VSetscreen format (rez=3 + ST-compat low rez modecode).
scr_set_falcon
	moveq.l	#3,d0
	swap	d0
	move.w	VIDEOMODE(a4),d0
	; Clear all bits except VGA/RGB + PAL/NTSC mode.
	and.w	#$30,d0
	; Set ST low mode.
	or.w	#$82,d0
	move.l	d0,LOWREZ_V(a4)
	bra.s	scr_set_common

scr_set_st
	;
	; Legacy ST low rez setup.
	;

	; Get current screen resolution.
	move.w	#4,-(a7)
	trap	#14
	addq.l	#2,a7

	; Save current screen resolution in the VSetscreen
	; format (ST rez + dummy modecode).
	move.w	d0,REZ(a4)
	clr.w	VIDEOMODE(a4)

	; Compute ST/STe/MegaSTe/TT low rez param in the
	; VSetscreen format (ST low rez + dummy modecode).
	moveq.l	#0,d0
	move.l	d0,LOWREZ_V(a4)

scr_set_common
	;
	; Common ST/Falcon VSetscreen trap invocation.
	;
	; d0 contains the ST low rez param in the VSetscreen
	; format, that is the resolution in the high 16 bits
	; and the modecode in the low 16 bits.
	;
	move.l	d0,-(a7)
	move.l	PHYSBASE(a4),-(a7)
	move.l	LOGBASE(a4),-(a7)
	move.w	#5,-(a7)
	trap	#14
	lea	14(a7),a7

	; Wait for the update of the screen configuration
	; to take effect.
	bsr	vsync

scr_set_cont
	; Save ST palette.
	movem.l	$ffff8240.w,d0-d7
	movem.l	d0-d7,PALETTE(a4)

	; Do not change the palette if screen setup failed.
	tst	REZ_INVALID(a4)
	bne.s	scr_set_ret

	; Set all 16 colors to the current background color.
	lea	$ffff8240.w,a0
	move.w	(a0)+,d0
	moveq.l	#14,d1
clear_cols
	move.w	d0,(a0)+
	dbf	d1,clear_cols

	bsr	vsync
scr_set_ret
	movem.l	(a7)+,d0-d7/a0-a4
	rts

	end
