***************************************************************************
*
* Safari Guns 100% - with game intro & multi-languages support
*
* Cracked, mega-trained, partly-filed, packed, linked, ramdisk, bug-fixed.
* 512KB, hard-drive and Falcon support.
*
* December 25, 2018 - Orion of The Replicants.
*
* The following code is fully documented and freely distributed
* for didactic purposes.
* It is a record of how games were cracked and packed on Atari ST
* in the golden age of microcomputers.
*
* This code is the loader of the game. It provides:
* - a small intro which prints a presentation text using fancy fonts
*   and which enables to select trainer options;
* - the patching, at runtime, of the intro and the main binaries of the
*   game in order to remove the copy-protections, to enable the trainer
*   mode and to fix several bugs;
* - the support of the library file containing all packed game files
*   linked together (game files are loaded from this library and depacked
*   on-the-fly).
*
* The source code is organized as follows: 
*  1. Main entry point
*  2. XBIOS Routines
*  3. GEMDOS Routines & helper routines
*  4. Game files loading/depacking/single-file support
*  5. Game patching at runtime (cracking, bug-fixing & trainer)
*  6. De-initialization routines
*  7. Resident data: system backup/init/restoring
*  8. Resident data: loading & depacking of game files
*  9. Resident data: game patching at runtime (cracking & trainer)
* 10. Non-resident code: initialization routines
* 11. Non-resident code: intro
* 12. Non-resident data: intro
*
* The copy-protection of the game and the techniques to make this
* advanced crack are detailed in section
*  5. Game patching at runtime (cracking, bug-fixing & trainer)
*
* Credits:
* All hacking & this loader's code by Orion / The Replicants
* Original supplied by Brume / Atari Legend
* This loader's fonts by Walt (L'Ing), first used in Fury's "Bloody" intro
* Xmas intro code by Kelly.X / HMD
* Xmas intro graphics by Dieu / HMD
* Xmas intro music by DMA-SC
* Xmas intro fonts by MacDos / Fuzion
* Atomik 3.5 unpacking routine by Altair / VMAX
* UPX packer by The UPX Team
*
* Git repository: https://github.com/orionfuzion/newcracks
* Contact:        orion.replicants@gmail.com or orion.fuzion@gmail.com
*
* This 'LOADER.S' ASM source file should be built (assembled) using Devpac
* as an executable program named 'LOADER.68K'.
*
***************************************************************************

***************************************************************************
* 1. Main entry point
***************************************************************************

	; Loader (this program) operating mode.
	; The loader executes a combination of actions
	; described as a bitwise-OR of the following constants.
CONFIG_INTINTRO	=	1
CONFIG_PROG1	=	2
CONFIG_PROG2	=	3
CONFIG_RAMDISK	=	4
CONFIG_WAIT	=	5
CONFIG_NODEINIT	=	6
CONFIG_ERROR	=	7

_CONFIG1 	=	(1<<CONFIG_INTINTRO)
_CONFIG2	=	_CONFIG1
;_CONFIG2	=	(1<<CONFIG_PROG1)!_CONFIG1
;_CONFIG2	=	(1<<CONFIG_PROG2)!_CONFIG1
_CONFIG3	=	(1<<CONFIG_WAIT)!_CONFIG2
CONFIG_DEFAULT	=	_CONFIG3

STACK_SIZE	=	512

	opt	o+,p+,c-

	; Program entry point.
pt_base
	lea	base_page(pc),a0
	move.l	4(a7),(a0)
	lea	stack_top(pc),a7

	; Get operating mode (the config).
	lea	get_config(pc),a0
	bsr	supexec
	movea.l	config_p(pc),a0
	; d5 = Loader operating mode.
	move.l	(a0),d5

	; a5 = global file info structure.
	lea	file_info(pc),a5

	; Save exception vectors.
	lea	save_vecs(pc),a0
	bsr	supexec

	; Machine backup & setup.
	lea	mach_setup(pc),a0
	bsr	supexec

	; Check if screen resolution is valid.
	movea.l	mach_conf_p(pc),a0
	tst	MACH2SCREEN+REZ_INVALID(a0)
	beq.s	run_intintro
	lea	txt_rez(pc),a0
	bsr	print
	bsr	readchar
	bra	error

	; Run internal intro.
run_intintro
	btst	#CONFIG_INTINTRO,d5
	beq.s	prt_wait
	lea	intro(pc),a0
	bsr	supexec

	; Print "please wait".
	; Reload config on purpose, as it may have been
	; modified by the internal intro.
prt_wait
	movea.l	config_p(pc),a0
	move.l	(a0),d5
	btst	#CONFIG_WAIT,d5
	beq.s	select_prog1
	lea	print_wait(pc),a0
	bsr	supexec

	; Select game program1.
select_prog1
	btst	#CONFIG_PROG1,d5
	beq.s	select_prog2
	lea	lnkprog1(pc),a0
	lea	dirprog1(pc),a1
	lea	dirprog1_end(pc),a2
	bra.s	prep_prog

	; Select game program2.
select_prog2
	btst	#CONFIG_PROG2,d5
	beq.s	deinit
	lea	lnkprog2(pc),a0
	lea	dirprog2(pc),a1
	lea	dirprog2_end(pc),a2

	; Prepare selected program's library file handling.
prep_prog
	bsr	lnkfile_prep
	tst.l	d0
	bmi.s	error

	; Adjust memory allocation.
	movea.l	base_page(pc),a0
	movea.l	d0,a1
	bsr.s	prog_mshrink

	; Install loading/depacking trap.
	lea	inst_trap1_depack(pc),a0
	bsr.s	supexec

	; Install patching trap.
	lea	inst_vecs_crack(pc),a0
	bsr.s	supexec

	; Run the game program.
	move.l	LNK_NAME(a5),a0
	bsr	pexec
	tst.l	d0
	bmi.s	error

	; Start de-initialization.
deinit
	; Close the library file.
	bsr	lnkfile_close

	; Restore machine state.
rest_mach
	btst	#CONFIG_NODEINIT,d5
	bne.s	rest_vecs
	lea	mach_restore(pc),a0
	bsr.s	supexec

	; Restore exception vectors.
rest_vecs
	lea	restore_vecs(pc),a0
	bsr.s	supexec

	; Return to the parent program.
quit
	clr.w	-(sp)
	trap	#1

	; An error has occurred, cleanup and terminate.
error
	movea.l	config_p(pc),a0
	move.l	#(1<<CONFIG_ERROR),d5
	move.l	d5,(a0)
	bra.s	deinit

	; prog_mshrink()
	; Adjust TPA to program's needs.
	; in
	;   a0: base page address
	;   a1: start of free memory (end of resident data)
	; out
	;   d0: GEMDOS error
prog_mshrink
	movem.l	a1-a2,-(a7)

	movea.l	8(a0),a2
	adda.l	12(a0),a2
	adda.l	20(a0),a2
	adda.l	28(a0),a2

	move.l	a1,d0
	add.l	#16,d0
	cmp.l	d0,a2
	bhi.s	clear_data
	move.l	d0,a2
clear_data
	clr.l	(a1)+
	cmp.l	a1,a2
	bhi.s	clear_data

	movem.l	(a7)+,a1-a2

	sub.l	a0,d0
	bsr.s	mshrink

	rts

***************************************************************************
* 2. XBIOS Routines
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
* 3. GEMDOS Routines & helper routines
***************************************************************************

	; Original (non-hijacked) GEMDOS access.
	; Original trap#1 vector is saved in trap#11.
TRAP_GEMDOS	macro
	trap	#11
	endm

	; mshrink()
	; Reduce already reserved memory.
	; in
	;   d0: new size
	;   a0: start address
	; out
	;   d0: GEMDOS error
mshrink
	movem.l	d1-d2/a0-a2,-(a7)

	move.l	d0,-(sp)
	pea	(a0)
	move.l	#$4a0000,-(sp)
	TRAP_GEMDOS
	lea	$c(sp),sp

  	movem.l	(a7)+,d1-d2/a0-a2
	rts

	; print()
	; Write a string to the standard output device (Cconws).
	; in
	;   a0: string address
	;
print
	movem.l	d0-d2/a0-a2,-(a7)

	pea	(a0)
	move.w	#9,-(sp)
	TRAP_GEMDOS
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
	TRAP_GEMDOS
	addq.l	#2,sp

  	movem.l	(a7)+,d1-d2/a0-a2
	rts

	; basename()
	; Strip directory from filename.
	; in
	;   a0: filename
	; out
	;   a0: stripped filename
basename
	move.l	a1,-(a7)

	move.l	a0,a1
bnam_s1	tst.b	(a0)+
	bne.s	bnam_s1
bnam_s2	cmp.b	#'\',-(a0)
	beq.s	bnam_s3
	cmp.b	#':',(a0)
	beq.s	bnam_s3
	cmp.l	a0,a1
	beq.s	bnam_s4
	bra.s	bnam_s2
bnam_s3	addq.l	#1,a0

bnam_s4	move.l	(a7)+,a1
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
	TRAP_GEMDOS
	lea	16(sp),sp

  	movem.l	(a7)+,d1-d2/a0-a2
  	rts

	; fopen()
	; Open a file.
	; in
	;   a0: filename
	; out
	;   d0: file handle or GEMDOS error
fopen
	movem.l	d1-d2/a0-a2,-(a7)

	clr.w	-(a7)
	pea	(a0)
	move.w	#$3d,-(a7)
	TRAP_GEMDOS
	addq.l	#8,a7

	movem.l	(a7)+,d1-d2/a0-a2
	rts

	; fcreate()
	; Create a file.
	; in
	;   d0: file attribute
	;   a0: filename
	; out
	;   d0: file handle or GEMDOS error
fcreate
	movem.l	d1-d2/a0-a2,-(a7)

	move.w	d0,-(a7)
	pea	(a0)
	move.w	#$3c,-(a7)
	TRAP_GEMDOS
	addq.l	#8,a7

	movem.l	(a7)+,d1-d2/a0-a2
	rts

	; fseek()
	; Move file position pointer.
	; in
	;   d0: file handle
	;   d1: new file offset (from start of file)
	; out
	;   d0: actual file offset or GEMDOS error
fseek
	movem.l	d1-d2/a0-a2,-(a7)

	clr.w	-(sp)
	move.w	d0,-(a7)
	move.l	d1,-(a7)
	move.w	#$42,-(a7)
	TRAP_GEMDOS
	lea	10(a7),a7

	movem.l	(a7)+,d1-d2/a0-a2
	rts

	; fread()
	; Read from a file.
	; in
	;   d0: file handle
	;   d1: number of bytes of data to read
	;   a0: address of the receiving buffer
	; out
	;   d0: number of bytes actually read or GEMDOS error
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

	; fclose()
	; Close a file.
	; in
	;   d0: file handle
	; out
	;   d0: GEMDOS error
fclose
	movem.l	d1-d2/a0-a2,-(a7)

	move.w	d0,-(a7)
	move.w	#$3e,-(a7)
	TRAP_GEMDOS
	addq.l	#4,a7

	movem.l	(a7)+,d1-d2/a0-a2
	rts

	; mcopy()
	; Copy a memory area.
	; in
	;   d0: number of bytes to copy
	;   a0: memory area source 
	;   a1: memory area destination
mcopy
	movem.l	d0-d1/a0-a1,-(a7)

	cmp.l	#32,d0
	blo.s	mcopy_slow
	move.l	a0,d1
	btst	#0,d1
	beq.s	mcopy_src_even
	move.b	(a0)+,(a1)+
	subq.l	#1,d0
	move.l	a0,d1
mcopy_src_even
	add.l	a1,d1
	btst	#0,d1
	bne.s	mcopy_slow_lp
	move.l	d0,d1
	and.l	#31,d0
	asr	#5,d1
	beq.s	mcopy_long
	movem.l	d2-d7/a2-a3,-(a7)
mcopy_chunk_lp
	movem.l	(a0)+,d2-d7/a2-a3
	movem.l	d2-d7/a2-a3,(a1)
	lea	32(a1),a1
	subq.l	#1,d1
	bne.s	mcopy_chunk_lp
	movem.l	(a7)+,d2-d7/a2-a3
mcopy_long
	move.l	d0,d1
	and.l	#3,d0
	asr	#2,d1
	beq.s	mcopy_slow
mcopy_long_lp
	move.l	(a0)+,(a1)+
	subq.l	#1,d1
	bne.s	mcopy_long_lp
mcopy_slow
	tst.l	d0
	beq.s	mcopy_end
mcopy_slow_lp
	move.b	(a0)+,(a1)+
	subq.l	#1,d0
	bne.s	mcopy_slow_lp
mcopy_end
	movem.l	(a7)+,d0-d1/a0-a1
	rts

***************************************************************************
* 4. Game files loading/depacking/single-file support
***************************************************************************

	; lnkfile_prep()
	; Prepare the library (linked) file containing all packed
	; game files for on-the-fly loading and depacking using
	; hijacked GEMDOS trap.
	; - Open the library file and save the handle in the
	;   global file info.
	; - Initialize the global file info.
	; - Install (copy) the library file directory (list of
	;   linked game files) to the appropriate destination area.
	; - Reserve memory for the file loading/depacking cache.
	; - Load the library file into ram (aka ramdisk) if enough
	;   RAM is available.
	; - Return the start address of the free memory of the
	;   current program after all necessary allocations have
	;   been performed.
	; in
	;   d5: loader operating mode
	;   a0: library filename
	;   a1: start of library file directory
	;   a2: end of library file directory
	;   a5: global file info
	; out
	;   d0: start of free memory or GEMDOS error
	;   The global file info is updated accordingly
lnkfile_prep
	movem.l	d1-d2/a0-a4,-(a7)

	; Open the library.
	bsr	fopen
	tst.w	d0
	bmi	lnkfile_prep_ret

	; Initialize the global file info used to handle
	; on-the-fly loading/depacking of a single game file
	; (simultaneous game files loading is not supported).
	moveq.l	#0,d1
	move.w	d1,LNK_ENABLED(a5)
	move.l	a0,LNK_NAME(a5)
	move.w	d0,LNK_HANDLE(a5)
	move.w	#-1,LNK_XHANDLE(a5)
	move.l	d1,LNK_RAM_OFF(a5)
	move.l	d1,LNK_RAM_ADDR(a5)
	move.w	#-1,FILE_HANDLE(a5)
	move.l	d1,FILE_LNKOFFSET(a5)
	move.l	d1,FILE_OFFSET(a5)
	move.l	d1,FILE_PACKSIZE(a5)
	move.l	d1,FILE_SIZE(a5)
	move.w	d1,FILE_NODEPACK(a5)
	move.w	d1,FILE_NOCACHE(a5)
	move.w	d1,FILE_CACHED(a5)

	; Copy the library directory to the beginning of the free
	; resident data memory.
	suba.l	a1,a2
	lea	resident_data_next(pc),a3
	movea.l	a3,a4
	adda.l	a2,a4

	move.l	a3,LNK_DIR(a5)
	move.l	a4,LNK_DIR_END(a5)
lnkdir_cp
	move.l	(a1)+,(a3)+
	cmp.l	a3,a4
	bhi.s	lnkdir_cp
	clr.l	(a3)+

	; Determine the size of the loading/depacking cache and
	; allocate/initialize it in the free resident data memory
	; (following the previously copied library directory).
	move.l	a3,FILE_CACHE_BUF(a5)

	bsr.s	lnkfile_cache_size

	add.l	#$100,d0
	asr	#2,d0
