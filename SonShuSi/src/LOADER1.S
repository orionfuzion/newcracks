***************************************************************************
*
* Son Shu Shi - First 100% Version
*
* Checksums removed, mega-trained, filed, repacked, linked, ramdisk,
* bug-fixed, hard-drive and MegaSTe/Falcon/TT/CT60 support.
*
* December 2022 - Orion of The Replicants.
*
* The following code is fully documented and freely distributed
* for didactic purposes.
* It is a record of how games were cracked, trained, filed and packed
* on Atari ST in the golden age of microcomputers.
*
* This code [LOADER1.S] is part of the loader of the game.
*
* The loader initializes the system.
* It loads and executes the main cracktro, then optionally the hidden
* cracktro (if the magic key has been pressed during the main cracktro).
* It prints the trainer menu using fancy fonts and allows to select
* the trainer options.
* It starts the game and patches the various programs of the game
* on-the-fly in order to implement the following improvements:
* - completely remove the copy-protection and especially the checksum
*   routines;
* - enable the mega-trainer mode;
* - support the ST(e), MegaSTe, TT, Falcon and CT60 machines;
*   in particular, provide Falcon-compatible sample replay routines and
*   play the musics and have the game frame rate at the right speed
*   on 60Hz monitors;
* - fix several bugs present in the game;
* - unpack game files using UPX;
* - load game files from a filesystem, using low-level FDC/DMA and
*   FAT12 routines (originally, the game did not use a filesystem but
*   loaded its data from hard-coded disk areas without TOS assistance);
* - run the game from a single 1.44 MB high density floppy disk if
*   supported by hardware or from two standard floppy disks otherwise;
* - use a ramdisk when possible to speed up loading;
* - run the game from a hard-drive on machines with at least 2MB of RAM.
*
* The whole source code is organized as follows:
*
* - LOADER1.S (this file)
*
*   This source file implements the first part of the loader. It is in
*   charge of initializing the system and loading the external cracktros.
*   The resulting binary is run from the GEM.
*   It implements the following components:
*
*    1. Main entry point (part #1)
*    2. XBIOS Routines
*    3. GEMDOS Routines & helper routines
*    4. System backup/initialization/restoring
*    5. External cracktros loading and "ghosts" animation
*    6. Internal intro code (trainer menu)
*    7. Internal intro data
*    8. BSS
*
* - LOADER2.S
*
*   This source file implements the second part of the loader. It is in
*   charge of starting the game and providing all improvements through
*   patches applied on-the-fly.
*   The resulting binary is integrated in the 'SSS1.LNK' library file
*   and executed by LOADER1.S.
*   It implements the following components:
*
*    9. Main entry point (part #2)
*   10. FDC/DMA support
*   11. Game files loading support
*   12. Game files unpacking support
*   13. Game modifications (cracking, enhancements, bug-fixes...)
*   14. Installation and start of the game
*   15. Game preparation
*
* - LOADERH.S
*
*   This header file provides common definitions used by LOADER1.S
*   and LOADER2.S.
*
* - ANIM.S
*
*   Implements the "ghosts" animation played while loading the hidden
*   cracktro. Code by Fury!
*
* - GHOSTS.S
*
*   The "ghosts" pixels arranged for the animation.
*
* - SHELL.S
*
*   The "shell" is a framework for external cracktros, it provides system
*   initialization/restoration routines, VBL handler support (for frame
*   rendering), 50Hz timer handler support (for music playback), and
*   mechanisms for exchanging information and synchronizing with this
*   loader.
*
* - CRACKTRO.S
*
*   A simple example which illustrates how to use the cracktro shell
*   (as the source code of the real cracktros is not provided).
*
* You should be interested, in particular, in the following parts:
*
* - The copy-protection of the game and the techniques to make this
*   advanced crack are detailed in LOADER2.S in sections:
*     13. Game modifications (cracking, enhancements, bug-fixes...)
*     14. Installation and start of the game
*   It includes improved sample replay routines, improved keyboard
*   routines, improved rasters support, 50Hz frame rate and correct
*   music speed on 60Hz monitors.
*
* - Loading game files from a filesystem using low-level FDC/DMA and
*   FAT12 routines is described in LOADER2.S in sections:
*     10. FDC/DMA support
*     11. Game files loading support
*
* - Initializing and restoring the system (CPU, caches, screen...)
*   on ST-compatible machines (ST family, TT, Falcon, CT60) is
*   described in LOADER1.S in section:
*      4. System backup/initialization/restoring
*
* Credits:
* Retro-hacking work & this loader code by Orion / The Replicants
* Initial but not 100% crack by Terminator Kid
* Working copy supplied by Mit / NeXT
* Floppy disks Kryoflux'ed by Brume / Atari Legend
* Testing on real HW by Twister, GT Turbo, Cooper, Fury & Jade
* Fonts of this loader by Walt (L'Ing), first used in Fury's "Bloody" intro
* Code of the main cracktro by Kelly.X / HMD
* Code of the "ghosts" animation by Fury / The Replicants
* Code of the hidden cracktro by Fury / The Replicants
* Code of the cracktro shell by Orion / The Replicants
* Graphics of the main cracktro by Dieu / HMD
* Graphics of the hidden cracktro by Jade / HMD
* Music of the main & hidden cracktros by Dma-Sc / Sector One
* ASCII art of the README by Senser / Effect
* UPX packer by The UPX Team
*
* Git repository: https://github.com/orionfuzion/newcracks
* Contact:        orion.replicants@gmail.com or orion.fuzion@gmail.com
*
* This ASM source code should be assembled using Devpac Developer
* (GenST) v2.23.
*
***************************************************************************

	;
	; Include common definitions.
	;
	include	"LOADERH.S"

***************************************************************************
*	
* 1. Main entry point (part #1)
*
***************************************************************************

	section text

loader_part1_base
	; Get the base page address.
	movea.l	4(a7),a0

	; Clear the BSS.
	bsr	clear_bss

	; Set up the stack.
	lea	stack_top(pc),a7

	; Adjust the memory allocated to the program.
	bsr	prog_mshrink
	tst.l	d0
	bmi.w	.quit

	;
	; System backup & setup.
	;
	lea	mach_setup(pc),a0
	bsr	supexec

	; Check if the screen resolution is valid.
	lea	mach_conf(pc),a0
	tst.w	MACH2SCREEN+REZ_INVALID(a0)
	beq.s	.rez_ok
	moveq.l	#EREZ,d0
	bra.w	.error
.rez_ok
	;
	; Run the external cracktros.
	;
	lea	extintro_pre(pc),a0
	bsr	supexec
	ifeq	DEBUG_LOAD_ANIM
	lea	extintro_name_main(pc),a0
	lea	extintro_cmdline_main(pc),a1
	bsr	pexec
	cmpi.w	#'!H',d0
	beq.s	.post           ; No hidden cracktro
	cmpi.w	#'H!',d0
	beq.s	.hidden         ; Hidden cracktro wanted
	lea	extintro_executed(pc),a0
	sf	(a0)            ; Main cracktro failure
	bra.s	.post
	; The hidden cracktro does not run on legacy 8MHz machines
	; configured with 60Hz video.
.hidden	move.w	cpu_conf+MCH_TYPE(pc),d0
	btst	#MCH_VIDEO_60HZ_BIT,d0
	beq.s	.mch_ok         ; 50Hz video
	cmpi.b	#MCH_MEGASTE,d0
	bhi.s	.mch_ok         ; Falcon/TT
	blo.s	.post           ; 8MHz ST/STe, 60Hz video
	btst	#MCH_MSTE_16MHZ_BIT,d0
	beq.s	.post           ; 8MHz MegaSTe, 60Hz video
.mch_ok
	endc	; DEBUG_LOAD_ANIM
	lea	extintro_post(pc),a0
	bsr	supexec
	lea	load_anim_start(pc),a0
	bsr	supexec
	ifne	DEBUG_LOAD_ANIM
	bsr	readchar
	elseif
	lea	extintro_name_hidden(pc),a0
	lea	extintro_cmdline_hidden(pc),a1
	bsr	pexec
	endc	; DEBUG_LOAD_ANIM
	lea	load_anim_stop(pc),a0
	bsr	supexec
.post	lea	extintro_post(pc),a0
	bsr	supexec

	;
	; Run the internal intro (trainer menu).
	;
.int	lea	intro(pc),a0
	bsr	supexec

	; Load and dynamically link the second part of the loader
	; (LOADER2.S) which is stored at the beginning of the
	; 'SSS1.LNK' library file.
.part2	bsr.s	loader_part2_link
	tst.l	d0
	bmi.s	.error

	;
	; Print debugging information.
	;
	ifne	DEBUG_REGS
	bsr	dump_regs
	endc

	; Execute the second part of the loader (LOADER2.S) which
	; will start the game.
	; This function returns in case of error only (library
	; file not found, not enough memory...).
	move.l	#'REPS',d0
	XCALL	loader_part2_entry

	;
	; Restore system state in case of error.
	;
.error	move.l	d0,d1
	lea	mach_restore(pc),a0
	bsr	supexec

	; Print a message corresponding to the encountered error.
	move.l	d1,d0
	bsr	print_error

	; Terminate this program and free its resources
	; (such as allocated memory blocks).
.quit	clr.w	-(a7)
	trap	#1

	;
	; clear_bss()
	;
	; Clear the BSS segment.
	;
	; Some executable packers (e.g. Atomik) do not clear
	; the BSS of the uncompressed program, so we clear
	; this segment explicitly to be safe.
	;
	; In:
	;   a0: base page address
	;
clear_bss
	movem.l	d0/a1,-(a7)

	movea.l	8(a0),a1        ; a1  = text addr
	adda.l	12(a0),a1       ; a1 += text size
	adda.l	20(a0),a1       ; a1 += data size
	move.l	28(a0),d0       ; d0  = bss size

	lsr.l	#2,d0
.clear	clr.l	(a1)+
	dbf	d0,.clear

	movem.l	(a7)+,d0/a1
	rts

	;
	; prog_mshrink()
	;
	; Adjust TPA to program's needs.
	;
	; In:
	;   a0: base page address
	;
	; Out:
	;   d0: GEMDOS error
	;
prog_mshrink
	move.l	8(a0),d0        ; d0  = text addr
	add.l	12(a0),d0       ; d0 += text size
	add.l	20(a0),d0       ; d0 += data size
	add.l	28(a0),d0       ; d0 += bss size
	; a0 = base page
	; d0 = prog end - base page
	sub.l	a0,d0
	bsr	mshrink
	rts

	;
	; loader_part2_link()
	;
	; Load and dynamically link the second part of the loader.
	;
	; The second part of the loader (LOADER2.S) is stored at the
	; beginning of the 'SSS1.LNK' library file, right before the
	; game files. It is loaded, dynamically linked and executed
	; by the first part of the loader (this file).
	; Once dynamically linked, LOADER1.S and LOADER2.S can perform
	; so-called XCALLS, ie calls from one of the two parts to the
	; other. Similarly, each of the two parts can access variables
	; (32-bit words) located in the other part.
	; Dynamic symbols are resolved and relocated when LOADER2.S
	; is loaded in memory by LOADER1.S, using a dynamic linking
	; mechanism.
	; Dynamic symbol resolution means binding symbol references
	; from one part to symbol definitions within the other part.
	; Dynamic symbol relocation means calculating the absolute
	; address of every symbol reference.
	; To this end, each loader part provides a set of two tables:
	; - A table of imported symbols.
	;   It lists the symbol references (ie imported symbols) that
	;   the loader part needs to call or access.
	; - A table of exported symbols.
	;   It lists the symbol definitions (ie exported symbols) that
	;   the other part can call or access.
	; The macro XCALL is used to call an external routine (ie
	; a routine located in the other part and referenced by
	; a dynamic symbol).
	; The macro XADDR is used to access an external variable (ie
	; a 32-bit word located in the other part and pointed to by a
	; dynamic symbol).
	;
	; Out:
	;   d0: GEMDOS error
	;
loader_part2_link
	movem.l	d1-d2/a0-a2,-(a7)

	; Allocate the memory block where the second part of the
	; loader will be installed.
	move.l	#PART2_SECTORS*512,d0
	move.l	d0,d1
	bsr	malloc
	tst.l	d0
	bne.s	.memok
	moveq.l	#ENSMEM,d0
	bra.w	.ret
.memok	movea.l	d0,a1

	; In release mode, the second part of the loader is always
	; available as a separate binary integrated in library #1.
	ifeq	MERGE_PART2_SRC

	; Open the library file (SSS1.LNK) containing the binary of
	; the second part (LOADER2.S).
	lea	lib1_fname(pc),a0
	bsr	fopen
	movea.l	a1,a0
	move.l	d0,d2
	bmi	.mfree

	; Load the library header, the game files directory and the
	; second part of the loader into the allocated memory.
	; Indeed, LOADER2.S is located at the beginning of the library,
	; after the directory and before the game files.
	bsr	fread
	cmp.l	d0,d1
	beq.s	.close
	moveq.l	#EREADF,d0

	; Close the library file.
.close	exg	d0,d2
	bsr	fclose
	move.l	d2,d0
	bmi.s	.mfree

	; Verify the integrity of the loaded chunk: the checksum
	; on its content must be equal to 0.
	move.w	#((PART2_SECTORS*512)>>4)-1,d0
	moveq.l	#0,d1
.chksum	rept	4
	add.l	(a1)+,d1
	endr
	dbf	d0,.chksum
	tst.l	d1
	bne.s	.err

	; In debug mode, the second part of the loader can be
	; included in source form directly from this file (see
	; part2_merged below).
	elseif	; MERGE_PART2_SRC

	; Copy the "merged" part into the allocated memory block.
	movea.l	a1,a0
	lea	part2_merged(pc),a2
	move.w	#((PART2_SECTORS*512)>>2)-1,d0
.cp	move.l	(a2)+,(a1)+
	dbf	d0,.cp

	endc	; MERGE_PART2_SRC

	; Sanity check: verify the magic of the library file header.
	cmpi.l	#'REPS',(a0)
	bne.s	.err
	; Sanity check: read the offset of the first game file from
	; the library directory and verify that it is equal to the
	; size of the second part of the loader. The first game file
	; is indeed located right after LOADER2.S in the library file.
	cmpi.w	#(PART2_SECTORS*512)>>4,8(a0)
	bne.s	.err

	; Skip the library directory and points to the beginning of
	; LOADER2.S which provides a special header followed by the
	; two dynamic symbol tables (imported and exported symbols).
	lea	(80*2)(a0),a1
	; And get the start address of the two dynamic symbol tables
	; provided by LOADER1.S (this file).
	lea	dyn_symbs(pc),a2

	; Check the magics of the header of LOADER2.S.
	cmpi.w	#$4afc,(a1)+
	bne.s	.err
	cmpi.l	#'RLNK',(a1)+
	bne.s	.err

	;
	; Dynamic symbols resolution.
	;
	; The principle used to resolve symbols is very simple: each
	; part of the loader provides a set of two tables, one for
	; imported symbols and another for exported symbols.
	; These tables allow to associate (resolve) the imported
	; symbols of one part with the exported symbols of the other
	; part, and vice versa.
	; The symbols listed by each part must be in the same order
	; and in equal number as those listed by the other part.
	; In other words, the symbols listed in the tables of both
	; parts of the loader must match one by one.
	;

	; Check the version number of the two sets of tables.
	cmpm.w	(a2)+,(a1)+
	bne.s	.err
	; The number of symbols imported by LOADER2.S must match the
	; number of symbols exported by LOADER1.S.
	move.w	(a2)+,d0
	cmp.w	(a1)+,d0
	bne.s	.err
	; The number of symbols exported by LOADER2.S must match the
	; number of symbols imported by LOADER1.S.
	move.w	(a2)+,d1
	cmp.w	(a1)+,d1
	bne.s	.err

	;
	; Dynamic symbols relocation.
	;
	; Once the symbol resolution is done, it is then necessary
	; to perform the relocation of the symbol references, i.e.
	; to calculate the absolute address of each imported symbol,
	; for both parts of the loader.
	; To do this, each part of the loader provides the other part
	; with the necessary information in its table of exported
	; symbols, i.e. the offsets of the symbols, which must then
	; be converted into absolute addresses.
	;

	; Relocate symbol references (imported symbols) of LOADER2.S.
.rel2	subq.w	#1,d0
	blt.s	.rel1
	move.l	a2,d2
	add.l	(a2)+,d2
	move.w	#$4ef9,(a1)+
	move.l	d2,(a1)+
	bra.s	.rel2

	; Relocate symbol references (imported symbols) of LOADER1.S.
.rel1	subq.w	#1,d1
	blt.s	.done
	move.l	a1,d2
	add.l	(a1)+,d2
	move.w	#$4ef9,(a2)+
	move.l	d2,(a2)+
	bra.s	.rel1

.done	moveq.l	#0,d0
.ret	movem.l	(a7)+,d1-d2/a0-a2
	rts
.err	moveq.l	#EPLFMT,d0
.mfree	bsr	mfree
	bra.s	.ret

	;
	; For debugging purposes only, the second part of the loader
	; can be included in source form directly here, to avoid
	; compiling and loading it separately.
	; For this purpose, a fake library file header is created,
	; followed by LOADER2.S as if library #1 had been partially
	; loaded here.
	;
	ifne	MERGE_PART2_SRC
	; Tell the second part that it is included in source form
	; so that it does not include LOADERH.S which is already
	; included by the current source file.
PART2_IS_MERGED = 1
part2_merged
	; Fake library #1 header.
	dc.l	'REPS',0
	; Offset of game file #0 in the library directory (also
	; known as the files table).
	dc.w	(part2_end-part2_merged)>>4
	ds.w	80-5
	; Second part of the loader is included here.
	include	"LOADER2.S"
part2_pad
	; Padding.
	ds.b	(PART2_SECTORS*512)-(part2_pad-part2_merged)
part2_end
	endc	; MERGE_PART2_SRC

	;
	; Macro used in print_error() to handle each
	; error case.
	;
prt_err	macro
	cmpi.b	#\1,d0
	bne.s	.nxt_\@
	lea	txt_\2(pc),a0
	bra.s	.pr_err
.nxt_\@
	endm

	;
	; print_error()
	;
	; Print a message of error corresponding to the
	; error code passed in d0.
	;
	; In:
	;   d0: error code
	;
print_error
	movem.l	d0/a0,-(a7)

	; Read all chars available in the input buffer.
	bsr	flush_input_buffer

	lea	cls(pc),a0
	bsr	print

	; Handle every error case.
	prt_err	EFDC,efdc
	prt_err	EREADF,ereadf
	prt_err	EFILNF,efilnf
	prt_err	ENSMEM,ensmem
	prt_err	EPLFMT,eplfmt
	prt_err	EMMU,emmu
	prt_err	EDRV,edrv
	prt_err	EHD2M,ehd2m
	prt_err	EMCH1M,emch1m
	prt_err	EREZ,erez

	; Default (generic) error case.
	lea	txt_egen(pc),a0

.pr_err	bsr	print
	bsr	readchar

	movem.l	(a7)+,d0/a0
	rts

	;
	; Dynamically linked symbols, file names and error
	; messages are placed in the data section.
	;
	section	data

	; Set of two tables describing dynamically linked symbols
	; (between the 1st and 2nd part of the loader).
dyn_symbs
	; Version number used to identify the tables.
	dc.w	DL_VERSION
	; Nb of symbols exported by the 1st loader part.
	dc.w	16
	; Nb of symbols imported by the 1st loader part.
	ifne	DEBUG_REGS
	dc.w	4
	elseif
	dc.w	1
	endc

	; Exported symbols (symbol definitions).
	; LOADER2.S lists the same symbols in the same order in its
	; table of imported symbols.
	EXPORT	wait_ikbd
	EXPORT	send_ikbd
	EXPORT	flush_acia
	EXPORT	supexec
	EXPORT	malloc
	EXPORT	mfree
	EXPORT	fopen
	EXPORT	fsize
	EXPORT	fread
	EXPORT	fclose
	EXPORT	getdrv
	EXPORT	cpu_conf+MCH_TYPE
	EXPORT	cpu_conf+RP
	EXPORT	opts_info
	EXPORT	lib1_fname
	EXPORT	lib2_fname

	; Imported symbols (symbol references).
	; LOADER2.S lists the same symbols in the same order in its
	; table of exported symbols.
	IMPORT	loader_part2_entry
	ifne	DEBUG_REGS
	IMPORT	get_tpa_end
	IMPORT	calibrate_delay
	IMPORT	dma_delay
	endc

	; Library #1 file name.
lib1_fname
	ifne	FORCE_LIBS_PATH
	dc.b	"c:\sss1.lnk",0
	elseif
	dc.b	"sss1.lnk",0
	endc
	even

	; Library #2 file name.
lib2_fname
	ifne	FORCE_LIBS_PATH
	dc.b	"c:\sss2.lnk",0
	elseif
	dc.b	"sss2.lnk",0
	endc
	even

	; -1   FDC/DMA (drive A) read error.
txt_efdc
	dc.b	"FDC READ ERROR!"
	dc.b	0
	even

	; -11  BIOS "file read" error.
txt_ereadf
	dc.b	"LIBRARY FILE READ ERROR!"
	dc.b	0
	even

	; -33  GEMDOS "file not found" error.
txt_efilnf
	dc.b	"LIBRARY FILE NOT FOUND!"
	dc.b	0
	even

	; -39  GEMDOS "not enough memory" error.
txt_ensmem
	dc.b	"NOT ENOUGH MEMORY!"
	dc.b	0
	even

	; -66  GEMDOS "invalid program format" error.
txt_eplfmt
	dc.b	"INVALID PROGRAM FORMAT!"
	dc.b	0
	even

	; -92  Loader generic error.
txt_egen
	dc.b	"FAILED TO SET UP THE GAME!"
	dc.b	0
	even

	; -95  Falcon/CT60/TT MMU error.
txt_emmu
	dc.b	"INCOMPATIBLE MMU ROOT POINTER!"
	dc.b	0
	even

	; -96  Loader "unsupported drive B" error.
txt_edrv
	dc.b	"RUNNING FROM DRIVE B IS NOT SUPPORTED!"
	dc.b	0
	even

	; -97  Loader "2MB min memory" error.
txt_ehd2m
	dc.b	"RUNNING FROM HDD REQUIRES 2MB OF RAM!"
	dc.b	0
	even

	; -98  Falcon/CT60/TT "1MB min memory" error.
txt_emch1m
	dc.b	"THIS MACHINE REQUIRES 1MB OF RAM!"
	dc.b	0
	even

	; -99  Falcon "bad resolution" error.
txt_erez
	dc.b	"INCOMPATIBLE SCREEN RESOLUTION!"
	dc.b	0
	even

	; Reset section to text.
	section	text

***************************************************************************
*
* 2. XBIOS routines
*
* Public routines:
* - supexec()
* - vsync()
* - vsync_sup()
*
* Doc:
* - https://freemint.github.io/tos.hyp/en/xbios_functions.html
*
***************************************************************************

	;
	; supexec()
	;
	; Execute a routine in supervisor mode.
	;
	; In:
	;   a0: routine address
	;
	; Out:
	;   d0: return value of the routine
	;
supexec
	movem.l	d1-d2/a0-a2,-(a7)

	pea	(a0)
	move.w	#$26,-(a7)
	trap	#14
	addq.l	#6,a7

  	movem.l	(a7)+,d1-d2/a0-a2
  	rts

	;
	; vsync()
	;
	; Wait for the next vertical sync signal.
	;
vsync
	movem.l	d0-d2/a0-a2,-(a7)

	move.w	#$25,-(a7)
	trap	#14
	addq.l	#2,a7

	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; vsync_sup()
	;
	; Optimized vsync implementation for the Supervisor mode.
	;
vsync_sup
	move.l	d0,-(a7)

	move.w	#$2700,sr
	move.w	$468.w,d0
.wait	stop	#$2300
	cmp.w	$468.w,d0
	beq.s	.wait

	move.l	(a7)+,d0
	rts

***************************************************************************
*
* 3. GEMDOS routines & helper routines
*
* Public routines:
* - mshrink()
* - malloc()
* - mfree()
* - print()
* - checkchar()
* - readchar()
* - getdrv()
* - pexec()
* - fopen()
* - fseek()
* - fsize()
* - fread()
* - fclose()
*
* Doc:
* - https://freemint.github.io/tos.hyp/en/gemdos_functions.html
*
***************************************************************************

	;
	; GEMDOS access.
	;
TRAP_GEMDOS	macro
	trap	#1
	endm

	;
	; mshrink()
	;
	; Reduce already reserved memory.
	;
	; In:
	;   d0: new size
	;   a0: start address
	;
	; Out:
	;   d0: GEMDOS error
	;
mshrink
	movem.l	d1-d2/a0-a2,-(a7)

	move.l	d0,-(a7)
	pea	(a0)
	move.l	#$4a0000,-(a7)
	TRAP_GEMDOS
	lea	12(a7),a7

  	movem.l	(a7)+,d1-d2/a0-a2
	rts

	;
	; malloc()
	;
	; Allocate a block of memory.
	;
	; In:
	;   d0: number of bytes to be allocated
	;
	; Out:
	;   d0: address of the allocated block,
	;       or NULL if not enough memory
	;
malloc
	movem.l	d1-d2/a0-a2,-(a7)

	move.l	d0,-(a7)
	move.w	#$48,-(a7)
	TRAP_GEMDOS
	addq.l	#6,a7	

  	movem.l	(a7)+,d1-d2/a0-a2
	rts

	;
	; mfree()
	;
	; Free the memory block previously allocated by malloc.
	;
	; In:
	;   a0: address of the block to be freed
	;
mfree
	movem.l	d0-d2/a0-a2,-(a7)

	pea	(a0)
	move.w	#$49,-(a7)
	TRAP_GEMDOS
	addq.l	#6,a7	

  	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; print()
	;
	; Write a string to the standard output device (Cconws).
	;
	; In:
	;   a0: string address
	;
print
	movem.l	d0-d2/a0-a2,-(a7)

	pea	(a0)
	move.w	#9,-(a7)
	TRAP_GEMDOS
	addq.l	#6,a7	

  	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; checkchar()
	;
	; Check whether a character is waiting in the standard
	; input buffer (Cconis).
	;
	; Out:
	;   d0: -1 if a character is available, 0 otherwise

	;
checkchar
	movem.l	d1-d2/a0-a2,-(a7)

	move.w	#11,-(a7)
	TRAP_GEMDOS
	addq.l	#2,a7

  	movem.l	(a7)+,d1-d2/a0-a2
	rts

	;
	; readchar()
	;
	; Read a character from the standard input device (Crawcin).
	;
	; Out:
	;   d0: key ASCII code
	;
readchar
	movem.l	d1-d2/a0-a2,-(a7)

	move.w	#7,-(a7)
	TRAP_GEMDOS
	addq.l	#2,a7

  	movem.l	(a7)+,d1-d2/a0-a2
	rts

	;
	; getdrv()
	;
	; Get the current drive.
	;
	; Out:
	;   d0: drive number: 0 (A), 1 (B), 2 (C)...
	;
getdrv
	movem.l	d1-d2/a0-a2,-(a7)

	ifne	FORCE_DRVA
	moveq.l	#0,d0
	elseif
	move.w	#$19,-(a7)
	TRAP_GEMDOS
	addq.l	#2,a7
	endc

  	movem.l	(a7)+,d1-d2/a0-a2
	rts

	;
	; pexec()
	;
	; Load and execute a program.
	;
	; In:
	;   a0: program filename
	;   a1: program command line
	;
	; Out:
	;   d0: exit code of child program or GEMDOS error
	;
pexec
	movem.l	d1-d2/a0-a2,-(a7)

	clr.l	-(a7)
	pea	(a1)
	pea	(a0)
	pea	$4b0000
	TRAP_GEMDOS
	lea	16(a7),a7

  	movem.l	(a7)+,d1-d2/a0-a2
  	rts

	;
	; fopen()
	;
	; Open a file.
	;
	; In:
	;   a0: filename
	;
	; Out:
	;   d0: file handle or GEMDOS error
	;
fopen
	movem.l	d1-d2/a0-a2,-(a7)

	clr.w	-(a7)
	pea	(a0)
	move.w	#$3d,-(a7)
	TRAP_GEMDOS
	addq.l	#8,a7

	movem.l	(a7)+,d1-d2/a0-a2
	rts

	;
	; fseek()
	;
	; Move file position pointer.
	;
	; In:
	;   d0: file handle
	;   d1: new file offset (from start of file)
	;
	; Out:
	;   d0: actual file offset or GEMDOS error
	;
fseek
	movem.l	d1-d2/a0-a2,-(a7)

	clr.w	-(a7)
	move.w	d0,-(a7)
	move.l	d1,-(a7)
	move.w	#$42,-(a7)
	TRAP_GEMDOS
	lea	10(a7),a7

	movem.l	(a7)+,d1-d2/a0-a2
	rts

	;
	; fsize()
	;
	; Get file size (using seek from EOF).
	;
	; In:
	;   d0: file handle
	;
	; Out:
	;   d0: actual file size or GEMDOS error,
	;   file position is reset to zero
	;
fsize
	movem.l	d0-d2/a0-a2,-(a7)

	; Seek from end of file.
	move.w	#2,-(a7)
	move.w	d0,-(a7)
	clr.l	-(a7)
	move.w	#$42,-(a7)
	TRAP_GEMDOS

	; Save return value.
	move.l	d0,10(a7)

	; Reset file position to 0.
	clr.w	8(a7)
	move.w	#$42,(a7)
	TRAP_GEMDOS
	lea	10(a7),a7

	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; fread()
	;
	; Read from a file.
	;
	; In:
	;   d0: file handle
	;   d1: number of bytes of data to read
	;   a0: address of the receiving buffer
	;
	; Out:
	;   d0: number of bytes actually read or GEMDOS error
	;
fread
	movem.l	d1-d2/a0-a2,-(a7)

	pea	(a0)
	move.l	d1,-(a7)
	move.w	d0,-(a7)
	move.w	#$3f,-(a7)
	TRAP_GEMDOS
	lea	12(a7),a7

	movem.l	(a7)+,d1-d2/a0-a2
	rts

	;
	; fclose()
	;
	; Close a file.
	;
	; In:
	;   d0: file handle
	;
	; Out:
	;   d0: GEMDOS error
	;
fclose
	movem.l	d1-d2/a0-a2,-(a7)

	; Valid file handle?
	tst.l	d0
	bmi.s	.ret

	move.w	d0,-(a7)
	move.w	#$3e,-(a7)
	TRAP_GEMDOS
	addq.l	#4,a7

.ret	movem.l	(a7)+,d1-d2/a0-a2
	rts

***************************************************************************
*
* 4. System backup/initialization/restoring
*
* The following code provides system backup, initialization and restoring
* for ST, STe, MegaSTe, TT, Falcon and CT60.
*
* Public routines:
* - flush_input_buffer()
* - send_ikbd()
* - flush_acia()
* - wait_ikbd()
* - VSetscreen()
* - mach_setup()
* - mach_restore()
* - dump_regs()
*
* Doc:
* - https://mikro.naprvyraz.sk/docs/Memory%20Maps/HARDWARE.TXT
* - https://mikro.naprvyraz.sk/docs/Memory%20Maps/FALVIDEO.TXT
* - http://retrospec.sgn.net/users/tomcat/miodrag/Atari_ST/Atari%20ST%20Internals.htm
* - https://www.nxp.com/docs/en/reference-manual/MC68030UM.pdf
* - https://www.nxp.com/docs/en/data-sheet/MC68060UM.pdf
* - https://www.kernel.org/doc/Documentation/input/atarikbd.txt
* - http://leonard.oxg.free.fr/articles/multi_atari/multi_atari.html
* - https://github.com/upx/upx/blob/master/src/stub/src/m68k-atari.tos.S#L78
* - http://d-bug.me/uls.php
*
***************************************************************************

	;
	; linea_hidemouse()
	;
	; Hide the mouse cursor.
	;
linea_hidemouse:
	movem.l	d0-d2/a0-a2,-(a7)

	dc.w	$a00a           ; Hide mouse

	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; linea_showmouse()
	;
	; Show the mouse cursor only if the number of "show mouse"
	; matches the number of "hide mouse".
	;
linea_showmouse:
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
	; flush_input_buffer()
	;
	; Read all characters available in the input buffer (con).
	;
flush_input_buffer
	move.l	d0,-(a7)

.flush	bsr	checkchar
	tst.l	d0
	beq.s	.ret
	bsr	readchar
	bra.s	.flush	

.ret	move.l	(a7)+,d0
	rts

	;
	; send_ikbd()
	;
	; Send a command to the IKBD.
	;
	; In:
	;   d0: IKBD command
	;
send_ikbd
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
	; flush_acia()
	;
	; Flush the ACIA receive buffer.
	;
flush_acia
	btst	#0,$fffffc00.w
	beq.s	.done
	tst.b	$fffffc02.w
	bra.s	flush_acia
.done	rts

	;
	; wait_ikbd()
	;
	; Wait until the IKBD is idle.
	; Make sure that all pending IKBD events are consumed
	; by the current IKBD interrupt handler.
	;
wait_ikbd
	movem.l	d0-d1/a0,-(a7)
	move.w	$3fe.w,-(a7)

	; Hook the IKBD interrupt vector.
	; Each time an IKBD interrupt is triggered, a flag is
	; raised at address $3fe.
	lea	.isr_hook(pc),a0
	move.l	$118.w,(.isr_orig+2-.isr_hook)(a0)
	move.l	a0,$118.w

	; Wait until the IKBD is idle: at least 20 milliseconds
	; (4 timer C interruptions) must elapse without any
	; IKBD interruptions.
.again	sf.b	$3fe.w          ; Clear the flag
	move.l	$4ba.w,d0       ; Timer C counter (_hz_200)
	addq.l	#4,d0           ; 4 timer C periods = 20 ms
.wait	stop	#$2300          ; Wait for interrupt
	tst.b	$3fe.w          ; Any IKBD interrupt?
	bne.s	.again          ; Yes, let's start over
	move.l	d0,d1
	sub.l	$4ba.w,d1       ; Wait for 20 ms
	bpl.s	.wait

	; Restore the original IKBD interrupt vector.
	move.l	(.isr_orig+2-.isr_hook)(a0),$118.w

	move.w	(a7)+,$3fe.w
	movem.l	(a7)+,d0-d1/a0
	rts

.isr_hook
	; Indicate that an IKBD interrupt has occurred.
	st	$3fe.w
.isr_orig
	; Call the original IKBD handler.
	jmp	$0.l

	;
	; mach_setup()
	;
	; Backup the machine configuration and set up a
	; ST-compatible CPU & screen configuration.
	;
	; Called from supexec.
	;
	; Out:
	;   d0: return value
	;
	; Scratch: a0-a1
	;
mach_setup
	lea	mach_conf(pc),a1

	; Ensure machine configuration is set up once.
	tst.w	CONF_DONE(a1)
	bne.s	.ret

	; Determine the machine type (ST/STe/MegaSTe/TT/Falcon).
	bsr.s	get_mch_type

	; Save the machine type.
	lea	MACH2CPU(a1),a0
	move.w	d0,MCH_TYPE(a0)

	; Save and set up CPU state: caches & freq, bus config.
	bsr	cpu_setup

	; Save and set up misc. peripherals/system config.
	lea	MACH2MISC(a1),a0
	bsr	misc_setup

	; Save and set up screen config: resolution, palette.
	lea	MACH2SCREEN(a1),a0
	bsr	screen_save
	tst.w	REZ_INVALID(a0)
	bne.s	.done
	bsr	screen_setup

	; Indicate machine config has been saved and set up.
.done	st	CONF_DONE(a1)

.ret	moveq.l	#0,d0
	rts

	;
	; get_mch_type()
	;
	; Walk through the cookie jar table to determine the
	; current machine type: ST/STe/MegaSTe/TT/Falcon/CT60.
	;
	; Out:
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
	cmpi.w	#$106,d1
	blo.s	.dflt

	; Get a pointer to the cookie jar table.
	move.l	$5a0.w,d1
	beq.s	.dflt
	movea.l	d1,a0

.loop	move.l	(a0)+,d1
	beq.s	.dflt
	cmpi.l	#'_MCH',d1
	beq.s	.found
	cmpi.l	#'CT60',d1      ; CT60
	bne.s	.next
	ori.w	#MCH_CT60,d0
.next	addq.l	#4,a0
	bra.s	.loop

.found	move.w	(a0)+,d1
	cmpi.w	#1,d1           ; STe
	bne.s	.tst_tt
	btst.b	#4,1(a0)        ; MegaSTe
	bne.s	.mste
	move.b	#MCH_STE,d0
	bra.s	.end

.mste	move.b	#MCH_MEGASTE,d0
	bra.s	.end

.tst_tt	cmpi.w	#2,d1           ; TT
	bne.s	.tst_falcon
	move.b	#MCH_TT,d0
	bra.s	.end

.tst_falcon
	cmpi.w	#3,d1           ; Falcon
	bne.s	.dflt
	move.b	#MCH_FALCON,d0
	bra.s	.end

.dflt	move.b	#MCH_ST,d0      ; Default/ST
.end
	; Force the CT60 flag if the CPU is a 68060,
	; this is needed when running EmuTOS.
	bsr.s	fix_mch_ct60

	movem.l	(a7)+,d1/a0
	rts

	;
	; fix_mch_ct60()
	;
	; Force the CT60 flag if the CPU is a 68060.
	; The 68060 does not implement the movep instruction,
	; this feature is used for the CPU detection.
	;
	; In:
	;   d0: machine type
	;
	; Out:
	;   d0: updated machine type
	;
fix_mch_ct60
	movem.l	d1/a0-a1,-(a7)

	; Mask interrupts.
	move.w	sr,-(a7)
	ori.w	#$700,sr

	; On 68060, movep generates an Unimplemented Integer
	; Instruction exception ($f4).
	move.l	$f4.w,-(a7)
	lea	cache_except(pc),a1
	move.l	a1,$f4.w

	movea.l	a7,a0
	lea	.cont(pc),a1
	clr.l	-(a7)

	move.w	#MCH_CT60,d1
	; d1.w = 0 if CPU <= 68040 (movep has been executed),
	; d1.w = MCH_CT60 otherwise (movep caused an exception).
	movep.w	0(a7),d1
.cont	movea.l	a0,a7

	move.l	(a7)+,$f4.w
	move.w	(a7)+,sr

	; Update the machine type.
	or.w	d1,d0

	movem.l	(a7)+,d1/a0-a1
	rts

	;
	; cpu_setup()
	;
	; - Save CPU state: caches & freq, bus config.
	; - Set up a ST-compatible CPU configuration.
	;
	; In:
	;   a0: cpu_conf
	;
cpu_setup
	movem.l	d0-d2/a0-a2,-(a7)
	movea.l	a0,a2

	;
	; Get the current cache config and disable all caches.
	; Handle the 3 following m68k families:
	; - 68000/68010: no cache
	; - 68020/68030: basic cache mngt through cacr
	; - 68040/68060: richer cache mngt through cacr
	;                and cpush/cinv instructions
	;
	; Also get the MMU root pointer if supported by the HW.
	; It is saved for later verification.
	;

	;
	; Save SR and mask all interrupts.
	;
	move.w	sr,-(a7)
	ori.w	#$700,sr

	;
	; Save exception vectors that will be modified.
	;
	move.l	$10.w,-(a7)     ; Illegal
	move.l	$2c.w,-(a7)     ; Line F
	move.l	$f4.w,-(a7)     ; Unimp Int Instr

	;
	; Install our own handlers to catch exceptions triggered
	; by unsupported cache maintenance instructions.
	;
	lea	cache_except(pc),a1
	move.l	a1,$10.w
	move.l	a1,$2c.w
	move.l	a1,$f4.w

	;
	; Reserve space for the MMU root pointer and set its
	; default value to zero.
	; The default value is used if the current architecture
	; does not support paged memory management (< 68030).
	;
	clr.l	-(a7)
	clr.l	-(a7)           ; crp is 64-bit

	nop	                ; Flush write pipeline

	movea.l	a7,a0           ; Save SP

	;
	; Get current cache config.
	;
	lea	.done(pc),a1
	moveq.l	#0,d0           ; cacr value if error
	dc.w	$4e7a,$0002     ; movec cacr,d0

	;
	; Disable caches on 68040/68060.
	;
.68040	lea	.68020(pc),a1
	nop	                ; Stall pipeline
	dc.w	$f4f8           ; cpusha bc
	moveq.l	#0,d1           ; Disable I/D caches
	dc.w	$4e7b,$1002     ; movec d1,cacr
	nop	                ; Stall pipeline

	;
	; Get the 68040/68060 user root pointer register.
	;
	dc.w	$4e7a,$1806     ; movec urp,d1
	move.l	d1,4(a0)        ; Save urp onto the stack

	bra.s	.done

	;
	; Disable caches on 68020/68030.
	;
.68020	lea	.done(pc),a1
	move.w	d0,d1
	andi.w	#$0101,d1
	asl.w	#3,d1
	or.w	d1,d0           ; Flush enabled caches
	dc.w	$4e7b,$0002     ; movec d0,cacr
	moveq.l	#0,d1           ; Disable I/D caches
	dc.w	$4e7b,$1002     ; movec d1,cacr
	nop	                ; Stall pipeline

	;
	; Get the 68030 CPU root pointer register.
	; The crp register is 64-bit. The root pointer is provided
	; in the lowest 32 bits.
	;
	dc.w	$f010,$4e00     ; pmove crp,(a0)

.done
	;
	; Save the original cacr register.
	;
	move.l	d0,CACR(a2)

	;
	; Save the MMU root pointer (used on 68030+) for later
	; verification.
	;
	addq.l	#4,a7
	move.l	(a7)+,RP(a2)

	;
	; Restore exception vectors and SR.
	;
	move.l	(a7)+,$f4.w
	move.l	(a7)+,$2c.w
	move.l	(a7)+,$10.w
	move.w	(a7)+,sr

	; Get the machine type.
	move.w	MCH_TYPE(a2),d0

	;
	; Save the MegaSTe freq/cache config,
	; set up a 8MHz uncached or 16MHz cached MegaSTe CPU.
	;
	; Notes about the MegaSTe cache:
	; - The MegaSTe cache is unified (contains both code and data)
	;   and is therefore totally transparent, in particular to
	;   self-modifying code.
	; - The cache is required to take advantage of the 16MHz freq,
	;   to avoid CPU stalls when accessing memory.
	; - Switching the CPU frequency/cache has immediate effect,
	;   as soon as the corresponding I/O register has been updated.
	;
.mste
	cmpi.b	#MCH_MEGASTE,d0
	bne.s	.falcon
	move.b	$ffff8e21.w,CACHE_MEGASTE(a2)
	ifeq	USE_MEGASTE_16MHZ
	clr.b	$ffff8e21.w     ; 8MHz uncached CPU
	elseif
	move.b	#$ff,$ffff8e21.w ; 16MHz cached CPU
	; Update the machine type with the selected CPU frequency.
	ori.w	#MCH_MSTE_16MHZ,d0
	move.w	d0,MCH_TYPE(a2)
	endc
	bra.s	.ret

	;
	; Save the Falcon bus control,
	; set up 16MHz Falcon CPU and STe bus emulation.
	;
.falcon
	; Use word comparison on purpose, so that the Falcon
	; bus control is not accessed on CT60 (touching this
	; register might hang the CT60).
	cmpi.w	#MCH_FALCON,d0
	bne.s	.ret
	move.b	$ffff8007.w,d1
	move.b	d1,BUS_FALCON(a2)
	bclr	#5,d1           ; STe bus emulation
	bset	#0,d1           ; 16MHz CPU
	move.b	d1,$ffff8007.w

.ret	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; misc_setup()
	;
	; Save and set up misc. peripherals/system config,
	; including conterm & internal speaker.
	;
	; In:
	;   a0: misc_conf
	;
misc_setup
	movem.l	d0-d1/a1,-(a7)

	; Save & disable interrupts.
	move.w	sr,-(a7)
	ori.w	#$700,sr

	; Save and clear conterm.
	move.b	$484.w,CONTERM(a0)
	clr.b	$484.w

	; Switch the internal speaker off.
	lea	$ffff8800.w,a1
	move.b	#14,(a1)        ; select Port A register
	move.b	(a1),d0         ; get current value
	move.b	d0,d1
	andi.b	#$40,d1         ; keep int. speaker bit
	move.b	d1,SPEAKER(a0)  ; and save it
	bset	#6,d0           ; internal speaker off
	move.b	d0,2(a1)        ; write new value

	; Restore interrupts.
	move.w	(a7)+,sr

	; Hide mouse.
	bsr	linea_hidemouse

	movem.l	(a7)+,d0-d1/a1
	rts

	;
	; screen_save()
	;
	; Save screen state: video base, resolution, palette...
	;
	; In:
	;   a0: screen_conf
	;
screen_save
	movem.l	d0-d7/a0-a4,-(a7)
	movea.l	a0,a4

	; Save physical start address of the video memory.
	move.w	#2,-(a7)
	trap	#14
	addq.l	#2,a7
	move.l	d0,PHYSBASE(a4)

	; Save logical start address of the video memory.
	move.w	#3,-(a7)
	trap	#14
	addq.l	#2,a7
	move.l	d0,LOGBASE(a4)

	; ST Shifter or Falcon VIDEL video chip?
	move.w	MCH_TYPE-CPU2SCREEN(a4),d4
	cmpi.b	#MCH_FALCON,d4
	bne.s	.st

	;
	; Save Falcon screen resolution & VIDEL state.
	;
	; On Falcon, the VIDEL state is saved in addition to the
	; TOS state (screen resolution & video mode) in order to
	; insure the video state can be restored completely and
	; safely. Indeed, on Falcon machines, the TOS is known
	; to have a weak VIDEL support.
	;
.falcon
	; Get current video mode.
	move.w	#-1,-(a7)
	move.w	#88,-(a7)
	trap	#14
	addq.l	#4,a7

	; Save current screen resolution in the VSetscreen
	; format (rez=3 / Falcon modecode).
	move.w	#3,REZ(a4)
	move.w	d0,VIDEOMODE(a4)

	; Determine current screen size and check if it is
	; compatible with ST low rez (size must be >= $7d00).
	move.w	d0,-(a7)
	move.w	#91,-(a7)
	trap	#14
	addq.l	#4,a7
	cmpi.l	#$7d00,d0
	slo	REZ_INVALID(a4)
	blo.s	.s_videl

	; Check if a monochrome monitor is used.
	move.w	#89,-(a7)
	trap	#14
	addq.l	#2,a7
	tst.b	d0
	seq	REZ_INVALID(a4)

.s_videl
	; Save the VIDEL state.
	lea	VIDEL(a4),a0
	bsr	videl_save

	; Save the Falcon palette.
	move.w	#255,d0
	lea	$ffff9800.w,a0
	lea	FA_PALETTE(a4),a1
.cp_pal	move.l	(a0)+,(a1)+
	dbf	d0,.cp_pal

	bra.s	.st_pal

	;
	; Save ST screen resolution (ST/STe/MegaSTe/TT).
	;
.st
	; Get current screen resolution.
	move.w	#4,-(a7)
	trap	#14
	addq.l	#2,a7

	; Save current screen resolution in the VSetscreen
	; format (ST rez / dummy modecode).
	move.w	d0,REZ(a4)
	clr.w	VIDEOMODE(a4)

	; Check if a monochrome monitor is used.
	cmpi.b	#6,d0           ; TT mono
	seq	REZ_INVALID(a4)
	beq.s	.sync
	cmpi.b	#MCH_TT,d4
	beq.s	.sync
	cmpi.b	#2,d0           ; ST mono
	seq	REZ_INVALID(a4)

.sync
	; Save also the current video sync mode.
	move.b	$ffff820a.w,REG_SYNC(a4)

.st_pal
	; Save the ST palette.
	movem.l	$ffff8240.w,d0-d7
	movem.l	d0-d7,ST_PALETTE(a4)

.ret	movem.l	(a7)+,d0-d7/a0-a4
	rts

	;
	; screen_setup()
	;
	; Set up a ST-compatible low resolution.
	;
	; In:
	;   a0: screen_conf
	;
screen_setup
	movem.l	d0-d1/d7/a0-a1,-(a7)
	movea.l	a0,a1

	; Clear the screen.
	bsr	vsync_sup
	lea	cls(pc),a0
	bsr	print

	; ST Shifter or Falcon VIDEL video chip?
	move.w	MCH_TYPE-CPU2SCREEN(a1),d7
	cmpi.b	#MCH_FALCON,d7
	bne.s	.st

	;
	; Falcon ST-compatible low rez setup.
	;
	; On Falcon, the VIDEL state is set up after configuring
	; the low resolution via the TOS. The TOS setup allows
	; TOS-based games to run correctly in low resolution,
	; while the additional VIDEL setup provides finer video
	; settings. In particular it provides a more stable HBL
	; support (useful for rasters).
	; 
.falcon
	; Compute ST-compatible low rez param in the
	; VSetscreen format (rez=3 / ST-compat low rez modecode).
	moveq.l	#3,d0           ; rez=3 -> use modecode
	swap	d0
	move.w	VIDEOMODE(a1),d0
	andi.w	#$30,d0         ; keep VGA/RGB + PAL/NTSC
	ori.w	#$82,d0         ; set ST-compat low rez
	move.l	d0,LOWREZ_V(a1)

	; Request the TOS to set up a ST-compatible low rez.
	movea.l	a1,a0
	bsr.s	VSetscreen      ; Provides a vsync

	; Re-configure the VIDEL to ST-compat low resolution.
	bsr	videl_setup

	; Wait for the update of the screen configuration
	; to take effect.
	bsr	vsync_sup

	bra.s	.st_pal

	;
	; Legacy ST low rez setup (ST/STe/MegaSTe/TT).
	;
.st
	; Compute ST/STe/MegaSTe/TT low rez param in the
	; VSetscreen format (ST low rez / dummy modecode).
	moveq.l	#0,d0
	move.l	d0,LOWREZ_V(a1)

	; Request the TOS to switch to low resolution.
	movea.l	a1,a0
	bsr.s	VSetscreen      ; Provides a vsync

	; Do not configure the video sync mode on TT since it does
	; not behave as on ST. Just update the machine type to
	; indicate that the TT video frame rate is 60Hz.
	cmpi.b	#MCH_TT,d7
	bne.s	.st_freq
	ori.w	#MCH_VIDEO_60HZ,d7
	bra.s	.st_pal

	; Legacy ST(e) family: Set 50Hz or 60Hz, internal sync.
.st_freq
	ifeq	USE_ST_60HZ
	move.b	#2,$ffff820a.w  ; 50Hz
	elseif
	move.b	#0,$ffff820a.w  ; 60Hz
	; Update the machine type to indicate that the video
	; frame rate is 60Hz.
	ori.w	#MCH_VIDEO_60HZ,d7
	endc	

.st_pal
	; Set all 16 colors to the current background color.
	lea	$ffff8240.w,a0
	move.w	(a0)+,d0
	moveq.l	#14,d1
.lp	move.w	d0,(a0)+
	dbf	d1,.lp

	bsr	vsync_sup

	; Save the updated machine type.
	move.w	d7,MCH_TYPE-CPU2SCREEN(a1)

	movem.l	(a7)+,d0-d1/d7/a0-a1
	rts

	;
	; VSetscreen()
	;
	; Common ST/Falcon VSetscreen trap invocation.
	;
	; In:
	;   d0: resolution parameter in the VSetscreen format,
	;       that is the resolution in the high 16 bits
	;       and the modecode in the low 16 bits.
	;   a0: screen_conf
	;
VSetscreen
	movem.l	d0-d2/a0-a2,-(a7)

	; The TOS waits for the start of the vblank before
	; updating the video controller.
	move.l	d0,-(a7)
	move.l	PHYSBASE(a0),-(a7)
	move.l	LOGBASE(a0),-(a7)
	move.w	#5,-(a7)
	trap	#14
	lea	14(a7),a7

	; Wait for the update of the screen configuration
	; to take effect.
	bsr	vsync_sup

	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; videl_save()
	;
	; Save the VIDEL state.
	;
	; Code ripped from the DHS synclock demosystem.
	;
	; ST-mode is detected by checking the HTT value.
	; Allowed values for the HTT register and other Videl
	; registers are listed in the "Video System Standard
	; Values" tables in the Videl guide from Aura and
	; Animal Mine.
	;
	; In:
	;   a0: screen_conf.sc_videl
	;
	; Scratch: a0
	;
videl_save
	move.w	sr,-(a7)
	move.w	#$2700,sr

	move.l	$ffff8200.w,(a0)+   ; Video base high/med
	move.w	$ffff820c.w,(a0)+   ; Video base low
	move.l	$ffff8282.w,(a0)+   ; H-regs
	move.l	$ffff8286.w,(a0)+   ; 
	move.l	$ffff828a.w,(a0)+   ; 
	move.l	$ffff82a2.w,(a0)+   ; V-regs
	move.l	$ffff82a6.w,(a0)+   ; 
	move.l	$ffff82aa.w,(a0)+   ; 
	move.w	$ffff82c0.w,(a0)+   ; Video control
	move.w	$ffff82c2.w,(a0)+   ; Video mode
	move.l	$ffff820e.w,(a0)+   ; Line offset/width
	move.w	$ffff820a.w,(a0)+   ; Video sync mode
	move.b	$ffff8265.w,(a0)+   ; Horizontal scroll
	clr.b 	(a0)                ; Clear ST flag
	cmpi.w	#$b0,$ffff8282.w    ; ST mode (HHT <= $b0)?
	sle	(a0)+               ; Yes, set ST flag
	move.w	$ffff8266.w,(a0)+   ; Falcon shift mode
	move.w	$ffff8260.w,(a0)+   ; ST shift mode

	move.w	(a7)+,sr
	rts

	;
	; videl_restore()
	;
	; Restore the VIDEL state.
	;
	; Code ripped from the DHS synclock demosystem and
	; slightly adapted.
	;
	; In:
	;   a0: screen_conf.sc_videl
	;
	; Scratch: a0
	;
videl_restore
	move.w	sr,-(a7)
	move.w	#$2700,sr

	clr.w	$ffff8266.w
	move.l	(a0)+,$ffff8200.w
	move.w	(a0)+,$ffff820c.w
	move.l	(a0)+,$ffff8282.w
	move.l	(a0)+,$ffff8286.w
	move.l	(a0)+,$ffff828a.w
	move.l	(a0)+,$ffff82a2.w
	move.l	(a0)+,$ffff82a6.w
	move.l	(a0)+,$ffff82aa.w
	move.w	(a0)+,$ffff82c0.w
	move.w	(a0)+,$ffff82c2.w
	move.l	(a0)+,$ffff820e.w
	move.w	(a0)+,$ffff820a.w
	move.b	(a0)+,$ffff8265.w
	;
	; Restore a Falcon or ST mode?
	;
	tst.b	(a0)+
	bne.s	.st
	;
	; Enable the Falcon shifter mode.
	;
	move.w	(a0),$ffff8266.w
	bra.s	.ret
.st	;
	; Writing to $ff8260 enables the ST shifter mode and,
	; as a side effect, makes the VIDEL update $ff82c2
	; and $ff8210. Those 2 registers are thus written again
	; with the expected values, to be safe.
	;
	move.w	(REG_ST_SHIFT-REG_FALC_SHIFT)(a0),$ffff8260.w
	move.w	(REG_VID_MODE-REG_FALC_SHIFT)(a0),$ffff82c2.w
	move.w	(REG_LINE_WIDTH-REG_FALC_SHIFT)(a0),$ffff8210.w

.ret	move.w	(a7)+,sr
	rts

	;
	; videl_setup()
	;
	; Configure the VIDEL to ST-compat low resolution,
	; taking into account the type of monitor: use either
	; the "50Hz RGB" config from Leonard or the "60Hz VGA"
	; config from ULS.
	;
	; There is also the "50Hz VGA" config from Leonard but
	; it is not used because only few VGA monitors support
	; such low refresh rate.
	; "60Hz VGA" is used instead, although the frame rate
	; is 20% too high for VBL-based animations and musics.
	; As a consequence, the game must be patched to cope with
	; this unexpectedly high frame rate.
	;
	; In:
	;   d7: machine type
	;
	; Out:
	;   d7: the machine type is ORed with MCH_VIDEO_60HZ if
	;       the video frame rate has been configured to 60Hz
	;
videl_setup
	move.l	d0,-(a7)
	move.w	sr,-(a7)
	move.w	#$2700,sr

	;
	; Determine the type of monitor:
	; 0. Monochrome
	; 1. RGB Color
	; 2. VGA Color
	; 3. TV Color
	;
	move.b	$ffff8006.w,d0
	lsr.b	#6,d0

	;
	; Perform VIDEL setup accordingly.
	;
	cmpi.b	#1,d0           ; RGB
	beq.s	.set_rgb
	cmpi.b	#3,d0           ; TV
	beq.s	.set_rgb

	;
	; Configure Falcon VIDEL registers.
	;

.set_vga
	ifne	USE_VGA_60HZ

	; Falcon VIDEL 60Hz VGA configuration.
	; These values come from ULS 3.12j.
.set_vga60
	move.l	#$170012,$ffff8282.w
	move.l	#$1020e,$ffff8286.w
	move.l	#$d0012,$ffff828a.w
	move.l	#$41903ff,$ffff82a2.w
	move.l	#$3f008d,$ffff82a6.w
	move.l	#$3ad0415,$ffff82aa.w
	move.w	#$186,$ffff82c0.w
	clr.w	$ffff820e.w
	;
	; $ff820a (video sync mode) has a different purpose
	; on Falcon: #$200 selects internal synchro and color
	; monitor.
	;
	move.w	#$200,$ffff820a.w	
	;
	; According to the Falcon doc by Aura & Animal Mine,
	; the following sequence shall be used to set up
	; ST-compatible modes:
	; - First clear $ff8266.
	; - Write to $ff8260 to select the ST shifter mode.
	;   As a side effect, this makes the VIDEL update
	;   $ff82c2 and $ff8210.
	; - Update $ff82c2 and $ff8210 again with the correct
	;   values.
	;
	clr.w	$ffff8266.w
	clr.b	$ffff8260.w
	move.w	#$5,$ffff82c2.w
	move.w	#$50,$ffff8210.w

	; Update the machine type to indicate that the video
	; frame rate is 60Hz.
	ori.w	#MCH_VIDEO_60HZ,d7

	elseif

	; Falcon VIDEL 50Hz VGA configuration.
	; These values come from Leonard's Multi Atari Boot code.
.set_vga50
	move.l	#$170011,$ffff8282.w
	move.l	#$2020E,$ffff8286.w
	move.l	#$D0012,$ffff828a.w
	move.l	#$4EB04D1,$ffff82a2.w
	move.l	#$3F00F5,$ffff82a6.w
	move.l	#$41504E7,$ffff82aa.w
	move.w	#$186,$ffff82c0.w
	clr.w	$ffff820e.w
	move.w	#$200,$ffff820a.w
	clr.w	$ffff8266.w
	clr.b	$ffff8260.w
	move.w	#$5,$ffff82c2.w
	move.w	#$50,$ffff8210.w

	endc

	bra.s	.ret

.set_rgb
	; Falcon VIDEL 50Hz RGB configuration.
	; These values come from Leonard's Multi Atari Boot code.
.set_rgb50
	move.l	#$300027,$ffff8282.w
	move.l	#$70229,$ffff8286.w
	move.l	#$1e002a,$ffff828a.w
	move.l	#$2710265,$ffff82a2.w
	move.l	#$2f0081,$ffff82a6.w
	move.l	#$211026b,$ffff82aa.w
	move.w	#$185,$ffff82c0.w
	clr.w	$ffff820e.w
	move.w	#$200,$ffff820a.w
	clr.w	$ffff8266.w
	clr.b	$ffff8260.w
	clr.w	$ffff82c2.w
	move.w	#$50,$ffff8210.w

.ret	move.w	(a7)+,sr
	move.l	(a7)+,d0
	rts

	;
	; mach_restore()
	;
	; Restore machine state: CPU caches & freq, bus config,
	; screen, palette...
	;
	; Called from supexec.
	;
	; Out:
	;   d0: return value
	;
	; Scratch: a0-a1
	;
mach_restore
	lea	mach_conf(pc),a1

	; Check if machine configuration has been saved.
	tst.w	CONF_DONE(a1)
	beq.s	.ret

	; Restore CPU state.
	lea	MACH2CPU(a1),a0
	bsr.s	cpu_restore

	; Restore screen config if needed.
	lea	MACH2SCREEN(a1),a0
	tst.w	REZ_INVALID(a0)
	bne.s	.misc
	bsr	screen_restore

	; Restore misc. peripherals/system config.
.misc	lea	MACH2MISC(a1),a0
	bsr	misc_restore

	; Reset saved machine config status.
.done	clr.w	CONF_DONE(a1)

.ret	moveq.l	#0,d0
	rts

	;
	; cpu_restore()
	;
	; Restore CPU state: caches & freq, bus config.
	;
	; In:
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
	ori.w	#$700,sr

	;
	; Save exception vectors that will be modified.
	;
	move.l	$10.w,-(a7)     ; Illegal
	move.l	$2c.w,-(a7)     ; Line F
	move.l	$f4.w,-(a7)     ; Unimp Int Instr

	;
	; Install our own handlers to catch exceptions triggered
	; by unsupported cache maintenance instructions.
	;
	lea	cache_except(pc),a1
	move.l	a1,$10.w
	move.l	a1,$2c.w
	move.l	a1,$f4.w
	nop	                ; Flush write pipeline

	movea.l	a7,a0           ; Save SP
	move.l	CACR(a2),d0     ; Original cacr

	;
	; Invalidate instr/data/branch/ATC caches on 68040/68060.
	;
.68040	lea	.68020(pc),a1
	nop	                ; Stall pipeline
	dc.w	$f4d8           ; cinva bc
	dc.w	$f518           ; pflusha
	nop	                ; Stall pipeline

	;
	; Restore original cacr value on 68020+ CPUs.
	;
.68020	lea	.done(pc),a1
	dc.w	$4e7b,$0002     ; movec d0,cacr
	nop	                ; Stall pipeline

	;
	; Restore exception vectors and SR.
	;
.done	move.l	(a7)+,$f4.w
	move.l	(a7)+,$2c.w
	move.l	(a7)+,$10.w
	move.w	(a7)+,sr

	; Get machine type.
	move.w	MCH_TYPE(a2),d0

	;
	; Restore MegaSTe cache/freq.
	;
.mste
	cmpi.b	#MCH_MEGASTE,d0
	bne.s	.falcon
	move.b	CACHE_MEGASTE(a2),$ffff8e21.w
	bra.s	.ret

	;
	; Restore Falcon bus control.
	;
.falcon
	; Use word comparison to skip this on CT60.
	cmpi.w	#MCH_FALCON,d0
	bne.s	.ret
	move.b	BUS_FALCON(a2),$ffff8007.w

.ret	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; cache_except()
	;
	; Catch exceptions triggered by unsupported
	; cache maintenance instructions.
	; Restore SP and resume execution at the address
	; specified in a1.
	;
	; In:
	;   a0: saved SP
	;   a1: return address
	;
cache_except
	movea.l	a0,a7
	jmp	(a1)

	;
	; misc_restore()
	;
	; Restore misc. peripherals/system config,
	; including conterm & internal speaker.
	;
	; In:
	;   a0: misc_conf
	;
misc_restore
	movem.l	d0/a1,-(a7)

	; Save & disable interrupts.
	move.w	sr,-(a7)
	ori.w	#$700,sr

	; Restore conterm.
	move.b	CONTERM(a0),$484.w

	; Restore internal speaker state.
	lea	$ffff8800.w,a1
	move.b	#14,(a1)        ; select Port A register
	move.b	(a1),d0         ; get current value
	bclr	#6,d0           ; clear internal speaker bit
	or.b	SPEAKER(a0),d0  ; set original/saved bit value
	move.b	d0,2(a1)        ; write new value

	; Restore interrupts.
	move.w	(a7)+,sr

	; Show mouse.
	bsr	linea_showmouse

	movem.l	(a7)+,d0/a1
	rts

	;
	; screen_restore()
	;
	; Restore screen state: resolution, palette.
	;
	; In:
	;   a0: screen_conf
	;
screen_restore
	movem.l	d0-d7/a0-a2,-(a7)
	movea.l	a0,a2

	; Clear the screen.
	bsr	vsync_sup
	lea	cls(pc),a0
	bsr	print

	; Request the TOS to restore the screen config.
	move.l	REZ_V(a2),d0
	movea.l	a2,a0
	bsr	VSetscreen      ; Provides a vsync

	; ST Shifter or Falcon VIDEL video chip?
	move.w	MCH_TYPE-CPU2SCREEN(a2),d1
	cmpi.b	#MCH_FALCON,d1
	bne.s	.st

.falcon
	; On Falcon, restore the VIDEL state.
	lea	VIDEL(a2),a0
	bsr	videl_restore

	; Restore also the Falcon palette.
	move.w	#255,d0
	lea	FA_PALETTE(a2),a0
	lea	$ffff9800.w,a1
.cp_pal	move.l	(a0)+,(a1)+
	dbf	d0,.cp_pal

	bra.s	.st_pal

.st
	; On ST(e)/MegaSTe/TT, restore the video sync mode.
	move.b	REG_SYNC(a2),$ffff820a.w

.st_pal
	; Restore the ST palette.
	movem.l	ST_PALETTE(a2),d0-d7
	movem.l	d0-d7,$ffff8240.w

	; Wait for the update of the screen configuration
	; to take effect.
	bsr	vsync_sup

	movem.l	(a7)+,d0-d7/a0-a2
	rts

	;
	; Print debugging (HW) information.
	;

	ifne	DEBUG_REGS

	;
	; dump_regs()
	;
dump_regs
	movem.l	d0/a0-a1,-(a7)

	; Read all chars available in the input buffer.
	bsr	flush_input_buffer

	; Set low rez colors to black.
	bsr	vsync
	lea	cols_black(pc),a0
	bsr	supexec

	; Clear screen.
	lea	cls(pc),a0
	bsr	print

	; Get the machine type.
	lea	mach_conf(pc),a1

	; Print the debugging screen title.
	lea	dbg_title(pc),a0
	bsr	print

	; Print the debug version.
	lea	dbg_version(pc),a0
	moveq.l	#DEBUG_VER,d0
	bsr	print_reg

	; Print the machine type.
	lea	dbg_mch(pc),a0
	moveq.l	#0,d0
	move.w	MACH2CPU+MCH_TYPE(a1),d0
	bsr	print_reg

	; Print the TOS version number.
	lea	get_tos_ver(pc),a0
	bsr	supexec
	lea	dbg_tos(pc),a0
	bsr	print_reg

	; Print the end of the TPA.
	XADDR	get_tpa_end,a0
	bsr	supexec
	lea	dbg_tpa(pc),a0
	bsr	print_reg

	; Print the physical start address of the video memory.
	lea	dbg_pbase(pc),a0
	move.l	MACH2SCREEN+PHYSBASE(a1),d0
	bsr	print_reg

	; Print the logical start address of the video memory.
	lea	dbg_lbase(pc),a0
	move.l	MACH2SCREEN+LOGBASE(a1),d0
	bsr	print_reg

	; Print the ST/Falcon initial resolution in the
	; VSetscreen format: rez / mode.
	lea	dbg_rez(pc),a0
	move.l	MACH2SCREEN+REZ_V(a1),d0
	bsr	print_reg

	; Print the start address of the program.
	lea	loader_part1_base(pc),a0
	move.l	a0,d0
	lea	dbg_pstart(pc),a0
	bsr	print_reg

	; Print the end address of the program.
	lea	pt_end(pc),a0
	move.l	a0,d0
	lea	dbg_pend(pc),a0
	bsr	print_reg

	; Print the user stack pointer register.
	lea	get_usp(pc),a0
	bsr	supexec
	lea	dbg_usp(pc),a0
	bsr	print_reg

	; Print the supervisor stack pointer register.
	lea	get_ssp(pc),a0
	bsr	supexec
	lea	dbg_ssp(pc),a0
	bsr	print_reg

	; Print the cacr (cache control) register.
	lea	dbg_cacr(pc),a0
	move.l	MACH2CPU+CACR(a1),d0
	bsr	print_reg

	; Print the MegaSte cache control register.
	move.w	MACH2CPU+MCH_TYPE(a1),d0
	cmpi.b	#MCH_MEGASTE,d0
	bne.s	.falcon
	moveq.l	#0,d0
	move.b	MACH2CPU+CACHE_MEGASTE(a1),d0
	lea	dbg_mste(pc),a0
	bsr	print_reg

	; Print the Falcon bus control register (skipped on CT60).
.falcon	move.w	MACH2CPU+MCH_TYPE(a1),d0
	cmpi.w	#MCH_FALCON,d0
	bne.s	.rp
	moveq.l	#0,d0
	move.b	MACH2CPU+BUS_FALCON(a1),d0
	lea	dbg_falcon(pc),a0
	bsr	print_reg

	; Print the MMU root pointer (crp or urp).
.rp	lea	dbg_rp(pc),a0
	move.l	MACH2CPU+RP(a1),d0
	bsr.s	print_reg

	; Print the current drive number.
	lea	dbg_drv(pc),a0
	bsr	getdrv
	bsr.s	print_reg

	; Print the FDC/DMA calibrated loop counter.
	XADDR	calibrate_delay,a0
	bsr	supexec
	XADDR	dma_delay,a0
	move.l	(a0),d0
	lea	dbg_calib(pc),a0
	bsr.s	print_reg

	; Print the "wait for space key" message.
	lea	dbg_key(pc),a0
	bsr	print

	; Show the text in white.
	bsr	vsync
	lea	dbg_col_on(pc),a0
	bsr	supexec

	; Wait for the space key.
.key	bsr	readchar
	swap	d0
	cmpi.b	#$39,d0
	bne.s	.key

	; Hide the text.
	bsr	vsync
	lea	dbg_col_off(pc),a0
	bsr	supexec

	; Clear the screen.
	lea	cls(pc),a0
	bsr	print

	movem.l	(a7)+,d0/a0-a1
	rts

	; Set the text color to white.
dbg_col_on
	move.w	#$777,$ffff825e.w
	rts

	; Set the text color to black.
dbg_col_off
	clr.w	$ffff825e.w
	rts

	; Get the TOS version number.
get_tos_ver
	movea.l	$4f2.w,a0
	moveq.l	#0,d0
	move.w	2(a0),d0
	rts

	; Get the user stack pointer register.
get_usp
	move	USP,a0
	move.l	a0,d0
	rts

	; Get the supervisor stack pointer register.
get_ssp
	move.l	sp,d0
	rts

	;
	; print_reg()
	;
	; Print a 32-bit value and its caption.
	;
	; In:
	;   d0: 32-bit value to be printed
	;   a0: corresponding caption
	;
print_reg
	movem.l	a0-a1,-(a7)

	; Current position of the text on the screen.
	lea	dbg_pos(pc),a1

	; Set the text position of the caption.
	exg.l	a1,a0
	move.b	#32+0,3(a0)
	bsr	print

	; Print the caption.
	exg.l	a1,a0
	bsr	print

	; Set the text position of the 32-bit value.
	exg.l	a1,a0
	move.b	#32+20,3(a0)
	bsr	print
	addq.b	#1,2(a0)

	; Print the 32-bit value.
	bsr.s	print_reg_val

	movem.l	(a7)+,a0-a1
	rts

	;
	; print_reg_val()
	;
	; Print a 32-bit value.
	;
	; In:
	;   d0: 32-bit value to be printed
	;
print_reg_val
	movem.l	d0-d2/a0-a1,-(a7)

	; Convert the 32-bit value to a printable string.
	lea	reg_val(pc),a0
	lea	1(a0),a1
	moveq.l	#7,d1

.next	rol.l	#4,d0
	move.b	d0,d2
	andi.b	#$f,d2
	cmpi.b	#$9,d2
	bls.s	.num
	addq.b	#'A'-'0'-$a,d2
.num	addi.b	#'0',d2
	move.b	d2,(a1)+
	dbf	d1,.next

	; Print the resulting string.
	bsr	print

	movem.l	(a7)+,d0-d2/a0-a1
	rts

	endc	; DEBUG_REGS

	;
	; Saved machine state and debug strings are placed
	; in the data section.
	;
	section data

	; Saved machine config.
	; [mach_conf - mach_conf_end]
mach_conf
	; Machine config has been set up.
mach_conf_done
	dc.w	0

CONF_DONE       =	(mach_conf_done-mach_conf)

	; Saved CPU configuration.
	; [cpu_conf - cpu_conf_end]
cpu_conf
	; Machine type (ST/STe/MegaSTe/TT/Falcon).
cc_mch_type
	ds.w	1
	; cacr register.
cc_cacr
	ds.l	1
	; MMU root pointer register (urp or crp).
cc_rp
	ds.l	1
	; MegaSTe CPU freq/cache ($ffff8e21).
cc_cache_mste
	ds.w	1
	; Falcon bus control ($ffff8007).
cc_bus_falcon
	ds.w	1
cpu_conf_end

MCH_TYPE        =	(cc_mch_type-cpu_conf)
CACR            =	(cc_cacr-cpu_conf)
RP              =	(cc_rp-cpu_conf)
CACHE_MEGASTE   =	(cc_cache_mste-cpu_conf)
BUS_FALCON      =	(cc_bus_falcon-cpu_conf)

	; Saved screen config.
	; [screen_conf - screen_conf_end]
screen_conf
	; ST/Falcon initial rez param (VSetscreen fmt: rez / mode).
sc_rez_v
	; Initial screen resolution.
sc_rez
	ds.w	1
	; Initial video mode.
sc_videomode
	ds.w	1
	; Set if resolution is invalid.
sc_rez_invalid
	ds.w	1
	; ST/Falcon low rez param (VSetscreen format: rez / mode).
sc_lowrez_v
	ds.l	1
	; Physical start address of the video memory.
sc_physbase
	ds.l	1
	; Logical start address of the video memory.
sc_logbase
	ds.l	1
	; Initial ST palette.
sc_st_palette
	ds.w	16
	; Initial Falcon palette.
sc_fa_palette
	ds.l	256
	; Initial ST shifter state.
sc_shifter
	; Initial Falcon VIDEL state.
sc_videl
	ds.b	46
screen_conf_end

REZ_V           =	(sc_rez_v-screen_conf)
REZ             =	(sc_rez-screen_conf)
VIDEOMODE       =	(sc_videomode-screen_conf)
REZ_INVALID     =	(sc_rez_invalid-screen_conf)
LOWREZ_V        =	(sc_lowrez_v-screen_conf)
PHYSBASE        =	(sc_physbase-screen_conf)
LOGBASE         =	(sc_logbase-screen_conf)
ST_PALETTE      =	(sc_st_palette-screen_conf)
FA_PALETTE      =	(sc_fa_palette-screen_conf)
VIDEL           =	(sc_videl-screen_conf)
SHIFTER         =	(sc_shifter-screen_conf)

	; Video registers offsets.
REG_VID_HM      =	(VIDEL+0)
REG_VID_L       =	(VIDEL+4)
REGS_H          =	(VIDEL+6)
REGS_V          =	(VIDEL+18)
REG_VCO         =	(VIDEL+30)
REG_VID_MODE    =	(VIDEL+32)
REG_LINE_OFF    =	(VIDEL+34)
REG_LINE_WIDTH  =	(VIDEL+36)
REG_SYNC        =	(VIDEL+38)
REG_HSCROLL     =	(VIDEL+40)
REG_ST_FLAG     =	(VIDEL+41)
REG_FALC_SHIFT  =	(VIDEL+42)
REG_ST_SHIFT    =	(VIDEL+44)

	; Saved misc. config.
	; [misc_conf - misc_conf_end]
misc_conf
	; Console output config (conterm).
mc_conterm
	ds.w	1
	; Internal speaker on/off (PSG Port A register).
mc_speaker
	ds.w	1
misc_conf_end

CONTERM         =	(mc_conterm-misc_conf)
SPEAKER         =	(mc_speaker-misc_conf)

mach_conf_end

MACH2CPU        =	(cpu_conf-mach_conf)
MACH2SCREEN     =	(screen_conf-mach_conf)
MACH2MISC       =	(misc_conf-mach_conf)
CPU2SCREEN      =	(screen_conf-cpu_conf)

	; Clear screen + cursor off.
cls
	dc.b	27,"E",27,"f",0
	even

	;
	; Debug messages.
	;
	ifne	DEBUG_REGS
reg_val
	dc.b	"$00000000",0
	even
dbg_pos
	dc.b	27,"Y",34,32,0
	even
dbg_title
	dc.b	"DEBUG INFORMATION",0
	even
dbg_key
	dc.b	10,13,10,13,"PRESS SPACE TO CONTINUE",0
	even
dbg_version
	dc.b	"DEBUG VERSION",0
	even
dbg_mch
	dc.b	"MACHINE",0
	even
dbg_tos
	dc.b	"TOS VERSION",0
	even
dbg_tpa
	dc.b	"TPA END",0
	even
dbg_pbase
	dc.b	"PHYSICAL BASE",0
	even
dbg_lbase
	dc.b	"LOGICAL BASE",0
	even
dbg_rez
	dc.b	"RESOLUTION",0
	even
dbg_pstart
	dc.b	"PROG START",0
	even
dbg_pend
	dc.b	"PROG END",0
	even
dbg_usp
	dc.b	"USER SP",0
	even
dbg_ssp
	dc.b	"SUPERVISOR SP",0
	even
dbg_cacr
	dc.b	"CACR",0
	even
dbg_mste
	dc.b	"MEGASTE CACHE CTRL",0
	even
dbg_falcon
	dc.b	"FALCON BUS CTRL",0
	even
dbg_rp
	dc.b	"MMU ROOT POINTER",0
	even
dbg_drv
	dc.b	"CURRENT DRIVE",0
	even
dbg_calib
	dc.b	"CALIBRATION LOOP",0
	even

	endc	; DEBUG_REGS

	; Reset section to text.
	section	text

***************************************************************************
*
* 5. External cracktros loading and "ghosts" animation
*
* Public routines:
* - extintro_pre()
* - extintro_post()
* - load_anim_start()
* - load_anim_stop()
*
***************************************************************************

	;
	; extintro_pre()
	;
	; Routine executed right before the external cracktros.
	; - Fade all colors to black.
	; - Replace the GEM critical error handler.
	;   If the TOS detects a disk error while loading an external
	;   cracktro, the handler below forces the TOS to retry the
	;   failing operation once and if the error continues it
	;   forces the TOS to abort that operation.
	;   This automatic behavior is preferable to the behavior of
	;   the default handler which displays a dialog box that
	;   cannot be used because all colors are black and the
	;   keyboard is disabled during loading.
	;
	; Called from supexec.
	;
	; Out:
	;   d0: return value
	;
	; Scratch: a0-a1
	;
extintro_pre
	lea	$ffff8240.w,a0
	lea	black_pal(pc),a1
	bsr	fade_palette_simple

	lea	gem_crit_err_vec(pc),a0
	move.l	$404.w,(a0)
	lea	gem_crit_error_retry(pc),a0
	move.l	a0,$404.w

	moveq.l	#0,d0
	rts

	;
	; extintro_post()
	;
	; Routine executed right after each external cracktro.
	; Restore screen phys/log base addresses, clear the
	; screen, set all colors to black again and restore the
	; original GEM critical error handler.
	;
	; Called from supexec.
	;
	; Out:
	;   d0: return value
	;
	; Scratch: a0
	;
extintro_post
	bsr	vsync_sup
	bsr	cols_black

	lea	mach_conf+MACH2SCREEN(pc),a0
	moveq.l	#-1,d0
	bsr	VSetscreen

	lea	cls(pc),a0
	bsr	print

	move.l	gem_crit_err_vec(pc),$404.w

	moveq.l	#0,d0
	rts

	;
	; load_anim_start()
	;
	; Start the "ghosts" animation which is played while loading
	; the second external cracktro (aka the hidden cracktro).
	;
	; Called from supexec.
	;
	; Out:
	;   d0: return value
	;
	; Scratch: a0-a2
	;
load_anim_start
	ifne	USE_LOAD_ANIM

	; Prepare the color fade of the "ghosts" halo.

	; Pre-calculated fade-in data.
	lea 	DOMGhostPalette_low(pc),a0
	lea	DOMGhostPalette_high(pc),a1
	lea	fadein_desc(pc),a2
	move.w	#FADEIN_HALO_FACTOR,d0
	bsr 	precalc_fade

	; Pre-calculated fade-out data.
	lea 	DOMGhostPalette_high(pc),a0
	lea	DOMGhostPalette_low(pc),a1
	lea	fadeout_desc(pc),a2
	move.w	#FADEOUT_HALO_FACTOR,d0
	bsr 	precalc_fade

	endc

	; Disable mouse.
	moveq.l	#$12,d0
	bsr	send_ikbd

	; Disable joystick.
	moveq.l	#$15,d0
	bsr	send_ikbd

	; Wait for pending IKBD events to be consumed.
	bsr	wait_ikbd

	ifeq	DEBUG_LOAD_ANIM
	; Pause IKBD transfers.
	moveq.l	#$13,d0
	bsr	send_ikbd
	; Wait for pending IKBD events to be consumed.
	bsr	wait_ikbd
	endc

	move.w	#$2700,sr

	; Save used vectors.
	lea	load_anim_vecs_saved(pc),a0
	move.l	$70.w,(a0)+     ; VBL
	move.l	$120.w,(a0)+    ; Timer B (HBL)
	move.l	$90.w,(a0)+     ; Saved VBL
	move.l	$94.w,(a0)+     ; Saved timer B (HBL)
	move.l	$98.w,(a0)+     ; Animation routine
	move.l	$9c.w,(a0)+     ; Saved _hz_200
	move.l	$a0.w,(a0)+     ; "Ghosts" palette
	move.l	$a4.w,(a0)+     ; Fade/shell handshake

	clr.b	$fffffa1b.w     ; Stop timer B
	bset.b	#0,$fffffa13.w
	bset.b	#0,$fffffa07.w  ; Enable timer B channel

	; Original VBL and HBL handlers are saved in $90 and $94
	; respectively so that the hidden cracktro can restore
	; them on exit (and thus stop the animation).
	move.l	$70.w,$90.w
	move.l	$120.w,$94.w

	; Install the VBL handler.
	lea	vbl_shell(pc),a0
	move.l	a0,$70.w

	; Install the VBL routine of the loading animation.
	; This routine is called by the VBL handler.
	ifne	USE_LOAD_ANIM
	lea	load_anim_vbl(pc),a0
	elseif
	lea	load_anim_vbl_dummy(pc),a0
	endc
	move.l	a0,$98.w

	; Save the current value of _hz_200 when the animation
	; is started.
	move.l	$4ba.w,$9c.w

	; Save the address of the "ghosts" palette in $a0 so that
	; the hidden cracktro can update it (for the fade-out).
	ifne	USE_LOAD_ANIM
	lea	DOMGhostPalette(pc),a0
	elseif
	lea	$ffff8240.w,a0  ; No palette update in HBL
	endc
	move.l	a0,$a0.w

	; $a4 provides a handshake mechanism between the color fade of
	; the "ghosts" halo and the hidden cracktro:
	; - $a4 is initialized with 'FADE_RUNNING' meaning that the
	;   color fade is in progress.
	; - The hidden cracktro can request the fade to finish by
	;   writing 'FADE_WAIT_END' in $a4.
	; - When the fade is over, the loader responds by writing
	;   'FADE_ENDED'.
	ifne	USE_LOAD_ANIM
	move.w	#FADE_RUNNING,$a4.w
	elseif
	clr.w	$a4.w           ; FADE_ENDED
	subi.l	#30*200,$9c.w   ; Shorten the anim duration
	endc

	; Install a special GEM critical error handler.
	; See gem_crit_error_stop_anim() for details.
	ifne	USE_LOAD_ANIM
	lea	gem_crit_error_stop_anim(pc),a0
	elseif
	lea	gem_crit_error_retry(pc),a0
	endc
	move.l	a0,$404.w       ; Vector $101

	move.w	#$2300,sr

	moveq.l	#0,d0
	rts

	;
	; load_anim_stop()
	;
	; Stop the loading animation previously started by
	; load_anim_start()
	;
	; Called from supexec.
	;
	; Out:
	;   d0: return value
	;
	; Scratch: a0
	;
load_anim_stop
	ifne	DEBUG_LOAD_ANIM
	; Wait for the color fade of the "ghosts" halo to finish.
	move.w	#FADE_WAIT_END,$a4.w
.wfade	stop	#$2300
	cmpi.w	#FADE_ENDED,$a4.w
	bne.s	.wfade
	endc

	bsr	vsync_sup

	move.w	#$2700,sr

	; Stop timer B and disable timer B channel.
	clr.b	$fffffa1b.w
	bclr.b	#0,$fffffa07.w
	bclr.b	#0,$fffffa13.w
	bclr.b	#0,$fffffa0b.w
	bclr.b	#0,$fffffa0f.w

	; Restore used vectors.
	lea	load_anim_vecs_saved(pc),a0
	move.l	(a0)+,$70.w
	move.l	(a0)+,$120.w
	move.l	(a0)+,$90.w
	move.l	(a0)+,$94.w
	move.l	(a0)+,$98.w
	move.l	(a0)+,$9c.w
	move.l	(a0)+,$a0.w
	move.l	(a0)+,$a4.w

	; Set all colors to black.
	bsr	cols_black

	move.w	#$2300,sr

	; Resume IKBD transfers.
	moveq.l	#$11,d0
	bsr	send_ikbd

	; Restore mouse.
	moveq.l	#$8,d0
	bsr	send_ikbd

	moveq.l	#0,d0
	rts

	;
	; gem_crit_error_stop_anim()
	;
	; The animation consumes quite a bit of CPU and so it can
	; disturb the loading of the hidden cracktro and cause the
	; TOS to detect a loading error (on TOS v1.00 in particular).
	; If this happens, the following handler is called by the TOS.
	; It disables the animation and forces the TOS to retry the
	; disk operation. If the error continues, it forces the TOS
	; to abort the operation (causing pexec() to return with an
	; error).
	;
	; It falls through to gem_crit_error_retry().
	;
gem_crit_error_stop_anim
	bsr	vsync_sup

	move.w	#$2700,sr

	; Set all colors to black.
	bsr	cols_black

	; Stop timer B and disable timer B channel.
	clr.b	$fffffa1b.w
	bclr.b	#0,$fffffa07.w
	bclr.b	#0,$fffffa13.w
	bclr.b	#0,$fffffa0b.w
	bclr.b	#0,$fffffa0f.w

	; Disable the animation by installing a dummy VBL handler.
	lea	load_anim_vbl_dummy(pc),a0
	move.l	a0,$98.w

	move.w	#$2300,sr

	; Clear the screen.
	movea.l 	mach_conf+MACH2SCREEN+PHYSBASE(pc),a0
	move.w	#$7d00/16-1,d0
.cls_lp	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	clr.l	(a0)+
	dbf	d0,.cls_lp

	clr.w	$a4.w           ; FADE_ENDED
	subi.l	#30*200,$9c.w   ; Shorten the anim duration
	lea	$ffff8240.w,a0  ; No more palette update in HBL
	move.l	a0,$a0.w
	; Fall-through

	;
	; gem_crit_error_retry()
	;
	; GEM critical error handler installed when loading external
	; cracktros.
	; If a disk error is detected by the TOS, this handler
	; forces the failing operation to be retried once and
	; then to be aborted if the error continues (by installing
	; the gem_crit_error_fatal() handler below).
	;
	; Out:
	;   d0: $10000 (retry)
	;
	; Scratch allowed by the TOS: d1-d2/a0-a2
	;
gem_crit_error_retry
	; The next GEM critical error will be fatal.
	lea	gem_crit_error_fatal(pc),a0
	move.l	a0,$404.w

	moveq.l	#1,d0
	swap	d0
	rts

	;
	; gem_crit_error_fatal()
	;
	; GEM critical error handler that forces a failing disk
	; operation to be aborted.
	; This handler is installed by gem_crit_error_retry() after
	; the failing disk operation has been retried without success.
	;
	; Out:
	;   d0: -1 (abort with an error)
	;
	; Scratch allowed by the TOS: d1-d2/a0-a2
	;
gem_crit_error_fatal
	moveq.l	#-1,d0
	rts

	;
	; VBL handler.
	;
	; This handler just calls the VBL routine registered in
	; vector $98.
	; This mechanism allows the shell of the hidden cracktro
	; to get the address of the loading animation routine (which
	; is registered in $98), to install its own VBL handler in
	; $98 and to call the loading animation routine from that
	; new handler.
	;
vbl_shell
	movem.l	d0-a6,-(a7)

	movea.l	$98.w,a0
	jsr	(a0)

	movem.l	(a7)+,d0-a6
	rte

	;
	; load_anim_vbl_dummy()
	;
	; Dummy loading animation routine used when the animation
	; should be disabled.
	; This routine is registered in $98.
	;
load_anim_vbl_dummy
	; Just invoke the TOS VBL.
	trap	#4
	rts

	ifne USE_LOAD_ANIM

	;
	; load_anim_vbl()
	;
	; Loading animation routine called by the VBL handler.
	; This routine is registered in $98.
	;
	; Scratch: d0-a6
	;
load_anim_vbl
	; Set up the first HBL handler.
	lea	anim_hbl_10(pc),a0
	move.l	a0,$120.w
	clr.b	$fffffa1b.w
	move.b	#10,$fffffa21.w ; Every 10 rasterlines
	move.b	#8,$fffffa1b.w

	; Set all colors to black.
	ifeq	HATARI_VIDEL_WORKAROUND
	bsr	cols_black
	endc	; HATARI_VIDEL_WORKAROUND

	; Call the VBL of the TOS.
	trap	#4

	ifne	LOAD_ANIM_VBL_TIME
	move.w	#$003,$ffff8240.w
	endc

	; Blit the active "ghosts" buffer to screen core.
	bsr	GhostBarrelRoll
	bsr	GhostBarrelBlit

	ifne	LOAD_ANIM_VBL_TIME
	move.w	#$007,$ffff8240.w
	endc

	; Handle the color fade of the "ghosts" halo.
	bsr	fade_ghosts

	ifne	LOAD_ANIM_VBL_TIME
	clr.w	$ffff8240.w
	endc
	rts

	;
	; ANIM_HBL_EOI()
	;
	; Set up the next HBL handler and trigger the EOI.
	;
ANIM_HBL_EOI	macro
	addi.l	#\1,$120.w

	btst	#3,$fffffa17.w
	beq.s	.eoi_done\@
	bclr.b	#0,$fffffa0f.w
.eoi_done\@
	endm

	;
	; HBL handlers for the loading animation.
	;
	; For the animation, 8 barrels are used in screen space
	; directly.
	; The core of the screen is used to display the resulting
	; "ghosts" animation.
	; The 8 barrels are hidden by setting a black palette
	; between rasterlines 1 to 79 and 110 to 200.
	; The "ghosts" palette is only active in the core of
	; the screen (rasterlines 80 to 109) where the animation
	; is displayed.
	;
	; The timer B (HBL) interrupt is triggered every 10
	; rasterlines on purpose so that it is triggered on
	; lines 80 and 110 as accurately as possible.
	;
	; Indeed, reconfiguring timer B on the fly would cause
	; the latency of each timer B interrupt to add to the
	; latency of the previous interrupt, and thus the latency
	; of timer B would increase as successive reconfigured
	; interrupts are triggered.
	;

anim_hbl_10
	ANIM_HBL_EOI	anim_hbl_20-anim_hbl_10
	rte
anim_hbl_20
	ANIM_HBL_EOI	anim_hbl_30-anim_hbl_20
	rte
anim_hbl_30
	ANIM_HBL_EOI	anim_hbl_40-anim_hbl_30
	rte
anim_hbl_40
	ANIM_HBL_EOI	anim_hbl_50-anim_hbl_40
	rte
anim_hbl_50
	ANIM_HBL_EOI	anim_hbl_60-anim_hbl_50
	rte
anim_hbl_60
	ANIM_HBL_EOI	anim_hbl_70-anim_hbl_60
	rte
anim_hbl_70
	ANIM_HBL_EOI	anim_hbl_80-anim_hbl_70
	rte

	;
	; Load the color palette of the ghosts.
	;
anim_hbl_80
	move.l	DOMGhostPalette(pc),$ffff8240.w
	move.l	DOMGhostPalette+4(pc),$ffff8244.w
	move.l	DOMGhostPalette+8(pc),$ffff8248.w
	move.l	DOMGhostPalette+12(pc),$ffff824c.w
	move.l	DOMGhostPalette+16(pc),$ffff8250.w
	move.l	DOMGhostPalette+20(pc),$ffff8254.w
	move.l	DOMGhostPalette+24(pc),$ffff8258.w
	move.l	DOMGhostPalette+28(pc),$ffff825c.w
	ANIM_HBL_EOI	anim_hbl_90-anim_hbl_80
	rte

anim_hbl_90
	ANIM_HBL_EOI	anim_hbl_100-anim_hbl_90
	rte
anim_hbl_100
	ANIM_HBL_EOI	anim_hbl_110-anim_hbl_100
	rte

	;
	; - Set all colors to black again.
	; - Stop the timer B (HBL).
	;   L Blit barrel in hidden screen space + 
	;   insert ghosts column in barrel screen space +
	;   blend with barrel - 1
	;
anim_hbl_110
	; Black palette.
	ifeq	HATARI_VIDEL_WORKAROUND
	clr.l	$ffff8240.w
	clr.l	$ffff8244.w
	clr.l	$ffff8248.w
	clr.l	$ffff824c.w
	clr.l	$ffff8250.w
	clr.l	$ffff8254.w
	clr.l	$ffff8258.w
	clr.l	$ffff825c.w
	endc	; HATARI_VIDEL_WORKAROUND
	; Stop timer B.
	clr.b	$fffffa1b.w
	; EOI.
	ANIM_HBL_EOI anim_hbl_stop-anim_hbl_110
	; Switch to IPL3, in order to execute the following
	; code at base level and thus to enable preemption
	; by any interrupts.
	move.w	#$2300,sr
	; Perform "ghosts" animation in hidden screen space.
	movem.l	d0-a6,-(a7)
	ifne	LOAD_ANIM_VBL_TIME
	move.w	#$004,$ffff8240.w
	endc
	bsr	GhostBarrelScroll
	ifne	LOAD_ANIM_VBL_TIME
	clr.w	$ffff8240.w
	endc
	movem.l	(a7)+,d0-a6
	rte

anim_hbl_stop
	clr.b	$fffffa1b.w
	ANIM_HBL_EOI	0
	rte

	;
	; fade_ghosts()
	;
	; Handle the color fade of the "ghosts" halo, including:
	; - Fade in.
	; - Pause the fade when the halo has the lightest colors.
	; - Fade out.
	; - Pause the fade when the halo has the darkest colors.
	;
	; Scratch: d0-d6/a0-a3
	;
fade_ghosts
	; Get the current state of the fade.
	lea	fade_step(pc),a3
	move.w	(a3),d6
	btst	#FADE_BIT,d6
	beq.s	.wait

	; Fade in/out.
	lea	fade_desc+(1*3*4)(pc),a0
.deltas	lea	fadein_deltas+(1*3*4)(pc),a1
	lea 	DOMGhostPalette+(1*2)(pc),a2
	moveq.l	#6,d0
	bsr	fade_palette_linear1

	; End of the fade reached?
	addq.b	#1,d6
	cmpi.b	#FADE_IN+FADEIN_HALO_STEPS,d6
	beq.s	.f_end
	cmpi.b	#FADE_OUT+FADEOUT_HALO_STEPS,d6
	bne.s	.save

	; End of the fade, a pause will start at the next VBL.
.f_end	andi.w	#~(1<<FADE_BIT),d6

.save	move.w	d6,(a3)
	rts

	; Check if the hidden cracktro has requested the fade to
	; finish (by writing 'FADE_WAIT_END' in $a4).
.wait	cmpi.w	#FADE_RUNNING,$a4.w
	bne.s	.fade_handshake

	; Pause the fade when the halo has the darkest/lightest colors.
.nstate	addq.b	#1,d6
	cmpi.b	#FADE_LOOP,d6
	beq.s	.f_in
	cmpi.b	#FADE_OUT,d6
	bne.s	.save

	; Prepare the fade-out that will start at the next VBL.
.f_out	move.w	#(fadeout_deltas-(.deltas+2))+(1*3*4),d0
	bra.s	.f_xchg

	; Prepare the fade-in that will start at the next VBL.
.f_in	moveq.l	#FADE_IN,d6
	move.w	#(fadein_deltas-(.deltas+2))+(1*3*4),d0

	; Swap deltas pointers (fade-in/fade-out).
.f_xchg	lea	.deltas+2(pc),a0
	move.w	d0,(a0)

	; Indicate that a new color fade will start at the next VBL.
	ori.w	#(1<<FADE_BIT),d6
	bra.s	.save

	; If the hidden cracktro has requested the fade to finish,
	; wait for the end of the fade-out and, when it has finished,
	; write 'FADE_ENDED' in $a4 to disable the fade and to tell
	; the cracktro that the fade is now over.
.fade_handshake
	; Fade already ended?
	cmpi.w	#FADE_ENDED,$a4.w
	beq.s	.ret
	; No, end of the fade-out reached?
	cmpi.w	#FADE_WAIT_DARK,d6
	bne.s	.nstate
	; Yes, stop the fade.
	move.w	#FADE_ENDED,$a4.w
.ret	rts

	;
	; Include Fury's code!
	;
	include	"ANIM.S"

	; Data of the color fade of the "ghosts" halo.
	section	data

	; State of the color fade of the "ghosts" halo
	; shared with the hidden cracktro.
FADE_RUNNING            =	2
FADE_WAIT_END           =	1
FADE_ENDED              =	0

	; Internal state of the color fade of the "ghosts" halo.
FADE_IN                 =	0
FADE_WAIT_LIGHT         =	(FADE_IN+FADEIN_HALO_STEPS)
FADE_OUT                =	(FADE_WAIT_LIGHT+FADE_WAIT_LIGHT_COUNT)
FADE_WAIT_DARK          =	(FADE_OUT+FADEOUT_HALO_STEPS)
FADE_LOOP               =	(FADE_WAIT_DARK+FADE_WAIT_DARK_COUNT)

FADE_BIT                =	12

	; Current internal state.
fade_step
	dc.w	FADE_WAIT_DARK

	; The fade descriptor below is placed in the BSS.
	section	bss

	; Pre-calculated fade-out data.
	; The fade-in of the halo shares the same descriptor as
	; the fade in/out of the fonts (see fade_desc).
fadeout_desc
	ds.l	3*16            ; R/G/B values
fadeout_deltas
	ds.l	3*16            ; R/G/B deltas

	endc	; USE_LOAD_ANIM

	;
	; External cracktros data.
	;
	section	data

	; Vectors used for the loading animation are saved here.
load_anim_vecs_saved
	ds.l	8

	; Original GEM critical error handler.
gem_crit_err_vec
	ds.l	1

	; Main (external) cracktro filename.
extintro_name_main
	dc.b	"cracktro.68k",0
	even

	; Main (external) cracktro command line.
extintro_cmdline_main
	dc.b	5,"MREPS",0
	even

	; Hidden (external) cracktro filename.
extintro_name_hidden
	dc.b	"hidden.68k",0
	even

	; Hidden (external) cracktro command line.
extintro_cmdline_hidden
	dc.b	5,"HREPS",0
	even

	; Indicate whether the main cracktro has been run.
extintro_executed
	dc.b	$ff
	even

	; Reset section to text.
	section	text

***************************************************************************
*
* 6. Internal intro code (trainer menu)
*
* Public routines:
* - intro()
* - cols_black()
* - fade_palette_simple()
* - reverse_fade()
* - precalc_fade()
* - fade_palette_linear1()
* - fade_palette_linear()
*
***************************************************************************

	;
	; intro()
	;
	; Internal intro: print a text using fancy fonts
	; and handle trainer options.
	;
	; If the main cracktro has been executed successfully,
	; then a very short text offering to choose the trainer
	; mode is printed.
	; If the execution of the main cracktro failed, a full
	; text with all credits is printed.
	;
	; Called from supexec.
	;
	; Out:
	;   d0: return value
	;
	; Scratch: a0-a2
	;
intro
	movem.l	d3-d7/a3-a6,-(a7)

	; Consume all chars available in the input buffer.
	bsr	flush_input_buffer

	; Initialize the text printing context.
	bsr	init_txt

	; Choose the text to be printed depending on whether
	; the main cracktro has been executed or not:
	; If the main cracktro has been executed then only a
	; short message needs to be printed.
	; If the execution of the main cracktro failed then
	; full credits should be printed.
	; In debug mode, the full text is always printed.
	lea	txt_intro(pc),a0
	ifeq	DEBUG
	move.b	extintro_executed(pc),d0
	beq.s	.prnt
	lea	txt_intro_short(pc),a0
	endc

	; Print the main text.
.prnt	bsr	print_txt

	; Initialize the color fade of the fonts.
	lea 	black_pal(pc),a0
	lea	fonts_pal(pc),a1
	lea	fade_desc(pc),a2
	move.w	#FADE_FONTS_FACTOR,d0
	bsr 	precalc_fade

	; Fade colors to the fonts colors.
	movea.l 	a2,a0
	moveq.l	#FADE_FONTS_STEPS-1,d0
	bsr	fade_palette_linear

	; Key handling of the main text.
.k_wait	bsr.s	xreadchar       ; read key
	cmpi.b	#' ',d0
	beq.s	intro_key_end   ; start game
	cmpi.b	#'t',d0
	beq.s	intro_trainer   ; trainer menu
	bra.s	.k_wait

intro_key_end
	; Fade colors to black.
	lea 	fade_desc(pc),a0
	moveq.l	#FADE_FONTS_STEPS-1,d0
	bsr	fade_palette_linear

	; Clear the screen
	lea	cls(pc),a0
	bsr	print_txt

	movem.l	(a7)+,d3-d7/a3-a6
	moveq.l	#0,d0
	rts

	; Print and handle the trainer options.
intro_trainer
	lea 	fade_desc(pc),a0
	moveq.l	#FADE_FONTS_STEPS-1,d0
	bsr	fade_palette_linear

	lea	txt_trainer(pc),a0
	bsr	print_txt

	; Print the trainer options.
	bsr.s	print_opts

	lea 	fade_desc(pc),a0
	moveq.l	#FADE_FONTS_STEPS-1,d0
	bsr	fade_palette_linear

	; Key handling of the trainer text.
.k_wait	bsr.s	xreadchar       ; read key
	cmpi.b	#' ',d0
	beq.s	intro_key_end   ; start game
	bsr.s	handle_opt      ; trainer options
	bsr.s	print_opts
	bra.s	.k_wait

	;
	; xreadchar()
	;
	; Read a character and return the corresponding
	; ASCII code.
	; Use our own scancode/keycode mapping.
	;
	; Out:
	;   d0: ASCII code of pressed key
	;
xreadchar
	movem.l	d1/a0,-(a7)

	; Loop until a valid key has been pressed.
.miss
	; Invoke GEMDOS Crawcin.
	bsr	readchar
	; Get the scancode.
	swap	d0

	; Get the keycode from the scancode.
	lea	key_map(pc),a0

.lp	move.b	(a0),d1
	beq.s	.miss
	cmp.b	d0,d1
	beq.s	.hit
	addq.l	#2,a0
	bra.s	.lp

	; A valid key has been pressed, return
	; the corresponding ASCII code.
.hit	moveq.l	#0,d0
	move.b	1(a0),d0

	movem.l	(a7)+,d1/a0
	rts

	;
	; print_opts()
	;
	; Print trainer options described in the
	; opts_info table.
	;
print_opts
	movem.l	d0-d1/a0-a1,-(a7)

	; Wait for vsync.
	bsr	vsync_sup

	; Walk through the trainer options description
	; table and print each trainer option.
	lea	opts_info(pc),a1
	move.w	(a1)+,d1        ; number of options
	subq.w	#1,d1           ; -1 for dbf

.lp	movea.l	a1,a0
	; Get the text of the trainer option.
	adda.l	(a1)+,a0
	; Get the type of the trainer option:
	;   0: boolean (Y/N)
	;  !0: numeric
	tst.w	(a1)+
	bne.s	.num

.bool	move.b	#'*',d0
	; Check the boolean value.
	tst.w	(a1)+
	bne.s	.doprt
	move.b	#' ',d0
	bra.s	.doprt

	; Get the numeric value.
.num	move.w	(a1)+,d0
	; Transform that value into a numeric ASCII code.
	addi.b	#$30,d0

	; Patch the trainer option text and print it.
.doprt	move.b	d0,4(a0)
	bsr	print_txt

	; Handle next option.
	dbf	d1,.lp

	movem.l	(a7)+,d0-d1/a0-a1
	rts

	;
	; handle_opt()
	;
	; Update the opts_info table describing trainer options
	; according to the key pressed by the user.
	;
	; In:
	;   d0: ASCII code of pressed key
	;
handle_opt
	movem.l	d0/a0,-(a7)

	; Get the table entry corresponding to the selected
	; option. Option 0 to n is selected by pressing key
	; '0' to 'n' (ASCII code).
	lea	opts_info(pc),a0
	subi.b	#$30,d0
	; Check if the selected trainer option is valid.
	cmp.w	(a0),d0
	bhs.s	.ret
	; Switch 0 and 9.
	subq.b	#1,d0
	bpl.s	.optype
	addi.b	#10,d0

.optype	lsl.w	#3,d0
	lea	2+4(a0,d0.w),a0
	tst.w	(a0)+
	bne.s	.num

	; Boolean trainer option: toggle the option value.
.bool	not.w	(a0)
	bra.s	.ret

	; Numeric trainer option: increment the option value.
.num	move.w	(a0),d0
	addq.b	#1,d0
	; Make sure the new value is in the allowed range.
	; -1(a0) gives the highest allowed value,
	; -2(a0) gives the lowest allowed value.
	cmp.b	-1(a0),d0
	bls.s	.num_ok
	move.b	-2(a0),d0
.num_ok	move.w	d0,(a0)

.ret	movem.l	(a7)+,d0/a0
	rts

	;
	; cols_black()
	;
	; Set low rez colors to black.
	;
cols_black
	movem.l	d0/a0,-(a7)
	lea	$ffff8240.w,a0
	moveq.l	#7,d0
.clear	clr.l	(a0)+
	dbf	d0,.clear
	movem.l	(a7)+,d0/a0
	rts

	;
	; fade_palette_simple()
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
fade_palette_simple
	movem.l	d0-d7/a0-a1,-(a7)

	; R/G/B masks are rotated in d1 to indicate the color
	; component (R,G,B) to be modified during the current
	; fade iteration.
	move.w	#$0f00,d1
	move.w	#$00f0,d2
	move.w	#$000f,d3

.fade	bsr	vsync
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

	;
	; ste_to_fadeRGB()
	;
	; This macro breaks down a STe color into separate R/G/B
	; values and represents them as fixed point numbers.
	; The 4 bits of each color component (R/G/B) are reorganized
	; so that these color components have strictly increasing
	; values when they gradually vary from dark to lighter.
	; This allows arithmetic operations, such as linear
	; interpolation between an initial value and a target value.
	; This is mandatory on STe where the least significant bit
	; of each color component is in the position one might
	; otherwise expect to be used for the most significant bit:
	; xx xx xx xx R0 R3 R2 R1 G0 G3 G2 G1 B0 B3 B2 B1
	;
	; In:
	;   \1: pointer to the STe color
	; Out:
	;   \1: input pointer is incremented
	;   \2: R<<16
	;   \3: G<<16
	;   \4: B<<16
	;
ste_to_fadeRGB	macro

	; STe color read.

	moveq.l	#0,\2
	move.w	(\1)+,\2

	; Reorder STe color bits to allow arithmetic in registers.
	;
	; \2 = R0 R3 R2 R1  G0 G3 G2 G1  B0 B3 B2 B1

	move.w	#$0888,\3   ;  1  0  0  0   1  0  0  0   1  0  0  0
	and.w	\2,\3       ; R0  0  0  0  G0  0  0  0  B0  0  0  0
	lsr.w	#3,\3       ;  0  0  0 R0   0  0  0 G0   0  0  0 B0
	andi.w	#$0777,\2   ;  0 R3 R2 R1   0 G3 G2 G1   0 B3 B2 B1
	add.w	\2,\2       ; R3 R2 R1  0  G3 G2 G1  0  B3 B2 B1  0
	or.w	\3,\2       ; R3 R2 R1 R0  G3 G2 G1 G0  B3 B2 B1 B0

	; \2 = R3 R2 R1 R0  G3 G2 G1 G0  B3 B2 B1 B0

	; Convert to fadeRGB (fixed point numbers).

	move.l	\2,\3
	move.l	\2,\4

	andi.w	#$f00,\2        ; \2 = R00
	lsr.w	#8,\2           ; \2 = 00R
	swap	\2              ; <<16

	andi.w	#$0f0,\3        ; \3 = 0G0
	lsr.w	#4,\3           ; \3 = 00G
	swap	\3              ; <<16

	andi.w	#$00f,\4        ; \4 = 00B
	swap	\4              ; <<16

	endm

	;
	; reverse_fade()
	;
	; Change the sign of the fade deltas to reverse the
	; color fade.
	;
	; In:
	;   d0: number of colors
	;   a0: fade descriptor containing the pre-calculated data
	;       (R/G/B values and fade deltas)
	;
	; Scratch: d0/a0
	;
reverse_fade
	; Fade deltas are stored after R/G/B values.
	lea	16*3*4(a0),a0
.rev	neg.l	(a0)+
	neg.l	(a0)+
	neg.l	(a0)+
	dbf	d0,.rev

	rts

	;
	; precalc_fade()
	;
	; Colors are faded from an initial palette to a target
	; palette using simple linear interpolation.
	;
	; This routine pre-calculates the critical data used for the
	; linear interpolation so that the fade routine is as fast as
	; possible:
	; - First it extracts the 3 components (R, G, B) of each color
	;   to represent them as 3 fixed point numbers. The STe format
	;   (16 R/G/B levels) is supported.
	; - Then for each individual component (R, G, B) of each color,
	;   it pre-calculates the delta between two consecutive values
	;   along the linear interpolation.
	;   Deltas are also represented and stored as fixed point
	;   numbers.
	;
	; In:
	;   d0: fade factor, a number between 0 and 1 represented as a
	;       fixed point number and used to calculate 2 consecutive
	;       color values along the linear interpolation; in other
	;       words this factor represents the distance between 2
	;       consecutive color values; the lower the value of this
	;       factor, the slower the color fade
	;   a0: initial color palette
	;   a1: target color palette
	;   a2: fade descriptor containing the pre-calculated data
	;       (initial R/G/B values and R/G/B deltas)
	;
precalc_fade
	movem.l	d0-d7/a0-a3,-(a7)

	; 16 colors in a low-rez palette.
	moveq.l	#15,d7

	lea	16*3*4(a2),a3

	; a2 = Initial colors broken down into separate R/G/B values,
	;      saved as fixed point numbers (called 'fadeRGB').
	; a3 = Deltas between 2 consecutive values along the linear
	;      interpolation of all R/G/B components, also saved as
	;      fixed point numbers (called 'fadeRGB deltas').

.prec
	; Compute initial and target fadeRGB (separate R/G/B values
	; represented as fixed point numbers).

	ste_to_fadeRGB a0,d1,d2,d3
	; d1-d3 = initial fadeRGB.

	ste_to_fadeRGB a1,d4,d5,d6
	; d4-d6 = target fadeRGB.

	; fadeRGB deltas between the initial and target colors.

	sub.l	d1,d4
	sub.l	d2,d5
	sub.l	d3,d6

	; Shift (>>16) fadeRGB deltas to return to 0..f

	swap	d4
	swap	d5
	swap	d6

	; fadeRGB deltas between two consecutive color values
	;   = fadeRGB delta(0..f) * factor(0..1<<16)

	muls.w	d0,d4
	muls.w	d0,d5
	muls.w	d0,d6

	; Save initial fadeRGB.

	move.l	d1,(a2)+
	move.l	d2,(a2)+
	move.l	d3,(a2)+

	; Save fadeRGB deltas.

	move.l	d4,(a3)+
	move.l	d5,(a3)+
	move.l	d6,(a3)+

	; Next color.
	dbra	d7,.prec

	movem.l	(a7)+,d0-d7/a0-a3
	rts

	;
	; fade_palette_linear1()
	;
	; Fade colors from an initial palette to a target palette
	; using simple linear interpolation.
	;
	; This routine calculates the next value, along the linear
	; interpolation, of each color.
	; It must be called multiple times to achieve the complete
	; color fade.
	; It uses the data pre-calculated by precalc_fade().
	; It supports the STe color format with 16 levels of R/G/B.
	;
	; Original implementation by Fury; adapted & optimized for
	; the loading animation by Orion.
	;
	; In:
	;   d0: number of colors
	;   a0: array of current fadeRGB values (separate R/G/B values
	;       represented as fixed point numbers)
	;   a1: array of fadeRGB deltas (deltas between consecutive
	;       R/G/B values)
	;   a2: destination color palette
	;
	; Scratch: d0-d5/a0-a2
	;
fade_palette_linear1
	moveq.l	#0,d4           ; Used to test BIT0
	moveq.l	#%10001,d5      ; XORed to return to STe format
.fade
	; Read current fadeRGB,
	; add fadeRGB deltas,
	; and save new fadeRGB.

	move.l	(a0),d1         ; R<<16
	add.l	(a1)+,d1
	move.l	d1,(a0)+

	move.l	(a0),d2         ; G<<16
	add.l	(a1)+,d2
	move.l	d2,(a0)+

	move.l	(a0),d3         ; B<<16
	add.l	(a1)+,d3
	move.l	d3,(a0)+

	; Return to STe format.

	; d1 = (0 R3 R2 R1 R0) << 16
	swap	d1              ;        d1 = ... 0 R3 R2 R1 R0
	btst	d4,d1           ; R0 set?
	beq.s	.st_r           ; No  => d1 = ... 0 R3 R2 R1  0
	eor.w	d5,d1           ; Yes => d1 = ... 1 R3 R2 R1  0
	; d1 = STe[R] << 1
.st_r
	lsl.w	#4,d1           ; STe[R] << 5

	swap	d2
	btst	d4,d2
	beq.s	.st_g
	eor.w	d5,d2
.st_g
	or.w	d2,d1
	lsl.w	#3,d1           ; STe[RG] << 4

	swap	d3
	btst	d4,d3
	beq.s	.st_b
	eor.w	d5,d3
.st_b
	lsr.w	#1,d3
	or.w	d3,d1           ; STe[RGB]

	; Store STe value.
	move.w	d1,(a2)+

	; Next color.
	dbra	d0,.fade

	rts

	;
	; fade_palette_linear()
	;
	; Fade colors from an initial palette to a target palette
	; using simple linear interpolation.
	;
	; For each color in the palette, a fixed number of discrete
	; values are calculated along the linear interpolation, with
	; each value being calculated and set in the HW palette at
	; the pace of VBL interrupts.
	;
	; The ST(e) palette ($ff8240) is automatically updated,
	; the STe color format (16 levels of R/G/B) is supported.
	;
	; In:
	;   d0: fade steps (number of fade iterations)
	;   a0: fade descriptor containing the pre-calculated data
	;       (initial R/G/B values and R/G/B deltas)
	;
fade_palette_linear
	movem.l	d0-d6/a0-a2,-(a7)

	lea	$ffff8240.w,a2
	lea	16*3*4(a0),a1
	move.l	d0,d6

.fade	bsr	vsync

	moveq.l	#15,d0
	bsr.s	fade_palette_linear1

	movea.l	a0,a1
	lea	-16*3*4(a0),a0
	lea	-16*2(a2),a2

	dbf	d6,.fade

	; Update the pre-calculated fade data so that the next
	; color fade is done in reverse.
	moveq.l	#15,d0
	bsr	reverse_fade

	movem.l	(a7)+,d0-d6/a0-a2
	rts

	;
	; init_txt()
	;
	; Initialize the text printing context:
	; - screen physical address
	; - text coordinates (cursor position)
	;
init_txt
	movem.l	a0-a1,-(a7)

	lea	txt_state(pc),a0
	lea.l	mach_conf(pc),a1
	move.l	MACH2SCREEN+PHYSBASE(a1),TXT_PHYSBASE(a0)
	clr.l	TXT_POSX(a0)
	clr.l	TXT_POSY(a0)

	movem.l	(a7)+,a0-a1
	rts	

	;
	; print_txt()
	;
	; Print a null-terminated text/string onto the screen,
	; using fancy fonts.
	; Use the same special characters as the GEMDOS Cconws
	; function: CR, LF, ESC sequences.
	;
	; In:
	;   a0: text buffer
	;
print_txt
	movem.l	d0-d3/a0-a3,-(a7)

	; a3 = text buffer.
	movea.l	a0,a3
	; a0 = text printing context.
	lea	txt_state(pc),a0

	; Iterate each text character.
.loop	moveq.l	#0,d0
	move.b	(a3)+,d0

.lf	cmpi.b	#10,d0          ; LF
	bne.s	.cr
	; Update the cursor Y position (in bytes).
	addi.l	#160*8,TXT_POSY(a0)
	bra.s	.loop

.cr	cmpi.b	#13,d0          ; CR
	bne.s	.end
	; Reset the cursor X position (in bytes).
	clr.l	TXT_POSX(a0)
	bra.s	.loop

.end	cmpi.b	#0,d0           ; END
	beq.s	.ret

.esc	cmpi.b	#27,d0          ; ESC
	bne.s	.char
	movea.l	a3,a1
	; Handle an ESC sequence.
	bsr.s	print_escape
	movea.l	a1,a3
	bra.s	.loop

	; Print a normal character.
.char	bsr.s	print_char

	; Handle next character.
	bra.s	.loop

.ret	movem.l	(a7)+,d0-d3/a0-a3
	rts

	;
	; print_char()
	;
	; Print a normal character onto the screen
	; at the current cursor position.
	;
	; In:
	;   d0: printable ASCII character
	;   a0: text printing context
	;
	; Scratch: d0,a1-a2
	;
print_char
	lea	fonts(pc),a1
	subi.b	#$20,d0
	lsl.l	#5,d0
	; a1 = font source address.
	adda.l	d0,a1
	movea.l	TXT_PHYSBASE(a0),a2
	adda.l	TXT_POSY(a0),a2
	move.l	TXT_POSX(a0),d0
	; a2 = screen target address
	adda.l	d0,a2
	; Increment the cursor X position (in bytes).
	addq.w	#1,d0
	btst	#0,d0
	bne.s	.even
	addq.w	#6,d0
.even	move.l	d0,TXT_POSX(a0)
	; Copy the font of the given character.
	moveq.l	#7,d0

.blk	move.b	(a1)+,(a2)
	move.b	(a1)+,2(a2)
	move.b	(a1)+,4(a2)
	move.b	(a1)+,6(a2)
	lea	160(a2),a2
	dbf	d0,.blk

	rts

	;
	; print_escape()
	;
	; Handle an ASCII code control (ESC) sequence.
	; Supported sequences are:
	; - ESC E: clear screen
	; - ESC Y: set cursor position
	; - ESC f: hide cursor
	;
	; In:
	;   a0: text printing context
	;   a1: pointer to the control character (right after
	;       the ESC character)
	;
	; Out:
	;   a1: pointer to the character following
	;       the ESC sequence
	;
print_escape
	movem.l	d0-d1/a2,-(a7)
	; Get the control character.
	move.b	(a1)+,d0

.cls	cmpi.b	#"E",d0
	bne.s	.pos

	; Clear screen.
	movea.l	TXT_PHYSBASE(a0),a2
	move.w	#$7d00/16-1,d0

.cls_lp	clr.l	(a2)+
	clr.l	(a2)+
	clr.l	(a2)+
	clr.l	(a2)+
	dbf	d0,.cls_lp
	bra.s	.ret

.pos	cmpi.b	#"Y",d0
	bne.s	.curoff

	; Set cursor position.
	; Cursor X & Y positions (TXT_POSX and TXT_POSY)
	; are in bytes.
	moveq.l	#0,d0
	move.b	(a1)+,d0
	subi.b	#32,d0
	mulu	#160*8,d0
	move.l	d0,TXT_POSY(a0)
	moveq.l	#0,d0
	move.b	(a1)+,d0
	subi.b	#32,d0
	move.w	d0,d1
	bclr	#0,d0
	lsl.w	#2,d0
	andi.b	#1,d1
	add.w	d1,d0
	move.l	d0,TXT_POSX(a0)
	bra.s	.ret

.curoff	cmpi.b	#"f",d0
	bne.s	.ret

	; Hide cursor: nothing to do.
	nop

.ret	movem.l	(a7)+,d0-d1/a2
	rts

***************************************************************************
*
* 7. Internal intro data
*
***************************************************************************

	;
	; Data section.
	;
	section	data

	; Main text - short version.
	; Used only if the main cracktro has been successfully
	; executed.
txt_intro_short
	dc.b	27,"E",27,"Y",44,32
	dc.b	"  BASH T FOR TRAINER OR SPACE TO START  ",10,13
	dc.b	0
	even

	; Main text - long version.
	; Used if the main cracktro did not run.
txt_intro
	dc.b	27,"E",27,"Y",32,32
	dc.b	"        THE REPLICANTS BRING YOU        ",10,13
	dc.b	10,13
	dc.b	"        ------------------------        ",10,13
	ifne	DEBUG_VER
	dc.b	"        --  SON SHU SHI [",DEBUG_MAJ,DEBUG_MIN,"]  --        ",10,13
	elseif
	dc.b	"        --  SON SHU SHI 100%  --        ",10,13
	endc
	dc.b	"        ------------------------        ",10,13
	dc.b	10,13
	dc.b	"FIXED/MEGA-TRAINED/FILED/REPACKED/LINKED",10,13
	dc.b	"HARD DISK/RAMDISK/MULTI-MACHINES SUPPORT",10,13
	dc.b	10,13
	dc.b	"         RETRO-HACKING BY ORION         ",10,13
	dc.b	10,13
	dc.b	"      INITIAL BUT NOT 100% CRACK BY     ",10,13
	dc.b	"             TERMINATOR KID             ",10,13
	dc.b	10,13
	dc.b	"      WORKING COPY SUPPLIED BY MIT      ",10,13
	dc.b	"        AND KRYOFLUX`ED BY BRUME        ",10,13
	dc.b	10,13
	dc.b	"       TESTED ON REAL HARDWARE BY       ",10,13
	dc.b	" TWISTER, GT TURBO, COOPER, FURY & JADE ",10,13
	dc.b	10,13
	dc.b	" FIND THE SOURCE CODE OF THIS CRACK AT: ",10,13
	dc.b	"HTTPS://GITHUB.COM/ORIONFUZION/NEWCRACKS",10,13
	dc.b	10,13
	dc.b	"  BASH T FOR TRAINER OR SPACE TO START  ",10,13
	dc.b	0
	even

	; Trainer text.
txt_trainer
	dc.b	27,"E",27,"Y",37,32
	dc.b	"       SON SHU SHI - TRAINER MENU       ",10,13
	dc.b	10,13
	dc.b	"   1>  UNLIMITED LIVES            [ ]   ",10,13
	dc.b	"   2>  UNLIMITED ENERGY           [ ]   ",10,13
	dc.b	"   3>  UNLIMITED TIME             [ ]   ",10,13
	dc.b	"   4>  UNLIMITED MONEY            [ ]   ",10,13
	dc.b	"   5>  SELECT WEAPON WITH <S>     [ ]   ",10,13
	dc.b	"   6>  MAX FIREPOWER              [ ]   ",10,13
	dc.b	"   7>  FALL INTO THE SKY          [ ]   ",10,13
	dc.b	"   8>  ENTER BRICK GAME WITH <B>  [ ]   ",10,13
	dc.b	"   9>  UNLIMITED BRICK LIVES      [ ]   ",10,13
	dc.b	"   0>  STARTING LEVEL             [ ]   ",10,13
	dc.b	10,13
	dc.b	"   PRESS KEYS 0-9 FOR TRAINER OPTIONS   ",10,13
	dc.b	"          BASH SPACE TO START           ",10,13
	dc.b	0
	even

	; Character strings for the trainer options
	; (patched with proper characters when options change).

TR_Y_START      =	39
TR_X_START      =	67

txt_opt1
	dc.b	27,"Y",TR_Y_START+0,TR_X_START," ",0
txt_opt2
	dc.b	27,"Y",TR_Y_START+1,TR_X_START," ",0
txt_opt3
	dc.b	27,"Y",TR_Y_START+2,TR_X_START," ",0
txt_opt4
	dc.b	27,"Y",TR_Y_START+3,TR_X_START," ",0
txt_opt5
	dc.b	27,"Y",TR_Y_START+4,TR_X_START," ",0
txt_opt6
	dc.b	27,"Y",TR_Y_START+5,TR_X_START," ",0
txt_opt7
	dc.b	27,"Y",TR_Y_START+6,TR_X_START," ",0
txt_opt8
	dc.b	27,"Y",TR_Y_START+7,TR_X_START," ",0
txt_opt9
	dc.b	27,"Y",TR_Y_START+8,TR_X_START," ",0
txt_opt0
	dc.b	27,"Y",TR_Y_START+9,TR_X_START," ",0
	even

	; Description table of trainer options
	; (used to patch previous character strings).

TR_OPT_VAL      =	(~(DEBUG_TRAINER-1))

opts_info
	; Number of trainer options
	dc.w	10
opt1_info
	dc.l	txt_opt1-opt1_info
	dc.w	0,TR_OPT_VAL
opt2_info
	dc.l	txt_opt2-opt2_info
	dc.w	0,TR_OPT_VAL
opt3_info
	dc.l	txt_opt3-opt3_info
	dc.w	0,TR_OPT_VAL
opt4_info
	dc.l	txt_opt4-opt4_info
	dc.w	0,TR_OPT_VAL
opt5_info
	dc.l	txt_opt5-opt5_info
	dc.w	0,TR_OPT_VAL
opt6_info
	dc.l	txt_opt6-opt6_info
	dc.w	0,TR_OPT_VAL
opt7_info
	dc.l	txt_opt7-opt7_info
	dc.w	0,TR_OPT_VAL
opt8_info
	dc.l	txt_opt8-opt8_info
	dc.w	0,TR_OPT_VAL
opt9_info
	dc.l	txt_opt9-opt9_info
	dc.w	0,TR_OPT_VAL
opt0_info
	dc.l	txt_opt0-opt0_info
	dc.b	1,6
	dc.w	1

	; Scancode/ASCII mapping.
key_map
	dc.b	$0b,'0',$02,'1',$03,'2',$04,'3',$05,'4',$06,'5',$07,'6',$08,'7',$09,'8',$0a,'9'
	dc.b	$70,'0',$6d,'1',$6e,'2',$6f,'3',$6a,'4',$6b,'5',$6c,'6',$67,'7',$68,'8',$69,'9'
	dc.b	$39,' ',$2d,'x',$14,'t',$00
	even

	; Context used to print a text without TOS support.
txt_state
ts_physbase
	ds.l	1               ; Screen phys base
ts_posx
	ds.l	1               ; X position in bytes
ts_posy
	ds.l	1               ; Y position in bytes
txt_state_end

TXT_PHYSBASE    =	(ts_physbase-txt_state)
TXT_POSX        =	(ts_posx-txt_state)
TXT_POSY        =	(ts_posy-txt_state)

	; Black color palette.
black_pal
	ds.w	16

	; Fonts palette.
	; Original "bluescale" converted to a greyscale by Orion.
fonts_pal
	dc.w	$000,$000,$000,$000,$000,$000,$000,$000
	dc.w	$223,$333,$334,$444,$555,$666,$777,$000

	; Fonts by Walt (L'Ing) coming from the "Bloody" Intro
	; coded by Fury.
fonts
	;  !"#$%&'()*+,-./
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
	dc.b	$10,$10,$0,$10,$0,$0,$10,$10,$10,$0,$10,$10,$0,$0,$10,$10,$10,$10,$0,$10,$0,$0,$0,$0,$0,$10,$0,$10,$0,$0,$0,$0
	dc.b	$4,$4,$40,$44,$44,$4,$40,$44,$2,$22,$20,$22,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$20,$0,$28,$28,$54,$24,$78,$7C,$20,$0,$28,$28,$1C,$1C,$60,$7C,$20,$28,$0,$28,$0,$0,$0,$0,$0,$0,$0,$0
	dc.b	$10,$10,$0,$10,$26,$6,$38,$3E,$50,$0,$50,$50,$24,$4,$38,$3C,$10,$12,$0,$12,$70,$7C,$0,$7C,$0,$10,$0,$10,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$62,$2,$60,$62,$44,$24,$60,$64,$0,$0,$8,$8,$10,$10,$0,$10,$22,$24,$0,$26,$46,$40,$0,$46,$0,$0,$0,$0
	dc.b	$18,$18,$20,$38,$44,$4,$40,$44,$0,$20,$28,$28,$40,$0,$50,$50,$90,$92,$0,$92,$80,$8C,$0,$8C,$42,$70,$0,$72,$0,$0,$0,$0
	dc.b	$10,$10,$0,$10,$0,$0,$10,$10,$0,$0,$8,$8,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
	dc.b	$4,$6,$0,$6,$0,$0,$8,$8,$10,$0,$10,$10,$0,$0,$10,$10,$10,$10,$0,$10,$0,$8,$0,$8,$6,$0,$0,$6,$0,$0,$0,$0
	dc.b	$0,$0,$60,$60,$0,$0,$10,$10,$0,$0,$8,$8,$0,$0,$8,$8,$8,$8,$0,$8,$10,$10,$0,$10,$40,$60,$0,$60,$0,$0,$0,$0
	dc.b	$0,$2,$40,$42,$24,$4,$20,$24,$10,$0,$18,$18,$E5,$86,$78,$FF,$18,$18,$0,$18,$20,$24,$0,$24,$42,$40,$0,$42,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$8,$8,$0,$0,$8,$8,$65,$6,$78,$7F,$8,$8,$0,$8,$0,$8,$0,$8,$0,$0,$0,$0,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$10,$10,$0,$10,$0,$10,$0,$10,$20,$0,$0,$20
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$64,$6,$78,$7E,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$10,$10,$0,$10,$0,$10,$0,$10,$0,$0,$0,$0
	dc.b	$0,$1,$0,$1,$2,$2,$0,$2,$4,$4,$0,$4,$0,$0,$8,$8,$10,$10,$0,$10,$20,$20,$0,$20,$40,$40,$0,$40,$0,$0,$0,$0
	; 0123456789
	dc.b	$1C,$1C,$20,$3C,$46,$6,$40,$46,$42,$2,$48,$4A,$40,$2,$50,$52,$0,$2,$60,$62,$42,$40,$0,$42,$C,$30,$0,$3C,$0,$0,$0,$0
	dc.b	$18,$18,$0,$18,$20,$0,$28,$28,$0,$0,$8,$8,$0,$0,$8,$8,$8,$8,$0,$8,$0,$8,$0,$8,$4E,$70,$0,$7E,$0,$0,$0,$0
	dc.b	$1C,$1C,$20,$3C,$42,$2,$40,$42,$2,$2,$0,$2,$4,$4,$0,$4,$8,$8,$0,$8,$10,$10,$0,$10,$4E,$70,$0,$7E,$0,$0,$0,$0
	dc.b	$1C,$1E,$60,$7E,$4,$4,$0,$4,$10,$0,$18,$18,$4,$4,$0,$4,$0,$2,$0,$2,$42,$40,$0,$42,$C,$30,$0,$3C,$0,$0,$0,$0
	dc.b	$C,$C,$0,$C,$4,$4,$10,$14,$4,$24,$20,$24,$44,$4,$40,$44,$1C,$1E,$60,$7E,$0,$4,$0,$4,$4,$0,$0,$4,$0,$0,$0,$0
	dc.b	$1C,$1E,$60,$7E,$40,$0,$40,$40,$54,$24,$78,$7C,$0,$2,$0,$2,$0,$2,$0,$2,$42,$40,$0,$42,$C,$30,$0,$3C,$0,$0,$0,$0
	dc.b	$1C,$1C,$20,$3C,$40,$0,$40,$40,$40,$0,$40,$40,$64,$4,$78,$7C,$0,$2,$40,$42,$42,$40,$0,$42,$C,$30,$0,$3C,$0,$0,$0,$0
	dc.b	$1C,$1E,$60,$7E,$4,$4,$0,$4,$0,$0,$8,$8,$0,$0,$10,$10,$0,$0,$20,$20,$20,$20,$0,$20,$0,$20,$0,$20,$0,$0,$0,$0
	dc.b	$1C,$1C,$20,$3C,$42,$2,$40,$42,$42,$2,$40,$42,$24,$4,$38,$3C,$0,$2,$40,$42,$42,$40,$0,$42,$C,$30,$0,$3C,$0,$0,$0,$0
	dc.b	$1C,$1C,$20,$3C,$42,$2,$40,$42,$42,$2,$40,$42,$24,$6,$38,$3E,$0,$2,$0,$2,$0,$4,$0,$4,$8,$30,$0,$38,$0,$0,$0,$0
	; :;<=>?@
	dc.b	$0,$0,$0,$0,$0,$0,$8,$8,$0,$0,$8,$8,$0,$0,$0,$0,$8,$8,$0,$8,$0,$8,$0,$8,$0,$0,$0,$0,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$8,$8,$0,$0,$8,$8,$0,$0,$0,$0,$8,$8,$0,$8,$0,$8,$0,$8,$0,$10,$0,$10,$0,$0,$0,$0
	dc.b	$4,$4,$0,$4,$0,$0,$8,$8,$10,$0,$10,$10,$20,$0,$20,$20,$10,$10,$0,$10,$0,$8,$0,$8,$4,$0,$0,$4,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$56,$26,$78,$7E,$0,$0,$0,$0,$0,$0,$0,$0,$72,$7C,$0,$7E,$0,$0,$0,$0,$0,$0,$0,$0
	dc.b	$0,$0,$20,$20,$0,$0,$10,$10,$0,$0,$8,$8,$4,$4,$0,$4,$8,$8,$0,$8,$10,$10,$0,$10,$0,$20,$0,$20,$0,$0,$0,$0
	dc.b	$1C,$1C,$20,$3C,$42,$2,$40,$42,$2,$2,$0,$2,$4,$4,$0,$4,$8,$8,$0,$8,$0,$0,$0,$0,$8,$0,$0,$8,$0,$0,$0,$0
	dc.b	$1C,$1C,$20,$3C,$42,$2,$40,$42,$42,$2,$48,$4A,$40,$2,$48,$4A,$4,$4,$40,$44,$40,$40,$0,$40,$E,$30,$0,$3E,$0,$0,$0,$0
	; ABCDEFGHIJKLMNOPQRSTUVWXYZ
	dc.b	$1C,$1C,$20,$3C,$42,$2,$40,$42,$42,$2,$40,$42,$40,$2,$40,$42,$1C,$1E,$60,$7E,$42,$40,$0,$42,$42,$40,$0,$42,$0,$0,$0,$0
	dc.b	$1C,$1C,$60,$7C,$42,$2,$40,$42,$42,$2,$40,$42,$64,$4,$78,$7C,$0,$2,$40,$42,$42,$40,$0,$42,$4C,$70,$0,$7C,$0,$0,$0,$0
	dc.b	$1C,$1C,$20,$3C,$42,$2,$40,$42,$40,$0,$40,$40,$40,$0,$40,$40,$0,$0,$40,$40,$42,$40,$0,$42,$C,$30,$0,$3C,$0,$0,$0,$0
	dc.b	$1C,$1C,$60,$7C,$42,$2,$40,$42,$42,$2,$40,$42,$40,$2,$40,$42,$0,$2,$40,$42,$42,$40,$0,$42,$4C,$70,$0,$7C,$0,$0,$0,$0
	dc.b	$1C,$1E,$60,$7E,$40,$0,$40,$40,$40,$0,$40,$40,$64,$4,$78,$7C,$0,$0,$40,$40,$40,$40,$0,$40,$4E,$70,$0,$7E,$0,$0,$0,$0
	dc.b	$1C,$1E,$60,$7E,$40,$0,$40,$40,$40,$0,$40,$40,$64,$4,$78,$7C,$0,$0,$40,$40,$40,$40,$0,$40,$40,$40,$0,$40,$0,$0,$0,$0
	dc.b	$1C,$1E,$20,$3E,$40,$0,$40,$40,$40,$0,$40,$40,$44,$6,$48,$4E,$0,$2,$40,$42,$42,$40,$0,$42,$E,$30,$0,$3E,$0,$0,$0,$0
	dc.b	$42,$2,$40,$42,$42,$2,$40,$42,$40,$2,$40,$42,$1C,$1E,$60,$7E,$42,$40,$0,$42,$42,$40,$0,$42,$0,$40,$0,$42,$0,$0,$0,$0
	dc.b	$26,$6,$38,$3E,$0,$0,$8,$8,$0,$0,$8,$8,$8,$8,$0,$8,$0,$8,$0,$8,$8,$0,$0,$8,$38,$0,$0,$3E,$0,$0,$0,$0
	dc.b	$2,$2,$0,$2,$2,$2,$0,$2,$0,$2,$0,$2,$0,$2,$0,$2,$2,$0,$0,$2,$42,$40,$0,$42,$38,$0,$0,$3C,$0,$0,$0,$0
	dc.b	$44,$4,$40,$44,$40,$0,$48,$48,$40,$0,$50,$50,$10,$10,$60,$70,$40,$48,$0,$48,$44,$40,$0,$44,$0,$40,$0,$42,$0,$0,$0,$0
	dc.b	$40,$0,$40,$40,$40,$0,$40,$40,$40,$0,$40,$40,$0,$0,$40,$40,$40,$40,$0,$40,$40,$40,$0,$40,$38,$40,$0,$7E,$0,$0,$0,$0
	dc.b	$2,$2,$80,$82,$46,$6,$C0,$C6,$A0,$82,$28,$AA,$90,$92,$0,$92,$82,$80,$0,$82,$2,$80,$0,$82,$0,$80,$0,$82,$0,$0,$0,$0
	dc.b	$42,$2,$40,$42,$42,$22,$60,$62,$40,$2,$50,$52,$10,$12,$40,$52,$42,$48,$0,$4A,$46,$40,$0,$46,$0,$40,$0,$42,$0,$0,$0,$0
	dc.b	$24,$4,$38,$3C,$42,$2,$40,$42,$40,$2,$40,$42,$0,$2,$40,$42,$42,$40,$0,$42,$42,$40,$0,$42,$38,$0,$0,$3C,$0,$0,$0,$0
	dc.b	$64,$4,$78,$7C,$42,$2,$40,$42,$40,$2,$40,$42,$1C,$1C,$60,$7C,$40,$40,$0,$40,$40,$40,$0,$40,$0,$40,$0,$40,$0,$0,$0,$0
	dc.b	$24,$4,$38,$3C,$42,$2,$40,$42,$40,$2,$40,$42,$0,$2,$40,$42,$52,$50,$0,$52,$4C,$40,$0,$4C,$30,$0,$0,$36,$0,$0,$0,$0
	dc.b	$64,$4,$78,$7C,$42,$2,$40,$42,$40,$2,$40,$42,$1C,$1C,$60,$7C,$40,$48,$0,$48,$44,$40,$0,$44,$0,$40,$0,$42,$0,$0,$0,$0
	dc.b	$24,$4,$38,$3C,$42,$2,$40,$42,$40,$0,$40,$40,$1C,$1C,$20,$3C,$2,$0,$0,$2,$42,$40,$0,$42,$38,$0,$0,$3C,$0,$0,$0,$0
	dc.b	$66,$6,$F8,$FE,$10,$0,$10,$10,$0,$0,$10,$10,$10,$10,$0,$10,$10,$10,$0,$10,$0,$10,$0,$10,$10,$0,$0,$10,$0,$0,$0,$0
	dc.b	$42,$2,$40,$42,$42,$2,$40,$42,$40,$2,$40,$42,$0,$2,$40,$42,$42,$40,$0,$42,$42,$40,$0,$42,$38,$0,$0,$3E,$0,$0,$0,$0
	dc.b	$42,$2,$40,$42,$42,$2,$40,$42,$40,$2,$40,$42,$0,$2,$40,$42,$42,$40,$0,$42,$4,$20,$0,$24,$18,$0,$0,$18,$0,$0,$0,$0
	dc.b	$2,$2,$80,$82,$2,$2,$80,$82,$80,$82,$0,$82,$90,$92,$0,$92,$A2,$A8,$0,$AA,$46,$C0,$0,$C6,$0,$80,$0,$82,$0,$0,$0,$0
	dc.b	$42,$2,$40,$42,$42,$2,$40,$42,$24,$4,$20,$24,$18,$18,$0,$18,$20,$24,$0,$24,$42,$40,$0,$42,$0,$40,$0,$42,$0,$0,$0,$0
	dc.b	$40,$1,$40,$41,$41,$0,$40,$41,$20,$2,$20,$22,$14,$14,$0,$14,$0,$8,$0,$8,$8,$0,$0,$8,$8,$0,$0,$8,$0,$0,$0,$0
	dc.b	$66,$6,$78,$7E,$4,$4,$0,$4,$0,$0,$8,$8,$10,$10,$0,$10,$20,$20,$0,$20,$40,$40,$0,$40,$38,$40,$0,$7E,$0,$0,$0,$0
	; [\]^_`
	dc.b	$6,$6,$18,$1E,$10,$0,$10,$10,$0,$0,$10,$10,$10,$10,$0,$10,$10,$10,$0,$10,$0,$10,$0,$10,$18,$0,$0,$1E,$0,$0,$0,$0
	dc.b	$0,$0,$80,$80,$40,$0,$40,$40,$20,$0,$20,$20,$10,$10,$0,$10,$0,$8,$0,$8,$4,$0,$0,$4,$0,$0,$0,$2,$0,$0,$0,$0
	dc.b	$60,$0,$78,$78,$0,$0,$8,$8,$0,$0,$8,$8,$8,$8,$0,$8,$0,$8,$0,$8,$8,$0,$0,$8,$38,$40,$0,$78,$0,$0,$0,$0
	dc.b	$0,$0,$10,$10,$0,$20,$28,$28,$44,$4,$40,$44,$80,$82,$0,$82,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$38,$C0,$0,$FE,$0,$0,$0,$0
	dc.b	$0,$0,$8,$8,$0,$0,$8,$8,$0,$0,$8,$8,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
	ifne	USE_LOWERCASE_FONTS
	; abcdefghijklmnopqrstuvwxyz
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$24,$4,$38,$3C,$0,$2,$0,$2,$32,$3C,$0,$3E,$42,$40,$0,$42,$38,$0,$0,$3E,$0,$0,$0,$0
	dc.b	$40,$0,$40,$40,$40,$0,$40,$40,$64,$4,$78,$7C,$0,$2,$40,$42,$42,$40,$0,$42,$42,$40,$0,$42,$38,$40,$0,$7C,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$24,$4,$38,$3C,$0,$0,$40,$40,$40,$40,$0,$40,$40,$40,$0,$40,$38,$0,$0,$3C,$0,$0,$0,$0
	dc.b	$2,$2,$0,$2,$2,$2,$0,$2,$24,$6,$38,$3E,$0,$2,$40,$42,$42,$40,$0,$42,$42,$40,$0,$42,$38,$0,$0,$3E,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$24,$4,$38,$3C,$0,$2,$40,$42,$72,$7C,$0,$7E,$40,$40,$0,$40,$38,$0,$0,$3C,$0,$0,$0,$0
	dc.b	$4,$4,$18,$1C,$0,$20,$20,$20,$64,$4,$78,$7C,$0,$0,$20,$20,$20,$20,$0,$20,$0,$20,$0,$20,$20,$0,$0,$20,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$24,$6,$38,$3E,$0,$2,$40,$42,$42,$40,$0,$42,$E,$30,$0,$3E,$0,$0,$0,$2,$1C,$1C,$60,$7C
	dc.b	$40,$0,$40,$40,$40,$0,$40,$40,$64,$4,$78,$7C,$0,$2,$40,$42,$42,$40,$0,$42,$42,$40,$0,$42,$0,$40,$0,$42,$0,$0,$0,$0
	dc.b	$0,$0,$8,$8,$0,$0,$0,$0,$0,$0,$18,$18,$8,$8,$0,$8,$0,$8,$0,$8,$8,$0,$0,$8,$38,$0,$0,$3C,$0,$0,$0,$0
	dc.b	$0,$0,$8,$8,$0,$0,$0,$0,$0,$0,$8,$8,$8,$8,$0,$8,$0,$8,$0,$8,$8,$0,$0,$8,$8,$0,$0,$8,$10,$10,$60,$70
	dc.b	$40,$0,$40,$40,$40,$0,$40,$40,$44,$4,$40,$44,$8,$8,$40,$48,$70,$70,$0,$70,$48,$40,$0,$48,$0,$40,$0,$44,$0,$0,$0,$0
	dc.b	$0,$0,$18,$18,$0,$0,$8,$8,$0,$0,$8,$8,$8,$8,$0,$8,$0,$8,$0,$8,$8,$0,$0,$8,$38,$0,$0,$3C,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$E4,$84,$68,$EC,$90,$92,$0,$92,$82,$80,$0,$82,$2,$80,$0,$82,$0,$80,$0,$82,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$64,$4,$78,$7C,$0,$2,$40,$42,$42,$40,$0,$42,$42,$40,$0,$42,$0,$40,$0,$42,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$24,$4,$38,$3C,$0,$2,$40,$42,$42,$40,$0,$42,$42,$40,$0,$42,$38,$0,$0,$3C,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$1C,$1C,$60,$7C,$42,$40,$0,$42,$42,$40,$0,$42,$0,$40,$0,$42,$1C,$1C,$60,$7C,$40,$0,$40,$40
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$1C,$1E,$20,$3E,$42,$40,$0,$42,$42,$40,$0,$42,$0,$40,$0,$42,$1C,$1E,$20,$3E,$2,$2,$0,$2
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$18,$18,$60,$78,$40,$44,$0,$44,$40,$40,$0,$40,$0,$40,$0,$40,$0,$0,$40,$40,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$1C,$1E,$20,$3E,$40,$40,$0,$40,$C,$30,$0,$3C,$0,$0,$0,$2,$1C,$1C,$60,$7C,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$10,$10,$1C,$1E,$60,$7E,$10,$10,$0,$10,$0,$10,$0,$10,$10,$0,$0,$10,$C,$C,$0,$C,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$0,$2,$40,$42,$42,$40,$0,$42,$42,$40,$0,$42,$0,$40,$0,$42,$1C,$1E,$20,$3E,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$0,$2,$40,$42,$42,$40,$0,$42,$42,$40,$0,$42,$20,$0,$0,$24,$18,$18,$0,$18,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$80,$82,$0,$82,$82,$80,$0,$82,$2,$80,$0,$82,$10,$40,$0,$54,$8,$8,$20,$28,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$0,$2,$40,$42,$20,$24,$0,$24,$8,$10,$0,$18,$20,$0,$0,$24,$0,$2,$40,$42,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$0,$2,$40,$42,$42,$40,$0,$42,$42,$40,$0,$42,$38,$0,$0,$3E,$0,$2,$0,$2,$64,$4,$78,$7C
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$1C,$1C,$60,$7C,$0,$8,$0,$8,$0,$10,$0,$10,$20,$0,$0,$20,$1C,$1E,$60,$7E,$0,$0,$0,$0
	; {|}~
	dc.b	$6,$6,$8,$E,$0,$0,$10,$10,$10,$10,$0,$10,$20,$20,$0,$20,$0,$10,$0,$10,$10,$0,$0,$10,$C,$E,$0,$E,$0,$0,$0,$0
	dc.b	$10,$0,$10,$10,$0,$0,$10,$10,$10,$10,$0,$10,$10,$10,$0,$10,$0,$10,$0,$10,$10,$0,$0,$10,$10,$10,$0,$10,$0,$0,$10,$10
	dc.b	$50,$20,$70,$70,$0,$0,$8,$8,$8,$8,$0,$8,$0,$4,$0,$4,$8,$0,$0,$8,$8,$0,$0,$8,$10,$10,$60,$70,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$60,$0,$60,$60,$90,$92,$0,$92,$92,$90,$0,$92,$C,$0,$0,$C,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
	endc	; USE_LOWERCASE_FONTS
	even

***************************************************************************
*
* 8. BSS
*
***************************************************************************

	section	bss

	; Descriptor used for the color fade (linear interpolation).
fade_desc
fadein_desc
	ds.l	3*16            ; R/G/B values
fadein_deltas
	ds.l	3*16            ; R/G/B deltas

	; Loader stack.
stack_bottom
	ds.b	STACK_SIZE
stack_top

	; Program end.
pt_end
	end
