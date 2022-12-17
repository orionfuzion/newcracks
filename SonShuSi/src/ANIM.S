
	***********************************************************
	*
	*   Son Shu Shi 100% + Replicants revival
	*
	*   DOM Ghosts 'Please Wait' animation v2.0
	*
	*   By Fury / The Replicants / Legacy
	*
	*   This source code implements the "ghosts" animation
	*   which is played while loading the hidden cracktro.
	*
	*   This file is included by LOADER1.S (the first part
	*   of the loader of the game).
	*
	*   You should read the comments at the beginning of
	*   LOADER1.S for a description of the organization and
	*   contents of the various source files of this crack.
	*
	***********************************************************

;
;;
;

M_INCLUDE_MACRO	SET 	1
	
	;

	include 	"GHOSTS.S"

	;

M_INCLUDE_MACRO	SET 	0

;
;;
;

;

M_SCROLL_IN_SCREEN 	EQU	90
M_SCROLL_HEIGHT 	EQU 	(M_DSHIFT_LINES)

;

M_BARREL_COUNT 	EQU	(16/M_DSHIFT_SPEED)

;

	;
	;; SW barrel 
	;

	;

M_BARREL_SIZE 	EQU	M_SCROLL_HEIGHT

	;

M_SCREEN_GAP 	EQU 	(200-(M_BARREL_COUNT*M_BARREL_SIZE))

	;

M_SCROLL_IN_BARREL_SLACK	EQU	0
M_SCROLL_BARREL_IN_SCREEN	EQU 	0
M_SCROLL_OFFSET_IN_BARREL 	EQU	0


	;

M_SCROLL_WINDOW_START	EQU 	(M_BARREL_COUNT>>1)*M_BARREL_SIZE
M_SCROLL_WINDOW_HEIGHT	EQU	((M_SCROLL_HEIGHT+M_SCREEN_GAP)>>1)

	;

	;
	;; Barrel roll for frame
	;

GhostBarrelRoll:
	lea  	ScreenBarrel(pc),a0
	move.l 	mach_conf+MACH2SCREEN+PHYSBASE(pc),d7

	; Active Barrel

	move.w 	(a0),d0
	moveq 	#0,d1
	move.w 	(ScreenBarrelOffset-ScreenBarrel)(a0,d0),d1
	add.l 	d7,d1

	; d1 = active barrel screen address

	; Barrel-1

	subq.w 	#2,d0
	moveq 	#0,d2
	move.w 	(ScreenBarrelOffset-ScreenBarrel)(a0,d0),d2
	add.l 	d7,d2
	; d2 =  barrel-1 screen address

	; Next barrel

	addq.w 	#4,d0
	and.w	#(M_BARREL_COUNT<<1)-1,d0
	move.w 	d0,(a0)+
	; a0 = ScScreenBarrel_

	; Write back frame barrels

	move.l 	d1,(a0)+
	move.l 	d2,(a0)+

	rts

	;
	;; SW - blit the active buffer to screen core
	; 

GhostBarrelBlit:
	move.l 	ScreenBarrel_(pc),a0
	move.l 	mach_conf+MACH2SCREEN+PHYSBASE(pc),a1
	lea 	M_SCROLL_IN_SCREEN*160(a1),a1

	bsr.s 	ScreenSpaceBlit

	rts

GhostBarrelScroll:
	;
	;; L Blit barrel in screen space 
	;

	move.l 	ScreenBarrel_(pc),a0
	bsr 	ScreenSpaceLBlit

	;
	;; Insert ghosts column in barrel screen space + blend with barrel - 1
	;

	move.l 	ScreenBarrel_(pc),a0
	move.l 	ScreenBarrel_+4(pc),a1
	bsr	UpdateGhostScroll

	rts
	
;
;;
;; 
;;
;

;
;;
;; Screen space barrell scroll
;;
;

M_BARREL_OFFSET	SET 	0

	;
	;; SW barrel setup - all buffers need to be be contingent and leave the core of screen empty
	;

		;

		dc.w 	(M_SCREEN_GAP+((M_BARREL_COUNT-1)*M_BARREL_SIZE))*160
ScreenBarrelOffset: 	; First half on top of screen
		REPT 	(M_BARREL_COUNT>>1)
		dc.w 	M_BARREL_OFFSET*M_BARREL_SIZE*160
M_BARREL_OFFSET	SET 	M_BARREL_OFFSET+1
		ENDR
		; Second half on bottom  of screen
		REPT 	(M_BARREL_COUNT>>1)
		dc.w 	(M_SCREEN_GAP+M_BARREL_OFFSET*M_BARREL_SIZE)*160
M_BARREL_OFFSET	SET 	M_BARREL_OFFSET+1
		ENDR

;
;;
;

ScreenBarrel:	dc.w 	0
ScreenBarrel_:	dcb.l 	2