lnkcache_clear
	clr.l	(a3)+
	dbf	d0,lnkcache_clear

	move.l	a3,d0

	; Check if the library file should be loaded into RAM.
	btst	#CONFIG_RAMDISK,d5
	beq.s	lnkfile_prep_ret

	; Load the library file into RAM if enough memory
	; is available (following the previously allocated
	; cache).
	movea.l	base_page(pc),a0
	; d1=end of TPA
	move.l	4(a0),d1
	; d1=free memory size
	sub.l	d0,d1
	cmp.l	#(1024-128)*1024,d1
	bcs.s	lnkfile_prep_ret

	movea.l	d0,a0
	bsr.s	lnkfile_load_ram
	tst.l	d0
	bmi.s	lnkfile_prep_ret

	add.l	a0,d0
	add.l	#16,d0
	and.l	#-2,d0

lnkfile_prep_ret
	; Return the start address of the free memory
	; of the current program (corresponding to the end
	; of the resident data).
  	movem.l	(a7)+,d1-d2/a0-a4
	rts

	; lnkfile_cache_size()
	; Determine the size of the loading/depacking cache.
	; Walk through the library directory to find game files
	; which need to be cached and get the maximum size of
	; these files once depacked.
	; in
	;   a5: global file info
	; out
	;   d0: cache size in bytes
lnkfile_cache_size
	movem.l	d1/a0-a1,-(a7)

	movea.l	LNK_DIR(a5),a0
	movea.l	LNK_DIR_END(a5),a1	
	moveq.l	#0,d0

lf_cache_size_next
	tst.b	(a0)+
	bne.s	lf_cache_size_next
	move.l	a0,d1
	addq.l	#1,d1
	and.l	#-2,d1
	movea.l	d1,a0
	move.l	4(a0),d1
	; Bit 28 is set in the packed size if the game file
	; needs to be cached.
	btst	#28,d1
	beq.s	lf_nocachesz
	move.l	8(a0),d1
	cmp.l	d0,d1
	bls.s	lf_nocachesz
	move.l	d1,d0
lf_nocachesz
	lea	12(a0),a0
	cmp.l	a0,a1
	bhi.s	lf_cache_size_next

	movem.l	(a7)+,d1/a0-a1
	rts

	; lnkfile_load_ram()
	; Load the library file into ram.
	; in
	;   a0: receiving buffer
	;   a5: global file info
	; out
	;   d0: loaded data size or GEMDOS error
	;   The global file info is updated with ramdisk info
lnkfile_load_ram
	movem.l	d1/a1,-(a7)

	; Skip game executable (first in the library,
	; followed by game data files).
	movea.l	LNK_DIR(a5),a1
lnkfile_prg_lp
	tst.b	(a1)+
	bne.s	lnkfile_prg_lp
	move.l	a1,d0
	addq.l	#1,d0
	and.l	#-2,d0
	move.l	d0,a1

	move.w	LNK_HANDLE(a5),d0
	move.l	4(a1),d1	; packed game prg size
	bsr	fseek
	tst.l	d0
	bmi.s	lnkfile_load_ram_ret

	move.w	LNK_HANDLE(a5),d0
	move.l	#$fffff,d1	; max size
	bsr	fread
	tst.l	d0
	bmi.s	lnkfile_load_ram_ret

	; Update the global file info with ramdisk info:
	; - offset of game data files in the library file (they
	;   follow the game prg which is not loaded into ram).
	; - start address of the ramdisk.
	move.l	4(a1),LNK_RAM_OFF(a5)
	move.l	a0,LNK_RAM_ADDR(a5)

lnkfile_load_ram_ret
	movem.l	(a7)+,d1/a1	
	rts

	; lnkfile_close()
	; Close (stop using) the library file.
	; in
	;   a5: global file info
	; out
	;   d0: GEMDOS error
	;   The global file info is updated accordingly
lnkfile_close
	move.w	LNK_HANDLE(a5),d0
	bmi.s	lf_xhdl_close
	bsr	fclose
lf_xhdl_close
	move.w	LNK_XHANDLE(a5),d0
	bmi.s	lf_close_ret
	bsr	fclose
lf_close_ret
	move.w	#-1,LNK_HANDLE(a5)
	move.w	#-1,LNK_XHANDLE(a5)
	move.w	#-1,FILE_HANDLE(a5)
	rts

	; lnkfile_read()
	; Read a game file from the library file or
	; from the ramdisk (if available).
	; in
	;   d0: size of data to read
	;   d1: offset from the start of the game file
	;   a0: receiving buffer
	;   a5: global file info
	; out
	;   d0: actual size of read data or GEMDOS error
lnkfile_read
	tst.l	LNK_RAM_ADDR(a5)
	bne.s	lnkfile_ramcopy

	; Read from the library file
	movem.l	d1-d2,-(a7)

	move.l	d0,d2

	; Adjust library file offset.
	move.w	LNK_HANDLE(a5),d0
	add.l	FILE_LNKOFFSET(a5),d1
lnkfile_fseek_retry
	bsr	fseek

	cmp.l	#-37,d0
	beq.s	lnkfile_inv_handle
	tst.l	d0
	bmi.s	lnkfile_read_ret

	; Read data.
	move.w	LNK_HANDLE(a5),d0
	move.l	d2,d1
	bsr	fread
lnkfile_read_ret
	movem.l	(a7)+,d1-d2
	rts

	; The library file handle may become invalid after
	; the pexec call.
	; It happens only if the library file is on a hard disk.
	; It's not clear if this behavior is TOS-specific or
	; emulator-specific.
	; In any case, try to reopen the library file to get
	; a new valid handle.
lnkfile_inv_handle
	move.l	a0,-(a7)
	move.l	LNK_NAME(a5),a0
	bsr	fopen
	move.l	(a7)+,a0
	ext.l	d0
	bmi.s	lnkfile_read_ret
	move.w	LNK_HANDLE(a5),LNK_XHANDLE(a5)
	move.w	d0,LNK_HANDLE(a5)
	bra.s	lnkfile_fseek_retry

	; Read from the ramdisk.
lnkfile_ramcopy
	movem.l	d1/a0-a1,-(a7)

	movea.l	a0,a1
	add.l	FILE_LNKOFFSET(a5),d1
	sub.l	LNK_RAM_OFF(a5),d1
	movea.l	LNK_RAM_ADDR(a5),a0
	adda.l	d1,a0
	bsr	mcopy

	movem.l	(a7)+,d1/a0-a1
	rts

	; inst_trap1_depack()
	; Hijack the GEMDOS trap to enable on-the-fly loading and
	; depacking of game data files.
	; Called from supexec.
	; Out:
	;   d0: return value
	; Scratch: a0-a2
inst_trap1_depack
	lea	trap1(pc),a0
	lea	tr1_jump+2(pc),a1
	move.l	$84.w,(a1)
	move.l	a0,$84.w

	; Fix the size of the trap exception stack frame
	lea	tr1_sf_sz(pc),a1
	move.l	vecs_conf+TRAP_SF_SIZE(pc),d0
	add.w	d0,2(a1)

	moveq.l	#0,d0
	rts

	; trap1()
	; Loader trap#1 handler.
	; Handle on-the-fly loading & depacking of game files.
	; Jump to the original GEMDOS trap handler for any other
	; GEMDOS operations.
	; Called from exception.
trap1
	movem.l	d1-d7/a0-a6,-(a7)

	lea	file_info(pc),a5
	tst.w	LNK_ENABLED(a5)
	beq.s	tr1_cont
tr1_sf_sz
	; Get stack pointer of interrupted mode
	lea	((4*14)+0)(a7),a0
	btst	#13,(4*14)(a7)
	bne.s	tr1_sup
	move.l	usp,a0
tr1_sup

	; Check GEMDOS operations that need to be "simulated".
tr1_tst_fopen
	cmpi.w	#$3d,(a0)
	bne.s	tr1_tst_fcreate
	bsr.s	tr1_fopen
	bra.s	tr1_check

tr1_tst_fcreate
	cmpi.w	#$3c,(a0)
	bne.s	tr1_tst_fread
	bsr	tr1_fcreate
	bra.s	tr1_check

tr1_tst_fread
	cmpi.w	#$3f,(a0)
	bne.s	tr1_tst_fclose
	bsr	tr1_fread
	bra.s	tr1_check

tr1_tst_fclose
	cmpi.w	#$3e,(a0)
	bne.s	tr1_tst_fseek
	bsr	tr1_fclose
	bra.s	tr1_check

tr1_tst_fseek
	cmpi.w	#$42,(a0)
	bne.s	tr1_cont
	bsr	tr1_fseek

	; Return from exception if d1 is positive,
	; or jump to native GEMDOS code otherwise.
tr1_check
	tst.l	d1
	bmi.s	tr1_cont

	; Return from exception, do not call GEMDOS.
tr1_stop
	movem.l	(a7)+,d1-d7/a0-a6
	rte

	; Let GEMDOS handle the operation.
tr1_cont
	movem.l	(a7)+,d1-d7/a0-a6
tr1_jump
	jmp	$0.l

	; Called to indicate the operation shall be handled
	; by the GEMDOS.
tr1_op_unhandled
	moveq.l	#-1,d1
	rts

	; Called to indicate that the operation failed
	; and that the failure shall be notified to the invoker.
	; In that case, 'Invalid file handle' is returned.
tr1_op_error
	moveq.l	#-37,d0
	moveq.l	#0,d1
	rts

	; tr1_fopen()
	; Perform/simulate the fopen of a game file.
	; in
	;   a0: invoker stack pointer
	;   a5: global file info
	; out
	;   d0: file handle or GEMDOS error
	;   d1: a positive value indicates the operation has
	;       been handled, a negative value indicates the
	;       GEMDOS shall handle the operation
tr1_fopen
	; The current implementation handles only one opened
	; file at a time.
	tst.w	FILE_HANDLE(a5)
	bpl.s	tr1_op_unhandled

	; Strip directory and drive letter from the filename.
	movea.l	2(a0),a0
	bsr	basename

	; Parse the library file directory to find
	; the stripped filename.
	movea.l	a0,a1
	movea.l	LNK_DIR(a5),a2
	movea.l	LNK_DIR_END(a5),a3

s_loop	move.b	(a1)+,d1
	bne.s	s_upper
	tst.b	(a2)
	beq.s	s_ok
	bra.s	s_next
s_upper	cmp.b	#'a',d1
	bcs.s	s_cmp
	cmp.b	#'z',d1
	bhi.s	s_cmp
	and.b	#$5f,d1
s_cmp	cmp.b	(a2)+,d1
	beq.s	s_loop

s_next	tst.b	(a2)+
	bne.s	s_next
	move.l	a2,d1
	add.l	#12+1,d1
	and.l	#-2,d1
	movea.l	d1,a2
	movea.l	a0,a1
	cmp.l	a2,a3
	bhi.s	s_loop

	; If the game file is not in the library file,
	; execute the standard fopen operation using
	; the stripped filename (it allows the game
	; to be executed from any drive/folder).
	bsr	fopen
	bra.s	tr1_fopen_ret

s_ok	; The filename has been found, update the global
	; file info with the relevant information.
	move.l	a2,d1
	addq.l	#2,d1
	and.l	#-2,d1
	movea.l	d1,a0

	moveq.l	#0,d0
	move.l	d0,FILE_OFFSET(a5)
	move.w	d0,FILE_NODEPACK(a5)
	move.w	d0,FILE_NOCACHE(a5)
	move.w	d0,FILE_CACHED(a5)
	move.w	LNK_HANDLE(a5),d0
	move.w	d0,FILE_HANDLE(a5)
	move.l	(a0)+,FILE_LNKOFFSET(a5)
	move.l	(a0)+,d1
	btst	#28,d1
	seq	FILE_NOCACHE(a5)
	and.l	#$FFFFFFF,d1
	move.l	d1,FILE_PACKSIZE(a5)
	move.l	(a0),FILE_SIZE(a5)
tr1_fopen_ret
	; The fopen operation has been handled, do not call GEMDOS.
	moveq.l	#0,d1
	rts

	; tr1_fcreate()
	; Perform/simulate the fcreate of a game file.
	; in
	;   a0: invoker stack pointer
	;   a5: global file info
	; out
	;   d0: file handle or GEMDOS error
	;   d1: 0 to indicate that the operation has been handled
tr1_fcreate
	move.w	6(a0),d0
	movea.l	2(a0),a0
	; Strip the filename.
	bsr	basename
	bsr	fcreate
	moveq.l	#0,d1
	rts

	; tr1_fread()
	; Perform/simulate the fread of a game file.
	; in
	;   a0: invoker stack pointer
	;   a5: global file info
	; out
	;   d0: actual size of read data or GEMDOS error
	;   d1: a positive value indicates the operation has
	;       been handled, a negative value indicates the
	;       GEMDOS shall handle the operation
tr1_fread	
	; Check if the file handle matches the currently opened
	; game file.
	tst.w	FILE_HANDLE(a5)
	bmi	tr1_op_unhandled
	move.w	2(a0),d1
	cmp.w	FILE_HANDLE(a5),d1
	bne	tr1_op_unhandled

	; A game file may be read in multiple chunks rather than
	; all at once. It may also be read non-sequentially.
	; In such case, the game file need to be entirely loaded
	; in a dedicated cache in order to be depacked in that
	; cache. Then the requested chunk can be copied to the
	; actual destination.

	; Test if game file is tagged as to be cached or not.
	tst.w	FILE_NOCACHE(a5)
	bne.s	tr1_fread_nocache

	; Game file is read/depacked through the cache.
	bsr.s	tr1_cached_read
	bra.s	tr1_fread_ret

tr1_fread_nocache
	; Game file is loaded to its final destination and
	; depacked in place.
	bsr.s	tr1_uncached_read
tr1_fread_ret
	moveq.l	#0,d1
	rts

	; tr1_uncached_read()
	; Read/unpack a game file directly into the
	; destination area.
	; in
	;   a0: invoker stack pointer
	;   a5: global file info
	; out
	;   d0: actual size of read data or GEMDOS error
tr1_uncached_read
	movem.l	d1/a0,-(a7)

	; d0: requested size.
	move.l	4(a0),d0
	; d1: current file offset.
	move.l	FILE_OFFSET(a5),d1
	; d0: file offset after read (expected end of read).
	add.l	d1,d0
	; End of read should not exceed packed file size.
	cmp.l	FILE_PACKSIZE(a5),d0
	bls.s	tr1_uncached_notrunc1
	move.l	FILE_PACKSIZE(a5),d0
tr1_uncached_notrunc1
	; d0: actual size of data to read.
	sub.l	d1,d0
	bpl.s	tr1_uncached_notrunc2
	moveq.l	#0,d0
tr1_uncached_notrunc2

	; a0: receiving buffer.
	movea.l	8(a0),a0
	bsr	lnkfile_read
	tst.l	d0
	bmi.s	tr1_uncached_ret

	; Check if depacking is disabled (and possibly
	; handled by the invoker).
	tst.w	FILE_NODEPACK(a5)
	bne.s	tr1_uncached_ret

	; Depack data in place.
	bsr	depack
	; d0: unpacked data size.

	; Update current file offset.
	add.l	d0,FILE_OFFSET(a5)
