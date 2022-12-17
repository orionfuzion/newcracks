***************************************************************************
*
* Son Shu Shi - First 100% Version
*
* Checksums removed, mega-trained, filed, repacked, linked, ramdisk,
* bug-fixed, hard-drive and MegaSTe/Falcon/TT/CT60 support.
*
* December 2022 - Orion of The Replicants.
*
* This code [LOADER2.S] is part of the loader of the game.
*
* The loader initializes the system, loads the main and hidden cracktros,
* prints the trainer menu, starts the game and patches the various programs
* of the game on-the-fly in order to implement all kinds of improvements.
*
* This source file (LOADER2.S) implements the second part of the loader.
* It is in charge of starting the game and providing all improvements
* through patches applied on-the-fly.
* The resulting binary is integrated in the 'SSS1.LNK' library file and
* executed by the first part of the loader (LOADER1.S).
* This source file implements the following components:
*
*    9. Main entry point (part #2)
*   10. FDC/DMA support
*   11. Game files loading support
*   12. Game files unpacking support
*   13. Game modifications (cracking, enhancements, bug-fixes...)
*   14. Installation and start of the game
*   15. Game preparation
*
* You should read the comments at the beginning of LOADER1.S for a
* description of the organization and contents of the various source
* files of this crack.
* Also read the comments inside the source code itself for detailed
* explanations of each routine.
*
* Git repository: https://github.com/orionfuzion/newcracks
* Contact:        orion.replicants@gmail.com or orion.fuzion@gmail.com
*
***************************************************************************

	;
	; Include common definitions.
	;
	; LOADERH.S is included only if LOADER2.S is compiled as a
	; separate binary and stored in the 'SSS1.LNK' library file.
	; This is the default behavior, and it is enforced in release
	; mode.
	;
	; However, in debug mode, LOADER2.S can be included directly
	; by LOADER1.S to facilitate development (by avoiding separate
	; compilation and loading).
	; In that case, LOADERH.S is already included by LOADER1.S
	; and must not be included by LOADER2.S.
	; PART2_IS_MERGED is defined by LOADER1.S when LOADER2.S is
	; included in source form.
	;
	ifnd	PART2_IS_MERGED
	include	"LOADERH.S"
	endc

***************************************************************************
*	
* 9. Main entry point (part #2)
*
***************************************************************************

	;
	; LOADER2.S provides a special header at offset 0, followed by
	; two dynamic symbol tables.
	; The purpose of these data structures is to allow LOADER1.S
	; to load LOADER2.S and then to dynamically link both parts,
	; allowing them to make function calls to each other and to
	; access shared variables.
	; See loader_part2_link() in LOADER1.S for explanations about
	; this dynamic linking mechanism.
	;

	section	text

loader_part2_base
	illegal	            ; 1st magic ($4afc)

	dc.l	'RLNK'      ; 2nd magic
	dc.w	DL_VERSION  ; Version number identifying the tables
	dc.w	16          ; Number of imported symbols
	ifne	DEBUG_REGS
	dc.w	4           ; Nb of exported symbols (debug mode)
	elseif
	dc.w	1           ; Nb of exported symbols (release mode)
	endc

	;
	; Imported symbols (symbol references).
	; LOADER1.S lists the same symbols in the same order in its
	; table of exported symbols (see dyn_symbs).
	;
	IMPORT	wait_ikbd
	IMPORT	send_ikbd
	IMPORT	flush_acia
	IMPORT	supexec
	IMPORT	malloc
	IMPORT	mfree
	IMPORT	fopen
	IMPORT	fsize
	IMPORT	fread
	IMPORT	fclose
	IMPORT	getdrv
	IMPORT	mach_type
	IMPORT	mach_rp
	IMPORT	opts_info
	IMPORT	lib1_fname
	IMPORT	lib2_fname

	;
	; Exported symbols (symbol definitions).
	; LOADER1.S lists the same symbols in the same order in its
	; table of imported symbols (see dyn_symbs).
	;
	EXPORT	loader_part2_entry
	ifne	DEBUG_REGS
	EXPORT	get_tpa_end
	EXPORT	calibrate_delay
	EXPORT	dma_info+DMA_FDC_DELAY
	endc

	;
	; Self-promotion.
	;
signature
	dc.b	0,"10 December 2022",0
	dc.b	"orion.fuzion@gmail.com",0
	dc.b	"orion.replicants@gmail.com",0
	dc.b	"https://github.com/orionfuzion/newcracks", 0
	even

	;
	; loader_part2_entry()
	;
	; This is the actual entry point of the second part of the
	; loader. This routine is called by LOADER1.S (using the XCALL
	; macro) after the external cracktros have been executed.
	; This routine installs the resident code (used to patch the
	; game programs on-the-fly) and starts the game.
	; It returns to LOADER1.S only in case of error.
	;
	; Out:
	;   d0: does no return if success, an error code otherwise
	;

loader_part2_entry

	; Make sure that this routine has been called by LOADER1.S:
	; - First instruction is an illegal instruction (part of the
	;   special header).
	; - LOADER1.S calls loader_part2_entry with the 'REPS' magic
	;   value in d0.
	lea	loader_part2_base(pc),a0
	cmpi.w	#$4afc,(a0)
.dead	bne.s	.dead
	cmpi.l	#'REPS',d0
	bne	loader_part2_base

	; Save the machine type which will be used for
	; machine-specific game adaptations.
	XADDR	mach_type,a0
	lea	mach_type(pc),a1
	move.w	(a0),(a1)

	;
	; First, perform sanity checks:
	; machine type, available memory...
	;
	bsr	sanity_checks
	tst.l	d0
	bmi.s	.error

	; Copy the configuration of the trainer mode from the generic
	; trainer options table that is used by the code of the trainer
	; menu into the game-specific table that is located in the
	; resident code.
	bsr	setup_trainer

	; The method used for loading the game depends
	; on the current drive.
	XCALL	getdrv
	tst.l	d0
	bne.s	.drv_hd

	;
	; Prepare game loading from drive A.
	;
.drv_a	lea	prepare_drv_a(pc),a0
	XCALL	supexec
	bra.s	.drv_ct

	;
	; Prepare game loading from HD drive.
	;
.drv_hd	bsr	prepare_drv_hd

	; Any error?
.drv_ct	tst.l	d0
	bmi.s	.error

	;
	; Run the game.
	;
	ifeq	NO_GAME_START
	lea	game_boot(pc),a0
	XCALL	supexec
	; Never returns.
	endc
	; Return only for debugging purposes (with an error).
	; Any allocated memory blocks will be freed by pterm().
	moveq.l	#EPLFMT,d0

	; Returns only in case of error.
.error	rts

***************************************************************************
*
* 10. FDC/DMA support
*
* The following code provides services for opening and reading library
* files (containing game files linked together) stored on floppy disks.
*
* Access to the library files is achieved without TOS support, by directly
* reading the sectors using FDC/DMA programming and by handling the FAT12
* filesystem.
*
* FDC/DMA support works on every machine by calibrating I/O busy-waits
* with respect to the speed of the machine.
*
* Public routines:
* - calibrate_delay()
* - open_library()
* - read_library()
* - read_sector()
* - fdc_deselect_noblock()
*
* Doc:
* - http://info-coach.fr/atari/documents/_mydoc/WD1772-JLG.pdf
* - https://info-coach.fr/atari/documents/_datasheets/WD177x-Prog.txt
* - http://info-coach.fr/atari/documents/_mydoc/FD-HD_Programming.pdf
* - http://info-coach.fr/atari/documents/_mydoc/Atari_HD_File_Sytem_Reference_Guide.pdf
* - https://www.atarimagazines.com/startv1n2/ProbingTheFDC.html
* - http://st-news.com/uploads/ST-News/Vol-2/Issue-7/PROGRAMS/PROTECT.S
* - http://bos.asmhackers.net/docs/filesystems/fat12-16-32/docs/FAT12Description.pdf
* - https://github.com/emutos/emutos/blob/master/bios/floppy.c
* - https://github.com/sarnau/AtariSTRomListings/blob/master/TOS206%2C206STBook%2C206.asm
* - https://exxosforum.co.uk/atari/last/floppy/index.htm
*
***************************************************************************

	;
	; calibrate_delay()
	;
	; Calibrate two delay loops: a first loop that lasts 50us
	; on any machines and a second delay loop of 5us.
	; Both delay loops are used during FDC/DMA operations for
	; timings and timeout purposes.
	;
	; The calibration works as follows:
	; - the timer-A is set up to operate at 100Hz
	; - a delay loop is executed during one timer-A
	;   period (10ms)
	; - the number of loop iterations executed during this
	;   period (10ms) is used to deduce the number of loop
	;   iterations required for a duration of 50us and 5us
	;   respectively.
	;
calibrate_delay
	movem.l	d0-d2/a0,-(a7)

	; Disable mouse.
	moveq.l	#$12,d0
	XCALL	send_ikbd

	; Disable joystick.
	moveq.l	#$15,d0
	XCALL	send_ikbd

	; Wait for pending IKBD events to be consumed.
	XCALL	wait_ikbd

	; Pause IKBD transfers.
	moveq.l	#$13,d0
	XCALL	send_ikbd

	; Wait for pending IKBD events to be consumed.
	XCALL	wait_ikbd

	; Disable all interrupts.
	move.w	#$2700,sr

	; Flush ACIA buffer.
	XCALL	flush_acia

	; Save MFP configuration & timer-A vector.
	lea	save_mfp(pc),a0

	move.l	$134.w,(a0)+

	move.b	$fffffa17.w,(a0)+
	move.b	$fffffa13.w,(a0)+
	move.b	$fffffa07.w,(a0)+
	move.b	$fffffa09.w,(a0)+

	; Disable all MFP interrupts.
	clr.b	$fffffa07.w     ; Interrupt Enable A
	clr.b	$fffffa09.w     ; Interrupt Enable B

	; Select Automatic End-Interrupt.
	bclr.b	#3,$fffffa17.w

	; Set up 100Hz timer-A:
	; Counter = 245
	; Divider = 100 (6 -> $fffa19)
	; Freq    = 2457600Hz / 245 / 100 = 100Hz

	; Stop timer-A.
	clr.b	$fffffa19.w     ; Timer-A Control
	; Configure timer-A.
	lea	timerA(pc),a0
	move.l	a0,$134.w       ; Timer-A vector
	bset.b	#5,$fffffa13.w  ; Interrupt Mask: timer-A
	bset.b	#5,$fffffa07.w  ; Interrupt Enable: timer-A
	move.b	#245,$fffffa1f.w ; Timer-A Data (counter)
	; Start timer-A.
	move.b	#6,$fffffa19.w  ; Timer-A Control (divider)

	moveq.l	#0,d0           ; Loop iterations number
	moveq.l	#0,d1           ; Timer-A interrupts count
	moveq.l	#0,d2           ; Saved loop iterations nb

	; Enable MFP interrupts only and stop CPU until first
	; timer-A interrupt occurs.
	stop	#$2500

	; Execute the following loop during 1 timer-A period of
	; 10 ms. The loop is stopped by the timer-A handler by
	; resetting the counter (d0) to 1.
.loop	subq.l	#1,d0
	bne.s	.loop

	; Make sure that the second timer-A interrupt has been
	; issued and thus that the number of loop iterations has
	; been saved in d2 (see timer-A handler).
.sync	cmpi.b	#2,d1
	bmi.s	.sync

	; Disable all interrupts.
	move.w	#$2700,sr

	; Stop timer-A.
	clr.b	$fffffa19.w

	; Restore MFP configuration & timer-A vector.
	lea	save_mfp(pc),a0

	move.l	(a0)+,$134.w

	move.b	(a0)+,$fffffa17.w
	move.b	(a0)+,$fffffa13.w
	move.b	(a0)+,$fffffa07.w
	move.b	(a0)+,$fffffa09.w

	; Flush ACIA buffer.
	XCALL	flush_acia

	; Re-enable interrupts.
	move.w	#$2300,sr

	; Resume IKBD transfers.
	moveq.l	#$11,d0
	XCALL	send_ikbd

	; Restore mouse.
	moveq.l	#$8,d0
	XCALL	send_ikbd

	;
	; Determine the number of loop iterations needed
	; for a duration of 50us and 5us respectively.
	;

	; The number of loop iterations has been counted backwards.
	neg.l	d2

	move.l	d2,d1
	; d2 and d1 now hold the number of loop iterations executed
	; during 1 timer-A period, that is 10000us (1/100 seconds).

	; Dividing d2 by 200 gives the number of loop iterations
	; which are executed during 50us (10000us / 200 = 50us).
.d50	divu	#200,d2
	ext.l	d2
	bne.s	.d5
	moveq.l	#1,d2

	; Dividing d1 by 2000 gives the number of loop iterations
	; which are executed during 5us (10000us / 20000 = 5us).
.d5	divu	#2000,d1
	ext.l	d1
	bne.s	.sav
	moveq.l	#1,d1

	; Save both loop counts for use during FDC/DMA operations.
.sav	lea	dma_info(pc),a0
	move.l	d2,DMA_FDC_DELAY(a0)
	move.l	d1,DMA_SHORT_DELAY(a0)

.ret	movem.l	(a7)+,d0-d2/a0
	rts

	;
	; timerA()
	;
	; Timer-A interrupt routine.
	;
timerA
	; Increment timer-A interrupts count.
	addq.l	#1,d1
	; - The first timer-A interrupt corresponds to the
	;   start of the loop execution, following the
	;   stop #$2500 instruction.
	; - The second timer-A interrupt marks the end of the
	;   timer-A period during which the loop was executed.
	;   The loop iterations number (d0) should be saved in d2
	;   and d0 should be reset to 1 in order to exit from
	;   the loop.
	cmpi.b	#2,d1
	bne.s	.ret
	move.l	d0,d2
	moveq.l	#1,d0

.ret	rte

	;
	; Saved MFP configuration.
	;
save_mfp
	ds.l	1
	ds.b	4
	even

	;
	; Start of the 'game_install' code & data block.
	; It includes all the routines needed during the installation
	; and the start of the game:
	; - The 'fileops' code & data block
	;     10. FDC/DMA support
	;     11. Game files loading support
	; - The 'depack' code & data block
	;     12. Game files unpacking support
	; - The routines that install and start the game
	;     13. Game modifications (cracking, enhancements...)
	;     14. Installation and start of the game
	;
	; This block is first copied to a low memory area by
	; game_boot() so that the game installation process can
	; be run safely from there.
	;
	; Indeed, it allows the game_install() and game_patch()
	; routines to install the game while avoiding any overlap
	; between the installation code (this block) and the areas
	; where the game components are installed.
	;
	; See sections "14. Installation and start of the game" and
	; "13. Game modifications" for a description of the game
	; installation process. 
	;
game_install_start

	;
	; Start of the 'fileops' code & data block.
	; It includes all the routines in charge of loading game
	; files from Drive-A or ramdisk:
	;   10. FDC/DMA support
	;   11. Game files loading support
	;
	; This block is installed in the main game program by
	; game_patch(), in place of the original loading routines.
	;
fileops_start

	;
	; open_library()
	;
	; Open a library file (containing linked game files)
	; stored on the floppy disk:
	; set up the context that will be used by the low-level
	; DMA/FDC routines to access the library file.
	;
	; Once opened, the contents of the library file can be
	; read using the read_library() routine below.
	;
	; In:
	;   a0: library info
	;   a1: cache buffer used for sectors loading
	;
	; Out:
	;   d0: 0 if success, EFILNF (-33) or EFDC (-1)
	;       otherwise
	;
open_library
	movem.l	d1-d2/a0-a5,-(a7)

	; Save library info pointer in a2.
	movea.l	a0,a2

	; Reset DMA (floppy) info.
	moveq.l	#1,d0
	lea	dma_info(pc),a3
	move.w	d0,DMA_SPT(a3)
	move.w	d0,DMA_NHEADS(a3)
	move.w	d0,DMA_NSECS(a3)
	st.b	DMA_CURTRK(a3)

	;
	; Read the boot sector of the floppy disk.
	;
	movea.l	a1,a0
	moveq.l	#0,d0
	; read_sector_bootstrap() should be called here only once,
	; the first time open_library() is used. read_sector() should
	; be called instead afterwards.
	; To this end, the read_sector_bootstrap() routine patches
	; the 'bsr' instruction below to replace it with a
	; 'bsr read_sector'.
	bsr	read_sector_bootstrap
	tst.l	d0
	bmi	.ret

	;
	; Set up DMA (floppy) info.
	;

	; Sectors per track.
	move.b	BPB_SPT(a0),DMA_SPT+1(a3)
	; Number of sides.
	move.b	BPB_NHEADS(a0),DMA_NHEADS+1(a3)
	; Total number of sectors.
	move.b	BPB_NSECS+1(a0),DMA_NSECS(a3)
	move.b	BPB_NSECS(a0),DMA_NSECS+1(a3)

	;
	; Set up filesystem info.
	;
	
	lea	fs_info(pc),a3
	moveq.l	#0,d0
	moveq.l	#0,d1
	; Sectors per cluster - usually 2.
	move.b	BPB_SPC(a0),FS_SPC+1(a3)
	; d0 = number of File Allocation Tables (FAT) - usually 2.
	move.b	BPB_NFATS(a0),d0
	; d1 = number of sectors per FAT.
	move.b	BPB_SPF(a0),d1
	; d0 = total number of sectors for all FATs.
	mulu	d1,d0
	; d1 = number of reserved sectors - usually 1 (boot sect).
	move.b	BPB_RES(a0),d1
	; The first sector of the root directory follows
	; the reserved and FATs sectors.
	; d0 = first sector of the root directory.
	add.w	d1,d0
	move.w	d0,FS_DIR(a3)
	; d1 = number of 32-bytes entries in the root directory.
	move.b	BPB_NDIRS(a0),d1
	; d1 = number of sectors containing the root directory.
	; (number of entries * 32 / 512).
	lsr.b	#4,d1
	move.w	d1,FS_NDIRS(a3)
	move.w	d0,d2
	add.w	d1,d2
	; d2 = first sector containing files data (follows the
	; root directory sectors).
	move.w	d2,FS_SECS(a3)

	;
	; Find the library file name in the root directory.
	; d0 = FS_DIR(a3) - first root directory sector
	; d1 = FS_NDIRS(a3) - number of root directory sectors
	;

.newsec	movea.l	a1,a0
	bsr	read_sector
	tst.l	d0
	bmi	.ret
	; Walk through the 16 directory entries (of 32 bytes each)
	; available in the current root directory sector.
	moveq.l	#15,d2
.newent	movea.l	a0,a4
	lea	LIB_FNAME(a2),a5
	; Does this directory entry correspond to our library?
.namcmp	cmp.b	(a4)+,(a5)+
	beq.s	.namcmp
	cmpi.b	#$ff,-(a5)
	beq.s	.found
	; No, try next entry.
	lea	32(a0),a0
	dbf	d2,.newent
	; No more entry, try next sector.
	addq.w	#1,d0	
	subq.w	#1,d1
	bne.s	.newsec
	; No more sector in the root directory, library not found.

	; Error, return EFILNF (-33).
.err	moveq.l	#EFILNF,d0
	bra.s	.ret

	; We found the directory entry matching our library.
.found
	; Get the first logical cluster of the library file
	; and convert it to a sector number.
	lea	DIRENT_CLUSTER+2(a0),a0
	move.b	-(a0),d0
	lsl.w	#8,d0
	move.b	-(a0),d0
	; First logical cluster value is 2.
	subq.w	#2,d0
	; Multiply by the number of sectors per cluster.
	mulu.w	FS_SPC(a3),d0
	; And add the first sector containing data.
	add.w	FS_SECS(a3),d0
	; Save the first sector of the library file.
	move.w	d0,LIB_SEC(a2)

	; Get and save the library file size.
	addq.l	#DIRENT_FSIZE-DIRENT_CLUSTER+3,a0
	move.b	-(a0),LIB_SIZE+1(a2)
	move.b	-(a0),LIB_SIZE+2(a2)
	move.b	-(a0),LIB_SIZE+3(a2)

	; Set up the sector cache.
	move.l	a1,LIB_CACHEBUF(a2)
	st.b	LIB_CACHESEC(a2)

	;
	; Read the table of linked files (the directory) 
	; from the library.
	;

	lea	LIB_FTABLE(a2),a0
	movea.l	a2,a1
	; Table is at offset 0 of the library file.
	moveq.l	#0,d0
	; Table size is 160 bytes (80 entries of 2 bytes each).
	moveq.l	#80,d1
	add.w	d1,d1
	bsr.s	read_library
	tst.l	d0
	bmi.s	.ret

	; Check the library header.
	cmpi.l	#'REPS',(a0)
	bne.s	.err
	move.l	LIB_TAG(a2),d0
	sub.l	4(a0),d0
	bne.s	.err
	; r0 = 0

	; Check the integrity of the library directory:
	; the checksum on its content must be equal to 0.
.sum	add.l	(a0)+,d0
	subq.w	#4,d1
	bne.s	.sum
	tst.l	d0
	bne.s	.err
	; r0 = 0

.ret	movem.l	(a7)+,d1-d2/a0-a5
	rts

	;
	; read_library()
	;
	; Read a raw byte sequence from the library file
	; (containing linked game files) using direct sector
	; loading.
	;
	; read_library() does not support file fragmentation,
	; therefore the library file shall sit on contiguous
	; sectors on the floppy disk.
	;
	; The library file must have been previously opened by
	; the open_library() routine above.
	;
	; In:
	;   d0: offset from the beginning of the library file
	;   d1: number of bytes to be read
	;   a0: destination buffer
	;   a1: library info
	;
	; Out:
	;   d0: number of bytes read if success,
	;       EFDC (-1) otherwise
	;
read_library
	movem.l	d1-d4/a0-a3,-(a7)

	;
	; The library file occupies contiguous clusters/sectors
	; on the floppy disk.
	; Convert the offset from the beginning of the library file
	; (provided as parameter in d0) to a logical/absolute
	; sector number and possibly an offset within this sector.
	; The requested data will be read from that sector and
	; the following ones on the floppy disk.
	;

	; d4 = length of a sector = $200 bytes.
	moveq.l	#$2,d4
	lsl.l	#8,d4

	; d0 = offset expressed in sectors.
	divu.w	d4,d0

	; d0 = logical/absolute sector number, corresponding
	; to the beginning of the requested data.
	move.l	d0,d2
	ext.l	d0
	add.w	LIB_SEC(a1),d0

	; d2 = offset in bytes within that sector.
	clr.w	d2
	swap	d2

	;
	; Data are read sector by sector in this loop.
	;
.sec_loop
	; d3 = $200
	move.l	d4,d3
	; d3 = size of data to be read from offset d2
	; in the current sector.
	sub.w	d2,d3
	; Compare with total remaining size.
	cmp.l	d3,d1
	bhi.s	.size_ok
	; And truncate that size if needed.
	move.l	d1,d3
	beq.s	.done
.size_ok
	;
	; d0 = current logical/absolute sector number
	; d1 = total remaining size
	; d2 = offset of the data to be read in current sector
	; d3 = number of bytes to be read in current sector
	; d4 = $200
	; a0 = destination buffer address
	; a1 = library info
	;
	; Check whether all or only part of the sector data should
	; be read.
	cmp.w	d4,d3
	bne.s	.sec_partial
.sec_full
	; Load a complete sector into the destination buffer.
	bsr.s	read_sector
	tst.l	d0
	bmi.s	.ret
	; Increment destination buffer address for next data.
	adda.l	d4,a0
	bra.s	.sec_cont
.sec_partial
	; Only part of the sector must be copied to the destination
	; buffer. Therefore load that sector into a cache buffer
	; and copy appropriate data.
	movea.l	a0,a3
	; Use a cache buffer.
	movea.l	LIB_CACHEBUF(a1),a0
	; Check if the cache already contains the sector.
	cmp.w	LIB_CACHESEC(a1),d0 
	beq.s	.tmp_sec_done
	; If not, load it.
	bsr.s	read_sector
	; Remember which sector has been loaded in the cache
	; buffer (in case of error, it is reset to $ffxx).
	move.w	d0,LIB_CACHESEC(a1)
	tst.l	d0
	bmi.s	.ret
.tmp_sec_done
	; Copy d3 bytes, from offset d2 in the current
	; sector, to the destination buffer.
	lea	0(a0,d2.w),a2
	movea.l	a3,a0
	move.w	d3,d2

	; Perform the copy.
.cp	move.b	(a2)+,(a0)+
	subq.w	#1,d2
	bne.s	.cp
	; As a side effect, sector offset is reset (d2 = 0).
.sec_cont
	; If more data need to be read, continue with
	; the next sector.
	addq.w	#1,d0
	sub.l	d3,d1
	bne.s	.sec_loop

 	; In case of success, return the size of the bytes read.
.done	move.l	(a7),d0

.ret	movem.l	(a7)+,d1-d4/a0-a3
	rts

	;
	; read_sector()
	;
	; Read one sector from the floppy disk (drive A only).
	;
	; In:
	;   d0: logical/absolute sector number
	;       (0 to total number of sectors - 1)
	;   a0: destination buffer address
	;
	; Out:
	;   d0: unchanged if success, EFDC (-1) if error
	;
read_sector
	movem.l	d0-d7/a1-a2,-(a7)

	lea	dma_info(pc),a1   ; a1 = DMA (floppy) info
	lea	$ffff8600.w,a2    ; a2 = DMA registers bank
	moveq.l	#2,d5             ; d5 = 3 retries (-1 for dbf)

	move.l	d0,d2             ; d2 = logical sector nr
	divu.w	DMA_SPT(a1),d2
	moveq.l	#0,d1
	move.w	d2,d1             ; d1 = logical track nr
	move.w	d1,d6             ; d6.w = logical track nr
	swap	d2
	addq.w	#1,d2             ; d2.w = sector nr
	divu.w	DMA_NHEADS(a1),d1 ; d1.w = track nr
	move.l	d1,d0
	swap	d0                ; d0.w = side nr
	move.w	DMA_CURTRK(a1),d7 ; d7.w = current logical track nr

	;
	; d0.w = side (0/1)
	; d1.w = track (e.g. 0-81)
	; d2.w = sector (e.g. 1-11)
	; d3   = scratch / FDC reg value / FDC status
	; d4   = scratch / delay loop count
	; d5   = retries count
	; d6.w = target logical track
	; d7.w = current logical track
	; a0   = destination buffer address
	; a1   = DMA (floppy) info
	; a2   = DMA registers bank ($ffff8600)
	;

	;
	; Select drive A and proper side.
	;
	ori.b	#2,d0             ; Add drive A selection
	bsr	fdc_select

	;
	; If the motor is off, force a 'seek with verify' command.
	;
	bsr	read_fdc_status
	; Verify the 'Motor On/Off' bit (status register, bit S7).
	btst	#7,d3
	bne.s	.seek_cmd

.force_seek
	; Set current logical track to unknown.
	; This will force a 'seek' command with the 'verify' flag.
	moveq.l	#-1,d7
	move.w	d7,DMA_CURTRK(a1)

	;
	; Seek to the desired track.
	;

.seek_cmd
	; Seek to the desired track only if needed.
	cmp.w	d6,d7
	beq.s	.sector_cmd
	; Select FDC data register of read mode.
	move.w	#$86,6(a2)
	; Load the track number.
	move.w	d1,d3
	bsr	write_fdc_reg
	; Select FDC control register of read mode.
	move.w	#$80,6(a2)
	; Issue a seek command:
	; Enable spin-up sequence (motor on), DD or HD stepping rate,
	; 'verify' is enabled only if current logical track is unknown.
	moveq.l	#$10,d3           ; seek cmd
	or.w	DMA_SEEKRATE(a1),d3
	tst.w	d7
	bpl.s	.no_vf
	ori.b	#$4,d3            ; verify flag
.no_vf	bsr	write_fdc_reg
	; Wait for the end of the DMA command.
	bsr	wait_dma_irq
	tst.l	d3
	bne.s	.restore_cmd
	; Read the FDC status.
	bsr	read_fdc_status
	; Verify the 'Seek Error' bit (status register, bit S4).
	andi.b	#$10,d3
	bne.s	.restore_cmd
	; Save current logical track.
	move.w	d6,DMA_CURTRK(a1)

	;
	; Read the desired sector.
	;
.sector_cmd
	; Select FDC sector register of read mode.
	move.w	#$84,6(a2)
	; Load the sector number.
	move.w	d2,d3
	bsr.s	write_fdc_reg
	; Load the DMA address (low, mid, high order).
	move.l	a0,d3
	move.b	d3,13(a2)         ; Low
	lsr.l	#8,d3
	move.b	d3,11(a2)         ; Mid
	lsr.l	#8,d3
	move.b	d3,9(a2)          ; High
	; Toggling the read/write transfer direction bit (bit 8) of
	; the mode register clears the DMA controller status register,
	; flushes the two internal FIFOs, and clears the sector count
	; register.
	move.w	#$190,6(a2)       ; DMA write mode
	bsr.s	short_delay
	move.w	#$90,6(a2)        ; DMA read mode
	bsr.s	short_delay
	; Update the DMA sector count register: 1 sector is read.
	move.w	#1,4(a2)
	bsr.s	short_delay
	; Select FDC control register of read mode.
	move.w	#$80,6(a2)
	; Issue a read sector command:
	; Single sector, enable spin-up sequence (motor on),
	; no delay.
	move.w	#$80,d3
	bsr.s	write_fdc_reg	
	; Wait for the end of the DMA command.
	bsr.s	wait_dma_irq
	tst.l	d3
	bne.s	.restore_cmd
	; Read the FDC status.
	bsr.s	read_fdc_status
	; Verify 'Lost Data', 'CRC error' and 'Record Not Found' bits
	; (status register, bits S2, S3, S4).
	andi.b	#$1c,d3
	bne.s	.restore_cmd

	; Read succeeded.
.ret	movem.l	(a7)+,d0-d7/a1-a2
	rts

	;
	; In case of error, seek to track 0 and retry.
	;
.restore_cmd
	; Select FDC control register of read mode.
	move.w	#$80,6(a2)
	; Issue a restore (seek to track 0) command:
	; Enable spin-up sequence (motor on), verify,
	; DD or HD stepping rate.
	moveq.l	#$4,d3            ; Restore cmd ($0) + verify flag
	or.w	DMA_SEEKRATE(a1),d3
	bsr.s	write_fdc_reg
	; Wait for the end of the DMA command.
	bsr.s	wait_dma_irq
	tst.l	d3
	bne.s	.err
	; Number of retries is limited.
	dbf	d5,.force_seek

	;
	; Read failed, return EFDC (-1) in d0.
	;
.err	moveq.l	#EFDC,d0
	move.l	d0,(a7)
	bra.s	.ret

	;
	; write_fdc_reg()
	;
	; Write a value to the selected FDC register while
	; taking timings constraints into account.
	;
	; Timings information is provided in the WD177x datasheet:
	; https://info-coach.fr/atari/documents/_datasheets/WD177x-Prog.txt
	; In particular, it is stated that after the CPU writes to
	; any register, it cannot read that register until 16us in MFM
	; or 32us in FM have elapsed.
	; Also after writing to the command register, the status bits
	; cannot be read during 32us.
	;
	; The following routine inserts a 50us delay before writing to
	; a freshly selected FDC register.
	; Note that the Linux floppy driver uses a value of 25us while
	; EmuTOS uses 50us.
	; A small delay of 5us is also added after writing to the FDC
	; register (by falling through to short_delay). Linux uses a
	; similar delay based on MFP access.
	;
	; In:
	;   d3: value to be written to the selected FDC register
	;   a1: DMA (floppy) info
	;   a2: $ffff8600
	;
	; Scratch: d4
	; 
write_fdc_reg
	; Wait to cope with device timings.
	bsr.s	fdc_delay
	; Write the value to the selected FDC register.
	move.w	d3,4(a2)
	; Wait to cope with device timings.
	;
	; fall through.

	;
	; short_delay()
	;
	; Insert a short delay of 5us in two cases:
	; - When toggling DMA data direction (same as in EmuTOS and
	;   Atari TOS 3 & 4).
	; - After writing to a selected FDC register.
	;
	; The number of loop iterations is calibrated
	; by the calibrate_delay() routine.
	;
	; In:
	;   a1: DMA (floppy) info
	;
	; Scratch: d4
	;
short_delay
	move.l	DMA_SHORT_DELAY(a1),d4
	bra.s	fdc_delay_wait

	;
	; fdc_delay()
	;
	; Insert a 50us busy-delay after a FDC register has been
	; selected through the DMA mode register (before accessing
	; the selected register).
	;
	; The number of loop iterations is calibrated
	; by the calibrate_delay() routine.
	;
	; In:
	;   a1: DMA (floppy) info
	;
	; Scratch: d4
	;
fdc_delay
	move.l	DMA_FDC_DELAY(a1),d4
fdc_delay_wait
	subq.l	#1,d4
	bne.s	fdc_delay_wait
	rts

	;
	; read_fdc_status()
	;
	; Return the FDC status.
	;
	; In:
	;   a1: DMA (floppy) info
	;   a2: $ffff8600
	;
	; Out:
	;   d3: FDC status
	;
	; Scratch: d4
	;
read_fdc_status
	; Select FDC control register of read mode.
	move.w	#$80,6(a2)
	bsr.s	fdc_delay
	; Read the FDC status.
	move.w	4(a2),d3
	rts

	;
	; wait_dma_irq()
	;
	; Wait for the end of the current DMA operation.
	;
	; If the DMA operation times out, a force interrupt
	; command is issued.
	; The timeout mechanism is based on the calibrated
	; FDC delay loop above.
	;
	; In:
	;   a1: DMA (floppy) info
	;   a2: $ffff8600
	;
	; Out:
	;   d3: 0 if success, != 0 if error
	;
	; Scratch: d4
	;
wait_dma_irq
	; Timeout = $10000*50us > 3.2s.
	moveq.l	#-1,d3            ; dbf will loop '$ffff + 1'

	; Check FDC interrupt bit in GPIO General Purpose register.
.poll	btst	#5,$fffffa01.w
	beq.s	.done
	bsr.s	fdc_delay
	dbf	d3,.poll

	; Timeout: issue a force interrupt command.
	move.w	#$d0,d3
	bsr.s	write_fdc_reg

	; Wait 8*50us > 400us.
	moveq.l	#7,d3
.wait	bsr.s	fdc_delay
	dbf	d3,.wait

	; Error: d3 != 0
	rts

	; Success: d3 = 0
.done	moveq.l	#0,d3
	rts

	;
	; fdc_select()
	;
	; FDC drive & side selection.
	;
	; In:
	;   d0: Bit0: 0 selects side 0, 1 selects side 1
	;       Bit1: 1 selects drive A, 0 deselects it
	;       Bit2: 1 selects drive B, 0 deselects it
	;   a2: $ffff8600
	;
	; Scratch: d3
	;
fdc_select
	; Save interrupts.
	move.w	sr,-(a7)
	; Disable interrupts.
	ori.w	#$700,sr
	; Select PSG register 14 (Port A).
	move.b	#14,$200(a2)
	; Read PSG register 14.
	move.b	$200(a2),d3
	; Clear drive A/B & side selection bits (0-2).
	andi.b	#$f8,d3
	; Bits of the floppy interface in PSG reg 14 are inverted:
	; Bit0: 1 selects side 0, 0 selects side 1
	; Bit1: 0 selects drive A, 1 deselects it
	; Bit2: 0 selects drive B, 1 deselects it
	or.b	d0,d3
	eori.b	#7,d3
	; Write PSG register 14.
	move.b	d3,$202(a2)
	; Restore interrupts.
	move.w	(a7)+,sr
	rts

	;
	; fdc_deselect_noblock()
	;
	; Deselect floppy disk drive A if the motor is shut down.
	;
	; This routine does not block, meaning that if the motor
	; is still on, the drive A is not deselected.
	;
	; Out:
	;   d0: 0 if drive A has been deselected, -1 otherwise
	;
fdc_deselect_noblock
	movem.l	d3-d4/a1-a2,-(a7)
	lea	dma_info(pc),a1
	lea	$ffff8600.w,a2
	bsr.s	read_fdc_status
	moveq.l	#-1,d0
	; Verify Motor On/Off (status register, bit S7).
	btst	#7,d3
	bne.s	.ret
	moveq.l	#0,d0
	bsr.s	fdc_select
.ret	movem.l	(a7)+,d3-d4/a1-a2
	rts

	;
	; DMA/floppy metadata used by the read_sector() routine.
	; [dma_info - dma_info_end]
	;
dma_info
	; Sectors per track.
di_spt
	dc.w	1
	; Number of sides.
di_nheads
	dc.w	1
	; Total number of sectors.
di_nsecs
	dc.w	1
	; Current logical track (seek command).
di_curtrk
	dc.w	$ffff
	; Number of loop iterations of the 50us delay routine.
di_fdc_delay
	dc.l	19
	; Number of loop iterations of the 5us delay routine.
di_short_delay
	dc.l	1
	; FDC seek rate (3 ms is the default for DD mode).
di_seekrate
	dc.w	3
dma_info_end

	;
	; Filesystem (FAT12) metadata.
	; [fs_info - fs_info_end]
	;
fs_info
	; Sectors per cluster (usually 2).
fsi_spc
	ds.w	1
	; First sector of the root directory.
fsi_dir
	ds.w	1
	; Number of sectors of the root directory.
fsi_ndirs
	ds.w	1
	; First sector of files data.
fsi_secs
	ds.w	1
fs_info_end

	;
	; Library file #1 (disk#1) metadata.
	; [lib_info - lib_info_end]
	;
lib_info1
lib_info
	; Tag/magic value stored at the beginning of the
	; library file.
li_tag
	; dc.l	'SSS1' ; => Same as the base file name below.
	; Library file name.
li_fname
	dc.b	"SSS1    LNK",$ff
	even
	; First logical/absolute sector of the library file.
li_sec
	ds.w	1
	; Size in bytes of the library file.
li_size
	ds.l	1
	; Cache buffer used for sectors loading.
li_cachebuf
	ds.l	1
	; Sector currently loaded in the cache.
li_cachesec
	ds.w	1
	; Library file offset from which it has been loaded
	; into RAM.
li_ram_off
	dc.l	-1
	; Address in RAM where the library file has been loaded.
li_ram_addr
	ds.l	1
	; Linked game file table (directory).
li_ftable
	ds.w	80
lib_info_end

	;
	; Library file #2 (disk#2) metadata.
	;
lib_info2
	; dc.l	'SSS2' ; => Same as the base file name below.
	dc.b	"SSS2    LNK",$ff
	even
	ds.b	lib_info_end-li_sec
	even

	; DMA/FDC metadata offsets.
DMA_SPT         =	(di_spt-dma_info)
DMA_NHEADS      =	(di_nheads-dma_info)
DMA_NSECS       =	(di_nsecs-dma_info)
DMA_CURTRK      =	(di_curtrk-dma_info)
DMA_FDC_DELAY   =	(di_fdc_delay-dma_info)
DMA_SHORT_DELAY =	(di_short_delay-dma_info)
DMA_SEEKRATE    =	(di_seekrate-dma_info)

	; Filesystem metadata offsets.
FS_SPC          =	(fsi_spc-fs_info)
FS_DIR          =	(fsi_dir-fs_info)
FS_NDIRS        =	(fsi_ndirs-fs_info)
FS_SECS         =	(fsi_secs-fs_info)

	; Library file metadata offsets.
LIB_TAG         =	(li_tag-lib_info)
LIB_FNAME       =	(li_fname-lib_info)
LIB_SEC         =	(li_sec-lib_info)
LIB_SIZE        =	(li_size-lib_info)
LIB_CACHEBUF    =	(li_cachebuf-lib_info)
LIB_CACHESEC    =	(li_cachesec-lib_info)
LIB_RAM_OFF     =	(li_ram_off-lib_info)
LIB_RAM_ADDR    =	(li_ram_addr-lib_info)
LIB_FTABLE      =	(li_ftable-lib_info)

	; Bios Parameter Block (boot sector) offsets.
BPB_OEM         =	$02
BPB_SERIAL      =	$08
BPB_BPS         =	$0b
BPB_SPC         =	$0d
BPB_RES         =	$0e
BPB_NFATS       =	$10
BPB_NDIRS       =	$11
BPB_NSECS       =	$13
BPB_MEDIA       =	$15
BPB_SPF         =	$16
BPB_SPT         =	$18
BPB_NHEADS      =	$1a
BPB_NHID        =	$1c

	; FAT12 directory entry offsets.
DIRENT_CLUSTER  =	26
DIRENT_FSIZE    =	28

***************************************************************************
*
* 11. Game files loading support
*
* This section provides services for loading game files from a filesystem
* and from a ramdisk.
*
* The original game does not use the TOS filesystem: game programs and data
* are written directly to two floppy disks as contiguous sectors, without
* standard file organization.
*
* The game uses a table describing where programs and data are located on
* the floppy disks. In this table, each "block of data" is described by
* a start offset and an end offset from the beginning of the floppy disk.
*
* "Filing" a game means making it executable from a filesystem although
* it was not originally intended for that purpose.
* To this end, every "block of data" described in the table is extracted
* from the floppy disks (by reading raw sectors directly) and saved as
* a separate file.
* In addition, the original loading routine of the game is replaced
* by a new routine that can load data from the filesystem.
*
* In total 96 files have been extracted from the floppy disks of this game,
* 38 from disk#1 and 58 from disk#2.
*
* These files were originally packed with Pack-Ice from Superior. They
* have been unpacked and repacked with UPX (NRV2B compression method).
* The compression ratio of UPX is better and the decompression is much
* faster.
*
* Once a game is filed, it is often interesting to gather all extracted
* files together in a single linkfile (also called library file) so that
* it can be loaded at once and used as a ramdisk on machines with enough
* RAM.
*
* For this game, extracted files have been linked together into two library
* files, one library file for each floppy disk.
* However files have been rearranged a bit to maximize the size of disk#2
* library and minimize the size of disk#1 library (in other words, some
* files have been moved from disk#1 to disk#2).
* Minimizing the size of the disk#1 library allows it to be loaded as
* a ramdisk on machines with only 1MB of RAM (into the upper 512KB).
*
* Files extracted from the game disks are listed hereafter.
* Every file is identified by the index in the original table of the
* game, that is used to extract its contents from the floppy disks.
* The complete caption is given at the end of the list.
*
* Disk#1:
*
* File     Remark   Type    Description
* ------   ------   ------  -----------
* File00            [Prog]  Insert disk#2
* File02            [Prog]  Loading animation
* File03            [Prog]  Main program
* File04            [Prog]  Level management (same as File54)
* File05            [Prog]  Flags selection
* File06            [Prog]  Intro screen (hero with rasters)
* File07            [Prog]  Presentation screen (text with music)
* File08            [Data]  Levels
* File09            [Prog]  Level presentation screen (magician)
* File0A            [Prog]  Level map screen
* File0B            [Data]  Levels
* File0C            [Data]  Levels
* File0D  [File8A]  [Data]  Route to the boss
* File0E  [File8B]  [Data]  Route to the boss
* File0F  [File8C]  [Data]  Route to the boss
* File10  [File8D]  [Data]  Route to the boss
* File11  [File8E]  [Data]  Route to the boss
* File12  [File8F]  [Data]  Route to the boss (level1)
* File13  [File90]  [Data]  Route to the boss (level2)
* File14  [File91]  [Data]  Route to the boss (level3)
* File15  [File92]  [Data]  Route to the boss (level4)
* File16  [File93]  [Data]  Route to the boss (level5)
* File17  [File94]  [Data]  Route to the boss (level6)
* File18  [File95]  [Prog]  Boss support
* File19            [Prog]  Level1 boss
* File1A            [Data]  Level1 boss
* File1B            [Prog]  Level2 boss
* File1C            [Data]  Level2 boss
* File1D            [Prog]  Level3 boss
* File1E            [Data]  Level3 boss
* File1F            [Prog]  Level4 boss
* File20            [Data]  Level4 boss
* File21            [Prog]  Level5 boss
* File22            [Data]  Level5 boss
* File23  [File96]  [Prog]  Level6 boss
* File24  [File97]  [Data]  Level6 boss
* File25            [Prog]  Game over screen (magician)
* File26            [Prog]  Hall of fame (top five)
*
* Disk#2:
*
* File     Remark   Type    Description
* ------   ------   ------  -----------
* File50            [Prog]  Insert disk#1
* File51            [Data]  Levels
* File52            [Prog]  Information shop
* File53            [Prog]  Weapon shop
* File54            [Prog]  Level management (same as File04)
* File55            [Prog]  Brick game
* File56            [Prog]  Levels secret passage
* File57            [Data]  Levels secret passage
* File58            [Data]  Levels secret passage
* File59  [x]       [Data]  Levels secret passage   (504 bytes at +$432a)
* File5A            [Data]  Level1 secret passage
* File5B            [Data]  Level2 secret passage
* File5C            [Data]  Level3 secret passage
* File5D            [Data]  Level4 secret passage
* File5E            [Data]  Level5 secret passage
* File5F            [Data]  Level6 secret passage	
* File60            [Prog]  Levels bonus room
* File61            [Data]  Levels bonus room
* File62            [Data]  Levels bonus room
* File63            [Data]  Levels bonus room
* File64            [Data]  Levels bonus room
* File65            [Data]  Level1 bonus room
* File66            [Data]  Level5 bonus room
* File67            [Data]  Level5 bonus room
* File68            [Data]  Level3 bonus room
* File69            [Data]  Level2 bonus room
* File6A            [Data]  Level1 bonus room
* File6B            [Data]  Level6 bonus room
* File6C            [Data]  Level4 bonus room
* File6D            [Data]  Level3 bonus room
* File6E            [Data]  Level4 bonus room
* File6F            [Data]  Level2 bonus room
* File70            [Data]  Level6 bonus room
* File71            [Data]  Level1 - The forest
* File72            [Data]  Level1
* File73            [Data]  Level1
* File74            [Data]  Level1
* File75            [Data]  Level2 - The sea
* File76            [Data]  Level2
* File77            [Data]  Level2
* File78            [Data]  Level2
* File79            [Data]  Level3 - The cavern
* File7A            [Data]  Level3
* File7B            [Data]  Level3
* File7C            [Data]  Level3
* File7D            [Data]  Level4 - The city
* File7E            [Data]  Level4
* File7F            [Data]  Level4
* File80            [Data]  Level4
* File81            [Data]  Level5 - Near the castle
* File82            [Data]  Level5
* File83  [x]       [Data]  Level5
* File84  [x]       [Data]  Level5
* File85  [x]       [Data]  Level6 - In the castle
* File86  [x]       [Data]  Level6
* File87  [x]       [Data]  Level6
* File88  [x]       [Data]  Level6
* File89  [x]       [Prog]  Game finale
*
* Caption:
*
* Remark: [Filexx] ... File has been moved to disk#2 library as 'Filexx'
*         [x] ........ File was corrupted in Terminator Kid's version
* Type:   [Data] ..... File contains data
*         [Prog] ..... File contains ASM68k code
*
* The closest version to the original copy of the game is the crack of
* Terminator Kid. But files $59 and $83 to $89 are corrupt in all dumps
* available on the Web: the game hangs when loading a secret passage,
* levels 5 and 6, or the game finale.
* Fortunately, a developer version of the game containing all the files
* in perfect condition was found, which allowed to restore the crack of
* Terminator Kid.
* The restored crack was thus used as a starting point for this 100%
* working release.
* See https://github.com/orionfuzion/newcracks/blob/master/SonShuSi/IPL.md
* for more information on the different problems that exist in cracked
* versions available on the Internet.
*
* In order to load files from the two libraries stored on the filesystem,
* the game needs to be adapted.
* To this end, the game's original DMA/FDC loading routines are replaced
* by the new 'fileops' routines, which consist of:
* - Low-level routines provided in section "10. FDC/DMA support".
*   They read raw byte sequences from the libraries stored on floppy disks
*   using DMA/FDC programming and FAT12 support.
*   See read_library() and open_library().
* - High-level routines provided in this section.
*   They extract game files from the libraries stored either on floppy
*   disks (using the low-level routines) or in ramdisk.
*   See read_file().
*
* Note that accessing the libraries from HDD requires them to be pre-loaded
* into memory as ramdisks. Direct access from HDD during the game is not
* supported. See prepare_drv_hd() and prepare_drv_a().
*
* Public routines:
* - read_file()
*
***************************************************************************

	;
	; read_file_retry()
	;
	; This label is invoked by the read_file() routine when the
	; checksum calculated on the file just loaded is incorrect.
	; read_file_retry() flushes the cached FDC/DMA data (the sector
	; cache and current logical track) and retries the read_file()
	; operation.
	;
read_file_retry
	lea	dma_info+DMA_CURTRK(pc),a0
	st.b	(a0)            ; Invalidate the cur logical track
	st.b	$6c.w           ; Invalidate the sector cache
read_file_reload_regs
	movem.l	(a7)+,d0-d3/a0-a2/a5
	; Fall-through

	;
	; read_file()
	;
	; Load a game file which is linked in a library with
	; other game files.
	; The library can be stored either on a floppy disk or
	; in memory (ramdisk).
	;
	; Game files are gathered in two libraries.
	; If the library containing the requested file is not
	; in RAM or on the floppy disk in use, then the user
	; is invited to insert the other floppy disk.
	;
	; In:
	;   d0.w: original game file number (0-75)
	;   a1:   destination buffer
	;
	; Out:
	;   d0: number of bytes read if success,
	;   does not return in case of error
	;
read_file
	movem.l	d0-d3/a0-a2/a5,-(a7)

	; a0 = destination buffer
	; a2 = files info
	movea.l	a1,a0
	lea	files_info(pc),a2

	; Mark the requested file as the latest loaded file.
	; This information is used when depacking the file,
	; in order to apply patches that affect only that file.
	; See apply_fixes() for detailed comments on that
	; on-the-fly patching mechanism.
	move.w	d0,FILES_FILE_NR(a2)

	; Convert the original game file number to the actual file
	; index in the libraries.
	; In the original game, each file is associated to a
	; given number: 0 to 38 for disk#1 files, 80 to 137
	; for disk#2 files.
	; In this crack, files have been rearranged to maximize
	; the size of library #2 (disk#2) and minimize the size
	; of library #1 (disk#1). In other words, some files have
	; been moved from disk#1 to disk#2.
	; Therefore game file indexes in the libraries are
	; slightly different from the original game file numbers.

	; a1 = game file numbers translation array.
	lea	FILES_IDX_CONV(a2),a1
.conv
	; If the file number is not found in the translation array
	; then the file index is the same as in the game.
	cmpi.b	#$ff,(a1)
	beq.s	.conv_done
	cmp.b	(a1),d0
	addq.l	#2,a1
	bne.s	.conv
	; File number found in the translation array,
	; file index is therefore updated.
	move.b	-(a1),d0
.conv_done

	; 0 = Disk#1.
	moveq.l	#0,d2
	; Library #1 (disk#1).
	lea	lib_info1(pc),a1
	; 80 = max number of files per library/disk.
	moveq.l	#$50,d3

	; Index < 80 means the file is in library #1 (disk#1),
	; Index >= 80 means the file is in library #2 (disk#2).
	cmp.b	d3,d0
	bmi.s	.nr_ok

	; 1 = Disk#2.
	moveq.l	#1,d2
	; Library #2 (disk#2).
	lea	lib_info2-lib_info1(a1),a1
	; Adjust the file index.
	sub.b	d3,d0
.nr_ok

	; d0.w = file index in the library
	; d2   = library/disk number
	; d3   = $50
	; a0   = destination buffer
	; a1   = library info
	; a2   = files info

	; Get the offsets, from the beginning of the library file,
	; of the requested file and the file that follows it.
	; Offsets are aligned on 16-bytes boundaries and therefore
	; are shifted to fit into 16-bits words.
	move.b	d0,d3
	add.w	d3,d3
	moveq.l	#0,d1
	; Offset of next file.
	move.w	LIB_FTABLE+10(a1,d3.w),d1
	; Offset of requested file.
	move.w	LIB_FTABLE+8(a1,d3.w),d3
	; An offset of zero means we try to access library #2 (on
	; the second disk) but it has not been opened yet, ie disks
	; 1 & 2 have not been swapped yet. Let's do it.
	beq.s	read_swap_disk

	; Shift the offsets.
	lsl.l	#4,d1
	lsl.l	#4,d3
	; Subtract the 2 consecutive offsets to get the size
	; of the requested file.
	sub.l	d3,d1
	ble	read_file_error

	; d0.w = file index in the library
	; d1   = size of the requested linked file (> 0)
	; d2   = library/disk number
	; d3   = offset, from the beginning of the library file,
	;        of the requested linked file.
	; a0   = destination buffer
	; a1   = library info
	; a2   = files info

	; Check if the file is already in RAM (that is if the
	; corresponding library has been loaded as a ramdisk).
	cmp.l	LIB_RAM_OFF(a1),d3
	bhs.s	read_file_ram

	; Otherwise, the library is on a floppy disk in drive A.
	; Check if drive A contains the expected library, or if
	; disks 1 & 2 should be swapped.
	cmp.b	FILES_DISK_NR+1(a2),d2
	bne.s	read_swap_disk

	; The sector loading cache is located at the end
	; of the first 512KB. It may be corrupted by the game.
	; If it is the case, the game informs us by writing
	; -1 into $6c. Take this information into account.
	tst.l	$6c.w
	beq.s	.valid
	st.b	LIB_CACHESEC(a1)
	clr.l	$6c.w
.valid
	; Finally, read the file from the library.
	move.l	d3,d0
	bsr	read_library
	tst.l	d0
	bmi	read_file_error

	;
	; Verify the checksum of the file that has just been loaded.
	; Checksums have been calculated for all game files. They are
	; stored after each game file in the two library (link) files.
	;
	lsr.l	#4,d1           ; d1 = file size / 16
	subq.w	#1,d1
	moveq.l	#0,d2
.csum	rept	4
	add.l	(a0)+,d2        ; Calculate the checksum
	endr
	dbf	d1,.csum
	tst.l	d2              ; If the checksum is not 0
	bne	read_file_retry ;   retry the read operation

read_file_ret
	addq.l	#4,a7
	movem.l	(a7)+,d1-d3/a0-a2/a5
	rts

	;
	; read_file_ram()
	;
	; Load a game file which is linked in a library located
	; in RAM (ramdisk mode).
	;
	; This routine is called by read_file().
	;
	; In:
	;   d1: size of the requested linked file (> 0)
	;   d3: offset, from the beginning of the library file,
	;       of the requested linked file
	;   a0: destination buffer
	;   a1: library info
	;
	; Out:
	;   d0: number of bytes read
	;
	; Scratch: d1,d3,a0,a2
	;
read_file_ram
	; a2 = base address of the library in RAM.
	movea.l	LIB_RAM_ADDR(a1),a2
	; d3 = offset, from the base address above,
	; of the requested linked file.
	sub.l	LIB_RAM_OFF(a1),d3
	; a2 = source address of the linked file in RAM.
	adda.l	d3,a2
	; d0 = return value = size of linked game file.
	move.l	d1,d0

	; Size of files is aligned on 16 bytes, therefore
	; copy file data by chunks of 16 bytes.
	lsr.l	#4,d1
	subq.w	#1,d1
.cp	rept	4
	move.l	(a2)+,(a0)+
	endr
	dbf	d1,.cp

	bra.s	read_file_ret

	;
	; read_swap_disk()
	;
	; Try to open the requested library file on the floppy disk
	; that is currently in drive A, and if it fails, ask the
	; user to insert the other floppy disk.
	;
	; This routine is called by read_file().
	;
	; In:
	;   d2: number of the requested library/disk
	;   a1: info of the requested library
	;   a2: files info
	;
	; Out:
	;   the appropriate floppy disk is inserted in drive A and
	;   the requested library file has been opened and is ready
	;   to be used
	;
read_swap_disk
	; Save in a5 the address where the program that displays a
	; picture asking to insert the other floppy disk is executed.
	; This is the same address used in the original game code.
	lea	SWAP_DISK_DEST_ADDR,a5

	; Load and execute this program.
	; Display the picture but keep all colors black.
	move.w	FILES_DISK_NR(a2),d0
	bsr.s	swap_disk_display

	movea.l	a1,a0
	movea.l	lib_info1+LIB_CACHEBUF(pc),a1

	; Open the requested library file.
.again	bsr	open_library
	; If the open operation failed, then the expected disk
	; is not in drive A.
	tst.l	d0
	bpl.s	.ret
	; Show the picture asking to swap the disks and wait for the
	; user to press the space key or the fire button.
	bsr.s	swap_disk_wait
	; Try again.
	bra.s	.again

	; Save the number of the newly inserted library/disk,
	; restore registers and restart the file read operation.
.ret	move.b	d2,FILES_DISK_NR+1(a2)
	bra	read_file_reload_regs

	;
	; swap_disk_display()
	;
	; Load and execute the game program that displays a picture
	; asking to insert the required floppy disk in drive A.
	;
	; This code does almost the same as the original game
	; code, except that picture colors are not displayed
	; immediately. They will be displayed only if needed,
	; that is only if the disks must be swapped (if the
	; expected library file cannot be found on the current
	; floppy disk).
	;
	; This routine is called by read_swap_disk().
	;
	; In:
	;   d0: current library/disk number (0 or 1 for resp.
	;       disk#1 or disk#2)
	;   a5: address where the program that displays the disk
	;       swap picture is executed
	;
swap_disk_display
	movem.l	d0-a6,-(a7)

	; First file (index 0 or 80) of the current library is
	; a game subprogram that displays a picture asking
	; to insert the other floppy disk.
	; Read this file at the same memory address as in the
	; original disk swap code.
	mulu	#$50,d0         ; 0 or 80
	lea	FILE_LOAD_ADDR,a1
	bsr	read_file

	; Unpack that subprogram at the same address as in the
	; original code.
	movea.l	a1,a0
	movea.l	a5,a1
	jsr	DEPACK_ADDR.w

	; Load the screen address in d0 and call the subprogram.
	move.l	$858.w,d0
	; Prevent the display of colors.
	eori.w	#$4e75^$4cfa,$72(a5)
	jsr	(a5)
	; Allow colors to be displayed again.
	eori.w	#$4e75^$4cfa,$72(a5)

	movem.l	(a7)+,d0-a6
	rts

	;
	; swap_disk_wait()
	;
	; Show the disk swap picture and wait for the joystick
	; button or the space key to be pressed, thus allowing
	; the user to insert the required disk into drive A.
	;
	; This routine is called by read_swap_disk().
	;
	; In:
	;   a5: address where the program that displays the disk
	;       swap picture is executed
	;
swap_disk_wait
	movem.l	d0-a6,-(a7)

	; Call the subprogram to display picture colors.
	jsr	$72(a5)

	; Start IKBD handling.
	movea.l	KEYB_FIX_RESID_PTR.w,a0
	jsr	KEYB_VBL_START_OFF(a0)

	; Deselect drive A as soon as the motor is off.
.wait	bsr	fdc_deselect_noblock

	; Loop until fire button/key is pressed.
	tst.b	KEYB_DATA_EXIT.w
	beq.s	.wait

	; Stop IKBD handling.
	jsr	KEYB_VBL_STOP_OFF(a0)

	; Call the subprogram to reset colors to black.
	jsr	$38(a5)

	movem.l	(a7)+,d0-a6
	rts

	;
	; read_file_error()
	;
	; Fatal DMA/FDC loading error.
	; Set the background color to red and halt the CPU.
	;
read_file_error
	move.w	#$2700,sr
	move.w	#$700,$ffff8240.w
.dead	bra.s	.dead

	;
	; Game files metadata.
	; [files_info - files_info_end]
	;
files_info
	; Game file number -> linked game file index.
fi_idx_conv
	dc.b	$0d,$8a,$0e,$8b,$0f,$8c,$10,$8d,$11,$8e
	dc.b	$12,$8f,$13,$90,$14,$91,$15,$92,$16,$93
	dc.b	$17,$94,$18,$95,$23,$96,$24,$97,$ff,$ff
	even
	; Library/disk currently in use (0/1 for disk#1/disk#2).
fi_disk_nr
	dc.w	0
	; Latest loaded file.
fi_file_nr
	dc.w	0
files_info_end

	; Game files metadata offsets.
FILES_IDX_CONV  =	(fi_idx_conv-files_info)
FILES_DISK_NR   =	(fi_disk_nr-files_info)
FILES_FILE_NR   =	(fi_file_nr-files_info)

	;
	; End of the 'fileops' code & data block containing the
	; routines in charge of loading game files from DRV-A or
	; ramdisk.
	;
fileops_end

	;
	; Length of the 'fileops' code & data block.
	;
FILEOPS_LEN     =	(fileops_end-fileops_start)

	;
	; Offsets within the 'fileops' block.
	;
READ_FILE_OFF   =	(read_file-fileops_start)
FILE_INFO_OFF   =	(files_info-fileops_start)
FI_DISK_NR_OFF  =	(fi_disk_nr-fileops_start)

***************************************************************************
*
* 12. Game files unpacking support
*
* This section provides services for:
* - Unpacking game files.
* - Patching game programs on-the-fly to enable various fixes and
*   improvements.
*
* Public routines:
* - depack()
* - apply_fixes()
* - decrunch_routine() / dec_nrv2b()
*
* Doc:
* - https://github.com/upx/upx
* - http://www.atari-forum.com/viewtopic.php?p=371256#p371256
*
***************************************************************************

	;
	; Start of the 'depack' code & data block.
	; It includes the routines in charge of unpacking game
	; files and patching them to enable game improvements.
	;
	; This block is installed in a low memory area by
	; game_patch().
	;
	; See sections "14. Installation and start of the game" and
	; "13. Game modifications" for a description of the game
	; installation process (including how resident code blocks
	; are installed).
	;
depack_start

	;
	; depack()
	;
	; Unpack a file and patch it on-the-fly if needed.
	;
	; In:
	;   a0: start address of packed data
	;   a1: destination address of unpacked data
	;
	; Out:
	;   d0: unpacked size
	;
depack
	movem.l	d1-d2/a0-a2,-(a7)

	; Unpack data.
	bsr.s	decrunch_routine

	;
	; Patch the unpacked data to enable available
	; improvements and fixes.
	;
	lea	fixes_tbl(pc),a2
	moveq.l	#(fixes_tbl_end-fixes_tbl)/4-1,d1
.lp	move.l	(a2)+,d2
	beq.s	.next
	movea.l	d2,a0
	bsr.s	apply_fixes
.next	dbf	d1,.lp

.ret	movem.l	(a7)+,d1-d2/a0-a2
	rts

	;
	; Array of tables of modifications.
	;
	; The following array puts together several tables of
	; modifications.
	;
	; A table of modifications is a set of fixes that are
	; related to a single feature (e.g. PSG, Keyboard or
	; Trainer...) and that should be applied to the programs
	; of the game (ie files containing code).
	;
	; Each entry in a table of modifications represents a
	; single fix to be applied to a particular program file.
	;
	; The following array gathers all tables of modifications,
	; i.e. all possible fixes that should be applied to the
	; game programs.
	;
	; When a file is loaded and unpacked, the depack() routine
	; walks through this array and call apply_fixes() for each
	; table of modifications.
	; All the fixes that are relevant to the program file that
	; has just been loaded are therefore applied.
	;
	; Some entries of this array are updated at runtime by the
	; game_patch() routine to cope with:
	; - resident code blocks installed at varying locations
	;   (ie determined dynamically): entries need therefore to
	;   be relocated.
	; - machine-specific adaptations: entries may be
	;   initialized or left to NULL depending on the machine
	;   type.
	;
	; A NULL entry is ignored.
	;
fixes_tbl
fixes_ent_keyb
	; Improved joystick/keyboard support. Corresponding code
	; might be installed either in low RAM or in high RAM,
	; meaning that this entry needs to be relocated.
	dc.l	KEYB_FIX_TBL_OFF
fixes_ent_psg
	; Improved sample replay routines. This entry is
	; present on machines with at least 1MB of RAM.
	; It is patched by the game_patch() routine.
	dc.l	0
fixes_ent_rasters
	; Optimized rasters support (high score screen). This entry
	; is present on machines with at least 1MB of RAM.
	; It is patched by the game_patch() routine.
	dc.l	0
fixes_ent_timer50hz
	; Enable musics to be played at 50Hz on 60Hz monitors.
	; This entry is present on TT and Falcon/CT60 machines
	; that are connected to a VGA monitor and on legacy
	; machines connected to a 60Hz monitor.
	; It is patched by the game_patch() routine.
	dc.l	0
fixes_ent_overscan
	; Fixes the removal of the low border (overscan).
	; This entry is present on fast machines only (> 8MHz).
	; It is patched by the game_patch() routine.
	dc.l	0
fixes_ent_tr
	; Trainer mode support.
	dc.l	TRAINER_RESID_ADDR+TR_TBL_OFF
fixes_tbl_end

	;
	; apply_fixes()
	;
	; Apply a set of modifications to the latest loaded and
	; unpacked program file.
	;
	; The table of modifications, which is passed in a0 to this
	; routine, provides several fixes corresponding to a single
	; feature (e.g. PSG, Keyboard or Trainer...) and possibly
	; applying to different program files.
	;
	; Each entry in the table represents a unique fix that
	; should be applied to a particular program file.
	;
	; The following routine walks through the given table and
	; applies the modifications that are only relevant to the
	; latest loaded and unpacked program file.
	;
	; Each entry of the table describes a single modification
	; and has the following structure:
	;   1 byte:  Game file number
	;   1 byte:  (L)ength of the data to be modified
	;   2 bytes: Offset from the beginning of the file where
	;            the data to be modified are located
	;   L bytes: new data
	;
	; The table contains multiple entries and ends with a
	; zero file number.
	;
	; In:
	;   a0: zero-terminated table of modifications
	;   a1: address of unpacked file data
	;
apply_fixes
	movem.l	d0-d2/a0,-(a7)

	; Get the file number corresponding to the unpacked data.
	; This information was saved by the read_file() routine.
	move.w	FILEOPS_ADDR+FILE_INFO_OFF+FILES_FILE_NR,d0
	moveq.l	#0,d1
	moveq.l	#0,d2

	; Walk through the table of modifications.
.lookup	move.b	(a0)+,d2
	beq.s	.done           ; end of table
	move.b	(a0)+,d1        ; d1 = patch length
	cmp.b	d0,d2           ; match current file?
	beq.s	.match          ; yes, apply this patch
	lea	2(a0,d1.w),a0   ; next table entry
	bra.s	.lookup

	; Apply a single fix.
.match	move.w	(a0)+,d2        ; d2 = file offset
.patch	move.w	(a0)+,0(a1,d2.l)
	addq.l	#2,d2
	subq.l	#2,d1
	bne.s	.patch          ; next patch word
	bra.s	.lookup         ; next table entry

.done	movem.l	(a7)+,d0-d2/a0
	rts

USE_PACK_DUMMY = 1

	ifne	USE_PACK_DUMMY
	;
	; dec_dummy()
	;
	; Copy a non-packed game file.
	;
	; Game files which are not packed are wrapped with a
	; dummy header so that they can be copied, as if they
	; were unpacked, to the expected destination address.
	;
	; In:
	;   a0: start address of file data
	;   a1: destination address of file data
	;
	; Out:
	;   (a7): original file data size
	;
	; Scratch: d0/a0-a1
	;
dec_dummy:
	move.l	8(a0),d0
	move.l	d0,(a7)
	lea	16(a0),a0
.cp	move.b	(a0)+,(a1)+
	subq.l	#1,d0
	bne.s	.cp
	bra.s	decompr_end
	endc

	;
	; UPX unpacking macros
	;

ADDBITS	macro
	add.b 	d0,d0           ; sets Z, C and X
	endm

	; Get 1 byte, then get 1 bit into both C and X.
FILLBITS	macro
	; Note: we shift the X flag through,
	; thus must init d0.b with $80.
	move.b	(a0)+,d0
	addx.b	d0,d0           ; sets C and X
	endm

GETBIT	macro
	ADDBITS
	bne.s	\@
	FILLBITS
\@
	endm

	;
	; dec_nrv2b()
	;
	; UPX NRV2B unpacking routine by Markus Oberhumer,
	; Laszlo Molnar & John Reiser.
	;
	; In:
	;   a0: start address of packed data
	;   a1: destination address of unpacked data
	;
	; Out:
	;   d0: unpacked data size
	;
decrunch_routine:
dec_nrv2b:
	movem.l	d0-a6,-(a7)

	; Check if the file is packed with UPX.
	cmpi.l	#"UPX!",(a0)
	ifne	USE_PACK_DUMMY
	; File is not packed with UPX, assume it is wrapped
	; with the dummy header.
	bne.s	dec_dummy
	elseif
	; File is not packed with UPX, return.
	bne.s	decompr_end
	endc

	; Store the unpacked file size into saved d0.
	move.l	8(a0),(a7)
	; Skip the UPX header.
	lea	32(a0),a0

	moveq.l	#-1,d5
	moveq.l	#-128,d0        ; d0.b = $80
	moveq.l	#-1,d7
	moveq.l	#-$68,d6        ; 0xffffff98
	lsl.w	#5,d6           ; 0xfffff300 = -0xd00
	bra.s	decompr_loop
decompr_end:
	movem.l	(a7)+,d0-a6
	rts

decompr_literal:
	move.b	(a0)+,(a1)+
decompr_loop:
	GETBIT
	bcs.s	decompr_literal
decompr_match:
	moveq.l	#1,d1
	moveq.l	#0,d3
decompr_l1:
	GETBIT
	addx.l	d1,d1
	GETBIT
	bcc.s	decompr_l1

	subq.l	#3,d1
	bcs.s	decompr_get_mlen ; last m_off
	lsl.l	#8,d1
	move.b	(a0)+,d1
	not.l	d1
	beq.s	decompr_end
	move.l	d1,d5

decompr_get_mlen:
	GETBIT
	addx.w	d3,d3
	GETBIT
	addx.w	d3,d3
	tst.w	d3              ; addx doesn't set the Z flag
	bne.s	decompr_got_mlen
	addq.w	#1,d3

decompr_l2:
	GETBIT
	addx.w	d3,d3
	GETBIT
	bcc.s	decompr_l2

	addq.w	#2,d3

decompr_got_mlen:
	lea	0(a1,d5.l),a2

	; Must use sub as cmp doesn't affect the X flag.
	move.l	d5,d1
	sub.l	d6,d1
	addx.w	d7,d3

	move.b	(a2)+,(a1)+
.copy:	move.b	(a2)+,(a1)+
	dbra	d3,.copy

	bra.s	decompr_loop

	;
	; End of the 'depack' code & data block containing the
	; routines in charge of unpacking game files and patching
	; them to enable game improvements.
	;
depack_end

	;
	; Length of the 'depack' code & data block.
	;
DEPACK_LEN                 =	(depack_end-depack_start)

***************************************************************************
*
* 13. Game modifications (cracking, enhancements, bug-fixes...)
*
* This section provides the game_patch() routine that modifies the game
* to achieve the following improvements:
*
* - Cracking
*   . Completely remove the copy-protection, and especially neutralize
*     the 4 checksum routines that are still active in Terminator Kid's
*     version.
*   . Install new game file loading routines (provided in sections 5 & 6).
*     This allows to load game files from a filesystem and from a ramdisk.
*   . Install new unpacking routines (provided in section 7).
*     Game files have been repacked with UPX.
*   . Add a mega-trainer mode.
*
* - Multi-machines support (MegaSTe/TT/Falcon/CT60)
*   . Install improved sample replay routines (music modules and sound FX)
*     that work on Falcon and do not hang on ST in the high score screen.
*   . Improve the stability of the rasters in the high score screen.
*   . Allow the musics to be played at 50Hz, and the game frame rate
*     to run at the correct speed, on 60Hz monitors.
*   . Provide an exception handler used to emulate the 'movep' instruction
*     on 68060 CPUs (CT60).
*   . Open the low border (overscan) only on ST(e) machines running at
*     8MHz, thereby avoiding a crash on faster machines.
*
* - Bug-fixes
*   . Install improved ACIA/IKBD routines (keyboard/joystick) so that
*     IKBD events are no longer lost.
*   . Modify the game finale (special animation played when the game has
*     been finished) so that it is now possible to access the high score
*     screen and restart the game.
*   . Improve the "blank screen" routine (cleanup routine called at
*     the end of every game subprogram).
*   . Fix a crash that may occur on fast machines when the scene
*     (the background) is drawn.
*   . Fix an out-of-bounds array access when too many objects (coins,
*     diamonds, food...) exist at the same time.
*   . Fix an out-of-bounds array access when too many projectiles appear
*     on the screen at the same time.
*   . Fix an out-of-bounds array access when 6 or more weapon bonuses
*     appear on the screen at the same time.
*
* Game modifications are implemented as:
*
* 1) Additional blocks of code installed in unused memory areas.
*
*    This section ("13. Game modifications") provides all resident code
*    blocks that implement game enhancements, except those that implement
*    file loading, which you will find in the following sections:
*      10. FDC/DMA support
*      11. Game files loading support
*      12. Game files unpacking support
*
*    All blocks of resident code are installed at startup by the
*    game_patch() routine. They are installed in safe memory areas,
*    ie areas which are not used by the game. These areas are located:
*    - in low memory (below $800)
*    - in high memory (on machines having 1MB of RAM or more)
*    - in the main game program itself, replacing disabled code
* 
*    The complete memory layout of the game, including safe areas where
*    blocks of resident code are installed, is detailed in section
*    "14. Installation and start of the game".
*
* 2) Sets of changes (patches) applied to various programs of the game.
*
*    Although all game files have been repacked for this release, their
*    original contents have been preserved (no changes, except repacking,
*    have been made to the files stored on disk).
*    Therefore, all changes which are applied to game programs are made
*    at runtime when programs are loaded and unpacked.
*
*    The main game program (file $03) is loaded at startup by the
*    game_install() routine and is patched directly by the game_patch()
*    routine.
*
*    Other program files are loaded during the game by the read_file()
*    routine (part of the 'fileops' code block), then unpacked and patched
*    by the depack() routine (part of the 'depack' code block).
*
*    See apply_fixes() for detailed comments on that on-the-fly patching
*    mechanism.
*
* See Section "14. Installation and start of the game" for a description
* of the game startup sequence, and in particular how the game_patch()
* routine is called.
*
* As stated above, one of the goals of the game_patch() routine is to
* completely remove the copy-protection from the game.
*
* In this game, the copy-protection is implemented as two complementary
* parts:
*
* 1) The first part of the protection is the earliest piece of code
*    that is executed, even before the initial animation is displayed.
*
*    The crack of Terminator Kid is the version closest to the original
*    copy of the game. And in this cracked version, the first part of
*    the protection is no longer executed.
*    However, it is still partially present on disk#1.
*
*    Despite the lack of an original copy containing the entire copy
*    protection, the first part of the protection has been identified.
*    It is called "Initial Program Load" (IPL). It is a huge piece of
*    code encrypted and using many anti-hackers techniques such as:
*    trace vector decoder, synchro decoding, code executing from $8,
*    false routines & dead ends, code running on the IKBD processor,
*    reset of the CPU & peripherals...
*    The purpose of the IPL is to verify that the disk in use is an
*    original copy. To this end, it reads protected tracks on the disk
*    and crashes in case of a copy.
*    It also writes some magic values in low memory that are checked
*    later during the game (see below).
*    Eventually, it loads and executes the initial program of the game.
*
*    See https://github.com/orionfuzion/newcracks/blob/master/SonShuSi/IPL.md
*    for a complete description of the IPL (a must read!).
*
* 2) The second part of the protection is composed of 11 checksum routines
*    hidden in the main program. These routines are executed during the
*    game and check that the magic values have been actually written in
*    low memory by the first part (the IPL).
*
*    Since the first part of the protection is no longer executed, it is
*    necessary to disable the 11 checksum routines.
*
*    Terminator Kid cracked the checksum routines as follows: he ran
*    the IPL on his machine, then he dumped the contents of the low
*    memory containing the magic values, and he just created a small
*    boot program that copies this dump into low memory before starting
*    the game.
*
*    But the magic values are not just constant values, they are actually
*    computed using machine-specific information.
*    Typically, magic values are computed using:
*    - The TOS version
*    - The TOS date
*    - The TOS start address
*    - The machine type (STf or STe)
*    - The memory configuration (512KB, 1MB,...)
*
*    Therefore, The magic values will not be the same on two different
*    machines. And this is what is verified by the checksum routines:
*    they compare the magic values found in low memory with the values
*    expected for the current machine.
*
*    So, if the cracking method is simply to write in low memory the
*    magic values found on a given machine, then the checksum routines
*    will only succeed on this machine (or identical) and fail on others.
*
*    And that's what happens with Terminator Kid's crack: it only works
*    correctly on a machine similar to the one he used to crack the game:
*    an Atari STe, with 4MB of RAM, using TOS 1.62.
*
*    To be exact, Terminator Kid managed to disable 7 checksum routines
*    out of the 11 present in the game. Indeed, his boot program also
*    includes a routine that dynamically generates certain magic values
*    correctly using machine-specific information.
*    But since he did not find all the magic values and the corresponding
*    checksum routines, he finally used the simplistic approach of dumping
*    the low memory as a workaround.
*
*    It must be said that the checksum routines are very difficult to
*    find: they are mixed up with the code of the game, their code is
*    obfuscated and it is almost impossible to guess what it does by
*    simply reading it.
*
*    In the end, Terminator Kid's crack contains 4 checksum routines that
*    are still active and that make the game crash at different stages.
*
*    Note that TK's crack images available on the Internet are all corrupt,
*    which also causes crashes during the game. See "11. Game files loading
*    support" for details.
*
*    The game_patch() routine hereafter neutralizes all checksum routines,
*    thus completely removing the copy-protection from the game.
*    As a result, magic values are no longer needed in the low memory,
*    which can then be used to place resident code.
*    Same for the areas occupied by checksum routines that are now used
*    to install small blocks of resident code (mainly bug fixes).
*
*    See the code of game_patch() for detailed information on every
*    checksum routine.
*
*    Note that an additional protection mechanism is present within the
*    game: all tracks are encrypted on both floppy disks and decrypted
*    on-the-fly when they are loaded (the game does not use the standard
*    FAT12 filesystem but loads its data from hard-coded disk areas,
*    without TOS assistance).
*
* Public routines:
* - game_patch()
*
* Resident code & data:
* - screen_off()
* - vectors_off()
* - copy_screen_fix()
* - weapon_fire_fix()
* - weapon_bonus_fix()
* - movep_emul()
* - overscan_fix_tbl
* - keyb_fix_tbl (improved ACIA/IKBD routines)
* - mus_fix_tbl (improved sample replay routines)
* - rasters_tbl (optimized rasters support for the high score screen)
* - timer50hz_tbl (60Hz monitor support)
* - tr_tbl (trainer routines)
*
* Doc:
* - https://github.com/orionfuzion/newcracks/blob/master/SonShuSi/IPL.md
* - https://github.com/orionfuzion/newcracks/blob/master/AudioS15/README.md
* - http://atari-forum.com/viewtopic.php?f=14&t=31939
*
***************************************************************************

	;
	; game_patch()
	;
	; Patch the main game program and install the various
	; blocks of resident code.
	;
	; The main game program is stored unmodified (but repacked)
	; in library #1 (disk#1).
	; It is loaded and unpacked by the game_install() routine
	; and patched on-the-fly here in order to:
	; - Remove the copy-protection
	; - Add trainer mode support
	; - Fix bugs
	; - Add MegaSTe/TT/Falcon/CT60 support
	; - Install new loading routines
	; - Install the new UPX unpacking routine
	;
	; Several blocks of resident code are installed either
	; in the main game program itself (replacing disabled
	; code) or in memory areas that are not used by the game
	; (typically below $800 or in high memory).
	; See section "14. Installation and start of the game"
	; for the detailed memory layout.
	;