;
;; Screen space blit
;; a0: source line
;; a1: target line
;

	ifeq	M_DSHIFT_LINES=20
	ERROR	"M_DSHIFT_LINES must be 20"
	endc

blit_count	set	0

BlocksBlit	macro
blit_count	set	blit_count+1
	movem.l 	(a0)+,d0-d7/a2-a6	; 6.5 blocks
	movem.l 	d0-d7/a2-a6,4*13*blit_count(a1)
	endm

ScreenSpaceBlit:

	movem.l 	(a0)+,d0-d7/a2-a6	; 6.5 blocks
	movem.l 	d0-d7/a2-a6,(a1)

	rept	60               	;((M_DSHIFT_LINES*40)/13)-1
	BlocksBlit                   	; 6.5 blocks
	endr

	movem.l 	(a0)+,d0-d6      	; 3.5 blocks
	movem.l 	d0-d6,4*13*(blit_count+1)(a1)

	; 400 blocks                 	; M_DSHIFT_LINES = 20

	rts

;
;; Screen space 16pix left scroll blit
;; a0: source line
;

ScreenSpaceLBlit:
	moveq 	#M_DSHIFT_LINES-1,d0 	; line count - it's fast enough to dbra a full line

l_leftBlitLine:	; Store line count

	;

	movem.l 	8(a0),d1-d7/a1-a6       	; 6.5 blocks
	movem.l 	d1-d7/a1-a6,(a0)
	movem.l 	(8+13*4)(a0),d1-d7/a1-a6	; 6.5 blocks
	movem.l 	d1-d7/a1-a6,(13*4)(a0)
	movem.l 	(8+26*4)(a0),d1-d7/a1-a5	; 6 blocks
	movem.l 	d1-d7/a1-a5,(26*4)(a0)
	; 19 blocks L

	lea 	160(a0),a0

	;

	dbra 	d0,l_leftBlitLine

	rts

;
;; Udpate ghost scroll in screen space
;; a0: screen space base line
;; a1: screen space barrel-1 base line
;

UpdateGhostScroll:

	;
	;; Update scroll insert + shift column
	;

	lea 	GhostScroll(pc),a5
	move.w 	(GhostScrollShift-GhostScroll)(a5),d1 	; Shift index
	move.w 	(GhostScrollIndex-GhostScroll)(a5),d2	; Scroll index
	moveq 	#0,d0
	move.w 	d1,d0 			; d0 = current shift index in PShift_ColumnarInsert_Map offset
	addq.w 	#4,d1 			; lookahead - next shift in hard map 
	and.w 	#M_DSHIFT_CMAP_WRAP_MASK,d1		; lookahead - wrap shift - 0 marks next index
	bne.s 	l_nextGhostShift

	; lookahead - Next ghost for next update

	move.w 	d2,d3
	addq.w 	#1,d3			; Next scroll index
	move.b 	(a5,d3),d4			; lookahead - next scroll item
	cmp.w 	#M_GHOST_END,d4			; Wrap check
	bne.s 	l_nextGhost
	moveq	#0,d3			; wrap ghost text
l_nextGhost:	move.w 	d3,(GhostScrollIndex-GhostScroll)(a5)	; lookahead -  Save next ghost index
l_nextGhostShift:
	move.w 	d1,(GhostScrollShift-GhostScroll)(a5)	; lookahead - Save shift

	; d2 = current ghost scroll index
	; d0 = current shift
	; a5 = GhostScroll(pc)
	; trash; d1,d3,d4

	;
	;; Insert ghost column
	;

	;

	moveq 	#0,d3
	move.b 	(a5,d2.w),d3 			; d3 = current ghost in PShift_Insert_Map offset
	lea 	DShift_Map(pc),a5 		; Ghost to preshift columns map
	moveq 	#0,d1
	move.w 	(a5,d3.w),d1			; d1 = Ghost to group offset
	add.l 	d1,a5			; a5 = Ghost group
	; a5 = Ghost group
	; trash: d1,d3

	;

	lea 	DShift_Columnar_Map(pc),a6
	add.l 	d0,a6 			; a6 = shift map data
	move.w 	(a6)+,d1			; d1 = Downshift group offset
	add.l 	d1,a5 			; a5 = Ghost downshift group
	moveq 	#~M_DSHIFT_SPEED_MASK,d5 		; d5 = uphift overflow mask 
	swap 	d5 			; d5.high = upshift overflow mask 
	move.w 	(a6)+,d6 			; d6 = downshift count
	moveq 	#M_DSHIFT_LINES-1,d7 		; d7 = line count
	; a5 = Downshifted column data for insertion
	; d5 = downshift mask
	; d6 = downshift count
	; d7 = line count -1 for dbra
	; trash: d0,d1,a6

	; Clear 4bpp to 'depack'

	IFNE 	(M_DSHIFT_COLUMN_STORE=1)
	moveq 	#0,d0
	moveq 	#0,d1
	moveq 	#0,d2
	moveq 	#0,d3
	ENDC