tr1_uncached_ret
	movem.l	(a7)+,d1/a0
	rts

	; tr1_cached_read()
	; Read/unpack a game file through the cache.
	; in
	;   a0: invoker stack pointer
	;   a5: global file info
	; out
	;   d0: actual size of read data or GEMDOS error
tr1_cached_read
	movem.l	d1/a0-a3,-(a7)
	
	movea.l	a0,a3
	movea.l	FILE_CACHE_BUF(a5),a0

	; File already loaded in the cache ?
	tst.w	FILE_CACHED(a5)
	bne.s	tr1_cached_copy

	; Read the packed file in the cache.
	move.l	FILE_PACKSIZE(a5),d0
	moveq.l	#0,d1
	bsr	lnkfile_read
	tst.l	d0
	bmi.s	tr1_cached_ret

	; Depack the loaded file.
	bsr	depack

	; Cache can be reused for future reads.
	move.w	#1,FILE_CACHED(a5)

	; Copy the requested file chunk.
tr1_cached_copy
	movea.l	a0,a2
	; a2: end of file in cache.
	adda.l	FILE_SIZE(a5),a2
	; a0: start of read in cache.
	adda.l	FILE_OFFSET(a5),a0
	movea.l	a0,a1
	; a1: end of read in cache.
	adda.l	4(a3),a1
	cmp.l	a1,a2
	bhi.s	tr1_cached_notrunc
	movea.l	a2,a1
tr1_cached_notrunc
	move.l	a1,d0
	; d0: actual size of data to read/copy.
	sub.l	a0,d0
	bpl.s	tr1_cached_notrunc2
	moveq.l	#0,d0
tr1_cached_notrunc2
	; a1: receiving/destination buffer.
	movea.l	8(a3),a1
	bsr	mcopy
	; d0: read data size.

	; Update current file offset.
	add.l	d0,FILE_OFFSET(a5)
tr1_cached_ret
	movem.l	(a7)+,d1/a0-a3
	rts

	; tr1_close()
	; Close the currently opened game file.
	; in
	;   a0: invoker stack pointer
	;   a5: global file info
	; out
	;   d0: E_OK or GEMDOS error
tr1_fclose
	; Check if the file handle matches the currently opened
	; game file.
	tst.w	FILE_HANDLE(a5)
	bmi	tr1_op_unhandled
	move.w	2(a0),d1
	cmp.w	FILE_HANDLE(a5),d1
	bne	tr1_op_unhandled

	; Reset the global file info meta-data.
	moveq.l	#0,d0
	move.w	#-1,FILE_HANDLE(a5)
	move.l	d0,FILE_LNKOFFSET(a5)
	move.l	d0,FILE_OFFSET(a5)
	move.l	d0,FILE_PACKSIZE(a5)
	move.l	d0,FILE_SIZE(a5)
	move.w	d0,FILE_NODEPACK(a5)
	move.w	d0,FILE_NOCACHE(a5)
	move.w	d0,FILE_CACHED(a5)

	move.l	d0,d1
	rts

	; tr1_fseek()
	; Perform/simulate the fseek of a game file.
	; in
	;   a0: invoker stack pointer
	;   a5: global file info
	; out
	;   d0: new file position or GEMDOS error
	;   d1: a positive value indicates the operation has
	;       been handled, a negative value indicates the
	;       GEMDOS shall handle the operation
tr1_fseek
	; Check if the file handle matches the currently opened
	; game file.
	tst.w	FILE_HANDLE(a5)
	bmi	tr1_op_unhandled
	move.w	6(a0),d1
	cmp.w	FILE_HANDLE(a5),d1
	bne	tr1_op_unhandled

	; d1: requested file offset.
	move.l	2(a0),d1
fseek_start
	; From start of file. 
	cmp.w	#0,8(a0)
	beq.s	fseek_cont
fseek_cur
	; From current position.
	cmp.w	#1,8(a0)
	bne.s	fseek_end
	add.l	FILE_OFFSET(a5),d1
	bra.s	fseek_cont
fseek_end
	; From end of file.
	cmp.w	#2,8(a0)
	bne	tr1_op_error
	sub.l	FILE_SIZE(a5),d1
	neg.l	d1
fseek_cont
	; File offset cannot be negative.
	tst.l	d1
	bpl.s	fseek_noneg
	moveq.l	#0,d1
	bra.s	fseek_notrunc
fseek_noneg
	; Truncate file offset if greater than
	; unpacked file size.
	cmp.l	FILE_SIZE(a5),d1
	bls.s	fseek_notrunc
	move.l	FILE_SIZE(a5),d1
fseek_notrunc
	; Update current file offset.
	move.l	d1,FILE_OFFSET(a5)

	move.l	d1,d0
	moveq.l	#0,d1
	rts

	; depack()
	; Atomik 3.5 unpacking routine by Altair / VMAX.
	; in
	;   a0: start address of packed data
	; out
	;   d0: unpacked size

MODE:         	EQU	1       	; a0 = src = dst
PIC_ALGO:     	EQU	0       	; no pic algo
DEC_SPACE:    	EQU	$100-$1c	; decrunch space = $100
RESTORE_SPACE:	EQU	1       	; restore decrunch space

depack:	movem.l	d0-a6,-(a7)
	cmp.l	#"ATM5",(a0)+
	bne	not_packed
	move.l	(a0),(a7)
	link	a2,#-28
	move.l	(a0)+,d0
	ifne	MODE
	lea	4(a0,d0.l),a5
	move.l	d0,-(a7)
	elseif
	move.l	a1,a5
	add.l	d0,a5
	endc
	move.l	a5,a4
	ifne	MODE
	ifne	DEC_SPACE
	lea	DEC_SPACE(a4),a5
	endc
	endc
	lea	-$c(a4),a4
	move.l	(a0)+,d0
	move.l	a0,a6
	add.l	d0,a6
	ifne	PIC_ALGO
	moveq	#0,d0
	move.b	-(a6),d0
	move	d0,-2(a2)
	ifne	RESTORE_SPACE
	lsl	#2,d0
	sub	d0,a4
	endc
	elseif
	ifne	RESTORE_SPACE
	clr	-2(a2)
	endc
	subq	#1,a6
	endc
	ifne	RESTORE_SPACE
	lea	buff_marg(pc),a3
	move	-2(a2),d0
	lsl	#2,d0
	add	#DEC_SPACE+$C,d0
	bra.s	.save
.save_m:	move.b	(a4)+,(a3)+
	subq	#1,d0
.save:	bne.s	.save_m
	movem.l	a3-a4,-(a7)
	endc
	ifne	PIC_ALGO
	pea	(a5)
	endc
	move.b	-(a6),d7
	bra	take_type
decrunch:	move	d3,d5
take_lenght:	add.b	d7,d7
.cont_take:	dbcs	d5,take_lenght
	beq.s	.empty1
	bcc.s	.next_cod
	sub	d3,d5
	neg	d5
	bra.s	.do_copy1
.next_cod:	moveq	#3,d6
	bsr.s	get_bit2
	beq.s	.next_cod1
	bra.s	.do_copy
.next_cod1:	moveq	#7,d6
	bsr.s	get_bit2
	beq.s	.next_cod2
	add	#15,d5
	bra.s	.do_copy
.empty1:	move.b	-(a6),d7
	addx.b	d7,d7
	bra.s	.cont_take
.next_cod2:	moveq	#13,d6
	bsr.s	get_bit2
	add	#255+15,d5
.do_copy:	add	d3,d5
.do_copy1:	lea	decrun_table(pc),a4
	move	d5,d2
	bne.s	bigger
	add.b	d7,d7
	bne.s	.not_empty
	move.b	-(a6),d7
	addx.b	d7,d7
.not_empty:	bcs.s	.ho_kesako
	moveq	#1,d6
	bra.s	word
.ho_kesako:	moveq	#3,d6
	bsr.s	get_bit2
	tst.b	-28(a2)
	beq.s	.ho_kesako1
	move.b	10-28(a2,d5.w),-(a5)
	bra	tst_end
.ho_kesako1:	move.b	(a5),d0
	btst	#3,d5
	bne.s	.ho_kesako2
	bra.s	.ho_kesako3
.ho_kesako2:	add.b	#$f0,d5
.ho_kesako3:	sub.b	d5,d0
	move.b	d0,-(a5)
	bra	tst_end
get_bit2:	clr	d5
.get_bits:	add.b	d7,d7
	beq.s	.empty
.cont:	addx	d5,d5
	dbf	d6,.get_bits
	tst	d5
	rts
.empty:	move.b	-(a6),d7
	addx.b	d7,d7
	bra.s	.cont
bigger:	moveq	#2,d6
word:	bsr.s	get_bit2
contus:	move	d5,d4
	move.b	14(a4,d4.w),d6
	ext	d6
	tst.b	1-28(a2)
	bne.s	.spe_ofcod1
	addq	#4,d6
	bra.s	.nospe_ofcod1
.spe_ofcod1:	bsr.s	get_bit2
	move	d5,d1
	lsl	#4,d1
	moveq	#2,d6
	bsr.s	get_bit2
	cmp.b	#7,d5
	blt.s	.take_orof
	moveq	#0,d6
	bsr.s	get_bit2
	beq.s	.its_little
	moveq	#2,d6
	bsr.s	get_bit2
	add	d5,d5
	or	d1,d5
	bra.s	.spe_ofcod2
.its_little:	or.b	2-28(a2),d1
	bra.s	.spe_ofcod3
.take_orof:	or.b	3-28(a2,d5.w),d1
.spe_ofcod3:	move	d1,d5
	bra.s	.spe_ofcod2
.nospe_ofcod1:	bsr.s	get_bit2
.spe_ofcod2:	add	d4,d4
	beq.s	.first
	add	-2(a4,d4.w),d5
.first:	lea	1(a5,d5.w),a4
	move.b	-(a4),-(a5)
.copy_same:	move.b	-(a4),-(a5)
	dbf	d2,.copy_same
	bra.s	tst_end
make_jnk:	add.b	d7,d7
	bne.s	.not_empty
	move.b	-(a6),d7
	addx.b	d7,d7
.not_empty:	bcs.s	string
	move.b	-(a6),-(a5)
tst_end:	cmp.l	a5,a3
	bne.s	make_jnk
	cmp.l	a6,a0
	beq.s	work_done
take_type:	moveq	#0,d6
	bsr	get_bit2
	beq.s	.nospe_ofcod
	move.b	-(a6),d0
	lea	2-28(a2),a1
	move.b	d0,(a1)+
	moveq	#1,d1
	moveq	#6,d2
.next:	cmp.b	d0,d1
	bne.s	.no_off_4b
	addq	#2,d1
.no_off_4b:	move.b	d1,(a1)+
	addq	#2,d1
	dbf	d2,.next
	st	1-28(a2)
	bra.s	.spe_ofcod
.nospe_ofcod:	sf	1-28(a2)
.spe_ofcod:	moveq	#0,d6
	bsr	get_bit2
	beq.s	.relatif
	lea	10-28(a2),a1
	moveq	#15,d0
.next_f:	move.b	-(a6),(a1)+
	dbf	d0,.next_f
	st	-28(a2)
	bra.s	.freq
.relatif:	sf	-28(a2)
.freq:	clr	d3
	move.b	-(a6),d3
	move.b	-(a6),d0
	lsl	#8,d0
	move.b	-(a6),d0
	move.l	a5,a3
	sub	d0,a3
	bra.s	make_jnk
string:	bra	decrunch
work_done:
	ifne	PIC_ALGO
	move.l	(a7)+,a0
	pea	(a2)
	bsr.s	decod_picture
	move.l	(a7)+,a2
	endc
	ifne	RESTORE_SPACE
	movem.l	(a7)+,a3-a4
	endc
	ifne	MODE
	move.l	(a7)+,d0
	bsr.s	copy_decrun
	endc
	ifne	RESTORE_SPACE
	move	-2(a2),d0
	lsl	#2,d0
	add	#DEC_SPACE+$C,d0
	bra.s	.restore
.restore_m:	move.b	-(a3),-(a4)
	subq	#1,d0
.restore:	bne.s	.restore_m
	endc
	unlk	a2
not_packed:	movem.l	(a7)+,d0-a6
 	rts
decrun_table:	dc.w	32,32+64,32+64+256,32+64+256+512,32+64+256+512+1024
	dc.w	32+64+256+512+1024+2048,32+64+256+512+1024+2048+4096
	dc.b	0,1,3,4,5,6,7,8
	ifne	PIC_ALGO
decod_picture:	move	-2(a2),d7
.next_picture:	dbf	d7,.decod_algo
	rts
.decod_algo:	move.l	-(a0),d0
	lea	0(a5,d0.l),a1
.no_odd:	lea	$7d00(a1),a2
.next_planes:	moveq	#3,d6
.next_word:	move	(a1)+,d0
	moveq	#3,d5
.next_bits:	add	d0,d0
	addx	d1,d1
	add	d0,d0
	addx	d2,d2
	add	d0,d0
	addx	d3,d3
	add	d0,d0
	addx	d4,d4
	dbf	d5,.next_bits
	dbf	d6,.next_word
	movem	d1-d4,-8(a1)
	cmp.l	a1,a2
	bne.s	.next_planes
	bra.s	.next_picture
	endc
	ifne	MODE
copy_decrun:	lsr.l	#4,d0
	lea	-12(a6),a6
.copy_decrun:	rept	4
	move.l	(a5)+,(a6)+
	endr
	dbf	d0,.copy_decrun
	rts
	endc
	ifne	RESTORE_SPACE
buff_marg:	dcb.b	$90+DEC_SPACE+$C
	endc
	even