game_patch
	movem.l	d0-d1/d7/a0-a2,-(a7)

	; Current machine type is saved in d7.
	move.w	mach_type(pc),d7

	;
	; Neutralize checksum routine #1 (located at $8330)
	;
	; Checksum routine #1 has the following characteristics:
	; - It is called each time a level, room or passage is
	;   started and when a level is resumed.
	; - It checks a magic word stored at $2a4, that is computed
	;   using the TOS version.
	; - It corrupts the game code if the check fails.
	; - It is neutralized in TK's crack.
	; - It is implemented as follows:
	;   (values in parentheses are for an STe, TOS 1.62, 4MB)
	;
	; lea	$849.a0
	; st	(a0)
	; move.w	#1,$8b4.w
	; move.w	-$847(a0),d0    ;   $2 (0162)
	; clr.l	$840.w
	; sub.w	-$5a5(a0),d0    ; $2a4 (0162)
	; lea	$9808(pc),a0
	; bne.s	<addr>          ; [corrupt code]
	;
	; Patch the routine: replace the 'bne.s' instruction
	; with a 'nop'.
	move.w	#$4e71,GAME_DEST_ADDR+$534c

	;
	; Neutralize checksum routine #2 (located at $acfe)
	;
	; Checksum routine #2 has the following characteristics:
	; - It is called every time a new life is started.
	; - It checks a magic byte stored at $2ac, that is computed
	;   using the TOS start address.
	; - It corrupts the game data if the check fails, and it
	;   saves #$9920 to $8c8 otherwise (for later check).
	; - It is neutralized in TK's crack.
	; - It is implemented as follows:
	;   (values in parentheses are for an STe, TOS 1.62, 4MB)
	;
	; lea	$ffd0(pc),a3
	; move.l	a3,d4
	; neg.l	d4
	; move.b	5(a3,d4.l),d0   ; $5 ($e0)
	; or.b	7(a3,d4.l),d0   ; $7 ($30)
	; move.l	a7,d1
	; addi.w	#$6e,d1
	; clr.b	d1              ; d1=$400
	; movea.w	d1,a1
	; sub.b	-$154(a1),d0    ; $2ac ($f0)
	; bne.s	<addr>          ; [corrupt data]
	; [save #$00009920 to $8c8]
	;
	; Patch the routine: skip the check and directly
	; save #$9920 to $8c8.
	move.w	#$6016,GAME_DEST_ADDR+$7d06

	;
	; Neutralize checksum routine #3 (located at $1061a)
	;
	; Checksum routine #3 has the following characteristics:
	; - It is called each time a level, room or passage is
	;   started, when a level is resumed and during the game
	;   when money is collected.
	; - It checks if $8c8 contains #$9920, as saved by checksum
	;   routine #2.
	; - It corrupts the screen address if the check fails.
	; - It is neutralized in TK's crack.
	; - It is implemented as follows:
	;
	; lea	$ffd0(pc),a4
	; move.l	a4,d3
	; addi.l	#$ffff9950,d3   ; d3=$9920
	; lea	$8cb.w,a4
	; cmp.l	-3(a4),d3       ; $8c8 ($9920)
	; beq.s	<addr>          ; [return]
	; [corrupt screen address in the data]
	;
	; Patch the routine: replace the 'beq.s' instruction
	; with a 'bra.s'.
	move.b	#$60,GAME_DEST_ADDR+$d62e

	;
	; Neutralize checksum routine #4 (located at $9586)
	;
	; Checksum routine #4 has the following characteristics:
	; - It is called each time a level, room or passage is
	;   started, when a level is resumed and when the hero
	;   dies.
	; - It checks a magic long stored at $4a4, that is computed
	;   using a constant magic word (stored at $29c), the TOS
	;   start address and the TOS date.
	; - It corrupts the game code if the check fails (a nop is
	;   placed in the game init): the array that describes the
	;   enemies on the screen is no longer cleared, causing a
	;   delayed out-of-bound array access and hence a memory
	;   corruption.
	; - It is still active in TK's crack.
	; - It is implemented as follows:
	;   (values in parentheses are for an STe, TOS 1.62, 4MB)
	;
	; .1: moveq	#$68,d0
	; movea.l	d0,a0
	; move.w	.1(pc),d7       ; d7=$7068
	; move.w	$234(a0),d0     ; $29c ($0755)
	; eori.w	#$74d,d0        ; d0=$18
	; move.l	-$64(a0),d1     ; $4 ($00e00030)
	; eori.w	#$3e00,d7       ; d7=$4e68
	; move.b	d0,d1           ; d1=$00e00018
	; move.l	$43c(a0),d0     ; $4a4 (01e119a8)
	; movea.l	d1,a0
	; add.l	(a0),d1         ; $e00018 ($01011990)
	; sub.l	d0,d1
	; beq.s	<addr>          ; [return]
	; [corrupt code with a 'nop' written at $9398]
	;
	; Patch the routine: replace the first instruction
	; with a 'rts'.
	; The copy_screen_fix() routine is installed in place
	; of this checksum routine in the $32 bytes available
	; right after the 'rts'
	move.w	#$4e75,GAME_DEST_ADDR+$6586

	;
	; Neutralize checksum routine #5 (located at $f618)
	;
	; Checksum routine #5 has the following characteristics:
	; - It is called during the game when an enemy or an object
	;   appears.
	; - It checks a magic word stored at $4a8, that is computed
	;   using the MMU (memory banks) configuration ($ff8001).
	; - It corrupts the game data if the check fails:
	;   Entering a game module (room, shop...) now causes an
	;   unexpected restart of the current level and corruption
	;   of the graphics.
	;   The address where the next program should be loaded is
	;   reset to 0 so that loading a new program (typically the
	;   "game over" screen) results in a crash.
	; - It is still active in TK's crack.
	; - It is implemented as follows:
	;   (values in parentheses are for an STe, TOS 1.62, 4MB)
	;
	; moveq	#-1,d0
	; moveq	#1,d1
	; .1: add.w	d1,d1
	; dbmi	d0, .1
	; addq	#1,d1           ; d0=$ffffffff d1=$8001
	; movea.w	d1,a0
	; move.b	(a0),d0         ; $ffff8001 ($0a)
	; subi.b	#$7b,d0         ; d0=$ffffff8f
	; lea	$45d2(a0),a0    ; a0=$ffffc5d3
	; cmp.w	$3ed5(a0),d0    ; $4a8 ($ff8f)
	; beq.s	<addr>          ; [continue]
	; [corrupt game data and loading address of next program]
	;
	; Patch the routine: replace the first instruction
	; with a 'bra.s' in order to skip the check.
	; The weapon_bonus_fix() routine is installed in place
	; of this checksum routine in the $28 bytes available
	; right after the 'bra.s'
	move.w	#$6028,GAME_DEST_ADDR+$c618

	;
	; Neutralize checksum routine #6 (located at $fe90)
	;
	; Checksum routine #6 has the following characteristics:
	; - It is called every time special enemies or objects
	;   appear.
	; - It checks a magic byte stored at $4aa, that is computed
	;   using the MMU (memory banks) configuration ($ff8001).
	; - It corrupts the game data if the check fails:
	;   the number of enemies currently on the screen is reset
	;   to a random number, which causes unexpected effects
	;   ranging from changing the number of enemies on the
	;   screen to a crash of the game.
	; - It is still active in TK's crack.
	; - It is implemented as follows:
	;   (values in parentheses are for an STe, TOS 1.62, 4MB)
	;
	; lea	$ffff8240.w,a0
	; lea	<buffer>(pc),a1
	; moveq	#7,d0
	; .1: move.l	(a0)+,(a1)+
	; dbf	d0,.1
	; lsr.w	#2,d0           ; d0=$3fff
	; adda.w	d0,a0           ; a0=$ffffc25f
	; move.b	$424b(a0),d0    ; $4aa ($0a)
	; sub.b	-$425e(a0),d0   ; $ffff8001 ($0a)
	; beq.s	<addr>          ; [return]
	; [corrupt number of enemies by writing d7.w to $2d32]
	;
	; Patch the routine: replace the 'lsr.w' instruction
	; with a 'rts'.
	; The copy_screen_fix() 'trampoline' is installed in place
	; of this checksum routine in the $18 bytes available
	; right after the 'rts'
	move.w	#$4e75,GAME_DEST_ADDR+$cea0

	;
	; Neutralize checksum routine #7 (located at $c63a)
	;
	; Checksum routine #7 has the following characteristics:
	; - It is called every time the hero passes a door to
	;   a room, a shop or a passage.
	; - It checks a magic byte stored at $4ab, that is computed
	;   using the machine type ($00 if STe, $ff if STf).
	; - It corrupts the game data (including a jump table) if
	;   the check fails.
	; - It is neutralized in TK's crack.
	; - It is implemented as follows:
	;   (values in parentheses are for an STe, TOS 1.62, 4MB)
	;
	; lea	.1(pc),a6
	; move.l	a6,$8.w
	; movea.l	a7,a6
	; st	d0              ; d0=$xxxxxxff
	; tst.b	$ffff8901.w     ; STe DMA Ctrl Register
	; sf	d0              ; d0=$xxxxxx00
	; .1: movea.l	a6,a7
	; cmp.b	$4ab.w,d0       ; $4ab ($00)
	; beq.s	<addr>          ; [continue]
	; [corrupt data, including a jump table]
	;
	; Patch the routine: replace the first instruction
	; with a 'bra' in order to skip the check.
	; The tr_force() routine is installed in place of this
	; checksum routine in the $3e bytes available right
	; after the 'bra'.
	move.l	#$6000ff6e,GAME_DEST_ADDR+$963a

	;
	; Neutralize checksum routine #8 (located at $8a30)
	;
	; Checksum routine #8 has the following characteristics:
	; - It is called every time a level, a room or a passage
	;   is exited.
	; - It checks a magic long stored at $4a0, that is computed
	;   using a constant magic long (stored at $294), the TOS
	;   start address and the TOS version.
	; - The #'SYNC' constant is used to obfuscate the magic
	;   value. It is a reference to the SYNC demogroup who
	;   coded Audio Sculpture and who participated in this
	;   protection! 
	; - It corrupts the game code if the check fails: the
	;   'rts' instruction of the current routine (containing
	;   the checksum code being executed) is replaced by a nop.
	;   It causes the hero to exit and re-enter the current
	;   level indefinitely.
	; - It is still active in TK's crack.
	;   Note that it has been fixed in Ppera's version.
	; - It is implemented as follows:
	;   (values in parentheses are for an STe, TOS 1.62, 4MB)
	;
	; lea	$8783(pc),a1
	; suba.l	a0,a0
	; lea	$4882(a1),a3
	; adda.l	$294(a0),a0     ; $294 ($ffffffdf)
	; move.l	$23(a0),d1      ; $2 ($016200e0)
	; move.l	$4c1(a0),d0     ; $4a0 ($523b4ea3)
	; eori.l	#'SYNC',d0      ; d0=$016200e0
	; eor.l	d0,d1
	; beq.s	<addr>          ; [continue]
	; [corrupt the code by writing a nop at $8a9c]
	;
	; Patch the routine: replace the first instruction
	; with a 'bra.s' in order to skip the check.
	; The weapon_fire_fix() routine is installed in place of
	; this checksum routine in the $2a bytes available right
	; after the 'bra.s'.
	move.w	#$602a,GAME_DEST_ADDR+$5a30

	;
	; Neutralize checksum routine #9 (located at $913a)
	;
	; Checksum routine #9 has the following characteristics:
	; - It is called every time a boss is killed.
	; - It checks a magic long stored at $2a6, that is computed
	;   using a constant magic byte (stored at $29b) and the
	;   TOS date.
	; - It corrupts the game data if the check fails.
	; - It is neutralized in TK's crack.
	; - It is implemented as follows:
	;   (values in parentheses are for an STe, TOS 1.62, 4MB)
	;
	; suba.l	a0,a0
	; moveq	#$7b,d0
	; move.l	-$77(a0,d0.w),d0 ; $4 ($00e00030)
	; move.b	$29b.w,d0       ; $29b ($08)
	; movea.l	d0,a0
	; move.l	$10(a0),d0      ; $e00018 ($01011990)
	; neg.l	d0
	; add.l	$2a6.w,d0       ; $2a6 ($01011990)
	; beq.s	<addr>          ; [continue]
	; [corrupt data]
	;
	; Patch the routine: replace the first instruction
	; with a 'bra.s' in order to skip the check.
	; The vectors_off() routine is installed in place of
	; this checksum routine in the $2e bytes available right
	; after the 'bra.s'.
	move.w	#$602e,GAME_DEST_ADDR+$613a

	;
	; Neutralize checksum routine #10 (located at $c870)
	;
	; Checksum routine #10 has the following characteristics:
	; - It is called every time the brick game is launched.
	; - It indirectly checks if the track decoding routine
	;   is present in low memory (floppy track encoding is
	;   part of the protection).
	;   To this end, the routine checks a magic long stored
	;   at $2a0, that is computed using the value found at
	;   address $706. This memory location is part of the
	;   track decoding routine and contains the address of
	;   the track loading buffer ($7ee00).
	; - It corrupts the game data if the check fails.
	; - It is neutralized as long as the original track
	;   loading and decoding routines are used, which is
	;   the case of TK's crack.
	; - It is implemented as follows:
	;
	; lea	$706.w,a0
	; move.l	(a0),d0         ; $706 ($0007ee00)
	; eori.l	#$bd556bdc,d0
	; move.l	-$466(a0),d1    ; $2a0 ($bd5285dc)
	; sub.l	d0,d1
	; beq.s	<addr>          ; [continue]
	; [corrupt data]
	;
	; Patch the routine: replace the first instruction
	; with a 'bra.s' in order to skip the check.
	; The tr_neverfall() routine is installed in place of
	; this checksum routine in the $2c bytes available right
	; after the 'bra.s'.
	move.w	#$602c,GAME_DEST_ADDR+$9870

	;
	; Neutralize checksum routine #11 (located at $978e)
	;
	; Checksum routine #11 has the following characteristics:
	; - It is called after the high scores screen (thus after
	;   the game is over).
	; - It checks a magic word stored at $2aa, that is computed
	;   using a constant magic word (stored at $298) and the
	;   TOS date.
	; - It corrupts the offset of a branch instruction in the
	;   code if the check fails.
	; - It is neutralized in TK's crack.
	; - It is implemented as follows:
	;   (values in parentheses are for an STe, TOS 1.62, 4MB)
	;
	; moveq	#4,d0
	; move.w	$2aa.w,d1       ; $2aa ($1a91)
	; movea.l	d0,a0
	; move.l	(a0)+,d0        ; $4 ($00e00030)
	; add.w	$290(a0),d1     ; $298 (0101)
	; subi.w	#$100,d1        ; d1=$1a92
	; move.b	#$18,d0
	; movea.l	d0,a0
	; move.w	(a0)+,d0        ; $e00018 (0101)
	; add.w	(a0),d0         ; $e0001a (1990)
	; addq.w	#1,d0           ; d0=$1a92
	; eor.w	d0,d1
	; beq.s	<addr>          ; [continue] 
	; [corrupt a 'branch' offset in the code]
	;
	; Patch the routine: replace the first instruction
	; with a 'bra.s' in order to skip the check.
	; The screen_off() routine is installed in place of
	; this checksum routine in the $2a bytes available right
	; after the 'bra.s'.
	move.w	#$602a,GAME_DEST_ADDR+$678e

	;
	; Patch the stack address: the stack is set to a new
	; address which is in low memory on 512KB machines,
	; or in high memory on machines with more RAM.
	;
	ifeq	FORCE_LOW_STACK
	lea	GAME_STACK_ADDR_HIGH,a0
	cmpa.l	TPA.w,a0
	bls.s	.sp_fix
	endc
	lea	GAME_STACK_ADDR_LOW,a0
.sp_fix	move.l	a0,GAME_DEST_ADDR+$61a8

	;
	; Debug mode only: setup the code used for stack overflow
	; detection.
	;
	ifne	DEBUG_ASSERT
	lea	-$800(a0),a0
	lea	mus_replay_assert(pc),a1
	move.l	a0,2(a1)
	move.l	a0,mus_replay_assert_falcon+2-mus_replay_assert(a1)
	endc	; DEBUG_ASSERT

	; Fix an incorrect SR assignment in the VBL routine used
	; during the game.
	move.w	#$2400,GAME_DEST_ADDR+$5310

	; Prevent the game from checking/using the high RAM
	; (the second 512KB), as it is now used for the ramdisk.
	move.l	#$4e714e71,GAME_DEST_ADDR+$6738

	; Patch the address of the unpacking routine so that the
	; new UPX routine is used (the original Pack-Ice routine
	; is no longer used).
	move.w	#DEPACK_ADDR,GAME_DEST_ADDR+$61b0

	; Make the game correctly get the unpacked size from
	; the header of compressed files (it was the pack-ice
	; header originally, it is the UPX header now).
	move.w	#8,GAME_DEST_ADDR+$671c

	; Patch the address of the file loading routine so that
	; our own FDC/DMA/FAT12 routines are used (the original
	; track loader routines are no longer used).
	move.w	#FILEOPS_ADDR+READ_FILE_OFF-(GAME_DEST_ADDR+$61ce),GAME_DEST_ADDR+$61ce

	; Prevent the game from loading the original file table
	; since our own FDC/DMA/FAT12 routines are now used.
	move.w	#$4e71,GAME_DEST_ADDR+$6742

	; The level management program is supplied in two copies:
	; file $04 on disk#1 is the same as file $54 on disk#2.
	; When the game loads this program, it selects file $04
	; or $54 depending on the disk currently inserted (to
	; avoid swapping disks).
	; When library #1 (containing file $04) is accessible as
	; a ramdisk, it is more efficient to always load the level
	; management program from it.
	; The main game program is patched below for this purpose.
	; See "11. Game files loading support" for a description
	; of game files.
	move.l	lib_info1+LIB_RAM_OFF(pc),d0
	bmi.s	.disk_nr
	move.w	#$7004,GAME_DEST_ADDR+$6188

	; Fix the address where the main game program expects to
	; find the number of the floppy disk in use.
.disk_nr
	move.w	#FILEOPS_ADDR+FI_DISK_NR_OFF+1-(GAME_DEST_ADDR+$6182),GAME_DEST_ADDR+$6182

	;
	; Install the 'fileops' code block containing the routines
	; in charge of loading game files from Drive-A or ramdisk.
	; This resident code block is installed in the main
	; game program in place of the original FDC/DMA loading
	; routines.
	; See fileops_start for implementation and detailed
	; explanations.
	;
inst_fileops
	lea	fileops_start(pc),a0
	lea	FILEOPS_ADDR,a1
	move.w	#FILEOPS_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	;
	; Install the screen_off() routine providing an improved
	; "blank screen".
	; It is copied into the main game program in place of
	; checksum routine #11.
	;
patch_screen_off
	lea	screen_off(pc),a0
	lea	GAME_DEST_ADDR+SCREEN_OFF_DEST_OFF,a1
	move.w	#SCREEN_OFF_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	; Hook into the original "blank screen" code to
	; execute the screen_off() routine instead.
	move.w	#$6000,GAME_DEST_ADDR+$4552.w
	move.w	#SCREEN_OFF_DEST_OFF-$4554,GAME_DEST_ADDR+$4554.w

	;
	; Install the vectors_off() routine providing MFP cleanup.
	; vectors_off() is called by screen_off().
	; It is copied into the main game program in place of
	; checksum routine #9.
	;
patch_vectors_off
	lea	vectors_off(pc),a0
	lea	GAME_DEST_ADDR+VECTORS_OFF_DEST_OFF,a1
	move.w	#VECTORS_OFF_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	;
	; Install the copy_screen_fix() routine which fixes a bug
	; that occurs while drawing the scene on fast machines.
	; It is copied into the main game program in place of
	; checksum routine #4.
	;
patch_copy_screen
	lea	copy_screen_fix(pc),a0
	lea	GAME_DEST_ADDR+COPY_SCREEN_FIX_DEST_OFF,a1
	move.w	#COPY_SCREEN_FIX_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	; Install a "trampoline" that connects the "scene drawing"
	; code to the copy_screen_fix() routine.
	; The trampoline provides an additional branch instruction
	; to cope with the "distance" between the "scene drawing"
	; code and the location where the copy_screen_fix() routine
	; is copied.
	; The trampoline is installed in the main game program
	; in place of checksum routine #6.
	move.w	#$6600,GAME_DEST_ADDR+COPY_SCREEN_FIX_TRAMP_OFF
	move.w	#$f204-(COPY_SCREEN_FIX_TRAMP_OFF+2),GAME_DEST_ADDR+(COPY_SCREEN_FIX_TRAMP_OFF+2)
	move.w	#$6000,GAME_DEST_ADDR+(COPY_SCREEN_FIX_TRAMP_OFF+4)
	move.w	#COPY_SCREEN_FIX_DEST_OFF-(COPY_SCREEN_FIX_TRAMP_OFF+6),GAME_DEST_ADDR+(COPY_SCREEN_FIX_TRAMP_OFF+6)

	; Hook into the original "scene drawing" code to call
	; the trampoline that branches to the copy_screen_fix()
	; routine.
	move.w	#$6000,GAME_DEST_ADDR+$f39a
	move.w	#COPY_SCREEN_FIX_TRAMP_OFF-$f39c,GAME_DEST_ADDR+$f39c

	;
	; Install the weapon_fire_fix() routine that fixes an
	; out-of-bounds array access when too many projectiles
	; appear on the screen at the same time.
	; It is copied into the main game program in place of
	; checksum routine #8.
	;
patch_weapon_fire
	lea	weapon_fire_fix(pc),a0
	lea	GAME_DEST_ADDR+WEAPON_FIRE_FIX_DEST_OFF,a1
	move.w	#WEAPON_FIRE_FIX_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	; Hook into the code that accesses the projectiles array
	; in order to call the weapon_fire_fix() routine.
	move.w	#$6100,GAME_DEST_ADDR+$6972
	move.w	#WEAPON_FIRE_FIX_DEST_OFF-$6974,GAME_DEST_ADDR+$6974

	;
	; Install the weapon_bonus_fix() routine that fixes an
	; out-of-bounds array access when 6 or more weapon bonuses
	; appear on the screen at the same time.
	; It is copied into the main game program in place of
	; checksum routine #5.
	;
patch_weapon_bonus
	lea	weapon_bonus_fix(pc),a0
	lea	GAME_DEST_ADDR+WEAPON_BONUS_FIX_DEST_OFF,a1
	move.w	#WEAPON_BONUS_FIX_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	; Hook into the code that accesses the weapon bonus array
	; in order to call the weapon_bonus_fix() routine.
	move.w	#$6100,GAME_DEST_ADDR+$87da
	move.w	#WEAPON_BONUS_FIX_DEST_OFF-$87dc,GAME_DEST_ADDR+$87dc

	;
	; Install the anims_underflow_fix() routine that fixes the
	; underflow error in the game's state machine used to display
	; enemy animations.
	; It is copied into the main game program in place of
	; checksum routine #5, right after the weapon_bonus_fix()
	; routine.
	;
patch_anims_underflow
	lea	anims_underflow_fix(pc),a0
	lea	GAME_DEST_ADDR+ANIMS_UNDERFLOW_FIX_DEST_OFF,a1
	move.w	#ANIMS_UNDERFLOW_FIX_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	; Hook into the code that uses the "active animations"
	; counter so that the anims_underflow_fix() routine is
	; called to prevent the counter from becoming negative.
	move.w	#$6100,GAME_DEST_ADDR+$d720
	move.w	#ANIMS_UNDERFLOW_FIX_DEST_OFF-$d722,GAME_DEST_ADDR+$d722
	move.w	#$6100,GAME_DEST_ADDR+$d782
	move.w	#ANIMS_UNDERFLOW_FIX_DEST_OFF-$d784,GAME_DEST_ADDR+$d784
	move.w	#$6100,GAME_DEST_ADDR+$d858
	move.w	#ANIMS_UNDERFLOW_FIX_DEST_OFF-$d85a,GAME_DEST_ADDR+$d85a

	;
	; Fix an out-of-bounds array access when too many objects
	; (coins, diamonds, food...) exist at the same time.
	;
	move.w	#$0031,GAME_DEST_ADDR+$8cae

	;
	; On Falcon & TT, patch the main game program to disable
	; color palette changes during screen update as it is not
	; supported by Hatari 2.3.
	; This is for debug purpose only.
	;
patch_hatari_videl
	ifne	HATARI_VIDEL_WORKAROUND
	cmpi.b	#MCH_MEGASTE,d7
	bls.s	prep_resid
	move.w	#$603c,GAME_DEST_ADDR+$51e2
	endc

	;
	; Determine where the improved ACIA/IKBD (keyboard) and
	; PSG (music) routines should be installed, based on
	; the available RAM.
	;
prep_resid
	cmpi.l	#$80000,TPA.w
	bls.s	.ramlo

	; On machines with 1MB of RAM or more, improved ACIA/IKBD
	; and PSG routines are installed in high memory, in the
	; [$80000-$84800] area.
.ramhi	lea	KEYB_FIX_RESID_ADDR_HIGH,a0
	ifne	FORCE_ORIG_PSG
	suba.l	a1,a1
	elseif
	lea	PSG_FIX_RESID_ADDR,a1
	endc
	bra.s	.save

	; On machines with only 512KB of RAM, improved ACIA/IKBD
	; routines are installed in low memory, in the [$1c0-$800]
	; area, while improved PSG routines are not used
	; (the corresponding address is thus set to 0).
.ramlo	lea	KEYB_FIX_RESID_ADDR_LOW.w,a0
	suba.l	a1,a1

	; Save the addresses where those routines should be
	; installed.
.save	move.l	a0,KEYB_FIX_RESID_PTR.w
	move.l	a1,PSG_FIX_RESID_PTR.w

	;
	; Improved ACIA/IKBD routines are installed either
	; in high memory or in low memory. Therefore several
	; absolute addresses are relocated accordingly.
	;
reloc_keyb_fix
	move.l	a0,d0
	lea	fixes_ent_keyb(pc),a0
	add.l	d0,(a0)
	lea	keyb_file07_fix_reloc+2(pc),a0
	add.l	d0,(a0)
	lea	keyb_file52_fix1_reloc+2(pc),a0
	add.l	d0,(a0)
	lea	keyb_file52_fix2_reloc+2(pc),a0
	add.l	d0,(a0)
	lea	keyb_file53_fix1_reloc+2(pc),a0
	add.l	d0,(a0)
	lea	keyb_file53_fix2_reloc+2(pc),a0
	add.l	d0,(a0)
	lea	keyb_file55_fix1_reloc+2(pc),a0
	add.l	d0,(a0)
	lea	keyb_file55_fix2_reloc+2(pc),a0
	add.l	d0,(a0)
	lea	keyb_file55_fix3_reloc+2(pc),a0
	add.l	d0,(a0)
	lea	keyb_file26_fix1_reloc+2(pc),a0
	add.l	d0,(a0)
	lea	keyb_file26_fix2_reloc+2(pc),a0
	add.l	d0,(a0)
	lea	keyb_file89_fix_reloc+2(pc),a0
	add.l	d0,(a0)

	;
	; Install the block of resident code providing improved
	; ACIA/IKBD routines (keyboard/joystick) in the memory
	; area determined previously.
	; See keyb_fix_start for implementation and detailed
	; explanations.
	;
inst_keyb_fix
	lea	keyb_fix_start(pc),a0
	movea.l	KEYB_FIX_RESID_PTR.w,a1
	move.w	#KEYB_FIX_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	;
	; Install the block of resident code providing improved
	; sample replay routines (music modules and sound FX)
	; in high memory in the [$80000-$84800] area.
	; See psg_fix_start for implementation and detailed
	; explanations.
	;
inst_psg_fix
	; Skip installation on 512KB machines.
	move.l	PSG_FIX_RESID_PTR.w,d0
	beq	inst_rasters

	movea.l	d0,a1

	; Make sure that improved PSG routines are taken into
	; account when game files are patched on-the-fly.
	; To that end, update the array of tables of modifications
	; as described in section "12. Game files unpacking support".
	; See the fixes_tbl array for detailed comments.
	lea	fixes_ent_psg(pc),a0
	addi.l	#MUS_FIX_TBL_OFF,d0
	move.l	d0,(a0)

	; Copy the improved routines in high memory.
	lea	psg_fix_start(pc),a0
	move.w	#PSG_FIX_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	; Perform additional steps on Falcon machines only.
	cmpi.b	#MCH_FALCON,d7
	bne.s	inst_rasters

	; On Falcon/CT60, initialize the DA table used by the
	; new replay routine dedicated to sound effects.
	; See fx_replay_init_falcon(), which is called here,
	; for details.
	lea	GAME_DEST_ADDR+$4962,a0
	movea.l	PSG_FIX_RESID_PTR.w,a1
	jsr	FX_REPLAY_INIT_FALCON_OFF(a1)

	; Hook into the MFP initialization code to make
	; sure the new sound FX replay routine is used.
	; The code below writes:
	; 'move.l	#<new_fx_replay_routine>,$134.w'.
	; a0 contains the address of the new replay routine
	; as returned by fx_replay_init_falcon().
	move.w	#$21fc,GAME_DEST_ADDR+$663c
	move.l	a0,GAME_DEST_ADDR+$663c+2
	move.w	#$134,GAME_DEST_ADDR+$663c+6

	; Make sure Falcon-specific replay routines are used.
	; These routines do not use PSG shadow registers since
	; they are not supported on Falcon.
	; See mus_replay_init() and mus_replay_init_unmask()
	; for details.
	addi.w	#(mus_replay_falcon-mus_replay),MUS_REPLAY_INIT_OFF+2(a1)
	addi.w	#(mus_replay_unmask_falcon-mus_replay_unmask),MUS_REPLAY_INIT_UNMASK_OFF+2(a1)

	; Make sure the game does not use PSG shadow registers.
	move.w	#$8800,GAME_DEST_ADDR+$4910
	move.w	#$8802,GAME_DEST_ADDR+$4914
	move.w	#$8800,GAME_DEST_ADDR+$492e
	move.w	#$8802,GAME_DEST_ADDR+$4932
	move.w	#$8800,GAME_DEST_ADDR+$4938
	move.w	#$8802,GAME_DEST_ADDR+$493c

	;
	; Install the block of resident code providing optimized
	; rasters support (for the high score screen) in high
	; memory in the [$80000-$84800] area.
	; See rasters_start for implementation and detailed
	; explanations.
	;
inst_rasters
	; Skip installation on 512KB machines.
	cmpi.l	#$80000,TPA.w
	bls.s	inst_timer50hz

	; Copy the corresponding code in high memory.
	lea	rasters_start(pc),a0
	lea	RASTERS_RESID_ADDR,a1
	move.w	#RASTERS_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	; Enable the optimized rasters support, ie ensure that it
	; is taken into account when the high score program file is
	; loaded and patched on-the-fly.
	; To that end, update the array of tables of modifications
	; as described in section "12. Game files unpacking support".
	; See the fixes_tbl array for detailed comments.
	lea	fixes_ent_rasters(pc),a0
	move.l	#RASTERS_TBL_OFF+RASTERS_RESID_ADDR,(a0)

	;
	; Install the block of resident code allowing the musics
	; to be played at 50Hz, and the game frame rate to run
	; at the correct speed, on 60Hz monitors.
	; This feature is used on TT and Falcon/CT60 machines that
	; are connected to a VGA monitor and on legacy machines
	; connected to a 60Hz monitor.
	; It is installed in high memory in the [$80000-$84800]
	; area.
	; See timer50hz_start for implementation and detailed
	; explanations.
	;
inst_timer50hz
	; Skip installation on 512KB machines.
	cmpi.l	#$80000,TPA.w
	bls.s	inst_movep_emul

	ifeq	FORCE_TIMER50HZ

	; Perform installation on machines with a 60Hz video setup.
	btst	#MCH_VIDEO_60HZ_BIT,d7
	beq.s	inst_movep_emul

	endc	; FORCE_TIMER50HZ

	; Copy the routines in high memory.
	lea	timer50hz_start(pc),a0
	lea	TIMER50HZ_RESID_ADDR,a1
	move.w	#TIMER50HZ_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	; Hook into the initialization code of the game modules
	; (level, room, passage) to enable improved frame rate
	; control.
	; See timer50hz_frame_setup() for details.
	move.l	#$4e714eb9,GAME_DEST_ADDR+$643e
	move.l	#TIMER50HZ_FRAME_SETUP_OFF+TIMER50HZ_RESID_ADDR,GAME_DEST_ADDR+$6442

	; Hook into the original frame rate control routine to
	; call the improved version instead.
	; See timer50hz_frame_wait() for details.
	move.w	#$4ef9,GAME_DEST_ADDR+$5aa2
	move.l	#TIMER50HZ_FRAME_WAIT_OFF+TIMER50HZ_RESID_ADDR,GAME_DEST_ADDR+$5aa4

	; Controlling the music playback frequency depends on the
	; use of improved PSG routines (see timer50hz_mus_setup()
	; for details).
	; So the former is enabled only if the latter is in use.
	tst.l	PSG_FIX_RESID_PTR.w
	beq.s	inst_movep_emul

	; Enable the control of the music playback frequency, ie
	; ensure that it is taken into account when game files are
	; patched on-the-fly.
	; To that end, update the array of tables of modifications
	; as described in section "12. Game files unpacking support".
	; See the fixes_tbl array for detailed comments.
	lea	fixes_ent_timer50hz(pc),a0
	move.l	#TIMER50HZ_TBL_OFF+TIMER50HZ_RESID_ADDR,(a0)

	;
	; Install the exception handler that emulates the 'movep'
	; instruction on 68060 CPUs (CT60).
	; It is installed in high memory in the [$80000-$84800]
	; area.
	; See movep_emul() for implementation and detailed
	; explanations.
	;
inst_movep_emul
	; Skip installation on ST/STe/MegaSTe machines.
	cmpi.b	#MCH_MEGASTE,d7
	bls.s	inst_movep_patch1
	; It is assumed that the Falcon/TT machines have at least
	; 1MB of RAM, which was verified by sanity_checks().

	lea	movep_emul(pc),a0
	lea	MOVEP_EMUL_RESID_ADDR,a1
	move.l	a1,$f4.w
	move.w	#MOVEP_EMUL_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	;
	; On 68060 CPUs (CT60), replace 3 routines that use the 'movep'
	; instruction extensively with new routines that do not use
	; this instruction so as not to degrade graphical performances
	; with the emulation of the 'movep' instruction.
	; See movep_patch1() and movep_patch3().
	;
inst_movep_patch1
	; Install the routines on CT60 only.
	ifeq	FORCE_MOVEP_PATCH
	btst	#MCH_CT60_BIT,d7
	beq.s	inst_crash_handlers
	endc

	lea	movep_patch1(pc),a0
	lea	GAME_DEST_ADDR+MOVEP_PATCH1_DEST_OFF,a1
	move.w	#MOVEP_PATCH1_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

inst_movep_patch2
	lea	movep_patch2(pc),a0
	lea	GAME_DEST_ADDR+MOVEP_PATCH2_DEST_OFF,a1
	move.w	#MOVEP_PATCH2_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

inst_movep_patch3
	lea	movep_patch3(pc),a0
	lea	GAME_DEST_ADDR+MOVEP_PATCH3_DEST_OFF,a1
	move.w	#MOVEP_PATCH3_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	;
	; Install the crash handlers in high memory in the
	; [$80000-$84800] area.
	; The crash handlers are used to catch CPU exceptions
	; (due to a fault/crash) in order to print useful debug
	; information.
	; On 512KB machines, these handlers are not available.
	;
inst_crash_handlers
	ifne	USE_CRASH_HANDLERS

	; Skip installation on 512KB machines.
	cmpi.l	#$80000,TPA.w
	bls.s	inst_overscan_fix

	; Copy the crash handlers code in high memory.
	lea	crash_handlers_start(pc),a0
	lea	CRASH_HANDLERS_RESID_ADDR,a1
	movea.l	a1,a2
	move.w	#CRASH_HANDLERS_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	; Make the exception vectors point to the crash handlers.
	moveq.l	#0,d0
	moveq.l	#0,d1
.inst	move.b	(a2)+,d0
	beq.s	inst_overscan_fix
	move.b	(a2)+,d1
	movea.w	0(a2,d0.w),a0
	move.l	a2,(a0)
	adda.l	d1,a2
	bra.s	.inst

	endc	; USE_CRASH_HANDLERS

	;
	; Install the table of modifications that fixes the
	; opening of the low border, in order to:
	; - Prevent a crash on fast machines (16MHz MegaSTe,
	;   Falcon, TT, CT60).
	; - Support legacy machines with a 60Hz monitor.
	; It is installed in low memory in the [$1c0-$800] area.
	; See overscan_fix_tbl for implementation and detailed
	; explanations.
inst_overscan_fix
	ifeq	FORCE_OVERSCAN_FIX

	; Keep low border overscan on legacy ST(e) machines with a
	; 50Hz video setup. Disable it on other machines.
	btst	#MCH_VIDEO_60HZ_BIT,d7
	bne.s	.stop           ; 60Hz monitor
	cmpi.b	#MCH_MEGASTE,d7
	bhi.s	.stop           ; Falcon/TT
	blo.s	inst_trainer    ; 8MHz ST/STe
	btst	#MCH_MSTE_16MHZ_BIT,d7
	beq.s	inst_trainer    ; 8MHz MegaSTe

	; Switch between 8MHz & 16MHz on 16MHz MegaSTe (50Hz video).
	lea	overscan_fix_mste_tbl(pc),a0
	move.w	#OVERSCAN_FIX_MSTE_TBL_LEN/2-1,d0
	bra.s	.dst

	endc	; FORCE_OVERSCAN_FIX

	; Overscan is supported on legacy machines with a 50Hz frame
	; rate only. Disable the overscan on all other machines.
.stop	lea	overscan_fix_stop_tbl(pc),a0
	move.w	#OVERSCAN_FIX_STOP_TBL_LEN/2-1,d0

	; Install the table in low memory.
.dst	lea	OVERSCAN_FIX_TBL_ADDR.w,a1
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	; Ensure the "overscan fix" table is taken into account
	; when game files are patched on-the-fly.
	; To that end, update the array of tables of modifications
	; as described in section "12. Game files unpacking support".
	; See the fixes_tbl array for detailed comments.
	lea	fixes_ent_overscan(pc),a0
	move.l	#OVERSCAN_FIX_TBL_ADDR,(a0)

	; Prevent the main game program from modifying the sync
	; mode register ($ff820a) in order not to corrupt the current
	; video settings.
	move.w	#$6004,GAME_DEST_ADDR+$3fb2

	;
	; Patch the main program to enable the trainer mode,
	; and install the resident code needed for some trainer
	; options.
	;
	; The resident code is composed of 4 parts:
	; 1) A table describing the modifications to be applied
	;    to game programs $04, $54 and $55 in order to enable
	;    some trainer features.
	;    See tr_tbl.
	; 2) The code that handles keys pressed during game
	;    execution.
	;    See tr_keys().
	; 3) The code that implements the 'fall into the sky'
	;    trainer option.
	;    See tr_neverfall()
	; 4) The code that implements the infinite energy,
	;    infinite money and max firepower options.
	;    See tr_force()
	;
	; Parts 1 and 2 are installed in low memory in the
	; [$1c0-$800] area.
	; Part 3 is copied into the main game program in place
	; of checksum routine #10.
	; Part 4 is copied into the main game program in place
	; of checksum routine #7.
	;
