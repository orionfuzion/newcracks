***************************************************************************
*
* Son Shu Shi - First 100% Version
*
* Checksums removed, mega-trained, filed, repacked, linked, ramdisk,
* bug-fixed, hard-drive and MegaSTe/Falcon/TT/CT60 support.
*
* December 2022 - Orion of The Replicants.
*
* This code [LOADERH.S] is part of the loader of the game.
*
* The loader initializes the system, loads the main and hidden cracktros,
* prints the trainer menu, starts the game and patches the various programs
* of the game on-the-fly in order to implement all kinds of improvements.
*
* This header file (LOADERH.S) provides common definitions used by
* LOADER1.S (1st part of the loader) and LOADER2.S (2nd part).
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
	; Assembly options.
	;

	opt	o+              ; Turn all optimizations on
	opt	p+              ; Disallow non-PC addressing
	opt	c-              ; Case insensitive labels
	opt	U-              ; Use periods (.) for local labels

	;
	; Config options.
	;
STACK_SIZE              =	512
USE_LOAD_ANIM           =	1   ; Enable the "ghosts" animation
USE_LOWERCASE_FONTS     =	0   ; Enable lower case fonts
USE_ST_60HZ             =	0   ; 50Hz or 60Hz video on ST(e)
USE_VGA_60HZ            =	1   ; 50Hz or 60Hz VGA on Falcon/TT
USE_MEGASTE_16MHZ       =	1   ; 8MHz uncached or 16MHz cached CPU
USE_CRASH_HANDLERS      =	1   ; CPU crash handlers

	;
	; Speed of the color fade of the "ghosts" halo.
	;
FADEIN_HALO_STEPS       =	32
FADEIN_HALO_FACTOR      =	($10000/FADEIN_HALO_STEPS)
FADEOUT_HALO_STEPS      =	64
FADEOUT_HALO_FACTOR     =	($10000/FADEOUT_HALO_STEPS)
FADE_FONTS_STEPS        =	32
FADE_FONTS_FACTOR       =	($10000/FADE_FONTS_STEPS)

	;
	; Duration of the pause of the fade when the halo has the
	; darkest/lightest colors.
	;
FADE_WAIT_DARK_COUNT    =	32
FADE_WAIT_LIGHT_COUNT   =	16

	;
	; Debug options.
	;
DEBUG                   =	0
DEBUG_ASSERT            =	(DEBUG&USE_CRASH_HANDLERS&0)
DEBUG_REGS              =	(DEBUG&0)
HATARI_VIDEL_WORKAROUND =	(DEBUG&0)
DEBUG_LOAD_ANIM         =	(DEBUG&USE_LOAD_ANIM&0)
LOAD_ANIM_VBL_TIME      =	(DEBUG_LOAD_ANIM&(~HATARI_VIDEL_WORKAROUND)&0)
SOUNDTRACK_VBL_TIME     =	(DEBUG&(~HATARI_VIDEL_WORKAROUND)&0)
MERGE_PART2_SRC         =	(DEBUG&1)
NO_GAME_START           =	(DEBUG&0)
FORCE_LIBS_PATH         =	(DEBUG&0)
FORCE_DRVA              =	(DEBUG&0)
FORCE_DRVA_NO_RAMDISK   =	(DEBUG&0)
FORCE_LOW_STACK         =	(DEBUG&0)
FORCE_512KB             =	(DEBUG&0)
FORCE_ORIG_PSG          =	(DEBUG&0)
FORCE_OVERSCAN_FIX      =	(DEBUG&0)
FORCE_TIMER50HZ         =	(DEBUG&0)
FORCE_MOVEP_PATCH       =	(DEBUG&0)
DEBUG_WEAPON_LIMITS     =	(DEBUG&0)
DEBUG_TRAINER           =	(DEBUG&1)

DEBUG_VER               =	(DEBUG*32)
DEBUG_MAJ               =	((DEBUG_VER/10)+$30)
DEBUG_MIN               =	((DEBUG_VER-((DEBUG_VER/10)*10))+$30)

	;
	; Supported error codes.
	;
EFDC                    =	-1  ; FDC read error
EREADF                  =	-11 ; Library file read error
EFILNF                  =	-33 ; Library file not found
ENSMEM                  =	-39 ; Not enough memory
EPLFMT                  =	-66 ; Invalid program format
EGEN                    =	-92 ; Failed to set up the game
EMMU                    =	-95 ; Incompatible MMU root pointer
EDRV                    =	-96 ; Drive B not supported
EHD2M                   =	-97 ; HDD support requires 2MB of RAM
EMCH1M                  =	-98 ; This machine requires 1MB of RAM
EREZ                    =	-99 ; Incompatible screen resolution

	;
	; Machine types.
	;
MCH_ST                  =	$1
MCH_STE                 =	$2
MCH_MEGASTE             =	$3
MCH_TT                  =	$4
MCH_FALCON              =	$5
MCH_CT60_BIT            =	8
MCH_MSTE_16MHZ_BIT      =	9
MCH_VIDEO_60HZ_BIT      =	12
MCH_CT60                =	(1<<MCH_CT60_BIT)
MCH_MSTE_16MHZ          =	(1<<MCH_MSTE_16MHZ_BIT)
MCH_VIDEO_60HZ          =	(1<<MCH_VIDEO_60HZ_BIT)

	; Size of the 2nd part of the loader (LOADER2.S) in sectors.
	; The 2nd part of the loader is stored at the beginning of
	; library #1 (SSS1.LNK) and is loaded, dynamically linked
	; and executed by the 1st part of the loader (LOADER1.S).
PART2_SECTORS           =	19

	; Version number of the dynamic symbol tables.
DL_VERSION              =	8
	;
	; Macros defining dynamically linked symbols between the 1st
	; and 2nd part of the loader.
	; See loader_part2_link() in LOADER1.S for explanations about
	; this dynamic linking mechanism.
	;

	; Import a dynamic symbol.
	; And provide the means to access the corresponding external
	; routine or variable.
IMPORT	macro
	; Trampoline used to jump to the external routine located
	; in the other part.
TRAMP_\1
	; This illegal instruction is replaced with a 'jump' during
	; dynamic linking.
	dc.w	$4afc
ADDR_\1
	; This invalid address is replaced with the absolute address
	; of the dynamic symbol during dynamic linking.
	dc.l	$ffffff33
	endm

	; Export a dynamic symbol.
EXPORT	macro
	; Offset of the symbol (\1) from the current address (\@).
	; During dynamic linking, this offset allows to compute the
	; symbol absolute address and to update the corresponding
	; entry in the imported symbols table.
\@	dc.l	\1-\@
	endm

	; Call an external routine referenced by a dynamic symbol.
XCALL	macro
	; Go through the trampoline located in the imported symbols
	; table.
  	bsr	TRAMP_\1
	endm

	; Get the absolute address of an external word pointed to by
	; a dynamic symbol.
XADDR	macro
	; Get the address from the imported symbols table.
	movea.l	ADDR_\1(pc),\2
	endm