***************************************************************************
* 5. Game patching at runtime (cracking, bug-fixing & trainer)
*
* Here are technical details about the game that help you understand the
* following routines used to neutralize the copy-protection, to fix the
* various bugs of the game and to add the support of the Falcon machine.
*
* Safari Guns comes on two floppy disks:
* - The first disk has two independent sides. Both sides have 80 tracks
*   (0-79), but the first side has 10 sectors per track, while the second
*   side has only 9 sectors per track.
*   The first side of the first disk contains 32 data files and
*   2 executable programs (in the auto folder):
*   . the intro, a GFA compiled program.
*   . the game, a C compiled program.
*   The second side of the first disk contains the intro music sample
*   stored on sectors directly without a filesystem.
* - The second disk has only one side containing 80 tracks with 10 sectors
*   per track.
*   This disk contains 100 data files.
*
* The game protection is the following:
* - The intro program checks the occupancy of the first disk (the free disk
*   space) and refuses to run if it is different from the expected value.
* - The two sides of the first disk are formatted differently (10 sectors
*   per track on the first side, versus 9 sectors per track on the second
*   side).
* - On the first disk, the last track (79) of first side is copy-protected.
*   This track is checked by the game after the display of the credits
*   (at the very beginning of the game loading).
*   If this check fails (disk is a copy), the game is altered so that the
*   gun cannot be used (game is not playable).
*   If the corresponding copy-protection routine is not executed (as the
*   result of a naive crack), then the mouse cannot be used (user gets
*   stuck during flags selection).
* - On the second disk, track 50 of first side is copy-protected.
*   This track is checked randomly when loading the game by a second
*   copy-protection routine.
*   If this check fails, the game is altered so that it will later crash.
* - A third copy-protection routine exists in the code but it is never
*   called.
* - The game does a checksum on the first copy-protection routine, ie it
*   checks if that routine has been modified (typically by a hacker).
*   If the checksum routine detects a modification, then the game freezes.
*   This check is performed after playing the game.
*
* In addition to the different protection techniques implemented in the
* game, there were two other difficulties to make an advanced crack
* (packed or HD-compatible version):
* - the music sample of the intro is directly stored on sectors without a
*   filesystem. Therefore the music sample needs to be extracted and saved
*   as normal files, and the intro code needs to be modified accordingly
*   so that it loads the music sample from those files.
* - the intro needs about $70000 Bytes (448KB, including the video memory)
*   to run, thus leaving very few memory on a 512KB machine for the
*   unpacking/single-file loader (minimal TOS memory usage, when a program
*   is launched from the auto folder, is between 40KB and 50KB depending
*   on the TOS version).
*
* There were also several bugs in the game. Some of them already existed
* on ST while some others occur only on Falcon.
* ST bugs:
* - the intro freezes if the user presses the space key before the music
*   starts.
* - the intro displays an error dialog box if it is not executed from the
*   auto folder.
* - the game may crash after several plays because of a random
*   out-of-bounds array access.
* - The music sample of the game (during level loading) is noisy when it
*   starts, for a short time (2/3 seconds). 
* Falcon bugs are:
* - The intro crashes if run in non ST-low resolution.
* - The intro crashes: old GFA compiled programs do not run on Falcon
*   because they require 24-bits addressing mode (while the Falcon uses
*   32-bits addressing mode).
* - The intro and the game crash when the sample music starts playing.
*   The player uses PSG shadow registers which exist on ST but not on
*   falcon (leading to a bus error on this machine).
* - The game crashes when the the first level screen appears.
*   The game code reads the sr register in user mode. Although this
*   is allowed on 68000, this generates a privilege exception on 68030.
*
* Note that New Deal released several versions of this game with subtle
* differences (supported languages, minor graphics or sound details).
* The copy-protection techniques and the bugs might slightly vary from
* one version to another.
*
* The developer left an easter egg in the code of the game intro.
* It is a hidden message for crackers:
*
* *** SAFARI GUNS (C) NEW DEAL Productions S.A. 1989 ***
* *** Atari ST version by Ric EXCOFFIER. ***
* *** If you crack this stuff, please call us for a job ***
* *** Phone: 48 70 86 94 (PARIS,FRANCE) ***
* *** We're also looking for an AY' Freaker, for our next games... Contact us !!
* *** See ya ! ***
*
* The developer also left a signature in the main binary of the game:
* "All Code by Richard Excoffier. Juillet 1989."
*
***************************************************************************

	; setup_trainer()
	; Copy the trainer mode configuration from the generic
	; trainer options table to the game-specific trainer
	; mode descriptor.
	; This descriptor will be used to patch the main binary
	; of the game after loading in order to enable selected
	; trainer options.
	; Called from the internal intro.
setup_trainer
	movem.l	a0-a1,-(a7)

	lea	opts_info+2(pc),a0
	movea.l	trainer_info_p(pc),a1
	move.b	8*0+7(a0),TRAINER_LIVES(a1)
	move.b	8*1+7(a0),TRAINER_PIC_SCORE(a1)
	move.b	8*2+7(a0),TRAINER_SCORE(a1)
	move.b	8*3+7(a0),TRAINER_LEVEL(a1)
	tst.b	8*4+7(a0)
	beq.s	setup_trainer_ret
	movea.l	config_p(pc),a0
	and.l	#~((1<<CONFIG_PROG1)!(1<<CONFIG_WAIT)),(a0)
setup_trainer_ret
	movem.l	(a7)+,a0-a1
	rts

	; inst_vecs_crack()
	; Install the "trap#5" handler which is used to patch
	; game binaries (intro and main) just after loading.
	; Game binaries are patched at runtime in order to
	; remove copy-protections, to enable the trainer mode
	; and to fix several bugs (native bugs or 68030/falcon
	; issues).
	; To this end, both the intro and the main binaries have
	; been patched manually: the first instruction has been
	; replaced with a "trap#5" instruction.
	; When those binaries are executed, they first execute
	; the "trap#5" instruction and thus fall into the
	; trap5_patch_handler routine.
	; This routine patches the interrupted program, restores
	; the original first instruction and resumes execution
	; of the program.
	; In order to support Falcon machines, a "privilege
	; violation" exception handler ($20) is also installed.
	; It is used to emulate "move sr,x" instructions which
	; are allowed in user mode on 68000 but which are
	; restricted to the supervisor mode on 68030.
	; See trap5_patch_handler() for detailed comments on game
	; and intro modifications and installation of associated
	; trap handlers.
	; Called from supexec.
	; Out:
	;   d0: return value
	; Scratch: a0
inst_vecs_crack
	lea	trap5_patch_handler(pc),a0
	move.l	a0,$80+(5*4).w

	lea	cpu_priv_instr(pc),a0
	move.l	a0,$20.w

	moveq.l	#0,d0
	rts

	; cpu_priv_instr()
	; Privilege violation exception handler.
	; Emulate "more sr,x" instructions on 68030.
	; Transform "move sr,x" into "move ccr,x" on-the-fly.
cpu_priv_instr
	movem.l	d0/a0,-(a7)

	movea.l	4*2+2(a7),a0
	move.w	(a0),d0
	and.w	#$ffc0,d0
	cmp.w	#$40c0,d0	; move sr,x
	bne.s	cpu_priv_instr_ret
	or.w	#$200,(a0)	; move ccr,x
cpu_priv_instr_ret
	movem.l	(a7)+,d0/a0
	rte

	***********************************************************
	* On-the-fly game intro patching
	* The following routines are trap handlers installed 
	* by the intro patching routine at runtime.
	* See trap5_patch_handler() for detailed comments on intro 
	* modifications and installation of associated trap
	* handlers.
	***********************************************************

	; trap3_intro_music()
	; Support for game's intro music loading.
	; This "trap#3" exception handler is used to emulate the
	; reading of floppy sectors (XBIOS Floprd).
	; In the original code, Floprd is used to load the intro
	; music (sample) directly from sectors (no file usage).
	; The game intro plays the music while music data are
	; loaded in background.
	; For this crack, the music sample has been ripped from
	; the original game and saved as 16 data files of 23KB
	; each.
	; The original "trap#14" instruction of the Floprd
	; invocation has been replaced with a "trap#3" so that
	; when the game intro reads (music) sectors, it actually
	; falls into the following routine which loads the music
	; from the packed files instead.
	; As in the original intro, music playing and music data
	; loading is performed in parallel (music is played while
	; files are loaded and depacked in background). 
	; The loading of a packed music file and the unpacking
	; of that file are not performed in the same trap
	; invocation, but they are performed in two different
	; (successive) trap invocations instead.
	; It enables to return to the intro code between files
	; loading and depacking, thus reducing the latency of
	; keystroke detection (the intro stops when the space
	; key is pressed).