inst_trainer
	; a0 points to the trainer mode configuration.
	; It is implemented as an array of bytes, each entry
	; describing a particular option: 0 if it is enabled,
	; non-zero otherwise.
	lea	tr_info(pc),a0

.lives	tst.b	(a0)            ; trainer: lives
	beq.s	.nrg
	; Patch the main program: do not decrement lives.
	move.w	#$4e75,GAME_DEST_ADDR+$6694

.nrg	tst.b	1(a0)           ; trainer: energy
	beq.s	.time
	; Patch the tr_force() routine: enable infinite energy.
	lea	tr_nrg(pc),a1
	move.w	#$4e71,(a1)

.time	tst.b	2(a0)           ; trainer: time
	beq.s	.money
	; Patch the main program: do not decrement time.
	move.l	#$4e714e71,GAME_DEST_ADDR+$d562

.money	tst.b	3(a0)           ; trainer: money
	beq.s	.fpower
	; Patch the tr_force() routine: enable infinite money.
	lea	tr_money(pc),a1
	move.w	#$4e71,(a1)

.fpower	tst.b	5(a0)           ; trainer: firepower
	beq.s	.nofall
	; Patch the tr_force() routine: enable max firepower.
	lea	tr_fpower(pc),a1
	move.w	#$4e71,(a1)