l_insertShiftColumn:

	; Set barrel & barrel-1 to last screen space column - also in-loop line increase

	lea 	152(a0),a0
	lea 	152(a1),a1

	;
	;; Shift right line column from barrel -1 & insert columnar 
	;; - no handling of overflow shifted bitsl this is handled by the L blit of barrels
	;

	IFNE 	(M_DSHIFT_COLUMN_STORE=2)

	; .w 2 implied - all ready to roll
	movem.w 	(a5)+,d0-d3

	ELSE

	; .b 1 implied - runtime 'depack' to .w
	move.b 	(a5)+,d0
	move.b 	(a5)+,d1
	move.b 	(a5)+,d2
	move.b 	(a5)+,d3

	ENDC

	; Shift columner P0-P3 to insertion 

	lsr.w 	d6,d0
	lsr.w 	d6,d1
	lsr.w 	d6,d2
	lsr.w 	d6,d3
	
	; Shift barrel-1 to insertion & blend with columnar insert

	move.l 	(a1)+,d4	; p0-p1
	lsl.l 	#M_DSHIFT_SPEED,d4
	and.l 	d5,d4
	or.w 	d1,d4 	; p1
	swap 	d4
	or.w 	d0,d4 	; p0
	swap 	d4
	
	; Write back p0-p1 in barrel right
	move.l 	d4,(a0)+

	;

	move.l 	(a1)+,d4	; p2-p3
	lsl.l 	#M_DSHIFT_SPEED,d4
	and.l 	d5,d4
	or.w 	d3,d4 	; p3
	swap 	d4
	or.w 	d2,d4 	; p2
	swap 	d4
	
	; Write back p2-p3 in barrel right
	move.l 	d4,(a0)+

	;

	dbra	d7,l_insertShiftColumn

	rts

;
;;
;

	section	data

;
;;
;

	; Destination palette of the ghosts.
DOMGhostPalette
	; Palette of the ghosts with the halo in dark colors.
DOMGhostPalette_low
	dc.w	$0000,$0123,$0234,$0135,$0124,$0013,$0012,$0001
	dc.w	$0500,$0112,$0334,$0445,$0556,$0667,$0777,$0776

	; Palette of the ghosts with the halo in light colors.
DOMGhostPalette_high
	ifne	DEBUG_LOAD_ANIM
	dc.w	$0700,$0345,$0456,$0677,$0567,$0467,$0456,$0345
	dc.w	$0700,$0700,$0700,$0700,$0700,$0700,$0700,$0700
	elseif
	dc.w	$0000,$0345,$0456,$0677,$0567,$0467,$0456,$0345
	dc.w	$0500,$0112,$0334,$0445,$0556,$0667,$0777,$0776
	endc

;
;;
;

M_GHOST_A 	EQU 	0
M_GHOST_B 	EQU 	1<<1
M_GHOST_CHAIN 	EQU 	2<<1
M_GHOST_I_LOVE	EQU 	3<<1
M_GHOST_REP	EQU 	4<<1
M_GHOST_LICANTS	EQU 	5<<1
M_GHOST_CRACK	EQU 	6<<1
M_GHOST_IS	EQU 	7<<1
M_GHOST_GOOD	EQU 	8<<1
M_GHOST_YOU_1	EQU 	9<<1
M_GHOST_YOU_2	EQU 	10<<1
M_GHOST_LOAD	EQU 	11<<1
M_GHOST_IN	EQU 	12<<1
M_GHOST_G__	EQU 	13<<1
M_GHOST_PLEASE	EQU 	14<<1
M_GHOST_WAI	EQU 	15<<1
M_GHOST_T__	EQU 	16<<1
M_GHOST_END	EQU	$ff

;

GhostScrollShift:	dc.w 	0
GhostScrollIndex:	dc.w 	0

;

GhostScroll: 	dc.b 	M_GHOST_A
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_B
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_CRACK
	dc.b 	M_GHOST_IS
	dc.b 	M_GHOST_GOOD
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_A
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_YOU_1
	dc.b 	M_GHOST_YOU_2
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_B
	dc.b 	M_GHOST_LOAD
	dc.b 	M_GHOST_IN
	dc.b 	M_GHOST_G__
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_A
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_PLEASE
	dc.b 	M_GHOST_WAI
	dc.b 	M_GHOST_T__
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_A
	dc.b 	M_GHOST_B
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_I_LOVE
	dc.b 	M_GHOST_REP
	dc.b 	M_GHOST_LICANTS
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_CHAIN
	dc.b 	M_GHOST_END
	EVEN

;
;;
;

	include 	"GHOSTS.S"