trap3_intro_music
	moveq.l	#0,d0
	movem.l	d0-d2/d7/a0-a2,-(a7)

	; The music_next_track table provides the mapping between
	; sector numbers (as loaded in the original code), and
	; file numbers (as loaded in this version).
	; The original Floprd invocation is based on a track
	; number which is converted into a file number here.
	; In the original game, the music only starts playing
	; after loading 8 tracks. So make sure that, in this
	; version, enough music files are read before this limit
	; is reached.
	lea	music_next_track_i(pc),a0
	lea	music_next_track(pc),a1
	adda.l	(a0),a1
	move.l	usp,a2
	move.w	2+4+4+2+2(a2),d0
	cmp	(a1),d0
	bne	trap3_mus_ret
	; Patch ret addr
	addq.l	#2,(a0)

	; Odd track numbers are used to load music files,
	; whereas even track numbers are used to unpack them. 
	btst	#0,d0
	bne.s	trap3_mus_fopen

	; Depack previously loaded music file.
	lea	music_buffer(pc),a1
	movea.l	(a1),a0
	move.l	#($200*$9*$4f)/$10,d0
	bsr	depack
	adda.l	d0,a0
	move.l	a0,(a1)
	bra.s	trap3_mus_ret

	; Load a music file.
	; Treat music files as any other game file, and thus
	; use the normal file loading path (trap#1) which is
	; intercepted by this loader to actually load files
	; from the library file (linked/packed files).
trap3_mus_fopen
	clr.w	-(a7)
	pea	music_fname(pc)
	move.w	#$3d,-(a7)
	trap	#1
	addq.l	#8,a7
	tst.w	d0
	bpl.s	trap3_mus_fopen_cont
	move.l	#-1,(a7)
	bra.s	trap3_mus_ret

trap3_mus_fopen_cont
	move.l	d0,d7
	lea	music_idx(pc),a0
	addq.b	#1,(a0)

	lea	music_buffer(pc),a0
	movea.l	(a0),a1
	cmp.l	#0,a1
	bne.s	trap3_mus_fread
	move.l	usp,a2
	move.l	2(a2),a1
	move.l	a1,(a0)

trap3_mus_fread
	; Disable on-the-fly depacking for this file,
	; since depacking will be performed at next
	; trap invocation.
	lea	file_info(pc),a0
	st	FILE_NODEPACK(a0)

	pea	(a1)
	pea	(($200*$9*$4f)/$10).w
	move.w	d7,-(a7)
	move.w	#$3f,-(a7)
	trap	#1
	lea	12(a7),a7
	tst.l	d0
	bpl.s	trap3_mus_fclose
	move.l	#-1,(a7)

trap3_mus_fclose
	move.w	d7,-(a7)
	move.w	#$3e,-(a7)
	trap	#1
	addq.l	#4,a7

trap3_mus_ret
	movem.l	(a7)+,d0-d2/d7/a0-a2
	rte

	; trap4_intro_addr24()
	; Fix invalid addresses on 68030.
	; GFA compiled code (of the game intro) requires 24-bit
	; addressing mode. Indeed it may use addresses with
	; garbage int their most significant byte.
	; This is not a problem on 68000 which uses 24-bit
	; addressing mode (most significant byte is ignored).
	; But on 68030, which use 32-bit addressing mode, such
	; generated code merely crashes.
	; In the game intro code, invalid addresses are always
	; loaded into a0 using the same instruction:
	; "movea.l -(a3),a0"
	; The game intro code is patched to replace every
	; occurrences of this instruction with a "trap#4",
	; thus falling into the following handler.
	; The handler merely loads a0 and clear its MSbyte.
trap4_intro_addr24
	move.l	d0,-(a7)
	move.l	-(a3),d0	; load invalid addr
	and.l	#$ffffff,d0	; clear MSbyte
	movea.l	d0,a0   	; a0 = correct addr
	move.l	(a7)+,d0
	rte

	; trap6_intro_cleanup()
	; Fix cleanup of intro music player.
	; There is a bug in the game intro: if the user presses
	; the space key before the music starts, then the music
	; player is not initialized but its cleanup function
	; is, however, called on exit. It leads to set ACIA/MFP
	; registers to zero on exit, causing a system freeze.
	; The game intro code is patched in two places:
	; - the "jsr (a0)" instruction (call to the music player
	;   cleanup routine) is replaced with a "nop".
	; - a "movea.l d0,a0" instruction of the music player
	;   init routine is replaced with a "trap#6" instruction
	;   so that when the music player init code is called,
	;   it invokes the following "trap#6" handler.
	; This handler patches the game intro code on-the-fly to
	; restore the "jsr (a0)" instruction (call to the cleanup
	; routine), and it loads d0 into a0 as done in the
	; original code.
	; That way, it is guaranteed that the cleanup routine is
	; called only if the init routine is actually called.
trap6_intro_cleanup
	move.l	2(a7),a0
	move.w	#$4e90,$3e(a0)	; "jsr (a0)"
	movea.l	d0,a0         	; original instruction
	; Fall-through
	; On ST, the handler returns here ("rte" below),
	; while on Falcon, the handler executes the code located
	; after the "rte" (which is patched with a "nop" - see
	; below).

	; trap6_intro_inst_psgfix()
	; Fix the intro sample player on Falcon.
	; On ST, the PSG (YM sound chip) has shadow registers
	; ($ff8804-x) while the Falcon does not.
	; The intro sample player uses those shadow registers
	; leading to a bus error on Falcon.
	; The "trap#6" handler, which is invoked by the init
	; routine of the sample player (see above), is patched
	; on Falcon so that the "rte" instruction below is
	; replaced with a nop.
	; The code located after that rte/nop (called during
	; sample player init) patches the interrupt routine
	; of the player on-the-fly:
	; The 2 "movep" instructions of that routine are replaced
	; with a "jsr" to the "psgfix_falcon" routine below.
	; The psgfix_falcon routine uses normal PSG registers
	; to write music data.
trap6_intro_inst_psgfix
	rte	; replaced with a nop on Falcon
	; Patch the interrupt routine of the intro player.
	move.l	#0,$30e+4(a0)       ; psgfix_falcon addr
	move.l	#$4e714eb9,$30e(a0) ; "nop ; jsr <addr>"
	rte

	; psgfix_falcon()
	; Called by the interrupt routine of the intro or game
	; sample player to use the normal PSG registers instead
	; of the shadow registers.
	; The original code uses "movep.l d5,0(a4)", which
	; writes to shadow registers $ff8804 and $$ff8806.
	; The new code uses 2 "movep.w" to $ff8800 and $ff8802
	; instead.
	; The 3rd "movep.w" was already present in the original
	; code and is just recopied here.
	; It fixes the sample player on Falcon.
	; The psgfix_falcon() routine is used for both the intro
	; and the game sample players because those players are
	; exactly the same.
	; The patching of the intro/game player interrupt routine
	; to call psgfix_falcon() is performed in two different
	; ways, depending on whether it is the intro or the game.
	; For the intro, the interrupt routine is patched by the
	; trap6_intro_inst_psgfix() routine right above.
	; For the game, the interrupt routine is patched by the
	; trap5_patch_handler() handler hereafter.
psgfix_falcon
	move.l	d5,d7
	swap	d7
	movep.w	d7,0(a4)
	movep.w	d5,0(a4)
	movep.w	d4,0(a4)
	rts

	***********************************************************
	* On-the-fly game patching
	* The following routines are trap handlers installed 
	* by the game patching routine at runtime.
	* See trap5_patch_handler() for detailed comments on game 
	* modifications and installation of associated trap
	* handlers.
	***********************************************************

	; trap3_array_idx_inc_safe()
	; Fix random out-of-bounds array access.
	; The game, which was written in C, has a subtle and
	; random bug which happens only after multiple plays.
	; An array may be accessed outside its bounds, leading
	; the game to crash.
	; The instruction which increments the array index is:
	; "addq.l #2,d0"
	; It is replaced with a "trap#3" so that when the array
	; index is supposed to be incremented, the following
	; "trap#3" handler is invoked instead.
	; The handle checks the array limit before safely
	; incrementing the index.
trap3_array_idx_inc_safe
	cmp.l	#$88a,d0	; array limit
	bcs.s	trap3_array_idx_inc
	; Avoid out-of-bounds array access.
	rte
trap3_array_idx_inc
	; Safely increment the array index.
	addq.l	#2,d0
	rte

	; trap4_game_music()
	; Fix the game sample player.
	; The game uses two different interrupt routines for
	; the sample music and the sound effects.
	; But the sound effects routine is still active while
	; the sample music is playing (during the loading of a
	; level), thus creating interference with the music.
	; The Game code is patched at two places:
	; - the function which starts the music player
	; - the function which stops the music player
	; The first and last instruction of respectively the
	; start and stop function is replaced with a "trap#4"
	; so that, when it is invoked, it falls into the following
	; "trap#4" handler.
	; The handler determines which function (start or stop)
	; was executing and performs the following actions
	; accordingly:
	; - music start: the handler saves the CPU registers
	;   as expected by the calling function (normally done
	;   by the instruction which was replaced with the trap).
	;   It then modifies the sound effects interrupt vector
	;   to temporary disable sound effects playing.
	; - music stop: the handler restores the sound effects
	;   interrupt vector so that sound effects playing is
	;   enabled again. Then it restores the CPU registers
	;   previously saved, as expected by the calling function
	;   (normally done by the instruction which was replaced
	;   with the trap).
trap4_game_music_fix
	move.l	a0,-(a7)
	move.l	4+2(a7),a0
	adda.l	#2,a0
	; Determine if we are in the "start" or "stop" case.
	cmp.w	#$41fa,(a0)
	bne.s	trap4_music_stop

	; Save registers and disable sound effects playing.
trap4_music_start
	move.l	a0,4+2(a7)
	; Save regs as normally done by the caller.
	movem.l	d0-a6,$1a0(a0)
	move.l	(a7)+,$1a0+8*4(a0)
	; Modify Timer C vector (used for sound effects) so that
	; sound effect playing code is bypassed.
	movea.l	$114.w,a1
	adda.l	#$3f0,a1
	move.l	a1,$114.w
	movem.l	$1a0(a0),d0-a6
	rte

	; Re-enable sound effects playing and restore registers.
trap4_music_stop
	adda.l	#4,a7
	; Restore original (sound effects) Timer C vector.
	movea.l	$114.w,a1
	suba.l	#$3f0,a1
	move.l	a1,$114.w
	; The caller normally restore regs and returns (rts).
	; Perform these operations on its behalf.
	lea	trap4_music_stop_ret(pc),a1
	move.l	a1,2(a7)
	movem.l	$100(a0),d0-a6
	rte
trap4_music_stop_ret
	rts

	; trap6_pic_score()
	; Handle the "Max points per picture" trainer option.
	; The instruction which normally saves the score
	; of a given picture is replaced with a "trap#6".
	; When the following "trap#6" handler is invoked,
	; it overwrites the score of the picture with the
	; maximum value.
trap6_pic_score
	move.w	#990,d1 	; maximum score is 990
	move.w	d1,6(a0)	; save it
	rte

	; trap7_level()
	; Handle the "Starting level" trainer option.
	; The instruction which normally saves the level number
	; into memory is replaced with a "trap#7" instruction.
	; When the following "trap#7" handler is invoked,
	; it saves the desired level at the expected location
	; in memory.
trap7_level
	movem.l	a0-a1,-(a7)
	movea.l	trainer_info_p(pc),a0
	; Get the return address (address of patched instr+2).
	movea.l	4*2+2(a7),a1
	; The memory address where the level number shall be
	; saved is in the patched instruction.
	movea.l	(a1),a1
	; Save the desired level.
	move.b	TRAINER_LEVEL(a0),(a1)
	movem.l	(a7)+,a0-a1
	; Fix return address (skip unused part of patched instr).
	addq.l	#4,2(a7)
	rte

PATCH_FRAMERATE	=	0
	ifne PATCH_FRAMERATE
trap8_vsync
	movem.l	d0/a0,-(a7)
	lea	game_vsync_nr(pc),a0
	move.l	$466.w,d0
	sub.l	(a0),d0
	cmp.l	#16,d0
	bls.s	tr8_ct
	move.l	#16,d0
tr8_ct	move.l	$466.w,(a0)
	lsl.l	#2,d0
	add.l	#1,4(a0,d0.l)
	movem.l	(a7)+,d0/a0	
	move.l	$80+14*4.w,-(a7)
	rts

_trap8_vsync
	move.l	a0,-(a7)
	lea	game_vsync_nr(pc),a0
trap8_vsync_wait
	move.l	$466.w,d0
	sub.l	(a0),d0
	cmp.l	#4,d0
	blo.s	trap8_vsync_wait
	move.l	$466.w,(a0)
	move.l	(a7)+,a0
	moveq.l	#1,d0
	rte

game_vsync_nr
	ds.l	1
	ds.l	20
	endc

	***********************************************************
	* On-the-fly intro/game patching
	* The following routine patches the intro and the game and
	* installs associated trap handlers.
	* Modifications and trap handlers are used to remove
	* copy-protections, to enable the trainer mode and to fix
	* several bugs (native bugs or 68030/falcon issues).
	***********************************************************

	; trap5_patch_handler()
	; The intro and game binaries have been manually patched
	; to replace the first program instruction with a "trap#5"
	; instruction.
	; When the intro or the game starts executing, it falls
	; into the following trap handler which modifies the code
	; of the interrupted intro or game.
	; The same "trap#5" handler is used for both the intro
	; and the game. The handler determines which program is
	; running and applies the appropriate patches.
trap5_patch_handler
	movea.l	2(a7),a0
	subq.l	#2,a0
	move.l	a0,2(a7)
	move.w	#$310,(a7)

	; Enable on-the-fly loading and depacking of game files.
	lea	file_info(pc),a1
	st	LNK_ENABLED(a1)

	; Determine which program (intro or game) is running.
	cmp.w	#$1b45,2(a0)
	bne	patch_game

	; Patch the intro code.
patch_intro
	; Restore first intro instruction.
	move.w	#$600a,(a0)

	; Neutralize free disk space (dfree) verification.
	movea.l	a0,a1
	adda.l	#$1ff0,a1
	move.w	#$6020,(a1)	; "bra.s pc+$22"

	; Intercept floppy reads (Floprd) used to load the
	; music sample. Music is now loaded as files.
	; See trap3_intro_music() for details.
	movea.l	a0,a1
	adda.l	#$23fa,a1
	; Replace original "trap#14" with "trap#3".
	move.w	#$4e43,(a1)

	; Install associated "trap#3" handler.
	lea	trap3_intro_music(pc),a1
	move.l	a1,$80+(3*4).w

	; Fix 24-bits memory accesses on 68030.
	; Replace all occurrences of the instruction that
	; loads invalid addresses with a "trap#4".
	; See trap4_intro_addr24() for details.
	movea.l	a0,a1
	adda.l	#$b6a,a1
	move.w	#$4e44,(a1)	; "trap#4"
	adda.l	#$2b2,a1
	move.w	#$4e44,(a1)	; "trap#4"
	adda.l	#$6c,a1
	move.w	#$4e44,(a1)	; "trap#4"

	; Install associated "trap#4" handler.
	lea	trap4_intro_addr24(pc),a1
	move.l	a1,$80+(4*4).w

	; Fix intro cleanup: do not call music player cleanup
	; when player was not initialized (music not started).
	; Patch the player init routine so that it invokes the
	; "trap#6" handler.
	; See trap6_intro_cleanup() for details.
	movea.l	a0,a1
	adda.l	#$243c,a1
	move.w	#$4e46,(a1)	; "trap#6"
	; Disable the player cleanup routine (it is re-enabled
	; in the "trap#6" handler).
	move.w	#$4e71,$40(a1)	; "nop"

	; Install associated "trap#6" handler.
	lea	trap6_intro_cleanup(pc),a1
	move.l	a1,$80+(6*4).w

	; Falcon: fix unsupported accesses to PSG shadow
	; registers ($8804-$88ff).
	move.l	mach_conf_p(pc),a1
	cmp.w	#MCH_FALCON,MACH2CPU+MCH_TYPE(a1)
	bne.s	patch_intro_aes

	; Patch the "trap#6" handler so that it executes
	; additional code on Falcon. This additional code
	; patches the interrupt routine of the intro sample
	; player during player initialization.
	; See trap6_intro_inst_psgfix handler() for details.
	lea	trap6_intro_inst_psgfix(pc),a1
	lea	psgfix_falcon(pc),a2
	; Replace the "rte" with a "nop".
	move.w	#$4e71,(a1)
	; Patch the "jsr <addr>" instruction with the address
	; of the psgfix_falcon routine.
	move.l	a2,4(a1)

	; Remove AES/VDI calls used during init/cleanup.
	; Otherwise, system may hang when screen resolution
	; is enforced to ST-Low.
patch_intro_aes
	; Write "nop" instructions here and there.
	move.l	#$4e714e71,$6e(a0)
	move.l	#$4e714e71,$be(a0)
	move.l	#$4e714e71,$ca(a0)
	move.w	#$4e71,$d6(a0)
	move.l	#$4e714e71,$ee(a0)
	move.w	#$4e71,$1c6(a0)

	; Do not generate an error dialog box when
	; the intro is not started from auto folder.
	movea.l	a0,a1
	adda.l	#$1c4a,a1
	move.w	#$4e71,(a1)	; "nop"

	bra	ret_to_prog

	; Patch the game code.
patch_game
	; Restore first game instruction.
	move.w	#$226f,(a0)

	; Neutralize unused disk protection routine.
	movea.l	a0,a1
	adda.l	#$12fbc,a1
	move.w	#$4e75,(a1)	; "rts"

	; Neutralize floppy B protection routine.
	movea.l	a0,a1
	adda.l	#$13836,a1
	move.w	#$4e75,(a1)	; "rts"

	; Neutralize floppy A protection routine.
	movea.l	a0,a1
	adda.l	#$11e12,a1
	move.l	#$600000b6,$50(a1) ; "bra pc+$b8"
	move.w	#$6000,$122(a1)	; "bra"

	; Neutralize protection code verification routine
	; (aka checksum).
	movea.l	a0,a1
	adda.l	#$12f36,a1
	move.w	#$4e75,(a1)	; "rts"

	; Fix random out-of-bounds array access bug.
	; Replace faulty instruction with a "trap#3".
	; See trap3_array_idx_inc_safe() for details.
	movea.l	a0,a1
	adda.l	#$1c002,a1
	move.l	#$0140004c,(a1) ; +1 array entry
	movea.l	a0,a1
	adda.l	#$7d6c,a1
	move.w	#$4e43,(a1)	; "trap#3"

	; Install associated "trap#3" handler.
	lea	trap3_array_idx_inc_safe(pc),a1
	move.l	a1,$80+(3*4).w
	
	; Fix concurrent accesses to PSG registers by both the
	; sample player interrupt routine and the sound effects
	; interrupt routine.
	; Neutralize the sound effects interrupt routine while
	; playing a sample.
	; See trap4_game_music_fix() for details.
	movea.l	a0,a1
	adda.l	#$13b2e,a1
	move.w	#$4e44,(a1)	; "trap#4"
	move.w	#$4e44,$a0(a1)	; "trap#4"
	move.w	#$2500,-$6e(a1)	; #$2500 -> sr

	; Install associated "trap#4" handler.
	lea	trap4_game_music_fix(pc),a1
	move.l	a1,$80+(4*4).w

	; Falcon: fix unsupported accesses to PSG shadow
	; registers ($8804-$88ff).
	move.l	mach_conf_p(pc),a1
	cmp.w	#MCH_FALCON,MACH2CPU+MCH_TYPE(a1)
	bne.s	patch_vsync

	; On Falcon, the sample player interrupt routine of the
	; game is patched as follows: "movep" instructions are
	; replaced with a "jsr" to psgfix_falcon().
	; See psgfix_falcon() for details.
	movea.l	a0,a1
	adda.l	#$13aaa,a1
	lea	psgfix_falcon(pc),a2
	move.l	#$4e714eb9,(a1)	; "nop ; jsr <addr>"
	move.l	a2,4(a1)	; <addr> = psgfix_falcon

	; Fix frame rate on fast machines.
patch_vsync
	ifne PATCH_FRAMERATE
	movea.l	a0,a1
	adda.l	#$1176c,a1
	move.w	#$4e48,(a1)
	lea	trap8_vsync(pc),a1
	move.l	a1,$80+(8*4).w
	endc
patch_trainer
	movea.l	trainer_info_p(pc),a2

	; Trainer: infinite lives.
patch_tr_lives
	tst.b	TRAINER_LIVES(a2)
	beq.s	patch_tr_pic_score
	movea.l	a0,a1
	adda.l	#$4138,a1
	; Neutralize the decrement of the lives number.
	move.w	#$4e71,(a1)	; "nop"

	; Trainer : max score per picture.
patch_tr_pic_score
	tst.b	TRAINER_PIC_SCORE(a2)
	beq.s	patch_tr_score
	; Patch the game so that, When the score of a picture
	; is computed, it will now invoke our "trap#6" handler.
	; See trap6_pic_score() for details.
	movea.l	a0,a1
	adda.l	#$4d40,a1
	move.w	#$4e46,(a1)	; "trap#6"
	move.w	#$4e71,2(a1)	; "nop"
	adda.l	#$4db2-$4d40,a1
	; The game adds randomness to picture scores.
	; This randomness is fake because it is not taken
	; into account in the computation of the final score.
	; When this trainer option is enabled, skip that
	; randomness trick.
	move.b	#$60,(a1)	; "bra.s"

	; Install associated "trap#6" handler.
	lea	trap6_pic_score(pc),a1
	move.l	a1,$80+(6*4).w

	; Trainer: always reach next level.
patch_tr_score
	tst.b	TRAINER_SCORE(a2)
	beq.s	patch_tr_level
	movea.l	a0,a1
	adda.l	#$22f0,a1
	; Neutralize the conditional branch to the next level.
	move.w	#$6018,(a1)	; "bra.s pc+$1a"

	; Trainer: starting level.	
patch_tr_level
	cmp.b	#1,TRAINER_LEVEL(a2)
	bne.s	patch_lev_ok
	move.b	#0,TRAINER_LEVEL(a2)
patch_lev_ok
	; Patch the game so that, when the game level is saved
	; to memory, our "trap#7" handler is actually invoked.
	; See trap7_level() for details.
	movea.l	a0,a1
	adda.l	#$fc2,a1
	move.w	#$4e47,(a1)	; "trap#7"

	; Install associated "trap#7" handler.
	lea	trap7_level(pc),a1
	move.l	a1,$80+(7*4).w

	; Patch a file name to cope with single disk usage.
	movea.l	a0,a1
	adda.l	#$1a910,a1
	move.b	#'1',(a1)

	; Patch high scores for fun.
	movea.l	a0,a1
	adda.l	#$190f4,a1
	lea	score_text(pc),a2
	moveq	#(score_text_end-score_text)-1,d0
cp_score_text
	move.b	(a2)+,(a1)+
	dbf	d0,cp_score_text

	; Clear BSS (not done by ATOMIK packer).
ret_to_prog
	movea.l	a0,a6
	move.l	USP,a1
	move.l	4(a1),a1
	movea.l	a0,a5
	adda.l	12(a1),a5
	movea.l	a5,a4
	adda.l	20(a1),a4
	movea.l	a4,a0
	movea.l	28(a1),a1
	cmp.l	#$10000,a1
	bhi.s	clear_sz_ok
	move.l	#$10000,a1
clear_sz_ok
	adda.l	a0,a1

mclear	clr.l	(a0)+
	cmp.l	a0,a1
	bhi.s	mclear

	; Clear CPU registers.
	moveq.l	#0,d0
	move.l	d0,d1
	move.l	d0,d2
	move.l	d0,d3
	move.l	d0,d4
	move.l	d0,d5
	move.l	d0,d6
	move.l	d0,d7
	movea.l	d0,a0
	movea.l	d0,a1
	movea.l	d0,a2
	movea.l	d0,a3

	; Resume interrupted program.
	rte

***************************************************************************
* 6. De-initialization routines
***************************************************************************

	; restore_vecs()
	; Restore CPU exception & trap vectors.
	; Called from supexec.
	; Out:
	;   d0: return value
	; Scratch: a0-a2
restore_vecs
	moveq.l	#9,d0
	lea	vecs_conf(pc),a2
	lea	CPU_EXCEPTS(a2),a0
	lea	$8.w,a1
restore_excepts_lp
	move.l	(a0)+,(a1)+
	dbf	d0,restore_excepts_lp

	moveq.l	#15,d0
	lea	TRAPS(a2),a0
	lea	$80.w,a1
restore_traps_lp
	move.l	(a0)+,(a1)+
	dbf	d0,restore_traps_lp

	moveq.l	#0,d0
	rts

	; mach_restore()
	; Restore machine state: CPU caches & freq, bus config,
	; screen, palette...
	; Called from supexec.
	; Out:
	;   d0: return value
	; Scratch: a0-a1
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
	bsr.s	screen_restore

	; Restore mouse & conterm.
	move.l	a1,-(a7)
	dc.w	$a009
	move.l	(a7)+,a1
	move.b	#7,$484.w

	; Reset saved machine config status.
	clr.w	CONF_DONE(a1)
mach_restore_ret
	moveq.l	#0,d0
	rts

	; cpu_restore()
	; Restore CPU state: caches & freq, bus config.
	; in:
	;   a0: cpu_conf
cpu_restore
	movem.l	d0-d2/a0-a2,-(a7)
	movea.l	a0,a2

	; Restore cacr register.
	move.l	$10.w,-(a7)
	movea.l	a7,a0
	lea	cache_rest_done(pc),a1
	move.l	a1,$10.w

	move.l	CACR(a2),d0
	dc.w	$4e7b,$0002	; movec d0,cacr
cache_rest_done
	movea.l	a0,a7
	move.l	(a7)+,$10.w

	move.w	MCH_TYPE(a2),d0

	; Restore MegaSTe cache/freq.
	cmp.b	#MCH_MEGASTE,d0
	bne.s	bus_rest_falcon
	move.b	CACHE_MEGASTE(a2),$ffff8e21.w
	bra.s	cpu_rest_ret

	; Restore Falcon bus control.
bus_rest_falcon
	cmp.b	#MCH_FALCON,d0
	bne.s	cpu_rest_ret
	move.b	BUS_FALCON(a2),$ffff8007.w
cpu_rest_ret
	movem.l	(a7)+,d0-d2/a0-a2
	rts

	; screen_restore()
	; Restore screen state: resolution, palette.
	; in:
	;   a0: screen_conf
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

	bsr	vsync

	; Restore screen config.
	move.l	REZ_V(a4),-(a7)
	move.l	PHYSBASE(a4),-(a7)
	move.l	LOGBASE(a4),-(a7)
	move.w	#5,-(a7)
	trap	#14
	lea	14(a7),a7

	; Clear the screen.
	lea	cls(pc),a0
	bsr	print

	movem.l	(a7)+,d0-d7/a0-a4
	rts

***************************************************************************
* 7. Resident data: system backup/init/restoring
***************************************************************************

	; Program stack.
stack_bottom
	ds.l	(STACK_SIZE/4)
stack_top

	; Program base page.
base_page
	ds.l	1

	; Saved exception vectors [vecs_conf - vecs_conf_end].
vecs_conf
v_cpu_excepts  	; CPU exception vectors.
	ds.l	10
v_traps        	; Trap vectors.
	ds.l	16
v_trap_sf_size 	; Trap exception stack frame size.
	ds.l	1
vecs_conf_end

CPU_EXCEPTS 	=	(v_cpu_excepts-vecs_conf)
TRAPS       	=	(v_traps-vecs_conf)
TRAP_SF_SIZE	=	(v_trap_sf_size-vecs_conf)

	; Machine types.
MCH_ST     	=	$1
MCH_STE    	=	$2
MCH_MEGASTE	=	$3
MCH_TT     	=	$4
MCH_FALCON 	=	$5
MCH_CT60   	=	$100

	; Pointer to actual saved machine configuration.
mach_conf_p
	ds.l	1

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

mach_conf_end

MACH2CPU   	=	(cpu_conf-mach_conf)
MACH2SCREEN	=	(screen_conf-mach_conf)
CPU2SCREEN 	=	(screen_conf-cpu_conf)

	; Pointer to actual loader operating mode.
config_p
	ds.l	1

	; Default loader operating mode.
config
	dc.l	CONFIG_DEFAULT

	; Clear screen + cursor off.
cls
	dc.b	27,"E",27,"f",0
	even

***************************************************************************
* 8. Resident data: loading & depacking of game files
***************************************************************************

	; Global file info structure [file_info - file_info_end].
	; Contains meta-data used to handle on-the-fly loading
	; and depacking of game files linked into a single library
	; file.
	; Only one opened game file is handled at a time.
file_info
fi_lnk_enabled 	; Library (linked) file mechanism enabled/disabled.
	dc.w	0
fi_lnk_dir     	; Library file directory (list of linked game files).
	ds.l	1
fi_lnk_dir_end 	; End of library file directory.
	ds.l	1
fi_lnk_name    	; Name of the library file.
	ds.l	1
fi_lnk_handle  	; Handle (fopen) of the library file.
	dc.w	-1
fi_lnk_xhandle 	; Dead library file handle (see lnkfile_inv_handle).
	dc.w	-1
fi_lnk_ram_off 	; Offset of linked data files in the library file.
	ds.l	1
fi_lnk_ram_addr	; RAM disk address (if enough memory).
	dc.l	0
fi_handle      	; Handle of the currently opened game file.
	dc.w	-1
fi_lnkoffset   	; Offset in the library file of the currently opened
               	; game file.
	ds.l	1
fi_offset      	; Offset (fseek) of the currently opened game file.
	ds.l	1
fi_packsize    	; Packed size of the currently opened game file.
	ds.l	1
fi_size        	; Unpacked (real) size of the currently opened game file.
	ds.l	1
fi_nodepack    	; If set, on-the-fly depacking is disabled.
	ds.w	1
fi_nocache     	; If set, file must be read/depacked in place,
               	; otherwise it must be handled through the cache.
	ds.w	1
fi_cached      	; If set, file is already in the cache.
	ds.w	1
fi_cache_buf   	; File cache address.
	ds.l	1
file_info_end

LNK_ENABLED	=	(fi_lnk_enabled-file_info)
LNK_DIR    	=	(fi_lnk_dir-file_info)
LNK_DIR_END	=	(fi_lnk_dir_end-file_info)
LNK_NAME	=	(fi_lnk_name-file_info)
LNK_HANDLE	=	(fi_lnk_handle-file_info)
LNK_XHANDLE	=	(fi_lnk_xhandle-file_info)
LNK_RAM_OFF	=	(fi_lnk_ram_off-file_info)
LNK_RAM_ADDR	=	(fi_lnk_ram_addr-file_info)
FILE_HANDLE	=	(fi_handle-file_info)
FILE_LNKOFFSET	=	(fi_lnkoffset-file_info)
FILE_OFFSET	=	(fi_offset-file_info)
FILE_PACKSIZE	=	(fi_packsize-file_info)
FILE_SIZE	=	(fi_size-file_info)
FILE_NODEPACK	=	(fi_nodepack-file_info)
FILE_NOCACHE	=	(fi_nocache-file_info)
FILE_CACHED	=	(fi_cached-file_info)
FILE_CACHE_BUF	=	(fi_cache_buf-file_info)

	; pexec command line.
cmdline
	dc.b	1," ",0
	even

	; Program1 library filename.
lnkprog1
	dc.b	"intro.lnk",0
	even

	; Program2 library filename.
lnkprog2
	dc.b	"game.lnk",0
	even

***************************************************************************
* 9. Resident data: game patching at runtime (cracking & trainer)
***************************************************************************

	; Loading & depacking address of the current intro
	; music file.
music_buffer
	dc.l	0
music_next_track_i
	dc.l	0

	; Table providing a mapping between sector (actually
	; track) numbers and file numbers for loading the music
	; during the game's intro.
	; See trap3_intro_music()
music_next_track
	dc.w	1,2,3,4,5,6
	dc.w	17,18,19,20,21,22,23,24,25,26,27,28
	dc.w	29,30,31,32,33,34,35,36,37,38,39,40,41,42
	dc.w	9999

	; Intro music filenames.
music_fname
	dc.b	"safari_"
music_idx
	dc.b	"a.spl",0
	even

	; Replicants are the best!
score_text
	dc.b	"REPLICANTS         ", 0
	dc.b	"REPLICANTS         ", 0
	dc.b	"REPLICANTS         ", 0
	dc.b	"REPLICANTS         ", 0
	dc.b	"REPLICANTS         ", 0
score_text_end
	even

	; Trainer mode descriptor.
	; Used at runtime to patch the game according to the
	; selected trainer options.
trainer_info_p
	ds.l	1
trainer_info
tr_lives
	dc.b	0
tr_level
	dc.b	0
tr_pic_score
	dc.b	1
tr_score
	dc.b	1
trainer_info_end
	even

TRAINER_LIVES	  =	(tr_lives-trainer_info)
TRAINER_LEVEL	  =	(tr_level-trainer_info)
TRAINER_PIC_SCORE =	(tr_pic_score-trainer_info)
TRAINER_SCORE	  =	(tr_score-trainer_info)

***************************************************************************
* End of resident data
* Code and data located before this limit are resident, that is remain
* allocated during the execution of the game. They are needed during game
* execution.
* Code and data located after this limit are freed before executing the
* game. They are not needed during game execution (e.g. internal intro).
* Additional resident data should be dynamically allocated starting from
* here (e.g. the depacking cache).
***************************************************************************

resident_data_next

***************************************************************************
* 10. Non-resident code: initialization routines
***************************************************************************

	; get_config()
	; Get the operating mode of the loader (this program).
	; This loader can handle multiple programs and their
	; associated library files. In particular this loader
	; can be executed multiple times, each time for a
	; different program and associated library file.
	; Therefore a configuration variable is used to drive
	; the loader operations:
	; - which program is handled,
	; - when the init/backup/restoring of the system is
	;   performed,
	; - when the intro is executed.
	; That configuration variable can be inherited from the
	; parent of this loader. If the parent program has the
	; "REPS" magic located at offset 2 from the beginning of
	; the code , then the next 4 bytes hold the address of
	; the parent configuration variable.
	; Otherwise, a local config variable is used instead.
	; Note that system backup and restoring require some
	; persistent memory. The parent program shall also
	; provide these memory areas. Their addresses are
	; given right after the parent configuration variable
	; address.
	; Called from supexec.
	; Out:
	;   d0: return value
	; Scratch: a0-a1
get_config
	; Get the base page.
	movea.l	base_page(pc),a0
	; Get the base page of the parent program.
	move.l	9*4(a0),d0
	beq.s	prog_cfg_ret
	movea.l	d0,a0
	; Get the start address of the parent program code.
	movea.l	2*4(a0),a0
	; Move to offset 2.
	addq.l	#2,a0
	; Check if the address is valid.
	cmp.l	$436.w,a0
	bhs.s	prog_cfg_local
	; Check for the "REPS" magic.
	cmp.l	#'REPS',(a0)+
	bne.s	prog_cfg_local
prog_cfg_parent
	; 1st entry: address of parent configuration variable.
	lea	config_p(pc),a1
	move.l	(a0)+,(a1)
	; 2nd entry: address of saved machine configuration.
	lea	mach_conf_p(pc),a1
	move.l	(a0)+,(a1)
	; 3rd entry: address of saved trainer information.
	lea	trainer_info_p(pc),a1
	move.l	(a0)+,(a1)
	bra.s	prog_cfg_ret
prog_cfg_local
	; Use local variables if not provided by the parent.
	lea	config(pc),a0
	lea	config_p(pc),a1
	move.l	a0,(a1)
	lea	mach_conf(pc),a0
	lea	mach_conf_p(pc),a1
	move.l	a0,(a1)
	lea	trainer_info(pc),a0
	lea	trainer_info_p(pc),a1
	move.l	a0,(a1)
prog_cfg_ret
	moveq.l	#0,d0
	rts

	; save_vecs()
	; - Save CPU exception vectors
	; - Save trap vectors
	; - Copy original GEMDOS trap#1 vector to trap#11
	; - Determine trap exception stack frame size which
	;   is different on 680000 and 68010+ CPUs
	; Called from supexec.
	; Out:
	;   d0: return value
	; Scratch: a0-a2
save_vecs
	; Save CPU exception vectors.
	moveq.l	#9,d0
	lea	$8.w,a0
	lea	vecs_conf(pc),a2
	lea	CPU_EXCEPTS(a2),a1
save_excepts_lp
	move.l	(a0)+,(a1)+
	dbf	d0,save_excepts_lp

	; Save trap vectors.
	moveq.l	#15,d0
	lea	$80.w,a0
	lea	TRAPS(a2),a1
save_traps_lp
	move.l	(a0)+,(a1)+
	dbf	d0,save_traps_lp

	; Determine trap exception stack frame size.
	lea	trap11_sf_size(pc),a0
	move.l	a0,$80+(11*4).w
	move.l	a7,d0
	trap	#11
	move.l	d0,TRAP_SF_SIZE(a2)

	; Install trap#11.
	move.l	$84.w,$80+(11*4).w

	moveq.l	#0,d0
	rts

trap11_sf_size
	sub.l	a7,d0
	rte

	; mach_setup()
	; Save the machine configuration and setup a
	; ST-compatible CPU & screen configuration.
	; Called from supexec.
	; Out:
	;   d0: return value
	; Scratch: a0-a1
mach_setup
	movea.l	mach_conf_p(pc),a1

	; Setup machine configuration once.
	tst.w	CONF_DONE(a1)
	bne.s	mach_setup_ret

	; Hide mouse and clear conterm.
	move.l	a1,-(a7)
	dc.w	$a00a
	move.l	(a7)+,a1
	clr.b	$484.w

	; Determine the machine type (ST/STe/MegaSTe/TT/Falcon).
	bsr.s	get_mch_type

	; Save the machine type.
	lea	MACH2CPU(a1),a0
	move.w	d0,MCH_TYPE(a0)

	; Save and setup CPU state: caches & freq, bus config.
	bsr.s	cpu_setup

	; Save and setup screen config: resolution, palette.
	lea	MACH2SCREEN(a1),a0
	bsr	screen_setup

	; Indicate machine config has been setup.
	st	CONF_DONE(a1)
mach_setup_ret
	moveq.l	#0,d0
	rts

	; get_mch_type()
	; Walk through the cookie jar table to determine
	; the current machine type: ST/STe/MegaSTe/TT/Falcon.
	; out:
	;   d0: machine type
get_mch_type
	movem.l	d1/a0,-(a7)

	moveq.l	#0,d0
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
	movem.l	(a7)+,d1/a0
	rts

	; cpu_setup()
	; Save CPU state: caches & freq, bus config.
	; Setup a ST-compatible CPU configuration.
	; in:
	;   a0: cpu_conf
cpu_setup
	movem.l	d0-d2/a0-a2,-(a7)
	move.l	a0,a2

	; Disable caches using the cacr register.
	move.l	$10.w,-(a7)
	movea.l	a7,a0
	lea	cache_dis_done(pc),a1
	move.l	a1,$10.w
	nop                	; Flush write pipeline

	moveq.l	#0,d0
	dc.w	$4e7a,$0002	; movec cacr,d0
	move.w	d0,d1
	and.w	#$0101,d1
	asl.w	#3,d1
	or.w	d1,d0      	; Flush enabled caches
	dc.w	$4e7b,$0002	; movec d0,cacr
	moveq.l	#0,d1      	; Disable I/D caches
	dc.w	$4e7b,$1002	; movec d1,cacr

cache_dis_done
	movea.l	a0,a7
	move.l	(a7)+,$10.w

	; Save original cacr register.
	move.l	d0,CACR(a2)

	move.w	MCH_TYPE(a2),d0

	; Save MegaSTe freq/cache config,
	; setup 8Mhz uncached MegaSTe CPU.
	cmp.b	#MCH_MEGASTE,d0
	bne.s	bus_compat_falcon
	move.b	$ffff8e21.w,CACHE_MEGASTE(a2)
	clr.b	$ffff8e21.w	; 8Mhz uncached CPU
	bra.s	cache_dis_ct60

	; Save Falcon bus control,
	; setup 8Mhz Falcon CPU and STe bus emulation.
bus_compat_falcon
	cmp.b	#MCH_FALCON,d0
	bne.s	cache_dis_ct60
	move.b	$ffff8007.w,BUS_FALCON(a2)
	clr.b	$ffff8007.w	; 8Mhz CPU + STe bus emul

	; Disable caches on CT60.
cache_dis_ct60
	and.w	#MCH_CT60,d0
	beq.s	cpu_setup_ret

	clr.w	-(a7)      	; Switch off all caches
	move.w	#5,-(a7)
	move.w	#160,-(a7)
	trap	#14
	addq.l	#6,a7
cpu_setup_ret
	movem.l	(a7)+,d0-d2/a0-a2
	rts

	; screen_setup()
	; Save screen state: resolution, palette.
	; Setup a ST-compatible low screen resolution.
	; in:
	;   a0: screen_conf
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

	move.w	MCH_TYPE-CPU2SCREEN(a4),d0
	cmp.b	#MCH_FALCON,d0
	bne.s	scr_set_st

	; Falcon ST-compatible low rez setup.

	; Get current video mode.
	move.w	#-1,-(a7)
	move.w	#88,-(a7)
	trap	#14
	addq.l	#4,a7
	move.w	d0,VIDEOMODE(a4)
	move.w	#3,REZ(a4)

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

	; Compute ST-compatible low rez param (VSetscreen).
scr_set_falcon
	; VSetscreen modecode.
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
	; Save current screen resolution.
	move.w	#4,-(a7)
	trap	#14
	addq.l	#2,a7
	move.w	d0,REZ(a4)
	clr.w	VIDEOMODE(a4)

	; Compute ST/STe/MegaSTe/TT low rez param (VSetscreen).
	moveq.l	#0,d0
	move.l	d0,LOWREZ_V(a4)

scr_set_common
	; Common ST/Falcon setscreen trap invocation.
	move.l	d0,-(a7)
	move.l	PHYSBASE(a4),-(a7)
	move.l	LOGBASE(a4),-(a7)
	move.w	#5,-(a7)
	trap	#14
	lea	14(a7),a7
scr_set_cont
	; On Falcon, the ST palette is active at next sync
	; signal only.
	bsr	vsync

	; Save ST palette.
	movem.l	$ffff8240.w,d0-d7
	movem.l	d0-d7,PALETTE(a4)

	; Do not change the palette if screen setup failed.
	tst	REZ_INVALID(a4)
	bne.s	scr_set_ret

	; Set all 16 colors to the current color
	; of the background.
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

***************************************************************************
* 11. Non-resident code: intro
***************************************************************************

	; print_wait()
	; Print "please wait".
	; Called from supexec.
	; Out:
	;   d0: return value
	; Scratch: a0
print_wait
	movem.l	d3-d7/a3-a6,-(a7)

	; Initialize text printing context.
	bsr	init_txt

	; Fade colors to black.
	lea	black_pal(pc),a0
	bsr	pal_fade

	; Print the text.
	lea	txt_wait(pc),a0
	bsr	print_txt

	; Fade colors to the palette colors.
	lea	fonts_pal(pc),a0
	bsr	pal_fade

	movem.l	(a7)+,d3-d7/a3-a6
	moveq.l	#0,d0
	rts	

	; intro()
	; Internal intro: print a text using fancy fonts
	; and handle trainer options if any.
	; Called from supexec.
	; Out:
	;   d0: return value
	; Scratch: a0
intro
	movem.l	d3-d7/a3-a6,-(a7)

	; Initialize text printing context.
	bsr	init_txt

	; Main intro loop.
intro_lp
	; Fade colors to black.
	lea	black_pal(pc),a0
	bsr	pal_fade

	; Print main text.
	lea	txt_intro(pc),a0
	bsr	print_txt

	; Print trainer options.
	bsr	print_opts

	; Fade colors to the palette colors.
	lea	fonts_pal(pc),a0
	bsr	pal_fade

	; Key handling of main text.
intro_key_wait
	bsr.s	xreadchar	; read key
	cmp.b	#' ',d0
	beq.s	intro_key_end	; start game
	cmp.b	#'x',d0
	beq.s	intro_extra	; extra message
	bsr	handle_opt	; trainer options
	bsr	print_opts
	bra.s	intro_key_wait
intro_key_end
	; Fade colors to black.
	lea	black_pal(pc),a0
	bsr	pal_fade

	; Clear screen
	lea	cls(pc),a0
	bsr	print_txt

	; Call game-specific routine to handle
	; selected trainer options.
	bsr	setup_trainer

	movem.l	(a7)+,d3-d7/a3-a6
	moveq.l	#0,d0
	rts

	; Print the extra message.
intro_extra
	lea	black_pal(pc),a0
	bsr	pal_fade

	lea	txt_extra(pc),a0
	bsr	print_txt

	lea	fonts_pal(pc),a0
	bsr	pal_fade

	; Wait for the space key to be pressed to
	; print the greetings text.
extra_key_wait
	bsr.s	xreadchar
	cmp.b	#' ',d0
	beq.s	intro_greet
	bra.s	extra_key_wait

	; Print the greetings message.
intro_greet
	lea	black_pal(pc),a0
	bsr	pal_fade

	lea	txt_greet(pc),a0
	bsr	print_txt

	lea	fonts_pal(pc),a0
	bsr	pal_fade

	; Wait for the space key to be pressed to
	; return to the main text.
greet_key_wait
	bsr.s	xreadchar
	cmp.b	#' ',d0
	beq	intro_lp
	bra.s	greet_key_wait

	; xreadchar()
	; Read a character and return the corresponding
	; ASCII code.
	; Use our own scancode/keycode mapping.
	; out:
	;   d0: ASCII code of pressed key
xreadchar
	movem.l	d1/a0,-(a7)

	; Loop until a valid key has been pressed.
xreadchar_miss
	; Invoke GEMDOS Crawcin.
	bsr	readchar
	; Get the scancode.
	swap	d0

	; Get the keycode from the scancode.
	lea	key_map(pc),a0
xreadchar_lp
	move.b	(a0),d1
	beq.s	xreadchar_miss
	cmp.b	d0,d1
	beq.s	xreadchar_hit
	addq.l	#2,a0
	bra.s	xreadchar_lp
xreadchar_hit
	; A valid key has been pressed, return
	; the corresponding ASCII code.
	moveq.l	#0,d0
	move.b	1(a0),d0

	movem.l	(a7)+,d1/a0
	rts

	; print_opts()
	; Print trainer options described in the
	; opts_info table.
print_opts
	movem.l	d0-d1/a0-a1,-(a7)

	; Wait for vsync.
	bsr	vsync

	; Walk through the trainer options description
	; table and print each trainer option.
	lea	opts_info(pc),a1
	move.w	(a1)+,d1	; number of options
	subq.w	#1,d1   	; -1 for dbf
prt_opt_lp
	movea.l	a1,a0
	; Get trainer option text.
	adda.l	(a1)+,a0
	; Get trainer option type:
	;   0: boolean (Y/N)
	;  !0: numeric
	tst.w	(a1)+
	bne.s	prt_opt_num
prt_opt_bool
	move.b	#'*',d0
	; Check the boolean value.
	tst.w	(a1)+
	bne.s	prt_opt_doprt
	move.b	#' ',d0
	bra.s	prt_opt_doprt
prt_opt_num
	; Get the numeric value.
	move.w	(a1)+,d0
	; Transform that value into a numeric ASCII code.
	add.b	#$30,d0
prt_opt_doprt
	; Patch the trainer option text and print it.
	move.b	d0,4(a0)
	bsr	print_txt

	; Handle next option.
	dbf	d1,prt_opt_lp

	movem.l	(a7)+,d0-d1/a0-a1
	rts

	; handle_opt()
	; Update the opts_info table describing trainer options
	; according to the key pressed by the user.
	; in:
	;   d0: ASCII code of pressed key
handle_opt
	movem.l	d0/a0,-(a7)

	; Get the table entry corresponding to the selected
	; option. Option 1 to n is selected by pressing key
	; '1' to 'n' (ASCII code).
	lea	opts_info(pc),a0
	sub.b	#$31,d0
	; Check if the selected trainer option is valid.
	cmp.w	(a0),d0
	bhs.s	hdl_opt_ret

	lsl.w	#3,d0
	lea	2+4(a0,d0.w),a0
	tst.w	(a0)+
	bne.s	hdl_opt_num

	; Boolean trainer option: toggle the option value.
hdl_opt_bool
	not.w	(a0)
	bra.s	hdl_opt_ret

	; Numeric trainer option: increment the option value.
hdl_opt_num
	move.w	(a0),d0
	addq.b	#1,d0
	; Check that the new value is in the allowed range.
	; -1(a0) gives the highest allowed value,
	; -2(a0) gives the lowest allowed value.
	cmp.b	-1(a0),d0
	bls.s	hdl_opt_num_ok
	move.b	-2(a0),d0
hdl_opt_num_ok
	move.w	d0,(a0)
hdl_opt_ret
	movem.l	(a7)+,d0/a0
	rts

	; cols_black()
	; Set low rez colors to black.
cols_black
	movem.l	d0-d7,-(a7)
	movem.l	black_pal(pc),d0-d7
	movem.l	d0-d7,$ffff8240.w
	movem.l	(a7)+,d0-d7
	rts

	; pal_fade()
	; Fade current low rez colors to the given palette.
	; Each color is gradually transformed to match the
	; target color in the palette.
	; At each vsync (a fading iteration), only one component
	; at a time (R, G, B) is modified in all colors.
	; in:
	;   a0: target colors palette
pal_fade
	movem.l	d0-d3/a0-a2,-(a7)

	movea.l	a0,a2
	; The following table describes the order in which
	; color components are modified.
	; At each fading iteration, a single component is
	; modified in all colors.
	lea	col_fade_tbl(pc),a0
	lea	$ffff8240.w,a1

pal_fade_loop
	; Each new fading iteration starts after a vsync.
	bsr	vsync
	moveq.l	#0,d2
	move.l	d2,d3

	; Iterate the 16 low rez colors (d2 = color index).
pal_fade_1
	; Get the value of the current color.
	move.w	(a1,d2.w),d0
	; STF/STE compat.
	and.w	#$777,d0
	; Get the value of the target color.
	move.w	(a2,d2.w),d1
	; A step forward in fading the current color
	; to the target color.
	bsr.s	col_fade_1
	; Set the new color.
	move.w	d0,(a1,d2.w)
	; Check if the color actually changed.
	cmp.w	d0,d1
	; Set a bit in d3 if it is the case.
	sne.b	d3
	lsl.l	#1,d3
	addq.b	#2,d2
	cmp.b	#16*2,d2
	blo.s	pal_fade_1

	; If no color was changed, we're done.
	tst.l	d3
	beq.s	pal_fade_done
	; Select next color component to be modified at
	; next iteration.
	addq.l	#4,a0
	tst.w	(a0)
	bne.s	pal_fade_loop
	lea	col_fade_tbl(pc),a0
	bra.s	pal_fade_loop
pal_fade_done
	movem.l	(a7)+,d0-d3/a0-a2
	rts

	; col_fade_1()
	; Change only one component (R, G or B) in the
	; current color to get closer to the target color.
	; in:
	;   d0: current color value
	;   d1: target color value
	;   a0: table entry describing the color component
	;       (R, G or B) that must be modified
col_fade_1
	movem.l	d1-d3,-(a7)

	move.w	(a0),d3
	move.w	d0,d2
	and.w	d3,d2
	and.w	d3,d1
	cmp.w	d2,d1
	beq.s	col_fade_1_ret
	bhs.s	col_fade_1_add
	; Target color component is darker than
	; current color component.
	sub.w	2(a0),d2
	bra.s	col_fade_1_res
coL_fade_1_add
	; Target color component is brighter than
	; current color component.
	add.w	2(a0),d2
col_fade_1_res	not.w	d3
	and.w	d3,d0
	or.w	d2,d0
col_fade_1_ret
	movem.l	(a7)+,d1-d3
	rts

	; init_txt()
	; Initialize text printing context:
	; - screen physical address
	; - text coordinates (cursor position)
init_txt
	movem.l	a0-a1,-(a7)

	lea	txt_state(pc),a0
	movea.l	mach_conf_p(pc),a1
	move.l	MACH2SCREEN+PHYSBASE(a1),TXT_PHYSBASE(a0)
	clr.l	TXT_POSX(a0)
	clr.l	TXT_POSY(a0)

	movem.l	(a7)+,a0-a1
	rts	

	; print_txt()
	; Print a null-terminated text/string onto the screen,
	; using fancy fonts.
	; Use the same special characters as the GEMDOS Cconws
	; function: CR, LF, ESC sequences.
	; in:
	;   a0: text buffer
print_txt
	movem.l	d0-d3/a0-a3,-(a7)

	; a3 = text buffer.
	movea.l	a0,a3
	; a0 = text printing context.
	lea	txt_state(pc),a0

	; Iterate each text character.
prt_loop
	moveq.l	#0,d0
	move.b	(a3)+,d0
prt_lf
	cmp.b	#10,d0	; LF
	bne.s	prt_cr
	; Update Y cursor position (in bytes).
	add.l	#160*8,TXT_POSY(a0)
	bra.s	prt_loop
prt_cr
	cmp.b	#13,d0	; CR
	bne.s	prt_end
	; Reset X cursor position (in bytes).
	clr.l	TXT_POSX(a0)
	bra.s	prt_loop
prt_end
	cmp.b	#0,d0	; END
	beq.s	prt_ret
prt_escape
	cmp.b	#27,d0	; ESC
	bne.s	prt_char
	movea.l	a3,a1
	; Handle ESC sequence.
	bsr.s	print_escape
	movea.l	a1,a3
	bra.s	prt_loop
prt_char
	; Print normal character.
	bsr.s	print_char
	; Handle next character.
	bra.s	prt_loop
prt_ret
	movem.l	(a7)+,d0-d3/a0-a3
	rts

	; print_char()
	; Print a normal character onto the screen
	; at current cursor position.
	; in:
	;   d0: printable ASCII character
	;   a0: text printing context
	; scratch: d0,a1-a2
print_char
	lea	fonts(pc),a1
	sub.b	#$20,d0
	lsl.l	#5,d0
	; a1 = source font address.
	adda.l	d0,a1
	movea.l	TXT_PHYSBASE(a0),a2
	adda.l	TXT_POSY(a0),a2
	move.l	TXT_POSX(a0),d0
	; a2 = screen target address
	adda.l	d0,a2
	; Increment cursor X position (in bytes).
	addq.w	#1,d0
	btst	#0,d0
	bne.s	prt_even
	addq.w	#6,d0
prt_even
	move.l	d0,TXT_POSX(a0)
	; Copy character font.
	moveq.l	#7,d0
prt_blk
	move.b	(a1)+,(a2)
	move.b	(a1)+,2(a2)
	move.b	(a1)+,4(a2)
	move.b	(a1)+,6(a2)
	lea	160(a2),a2
	dbf	d0,prt_blk

	rts

	; print_escape()
	; Handle an ASCII code control (ESC) sequence.
	; Supported sequences are:
	; - ESC E : clear screen
	; - ESC Y : set cursor position
	; - ESC f : hide cursor
	; in:
	;   a0: text printing context
	;   a1: pointer to the control character (right after
	;       the ESC character)
	; out:
	;   a1: pointer to the character following
	;       the ESC sequence
print_escape
	movem.l	d0-d1/a2,-(a7)
	; Get the control character.
	move.b	(a1)+,d0
prt_esc_cls
	cmp.b	#"E",d0
	bne.s	prt_esc_pos

	; Clear screen.
	movea.l	TXT_PHYSBASE(a0),a2
	move.l	#$7d00/16-1,d0
prt_cls_lp
	clr.l	(a2)+
	clr.l	(a2)+
	clr.l	(a2)+
	clr.l	(a2)+
	dbf	d0,prt_cls_lp
	bra.s	prt_esc_ret
prt_esc_pos
	cmp.b	#"Y",d0
	bne.s	prt_esc_curoff

	; Set cursor position.
	; X & Y cursor positions (TXT_POSX and TXT_POSY)
	; are in bytes.
	moveq.l	#0,d0
	move.b	(a1)+,d0
	sub.b	#32,d0
	mulu	#160*8,d0
	move.l	d0,TXT_POSY(a0)
	moveq.l	#0,d0
	move.b	(a1)+,d0
	sub.b	#32,d0
	move.w	d0,d1
	bclr	#0,d0
	lsl.w	#2,d0
	and.b	#1,d1
	add.w	d1,d0
	move.l	d0,TXT_POSX(a0)
	bra.s	prt_esc_ret
prt_esc_curoff
	cmp.b	#"f",d0
	bne.s	prt_esc_ret

	; Hide cursor: nothing to do.
	nop
prt_esc_ret
	movem.l	(a7)+,d0-d1/a2
	rts

***************************************************************************
* 12. Non-resident data: intro
***************************************************************************

	; For Falcon only.
txt_rez
	dc.b	27,"E"
	dc.b	"INCOMPATIBLE SCREEN RESOLUTION!"
	dc.b	0
	even

	; Before loading the game.
txt_wait
	dc.b	27,"E",27,"Y",44,47
	dc.b	"PLEASE WAIT"
	dc.b	0
	even

	; Main text.
txt_intro
	dc.b	27,"E",27,"Y",32,32
	dc.b	"  THE REPLICANTS - ATARI LEGEND - HMD   ",10,13
	dc.b	"               BRING YOU                ",10,13
	dc.b	10,13
	dc.b	"        --  SAFARI GUNS 100%  --        ",10,13
	dc.b	10,13
	dc.b	"    PACKED/LINKED/TRAINED/BUG-FIXED     ",10,13
	dc.b	"    512KB/HARD-DRIVE/FALCON SUPPORT     ",10,13
	dc.b	10,13
	dc.b	"         RETRO-HACKED BY ORION          ",10,13
	dc.b	10,13
	dc.b	"      ORIGINAL KRYOFLUXED BY BRUME      ",10,13
	dc.b	10,13
	dc.b	"       XMAS INTRO CODE BY KELLY.X       ",10,13
	dc.b	"  GRAPHICS BY DIEU AND MUSIC BY DMA-SC  ",10,13
	dc.b	10,13
	dc.b	"    1>  UNLIMITED LIVES          [ ]    ",10,13
	dc.b	"    2>  MAX POINTS PER PICTURE   [ ]    ",10,13
	dc.b	"    3>  ALWAYS REACH NEXT LEVEL  [ ]    ",10,13
	dc.b	"    4>  STARTING LEVEL           [ ]    ",10,13
	dc.b	"    5>  SKIP GAME INTRO          [ ]    ",10,13
	dc.b	10,13
	dc.b	"   PRESS KEYS 1-5 FOR TRAINER OPTIONS   ",10,13
	dc.b	"       HIT X FOR AN EXTRA MESSAGE       ",10,13
	dc.b	"          BASH SPACE TO START           ",10,13
	dc.b	0
	even

	; Characters of trainer options
	; (patched with proper characters when options change).
txt_opt1
	dc.b	27,"Y",47,66," ",0
txt_opt2
	dc.b	27,"Y",48,66," ",0
txt_opt3
	dc.b	27,"Y",49,66," ",0
txt_opt4
	dc.b	27,"Y",50,66," ",0
txt_opt5
	dc.b	27,"Y",51,66," ",0
	even

	; Trainer options description table
	; (used to patch previous character strings).
opts_info
	; Number of trainer options
	dc.w	5
opt1_info
	dc.l	txt_opt1-opt1_info
	dc.w	0,0
opt2_info
	dc.l	txt_opt2-opt2_info
	dc.w	0,0
opt3_info
	dc.l	txt_opt3-opt3_info
	dc.w	0,0
opt4_info
	dc.l	txt_opt4-opt4_info
	dc.b	1,5
	dc.w	1
opt5_info
	dc.l	txt_opt5-opt5_info
	dc.w	0,0

	; Extra text.
txt_extra
	dc.b	27,"E",27,"Y",33,32
	dc.b	"    -- SPECIAL MESSAGE FROM ORION --    ",10,13
	dc.b	10,13
	dc.b	"YOU CAN  FIND THE  SOURCE CODE  OF  THIS",10,13
	dc.b	"CRACK  WITH  DETAILED  EXPLANATIONS  AT ",10,13
	dc.b	10,13
	dc.b	"https://github.com/orionfuzion/newcracks",10,13
	dc.b	10,13
	dc.b	"THE COPY-PROTECTION  USED IN THIS  GAME,",10,13
	dc.b	"THE TECHNIQUES TO CRACK IT  AND THE FULL",10,13
	dc.b	"ASM CODE  OF THIS LOADER (MULTI-MACHINES",10,13
	dc.b	"SUPPORT,  ON-THE-FLY  DEPACKING  OF  THE",10,13
	dc.b	"GAME FILES...) ARE DESCRIBED  IN DETAILS",10,13
	dc.b	"FOR DIDACTIC PURPOSES.                  ",10,13
	dc.b	10,13
	dc.b	"IF YOU ARE A FORMER OR ACTIVE CRACKER ON",10,13
	dc.b	"ATARI ST,  PLEASE  SHARE YOUR  KNOWLEDGE",10,13
	dc.b	"AND  PUBLISH  YOUR SOURCES  OR ANY OTHER",10,13
	dc.b	"VALUABLE MATERIAL.  TECHNIQUES DEVELOPED",10,13
	dc.b	"BY  THE ATARI ST  HACKERS  MUST NOT FADE",10,13
	dc.b	"INTO OBLIVION.                          ",10,13
	dc.b	10,13
	dc.b	"         BANG SPACE TO CONTINUE         ",10,13
	dc.b	0
	even

	; Greetings text.
txt_greet
	dc.b	27,"E",27,"Y",32,32
	dc.b	"GREETINGS ARE  FLYING TO:  ATARI LEGEND,",10,13
	dc.b	"HMD, ELITE,  ECG, D-BUG, PPERA,  EFFECT,",10,13
	dc.b	"NOEXTRA, MJJ PROD,  SECTOR ONE, NEWLINE,",10,13
	dc.b	"CHECKPOINT,  MYSTIC  BYTES,  DHS,  SMFX,",10,13
	dc.b	"DEKADENCE,  DYNO, AVENA, MR STYCKX, PHF,",10,13
	dc.b	"tSCc, FLUSH, RGCD,  CEREBRAL VORTEX  AND",10,13
	dc.b	"ALL ACTIVE ATARI ST SCENERS!",10,13
	dc.b	10,13
	dc.b	"HI TO: BRUME, JACE, DIEU, MAARTAU, MARA,",10,13
	dc.b	"COOPER,  LOTEK STYLE, SENSER, MR. NOURS,",10,13
	dc.b	"ZORRO2, MUG U.K, MIT, DBUG II, GUNSTICK,",10,13 
	dc.b	"ADORU, ROCKABIT, TROED,  BANDIT, MARCER,",10,13
	dc.b	"ST SURVIVOR, BOSS,  AN COOL, MELLOW MAN,",10,13
	dc.b	"VINCENT RIVIERE, KOVAX, AVB, JEF GREZES,",10,13
	dc.b	"DOCNO, SQUAT,  KASAR,  LAURENZO,  ZAE...",10,13
	dc.b	10,13
	dc.b	"WARM  HELLO  TO ALL  REPLICANTS MEMBERS:",10,13
	dc.b	"ELLFIRE,  CAMEO, ILLEGAL,  FURY,  SNAKE,",10,13
	dc.b	"EXCALIBUR, RANK XEROX,  DOM, BLACK ANGEL",10,13
	dc.b	"AND ALL THE OTHERS WE HOPE  TO HEAR FROM",10,13
	dc.b	"SOON...",10,13
	dc.b	10,13
	dc.b	"   GET READY FOR OUR NEXT PRODUCTION!   ",10,13
	dc.b	10,13
	dc.b	"        SMASH SPACE TO CONTINUE         ",10,13
	dc.b	0
	even

	; Scancode/ASCII mapping.
key_map
	dc.b	$0b,'0',$02,'1',$03,'2',$04,'3',$05,'4',$06,'5',$07,'6',$08,'7',$09,'8',$0a,'9'
	dc.b	$70,'0',$6d,'1',$6e,'2',$6f,'3',$6a,'4',$6b,'5',$6c,'6',$67,'7',$68,'8',$69,'9'
	dc.b	$39,' ',$2d,'x',$14,'t',$00
	even

	; How color components are modified during colors fading. 
col_fade_tbl
	dc.w	$f00,$100,$0f0,$010,$00f,$001,0
col_fade_tbl_i
	dc.l	0

	; Context used to print a text without TOS support.
txt_state
ts_physbase
	ds.l	1	; Screen phys base
ts_posx
	ds.l	1	; X position in bytes
ts_posy
	ds.l	1	; Y position in bytes
txt_state_end

TXT_PHYSBASE	=	(ts_physbase-txt_state)
TXT_POSX	=	(ts_posx-txt_state)
TXT_POSY	=	(ts_posy-txt_state)

	; Black color palette.
black_pal
	ds.w	16

	; Fonts palette.
	; Original "bluescale" converted to a greyscale by Orion.
fonts_pal
	dc.w	$000,$000,$000,$000,$000,$000,$000,$000
	dc.w	$223,$333,$334,$444,$555,$666,$777,$000

	; Fonts by Walt (L'Ing) coming from the Bloody Intro coded by Fury.
fonts
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
	dc.b	$0,$0,$0,$0,$0,$0,$8,$8,$0,$0,$8,$8,$0,$0,$0,$0,$8,$8,$0,$8,$0,$8,$0,$8,$0,$0,$0,$0,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$8,$8,$0,$0,$8,$8,$0,$0,$0,$0,$8,$8,$0,$8,$0,$8,$0,$8,$0,$10,$0,$10,$0,$0,$0,$0
	dc.b	$4,$4,$0,$4,$0,$0,$8,$8,$10,$0,$10,$10,$20,$0,$20,$20,$10,$10,$0,$10,$0,$8,$0,$8,$4,$0,$0,$4,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$56,$26,$78,$7E,$0,$0,$0,$0,$0,$0,$0,$0,$72,$7C,$0,$7E,$0,$0,$0,$0,$0,$0,$0,$0
	dc.b	$0,$0,$20,$20,$0,$0,$10,$10,$0,$0,$8,$8,$4,$4,$0,$4,$8,$8,$0,$8,$10,$10,$0,$10,$0,$20,$0,$20,$0,$0,$0,$0
	dc.b	$1C,$1C,$20,$3C,$42,$2,$40,$42,$2,$2,$0,$2,$4,$4,$0,$4,$8,$8,$0,$8,$0,$0,$0,$0,$8,$0,$0,$8,$0,$0,$0,$0
	dc.b	$1C,$1C,$20,$3C,$42,$2,$40,$42,$42,$2,$48,$4A,$40,$2,$48,$4A,$4,$4,$40,$44,$40,$40,$0,$40,$E,$30,$0,$3E,$0,$0,$0,$0
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
	dc.b	$6,$6,$18,$1E,$10,$0,$10,$10,$0,$0,$10,$10,$10,$10,$0,$10,$10,$10,$0,$10,$0,$10,$0,$10,$18,$0,$0,$1E,$0,$0,$0,$0
	dc.b	$0,$0,$80,$80,$40,$0,$40,$40,$20,$0,$20,$20,$10,$10,$0,$10,$0,$8,$0,$8,$4,$0,$0,$4,$0,$0,$0,$2,$0,$0,$0,$0
	dc.b	$60,$0,$78,$78,$0,$0,$8,$8,$0,$0,$8,$8,$8,$8,$0,$8,$0,$8,$0,$8,$8,$0,$0,$8,$38,$40,$0,$78,$0,$0,$0,$0
	dc.b	$0,$0,$10,$10,$0,$20,$28,$28,$44,$4,$40,$44,$80,$82,$0,$82,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$38,$C0,$0,$FE,$0,$0,$0,$0
	dc.b	$0,$0,$8,$8,$0,$0,$8,$8,$0,$0,$8,$8,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
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
	dc.b	$6,$6,$8,$E,$0,$0,$10,$10,$10,$10,$0,$10,$20,$20,$0,$20,$0,$10,$0,$10,$10,$0,$0,$10,$C,$E,$0,$E,$0,$0,$0,$0
	dc.b	$10,$0,$10,$10,$0,$0,$10,$10,$10,$10,$0,$10,$10,$10,$0,$10,$0,$10,$0,$10,$10,$0,$0,$10,$10,$10,$0,$10,$0,$0,$10,$10
	dc.b	$50,$20,$70,$70,$0,$0,$8,$8,$8,$8,$0,$8,$0,$4,$0,$4,$8,$0,$0,$8,$8,$0,$0,$8,$10,$10,$60,$70,$0,$0,$0,$0
	dc.b	$0,$0,$0,$0,$60,$0,$60,$60,$90,$92,$0,$92,$92,$90,$0,$92,$C,$0,$0,$C,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0
	even

***************************************************************************
* Optional resident data (moved at runtime)
***************************************************************************

	; Library file directory of program1.
dirprog1
	incbin	c:intro.dir
dirprog1_end
	even
	ds.l	1

	; Library file directory of program2.
dirprog2
	incbin	c:game.dir
dirprog2_end
	even
	ds.l	1
data_end
	end