.nofall	tst.b	6(a0)           ; trainer: fall into the sky
	beq.s	.brick
	; Hook into the code that handles the movements of the
	; hero to call the tr_neverfall() routine.
	move.w	#$6100,GAME_DEST_ADDR+$69e6
	move.w	#TR_NEVERFALL_DEST_OFF-$69e8,GAME_DEST_ADDR+$69e8

.brick	tst.b	10(a0)          ; trainer: brick lives
	beq.s	.level
	; Patch the table of modifications (tr_tbl) to enable
	; infinite brick lives.
	lea	tr_brick_lives(pc),a1
	move.w	#$6004,4(a1)

.level	moveq.l	#0,d0
	move.b	13(a0),d0       ; trainer: level
	beq.s	.savlev
	; Patch the table of modifications (tr_tbl) to select
	; the starting level.
	subq.b	#1,d0
	ror.l	#8,d0
	ori.l	#$00020003,d0
.savlev	lea	tr_level(pc),a1
	move.l	d0,4(a1)

	; Copy parts 1 & 2 (table of modifications, and support
	; of keys pressed during the game) in low memory in the
	; [$1c0-$800] area.
	lea	tr_resid_start(pc),a0
	lea	TRAINER_RESID_ADDR.w,a1
	move.w	#TR_RESID_LEN/2-1,d0
.cp1	move.w	(a0)+,(a1)+
	dbf	d0,.cp1

	; Hook into the original key handling code to call the
	; tr_keys() routine.
	move.l	#$4eb80000+TRAINER_RESID_ADDR+TR_KEYS_OFF,GAME_DEST_ADDR+$6126

	; Copy part 3 (the 'fall into the sky' option) into the
	; main game program in place of checksum routine #10.
	lea	tr_neverfall(pc),a0
	lea	GAME_DEST_ADDR+TR_NEVERFALL_DEST_OFF,a1
	move.w	#TR_NEVERFALL_LEN/2-1,d0
.cp2	move.w	(a0)+,(a1)+
	dbf	d0,.cp2

	; Copy part 4 (infinite energy, infinite money and max
	; firepower options) into the main game program in place
	; of checksum routine #7.
	lea	tr_force(pc),a0
	lea	GAME_DEST_ADDR+TR_FORCE_DEST_OFF,a1
	move.w	#TR_FORCE_LEN/2-1,d0
.cp3	move.w	(a0)+,(a1)+
	dbf	d0,.cp3

	; Hook into the code that updates the game status bar
	; to call the tr_force() routine.
	move.w	#$6100,GAME_DEST_ADDR+$d440
	move.w	#TR_FORCE_DEST_OFF-$d442,GAME_DEST_ADDR+$d442

	;
	; Install the 'depack' code block containing the routines
	; in charge of unpacking game files and patching them to
	; enable game improvements.
	; It is installed in low memory in the [$1c0-$800]
	; area.
	; See depack_start for implementation and detailed
	; explanations.
	;
inst_depack
	lea	depack_start(pc),a0
	lea	DEPACK_ADDR.w,a1
	move.w	#DEPACK_LEN/2-1,d0
.cp	move.w	(a0)+,(a1)+
	dbf	d0,.cp

	; End of game_patch(), return to the caller.
	movem.l	(a7)+,d0-d1/d7/a0-a2
	rts

	;
	; screen_off()
	;
	; Improved "blank screen" routine.
	;
	; At the end of every game subprogram, a special
	; routine is executed to set all colors to black.
	; This routine, located in the main game program,
	; is replaced by the following improved version
	; in order to perform additional cleanup tasks:
	; - Disable all MFP interrupts and install dummy
	;   interrupt handlers.
	; - set all colors to black.
	; - turn the sound off.
	; - flush the ACIA/IKBD.
	;
	; This code is copied by the game_patch() routine into a
	; free area of the main game program (replacing checksum
	; routine #11).
	;
screen_off
	movem.l	d0/a0-a1,-(a7)
	; Call vectors_off() to disable MFP interrupts and install
	; dummy interrupt handlers.
	dc.w	$6100
.here1	dc.w	screen_off-.here1+VECTORS_OFF_DEST_OFF-SCREEN_OFF_DEST_OFF
	; Set all colors to black.
	movea.w	#$8240,a0
	moveq.l	#7,d0
.lp	clr.l	(a0)+
	dbf	d0,.lp
	; Call a routine in the main game program that
	; clears sound registers.
	dc.w	$6100
.here2	dc.w	screen_off-.here2+$5162-SCREEN_OFF_DEST_OFF
	; Flush IKBD/ACIA.
	movea.l	KEYB_FIX_RESID_PTR.w,a0
	jsr	KEYB_RESET_OFF(a0)
	movem.l	(a7)+,d0/a0-a1
	rts
screen_off_end

	;
	; vectors_off()
	;
	; Disable all MFP interrupts and install dummy
	; interrupt handlers.
	; It is called by screen_off().
	;
	; Scratch: a0
	;
	; This code is copied by the game_patch() routine into a
	; free area of the main game program (replacing checksum
	; routine #9).
	;
vectors_off
	clr.b	$fffffa07.w
	clr.b	$fffffa09.w
	lea	$74.w,a0
	move.w	#$4e73,(a0)
	move.l	a0,$68.w
	move.l	a0,$70.w
	move.l	a0,$114.w
	move.l	a0,$120.w
	move.l	a0,$134.w
	rts
vectors_off_end

	;
	; Information for the installation of the two previous
	; routines: lengths of the routines & destination offsets
	; in the main game program.
	;
SCREEN_OFF_LEN             =	(screen_off_end-screen_off)
SCREEN_OFF_DEST_OFF        =	$6790
VECTORS_OFF_LEN            =	(vectors_off_end-vectors_off)
VECTORS_OFF_DEST_OFF       =	$613c

	;
	; copy_screen_fix()
	;
	; Fix a bug that occurs while drawing the scene (the
	; background) on fast machines.
	;
	; The routine that draws the scene works as follows:
	; - A first loop starts drawing the scene.
	; - The joystick1 report is polled during that loop.
	; - When the joystick1 report is received, control
	;   jumps to a second loop that finishes drawing
	;   the scene.
	;
	; There is an assumption about the timing of these
	; operations:
	; - the joystick1 report is expected to be received
	;   during the first loop, before the loop terminates,
	;   that is before the scene is completely drawn.
	; - The second loop expects the scene to be partially
	;   drawn, so it continues to draw the scene without
	;   checking whether it is already done.
	;
	; The bug occurs on fast machines when the joystick1
	; report is not received during the first loop (which
	; executes too quickly).
	; In that case, the scene is entirely drawn by the
	; first loop and, when done, the control flow continues
	; with the second loop which then draws garbage.
	;
	; The fix is to execute the following routine after
	; the first loop if the joystick1 report has not been
	; received yet.
	; This routine polls the joystick1 report until it is
	; received and returns to the caller, thus skipping
	; the second loop and avoiding drawing garbage.
	;
	; This code is copied by the game_patch() routine into a
	; free area of the main game program (replacing checksum
	; routine #4).
	; The scene drawing routine is hooked to jump into that
	; code.
	;
copy_screen_fix
	lea	$845.w,a6
	; 'JOYSTICK INTERROGATE' command sent to the IKBD?
	tst.b	(a6)+
	; No, don't poll joystick1 report.
	bne.s	.ret
	; Yes, wait for it.
	moveq.l	#0,d1
	move.b	(a6),d1
	; Do nothing if it has already been received.
	beq.s	.ret
	; Wait for the joystick1 report.
	; Execute a routine of the main game program that polls
	; the ACIA/IKBD and returns the received IKBD data.
.jwait	dc.w	$6100
.here	dc.w	copy_screen_fix-.here+$4586-COPY_SCREEN_FIX_DEST_OFF
	tst.b	-2(a6)
	; Joystick report header already received?
	bne.s	.jdata
	; No, has it just been received?
	cmpi.b	#$fd,d0
	bne.s	.jwait
	; Got the header, need to wait for the data now. 
	move.b	d0,-2(a6)
	bra.s	.next
	; Handle joystick 0 & 1 reports.
.jdata	move.b	d0,-6(a6,d1.w)
.next	subq.b	#1,d1
	bne.s	.jwait
	; Joystick1 report received, return to the caller
	; so that the second drawing loop is not executed.
	move.b	d1,(a6)
.ret	rts
copy_screen_fix_end

	;
	; Information for the installation of the previous
	; routine: routine length & destination offset in
	; the main game program.
	;
	; The distance between the drawing routine and the
	; previous routine is greater than $7fff bytes, but
	; the drawing routine can only be patched with a
	; 'bra.w' instruction.
	; Therefore a trampoline, containing an additional
	; branch instruction, is installed to connect both
	; routines. It is installed in place of checksum
	; routine #6.
	;
COPY_SCREEN_FIX_LEN        =	(copy_screen_fix_end-copy_screen_fix)
COPY_SCREEN_FIX_DEST_OFF   =	$6588
COPY_SCREEN_FIX_TRAMP_OFF  =	$cea2

	;
	; weapon_fire_fix()
	;
	; Fix an out-of-bounds array access when too many
	; projectiles appear on the screen at the same time.
	;
	; This bug occurs very rarely, probably only on slow
	; machines, and causes data corruption that results
	; in a fatal crash.
	;
	; This code is copied by the game_patch() routine into a
	; free area of the main game program (replacing checksum
	; routine #8).
	; The main game program is patched to jump into that code
	; to prevent the out-of-bounds array access.
	;
weapon_fire_fix
	; Debug only: select weapon 2 with max rate of fire.
	; It allows to reproduce the bug more easily.
	ifne	DEBUG_WEAPON_LIMITS
	move.w	#$0202,$2ce0.w
	move.w	#$1f1f,$2ce2.w
	endc
	; Check available slots in the projectiles array.
	cmpi.w	#$17-3,$2ce6.w
	bls.s	.ret
	; Prevent out-of-bounds array access by skipping the
	; caller code that accesses the array incorrectly.
	move.l	#GAME_DEST_ADDR+$69d6,(a7)
	; Execute the instruction which has been modified to
	; jump here.
.ret	move.w	$2ce4.w,d0
	rts
weapon_fire_fix_end

	;
	; Information for the installation of the previous
	; routine: routine length & destination offset in
	; the main game program.
	;
WEAPON_FIRE_FIX_LEN        =	(weapon_fire_fix_end-weapon_fire_fix)
WEAPON_FIRE_FIX_DEST_OFF   =	$5a32

	;
	; weapon_bonus_fix()
	;
	; Fix an out-of-bounds array access when 6 or more weapon
	; bonuses appear on the screen at the same time.
	;
	; This bug occurs very rarely, probably only on fast
	; machines, and causes data corruption that results
	; in a fatal crash.
	;
	; This code is copied by the game_patch() routine into a
	; free area of the main game program (replacing checksum
	; routine #5).
	; The main game program is patched to jump into that code
	; to prevent the out-of-bounds array access.
	;
weapon_bonus_fix
	; Number of weapon bonuses currently displayed.
	cmpi.w	#6,$2d36.w
	blo.s	.ret
	; Prevent out-of-bounds array access by skipping the
	; caller code that accesses the array incorrectly.
	move.l	#GAME_DEST_ADDR+$8834,(a7)
	; Execute the instruction which has been modified to
	; jump here.
.ret	move.w	$2d36.w,d5
	rts
weapon_bonus_fix_end

	;
	; Information for the installation of the previous
	; routine: routine length & destination offset in
	; the main game program.
	;
WEAPON_BONUS_FIX_LEN       =	(weapon_bonus_fix_end-weapon_bonus_fix)
WEAPON_BONUS_FIX_DEST_OFF  =	$c61a

	;
	; anims_underflow_fix()
	;
	; Prevents the number of enemy animations from becoming
	; negative.
	;
	; The game maintains a counter in $2d28 describing the total
	; number of animations to be displayed in the current scene,
	; corresponding to the different active enemies on the screen.
	; This counter is used as a number of states in the game's
	; state machine used to display enemy movements.
	;
	; A random bug (with a rare occurrence, occurring mainly at
	; the beginning of level 6) results in the counter becoming
	; negative. But this theoretically impossible negative value
	; is handled as a large positive number of animations.
	; This leads to incorrect or non-existent animations being
	; displayed. Most of the time this results in a game crash.
	;
	; This code is copied by the game_patch() routine into a
	; free area of the main game program (replacing checksum
	; routine #5, after the weapon_bonus_fix() routine).
	; The main game program is patched to jump into that code
	; to catch and fix the underflow error on-the-fly when it
	; occurs.
	;
anims_underflow_fix
	; Read the counter and check if it is negative.
	move.w	$2d28.w,d6
	bge.s	.ret
	; If it is negative, reset it to zero.
	clr.w	d6
	move.w	d6,$2d28.w
.ret	rts
anims_underflow_fix_end

	;
	; Information for the installation of the previous
	; routine: routine length & destination offset in
	; the main game program.
	;
ANIMS_UNDERFLOW_FIX_LEN      =	(anims_underflow_fix_end-anims_underflow_fix)
ANIMS_UNDERFLOW_FIX_DEST_OFF =	WEAPON_BONUS_FIX_DEST_OFF+WEAPON_BONUS_FIX_LEN

	;
	; movep_emul()
	;
	; Exception handler used to emulate the 'movep' instruction
	; on 68060 CPUs (CT60).
	;
	; On 68060 CPUs, the 'movep' instruction is not supported
	; and triggers the 'Unimplemented Integer Instruction'
	; exception (vector $f4).
	;
	; This handler catches such exception and emulates the
	; corresponding instruction.
	;
	; It is installed in a high memory area by the game_patch()
	; routine.
	;
	; Note:
	;   In the game, 3 graphics routines make extensive use
	;   of the movep instruction.
	;   These routines are performance-critical so movep
	;   emulation can have a visible impact on performance.
	;   These routines are located at $10636, $106b2 and
	;   $12972 in the main game program.
	;
	; Doc:
	; - http://goldencrystal.free.fr/M68kOpcodes-v2.3.pdf
	;
movep_emul
	movem.l	d0-d1/a0-a1,-(a7)

	; Get the 'movep' opcode.
	movea.l	4*4+2(a7),a0
	move.w	(a0),d0

	; Get the src or dst address from the appropriate
	; address register.
.dec_an	lsl.w	#2,d0
	andi.w	#%11100,d0
	jmp	.get_an(pc,d0.w)

.get_an	movea.l	4*2(a7),a1
	movea.l	a1,a1
	bra.s	.offset
	movea.l	a2,a1
	bra.s	.offset
	movea.l	a3,a1
	bra.s	.offset
	movea.l	a4,a1
	bra.s	.offset
	movea.l	a5,a1
	bra.s	.offset
	movea.l	a6,a1
	bra.s	.offset
	movea.l	a7,a1
	nop

	; Add the immediate offset to the src or dst address.
.offset	move.l	(a0),d0         ; d0.l = opcode/offset
       	adda.w	d0,a1           ; d0.w = offset

	; Get the 'movep' direction (read or write).
.dir   	swap	d0              ; d0.w = opcode
	btst	#7,d0
	beq.s	movep_mem2reg

	; Register to memory (write) case.
movep_reg2mem
	; Get the data to be written from the appropriate
	; data register.
.dec_dn	lsr.w	#9-2,d0
	andi.w	#%11100,d0
	jmp	.get_dn(pc,d0.w)

.get_dn	move.l	(a7),d1
	bra.s	.get_ct
	move.l	d1,d1
	bra.s	.get_ct
	move.l	d2,d1
	bra.s	.get_ct
	move.l	d3,d1
	bra.s	.get_ct
	move.l	d4,d1
	bra.s	.get_ct
	move.l	d5,d1
	bra.s	.get_ct
	move.l	d6,d1
	bra.s	.get_ct
	move.l	d7,d1
	nop
.get_ct
	; Atomically write the data to the expected address.
	ori.w	#$700,sr
	btst	#6,1(a0)
	bne.s	.long

	; Data is a word (2 bytes).
.word	rol.w	#8,d1
	move.b	d1,(a1)
	rol.w	#8,d1
	move.b	d1,2(a1)
	bra.s	movep_ret

	; Data is a long (4 bytes).
.long	rol.l	#8,d1
	move.b	d1,(a1)
	rol.l	#8,d1
	move.b	d1,2(a1)
	rol.l	#8,d1
	move.b	d1,4(a1)
	rol.l	#8,d1
	move.b	d1,6(a1)
	bra.s	movep_ret

	; Memory to register (read) case.
movep_mem2reg
	; Atomically read the data from the expected address.
	ori.w	#$700,sr
	btst	#6,d0
	bne.s	.long

	; Data is a word (2 bytes).
.word	move.b	(a1),d1
	rol.w	#8,d1
	move.b	2(a1),d1
	bra.s	.dec_dn

	; Data is a long (4 bytes).
.long	move.b	(a1),d1
	rol.l	#8,d1
	move.b	2(a1),d1
	rol.l	#8,d1
	move.b	4(a1),d1
	rol.l	#8,d1
	move.b	6(a1),d1

	; Place the data into the appropriate data register.
.dec_dn	lsr.w	#9-2,d0
	andi.w	#%11100,d0
	jmp	.put_dn(pc,d0.w)

.put_dn	move.l	d1,(a7)
	bra.s	.put_ct
	move.l	d1,d1
	bra.s	.put_ct
	move.l	d1,d2
	bra.s	.put_ct
	move.l	d1,d3
	bra.s	.put_ct
	move.l	d1,d4
	bra.s	.put_ct
	move.l	d1,d5
	bra.s	.put_ct
	move.l	d1,d6
	bra.s	.put_ct
	move.l	d1,d7
	nop
.put_ct
	; Emulation complete.
movep_ret
	movem.l	(a7)+,d0-d1/a0-a1
	; Return after the 'movep' instruction.
	addq.l	#4,2(a7)
	rte
movep_emul_end

	;
	; Length of the previous handler for installation
	; into a high memory area.
	;
MOVEP_EMUL_LEN             =	(movep_emul_end-movep_emul)

	;
	; movep_patch1()
	; movep_patch2()
	; movep_patch3()
	;
	; The main program of the game has 3 routines that use the
	; 'movep' instruction extensively for drawing pixels.
	;
	; The first two routines are used for drawing the fonts in
	; the status bar (score, time, lives, money).
	; The third routine is used when drawing the background scene.
	;
	; On 68060 CPUs, the 'movep' instruction is not implemented
	; and is therefore emulated (see movep_emul() above) with the
	; expected consequences on performance.
	;
	; To avoid this performance degradation due to emulation,
	; the 3 impacted routines are replaced with new routines that
	; do not use the 'movep' instruction.
	;
	; Even if the new routines are not optimal for a basic ST,
	; they are good enough for machines as fast as the CT60.
	;

	; Routine used for drawing the fonts in the status bar.
	; movep_patch1() and movep_patch2() are strictly identical.
movep_patch1
movep_patch2
	moveq.l	#6,d6
.lp	move.b	(a0),(a1)
	move.b	(a0)+,(a2)
	move.b	(a0),2(a1)
	move.b	(a0)+,2(a2)
	move.b	(a0),4(a1)
	move.b	(a0)+,4(a2)
	move.b	(a0),6(a1)
	move.b	(a0)+,6(a2)
	lea	160(a1),a1
	lea	160(a2),a2
	dbf	d6,.lp
	lea	-(160*7)(a1),a1
	lea	-(160*7)(a2),a2
	dc.w	$6000
.here	dc.w	($d69e-$d658)-(.here-movep_patch1)
movep_patch1_end

	; Routine used for drawing the background scene.
movep_patch3
	moveq.l	#15,d6
.lp	move.b	1(a0),(a1)+
	move.b	(a4),(a1)+
	move.b	3(a0),(a1)+
	move.b	2(a4),(a1)+
	move.b	5(a0),(a1)+
	move.b	4(a4),(a1)+
	move.b	7(a0),(a1)+
	move.b	6(a4),(a1)+
	addq.l	#8,a0
	addq.l	#8,a4
	lea	160-8(a1),a1
	dbf	d6,.lp
	dc.w	$6000
.here	dc.w	($faa4-$f9a2)-(.here-movep_patch3)
movep_patch3_end

	;
	; Information for the installation of the 3 previous
	; routines: length of the routines & destination offsets
	; in the main game program.
	;

MOVEP_PATCH1_LEN           =	(movep_patch1_end-movep_patch1)
MOVEP_PATCH1_DEST_OFF      = 	$d658

MOVEP_PATCH2_LEN           =	MOVEP_PATCH1_LEN
MOVEP_PATCH2_DEST_OFF      = 	$d6c8

MOVEP_PATCH3_LEN           =	(movep_patch3_end-movep_patch3)
MOVEP_PATCH3_DEST_OFF      = 	$f9a2

	ifne	USE_CRASH_HANDLERS

	;
	; The following code provides crash handlers.
	;
	; If a CPU exception is triggered during the game because
	; of a bug, the corresponding exception handler is invoked
	; to print useful information about the crash.
	;
crash_handlers_start

	;
	; Exception stack address.
	;
CRASH_STACK     =	$80000

	;
	; Exception entry stub.
	;
	; Mask all interrupts, save the exception vector address in
	; a6 (which is saved in USP) and jump to the common code.
EX_STUB	macro
	; Offset in this stub to the exception vector address.
	dc.b	\@_x+2-\@_s
	; Offset to the end of the stub.
	dc.b	\@_e-\@_s
\@_s	move.w	#$2700,sr
	move	a6,USP
\@_x	movea.w	#\1,a6
	bra.w	crash_handlers_common
\@_e
	endm

	;
	; Declare the CPU exceptions that are caught.
	;
	EX_STUB	$8              ; Bus error
	EX_STUB	$c              ; Address error
	EX_STUB	$10             ; Illegal instruction
	EX_STUB	$14             ; Divide by zero
	EX_STUB	$18             ; CHK, CHK2 instruction
	EX_STUB	$1c             ; TRAPcc, TRAPV instructions
	EX_STUB	$20             ; Privilege violation
	EX_STUB	$28             ; Line-A
	EX_STUB	$2c             ; Line-F
	EX_STUB	$30             ; Emulator interrupt
	EX_STUB	$34             ; Copro protocol violation
	EX_STUB	$38             ; Format error
	EX_STUB	$3c             ; Uninitialized interrupt
	EX_STUB	$e0             ; MMU config error
	EX_STUB	$e4             ; MC68851, not used by MC68030
	EX_STUB	$e8             ; MC68851, not used by MC68030
	EX_STUB	$f0             ; Unimplemented effective addr
	dc.w	0

	;
	; Common exception handling code.
	; Print useful information about the exception.
	;
crash_handlers_common
	; Save the exception context onto the exception stack.
	move.l	a7,CRASH_STACK-6
	lea	CRASH_STACK-6,a7
	move.w	a6,4(a7)
	move	USP,a6
	movem.l	d0-a6,-(a7)

	; Set all colors to black.
	moveq.l	#7,d0
	lea	$ffff8240.w,a0
.black	clr.l	(a0)+
	dbf	d0,.black

	; Tell the PSG to shut up.
	lea	$ffff8800.w,a0
	move.b	#$08,(a0)
	clr.b	2(a0)
	move.b	#$09,(a0)
	clr.b	2(a0)
	move.b	#$0a,(a0)
	clr.b	2(a0)

	; Get the current screen address.
	moveq.l	#0,d0
	move.b	$ffff8201.w,d0
	swap	d0
	move.b	$ffff8203.w,d0
	lsl.w	#8,d0
	movea.l	d0,a6

	; Clear the screen.
	movea.l	a6,a0
	move.w	#(160*200)/4-1,d0
.cls	clr.l	(a0)+
	dbf	d0,.cls

	; Set the font color to white.
	move.w	#$fff,$ffff8242.w

	; The main program of the game provides 1-plane 8x8 pixels
	; fonts at address $7024.
	lea	$7024.w,a5

	; These 3 "global" regs handle the current text position
	; (offset) on the screen.
	moveq.l	#0,d5           ; Pos of the current line
	moveq.l	#0,d6           ; Position on the screen
	moveq.l	#1,d7           ; Offset to next char

	; Reserve space in the stack for local variables.
	subq.l	#8,a7
	movea.l	a7,a0

	; Print the exception vector address.
	move.l	#'EX: ',(a0)
	lea	8+16*4(a7),a1
	move.w	#$4413,d0
	bsr	print_cap_hex

	; Print the status register.
	move.l	#'SR: ',(a0)
	movea.l	8+15*4(a7),a1
	move.w	#$4413,d0
	bsr	print_cap_hex

	; Print the faulting PC.
	move.l	#'PC: ',(a0)
	movea.l	8+15*4(a7),a1
	addq.l	#2,a1
	move.w	#$0813,d0
	bsr	print_cap_hex

	moveq.l	#2,d0
	bsr	print_cr

	; Print data and address registers.
	move.l	#' 0: ',(a0)
	lea	8(a7),a2
	moveq.l	#7,d1
.dxax	move.b	#'D',(a0)
	movea.l	a2,a1
	move.w	#$4813,d0
	bsr	print_cap_hex
	move.b	#'A',(a0)
	lea	8*4(a2),a1
	move.w	#$0813,d0
	bsr	print_cap_hex
	moveq.l	#1,d0
	bsr	print_cr
	addq.l	#4,a2
	addq.b	#1,1(a7)
	dbf	d1,.dxax

	moveq.l	#1,d0
	bsr	print_cr

	; Dump the program stack.

	move.b	#$1b,(a0)       ; '['
	moveq.l	#1,d0
	bsr	print_ascii
	move.l	8+15*4(a7),d0
	subi.l	#4*4+2,d0
	andi.b	#-2,d0
	movea.l	d0,a1
	move.l	d0,(a0)
	moveq.l	#8,d0
	bsr	print_hex
	move.w	#$1d3a,(a0)     ; ']:'
	moveq.l	#2,d0
	bsr	print_ascii

	moveq.l	#1,d0
	bsr	print_cr

	movea.l	a1,a0
	moveq.l	#8,d1
.stackl	moveq.l	#3,d2
.stackc	moveq.l	#8,d0
	bsr	print_hex
	moveq.l	#2,d0
	bsr	print_space
	addq.l	#4,a0
	dbf	d2,.stackc
	moveq.l	#1,d0
	bsr	print_cr
	dbf	d1,.stackl

	moveq.l	#1,d0
	bsr	print_cr

	movea.l	a7,a0

	; Print the HBL handler address.
	move.l	#'068:',(a0)
	lea	$68.w,a1
	move.w	#$4814,d0
	bsr.s	print_cap_hex

	; Print the VBL handler address.
	move.l	#'070:',(a0)
	lea	$70.w,a1
	move.w	#$4814,d0
	bsr.s	print_cap_hex

	moveq.l	#1,d0
	bsr	print_cr

	; Print the Timer-C (50Hz) handler address.
	move.l	#'114:',(a0)
	lea	$114.w,a1
	move.w	#$4814,d0
	bsr.s	print_cap_hex

	; Print the ACIA (IKBD) handler address.
	move.l	#'118:',(a0)
	lea	$118.w,a1
	move.w	#$4814,d0
	bsr.s	print_cap_hex

	moveq.l	#1,d0
	bsr.s	print_cr

	; Print the Timer-B (HBL) handler address.
	move.l	#'120:',(a0)
	lea	$120.w,a1
	move.w	#$4814,d0
	bsr.s	print_cap_hex

	; Print the Timer-A (sound) handler address.
	move.l	#'134:',(a0)
	lea	$134.w,a1
	move.w	#$4814,d0
	bsr.s	print_cap_hex

	moveq.l	#1,d0
	bsr.s	print_cr

	; Halt the CPU.
	addq.l	#8,a7
.dead	bra.s	.dead

	;
	; print_cap_hex()
	;
	; Print an hexadecimal value with a caption.
	;
	; In:
	;   a0: points to the caption (ASCII characters)
	;   a1: points to the hexadecimal value
	;   a5: points to the fonts
	;   a6: screen address
	;   d0: provides 4 nibbles 'dcba' where
	;       'a' is the number of ASCII chars in the caption
	;       'b' is the number of spaces after the caption
	;       'c' is the number of nibbles in the hex value
	;       'd' is the number of spaces after the hex value
	;   d6-d7: current text position on the screen
	;
	; Out:
	;   d6-d7: updated text position on the screen
	;
print_cap_hex
	movem.l	d0-d1/a0-a1,-(a7)

	move.w	d0,d1
	andi.l	#$f,d0          ; Caption
	bsr.s	print_ascii
	lsr.w	#4,d1
	move.w	d1,d0
	andi.w	#$f,d0          ; Spaces
	bsr.s	print_space
	lsr.w	#4,d1
	move.w	d1,d0
	andi.w	#$f,d0          ; Hex value
	movea.l	a1,a0
	bsr.s	print_hex
	lsr.w	#4,d1
	move.w	d1,d0
	andi.w	#$f,d0          ; Spaces
	bsr.s	print_space

	movem.l	(a7)+,d0-d1/a0-a1
	rts

	;
	; print_cr()
	;
	; Carriage return + line feed.
	;
	; In:
	;   d0: number of CRLF (text lines to skip)
	;   d5: position (offset) of the current text line
	;   d6-d7: current text position (offset) on the screen
	;
	; Out:
	;   d5-d7: updated text position on the screen
	;
	; Scratch: d0
	;
print_cr
	move.l	d5,d6
	mulu.w	#160*8,d0       ; 1 text line = 8 pixel lines
	add.w	d0,d6
	move.l	d6,d5
	moveq.l	#1,d7
	rts

	;
	; print_space()
	;
	; Print spaces.
	;
	; In:
	;   d0: number of spaces to print
	;   d6-d7: current text position on the screen
	;
	; Out:
	;   d6-d7: updated text position on the screen
	;
	; Scratch: d0
	;
print_space
	subq.w	#1,d0
	bmi.s	.ret
.nxt	add.w	d7,d6
	eori.b	#6,d7
	dbf	d0,.nxt
.ret	rts

	;
	; print_ascii()
	;
	; Print an ASCII string.
	;
	; In:
	;   a0: points to the ASCII string
	;   a5: points to the fonts
	;   a6: screen address
	;   d0: number of characters in the string
	;   d6-d7: current text position on the screen
	;
	; Out:
	;   d6-d7: updated text position on the screen
	;
print_ascii
	movem.l	d0/d5/a0-a2,-(a7)

	subq.w	#1,d0
.nxt	moveq.l	#0,d5
	move.b	(a0)+,d5
	subi.b	#$1b,d5
	lsl.w	#3,d5
	lea	0(a5,d5.w),a1
	lea	0(a6,d6.w),a2
	move.b	(a1)+,(a2)
	move.b	(a1)+,160*1(a2)
	move.b	(a1)+,160*2(a2)
	move.b	(a1)+,160*3(a2)
	move.b	(a1)+,160*4(a2)
	move.b	(a1)+,160*5(a2)
	move.b	(a1)+,160*6(a2)
	move.b	(a1)+,160*7(a2)
	add.w	d7,d6
	eori.b	#6,d7
	dbf	d0,.nxt

	movem.l	(a7)+,d0/d5/a0-a2
	rts

	;
	; print_hex()
	;
	; Print an hexadecimal value.
	;
	; In:
	;   a0: points to the hex value
	;   a5: points to the fonts
	;   a6: screen address
	;   d0: number of nibbles in the hex value
	;   d6-d7: current text position on the screen
	;
	; Out:
	;   d6-d7: updated text position on the screen
	;
print_hex
	movem.l	d0-d3/a0-a1,-(a7)
	lea	-40(a7),a7

	subq.w	#1,d0
	moveq.l	#4,d1
	moveq.l	#0,d2
	moveq.l	#0,d3
	movea.l	a7,a1

	; Convert the hex value to an ASCII string.
.nxt	move.b	(a0),d3
	lsr.b	d1,d3
	andi.b	#$f,d3
	cmpi.b	#$9,d3
	bls.s	.num
	addq.b	#'A'-'0'-$A,d3
.num	addi.b	#'0',d3
	move.b	d3,(a1)+

	adda.l	d2,a0
	eori.b	#4,d1
	eori.b	#1,d2
	dbf	d0,.nxt

	; Print the string.
	movea.l	a7,a0
	move.l	40(a7),d0
	bsr	print_ascii

	lea	40(a7),a7
	movem.l	(a7)+,d0-d3/a0-a1
	rts

	;
	; End of the block of resident code providing the
	; crash handlers.
	;
crash_handlers_end

	;
	; Length of the previous crash handlers code for
	; installation into a high memory area.
	;
CRASH_HANDLERS_LEN          =	(crash_handlers_end-crash_handlers_start)

	elseif	; USE_CRASH_HANDLERS

	; If the crash handlers are not used.
CRASH_HANDLERS_LEN          =	0

	endc	; USE_CRASH_HANDLERS

	;
	; overscan_fix_stop_tbl
	; overscan_fix_mste_tbl
	;
	; Tables describing the modifications to apply to programs
	; that open the low border so that:
	; - They don't crash on fast machines.
	; - They don't corrupt the current video settings on modern
	;   machines (Falcon/TT).
	; - They don't modify the video sync frequency on legacy
	;   machines with a 60Hz monitor.
	;
	; Low border overscan is only supported on legacy ST/STe
	; machines running at 8MHz with a 50Hz monitor: the routines
	; used in the game to open the low border are based on a jump
	; table indexed by the video counter.
	; On Machines running at a different speed than a mere ST or
	; with a 60Hz monitor, the jump table may result in a wrong
	; jump to unexpected code and possibly to a crash.
	; Therefore, on these machines (16MHz MegaSTe, TT, Falcon,
	; CT60, 60Hz monitor) the following workaround is used:
	; - On TT, Falcon/CT60 and legacy machines with a 60Hz monitor,
	;   all programs that open the low border are patched to disable
	;   the overscan code.
	;   This is achieved by installing the overscan_fix_stop_tbl
	;   table.
	;   In addition, programs that "touch" the video sync mode
	;   register ($ff820a) are also patched on these machines so
	;   that this register is no longer modified. This is needed
	;   in order not to corrupt the current video settings.
	; - On 16MHz MegaSTe, the CPU freq is adapted dynamically:
	;   it is lowered to 8MHz (without cache) before executing
	;   the programs that open the low border and then it is
	;   raised back to 16MHz (with cache enabled) when these
	;   programs are finished.
	;   This is achieved by installing the overscan_fix_mste_tbl
	;   table.
	;
	; The following files are impacted:
	; - file $06: intro screen
	; - file $09: level presentation screen
	; - file $0a: level map screen
	; - file $25: game over screen
	; - file $26: high score screen
	; - file $55: brick game program
	; - file $89: game finale program
	;
	; These files are modified during the game after they are
	; loaded & unpacked, according to the information provided
	; in the selected table.
	;
	; The appropriate table is selected depending on the machine
	; type and installed in a low memory area by the game_patch()
	; routine.
	;
	; See also the depack() and apply_fixes() routines.
	;

	;
	; overscan_fix_stop_tbl
	;
	; Disable overscan and video sync mode register usage
	; on Falcon, TT, CT60 and legacy machines with a 60Hz
	; monitor.
	;
overscan_fix_stop_tbl
	; File $06: intro screen.
	dc.w	$0604,$10be,$6000,$00a4         ; overscan

	; File $09: level presentation screen.
	dc.w	$0904,$0e5e,$6000,$00a4         ; overscan
	dc.w	$0902,$0030,$6004               ; sync reg

	; File $0a: level map screen.
	dc.w	$0a04,$055c,$6000,$00a4         ; overscan
	dc.w	$0a02,$0030,$6004               ; sync reg

	; File $25: game over screen.
	dc.w	$2504,$0f44,$6000,$00a4         ; overscan
	dc.w	$2502,$002a,$6004               ; sync reg

	; File $26: high score screen.
	dc.w	$2602,$0076,$6004               ; sync reg

	; File $55: brick game program.
	dc.w	$5502,$003c,$6004               ; sync reg

	; File $89: game finale program.
	dc.w	$8902,$003c,$6004               ; sync reg

	; End of the modifications.
	dc.w	0
overscan_fix_stop_tbl_end

	;
	; overscan_fix_mste_tbl
	;
	; Allow overscan on 16MHz MegaSTe: switch the CPU frequency
	; to 8MHz (without cache) when needed to make the overscan
	; code happy. Switch back to 16MHz (with cache) when no
	; overscan technique is used.
	; Note that changing the CPU/cache config has immediate
	; effect (as soon as the corresponding I/O register has
	; been updated).
	;
overscan_fix_mste_tbl
	; File $06: intro screen.
	dc.w	$0604,$0004
	clr.b	$ffff8e21.w                     ; 8MHz
	dc.w	$0602,$0028
	nop
	dc.w	$060a,$009c
	move.w	#$2700,sr
	move.b	#$ff,$ffff8e21.w                ; 16MHz + cache
	dc.w	$0604,$00ba
	clr.b	$fffffa1f.w

	; File $09: level presentation screen.
	dc.w	$0906,$0030
	clr.b	$ffff8e21.w                     ; 8MHz
	nop
	dc.w	$0902,$010e
	rts
	dc.w	$0904,$011c
	move.b	#$ff,d0
	dc.w	$0904,$012c
	move.b	d0,$ffff8e21.w                  ; 16MHz + cache

	; File $0a: level map screen.
	dc.w	$0a06,$0030
	clr.b	$ffff8e21.w                     ; 8MHz
	nop
	dc.w	$0a02,$00ec
	rts
	dc.w	$0a04,$00fe
	move.b	#$ff,d0
	dc.w	$0a04,$010e
	move.b	d0,$ffff8e21.w                  ; 16MHz + cache

	; File $25: game over screen.
	dc.w	$2506,$002a
	clr.b	$ffff8e21.w                     ; 8MHz
	nop
	dc.w	$2506,$011a
	move.b	#$ff,$ffff8e21.w                ; 16MHz + cache

	; End of the modifications.
	dc.w	0
overscan_fix_mste_tbl_end

	;
	; Lengths of the previous tables for installation
	; into a low memory area.
	;
OVERSCAN_FIX_STOP_TBL_LEN  =	(overscan_fix_stop_tbl_end-overscan_fix_stop_tbl)
OVERSCAN_FIX_MSTE_TBL_LEN  =	(overscan_fix_mste_tbl_end-overscan_fix_mste_tbl)

	;
	; Take the biggest length.
	;
	ifgt	(OVERSCAN_FIX_STOP_TBL_LEN-OVERSCAN_FIX_MSTE_TBL_LEN)
OVERSCAN_FIX_TBL_LEN       = OVERSCAN_FIX_STOP_TBL_LEN
	elseif
OVERSCAN_FIX_TBL_LEN       = OVERSCAN_FIX_MSTE_TBL_LEN	
	endc

	;
	; Start of the block of resident code providing improved
	; ACIA/IKBD routines (keyboard/joystick).
	;
	; This block of code is installed either into a low
	; memory area or into a high memory area (depending on
	; the available RAM) by the game_patch() routine.
	;
	; The original ACIA/IKBD routines use a special polling
	; mechanism to get ACIA/IKBD data, leading to miss some
	; of them randomly:
	; - The joystick is interrogated once per VBL:
	;   a 'JOYSTICK INTERROGATE' command is sent to the IKBD
	;   from the VBL routine while the corresponding joystick
	;   report is polled from the HBL handler.
	; - Keyboard scan codes are polled at base level or from
	;   the VBL routine, possibly concurrently with the
	;   polling of the joystick reports.
	; Such concurrent accesses to the ACIA (keyboard scan
	; codes and joystick reports) result in the loss of 
	; keyboard events.
	;
	; The following improved routines replace the original
	; buggy ones. They use an IKBD/ACIA interrupt handler
	; which collects all IKBD events (keyboard scan codes
	; as well as joystick reports) thus avoiding concurrent
	; accesses to the ACIA from different places.
	;
	; In addition, an internal service is provided.
	; This service detects keyboard events indicating that
	; the current program or activity should end.
	; To this end, special VBL and ACIA/IKBD interrupt handlers
	; are installed to detect whether the escape key, the space
	; key or the fire button has been triggered.
	; This internal service is used when the player is asked to
	; swap floppy disks #1 & #2.
	; See keyb_vbl_start() and swap_disk_wait() for details.
	;
	; Doc:
	; - https://www.kernel.org/doc/Documentation/input/atarikbd.txt
	;

keyb_fix_start
	ifne	DEBUG
	nop
	endc

	;
	; Table describing the modifications to be applied to the
	; game files in order to replace the original keyboard
	; routines with the improved versions.
	;
	; There are 5 different programs, corresponding to 5
	; files, which need to be patched:
	; - file $07: Presentation screen
	; - file $26: High score screen
	; - file $52: Information shop
	; - file $53: Weapon shop
	; - file $55: Brick game
	;
	; These files are modified during the game after they are
	; loaded & unpacked, according to the information provided
	; in this table.
	; See also the depack() and apply_fixes() routines.
	;
	; Each program file is modified:
	; - to disable the original IKBD management.
	; - to jump into the code below:
	;   . when the program initializes, in order to set up the
	;     new ACIA/IKBD and new VBL interrupt handlers.
	;   . when it terminates, in order to stop the ACIA/IKBD
	;     interrupt handler.
	;
	; A new VBL routine is installed for each program. This
	; routine calls the program's original VBL routine and
	; additionally performs ACIA/IKBD management:
	; - it sends a 'JOYSTICK INTERROGATE' command to the IKBD,
	; - it checks the events collected by the ACIA/IKBD
	;   interrupt handler,
	; - it updates the data of the running program to report
	;   detected IKBD events (joystick fire, escape key...).
	;
	; File $89 (game finale) originally does not handle IKBD
	; events: the final animation takes place entirely until
	; it hangs in an infinite loop (without reaching the high
	; scores screen).
	; In order to avoid this unfriendly behavior, file $89 is
	; also patched: when the final animation is finished, the
	; player can now press a key to access the high score
	; screen and possibly restart a new game.
	;

keyb_fix_tbl
	; File $07: presentation screen.
	; 1. Disable the check of the joystick1 event used to
	;    trigger the end of the program as this event is now
	;    handled by the keyb_file07_vbl() handler.
	dc.w	$0702,$028c,$4e75
	; 2. Disable the polling of the escape key used to
	;    trigger the end of the program as this event is
	;    now handled by the keyb_file07_vbl() handler.
	dc.w	$0702,$02a0,$4e75
	; 3. Disable HBL-based joystick management.
	dc.w	$0702,$04fc,$4e75
	dc.w	$0702,$0516,$4e75
	; 4. Program init: call keyb_file07_init() to install the
	;    new ACIA/IKBD and the new VBL routines.
	dc.w	$0706,$0022
keyb_file07_fix_reloc
	jsr	KEYB_FILE07_INIT_OFF

	; File $52: information shop.
	; 1. Disable HBL-based joystick management.
	dc.w	$5202,$0c3a,$4e75
	dc.w	$5202,$0c40,$4e75
	; 2. Program init: call keyb_file52_init() to install the
	;    new ACIA/IKBD and the new VBL routines.
	dc.w	$5206,$001a
keyb_file52_fix1_reloc
	jsr	KEYB_FILE52_INIT_OFF
	; 3. Program cleanup: call keyb_file52_fini() to stop
	;    the ACIA/IKBD interrupt handler.
	dc.w	$5206,$0142
keyb_file52_fix2_reloc
	jmp	KEYB_FILE52_FINI_OFF
	; 4. VBL routine: remove unexpected modification of SR.
	dc.w	$5204,$c24,$4e71,$4e71

	; File $53: weapon shop.
	; 1. Disable HBL-based joystick management.
	dc.w	$5302,$0cba,$4e75
	dc.w	$5302,$0cc0,$4e75
	; 2. Program init: call keyb_file52_init() to install the
	;    new ACIA/IKBD and the new VBL routines.
	dc.w	$5308,$001a
	nop
keyb_file53_fix1_reloc
	jsr	KEYB_FILE52_INIT_OFF
	; 3. Program cleanup: call keyb_file52_fini() to stop
	;    the ACIA/IKBD interrupt handler.
	dc.w	$5306,$014c
keyb_file53_fix2_reloc
	jmp	KEYB_FILE52_FINI_OFF
	; 4. VBL routine: remove unexpected modification of SR.
	dc.w	$5304,$ca2,$4e71,$4e71

	; File $55: brick game.
	; 1. Program init: call keyb_file55_init() to install the
	;    new ACIA/IKBD routine.
	dc.w	$5506,$097e
keyb_file55_fix1_reloc
	jmp	KEYB_FILE55_INIT_OFF
	; 2. Program cleanup: call keyb_file55_fini() to stop
	;    the ACIA/IKBD interrupt handler.
	dc.w	$5506,$09a2
keyb_file55_fix2_reloc
	jmp	KEYB_FILE55_FINI_OFF
	; 3. Remove HBL-based joystick management from the original
	;    VBL routine and call keyb_file55_vbl() instead.
	dc.w	$5506,$28ca
keyb_file55_fix3_reloc
	jmp	KEYB_FILE55_VBL_OFF
	; 4. Disable HBL-based joystick management.
	dc.w	$5502,$28e4,$4e75
	; 5. Disable the polling of the escape key and the space
	;    key used to trigger the end of the game and the pause
	;    of the game respectively.
	;    Those events are now handled by the keyb_file55_vbl()
	;    routine.
	dc.w	$5502,$2842,$4e75

	; File $26: high score screen.
	; 1. Avoid a deadlock by saving a6 in the stack instead
	;    of USP in the sample replay routine (timer-A).
	;    This fix is superseded by a more elaborated fix
	;    on machines with 1MB of RAM or more. See comments
	;    of psg_fix_start() for details.
	;
	dc.w	$2602,$bd78,$2f0e
	dc.w	$2602,$bd90,$2c5f
	dc.w	$2602,$bdaa,$2c5f
	; 2. Disable HBL-based joystick management.
	dc.w	$2604,$05a4,$4e71,$4e71
	dc.w	$2602,$05c0,$4e71
	dc.w	$2602,$05c6,$4e75
	; 3. Remove HBL-based joystick management from the original
	;    VBL routine and replace it with a small code that
	;    installs the new ACIA/IKBD interrupt handler.
	;    This code is only executed after the player has
	;    entered his name in the high score table.
	;    So the new ACIA/IKBD handler is only used to detect
	;    the keypress or the joystick event that terminates
	;    the program (ie during the second part of the program
	;    as explained in the comments of keyb_file26_init()).
	;
	dc.w	$260a,$0604
keyb_file26_fix1_reloc
	move.l	#KEYB_ISR_OFF,$118.w
	rts
	; 4. Program init: call keyb_file26_init() to start the
	;    new ACIA/IKBD management and to install the new VBL
	;    routine.
	dc.w	$2606,$0366
keyb_file26_fix2_reloc
	jsr	KEYB_FILE26_INIT_OFF

	; file $89: game finale.
	; 1. Remove unused joystick management.
	dc.w	$8902,$0e2a,$4e75
	; 2. Wait for a keypress at the end of the final
	;    animation.
	dc.w	$8906,$02e2
keyb_file89_fix_reloc
	jmp	KEYB_FILE89_END_OFF
	; 3. VBL routine: remove unexpected modifications of SR.
	dc.w	$8904,$e06,$4e71,$4e71
	dc.w	$8904,$e1e,$4e71,$4e71

	; End of the modifications.
	dc.w	0

	;
	; Show the CPU used by the VBL routine.
	; Available in debug mode only.
	;

VBL_INIT_COL    macro
	ifne	SOUNDTRACK_VBL_TIME
	move.w	#\1,BG_COL.w
	endc
	endm

VBL_SHOW_COL    macro
	ifne	SOUNDTRACK_VBL_TIME
	move.w	BG_COL.w,$ffff8240.w
	endc
	endm

TIM_SET_COL     macro
	ifne	SOUNDTRACK_VBL_TIME
	move.w	#$2400,sr
	move.w	BG_COL.w,BG_COL+2.w
	move.w	#\1,BG_COL.w
	move.w	#\1,$ffff8240.w
	move.w	#$2300,sr
	endc
	endm

TIM_RESTORE_COL macro
	ifne	SOUNDTRACK_VBL_TIME
	move.w	#$2400,sr
	move.w	BG_COL+2.w,BG_COL.w
	move.w	BG_COL.w,$ffff8240.w
	move.w	#$2300,sr
	endc
	endm

	;
	; keyb_file52_init()
	;
	; Called during the initialization of programs $52 & $53
	; to install the new ACIA/IKBD and VBL routines.
	;
keyb_file52_init
	movea.l	(a7)+,a1
	; Replace the original VBL routine with keyb_file52_vbl().
	lea	$36(a1),a1
	lea	keyb_file52_vbl_orig+2(pc),a0
	move.l	$38(a1),(a0)
	lea	keyb_file52_vbl(pc),a0
	move.l	a0,$38(a1)
	; Enable interrupt-driven ACIA/IKBD management.
	bsr	keyb_init
	; Save in KEYB_PTR_JOY.w the address where the joystick
	; reports are to be written. This is the address where
	; programs $52 & $53 expect to find them.
	lea	-3(a6),a0
	move.l	a0,KEYB_PTR_JOY.w
	; Color used for VBL CPU usage.
	VBL_INIT_COL	$000
	; Execute the instruction which has been patched to jump
	; into this code, and return to the calling program.
	move.w	#$2300,sr
	jmp	(a1)

	;
	; keyb_file52_fini()
	;
	; Called during the cleanup of programs $52 & $53
	; to stop the ACIA/IKBD interrupt handler.
	;
keyb_file52_fini
	move.w	#$2700,sr
	bra	keyb_fini

	;
	; keyb_file52_vbl()
	;
	; New VBL routine used in programs $52 & $53.
	; This routine calls the program's original VBL
	; handler and performs ACIA/IKBD management:
	; A joystick report is requested by sending a
	; 'JOYSTICK INTERROGATE' command ($16) to the IKBD.
	; The report is then received by the ACIA/IKBD interrupt
	; handler and saved to a memory location polled by the
	; current program, as indicated in the KEYB_PTR_JOY.w
	; variable by keyb_file52_init().
	;
keyb_file52_vbl
	; Call the original VBL routine.
keyb_file52_vbl_orig
	jsr	$0.l
	VBL_SHOW_COL
	; Request a joystick report by sending a
	; 'JOYSTICK INTERROGATE' command to the IKBD.
	bsr	keyb_joy_query
	rte

	;
	; keyb_file55_init()
	;
	; Called during the initialization of program $55 to save
	; in KEYB_PTR_JOY.w ($64.w) the address where the joystick
	; reports are to be written by the IKBD interrupt handler.
	; This is the address where program $55 expects to find
	; those reports.
	;
keyb_file55_init
	; Execute the instruction which has been patched to jump
	; into this code.
	move.l	a0,$134.w
	; Enable interrupt-driven ACIA/IKBD management.
	bsr	keyb_init
	; Indicate where joystick reports are to be written.
	lea	$27(a6),a0
	move.l	a0,KEYB_PTR_JOY.w
	; Return to the calling program.
	rts

	;
	; keyb_file55_fini()
	;
	; Called during the cleanup of program $55 to
	; stop the ACIA/IKBD interrupt handler.
	;
keyb_file55_fini
	move.w	#$2700,sr
	bra	keyb_fini

	;
	; keyb_file55_vbl()
	;
	; Routine called by the program's VBL handler.
	; It performs ACIA/IKBD management:
	; - report to the current program the detected keystroke
	;   ('escape' exits the game and 'space' pauses it).
	; - trigger a joystick interrogate, the resulting report
	;   being written directly into the game data as indicated
	;   in KEYB_PTR_JOY.w.
	;
keyb_file55_vbl
	; Get the latest keystroke.
	move.b	KEYB_DATA_KEY.w,d0
	; Escape?
.esc	cmpi.b	#1,d0
	bne.s	.space
	; Yes, trigger the end of the program.
	clr.b	$1f(a6)
	bra.s	.joy
	; Space?
.space	cmpi.b	#$39,d0
	bne.s	.joy
	; Yes, switch the pause state.
	neg.b	$1e(a6)
	; Request a joystick report by sending a
	; 'JOYSTICK INTERROGATE' command to the IKBD.
.joy	bsr	keyb_joy_query
	rts

	;
	; keyb_file07_init()
	;
	; Called during the initialization of program $07 to
	; install the new ACIA/IKBD and VBL routines.
	;
keyb_file07_init
	; Replace the original VBL routine with keyb_file07_vbl().
	movea.l	(a7)+,a6
	lea	$174(a6),a6
	lea	keyb_file07_vbl_orig+2(pc),a0
	move.l	$1c(a6),(a0)
	lea	keyb_file07_vbl(pc),a0
	move.l	a0,$1c(a6)
	; Disable unused Timer-B/HBL (was unexpectedly set up by
	; the calling program).
	bclr	#0,$fffffa07.w
	bclr	#0,$fffffa13.w
	; Enable interrupt-driven ACIA/IKBD management.
	; Keep the default settings: joystick1 reports are written
	; to a private location (at KEYB_DATA_JOY) because they
	; are only accessed by the new VBL handler.
	bsr	keyb_init
	; Color used for VBL CPU usage.
	VBL_INIT_COL	$000
	; Execute the instruction which has been patched to jump
	; into this code, and return to the calling program.
	move.w	#$2300,sr
	jmp	(a6)

	;
	; keyb_file07_vbl()
	;
	; New VBL routine used in program $07.
	; This routine calls the program's original VBL
	; handler and performs ACIA/IKBD management:
	; - if the escape key, the space key or the joystick fire
	;   button has been pressed, update the data of the current
	;   program to indicate that it must exit.
	; - trigger a joystick interrogate, the resulting reports
	;   being written to a private location as they are only
	;   used by this VBL routine.
	;
keyb_file07_vbl
	movem.l	d0/a0/a6,-(a7)
	; Call the original VBL routine.
keyb_file07_vbl_orig
	jsr	$0.l
	VBL_SHOW_COL
	; Do not perform ACIA/IKBD management if keyb_fini()
	; has already been called.
	cmpi.l	#$74,$118.w
	beq.s	.ret
	; Test keyboard events terminating the program: escape
	; key, space key or fire button has been triggered?
	bsr	keyb_exit_tst
	tst.b	d0
	beq.s	.no_exit
	; Yes, stop ACIA/IKBD management.
	bsr	keyb_fini
	; Indicate that the program shall be terminated.
	clr.b	$f(a6)
	bra.s	.ret
	; Request a joystick report by sending a
	; 'JOYSTICK INTERROGATE' command to the IKBD.
.no_exit	bsr	keyb_joy_query
.ret	movem.l	(a7)+,d0/a0/a6
	rte

	;
	; keyb_file26_init()
	;
	; Called during the initialization of program $26 to
	; enable interrupt-driven ACIA/IKBD management and
	; install the new VBL routine.
	;
	; From an ACIA/IKBD management standpoint, program $26
	; (the high score screen) is divided into two parts:
	; 1) the player enters his name when he reaches a
	;    new high score.
	; 2) the high score table is displayed until the
	;    player exits the program by pressing escape
	;    or the fire button.
	;
	; In the first part, the original code polls keyboard
	; scan codes at base level and no joystick report is
	; requested. So there is no concurrency problem and thus
	; no need to modify this part of the program.
	; In the second part, the original code polls keyboard
	; scan codes and joystick reports concurrently, so this
	; part of the program is modified.
	;
	; The keyb_file26_init() routine is called when program
	; $26 initializes: it enables interrupt-driven ACIA/IKBD
	; management but installs a fake interrupt handler so that
	; the new ACIA/IKBD management is not active during the
	; first part of the program.
	; Program $26 is modified to install the actual ACIA/IKBD
	; handler after the first part is over.
	; Therefore the new ACIA/IKBD management is only used
	; during the second part to safely detect the keypress
	; or the joystick event that terminates the program (see
	; also the comments in the keyb_fix_tbl table).
	;
keyb_file26_init
	movea.l	(a7)+,a1
	; Two instructions have been modified to jump here.
	; Restore the opcode of the second instruction as it
	; will be executed upon return.
	move.w	#$4eba,-(a1)
	; Replace the original VBL routine with keyb_file26_vbl().
	lea	keyb_file26_vbl_orig+2(pc),a0
	move.l	$36(a1),(a0)
	lea	keyb_file26_vbl(pc),a0
	move.l	a0,$36(a1)
	; Enable interrupt-driven ACIA/IKBD management.
	; Keep the default settings: joystick1 reports are written
	; to a private location (at KEYB_DATA_JOY) because they are
	; only used by the new VBL handler.
	bsr	keyb_init
	; Temporarily install a fake ACIA/IKBD interrupt handler.
	bsr	keyb_dummy
	; Color used for VBL CPU usage.
	VBL_INIT_COL	$222
	; Execute the instruction which has been replaced to jump
	; into this code, and return to the calling program.
	move.w	#$2300,sr
	jmp	(a1)

	;
	; keyb_file26_vbl()
	;
	; New VBL routine used in program $26.
	; This routine calls the program's original VBL
	; handler and performs ACIA/IKBD management:
	; - if the escape key, the space key or the joystick fire
	;   button has been pressed, update the current program
	;   data to indicate that the program must exit.
	; - trigger a joystick interrogate, the resulting reports
	;   being written to a private location as they are
	;   only used by this VBL routine.
	;
keyb_file26_vbl
	movem.l	d0/a0,-(a7)
	; Call the original VBL routine.
keyb_file26_vbl_orig
	jsr	$0.l
	VBL_SHOW_COL
	; Do not perform ACIA/IKBD management if the first part
	; of the program is executing or if keyb_fini() has
	; already been called (ie program is exiting).
	cmpi.l	#$74,$118.w
	beq.s	.ret
	; Test keyboard events terminating the program: escape
	; key, space key or fire button has been triggered?
	bsr	keyb_exit_tst
	tst.b	d0
	beq.s	.no_exit
	; Yes, stop ACIA/IKBD management.
	bsr	keyb_fini
	; Indicate that the program shall be terminated.
	movea.l	keyb_file26_vbl_orig+2(pc),a0
	move.b	#$80,-$1f5(a0)
	; Patch the code executed by the VBL routine so that it
	; does not reinstall the ACIA/IKBD interrupt handler.
	move.w	#$4e75,$70(a0)
	bra.s	.ret
	; Request a joystick report by sending a
	; 'JOYSTICK INTERROGATE' command to the IKBD.
.no_exit	bsr	keyb_joy_query
.ret	movem.l	(a7)+,d0/a0
	rte

	;
	; keyb_file89_end()
	;
	; Allow to resume the game once the final animation is
	; finished.
	;
	; The original code contains an infinite loop at the end
	; of the animation.
	; This loop is replaced by a jump to this code.
	; It waits for the space or escape key to be pressed to
	; resume the game on the high score screen.
	;
keyb_file89_end
	; Execute the instruction which has been patched to jump
	; into this code.
	movea.l	$2d62.w,a0
	jsr	$90(a0)
	; Flush ACIA/IKBD.
	bsr	keyb_reset
	; Call a routine in the main game program that waits for
	; a keypress and return the corresponding scan code.
.wait	jsr	GAME_DEST_ADDR+$4586.w
	; Space?
	cmpi.b	#$39,d0
	beq.s	.reboot
	; Escape?
	cmpi.b	#1,d0
	; Loop until a valid key is pressed.
	bne.s	.wait
	; Resume the game.
.reboot	move.w	#$2700,sr
	; Disable MFP interrupts and install dummy interrupt
	; handlers.
	jsr	GAME_DEST_ADDR+VECTORS_OFF_DEST_OFF
	; Go to the high score screen.
	jmp	GAME_DEST_ADDR+$66c0

	;
	; Defines the addresses where the ACIA/IKBD interrupt
	; handler saves keyboard event reports.
	;
	; An ACIA/IKBD interrupt is triggered when:
	; - The IKBD generates a keyboard scan code for a key
	;   press.
	; - the IKBD responses to joystick interrogation with
	;   a three byte report of the form:
	;   0xFD        joystick report header
	;   %x000yyyy   joystick 0
	;   %x000yyyy   joystick 1 where x is the button trigger
	;               and yyy is the stick position
	;
	; - $B0 contains the number (index) of the last byte
	;   received on the 3 included in a joystick report.
	; - $B1 contains the scan code corresponding to the
	;   latest key press (1 byte).
	; - $B2 contains the joystick1 event report (1 byte).
	;   This report is actually saved to the memory location
	;   specified in $B4, which is $B2 by default.
	;   Specifying a different address (in $B4) allows to
	;   place the report directly into the game data as
	;   expected by the game.
	; - $B3 contains a byte indicating whether the end of
	;   the current program has been requested: the escape
	;   key, the space key, or the fire button has been
	;   triggered.
	;   Note that $B3 is updated only if the keyb_vbl()
	;   handler is used, that is if keyb_vbl_start()
	;   has been invoked.
	;
KEYB_DATA       =	$b0             ; ACIA/IKBD reports address
KEYB_DATA_CNT   =	KEYB_DATA+0     ; Joystick report byte nr
KEYB_DATA_KEY   =	KEYB_DATA+1     ; Latest key scan code
KEYB_DATA_JOY   =	KEYB_DATA+2     ; Joystick1 report byte
KEYB_DATA_EXIT  =	KEYB_DATA+3     ; Exit notification
KEYB_PTR_JOY    =	$b4             ; Joystick1 report address

	;
	; keyb_vbl_start()
	;
	; Start the service used to asynchronously detect
	; keyboard events indicating that the current program
	; or activity should end.
	;
	; It installs special VBL and ACIA/IKBD interrupt
	; handlers to detect whether the escape key, the space
	; key or the fire button has been triggered.
	;
	; This internal service is used by the swap_disk_wait()
	; routine.
	;
keyb_vbl_start
	move.l	a0,-(a7)
	; Mask interrupts and install dummy handlers.
	move.w	#$2700,sr
	jsr	GAME_DEST_ADDR+VECTORS_OFF_DEST_OFF
	; Enable interrupt-driven ACIA/IKBD management.
	; Keep the default settings: joystick1 reports are written
	; to a private location (at KEYB_DATA_JOY) because they are
	; only accessed by the new VBL handler.
	bsr	keyb_init
	; Install the special VBL handler.
	lea	keyb_vbl(pc),a0
	move.l	a0,$70.w
	; Enable interrupts.
	move.w	#$2300,sr
	movea.l	(a7)+,a0
	rts

	;
	; keyb_vbl_stop()
	;
	; Stop the service previously started by keyb_vbl_start().
	;
keyb_vbl_stop
	; Mask all interrupts.
	move.w	#$2700,sr
	; Stop ACIA/IKBD management.
	bsr	keyb_fini
	; Install a dummy VBL handler.
	move.l	$118.w,$70.w
	rts

	;
	; keyb_vbl()
	;
	; VBL routine used to detect keyboard events indicating
	; that the current program or activity should end.
	;
	; The byte at address KEYB_DATA_EXIT ($B3) is set
	; to 1 if the escape key, the space key or the fire
	; button has been triggered.
	;
	; This VBL routine is for internal use only:
	; it is started by keyb_vbl_start(), stopped by
	; keyb_vbl_stop() and used by the swap_disk_wait()
	; routine.
	; 
keyb_vbl
	move.l	d0,-(a7)
	; Do nothing if the program has already been notified.
	move.b	KEYB_DATA_EXIT.w,d0
	bne.s	.ret
	; The escape key, space key or fire button has been
	; triggered?
	bsr.s	keyb_exit_tst
	tst.b	d0
	beq.s	.no_exit
	; Yes, update the byte at address KEYB_DATA_EXIT
	; to notify that the program shall terminate.
	move.b	d0,KEYB_DATA_EXIT.w
	bra.s	.ret
	; Request a joystick report by sending a
	; 'JOYSTICK INTERROGATE' command to the IKBD.
.no_exit	bsr.s	keyb_joy_query
.ret	move.l	(a7)+,d0
	rte

	;
	; keyb_isr()
	;
	; ACIA/IKBD interrupt handler.
	;
	; Handle ACIA/IKBD interrupts triggered when a keyboard
	; scan code or a joystick report is received.
	;
	; - A scan code is received each time a key is pressed.
	; - A joystick report is received in response to each
	;   'JOYSTICK INTERROGATE' command sent to the IKBD.
	;
	; This handler saves the received keyboard data at
	; address KEYB_DATA ($B0-$B4).
	; See the description of the KEYB_DATA macros above.
	;
keyb_isr
	; Available RX data?
	btst	#0,$fffffc00.w
	bne.s	.avail
	; No, return (spurious interrupt).
	rte
	; Yes, handle received event.
.avail	move.l	d0,-(a7)
	; Get received keyboard data.
	move.b	$fffffc02.w,d0
	; Joystick report header?
	cmpi.b	#$fd,d0
	beq.s	.jhead
	; Joystick 0/1 report?
	tst.b	KEYB_DATA_CNT.w
	bne.s	.jdata
	; No, so it is a keyboard scan code.
	; Save it in KEYB_DATA_KEY.
	move.b	d0,KEYB_DATA_KEY.w
.ret	move.l	(a7)+,d0
	rte
	; Joystick report header received, get ready to
	; receive the following 2 reports (joystick 0 & 1).
.jhead	move.b	#2,KEYB_DATA_CNT.w
	bra.s	.ret
	; Joystick0 is not used, so merely skip it and get ready
	; to receive the joystick1 report.
.jdata	subq.b	#1,KEYB_DATA_CNT.w
	bne.s	.ret
	; Joystick1 report received, save it at the address
	; pointed to by KEYB_PTR_JOY (which is KEYB_DATA_JOY
	; by default).
	move.l	a0,-(a7)
	movea.l	KEYB_PTR_JOY.w,a0
	move.b	d0,(a0)
	movea.l	(a7)+,a0
	bra.s	.ret

	;
	; keyb_joy_query()
	;
	; Request a joystick report by sending a
	; 'JOYSTICK INTERROGATE' command to the IKBD.
	;
keyb_joy_query
	btst	#1,$fffffc00.w
	beq.s	.skip
	clr.l	KEYB_DATA.w
	move.b	#$16,$fffffc02.w
.skip	rts

	;
	; keyb_exit_tst()
	;
	; Indicate whether a keyboard event ending the current
	; program has been received.
	;
	; Out:
	;   d0.b: $01 if the escape key has been pressed,
	;         $39 if the space key has been pressed,
	;         $ff if the joystick button has been triggered,
	;         0 otherwise.
	;
keyb_exit_tst
	; Get the latest scan code received.
	move.b	KEYB_DATA_KEY.w,d0
	; Escape key?
	cmpi.b	#1,d0
	beq.s	.exit
	; Space key?
	cmpi.b	#$39,d0
	beq.s	.exit
	; Has the fire button been triggered?
	btst	#7,KEYB_DATA_JOY.w
	; Yes: d0=$ff, No: d0=0.
	sne	d0
.exit	rts

	;
	; keyb_init()
	;
	; Enable interrupt-driven ACIA/IKBD management.
	;
	; - Set up the IKBD & flush the ACIA.
	; - Install the ACIA/IKBD interrupt handler.
	; - Set up the MFP.
	;
keyb_init
	; Set up the IKBD & flush the ACIA.
	bsr.s	keyb_reset
	; Reset KEYB_DATA content.
	; Incoming keyboard events will be saved here.
	clr.l	KEYB_DATA.w
	; By default, joystick1 reports are written to a private
	; location (at KEYB_DATA_JOY).
	move.l	#KEYB_DATA_JOY,KEYB_PTR_JOY.w
	; Install the interrupt handler.
	pea	keyb_isr(pc)
	move.l	(a7)+,$118.w
	; Enable keyboard/MIDI in the MFP enable & mask B regs.
	bset	#6,$fffffa15.w
	bset	#6,$fffffa09.w
	rts

	;
	; keyb_fini()
	;
	; Stop ACIA/IKBD management.
	;
keyb_fini
	; Disable keyboard/MIDI in the MFP enable & mask B regs.
	bclr	#6,$fffffa09.w
	bclr	#6,$fffffa15.w
keyb_dummy
	; Install a dummy ACIA/IKBD interrupt handler.
	move.l	#$74,$118.w
	rts

	;
	; keyb_reset()
	;
	; Set up the IKBD & flush the ACIA.
	;
keyb_reset
	movem.l	d0/a0,-(a7)
	lea	$fffffc00.w,a0
	; Disable joysticks.
	move.b	#$1a,d0
	bsr.s	keyb_send
	; Flush the ACIA.
	bsr.s	keyb_flush
	; Set joystick interrogation mode.
	move.b	#$15,d0
	bsr.s	keyb_send
	; Flush the ACIA again.
	bsr.s	keyb_flush
	movem.l	(a7)+,d0/a0
	rts

	;
	; keyb_flush()
	;
	; Flush the ACIA receive buffer.
	;
	; In:
	;   a0: Keyboard ACIA control ($fffffc00)
	;
	; Scratch: d0
	;
keyb_flush	btst	#0,(a0)
	beq.s	.done
	move.b	2(a0),d0
	bra.s	keyb_flush
.done	rts

	;
	; keyb_send()
	;
	; Send a command to the IKBD.
	;
	; In:
	;   d0: IKBD command
	;   a0: Keyboard ACIA control ($fffffc00)
	;
keyb_send	btst	#1,(a0)
	beq.s	keyb_send
	move.b	d0,2(a0)
	rts

	;
	; End of the block of resident code providing improved
	; ACIA/IKBD routines (keyboard/joystick).
	;
keyb_fix_end

	;
	; Information for the installation of the previous
	; keyboard routines: routines lengths & routines
	; offsets within the block of code.
	;

KEYB_FIX_LEN               =	(keyb_fix_end-keyb_fix_start)
KEYB_FIX_TBL_OFF           =	(keyb_fix_tbl-keyb_fix_start)
KEYB_VBL_START_OFF         =	(keyb_vbl_start-keyb_fix_start)
KEYB_VBL_STOP_OFF          =	(keyb_vbl_stop-keyb_fix_start)
KEYB_ISR_OFF               =	(keyb_isr-keyb_fix_start)
KEYB_RESET_OFF             =	(keyb_reset-keyb_fix_start)
KEYB_FILE07_INIT_OFF       =	(keyb_file07_init-keyb_fix_start)
KEYB_FILE52_INIT_OFF       =	(keyb_file52_init-keyb_fix_start)
KEYB_FILE52_FINI_OFF       =	(keyb_file52_fini-keyb_fix_start)
KEYB_FILE55_INIT_OFF       =	(keyb_file55_init-keyb_fix_start)
KEYB_FILE55_FINI_OFF       =	(keyb_file55_fini-keyb_fix_start)
KEYB_FILE55_VBL_OFF        =	(keyb_file55_vbl-keyb_fix_start)
KEYB_FILE26_INIT_OFF       =	(keyb_file26_init-keyb_fix_start)
KEYB_FILE89_END_OFF        =	(keyb_file89_end-keyb_fix_start)

	;
	; Start of the block of resident code providing improved
	; sample replay routines (music modules and sound FX).
	;
	; This block of code is installed in a high memory area
	; by the game_patch() routine.
	;
	; The original replay routines have the following issues:
	; - They only work on ST and crash on Falcon: indeed
	;   PSG shadow registers ($ff8804-$ffff88ff) are not
	;   available on Falcon.
	; - They also do not work on CT60 as the 68060 CPU
	;   does not implement the 'movep' instruction that is
	;   used in those routines.
	; - A subtle bug occurs when the replay routine is
	;   re-entered in case of nested interrupts.
	;   Indeed, in the high score screen, MFP interrupts are
	;   reenabled in the replay routine (allowing reentrancy)
	;   in order to reduce the latency of HBL interrupts and
	;   thus stabilize rasters.
	;   When such reentrancy occurs, the USP register is
	;   corrupted, resulting in a deadlock in the high score
	;   screen.
	;
	; The following improved routines work on all machines
	; and support reentrancy.
	; However, due to the use of specific DA tables, they
	; have an important memory footprint (almost 10KB) so
	; they cannot be installed in low memory (the game
	; occupies most of the first 512KB of memory).
	; As a consequence, they are installed in high RAM,
	; that is only on machines with 1MB of RAM or more.
	; It is OK for the Falcon and CT60 machines which have
	; at least 1MB of RAM.
	; On a ST with only 512KB of RAM, the following routines
	; are not used. Therefore another fix (more basic) is
	; provided to prevent the high score screen deadlock.
	; See the keyb_fix_tbl (file $26) for details.
	;
	; Doc:
	; - http://s390174849.online.de/ray.tscc.de/samples.htm
	; - http://www.page6.org/archive/issue_31/page_32.htm
	;
psg_fix_start
	ifne	DEBUG
	nop
	endc

	;
	; Table describing the modifications to be applied to
	; the game files in order to replace the original replay
	; routines with the improved versions.
	;
	; There are 6 different programs, corresponding to 6
	; files, which use a sample replay routine and which
	; need to be patched:
	; - file $03: Main game program
	; - file $07: Presentation screen
	; - file $26: High score screen
	; - file $52: Information shop
	; - file $53: Weapon shop
	; - file $89: Game finale
	;
	; File $03 is directly modified by the game_patch()
	; routine before the game is started. The other files
	; are modified on-the-fly after they are loaded and
	; unpacked, according to the information provided in
	; this table.
	; See also the depack() and apply_fixes() routines.
	;
	; Each program file is modified to jump into the
	; code below when it initializes and shutdowns the MFP.
	;
	; In addition, file $07 (presentation screen) which is
	; the first program that plays a music module is modified
	; as follows: the music DA table used in this program,
	; which is identical to that of the other programs,
	; is converted into a DA table that can be used by the
	; new music replay routines.
	; This new music DA table is used in all programs.
	;
mus_fix_tbl
	; File $07: presentation screen.
	; 1. Initialize the Digital-to-Analog (DA) table.
	dc.w	$0706,$01c
	jsr	PSG_FIX_RESID_ADDR+MUS_DA_TABLE_INIT_OFF
	; 2. MFP init: set up timer-A to use the new replay routine.
	dc.w	$0706,$136
	jsr	PSG_FIX_RESID_ADDR+MUS_REPLAY_INIT_OFF
	; 3. MFP cleanup: empty routine (placeholder).
	dc.w	$0708,$184
	jsr	PSG_FIX_RESID_ADDR+MUS_REPLAY_FINI_OFF
	nop

	; File $26: high score screen.
	; 1. MFP init: set up timer-A to use the new replay routine.
	dc.w	$2606,$15c
	jsr	PSG_FIX_RESID_ADDR+MUS_REPLAY_INIT_UNMASK_OFF
	; 2. MFP cleanup: empty routine (placeholder).
	dc.w	$2608,$186
	jsr	PSG_FIX_RESID_ADDR+MUS_REPLAY_FINI_OFF
	nop

	; File $52: information shop.
	; 1. MFP init: set up timer-A to use the new replay routine.
	dc.w	$5206,$ae8
	jsr	PSG_FIX_RESID_ADDR+MUS_REPLAY_INIT_OFF
	; 2. MFP cleanup: empty routine (placeholder).
	dc.w	$5208,$13a
	jsr	PSG_FIX_RESID_ADDR+MUS_REPLAY_FINI_OFF
	nop

	; File $53: weapon shop.
	; 1. MFP init: set up timer-A to use the new replay routine.
	dc.w	$5306,$b42
	jsr	PSG_FIX_RESID_ADDR+MUS_REPLAY_INIT_OFF
	; 2. MFP cleanup: empty routine (placeholder).
	dc.w	$5308,$144
	jsr	PSG_FIX_RESID_ADDR+MUS_REPLAY_FINI_OFF
	nop

	; File $89: game finale.
	; MFP init: set up timer-A to use the new replay routine.
	dc.w	$8906,$162
	jsr	PSG_FIX_RESID_ADDR+MUS_REPLAY_INIT_ONCE_OFF

	; End of the modifications.
	dc.w	0

	;
	; psg_da_table_init()
	;
	; Convert the DA table used by an original replay routine
	; to a DA table that is suitable for the replacement replay
	; routine.
	;
	; This routine is called to create:
	; - the DA table used for the music modules
	; - the DA table used for the sound FX (Falcon case only)
	;
	; Original DA tables encode volume data as follows:
	; 8-bits ... Channel A select  \                / $ff8800
	; 8-bits ... Channel A volume   \  movep.l =>  /  $ff8802
	; 8-bits ... Channel B select   /    (2)       \  $ff8804
	; 8-bits ... Channel B volume  /                \ $ff8806
	; 8-bits ... Channel C select  \                / $ff8800
	; 8-bits ... 0                  \  move.l =>   /  $ff8801
	; 8-bits ... Channel C volume   /    (1)       \  $ff8802
	; 8-bits ... 0                 /                \ $ff8803
	; 1 entry for the 3 channels occupies 16 bytes.
	;
	; The new DA tables encode volume data as follows:
	; 8-bits ... Channel C select  \   
	; 8-bits ... 0                  \  
	; 8-bits ... Channel C volume   /  ST(e): movem.l d5-d7
	; 8-bits ... 0                 /   [$ff8800 - $ff880b]
	; 8-bits ... Channel A select  \   
	; 8-bits ... 0                  \  or
	; 8-bits ... Channel A volume   /  
	; 8-bits ... 0                 /   Falcon: move.l d5/d6/d7
	; 8-bits ... Channel B select  \   [$ff8800 - $ff8803]
	; 8-bits ... 0                  \  
	; 8-bits ... Channel B volume   /  
	; 8-bits ... 0 ________________/   
	; 8-bits ... 0                 \
	; 8-bits ... 0                  \  ignored
	; 8-bits ... 0                  /
	; 8-bits ... 0                 /
	; 1 entry for the 3 channels now occupies 32 bytes.
	;
	; - in the original replay routines, the volume of
	;   channel C (1) is updated before the volume of
	;   channels A & B (2). This order is respected in the
	;   new routines.
	; - bytes written to odd addresses ($ff8801, $ff8803...)
	;   are ignored.
	; - [$ff8804 - $ff880b] are shadow registers (equivalent
	;   to [$ff8800 - $ff8803]), they are not present on
	;   Falcon/CT60 machines.
	;
	; In:
	;   a0: original DA table
	;   a1: buffer containing the converted DA table
	;
	; Scratch: d0,d1,d2,d3,a0,a1
	;
psg_da_table_init
	move.w	#256-1,d0
.lp	move.l	(a0)+,d1        ; d1 = $cavacbvb
	move.l	d1,d2           ; d2 = $cavacbvb
	ror.l	#8,d2           ; d2 = $vbcavacb
	andi.l	#$ff00ff00,d1   ; d1 = $ca00cb00
	andi.l	#$ff00ff00,d2   ; d2 = $vb00va00
	move.l	d2,d3           ; d3 = $vb00va00
	move.w	d1,d2           ; d2 = $vb00cb00
	swap	d2              ; d2 = $cb00vb00
	move.w	d3,d1           ; d1 = $ca00va00
	move.l	(a0)+,(a1)+     ; $cc00vc00
	move.l	d1,(a1)+        ; $ca00va00
	move.l	d2,(a1)+        ; $cb00vb00
	clr.l	(a1)+           ; $00000000
	dbf	d0,.lp
	rts

	;
	; fx_replay_init_falcon()
	;
	; Initialize the DA table used by the new replay routine
	; dedicated to sound effects (Falcon/CT60 only).
	;
	; While original music replay routines have issues on all
	; machines (in particular the reentrancy bug), the original
	; sound FX replay routine has issues on Falcon machines
	; only (reentrancy is not used but PSG shadow registers
	; are).
	; Since this routine is super optimized and performance
	; is critical (sound FX are played during the game), the
	; original sound FX replay routine is kept "as is" on ST(e)
	; and is replaced on Falcon/CT60 only.
	; 
	; Therefore, a suitable DA table should be created for
	; the sound effects on those machines only.
	;
	; The original sound effects replay routine is located in
	; the main game program (file $03). It is replaced by the
	; game_patch() routine before the game is started.
	; The new sound FX DA table is set up at the same moment,
	; when game_patch() invokes fx_replay_init_falcon().
	; The new sound FX DA table is placed in high RAM, right
	; after the new music DA table.
	;
	; In:
	;   a0: original sound FX DA table
	;
	; Out:
	;   a0: address of the new sound FX replay routine.
	;
fx_replay_init_falcon
	movem.l	d0-d3/a1-a2,-(a7)

	; First, copy the new sound FX replay routine.
	; It is placed between the new music DA table and the new
	; sound FX DA table.
	; This is done to cope with the use of the 
	; 'movem.l psg_da_table(pc,d7.w),d5-d7' instruction which
	; has a limited pc-relative offset.
	lea	psg_da_table+(256*16)(pc),a1
	lea	fx_replay_falcon(pc),a2
	move.w	#(psg_da_table-fx_replay_falcon)/2-1,d0
.cp	move.w	(a2)+,(a1)+
	dbf	d0,.cp

	; Then convert the original sound FX DA table into
	; a version compatible with the new replay routine.
	bsr.s	psg_da_table_init

	; Return the address of the new sound FX replay routine.
	; This is used by the game_patch() routine to fix the
	; main game program so that it uses the new replay routine
	; instead of the original one.
	lea	psg_da_table+(256*16)(pc),a0
	movem.l	(a7)+,d0-d3/a1-a2
	rts

	;
	; mus_da_table_init()
	;
	; Initialize the DA table used by the new replay routines
	; dedicated to music modules.
	;
	; All programs which play a music module use an identical
	; or similar replay routine based exactly on the same DA
	; table.
	;
	; File $07 is the first program that plays a music module.
	; The DA table provided in this file is converted to a new
	; DA table suitable for the improved replay routines. It
	; is installed in high memory for use by all programs that
	; play a music module.
	;
	; File $07 is modified after loading and unpacking by the
	; apply_fixes() routine according to the mus_fix_tbl
	; modifications table, so that the following routine
	; is called when program $07 initializes.
	;
mus_da_table_init
	movem.l	d0-d3/a0-a1,-(a7)

	; Execute the instruction which has been replaced in
	; file $07 to jump into this routine.
	adda.l	#$fa00,a5

	; Get the address of the original DA table.
	lea	$b60(a5),a0
	; Convert it and install the new table at the end
	; of the current block of code.
	lea	psg_da_table(pc),a1
	bsr.s	psg_da_table_init

	; Resume program $07 init.
	movem.l	(a7)+,d0-d3/a0-a1
	rts

	;
	; mus_replay_init_once()
	; mus_replay_init()
	; mus_replay_init_unmask()
	;
	; Every program that plays a music module calls one of
	; these 3 functions to install the appropriate sample
	; replay routine.
	;
	; These functions save the address of the appropriate
	; music replay routine into the mus_replay_rout variable
	; and return the address of mus_replay_hook() to the
	; caller.
	;
	; The mus_replay_hook() routine (returned in a0) is then
	; installed as the timer-A handler by the caller. When the
	; first timer-A interrupt is triggered, mus_replay_hook()
	; is executed: it saves the address of the samples buffer
	; (which is in a5) and installs the actual timer-A handler
	; (previously saved in mus_replay_rout).
	;
	; 4 sample replay routines are provided for the music:
	; - mus_replay() is used on ST(e).
	;   It takes advantage of the PSG shadow registers.
	;   MFP Interrupts are disabled during the execution of
	;   the routine.
	; - mus_replay_unmask() is similar to mus_replay() but
	;   the MFP interrupts are reenabled during the execution
	;   of the routine, thus enabling reentrancy.
	; - mus_replay_falcon() is used on Falcon and CT60.
	;   It does not use PSG shadow registers and keeps
	;   MFP interrupts disabled.
	; - mus_replay_falcon_unmask() is similar to
	;   mus_replay_falcon() but the MFP interrupts are
	;   reenabled during the execution of the routine,
	;   thus enabling reentrancy.
	;
	; The reentrant versions are used in the high score screen
	; (program $26) only.
	;
	; Programs $07, $52 and $53 are modified after loading and
	; unpacking (according to the mus_fix_tbl modifications
	; table) so that the mus_replay_init() routine is called
	; when the program sets up the timer-A.
	; mus_replay_init() will cause the mus_replay() or
	; mus_replay_falcon() routine (depending on the machine
	; type) to be installed as the timer-A handler.
	;
	; Program $26 is modified in the same way, but the
	; program calls mus_replay_init_unmask() which causes
	; the installation of either mus_replay_unmask() or
	; mus_replay_unmask_falcon() as the timer-A handler.
	;
	; Program $89 is modified similarly, but the program
	; calls mus_replay_init_once() which is equivalent to
	; mus_replay_init() with the following difference:
	; mus_replay_init_once() modifies the code of the calling
	; program so that it can be executed several times, but
	; mus_replay_hook(pc) is only installed the first time
	; and the current timer-A handler remains unchanged
	; the other times.
	;
	; Out:
	;   a0: address of mus_replay_hook()
	;       mus_replay_rout contains the address of one of the
	;       following 3 functions: - mus_replay_init_once()
	;                              - mus_replay_init()
	;                              - mus_replay_init_unmask()
	;

mus_replay_init_once
	movea.l	(a7),a0
	move.l	a1,-(a7)
	; Modify the code of the caller so that next time
	; it is executed, mus_replay_rout_get() is called
	; instead of this routine. 
	lea	mus_replay_rout_get(pc),a1
	move.l	a1,-4(a0)
	movea.l	(a7)+,a1
	; Fall-through

mus_replay_init
	; Use mus_replay() as the replay/timer-A routine.
	; On Falcon/CT60, the following instruction is patched
	; by the game_patch() routine, so that mus_replay_falcon()
	; is used instead.
	pea	mus_replay(pc)
	bra.s	mus_replay_init_cont

mus_replay_init_unmask
	; Use mus_replay_unmask() as the replay/timer-A routine.
	; On Falcon/CT60, the following instruction is patched
	; by the game_patch() routine, so that
	; mus_replay_unmask_falcon() is used instead.
	pea	mus_replay_unmask(pc)

mus_replay_init_cont
	; Save the selected replay routine in mus_replay_rout
	; and return the address of mus_replay_hook() in a0.
	lea	mus_replay_hook(pc),a0
	move.l	(a7)+,mus_replay_rout-mus_replay_hook(a0)
	rts

	;
	; mus_replay_fini()
	;
	; This function is called when MFP interrupts are stopped,
	; by all programs which have been modified to use the new
	; replay routines.
	; Actually, it only executes the original instructions
	; which have been patched to jump into that function.
	;
mus_replay_fini
	; Execute the original instructions: reset timer-A
	; and timer-B handlers to the default value.
	move.l	a0,$120.w
	move.l	a0,$134.w
	rts

	;
	; mus_replay_rout_get()
	;
	; Used in conjunction with mus_replay_init_once() to
	; make sure the mus_replay_hook() routine is installed
	; only once, even if mus_replay_init_once() is called
	; several times.
	; This routine merely returns in a0 the address of the
	; replay routine currently in use so that it can be
	; re-installed as the timer-A handler by the caller.
	;
	; Out:
	;   a0: address of the replay routine currently in use
	;
mus_replay_rout_get
	movea.l	mus_replay_rout(pc),a0
	rts

	; Hold the address of the selected music replay routine.
mus_replay_rout
	dc.l	0

	;
	; mus_replay_hook()
	;
	; Bootstrap code used by all music replay routines.
	; mus_replay_hook() is executed only once when the first
	; timer-A interrupt is triggered.
	; - It saves the address of the samples buffer which is
	;   placed in a5 by the running program.
	;   The start address of the samples buffer is needed to
	;   handle the rollover at the end of that buffer.
	; - It then installs the address of the selected music
	;   replay routine in the timer-A vector.
	;
mus_replay_hook
	move	a6,USP
	; Use the "ST Replay" mode (tone is OFF) instead of the
	; "Quartet" mode (tone is ON), as it gives better
	; results under Hatari...
	movea.w	#$8800,a6
	move.b	#$7,(a6)
	move.b	#$7f,2(a6)
	; Save the start address of the samples buffer.
	lea	mus_buf_start(pc),a6
	move.l	a5,(a6)
	move	USP,a6
	; Install the actual music replay routine.
	move.l	mus_replay_rout(pc),$134.w
	; Continue with the Falcon replay routine which also
	; works on a plain ST.
	; Normal interrupt processing, using the selected
	; replay routine, will take place from the next
	; interrupts.
	bra.s	mus_replay_falcon

	;
	; mus_replay_unmask()
	; mus_replay()
	;
	; Music sample replay routines.
	; ST(e) versions.
	;
	; Load a sample, get the corresponding volume data
	; from the music DA table and write those data to
	; the PSG registers.
	;
	; The samples buffer is pointed to by a5.
	; Volumes of the 3 channels are written at once by the
	; 'movem.l' instruction via the PSG shadow registers.
	;
	; mus_replay_unmask() enables reentrancy while
	; mus_replay() keeps MFP interrupts disabled.
	;

mus_replay_unmask
	; Reenable MFP interrupts, so the handler is reentrant.
	move	#$2500,sr
	; Detect a possible stack overflow (in debug mode only).
	ifne	DEBUG_ASSERT
mus_replay_assert
	cmpa.l	#$0,a7
	bhs.s	.stack_ok
	illegal	; Trigger the crash handler.
.stack_ok
	endc	; DEBUG_ASSERT
mus_replay
	movem.l	d5-d7,-(a7)
	; Get next sample.
	move.w	(a5)+,d7
	; Check for rollover.
	blt.s	mus_rollover
	add.w	d7,d7
	add.w	d7,d7	
	; Get corresponding volume data.
	movem.l	psg_da_table(pc,d7.w),d5-d7
	; Output data to PSG (and shadow) registers.
	movem.l	d5-d7,$ffff8800.w
	movem.l	(a7)+,d5-d7
mus_replay_ret
	rte
	; Provide 4 bytes after the 'rte' instruction so that it
	; can be patched on-the-fly and replaced by a jmp <addr>
	; instruction by the timer50hz routines.
	dc.l	0

	;
	; mus_replay_unmask_falcon()
	; mus_replay_falcon()
	;
	; Music sample replay routines.
	; Falcon/CT60 versions.
	;
	; Same routines as the ST(e) versions, but PSG shadow 
	; registers are not used.
	;
	; mus_replay_unmask_falcon() enables reentrancy while
	; mus_replay_falcon() keeps MFP interrupts disabled.
	;

mus_replay_unmask_falcon
	move	#$2500,sr
	; Detect a possible stack overflow (in debug mode only).
	ifne	DEBUG_ASSERT
mus_replay_assert_falcon
	cmpa.l	#$0,a7
	bhs.s	.stack_ok
	illegal	; Trigger the crash handler.
.stack_ok
	endc	; DEBUG_ASSERT
mus_replay_falcon
	movem.l	d5-d7,-(a7)
mus_get_sample
	move.w	(a5)+,d7
	blt.s	mus_rollover
	add.w	d7,d7
	add.w	d7,d7	
	movem.l	psg_da_table(pc,d7.w),d5-d7
	; Don't use PSG shadow regs.
	move.l	d5,$ffff8800.w
	move.l	d6,$ffff8800.w
	move.l	d7,$ffff8800.w
	movem.l	(a7)+,d5-d7
mus_replay_falcon_ret
	rte
	; Provide 4 bytes after the 'rte' instruction so that it
	; can be patched on-the-fly and replaced by a jmp <addr>
	; instruction by the timer50hz routines.
	dc.l	0

	;
	; mus_rollover()
	;
	; Handle the rollover at the end of the samples buffer.
	; Reload the buffer start address in a5 and resume the
	; execution of the music sample replay routine.
	; The buffer start address was previously saved by the
	; mus_replay_hook() bootstrap routine. 
	;
mus_rollover
	; Reload the buffer start address.
	movea.l	mus_buf_start(pc),a5
	; Resume the execution of the replay routine by jumping
	; to the falcon version which works on all machines.
	bra.s	mus_get_sample

	; Hold the start address of the music samples buffer.
mus_buf_start
	dc.l	0

	;
	; fx_replay_falcon()
	;
	; Sound FX sample replay routine.
	; Falcon/CT60 only.
	;
	; Load a sample, get the corresponding volume data
	; from the sound FX DA table and write those data
	; to the PSG registers.
	;
	; The samples buffer is pointed to by a5.
	; As in the original routine, there is no buffer rollover.
	;
	; This routine is recopied after the music DA table,
	; right before the sound FX DA table, as described in
	; the fx_replay_init_falcon() routine.
	;
fx_replay_falcon
	movem.l	d5-d7,-(a7)
	moveq.l	#0,d7
	move.b	(a5)+,d7
	lsl.w	#4,d7
	movem.l	psg_da_table(pc,d7.w),d5-d7
	; Don't use PSG shadow regs.
	move.l	d5,$ffff8800.w
	move.l	d6,$ffff8800.w
	move.l	d7,$ffff8800.w
	movem.l	(a7)+,d5-d7
	rte

	; DA table created and installed on-the-fly by the
	; mus_da_table_init() routine.
psg_da_table

	;
	; End of the block of resident code providing improved
	; sample replay routines.
	;
psg_fix_end

	;
	; Information for the installation of the previous
	; replay routines: routines lengths & routines offsets
	; within the block of code.
	;

PSG_FIX_LEN                =	(psg_fix_end-psg_fix_start)
PSG_FIX_FULL_LEN           =	((psg_da_table-psg_fix_start)+(psg_da_table-fx_replay_falcon)+(256*16*2))
MUS_FIX_TBL_OFF            =	(mus_fix_tbl-psg_fix_start)
MUS_DA_TABLE_INIT_OFF      =	(mus_da_table_init-psg_fix_start)
MUS_REPLAY_FINI_OFF        =	(mus_replay_fini-psg_fix_start)
MUS_REPLAY_INIT_ONCE_OFF   =	(mus_replay_init_once-psg_fix_start)
MUS_REPLAY_INIT_OFF        =	(mus_replay_init-psg_fix_start)
MUS_REPLAY_INIT_UNMASK_OFF =	(mus_replay_init_unmask-psg_fix_start)
MUS_REPLAY_RET_OFF         =	(mus_replay_ret-psg_fix_start)
MUS_REPLAY_FALCON_RET_OFF  =	(mus_replay_falcon_ret-psg_fix_start)
FX_REPLAY_INIT_FALCON_OFF  =	(fx_replay_init_falcon-psg_fix_start)

	;
	; Start of the block of resident code providing optimized
	; rasters support for the high score screen.
	;
	; This block of code is installed in a high memory area
	; by the game_patch() routine.
	;
	; In the high score screen, rasters are used to color the
	; fonts of the score text.
	; The original rasters routine gets the color of the
	; current line from a buffer indexed by a counter which
	; is incremented on every line.
	; With this technique, the counter needs to be loaded,
	; incremented and saved every rasterline, and registers
	; used for that purpose need to be saved onto the stack.
	; This is sub-optimal, especially on Falcon on which very
	; little time is available in the left and right borders
	; for rasters.
	;
	; To have super-optimized rasters code, it is possible to
	; generate it automatically as follows:
	; a specific routine is created for each rasterline, the
	; appropriate color being hard-coded directly in the
	; generated code.
	; With this technique, no need to use a buffer, counter
	; or registers.
	; It allows to have stable rasters on Falcon machines.
	;
	; Due to its important memory footprint (2.5KB), this block
	; of resident code cannot be installed in low memory (the
	; game occupies most of the first 512KB of memory).
	; As a consequence, it is installed in high RAM, that is
	; only on machines with 1MB of RAM or more.
	; On a ST with only 512KB of RAM, the original rasters
	; code is used.
	;
	; In addition to improving the rasters code, this block also
	; provides an improved "screen buffer swap" mechanism.
	;
	; In the original code, the two screen buffers are swapped
	; on every frame even when no change has been made to the
	; screen content (the screen content is only updated when
	; a letter is entered by the player).
	; Since the screen buffers are swapped at base level (IPL 3)
	; it is possible that the video address update is interrupted
	; by a higher priority routine between the update of the high
	; byte and the update of the mid byte.
	; This can produce a glitch on the screen depending on how
	; long the higher priority routine takes to execute and when
	; the video address is updated relative to the VBL.
	; Such glitch happens quite frequently on Falcon (VIDEL chip).
	;
	; To work around this issue, the main loop of the high score
	; program is modified so that the screen buffers are swapped
	; only when necessary, i.e. when the screen content has been
	; actually changed. This drastically reduces the occurrence
	; of the glitch.
	;
	; Doc:
	; - http://thethalionsource.w4f.eu/Artikel/Rasters.htm
	;
rasters_start
	ifne	DEBUG
	nop
	endc

	;
	; Table describing the modifications to be applied to
	; the high score program in order to replace the original
	; rasters code with the optimized rasters support.
	;
	; The high score program (file $26) is modified on-the-fly
	; after it is loaded and unpacked, according to the
	; information provided in this table.
	; See also the depack() and apply_fixes() routines.
	;
	; It is modified to jump into the block of code below when
	; it initializes the MFPs (at startup) and when it sets
	; up the timer-B/HBL handler (in the VBL routine).
	;
	; It is also modified so that the main loop of the program
	; calls a new routine that improves the "screen buffers swap".
	;
rasters_tbl
	; File $26: high score screen.
	; 1. When MFPs are initialized by the program, jump into
	;    the rasters_init() routine.
	dc.w	$2608,$150
	jsr	RASTERS_RESID_ADDR+RASTERS_INIT_OFF
	nop
	; 2. When the timer-B/HBL handler is set up, install the
	;    first of the generated raster routines.
	dc.w	$260a,$5e2
	move.l	#RASTERS_RESID_ADDR+RASTERS_ROUTS_OFF,$120.w
	rts
	; 3. Patch the main loop of the program so that it calls
	;    rasters_swap_screen() in high memory.
	;    This will improve the "screen buffers swap".
	dc.w	$2608,$36e
	jsr	RASTERS_RESID_ADDR+RASTERS_SWAP_SCREEN_OFF
	nop

	; End of the modifications.
	dc.w	0

	;
	; rasters_init()
	;
	; Generate the raster code: a specific routine is
	; created for each rasterline. The purpose of these
	; routines is to change the color of the score text
	; several times per VBL to create raster bars.
	;
	; There are 2 cases:
	; - The color is the same as for the previous rasterline.
	; - The color is different (a new color value must be
	;   set).
	;
	; When a new color value must be set, the following
	; routine is generated:
	;
	;   move.w #<color_value>,$ffff825e.w
	;   addi.w #$e,$122.w
	;   rte
	;
	; When the color is the same as for the previous line,
	; the generated routine is:
	;
	;   addq.w #6,$122.w
	;   rte
	;
	; Each routine updates the timer-B/HBL interrupt vector
	; so that the routine corresponding to the next rasterline
	; is executed at the next timer-B/HBL interrupt.
	; As generated routines are one after the other in memory,
	; a simple offset is added to the current address in the
	; timer-B/HBL interrupt vector.
	; For performance reasons, the offset is added only to the
	; lower 16-bits of the address. It works because all the
	; routines generated fit in the same block aligned on 64KB.
	;
rasters_init
	movem.l	d0-d2/a0-a1,-(a7)

	; Execute the 2 instructions of the high score program
	; which have been replaced by a 'jsr' to call this init
	; routine.
	move.l	a0,$68.w
	move.l	a0,$120.w

	; a0 points to the color buffer of the high score program.
	lea	$268(a0),a0
	; a1 points to the area where routines are generated.
	lea	rasters_routs(pc),a1
	; There are 178 routines.
	move.w	#177,d0
	moveq.l	#-1,d1
.lp	move.w	(a0)+,d2
	cmp.w	d1,d2
	beq.s	.nocol
	; First case: generate a routine that sets the color.
	move.w	#$31fc,(a1)+     ; move.w #x,a.w
	move.w	d2,(a1)+         ; x=color
	move.w	#$825e,(a1)+     ; a=$ffff825e
	move.l	#$678000e,(a1)+  ; addi.w #$e,a.w
	move.w	#$122,(a1)+      ; a=$122
	move.w	d2,d1
	bra.s	.rte
	; Second case: generate a routine that does nothing
	; except setting up the next routine.
.nocol	move.l	#$5c780122,(a1)+ ; addq.w #6,$122.w
.rte	move.w	#$4e73,(a1)+     ; rte
	dbf	d0,.lp
	; The last routine executes only a 'rte'.
	move.w	#$4e73,(a1)+     ; rte

	; Return to to high score program.
	movem.l	(a7)+,d0-d2/a0-a1	
	rts

	;
	; rasters_swap_screen() is called by the main loop of the
	; high-score program to improve the "screen buffers swap"
	; mechanism.
	;
	; The original code of the main loop has been patched by
	; replacing two short calls to routines in the program with
	; a long call to the routine below located in high memory. 
	;
	; rasters_swap_screen() just calls the two original routines,
	; making sure that the "screen buffers swap" routine is only
	; called if necessary.
	;
rasters_swap_screen
	; Get the return address.
	movea.l	(a7),a0
	; A letter has been displayed in the high-score?
	; i.e. has the screen content been modified?
	tst.w	$3a(a0)
	beq.s	.noswap
	; Yes, update the shifter and call the original routine that
	; swaps the two screen buffers.
	lea	$14(a0),a0
	move	#$2700,sr
	move.b	1(a0),$ffff8201.w
	move.b	2(a0),$ffff8203.w
	move	#$2300,sr
	jsr	-($2b4+$14-$10)(a0)
.noswap	movea.l	(a7),a0
	; Call the vsync routine of the program.
	jsr	$20a(a0)
	rts

	;
	; Raster routines are generated hereafter.
	; The necessary space is provided when resident code blocks
	; are installed.
	;
rasters_routs

	;
	; End of the block of resident code providing improved
	; rasters support.
	;
rasters_end

	;
	; Information for the installation of the previous
	; improved rasters support: routines lengths & routines
	; offsets within the block of code.
	;

RASTERS_LEN                =	(rasters_end-rasters_start)
RASTERS_FULL_LEN           =	(RASTERS_LEN+(14*178+2))
RASTERS_TBL_OFF            =	(rasters_tbl-rasters_start)
RASTERS_INIT_OFF           =	(rasters_init-rasters_start)
RASTERS_SWAP_SCREEN_OFF    =	(rasters_swap_screen-rasters_start)
RASTERS_ROUTS_OFF          =	(rasters_routs-rasters_start)

	;
	; Start of the block of resident code allowing the
	; musics to be played at 50Hz, and the game frame rate
	; to run at the correct speed, on 60Hz monitors.
	;
	; This block of code is needed on TT and Falcon/CT60
	; machines that are connected to a VGA monitor (VIDEL is
	; configured at 60Hz) and on legacy machines connected to
	; a 60Hz monitor (e.g. NTSC).
	; It is installed in a high memory area by the game_patch()
	; routine.
	;
	; The game assumes the Atari machine is connected to a
	; RGB monitor or a TV running at a refresh rate of 50Hz.
	; In such configurations, the VBL interrupt is triggered
	; 50 times per second.
	; That VBL interrupt is used to periodically call the
	; music player as well as to control the frame rate (and
	; thus the play speed) of the game.
	; With this technique, the musics of the game are played
	; at the right speed only if the VBL runs at 50Hz.
	; Similarly, the frame rate of the game (the play speed)
	; is optimal only with a 50Hz VBL.
	; But when a VGA or NTSC monitor is used, the refresh rate
	; of the display is 60Hz, meaning that the VBL is triggered
	; 60 times per second instead of 50.
	; This leads the musics and the game frame rate, which
	; are both timed on VBL, to be 20% faster than expected.
	; This happens on TT and Falcon/CT60 machines when they
	; are connected to a VGA monitor or on legacy NTSC machines
	; for instance.
	;
	; The purpose of the following block of code is to have
	; the musics played at 50Hz and the game frame rate run
	; at the expected speed, even if the display refresh rate
	; (and the VBL) is not at 50Hz.
	;
	; The principle is the following:
	; - The timer-C (which is not used by the game) is
	;   configured to run at 50Hz.
	; - Every program that plays a music module is modified
	;   on-the-fly so that the routine of the music player
	;   is no longer called by the VBL handler but is called
	;   by the timer-C handler instead.
	;   The VBL handler still handles the display stuffs
	;   (palette & video buffers swapping) and the keyboard
	;   interrogation (including the joystick).
	; - The main program is modified (by the game_patch()
	;   routine directly) so that the frame rate is now timed
	;   on both the timer-C (to limit the play speed) and
	;   the VBL (to avoid display glitches when swapping
	;   display buffers).
	; - A special trick (detailed hereafter) is used to
	;   make the timer-C handler run at the lowest priority.
	;   That trick prevents the timer-C handler from preempting
	;   an already running handler (such as the VBL).
	;   Remember that the timer-C uses an MFP interrupt with
	;   a higher IPL (6) than the VBL (4).
	;   This ensures that operations performed in the VBL
	;   handler, or any other interrupt handler, cannot be
	;   delayed by the music player routine (which can take
	;   up to half of a VBL to run).
	;   That mechanism is necessary so as not to disturb the
	;   sensitive operations performed by the VBL handler,
	;   such as starting the timer-B for the rasters.
	;
timer50hz_start
	ifne	DEBUG
	nop
	endc

	;
	; Table describing the modifications to apply to the
	; game files in order to play the musics at 50Hz and
	; to have a normal play speed regardless of the refresh
	; rate of the display.
	;
	; 6 programs, corresponding to 6 files, need to be patched.
	; 5 programs play a music module and are modified to play
	; that music at the correct speed:
	; - file $07: Presentation screen
	; - file $52: Information shop
	; - file $26: High score screen
	; - file $53: Weapon shop
	; - file $89: Game finale
	; The main program (file $03) is modified to have a correct
	; frame rate. It is directly patched by the game_patch()
	; routine before the game is started.
	; The other files are modified on-the-fly after they are
	; loaded and unpacked, according to the information that
	; are provided in this table.
	; See also the depack() and apply_fixes() routines.
	;
timer50hz_tbl
	; File $07: presentation screen.
	; The VBL handler now calls the timer50hz_mus_setup()
	; routine before calling the music player.
	dc.w	$0706,$4ee
	jsr	TIMER50HZ_MUS_SETUP_OFF+TIMER50HZ_RESID_ADDR

	; File $26: high score screen.
	; The VBL handler now calls the timer50hz_mus_setup()
	; routine before calling the music player.
	dc.w	$2606,$5ac
	jsr	TIMER50HZ_MUS_SETUP_OFF+TIMER50HZ_RESID_ADDR

	; File $52: information shop.
	; 1. The VBL handler now calls the timer50hz_mus_setup()
	;    routine before calling the music player.
	dc.w	$5206,$c2c
	jsr	TIMER50HZ_MUS_SETUP_OFF+TIMER50HZ_RESID_ADDR
	; 2. The VBL handler no longer modifies SR.
	dc.w	$5204,$c24,$4e71,$4e71

	; File $53: weapon shop.
	; 1. The VBL handler now calls the timer50hz_mus_setup()
	;    routine before calling the music player.
	dc.w	$5306,$caa
	jsr	TIMER50HZ_MUS_SETUP_OFF+TIMER50HZ_RESID_ADDR
	; 2. The VBL handler no longer modifies SR.
	dc.w	$5304,$ca2,$4e71,$4e71

	; File $89: game finale.
	; 1. The VBL handler now calls the timer50hz_mus_setup()
	;    routine before calling the music player.
	dc.w	$8906,$e0e
	jsr	TIMER50HZ_MUS_SETUP_OFF+TIMER50HZ_RESID_ADDR
	; 2. The VBL handler no longer modifies SR.
	dc.w	$8904,$e06,$4e71,$4e71

	; End of the modifications.
	dc.w	0

	;
	; timer50hz_setup()
	;
	; Configure the MFP to start a 50Hz timer-C.
	;
	; The MFP's timer clock is 2457600Hz (2.4576MHz).
	; The timer freq is 2457600Hz / Divider / Counter.
	;
	; Divider = 200 (7<<4 -> $fffa1d)
	; Counter = 245
	; Freq    = 2457600Hz / 200 / 245 = 50Hz
	;
timer50hz_setup
	clr.b	$fffffa1d.w         ; Stop timer-C
	move.l	a1,$114.w           ; Install handler
	bset	#5,$fffffa15.w      ; Unmask timer-C intr
	bset	#5,$fffffa09.w      ; Enable timer-C intr
	move.b	#245,$fffffa23.w    ; Timer-C counter
	move.b	#(7<<4),$fffffa1d.w ; Start 50Hz timer-C

	; Work around an uncommon behavior that might occur in
	; timer50hz_intr_mfp(): masking the timer-A at the MFP level
	; while a timer-A interrupt is about to be handled (interrupt
	; cycle is started but not finished) triggers a spurious
	; interrupt. A dummy handler is thus installed in $60 to
	; ignore such undesired interrupts.
	move.w	#$4e73,$74.w
	move.l	#$74,$60.w
	rts

	;
	; timer50hz_mus_setup()
	;
	; Have the music player called by the timer-C handler
	; and no longer by the VBL handler.
	;
	; Each program that plays a music provides:
	; - A timer-A handler executing a sample replay routine.
	;   This routine is replaced with an improved version
	;   (see psg_fix_start for detailed comments).
	; - A VBL handler executing the main routine of the music
	;   player.
	;
	; The VBL handler of each program is modified so that it
	; now invokes timer50hz_mus_setup() right before calling
	; the music player.
	; This modification is done as follows:
	; In the code of the original VBL handler, the address of
	; the music player is computed using two instructions,
	; the first instruction loads a PC-relative address, the
	; second instruction adds a long immediate, the VBL handler
	; then calls the routine located at that address (which is
	; stored in a0).
	; The 2nd instruction (add a long immediate) is replaced
	; with a jump to timer50hz_mus_setup().
	;
	; When invoked by the VBL handler, timer50hz_mus_setup()
	; checks if the timer-C is already set up (by testing the
	; Interrupt Enable B register).
	;
	; If the timer-C is already running, the routine simply
	; prevents the caller (the original VBL handler) from
	; calling the music player on return: it patches the
	; return address in the stack so that the call to the
	; music player is skipped.
	; Indeed, the music player is now called by the timer-C.
	;
	; If the timer-C is not set up yet, it means that the
	; timer50hz_mus_setup() routine is called for the first
	; time. In that case, it sets up the timer-C as follows:
	; - The routine configures the MFP to start the timer-C.
	; - It saves the address of the music player, passed in
	;   a0 by the original VBL handler, so that it can be
	;   invoked by the timer-C handler.
	; - It installs a "wrapper" for the original VBL handler.
	;   To do this, the wrapper routine, timer50hz_vbl(),
	;   is patched to call the original VBL handler and
	;   then installed as the new VBL interrupt handler.
	;   A trap handler is used by the VBL wrapper to build a
	;   fake exception stack frame. This allows the original
	;   VBL handler to automatically return to the wrapper
	;   when it execute the 'rte' instruction.
	;   The VBL wrapper is used to control the preemption
	;   of the original VBL handler.
	;   See below for details.
	; - It patches the new music replay code in order to
	;   control the preemption of the music replay routine.
	;   See below for details.
	;
	; The last two points are used to prevent the timer-C
	; from preempting and delaying the execution of the
	; VBL handler and the music replay routine.
	; In other words, this allows the timer-C handler to run
	; as a background task (with the lowest priority) so as
	; not to disturb other interrupt handlers.
	;
	; Here is how this tricky mechanism works:
	;
	; 1) The following interrupt handlers might be preempted
	;    by the new timer-C handler running at IPL 6:
	;    - the VBL handler, which runs at IPL 4.
	;    - the timer-A handler, which is used to replay music
	;      samples.
	;      Indeed, in the high score program, the music replay
	;      routine lowers the IPL from 6 to 5 so that it can be
	;      preempted by handlers running at IPL 6. It is used
	;      to allow preemption by the timer-B handler in order
	;      to make rasters more stable.
	;
	; 2) A simple technique that could prevent the timer-C
	;    from preempting handlers running at IPL-4 or IPL-5,
	;    would be to mask and unmask the timer-C at MFP level
	;    (using the Interrupt Mask B register) respectively
	;    when entering and exiting those handlers.
	;    But this technique would require to do that in the
	;    sample replay routine which runs at 15KHz.
	;    It would consume too much CPU and would have an
	;    impact on the timer-B latency, thus making the
	;    rasters less stable.
	;
	; 3) Therefore, a more subtle technique is used.
	;
	;    The timer-C is allowed to preempt a handler running
	;    at a lower IPL (4 or 5).
	;    When this happens, the timer-C routine detects this
	;    situation by checking which IPL has been interrupted.
	;    - An IPL 4 means the VBL handler has been preempted.
	;    - An IPL 5 means the timer-A (music replay) handler
	;      has been preempted.
	;    Note that IPL 4 & 5 are only used by those handlers
	;    in all game programs.
	;
	;    If the VBL or timer-A handler has been preempted,
	;    the timer-C routine modifies on-the-fly the 'rte'
	;    instruction of the preempted handler so that it
	;    returns to the timer-C routine instead of returning
	;    from exception.
	;    Then, the timer-C routine immediately resumes the
	;    execution of the preempted handler.
	;    The preempted handler can thus complete its execution
	;    and when it exits, it returns to the timer-C routine
	;    as expected.
	;    With this technique, a preempted handler is only
	;    delayed by a few cycles, which is the time it takes
	;    to patch and resume it.
	;
	;    The timer-C routine performs the same operations
	;    in loop until there is no more preempted handler,
	;    that is until the preempted code runs at base level
	;    (IPL 3).
	;
	;    Note that patching the 'rte' instruction of preempted
	;    handlers requires knowing the address of that
	;    instruction.
	;    For the sample replay routine (timer-A), this address
	;    is known since our own routine is used (one of the
	;    mus_replay* routines, depending on the machine).
	;    This is more complicated for the VBL handler since
	;    every program provides its own VBL handler with a
	;    different address for the 'rte' instruction.
	;    That's why a VBL wrapper is used. This allows to have
	;    the 'rte' instruction which should be patched at a
	;    well-defined address.
	;
	;    In summary, the timer-C routine ensures that only the
	;    base-level code is preempted to call the music player.
	;    Before calling the music player, the IPL is lowered
	;    to 3 so that the timer-C routine becomes preemptible,
	;    which means that any other handler (VBL, timer A or B)
	;    can preempt the music player and run without delay.
	;
timer50hz_mus_setup
	; Test if the timer-C is already running.
	btst	#5,$fffffa09.w
	beq.s	.init
	; Yes, modify the return address so that the original
	; VBL handler skips the call to the music player.
	addq.l	#2,(a7)
	rts

	;
	; No, set up the timer-C as described above.
	;
.init	move.l	a1,-(a7)

	; Color used for VBL CPU usage (debug mode only).
	VBL_INIT_COL	$000

	;
	; Save the address of the music player so that the timer-C
	; handler can call it.
	;

	; Determine the address of the main routine of the
	; music player. To this end, execute the instruction
	; (add long immediate to a0) which has been patched
	; to jump into timer50hz_mus_setup().
	; Files $07, $26, $52 and $53 add $fa00 to a0.
	adda.l	#$fa00,a0
	cmpi.w	#$89,FILEOPS_ADDR+FILE_INFO_OFF+FILES_FILE_NR
	bne.s	.set_cb
	; File $89 adds $17700.
	adda.l	#$17700-$fa00,a0
	; Save the address.
.set_cb	lea	timer50hz_callback(pc),a1
	move.l	a0,2(a1)

	;
	; Prepare (patch) the sample replay routines so that
	; every 'rte' instruction can be quickly turned into
	; a 'jmp <timer50hz_intr_mfp_post>' instruction.
	;
	; See also mus_replay_ret and mus_replay_falcon_ret.
	;
	lea	MUS_REPLAY_RET_OFF+2+PSG_FIX_RESID_ADDR,a1
	move.l	#TIMER50HZ_INTR_MFP_POST_OFF+TIMER50HZ_RESID_ADDR,(a1)
	move.l	(a1),(MUS_REPLAY_FALCON_RET_OFF-MUS_REPLAY_RET_OFF)(a1)

	;
	; Set up the trap handler used by the VBL wrapper to build
	; a fake exception stack frame.
	;
	lea	timer50hz_vbl_trap(pc),a1
	move.l	a1,($80+(TIMER50HZ_TRAP<<2)).w

	;
	; Set up and install the VBL wrapper.
	;
	lea	timer50hz_vbl_orig(pc),a1
	move.l	$70.w,2(a1)
	lea	timer50hz_vbl(pc),a1
	move.l	a1,$70.w

	; Start the timer-C.
	lea	timer50hz_handler(pc),a1
	bsr.w	timer50hz_setup

	movea.l	(a7)+,a1
	rts

	;
	; timer50hz_vbl()
	;
	; VBL wrapper, installed as the actual VBL handler.
	;
	; It is used to:
	; - Call the original VBL handler of the music programs.
	; - Ensure that the 'rte' instruction of the VBL handler
	;   is at a well-defined address so that the timer-C
	;   handler can easily patch it.
	;   This allows the timer-C handler to resume execution
	;   of the VBL handler if it has been preempted, and
	;   then continue after the VBL handler finishes.
	;
	; See timer50hz_mus_setup() for detailed comments.
	;
timer50hz_vbl
	;
	; Build a fake exception stack frame so that the original
	; VBL handler returns to timer50hz_vbl_post when it
	; executes its 'rte' instruction.
	;

	; The fake exception stack frame is created using a generic
	; method (working on all CPUs): a 'trap' exception is
	; triggered, which ends up in timer50hz_vbl_trap (the
	; trap handler).
	trap	#TIMER50HZ_TRAP
timer50hz_vbl_trap
	; The return address of the fake exception is modified
	; to timer50hz_vbl_post, which is where the 'rte'
	; instruction of the original VBL handler must return.
	move.l	#TIMER50HZ_VBL_POST_OFF+TIMER50HZ_RESID_ADDR,2(a7)
timer50hz_vbl_orig
	; Execute the original VBL handler.
	jmp	$0.l
timer50hz_vbl_post
	; End of the VBL wrapper:
	; - Return from exception in the normal case, ie if the VBL
	;   handler has not been preempted by the timer-C handler.
	; - Or jump to timer50hz_intr_vbl_post if the VBL handler
	;   has been preempted by the timer-C handler (in which
	;   case the 'rte' instruction below is changed to a
	;   'jmp timer50hz_intr_vbl_post' instruction).
	rte
	dc.l	TIMER50HZ_INTR_VBL_POST_OFF+TIMER50HZ_RESID_ADDR

	;
	; timer50hz_handler() and helper routines
	;
	; The timer-C handler calls the main routine of the music
	; player and implements a special trick to not preempt
	; VBL and timer-A handlers.
	;
	; See timer50hz_mus_setup() for detailed comments.
	;

	;
	; timer50hz_intr_vbl() is called by the timer-C handler
	; when it detects that the VBL handler has been preempted
	; and should be resumed.
	;
	; The 'rte' instruction of the VBL handler is modified
	; to a 'jmp timer50hz_intr_vbl_post' instruction so that
	; the VBL handler returns to timer50hz_intr_vbl_post()
	; after its execution has been resumed and completed.
	;
timer50hz_intr_vbl
	move.w	#$4ef9,TIMER50HZ_VBL_POST_OFF+TIMER50HZ_RESID_ADDR
	rte

	;
	; timer50hz_intr_vbl_post() is called by the VBL handler
	; after its execution has been resumed and completed.
	; The 'rte' instruction of the VBL handler is restored
	; and control is returned to the timer-C handler.
	;
timer50hz_intr_vbl_post
	move.w	#$4e73,TIMER50HZ_VBL_POST_OFF+TIMER50HZ_RESID_ADDR
	bra.s	timer50hz_handler_post

	;
	; timer50hz_intr_mfp() is called by the timer-C handler
	; when it detects that the MFP timer-A handler has been
	; preempted and should be resumed.
	;
	; The 'rte' instructions of the timer-A handler are changed
	; to a 'jmp timer50hz_intr_mfp_post' instruction so that
	; the timer-A handler returns to timer50hz_intr_mfp_post()
	; after its execution has been resumed and completed.
	;
	; Here, the timer-A is masked at MFP level to prevent
	; reentrancy (the timer-C lowers the IPL to 5 and thus
	; any MFP interrupt can be served again, including a
	; new/nested timer-A interrupt).
	; Indeed, the modification on-the-fly of the timer-A
	; code is not compatible with a possible reentrancy
	; of this code.
timer50hz_intr_mfp
	ifne	DEBUG_ASSERT
	; The interrupted code can only be a music sample replay
	; routine. Assert it in debug mode only.
	cmpi.l	#PSG_FIX_RESID_ADDR,2(a7)
	blo.s	.hang
	cmpi.l	#PSG_FIX_RESID_ADDR+PSG_FIX_LEN,2(a7)
	blo.s	.pc_ok
.hang	illegal	; Trigger the crash handler.
.pc_ok
	endc	; DEBUG_ASSERT
	; Mask the timer-A using the Interrupt Mask A register.
	; The timer-A is masked while executing the "patched" replay
	; routine (ending with a 'jmp timer50hz_intr_mfp_post').
	; It will be unmasked by timer50hz_intr_mfp_post() after the
	; execution of the modified replay routine.
	; Note that a spurious interrupt might be triggered when
	; masking the timer-A while a timer-A interrupt is already
	; active (ie about to be processed). So a dummy handler is
	; installed in $60 by timer50hz_setup() to work around this
	; behavior.
	bclr	#5,$fffffa13.w
	; Stall the pipeline to ensure that the timer-A is actually
	; masked before patching the timer-A handler.
	nop
	; There are actually two possible exit points from the
	; music replay routine (the timer-A): the falcon version
	; is called by the ST(e) version in case of samples
	; buffer rollover. See mus_replay() and mus_rollover().
	; Therefore, patch both 'rte' instructions.
	move.w	#$4ef9,MUS_REPLAY_RET_OFF+PSG_FIX_RESID_ADDR
	move.w	#$4ef9,MUS_REPLAY_FALCON_RET_OFF+PSG_FIX_RESID_ADDR
	; Return to the interrupted replay routine.
	rte

	;
	; timer50hz_intr_mfp_post() is called by the timer-A
	; handler after its execution has been resumed and
	; completed.
	; The 'rte' instructions of the timer-A handler are
	; restored, the timer-A is unmasked at MFP level and
	; control is returned to the timer-C handler.
	;
timer50hz_intr_mfp_post
	move.w	#$4e73,MUS_REPLAY_RET_OFF+PSG_FIX_RESID_ADDR
	move.w	#$4e73,MUS_REPLAY_FALCON_RET_OFF+PSG_FIX_RESID_ADDR
	; Unmask the timer-A at the MFP level.
	bset	#5,$fffffa13.w
	bra.s	timer50hz_handler_post

	;
	; timer50hz_handler() is the timer-C entry point.
	;
	; It checks if the VBL or timer-A handler has been
	; preempted, resumes the execution of preempted
	; handlers, and then calls the music player.
	;
timer50hz_handler
	; First, mask the timer-C interrupt at MFP level to
	; prevent reentrancy once the IPL is lowered.
	; Indeed, we want to avoid the situation where the timer-C
	; has to handle self-preemption.
	bclr	#5,$fffffa15.w
	; Lower the IPL to 5 to enable preemption by the timer-A
	; (sample music replay) and timer-B (rasters).
	move.w	#$2500,sr

	; Use the saved IPL to determine which interrupt handler
	; has been preempted (if any).
	; Immediately resume the preempted handler.
	; The control is then returned to timer50hz_handler_post()
	; which redoes the same operations in loop until there
	; is no more preempted handler.
	; 
timer50hz_handler_post
	; IPL 5 means the timer-A handler has been preempted.
	cmpi.b	#$25,(a7)
	beq.s	timer50hz_intr_mfp
	; IPL 4 means the VBL handler has been preempted.
	cmpi.b	#$24,(a7)
	beq.s	timer50hz_intr_vbl
	ifne	DEBUG_ASSERT
	; If the saved IPL is not 4 or 5, it must be 3.
	; Assert it in debug mode only.
	cmpi.b	#$23,(a7)
	beq.s	timer50hz_intr_base
	illegal	; Trigger the crash handler.
	endc	; DEBUG_ASSERT

	; It is now guaranteed that the preempted code runs
	; at base level (IPL 3).
timer50hz_intr_base
	; Lower the IPL to 3 to enable preemption by the VBL.
	move.w	#$2300,sr

	; Call the music player.
	; a5 is not saved as it is modified in the background
	; by the sample replay routine.
	movem.l	d0-a4/a6,-(a7)
	TIM_SET_COL	$013
timer50hz_callback
	jsr	$0.l
	TIM_RESTORE_COL
	movem.l	(a7)+,d0-a4/a6

	; Reenable the timer-C at MFP level and return from
	; exception.
	; The IPL is raised to 6 to avoid reentrancy once the
	; timer-C interrupt is reenabled.
	move.w	#$2600,sr
	bset	#5,$fffffa15.w
	rte

	;
	; timer50hz_frame_setup()
	;
	; Have the game frame rate (the play speed) timed on both
	; the 50Hz timer-C and the VBL.
	;
	; The main game program provides a routine that controls
	; the frame rate of the game.
	; More precisely, this routine ensures that a constant
	; number of VBL events occurs between two consecutive
	; frames.
	; This routine is called whenever a new frame is drawn
	; during the game, so that the game play progresses at
	; a steady pace.
	; However, the routine generates a correct frame rate on
	; 50Hz monitors only. 
	; On 60Hz monitors, the frame rate (and therefore the play
	; speed) is 20% faster.
	;
	; The purpose of the following routines is to ensure that
	; the frame rate of the game runs at the correct speed
	; regardless of the refresh rate of the display.
	;
	; To this end, the main game program ($03) is modified by
	; game_patch() so that the original routine that controls
	; the frame rate is replaced by timer50hz_frame_wait().
	;
	; timer50hz_frame_wait() uses the timer-C, which runs at
	; 50Hz, to control the frame rate, and it uses the VBL
	; only to ensure that the next frame can be drawn safely
	; (without graphical glitches).
	;
	; timer50hz_frame_setup() is called by the main game
	; program each time a new game level, room or passage
	; is started. It will just launch the timer-C that is
	; used by timer50hz_frame_wait().
	;
timer50hz_frame_setup
	; Execute the 2 'stop' instructions which have been
	; replaced by a 'jmp' to branch into this routine.
	stop	#$2300
	stop	#$2300
	move.l	a1,-(a7)
	; Start the MFP timer-C and use a simple handler
	; that just counts the number of VBL events.
	clr.b	TIMER50HZ_COUNT.w
	lea	timer50hz_hdl_count(pc),a1
	bsr	timer50hz_setup
	movea.l	(a7)+,a1
	rts

	;
	; timer50hz_frame_wait()
	;
	; Control the frame rate of the game.
	; It is called whenever a new frame is drawn during the
	; game.
	;
	; - $84a is incremented by the VBL handler, it provides
	;   a counter for number of VBL events.
	; - $84b is set by the caller, it contains the number of
	;   VBL events that should occur between two consecutive
	;   frames (and thus between two consecutive calls to
	;   this routine).
	;   $84b is used by the calling program to determine the
	;   current frame rate, and thus the current play speed.
	;
	; The following routine counts the number of timer-C
	; events (instead of VBL events) that occur between
	; two consecutive calls, and ensures that this number
	; is greater than the number requested in $84b.
	; The routine also waits for one VBL event so that the
	; caller can safely swap graphics buffers and draw the
	; next scene.
	;
timer50hz_frame_wait
	; Reset the VBL event counter.
	clr.b	$84a.w
	; Minimal number of VBL (50Hz) events that must
	; occur between two frames (hence between two calls).
	move.b	$84b.w,d0
	; Use the timer-C which runs at 50Hz, and ensure that the
	; requested number of events has occurred since the last
	; invocation.
.w_tim	cmp.b	TIMER50HZ_COUNT.w,d0
	bhi.s	.w_tim
	; Synchronization on the VBL: ensure that at least one VBL
	; event has occurred during the execution of this routine.
.w_vbl	tst.b	$84a.w
	beq.s	.w_vbl
	moveq.l	#0,d7
	; Reset VBL and timer-C event counters.
	move.b	d7,$84a.w
	move.b	d7,TIMER50HZ_COUNT.w
	rts

	;
	; timer50hz_hdl_count()
	;
	; Timer-C handler used to control the frame rate during
	; the game.
	; It merely counts the number of timer-C events (occurring
	; at 50Hz).
	;
timer50hz_hdl_count
	addq.b	#1,TIMER50HZ_COUNT.w
	rte

	;
	; End of the block of resident code allowing the
	; musics to be played at 50Hz and the game framerate
	; to run at the correct speed on 60Hz monitors.
	;
timer50hz_end

	;
	; Information for the installation of the previous
	; timer50hz routines: routines lengths & routines
	; offsets within the block of code.
	;

TIMER50HZ_TRAP              =	6 ; $98
TIMER50HZ_COUNT             =	$9c

TIMER50HZ_LEN               =	(timer50hz_end-timer50hz_start)
TIMER50HZ_TBL_OFF           =	(timer50hz_tbl-timer50hz_start)
TIMER50HZ_MUS_SETUP_OFF     =	(timer50hz_mus_setup-timer50hz_start)
TIMER50HZ_VBL_POST_OFF      =	(timer50hz_vbl_post-timer50hz_start)
TIMER50HZ_INTR_VBL_POST_OFF =	(timer50hz_intr_vbl_post-timer50hz_start)
TIMER50HZ_INTR_MFP_POST_OFF =	(timer50hz_intr_mfp_post-timer50hz_start)
TIMER50HZ_FRAME_SETUP_OFF   =	(timer50hz_frame_setup-timer50hz_start)
TIMER50HZ_FRAME_WAIT_OFF    =	(timer50hz_frame_wait-timer50hz_start)

	;
	; Start of the block of resident code providing trainer
	; mode support.
	;
	; It is installed in low memory by the game_patch() routine
	; and called from the main game program.
	;
tr_resid_start

	;
	; Trainer mode configuration:
	; 0: trainer option disabled
	; 1: trainer option enabled
	;
tr_info
	dc.b	0               ;  0 - infinite lives
	dc.b	0               ;  1 - infinite energy
	dc.b	0               ;  2 - infinite time
	dc.b	0               ;  3 - infinite money
	dc.b	0               ;  4 - weapon selection
	dc.b	0               ;  5 - max firepower
	dc.b	0               ;  6 - fall into the sky
	dc.b	(DEBUG&1)       ;  7 - enter info shop
	dc.b	(DEBUG&1)       ;  8 - enter weapon shop
	dc.b	0               ;  9 - enter brick game
	dc.b	0               ; 10 - infinite brick lives
	dc.b	(DEBUG&1)       ; 11 - go to game finale
	dc.b	(DEBUG&1)       ; 12 - debug mode
	dc.b	0               ; 13 - starting level (0-5)
 	even

	;
	; Table describing the modifications to be applied to the
	; game files in order to enable some trainer features.
	;
	; Most of the trainer options are enabled by modifying
	; the main game program (file $03) directly from the
	; game_patch() routine before the game is started.
	; But 3 additional files, which are loaded later
	; during the game, need to be modified as well:
	; - files $04 and $54: Level management
	; - file $55: Brick game
	; The modifications are applied immediately after 
	; the files are loaded and unpacked, according to
	; the information provided in the following table.
	; See also the depack() and apply_fixes() routines.
	;
tr_tbl
tr_level
	; File $04: level management.
	; Force the starting level of the game.
	; 0 = first level, 1 = second level...
	; The game_patch() routine modifies the long word below
	; according to the selected level.
	dc.w	$0404,$75ec
	dc.l	0

tr_brick_lives
	; File $55: brick game.
	; Implement the infinite brick lives trainer option.
	; The word below contains the original opcode of the
	; brick program, which decrements the number of lives:
	; '$536e' = 'subq.w #1,x(a6)'.
	; When the trainer option is disabled, applying this
	; modification has no effect (opcode is the same as in
	; the game).
	; When the trainer option is enabled, the '$536e' word
	; is replaced by the game_patch() routine with a 'bra.s',
	; turning the dummy fix into an real fix.
	dc.w	$5502,$27b6,$536e

	; Files $04 and $54: level management program (the two
	; files are identical).
	; Fix how the level management program reads the header
	; of compressed files to get the unpacked size.
	; Originally, the pack-ice header was used, now it is
	; the UPX header.
	; Nothing to do with trainer support, but it has been put
	; here for the sake of simplicity.
	dc.w	$0402,$7cbe,$0008
	dc.w	$5402,$7cbe,$0008

	; End of the modifications.
	dc.w	0

	;
	; tr_keys()
	;
	; Handle keys pressed during game execution and
	; provide support for the following trainer options:
	; - key 's' ..... weapon selection
	; - key '1' ..... enter information shop
	; - key '2' ..... enter weapon shop
	; - key 'b' ..... enter brick game
	; - key '0' ..... go to game finale
	; - key 'esc' ... exit current game play (game over)
	; - key 'd' ..... enter the debugger
	;
	; Keys '1', '2', '0', 'esc' and 'd' are handled in
	; debug mode only (DEBUG=1).
	;
	; The original key handling routine is patched so that
	; it falls here when a key is pressed during the game.
	;
tr_keys
	movem.l	d0-d2/a0-a2,-(a7)
	lea	tr_info(pc),a0

	;
	; key 's' - weapon selection.
	;
.wsel	cmpi.b	#$1f,d7
	bne.s	.newlev
	tst.b	4(a0)           ; trainer: weapon select
	beq	.ret
	lea	$2ce0.w,a1
	moveq.l	#0,d0
	; Get current weapon.
	move.b	(a1),d0
	; Select next weapon.
	addq.b	#1,d0
	; 16 weapons are available.
	andi.b	#$f,d0
	; Update current weapon.
	move.b	d0,(a1)+
	move.b	d0,(a1)+
	; Update weapon's rate of fire.
	lea	$9a8.w,a0
	adda.l	d0,a0
	move.b	(a0),(a1)+
	move.b	(a0),(a1)
	bra	.ret

	;
	; Enter a new game module.
	;
.newlev	lea	$2d6d.w,a1
	tst.b	(a1)+
	bne.s	.finale

	;
	; key 'b' - enter the brick game.
	;
.brick	cmpi.b	#$30,d7
	bne.s	.shop1
	tst.b	9(a0)           ; trainer: brick game
	beq	.ret
	; Module 6 = brick game.
	move.b	#6,(a1)
	bra.s	.siglev

	;
	; key '1' - enter the information shop.
	;
.shop1	cmpi.b	#2,d7
	bne.s	.shop2
	tst.b	7(a0)           ; trainer: info shop
	beq.s	.ret
	; Module 4 = info shop.
	move.b	#4,(a1)
	bra.s	.shopct

	;
	; key '2' - enter the weapon shop.
	;
.shop2	cmpi.b	#3,d7
	bne.s	.finale
	tst.b	8(a0)           ; trainer: weapon shop
	beq.s	.ret
	; Module 5 =  weapon shop.
	move.b	#5,(a1)

	;
	; Save the character position.
	; Needed only when returning from info/weapon shops.
	;
.shopct	move.l	$2cf6.w,$2dc6.w
	bra.s	.siglev

	;
	; key '0' - go to the game finale.
	;
.finale	cmpi.b	#$b,d7
	bne.s	.esc
	tst.b	11(a0)          ; trainer: game finale
	beq.s	.ret
	; Level 5, module 3 = end of game.
	move.l	#$05000003,-4(a1)
	move.b	#3,(a1)

	;
	; Signal that the character enters a new module.
	; The game level management code will handle this
	; event and load/execute the appropriate game module
	; according to the module number saved in a1=$2d6e.w
	;
.siglev	move.b	-(a1),$2d6b.w
	move.w	#1,$2d4e.w
	bra.s	.ret

	;
	; key 'esc' - force a game over.
	;
.esc	cmpi.b	#1,d7
	bne.s	.debug
	tst.b	12(a0)          ; trainer: debug
	beq.s	.ret
	; Reset the credits number.
	move.b	#3,$2deb.w
	; Credits screen: ask for confirmation.
	; Does not return if game over is confirmed.
	jsr	GAME_DEST_ADDR+$66a4
	; The user decided not to exit: restore the game.
	jmp	GAME_DEST_ADDR+$61ee

	;
	; key 'd' - trigger an illegal instruction to enter
	; the debugger (if any).
	;
.debug	cmpi.b	#$20,d7
	bne.s	.ret
	tst.b	12(a0)          ; trainer: debug
	beq.s	.ret
	illegal

	; Return to the original key handling routine and
	; execute the instruction which has been modified
	; to jump into this routine.
.ret	movem.l	(a7)+,d0-d2/a0-a2
	cmpi.b	#$39,d7
	rts

	;
	; End of the block of resident code providing trainer
	; mode support.
	;
tr_resid_end

	;
	; tr_neverfall()
	;
	; Implement the 'fall into the sky' trainer option.
	; The original game code is patched so that when the
	; character moves down, this routine is called to update
	; (and control) its vertical position.
	; The following routine is copied into a free area of the
	; main game program (replacing checksum routine #10).
	;
tr_neverfall
	; Increment the character's vertical position.
	addq.w	#8,$2cf8.w
	; If the character reaches the low border, then
	; reset its vertical position to zero.
	; As a result, the character will end up in the sky
	; and will continue to fall from there.
	cmpi.w	#$110,$2cf8.w
	blt.s	.ret
	clr.w	$2cf8.w
.ret	rts
tr_neverfall_end

	;
	; tr_force()
	;
	; Implement the infinite energy, infinite money and
	; max firepower options.
	; The original game code is patched so that this routine
	; is called when the status bar needs to be redrawn.
	; Each 'bra.s' instruction below is replaced by a 'nop'
	; by the game_patch() routine if the corresponding trainer
	; option is enabled.
	; The following routine is copied into a free area of the
	; main game program (replacing checksum routine #7).
	;
tr_force
tr_nrg
	bra.s	tr_money
	; Force the energy to the max value (99).
	move.w	#$78,$2da8.w
tr_money
	bra.s	tr_fpower
	; Force the money to the max value (990).
	move.w	#$990,$2dae.w
tr_fpower
	bra.s	.ret
	movem.l	d0/a0,-(a7)
	; Force the firepower of the 16 weapons
	; to the max value (256).
	lea	$9b8.w,a0
	moveq.l	#-1,d0
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	move.l	d0,(a0)+
	movem.l	(a7)+,d0/a0

.ret	; Return to the game code and execute the instruction
	; which has been modified to jump into this routine.
	move.w	$2da8.w,d7
	rts
tr_force_end

	;
	; Information for the installation of the previous
	; trainer routines: routines lengths, offsets of the
	; routines within the block of code, destination
	; addresses.
	;

TR_RESID_LEN               =	(tr_resid_end-tr_resid_start)
TR_TBL_OFF                 =	(tr_tbl-tr_resid_start)
TR_KEYS_OFF                =	(tr_keys-tr_resid_start)

TR_NEVERFALL_LEN           =	(tr_neverfall_end-tr_neverfall)
TR_NEVERFALL_DEST_OFF      =	$9872

TR_FORCE_LEN               =	(tr_force_end-tr_force)
TR_FORCE_DEST_OFF          =	$963e

***************************************************************************
*
* 14. Installation and start of the game
*
* This section provides the code in charge of installing and starting
* the game.
*
* The startup sequence and the memory layout (where components are
* installed) are as follows:
*
* 1) Game startup sequence
*
* First, the game_boot() routine installs the 'game_install' code block
* in low memory where it can be safely executed.
* The 'game_install' block includes the following routines:
*   10. FDC/DMA support
*   11. Game files loading support
*   12. Game files unpacking support
*   13. Game modifications (cracking, enhancements, bug-fixes...)
*   14. Installation and start of the game (this part)
*
* Then, the game_install() routine (the entry point of the 'game_install'
* code block) in executed from low memory in order to:
*   - Install the ramdisk(s) if any.
*   - Launch the initial animation.
*   - Load and depack the main game program.
*   - Call game_patch() to patch the main game program and install
*     all blocks of resident code that implement game enhancements
*     (new game file loading, new unpacking routine, multi-machines
*     support, trainer mode...).
*   - Start the main game program.
*
* 2) Game memory layout
*
* The game uses fixed partitioning of the first 512 kilobytes of memory,
* enforcing the location of the following components:
*   - The main program
*     It is the only resident program; it is in charge of loading and
*     executing the various subprograms and providing them with common
*     services.
*   - The subprograms
*     They are loaded when needed; they implement the different modules
*     of the game (game levels, info & weapon shops, secret passages,
*     bonus rooms, boss parts, brick game) as well as the various screens
*     (presentation screens, level map, level magician, game over, high
*     score, game finale).
*   - The global data shared between the main program and subprograms.
*   - The temporary loading area.
*   - The DMA/FDC track buffer.
*
* Very little memory is available (ie not used by the game).
* To maximize available space in low memory and in particular to have
* a large slot of free memory at [$1c0-$800], the following components
* originally present in the game have been moved or removed:
*   - The Pack-Ice depack routine originally located at [$140-$294] has
*     been removed because the UPX depack routine is now used.
*   - Magic values (part of the copy-protection) originally located
*     at [$294-$2b0] and [$4a0-$4ac] have been removed because all
*     checksum routines are now neutralized (see section 8 for details
*     on the copy-protection).
*   - The game stack originally located at [$2b0-$492] has been moved to
*     [$2e00-$3000] (in an unused area).
*   - The track decoding routine originally located at [$700-$730] has
*     been removed because track loading has been replaced by file loading.
*
* The resulting memory slot is used to install most resident code blocks
* that provide game enhancements:
*   - the UPX depack routine
*   - the resident trainer code
*   - the overscan fix table
*   - the improved keyboard routines
*
* However, some components are placed in high memory only:
*   - the improved PSG/replay routines
*   - the optimized rasters support (high score screen)
*   - the 50Hz-VBL emulation routines
*   - the movep emulation routine
*   - the crash handlers (for debugging purposes)
*   - the ramdisk data
*
* Some blocks of resident code are even installed directly into the main
* program of the game, replacing pieces of disabled code.
* For instance the new DMA/FDC/ramdisk loading routines are installed in
* place of the original track loading routines.
* Similarly, several bug-fixing routines are installed in place of the
* original copy-protection code.
*
* Importantly, depending on the memory available, some components are
* installed in different locations or are absent:
*
*   - On machine with only 512KB of RAM (STf/STe family):
*
*     All resident code is installed into [$1c0-$800] and the stack pointer
*     is set to $3000 (which is possible because the [$2e00-$3000] area
*     is not used by the game).
*
*     Improved PSG/replay routines, optimized rasters support, 50Hz-VBL
*     emulation code, movep emulation code, the crash handlers and the
*     ramdisk are not used on these machines.
*
*   - On machines with 1MB or more (STf/STe family, TT, falcon, CT60):
*
*     The UPX depack routine, the resident trainer code and the overscan
*     fix table are installed into [$1c0-$700].
*
*     Improved keyboard routines are installed in high memory so that
*     the [$700-$800] area is not modified.
*
*     Indeed, this area contains the MMU table on TT & Falcon030 machines.
*     It should be noted that on CT60 (with CT60 TOS by Didier Mequignon),
*     the MMU table is installed at the end of the ST RAM or SDRAM.
*
*     Improved PSG/replay routines, optimized rasters support, 50Hz-VBL
*     emulation code, movep emulation code, crash handlers code, ramdisk
*     data and the stack are placed in high RAM (above the first 512KB
*     of ST RAM).
*
* Here is the original memory layout (of the unmodified game):
*
*    +---------------------------------+     $0
*    ! Exception vectors               !
*    !---------------------------------!   $140
*    ! Pack-Ice depack routine         !
*    !---------------------------------!   $294
*    ! Magic values (protection)       !
*    !---------------------------------!   $2b0
*    ! Stack                           !
*    !---------------------------------!   $492
*    ! Unused                          !
*    !---------------------------------!   $4a0
*    ! Magic values (protection)       !
*    !---------------------------------!   $4ac
*    ! Unused                          !
*    !---------------------------------!   $700
*    ! Track decoding routine          !
*    !---------------------------------!   $730
*    ! Unused                          !
*    !---------------------------------!   $800
*    ! Global game data                !
*    !---------------------------------!  $2e00
*    ! Unused                          !
*    !---------------------------------!  $3000
*    ! Main game program               !
*    !---------------------------------! $12d04
*    ! Game subprograms & data         !
*    !.................................! $628e0
*    ! Temporary loading area          !
*    !.................................! $7ee00
*    ! DMA/FDC track buffer            !
*    !=================================! $80000
*    ! DMA/FDC loading cache    [>1MB] !
*    +---------------------------------+
*
* Here is the new memory layout (of the improved game):
*
*    +---------------------------------+     $0
*    ! Exception vectors               !
*    !---------------------------------!    $94
*    ! Shared variables                !
*    !---------------------------------!    $b8
*    ! Exception vectors               !
*    !---------------------------------!   $1c0
*    ! UPX depack routine              !
*    !.................................!
*    ! Resident trainer code           !
*    !.................................!
*    ! Overscan fix table [>8MHz 60Hz] !
*    !.................................!
*    ! Keyboard routines       [512KB] !
*    !   OR                            !
*    ! Unused                   [>1MB] !
*    !---------------------------------!   $700
*    ! Keyboard routines       [512KB] !
*    !   OR                            !
*    ! 68030 MMU table         [68030] !
*    !---------------------------------!   $800
*    ! Global game data                !
*    !---------------------------------!  $2e00
*    ! Stack                   [512KB] !
*    !---------------------------------!  $3000
*    ! Main game program               !
*    !---------------------------------! $12d04
*    ! Game subprograms & data         !
*    !.................................! $628e0
*    ! Temporary loading area          !
*    !.................................! $7fe00
*    ! DMA/FDC sector buffer           !
*    !=================================! $80000
*    ! Keyboard routines        [>1MB] !
*    !.................................! $80800
*    ! PSG/Replay routines      [>1MB] !
*    !.................................!
*    ! Rasters support          [>1MB] !
*    !.................................!
*    ! 50Hz-VBL emulation  [>1MB 60Hz] !
*    !.................................!
*    ! movep emulation     [>1MB CT60] !
*    !.................................!
*    ! Crash Handlers           [>1MB] !
*    !---------------------------------! $84800
*    ! Stack                    [>1MB] !
*    !---------------------------------! $85000
*    ! Ramdisk                  [>1MB] !
*    +---------------------------------+
*
* Caption:
*
*    [512KB] .... On machines with only 512KB of RAM
*    [>1MB] ..... On machines with 1MB of RAM or more
*    [>8MHz] .... On fast machines (16MHz MegaSTe, Falcon, TT, CT60)
*    [68030] .... On Falcon030 & TT machines
*    [CT60] ..... On CT60 machines
*    [60Hz] ..... On machines connected to a 60Hz monitor (VGA, NTSC)
*
* Public routines:
* - game_install() [executed from low memory]
* - game_boot()
*
***************************************************************************

	;
	; Memory layout definition
	;
	; Defines the addresses where all components are placed
	; during the installation of the game.
	;
	; See comments above (section 9) for a full description
	; of the memory layout.
	;
	; See game_install() and game_patch() for details about
	; game installation.
	;

GAME_INST_ADDR             =	$1000
GAME_DEST_ADDR             =	$3000
GAME_STACK_ADDR_LOW        =	$3000   ; was $492 originally
GAME_STACK_ADDR_HIGH       =	$85000
FILEOPS_ADDR               =	(GAME_DEST_ADDR+$5360)
FILE_LOAD_ADDR             =	$628e0
SWAP_DISK_DEST_ADDR        =	$7ee00
ANIM_DEST_ADDR             =	$70000
TMP_SCREEN_ADDR            =	$77000
SECTOR_BUF_ADDR            =	$7fe00  ; was $7ee00 originally

DRVA_RAMDISK_ADDR          =	GAME_STACK_ADDR_HIGH

RESID_ADDR_LOW             =	$1c0
DEPACK_ADDR                =	RESID_ADDR_LOW
TRAINER_RESID_ADDR         =	(DEPACK_ADDR+DEPACK_LEN)
OVERSCAN_FIX_TBL_ADDR      =	(TRAINER_RESID_ADDR+TR_RESID_LEN)
KEYB_FIX_RESID_ADDR_LOW    =	(OVERSCAN_FIX_TBL_ADDR+OVERSCAN_FIX_TBL_LEN)
KEYB_FIX_RESID_ADDR_HIGH   =	($80000+KEYB_FIX_RESID_ADDR_LOW)
PSG_FIX_RESID_ADDR         =	$80800
RASTERS_RESID_ADDR         =	(PSG_FIX_RESID_ADDR+PSG_FIX_FULL_LEN)
TIMER50HZ_RESID_ADDR       =	(RASTERS_RESID_ADDR+RASTERS_FULL_LEN)
MOVEP_EMUL_RESID_ADDR      =	(TIMER50HZ_RESID_ADDR+TIMER50HZ_LEN)
CRASH_HANDLERS_RESID_ADDR  =	(MOVEP_EMUL_RESID_ADDR+MOVEP_EMUL_LEN)
RESID_ADDR_HIGH_END        =	(CRASH_HANDLERS_RESID_ADDR+CRASH_HANDLERS_LEN)

BG_COL                     =	$94
;TIMER50HZ_TRAP            =	$98     ; trap#6
;TIMER50HZ_COUNT           =	$9c
TPA                        =	$a0
KEYB_FIX_RESID_PTR         =	$a4
PSG_FIX_RESID_PTR          =	$a8
;KEYB_DATA                 =	$b0
;KEYB_PTR_JOY              =	$b4

	;
	; game_install()
	;
	; Bootstrap code which installs and boots the game:
	; - optionally install libraries in high RAM, 
	; - launch the initial animation,
	; - load & depack the main program of the game,
	;   patch it and start it.
	;
	; This installation routine (and all code & data it
	; depends on) is copied to a low memory address ($1000) 
	; where it is executed.
	; It ensures that it does not overlap with the memory
	; areas where data are installed.
	;
	; A descriptor, so-called game installation metadata,
	; details the operations which shall be performed by the
	; routine. It is filled either by the prepare_drv_a()
	; routine or by the prepare_drv_hd() routine, depending
	; on the drive from which the game runs (A or HDD).
	; This descriptor specifies:
	;
	; - if the game is executed from drive A and the machine
	;   has at least 1MB of RAM:
	;   the high memory area where the library #1 (disk#1)
	;   shall be loaded (ramdisk mode).
	;
	; - if the game is executed from a HDD and the machine
	;   has at least 2MB of RAM:
	;   the high memory areas where the two libraries shall
	;   be moved (in case of HDD usage, both libraries have
	;   been previously loaded into arbitrary RAM areas and
	;   must now be moved into high memory).
	;
game_install
	; First, disable running HW drivers.
	bsr	hw_setup

	; The $6c vector is used by the game to indicate if the
	; sectors loading cache (located at [$7ee00-$80000])
	; has been corrupted. Clear it.
	clr.l	$6c.w

	; Game installation metadata describing the operations
	; which shall be performed.
	lea	inst_info(pc),a2

	;
	; Case where the game is executed from HDD:
	; Move the two libraries into high RAM.
	;

.move1	move.l	INST_RAM_SIZE1(a2),d0
	beq.s	.move2
	movea.l	INST_RAM_SRC1(a2),a0
	movea.l	INST_RAM_DST1(a2),a1
	bsr	mem_copy
	
.move2	move.l	INST_RAM_SIZE2(a2),d0
	beq.s	.anim
	movea.l	INST_RAM_SRC2(a2),a0
	movea.l	INST_RAM_DST2(a2),a1
	bsr	mem_copy

	;
	; Load and start the initial animation.
	;

	; Load initial animation program (file #2).
.anim	moveq.l	#2,d0
	lea	FILE_LOAD_ADDR,a1
	bsr	read_file

	; Depack it at the expected location ($70000).
	movea.l	a1,a0
	lea	ANIM_DEST_ADDR,a1
	bsr	decrunch_routine

	; Patch the animation code so that it won't load the
	; main program (which is loaded hereafter).
	move.w	#$4e75,$fe(a1)

	; Start the animation.
	jsr	(a1)

	; Hook the VBL handler of the animation program to
	; increment a vblank counter.
	; It is used to ensure that the animation runs for a
	; minimum of time even if the initial game data is
	; loaded very quickly, typically from the ramdisk.
	; See .wait below.
	clr.l	$40.w
	lea	anim_vbl(pc),a0
	move.l	$70.w,(anim_vbl_jmp+2-anim_vbl)(a0)
	move.l	a0,$70.w

	;
	; Case where the game is executed from floppy disk
	; and a ramdisk can be used:
	; load library #1 (disk#1) in high RAM.
	;
	move.l	INST_LIB1_SIZE(a2),d1
	beq.s	.chk2
	move.l	INST_LIB1_OFF(a2),d0
	movea.l	INST_LIB1_ADDR(a2),a0
	lea	lib_info1(pc),a1
	bsr	read_library
	tst.l	d0
	bmi	read_file_error

	;
	; Check the integrity of the libraries that have just
	; been loaded into high RAM.
	;

	; Check library #1 when loaded from the floppy disk.
.chk1	bsr	verify_library
	tst.l	d0              ; Checksum valid (= 0)?
	beq.s	.mainld         ; If not, disable ramdisk
	moveq.l	#-1,d0
	move.l	d0,LIB_RAM_OFF(a1)
	bra.s	.mainld

	; Check both libraries when loaded from HDD.
.chk2	move.l	INST_RAM_SIZE1(a2),d0
	beq.s	.chk3
	movea.l	INST_RAM_DST1(a2),a0
	bsr	verify_library
	tst.l	d0              ; Checksum valid (= 0)?
	bne	read_file_error ; If not, fatal error

.chk3	move.l	INST_RAM_SIZE2(a2),d0
	beq.s	.mainld
	movea.l	INST_RAM_DST2(a2),a0
	bsr	verify_library
	tst.l	d0              ; Checksum valid (= 0)?
	bne	read_file_error ; If not, fatal error

	;
	; Install and start the main game program.
	;

	; Load the main game program (file #3).
.mainld	moveq.l	#3,d0
	lea	FILE_LOAD_ADDR,a1
	bsr	read_file

	; Depack it at the expected location ($3000).
	movea.l	a1,a0
	lea	GAME_DEST_ADDR.w,a1
	bsr	decrunch_routine

	; Patch it in order to:
	; - crack it properly
	; - enable the trainer mode
	; - add linkfile/ramdisk support
	; - add multi-machines support
	; - fix bugs
	bsr	game_patch

	; Before executing the game code, first cleanup
	; the memory area [$800 - $3000] where the game
	; stores its global data.
	; Copy the corresponding routine to a safe area
	; where it will be executed.
	lea	game_cleanup(pc),a0
	lea	SWAP_DISK_DEST_ADDR,a1
	move.w	#game_cleanup_end-game_cleanup,d0
	bsr	mem_copy

	; Everything is ready, the main program of the game can
	; be executed, just ensure that the animation runs for a
	; minimum amount of time (3 or 4 seconds depending on the
	; refresh rate) regardless of the speed at which the
	; initial game data was loaded.
.wait	cmpi.l	#50*4,$40.w
	blo.s	.wait
	move.l	anim_vbl_jmp+2(pc),$70.w

	; Execute the trampoline routine which cleans up the
	; global data and runs the main program.
	movea.l	a1,a7
	jmp	(a1)

	;
	; Cleanup the memory area where the game stores
	; its global data, and jump to the entry point
	; of the main game program.
	;
game_cleanup
	lea	$800.w,a0
	move.w	#(GAME_DEST_ADDR-$800)/4-1,d0
.wr_lp
	ifne	DEBUG
	move.l	#$77777777,(a0)+
	elseif
	clr.l	(a0)+
	endc
	dbf	d0,.wr_lp

	; Set the game stack pointer.
	movea.l	$61a8(a0),a7

	; Go!
	jmp	(a0)
game_cleanup_end

	;
	; hw_setup()
	;
	; Disable running HW drivers.
	;
	; Set up HW registers and interrupt vectors:
	; - MFP interrupts are stopped
	; - Timers are stopped
	; - Mouse & joystick are disabled
	; - Dummy interrupt handlers are installed
	; - Colors are set to 0
	; - A temporary video buffer is set up
	;
hw_setup
	movem.l	d0/a0-a1,-(a7)

	;
	; Mask all MFP interrupts and stop all timers.
	;
	clr.b	$fffffa07.w
	clr.b	$fffffa13.w
	clr.b	$fffffa09.w
	clr.b	$fffffa15.w
	move.b	#$10,$fffffa19.w    ; reset
	move.b	#$10,$fffffa1b.w    ; reset
	clr.b	$fffffa1d.w
	clr.b	$fffffa19.w
	clr.b	$fffffa1b.w

	;
	; Mask all MFP2 (TT) interrupts and stop all timers.
	;
	move.w	mach_type(pc),d0
	cmpi.b	#MCH_TT,d0
	bne.s	.ikbd
	clr.b	$fffffa87.w
	clr.b	$fffffa93.w
	clr.b	$fffffa89.w
	clr.b	$fffffa95.w
	clr.b	$fffffa9d.w
	clr.b	$fffffa99.w
	clr.b	$fffffa9b.w

	;
	; Disable mouse & joystick.
	;
.ikbd	lea	$fffffc00.w,a0
	move.b	#$12,d0
	bsr	keyb_send
	bsr	keyb_flush
	move.b	#$1a,d0
	bsr	keyb_send
	bsr	keyb_flush

	;
	; Install a dummy handler for all interrupt vectors
	; including the 'Spurious Interrupt' vector that might be
	; triggered when tweaking the MFP.
	;

	lea	$74.w,a0

	lea	$60.w,a1
	moveq.l	#($7c-$60)/4,d0
.vecs1	move.l	a0,(a1)+
	dbf	d0,.vecs1

	lea	$100.W,a1
	move.w	#($1bc-$100)/4,d0
.vecs2	move.l	a0,(a1)+
	dbf	d0,.vecs2

	move.w	#$4e73,(a0)+

	; Vsync
	stop	#$2300

	; Set all colors to black.
	lea	$ffff8240.w,a0
	moveq.l	#7,d0
.clear	clr.l	(a0)+
	dbf	d0,.clear

	; Set a temporary video buffer.
	move.b	#((TMP_SCREEN_ADDR>>16)&$ff),$ffff8201.w
	move.b	#((TMP_SCREEN_ADDR>>08)&$ff),$ffff8203.w
	clr.b	$ffff820d.w

	; Vsync
	stop	#$2300
	stop	#$2300
	move.w	#$2700,sr

	movem.l	(a7)+,d0/a0-a1
	rts

	;
	; anim_vbl()
	;
	; VBL hook, providing a vblank counter.
	;
	; The VBL handler of the animation program is hooked
	; to increment a vblank counter (at $40).
	; It is used to ensure that the animation runs for a
	; minimum of time even if the initial game data is
	; loaded very quickly, typically from the ramdisk.
	;
anim_vbl
	addq.l	#1,$40.w
anim_vbl_jmp
	jmp	$0.l

	;
	; mem_copy()
	;
	; Copy a memory region.
	;
	; - Handle possible overlap between source and
	;   destination areas.
	; - The memory region is copied by chunks of 32 bytes
	;   (as a result, the size of the copied data is a
	;   multiple of 32 bytes).
	; - This routine is used when preparing the game
	;   (installing the 'game_install' code & data block,
	;   moving libraries into high RAM...).
	;
	; In:
	;   d0: number of bytes to be copied
	;   a0: source address
	;   a1: destination address
	;  
mem_copy
	movem.l	d0-d7/a0-a2,-(a7)

	; Nothing to copy if source = destination.
	cmpa.l	a0,a1
	beq.s	.ret

	; Copy by chunks of 32 bytes.
	lsr.l	#5,d0
	; Handle possible overlap of src/dst areas.
	cmpa.l	a0,a1
	bhi.s	.revers

	; Copy from the beginning of the area.
.cp1	movem.l	(a0)+,d1-d7/a2
	movem.l	d1-d7/a2,(a1)
	lea	8*4(a1),a1
	dbf	d0,.cp1
	bra.s	.ret

	; Copy from the end of the area.
.revers	move.l	d0,d1
	addq.l	#1,d1
	lsl.l	#5,d1
	adda.l	d1,a0
	adda.l	d1,a1

.cp2	lea	-8*4(a0),a0
	movem.l	(a0),d1-d7/a2
	movem.l	d1-d7/a2,-(a1)
	dbf	d0,.cp2

.ret	movem.l	(a7)+,d0-d7/a0-a2
	rts

	;
	; verify_library()
	;
	; Check the integrity of a library that has just been
	; loaded into memory.
	; To this end, verify that the checksum on the content
	; of that library is equal to 0.
	;
	; In:
	;   d0: size of the library in memory
	;   a0: address of the library in memory
	;
	; Out:
	;   d0: 0 if the checksum is valid, !0 otherwise
	;
verify_library
	movem.l	d1/a0,-(a7)

	; The size of a library is a multiple of 16-bytes.
	move.l	d0,d1
	lsr.l	#4,d1
	subq.l	#1,d1
	moveq.l	#0,d0
.chksum	rept	4
	add.l	(a0)+,d0
	endr
	dbf	d1,.chksum

	; d0=0 if the checksum is valid, !0 otherwise.
	movem.l	(a7)+,d1/a0
	rts

	; Machine type used to customize the patching of the game.
mach_type
	ds.w	1

	;
	; Game installation metadata:
	; Structure describing the operations which shall be
	; performed by the game_install() bootstrap routine.
	; [inst_info - inst_info_end]
	;
inst_info
	; Area in high RAM where library #1 shall be loaded
	; as a ramdisk (floppy disk support).
	; Also specifies the offset and length of the data
	; from library #1 to be loaded into the ramdisk.
ii_lib1_addr
	dc.l	0
ii_lib1_off
	dc.l	0
ii_lib1_size
	dc.l	0

	; Source area containing one of the two libraries and
	; destination area in high RAM where it must be moved
	; (HDD support).
ii_ram_src1
	dc.l	0
ii_ram_dst1
	dc.l	0
ii_ram_size1
	dc.l	0

	; Source area containing the other of the two libraries
	; and destination area in high RAM where it must be moved
	; (HDD support).
ii_ram_src2
	dc.l	0
ii_ram_dst2
	dc.l	0
ii_ram_size2
	dc.l	0
inst_info_end

	;
	; Offsets within the previous structure.
	;
INST_LIB1_ADDR  =	(ii_lib1_addr-inst_info)
INST_LIB1_OFF   =	(ii_lib1_off-inst_info)
INST_LIB1_SIZE  =	(ii_lib1_size-inst_info)
INST_RAM_SRC1   =	(ii_ram_src1-inst_info)
INST_RAM_DST1   =	(ii_ram_dst1-inst_info)
INST_RAM_SIZE1  =	(ii_ram_size1-inst_info)
INST_RAM_SRC2   =	(ii_ram_src2-inst_info)
INST_RAM_DST2   =	(ii_ram_dst2-inst_info)
INST_RAM_SIZE2  =	(ii_ram_size2-inst_info)

	;
	; End of the 'game_install' code & data block containing
	; all the routines needed during the installation and the
	; start of the game.
	;
game_install_end

	;
	; Length of the 'game_install' code & data block.
	;
GAME_INSTALL_LEN           =	(game_install_end-game_install_start)

	;
	; Offset of the game_install() routine within the
	; 'game_install' block.
	;
GAME_INSTALL_OFF           =	(game_install-game_install_start)

	;
	; game_boot()
	;
	; Install the 'game_install' code & data block in low
	; memory and execute the game_install() bootstrap routine
	; from there. It will install and start the game.
	;
	; See game_install() for details.
	;
	; Called from supexec, but never returns.
	;
game_boot
	; Point of no return: we mask all interrupts as we are
	; going to overwrite the low memory (used by the TOS)
	; to install the 'game_install' block, therefore we will
	; break the OS and make any return impossible.
	move.w	#$2700,sr

	; Install the 'game_install' block at address $1000.
	lea	game_install_start(pc),a0
	lea	GAME_INST_ADDR.w,a1
	move.l	#GAME_INSTALL_LEN,d0
	bsr	mem_copy

	; Save end of TPA for future use.
	ifne	FORCE_512KB
	move.l	#$78000,TPA.w
	elseif
	move.l	$436.w,TPA.w
	endc

	; Clear the low memory where resident code is installed.
	; As a side effect, this ensures that memvalid, memval2
	; and resvalid (system variables) are cleared and thus
	; that the machine can be reset properly.
	lea	RESID_ADDR_LOW.w,a0
	move.w	#($700-RESID_ADDR_LOW)/4-1,d0
.clear	clr.l	(a0)+
	dbf	d0,.clear

	; Update the stack pointer and execute game_install().
	movea.l	a1,a7
	jmp	GAME_INSTALL_OFF(a1)
	; Never returns.

***************************************************************************
*
* 15. Game preparation
*
* The following code prepares everything necessary for installing and
* starting the game, including:
* - Checking if the game can run in the current configuration (machine
*   type, current drive, available memory, MMU root pointer...).
* - Determining which trainer options shall be implemented.
* - Opening library #1 (disk#1) if the game is running from a floppy disk.
*   This will set up the context used by the low-level DMA/FDC routines to
*   access the library file on the floppy disk.
* - Determining if a ramdisk can be used (if enough memory is available).
* - Pre-loading disk#1 & disk#2 libraries (containing all the game files
*   linked together) in memory if the game is running from a hard-drive.
*
* Public routines:
* - sanity_checks()
* - setup_trainer()
* - prepare_drv_a()
* - prepare_drv_hd()
*
***************************************************************************

	;
	; sanity_checks()
	;
	; Perform sanity checks such as machine type,
	; current drive, available memory, MMU root
	; pointer...
	;
	; Out:
	;   d0: 0 if OK, an error code otherwise
	;
sanity_checks
	movem.l	d1/a0-a1,-(a7)

	; Internal/debug sanity checks: verify that the resident
	; code blocks fit in their destination areas.
	ifne	DEBUG

	bsr.s	.chk
	dc.l	($894e-$8360)-FILEOPS_LEN
	dc.l	KEYB_FIX_RESID_ADDR_LOW 
	dc.l	($800-KEYB_FIX_RESID_ADDR_LOW)-KEYB_FIX_LEN
	dc.l	GAME_INST_ADDR+GAME_INSTALL_LEN
	dc.l	RESID_ADDR_HIGH_END
.chk	movea.l	(a7)+,a0
	; Enough space for the 'fileops' block?
	tst.l	(a0)+
	bmi.s	.chkerr
	; Enough space in Falcon/TT low memory for the resident
	; code? (do not overwrite the 68030 MMU table).
	cmpi.l	#$700,(a0)+
	bhi.s	.chkerr
	; Enough space in ST low memory for the resident code?
	tst.l	(a0)+
	bmi.s	.chkerr
	; Does the 'game_install' block overlap the main game
	; program?
	cmpi.l	#GAME_DEST_ADDR,(a0)+
	bhi.s	.chkerr
	; Is the end of the resident code in high memory
	; below the limit?
	cmpi.l	#GAME_STACK_ADDR_HIGH-$800,(a0)+
	bhi.s	.chkerr
	bra.s	.chkok
.chkerr	moveq.l	#EGEN,d0
	bra.s	.ret
.chkok
	endc	; DEBUG

	; Get the end address of the user memory.
	lea	get_tpa_end(pc),a0
	XCALL	supexec
	movea.l	d0,a0

	; Get the machine type.
	move.w	mach_type(pc),d1

	cmpi.b	#MCH_MEGASTE,d1
	bls.s	.mch_ram_ok

	; 1 MB of RAM is required on TT/Falcon/CT60.
	cmpa.l	#$80000,a0
	bhi.s	.mch_ram_ok
	moveq.l	#EMCH1M,d0
	bra.s	.ret
.mch_ram_ok
	; Get the current drive.
	XCALL	getdrv
	tst.l	d0
	beq.s	.drv_ram_ok

	; Running from drive B is not supported.
	cmpi.w	#1,d0
	bne.s	.drv_ok
	moveq.l	#EDRV,d0
	bra.s	.ret
.drv_ok
	; 2 MB of RAM is required if running from HDD.
	cmpa.l	#$100000,a0
	bhi.s	.drv_ram_ok
	moveq.l	#EHD2M,d0
	bra.s	.ret
.drv_ram_ok
	; Check if the MMU root pointer is in a safe area.
	XADDR	mach_rp,a1
	move.l	(a1),d0
	beq.s	.mmu_ok
	btst	#MCH_CT60_BIT,d1
	bne.s	.mmu_ct60
	; MMU RP located at $700 on 68030 is OK.
	cmpi.l	#$700,d0
	beq.s	.mmu_ok
.mmu_ct60
	; MMU RP located beyond TPA is OK.
	cmpa.l	d0,a0
	bls.s	.mmu_ok
	; MMU RP is not in a safe area.
	moveq.l	#EMMU,d0
	bra.s	.ret
.mmu_ok
	moveq.l	#0,d0

.ret	movem.l	(a7)+,d1/a0-a1
	rts

	;
	; setup_trainer()
	;
	; Copy the trainer mode configuration from the trainer
	; options table used by the trainer menu (opts_info)
	; into the game-specific table (tr_info).
	;
	; The game-specific table is resident and is used to patch
	; game programs on-the-fly to enable the selected trainer
	; options.
	;
	; Called from loader_part2_entry().
	;
setup_trainer
	movem.l	a0-a1,-(a7)

	XADDR	opts_info,a0
	lea	tr_info(pc),a1
	move.b	2+8*0+7(a0),(a1)    ; infinite lives
	move.b	2+8*1+7(a0),1(a1)   ; infinite energy
	move.b	2+8*2+7(a0),2(a1)   ; infinite time
	move.b	2+8*3+7(a0),3(a1)   ; infinite money
	move.b	2+8*4+7(a0),4(a1)   ; weapon selection
	move.b	2+8*5+7(a0),5(a1)   ; max firepower
	move.b	2+8*6+7(a0),6(a1)   ; fall into the sky
	move.b	2+8*7+7(a0),9(a1)   ; enter brick game
	move.b	2+8*8+7(a0),10(a1)  ; infinite brick lives
	move.b	2+8*9+7(a0),13(a1)  ; starting level
	subq.b	#1,13(a1)           ; [1-6] -> [0-5]

	movem.l	(a7)+,a0-a1
	rts

	;
	; fdc_deselect()
	;
	; Wait for the floppy disk drive A to shut down
	; and deselect the drive.
	;
fdc_deselect
	move.l	d0,-(a7)
.again	bsr	fdc_deselect_noblock
	tst.l	d0
	bne.s	.again
	move.l	(a7)+,d0
	rts

	;
	; getbpb_hook()
	;
	; Custom getbpb routine, registered in the getbpb vector
	; and called by the Bios to read the BPB.
	;
	; when called by the Bios for drive A, this routine makes
	; the mediach hook below return to standard behavior.
	; In any case, it calls the original getbpb routine to
	; read the BPB.
	;
	; Scratch: d0/a0
	;
getbpb_hook
	lea	mediach_hook+2(pc),a0
	move.w	4(a7),d0        ; Bios drive unit
	cmp.w	(a0),d0         ; mediach_hook() drive unit
	bne.s	getbpb_orig
	move.w	#-1,(a0)        ; Patch mediach_hook()
getbpb_orig
	jmp	$0.l            ; Original getbpb routine

	;
	; mediach_hook()
	;
	; Custom mediach routine, registered in the mediach vector
	; and called by the Bios to ask if the media has changed.
	;
	; When called by the Bios for drive A, and until the
	; getbpb hook above is called, this routine returns a
	; value indicating that the media in drive A has changed.
	; Then, it just calls the original mediach routine.
	;
	; Scratch: d0
	;
mediach_hook
	move.w	#0,d0           ; Drive A or -1
	cmp.w	4(a7),d0        ; Bios drive unit
	bne.s	mediach_orig
	moveq.l	#2,d0           ; Media definitely has changed
	rts
mediach_orig
	jmp	$0.l            ; Original mediach routine

	;
	; force_mediach()
	;
	; Force the TOS to update its internal state regarding
	; the FDC.
	;
	; The library containing the linked game files is opened 
	; by this loader using direct FDC/DMA programming (and
	; thus bypassing the TOS). This can cause the internal
	; TOS state to become inconsistent regarding the FDC.
	; By forcing the detection of the media change when
	; calling fsfirst(), we force the TOS to update (and fix)
	; its internal state regarding the FDC.
	; This function is only called if the library could not
	; be opened and the program has to return to GEMDOS.
	;
force_mediach
	movem.l	d0-d2/a0-a2,-(a7)

	; Hook the getbpb vector.
	lea	getbpb_hook(pc),a0
	move.l	$472.w,(getbpb_orig+2-getbpb_hook)(a0)
	move.l	a0,$472.w

	; Hook the mediach vector.
	lea	mediach_hook(pc),a0
	move.l	$47e.w,(mediach_orig+2-mediach_hook)(a0)
	move.l	a0,$47e.w

	; Force the TOS to update its internal state regarding
	; the FDC.
	move.w	#%100111,-(a7)
	XADDR	lib1_fname,a0
	move.l	a0,-(a7)
	move.w	#78,-(a7)
	trap	#1
	addq.l	#8,a7

	; Restore hooked vectors.
	move.l	getbpb_orig+2(pc),$472.w
	move.l	mediach_orig+2(pc),$47e.w

	movem.l	(a7)+,d0-d2/a0-a2
	rts

	;
	; read_sector_bootstrap()
	;
	; Determine the FDC seek rate according to the density of the
	; current floppy disk.
	; Standard 720KB floppies have a double density (DD) geometry
	; while 1.44MB floppies have a high density (HD) geometry.
	;
	; The HD mode (1.44MB floppies) is using twice the clock speed
	; (16MHz instead of 8MHz) for the FDC, so the FDC has to seek
	; "slower".
	; Therefore the seek rate is set to 3 ms for DD floppies
	; (720KB) and 6 ms for HD floppies (1.44MB).
	;
	; The density of the current floppy disk is determined by
	; reading the boot sector using the XBios Floprd call and
	; by checking the number of sectors per track: 13 sectors
	; or more indicate HD mode.
	;
	; This function is called by open_library() only once, the
	; first time open_library() is used. Then open_library() is
	; patched so that the call to read_sector_bootstrap() is
	; replaced with a call to read_sector().
	;
	; In:
	;   d0: 0 (boot sector)
	;   a0: buffer where the boot sector is loaded
	;   Floppy access is locked ($43e)
	;
	; Out:
	;   d0: 0 if success and di_seekrate is updated with the
	;       appropriate seek rate, EFDC (-1) if error
	;
read_sector_bootstrap
	movem.l	d1-d2/a0-a2,-(a7)

	tst.l	d0              ; Boot sector should be read?
	bne.s	.err            ;   if not, error

	sf	$43e.w          ; Unlock floppy access.

	; Read the boot sector.
	move.w	#1,-(a7)        ; 1 sector to be read
	move.w	#0,-(a7)        ; Side 0
	move.w	#0,-(a7)        ; Track 0
	move.w	#1,-(a7)        ; Sector 1
	move.w	#0,-(a7)        ; Drive A
	clr.l	-(a7)
	move.l	a0,-(a7)        ; Buffer
	move.w	#8,-(a7)        ; Floprd
	trap	#14
	lea	20(a7),a7

	st	$43e.w          ; Re-lock floppy access.

	tst.l	d0              ; Floprd error?
	bne.s	.err

	; Patch the 'bsr read_sector_bootstrap' instruction that
	; called us to replace it with a 'bsr read_sector'.
	movea.l	5*4(a7),a0      ; Return address
	subq.l	#4,a0           ; Points to 'bsr <addr>'
	cmpi.w	#$6100,(a0)+    ; Check the 'bsr' opcode
	bne.s	.err
	lea	read_sector(pc),a1
	suba.l	a0,a1
	move.w	a1,(a0)         ; Patch the 'bsr' offset

	; Determine the seek rate according to the geometry of
	; the floppy disk: 13 sectors or more indicate HD mode.
	movea.l	2*4(a7),a0      ; Boot sector buffer
	lea	dma_info(pc),a1
	moveq.l	#3,d1           ; Default DD seek rate = 3 ms
	cmpi.b	#13,BPB_SPT(a0) ; HD mode if 13 sectors or more
	blo.s	.save
	moveq.l	#0,d1           ; HD seek rate = 6 ms

	; Save the FDC seek rate so that it can be used by the
	; read_sector() routine.
.save	move.w	d1,DMA_SEEKRATE(a1)

.ret	movem.l	(a7)+,d1-d2/a0-a2
	rts
.err	moveq.l	#EFDC,d0
	bra.s	.ret

	;
	; prepare_drv_a()
	;
	; Prepare the game installation & boot, when drive A
	; is used.
	;
	; Support of drive A is achieved by making the game load
	; its files from 2 libraries (stored on 2 floppy disks)
	; containing all the game files linked together.
	;
	; If the machine has at least 1MB of RAM, the first
	; library is loaded in high RAM to act as a ramdisk.
	; Hence only floppy disk#2 needs to be inserted in
	; drive A. Disks swapping is thus avoided.
	;
	; To achieve this, the following routine:
	; - Opens library #1 (stored on floppy disk in drive A)
	;   to prepare the FDC/DMA loading context.
	; - Checks if a ramdisk can be used for library #1 and
	;   fills the game installation metadata accordingly.
	;   It will be used by the game_install() bootstrap
	;   routine to load library #1 into that ramdisk.
	;
	; Out:
	;   d0: 0 in case of success, an error code otherwise
	;
prepare_drv_a
	movem.l	d1/a0-a3,-(a7)

	; Calibrate the FDC/DMA delay loop.
	bsr	calibrate_delay

	; Allocate a temporary DMA/FDC cache buffer
	; for sector loading.
	move.l	#$200,d0
	XCALL	malloc
	tst.l	d0
	bne.s	.open
	moveq.l	#ENSMEM,d0
	bra.s	.ret

.open	; Lock floppy access.
	st	$43e.w

	; Open library #1 using direct FDC/DMA programming.
	movea.l	d0,a1
	lea	lib_info1(pc),a0
	bsr	open_library

	; Keep the floppy access locked in case of success.
	tst.l	d0
	bpl.s	.reset

	; Deselect drive A in case of error.
	bsr	fdc_deselect
	; Unlock floppy access.
	sf	$43e.w
	; Force the TOS to update its internal state regarding
	; the FDC.
	bsr	force_mediach
	; Return the error code.
	bra.s	.mfree

	; Reset some variables to default values.
.reset	moveq.l	#-1,d0
	move.l	#SECTOR_BUF_ADDR,LIB_CACHEBUF(a0)
	move.w	d0,LIB_CACHESEC(a0)
	move.l	d0,LIB_RAM_OFF(a0)
	move.l	d0,lib_info2-lib_info1+LIB_RAM_OFF(a0)

	;
	; Check if a ramdisk can be used for library #1.
	;

	;
	; Determine the offset and size of data from library #1
	; to be loaded into the ramdisk.
	;
	moveq.l	#0,d0
	; Library #1 will be loaded into the ramdisk
	; starting from file #4.
	move.w	LIB_FTABLE+8+(4*2)(a0),d0
	lsl.l	#4,d0
	; Deduce the ramdisk size.
	move.l	LIB_SIZE(a0),d1
	sub.l	d0,d1

	; Is a ramdisk possible (machine has at least 1MB)?
	lea	DRVA_RAMDISK_ADDR,a2
	lea	0(a2,d1.l),a3
	ifne	(FORCE_DRVA_NO_RAMDISK!FORCE_512KB)
	cmpa.l	#$78000,a3
	elseif
	cmpa.l	$436.w,a3
	endc
	bhi.s	.noram

	;
	; Library #1 is later loaded into the ramdisk by the
	; game_install() routine following the instructions
	; provided in the game installation metadata.
	; Those instructions are set up here.
	;
	lea	inst_info(pc),a3
	; Update the installation metadata: indicate the offset
	; and size of the data from library #1 to be loaded.
	move.l	d0,INST_LIB1_OFF(a3)
	move.l	d1,INST_LIB1_SIZE(a3)
	; Update the installation metadata: indicate the address
	; of the ramdisk in memory.
	move.l	a2,INST_LIB1_ADDR(a3)

	;
	; Save information about the ramdisk in the metadata
	; of library #1.
	;
	move.l	a2,LIB_RAM_ADDR(a0)
	move.l	d0,LIB_RAM_OFF(a0)

.noram	moveq.l	#0,d0

.mfree	; Free the temporary DMA/FDC cache buffer.
	movea.l	a1,a0
	XCALL	mfree

.ret	movem.l	(a7)+,d1/a0-a3
	rts

	;
	; load_file_hd()
	;
	; Allocate a memory block and load a library file
	; from HDD into it.
	;
	; In:
	;   a0: library file name
	;
	; Out:
	;   d0: library file size if success, or an error
	;       number otherwise
	;   a0: start of the memory block containing the
	;       library data
	;
load_file_hd
	movem.l	d0-d3,-(a7)

	; Open the library file.
	XCALL	fopen
	move.l	d0,d2
	bmi.s	.close

	; Get its size.
	XCALL	fsize
	move.l	d0,d3
	bmi.s	.close

	; Allocate a memory block of that size plus a margin to
	; cope with the alignment of destination addresses where
	; the library files are copied. See prepare_drv_hd().
	addi.l	#$400,d0
	XCALL	malloc
	tst.l	d0
	bne.s	.load
	moveq.l	#ENSMEM,d0
	bra.s	.close

	; Load the library file into it.
.load	movea.l	d0,a0
	move.l	d2,d0
	move.l	#$ffffff,d1
	XCALL	fread
	cmp.l	d0,d3
	beq.s	.close
	moveq.l	#EREADF,d0

	; Free the memory block in case of error.
	XCALL	mfree

	; Save the return value (library file size or error).
.close	move.l	d0,(a7)

	; Close the library file.
	move.l	d2,d0
	XCALL	fclose

	movem.l	(a7)+,d0-d3
	rts

	;
	; libdir_copy()
	;
	; Copy the directory (file table) of a library file to
	; the corresponding library info and check the integrity
	; of the directory.
	;
	; In:
	;   a0: start address of the library directory
	;   a3: library info
	;
	; Out:
	;   d0: 0 if the directory is valid, EPLFMT otherwise
	;
libdir_copy
	movem.l	d1-d3/a0-a1,-(a7)

	; Default error code.
	moveq.l	#EPLFMT,d0

	; First check the 2 magic values at the beginning of the
	; directory: 'REPS' and 'SSSx'.
	cmpi.l	#'REPS',(a0)
	bne.s	.ret
	move.l	4(a0),d1
	cmp.l	(a3),d1
	bne.s	.ret

	; The directory is valid if its integrity is intact that is
	; if the checksum on the directory content is equal to 0.
	; Copy the directory and calculate the checksum simultaneously.
	moveq.l	#(80*2)/4-1,d1
	moveq.l	#0,d2
	lea	LIB_FTABLE(a3),a1
.cp	move.l	(a0)+,d3
	add.l	d3,d2
	move.l	d3,(a1)+
	dbf	d1,.cp

	; Checksum OK?
	tst.l	d2
	bne.s	.ret

	; Directory is valid.
	moveq.l	#0,d0

.ret	movem.l	(a7)+,a0-a1/d1-d3
	rts

	;
	; prepare_drv_hd()
	;
	; Prepare the game installation & boot, when the HDD
	; is used.
	;
	; Support of HDD is achieved by making the game load its
	; files from RAM: if the machine has at least 2MB of RAM,
	; the two libraries containing all the games files linked
	; together are loaded in high RAM to act as ramdisks.
	;
	; To this end, the following routine:
	; - Loads both libraries from HDD to free memory (not
	;   necessarily in high memory).
	; - Fills the game installation metadata to indicate
	;   the high memory areas where those libraries shall
	;   be moved (by the game_install() bootstrap routine).
	;
	; Out:
	;   d0: 0 in case of success, an error code otherwise
	;
prepare_drv_hd
	movem.l	d1-d4/a0-a4,-(a7)

	ifne	DEBUG
	; Calibrate the FDC/DMA delay loop.
	lea	calibrate_delay(pc),a0
	XCALL	supexec
	endc

	; Get the end of TPA (top of user memory).
	lea	get_tpa_end(pc),a0
	XCALL	supexec
	move.l	d0,d4

	lea	inst_info(pc),a2
	lea	lib_info1(pc),a3
	lea	lib_info2(pc),a4

	; Allocate memory and load library #2.
	XADDR	lib2_fname,a0
	bsr	load_file_hd
	tst.l	d0
	bmi	.ret
	; Save the allocated memory area.
	move.l	d0,d1
	movea.l	a0,a1

	; Allocate memory and load library #1.
	XADDR	lib1_fname,a0
	bsr	load_file_hd
	tst.l	d0
	bmi	.free2

	;
	; Both libraries must be moved into high memory.
	; The library currently located at the highest
	; address in memory is moved first to the highest
	; possible area in RAM. The other library is moved
	; to the area located right before.
	; That way, we make sure copies are made safely,
	; without overlap.
	;
	cmpa.l	a0,a1
	bls.s	.save

	; Make sure the library which has been loaded in the
	; highest memory area is moved first.
	exg.l	d0,d1
	exg.l	a0,a1
	exg.l	a3,a4

.save	moveq.l	#0,d2
	move.l	d4,d3

	; Do not move the library if is has been loaded
	; in alt-RAM (beyond TPA).
	cmp.l	a0,d4
	bhi.s	.dst1
	move.l	a0,INST_RAM_DST1(a2)
	bra.s	.src1
	; Reserve space in high RAM for the first library.
.dst1	sub.l	d0,d3
	; Align the destination address.
	subi.l	#$ff,d3
	clr.b	d3
	; Update the game installation metadata.
	move.l	d3,INST_RAM_DST1(a2)
.src1	move.l	a0,INST_RAM_SRC1(a2)
	move.l	d0,INST_RAM_SIZE1(a2)
	; Update the corresponding library info.
	move.l	d2,LIB_RAM_OFF(a3)
	move.l	INST_RAM_DST1(a2),LIB_RAM_ADDR(a3)
	; Copy the library directory to it and check the integrity
	; of the directory.
	bsr	libdir_copy
	tst.l	d0
	bne.s	.free1

	exg.l	a4,a3
	; Do not move the library if is has been loaded
	; in alt-RAM (beyond TPA).
	cmp.l	a1,d4
	bhi.s	.dst2
	move.l	a1,INST_RAM_DST2(a2)
	bra.s	.src2
	; Reserve space in high RAM for the second library.
.dst2	sub.l	d1,d3
	; Align the destination address.
	subi.l	#$ff,d3
	clr.b	d3
	; Update the game installation metadata.
	move.l	d3,INST_RAM_DST2(a2)
.src2	move.l	a1,INST_RAM_SRC2(a2)
	move.l	d1,INST_RAM_SIZE2(a2)
	; Update the corresponding library info.
	move.l	d2,LIB_RAM_OFF(a3)
	move.l	INST_RAM_DST2(a2),LIB_RAM_ADDR(a3)
	; Copy the library directory to it and check the integrity
	; of the directory.
	exg.l	a0,a1
	bsr	libdir_copy
	tst.l	d0
	bne.s	.free1

	; Check if there is enough memory for HDD support
	; (machine should have at least 2MB).
	; r0 = 0
	cmpi.l	#DRVA_RAMDISK_ADDR,d3
	bhs.s	.ret
	moveq.l	#ENSMEM,d0

	; Error: free previously allocated memory.
.free1	XCALL	mfree
.free2	movea.l	a1,a0
	XCALL	mfree

.ret	movem.l	(a7)+,d1-d4/a0-a4
	rts

	;
	; get_tpa_end()
	;
	; Get the top of the available memory (end of TPA).
	;
	; Called from supexec.
	;
	; Out:
	;   d0: end of TPA
get_tpa_end
	ifne	FORCE_512KB
	move.l	#$78000,d0
	elseif
	move.l	$436.w,d0
	endc
	rts
