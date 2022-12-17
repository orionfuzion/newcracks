# Son Shu Shi - The Copy-Protection

The copy-protection used in
*[Son Shu Shi](http://www.atarimania.com/game-atari-st-son-shu-si_24613.html)*
is very special!

It is actually used on all titles published by
*[Expose Software](http://www.atarimania.com/pgelstsoft.awp?system=S&publisher=2865)*.  
*Expose Software* was a French software-house run by members of the
Atari ST demo-scene, mainly coming from the
*[NeXT](https://demozoo.org/groups/31770/)*
demo-group (who released the
*[Phaleon Giga Demo](https://demozoo.org/productions/73226)*).

Titles that use this copy-protection are: all releases of **Audio
Sculpture**, **No Buddies Land** and **Son Shu Shi**.

This terrifying copy-protection was developed by talented Atari ST
sceners including:
**Illegal** (*[The Replicants](https://demozoo.org/groups/31491)*),
**Altair** (*[VMAX](https://demozoo.org/groups/31500)*),
**Zarathustra** (*[The Invisibles](https://demozoo.org/groups/39198)*)
and **Redhead** (*[SYNC](https://demozoo.org/groups/2256)*).

It is composed of two distinct and complementary parts:

1. The **Initial Program Load** (**IPL**) is executed at boot time.  
   It is a huge piece of encrypted code protected against reverse
   engineering and hacking.  
   Its purpose is to verify that the disk in use is an original copy.
   To this end, it reads special tracks on the disk and crashes in case
   of a copy. It also writes some magic values in low memory that are
   checked later during the game. Eventually, it loads and executes the
   initial program of the game.  
   Fun fact: the IPL was also called **Initial Program Lock** by its
   authors, probably in reference to the famous
   *[Rob Northen Copylock](https://en.wikipedia.org/wiki/Rob_Northen_copylock)*.

2. Several **checksum routines** are hidden in the main program of the game.   
   These routines are executed during the game and check the magic values
   written in low memory by the IPL.  
   If magic values are missing or incorrect, the game code or data is
   corrupted to cause a malfunction or even a crash.  
   This ensures that the IPL has not been removed by a hacker.

   *Son Shu Shi* uses an additional protection mechanism: the content of
   the two floppy disks is fully encrypted.  
   Decryption is performed on-the-fly when disk tracks are loaded; the
   game does not use the standard
   *[FAT12](https://en.wikipedia.org/wiki/File_Allocation_Table#FAT12)*
   filesystem but loads its data from hard-coded disk areas, without
   *[TOS](https://en.wikipedia.org/wiki/Atari_TOS)* assistance.

## The IPL

This section details the software mechanisms used in the IPL to make
game cracking almost impossible using a native Atari ST debugger.

> It also briefly depicts the hardware mechanisms used by the copy-protection,
> that is, how tracks and sectors are physically protected and verified by the IPL.  
> The description of that physical part is based on the analysis performed by
> *[DrCoolZik](https://info-coach.fr/atari/index.php)* for **Audio Sculpture**.
> It is valid for **Son Shu Shi** as both software use the same protection scheme.  
> If you are interested in the physical part of this copy-protection, it is detailed in
> *[Audio Sculpture 1.5 - Cracking the copy-protection under Hatari](../AudioS15/README.md)*.  
> The technical terms used in this README for the physical part are explained in a
> *[document](http://info-coach.fr/atari/documents/_mydoc/Atari-Copy-Protection.pdf)*
> written by *DrCoolZik*.

The IPL consists of **three** different protections assembled into
a single mega-protection whose complete execution takes **15 seconds**!

All hardware mechanisms necessary for a native debugger to run (CPU exception
handling, keyboard or screen usage...) are hijacked or neutralized by the IPL
code, which makes it almost impossible to use such a debugger to hack the IPL.

For instance, the code of the three parts of the IPL is encrypted and
decrypted on-the-fly using different techniques, such as *trace vector
decoding* (*[TVD](https://en.wikipedia.org/wiki/Trace_vector_decoder)*):
the trace mode of the CPU is used to decode each 
instruction just-in-time before it is executed and to re-encrypt it
after the execution.  

All possible CPU exceptions are also triggered on purpose during the
execution of the IPL to take new execution paths.  
But CPU exceptions may also occur if the protection does not execute
correctly. This can happen because the protection code uses many tricks
to detect the presence of a debugger and, in this case, insidiously take
an alternate execution path that will later result in code corruption
and thus in an exception.  
Because of this, you never know if an exception is triggered on purpose
by the protection code or if the code executed is just wrong.  

Additional techniques are used to prevent the use of a debugger and thus
to make the reverse-engineering of the protection very painful:
- execution of code installed in low memory in place of the
  *[exception vectors](http://deunstg.free.fr/sct1/hardware.htm)*,
- use of the stack pointer to points to *I/O* registers (thus making the
  debugger unable to handle its own exceptions),
- use of the *VBL*, *HBL* and *timer-A* to execute concurrent (but
  synchronized) protection code,
- resetting or stopping peripherals such as the keyboard,
- complete reset of the CPU and peripherals (*RESET* instruction),
- modifying the video settings and in particular switching to high
  resolution (71Hz),
- Use of the 1MHz *[HD6301](https://github.com/nocrew/ostis/blob/master/doc/ikbd.txt)*
  8-bit microprocessor (controlling the ST keyboard) to decrypt code/data
  running on the 68000,
- use of uncommon 68000 instructions, undocumented features (at that
  time), and CPU corner cases.

Finally, each of the 3 parts of the IPL checks a different protected
track to validate that the disk is an original copy.

Surprisingly, the IPL is partially present on
*[Terminator Kid's crack](http://atariforce.free.fr/st/jeux/sonshu.zip)*,
although it is no longer executed.  
Parts 1 and 2 of the IPL are still present on disk#1, respectively on
tracks 75 and 78-79 of side 0.  
The original bootsector is missing as it has been replaced by a version
which loads the crack intro and bypasses the IPL protection.  
Part 3 is also missing because it was stored on track 76 whose special
format prevented its content from being copied.

### 1st part of the IPL - Developed by Illegal

   This protection was originally developed for the game
   *[Toki](http://www.atarimania.com/game-atari-st-toki_10641.html)*,
   but since *[Ocean](https://en.wikipedia.org/wiki/Ocean_Software)*
   never used it, it was eventually integrated in the IPL.

   *Illegal*'s part executes in low memory in place of the exception vectors.
   The code is entirely encrypted and is decoded on-the-fly using
   different techniques, and in particular the *trace vector decoding*:
   - The trace exception handler is installed at address *$8*, at the
     beginning of the exception vectors.
   - The stack pointer is set to different low memory addresses not
     compatible with a debugger (such as *$34*, *$54*) and it cannot be
     changed by a hacker as the value of the stack pointer is used by
     the trace handler to compute the decryption key for the next
     instruction to be decrypted.  
     The stack pointer is also used as the base register to access the
     *DMA* controller (*$ff860x*), thus ensuring that it cannot be changed
     to point to a memory area suitable for the debugger.

   The protection starts with a funny trick in the boot sector:
   the boot sector code discreetly checks the content of
   *PSG register 14 (Port A)* to determine which sector will be
   loaded and then executed.  

   Normally, when the boot sector is executed by the *TOS* at startup,
   *PSG register 14* indicates that drive *A* and side *0* are selected.
   This is because the boot sector has just been read and the drive is
   still in use (the motor is still running) when the boot sector starts
   executing.  

   However, when a debugger is used, the boot sector needs to be loaded
   **manually** into memory before it can be debugged. And because this
   step is manual, the time between loading the boot sector and starting
   the debugging process is long enough for the drive motor to shut down.
   In such a case, *PSG register 14* indicates that the drive *A* is
   no longer selected.  

   This is detected by the protection code executed in the boot sector,
   and in this case a wrong sector is loaded on purpose.  
   This sector contains an alternative protection which is only a decoy
   to make the hacker believe that he is executing the right sector
   whereas he is executing code which leads nowhere.  
   This fake protection sector contains the string ***TOKI-LOADER*** at
   the beginning and the code changes the background color to blue in a
   similar way to what the real protection code does, then it executes
   a *trace vector decoder* that will load another (wrong) sector.
   In the end, this fake protection will crash.  

   And the funny thing is that the sector containing the real protection
   code contains only obfuscated 68000 instructions: instructions are
   unusual, used in a strange way or encrypted (and decrypted on-the-fly)
   and a hacker who sees them will think that it is only garbage.  
   So if the hacker loads the wrong sector, he will see some protection
   code (which is just a dead end), but if he loads the correct sector,
   he will see garbage (which is actually the real protection code).  
   That's **evil**!

   In the same vein, in the middle of that protection, the code jumps
   to a memory area that contains no code (only zeroes), just to fool
   the hacker into thinking the execution failed.

   The protection checks that the disk is an original copy as follows:
   a first protected track stored on disk#1 contains *invalid data in gap*
   (**IDG**) and *hidden data in gap* (**HDG**) at the start of the track.  
   The protection verifies that the expected data is present, and crashes
   otherwise.

   After checking the protected track, the second part of the IPL is
   loaded and executed.

   During the execution of *Illegal*'s part, the background color changes
   from bright blue to dark blue, and is set to black at the beginning
   of the second part.

### 2nd part of the IPL - Developed by Zarathustra

   The second part of the IPL was developed by *Zarathustra* although
   it also includes a piece of code developed by *Altair*.

   This part is mainly a *trace vector decoder*, with a huge quantity of
   code being decoded on-the-fly. Every CPU exception (bus error,
   address error, illegal, divide by zero, CHK, TRAPV and every Trap)
   is triggered during trace vector decoding to disrupt the
   *[control flow](https://en.wikipedia.org/wiki/Control_flow)*.

   The protection code switches the video mode to high resolution,
   resets the keyboard (by sending a reset command to
   *[IKBD](https://www.kernel.org/doc/Documentation/input/atarikbd.txt)*),
   disables *MFPs* and resets the CPU (by executing the *RESET* instruction).

   This part also contains a **sync decoding** mechanism (developed by
   *Altair*): the base level code computes a decryption key while the
   *timer-A* running in the background modifies that key on-the-fly.
   The decryption key is computed correctly only if the base level
   and *timer-A* code are scheduled in the correct order, which is not
   the case when a debugger is used to step through the code.

   Simpler sync techniques are also used, based on the *HBL* and *VBL*,
   whose purpose is to behave differently depending on whether a
   debugger is used or not.

   The protection checks that the disk is an original copy as follows:
   a second protected track stored on disk#1 contains *invalid data in
   gap* (**IDG**) and *hidden data in gap* (**HDG**) at the start and at the end
   of the track.  
   The protection verifies that the said data is present at the **start**
   of the track, and crashes otherwise.  
   The *hidden data in gap* at the **end** of the track is checked later,
   in the third part of the IPL.

   The protected track has a special format: it has 5 sectors of 1024
   bytes and 1 sector of 512 bytes (like the
   *[Union Demo](https://demozoo.org/productions/68152/)* format),
   and it contains the third part of the IPL.

   In the case of *Son Shu Shi* (*Terminator Kid*'s version), this special
   format led to an incorrect copy of the track and therefore to the
   loss of the third part of the IPL.  
   Fortunately, a very close version of this part can be found in the
   original copy on *Audio Sculpture 1.5*, on track #2.

   After checking the protected track, the third part of the IPL is
   loaded and executed.

### 3rd part of the IPL - Developed by Zarathustra/Illegal/Redhead

   The third part of the IPL was developed by *Zarathustra*, with the
   help of *Illegal* and *Redhead*.

   This part uses techniques similar to those used in the first 2 parts:
   *trace vector decoding*, use of CPU exceptions, stack pointer pointing
   to *I/O* registers, *IKBD* reset, CPU reset, switching to high resolution,
   anti-debugging sync tricks.

   Like *Illegal*'s part, this protection begins with several instructions
   used in a strange way to make hackers believe in incorrect *ASM* code
   that would have been badly loaded or decrypted.

   Unusual instructions with poorly understood behavior are also used
   to confuse hackers. For instance, a *STOP* instruction that clears
   the *[Supervisor](https://www.atarimagazines.com/startv1n3/SupervisorMode.html)*
   flag is used to trigger a *privilege violation exception*. This behavior
   was *[not properly emulated in Hatari](http://www.atari-forum.com/viewtopic.php?f=14&t=31939&start=50#p330399)*
   until the end of 2017!

   In addition, the third part of the IPL implements the following
   techniques:

   - Use of the *[prefetch queue](http://pasti.fxatari.com/68kdocs/68kPrefetch.html)*
     effect on *[self-modifying code](https://en.wikipedia.org/wiki/Self-modifying_code)*:
     the next instruction is modified but that modification is not taken
     into account due to the *68000 prefetch queue*. Therefore the original
     (unmodified) instruction is actually executed. But when stepping
     through the code under a debugger, the prefetch queue behaves
     differently causing the modified instruction to be executed.

   - The 1MHz HD6301 8-bit microprocessor (controlling the ST keyboard)
     is reprogrammed in order to decrypt code/data running on the 68000.
     More precisely, a special program is uploaded to the keyboard
     microprocessor to replace the original keyboard management program.
     When the special value *$42* is sent to this program through the
     *ACIA* (by writing to *$fffc02*), the program responds by sending the
     two magic values *$4b* and *$13* to the 68000 (read from *$fffc02*).
     These values are used to decrypt data on the 68000 side.  
     This is really nasty as the keyboard can no longer be used by the
     debugger since it is now used for the protection!

   - Magic values are written in low memory before loading the initial
     game program. These values are checked later during the game.  
     If they are missing or incorrect, the game is altered. This ensures
     that the IPL has been executed and has not been removed by a hacker.

     *SYNC* members have certainly contributed to the implementation of
     the checksums and we can find traces of this collaboration in
     the code of a checksum routine: the hexadecimal value **SYNC** is
     used to decode a magic value!

   Just before reprogramming the keyboard microprocessor and writing
   the magic values in low memory, the third part of the IPL checks
   two protected tracks as follows:

   - The protected track which is checked in the second part is checked
     again here, but this time the code verifies the *hidden data in gap*
     at the **end** of the track.  
     If the expected data is missing, the protection crashes.

   - A third protected track on disk#1 is checked. It uses several Hardware
     protection mechanisms: *hidden data in gap* (**HDG**), *sector data with
     no ID* (**SNI**), *invalid data in gap* (**IDG**), *invalid track number*
     (**ITN**), *ID within ID* (**IWI**).  
     The protection code computes a checksum on *$1798* bytes of the track
     starting from a *$c2* sync mark (thus covering most of the track).
     This checksum is used to decrypt a small routine executed later.
     Therefore, if the checksum is invalid (in case of a copy), the
     routine will not be decoded correctly and will crash.

     This track also uses a very special protection scheme, probably
     never used on Atari ST: **write splice inside sector** (**SIS**).

     *Altair* (the author) describes the protection as follow:

     > *The principle is very simple, it's based on the disk drives rotation
     > speed variation on a whole round, it's in fact an extreme pain in
     > the ass to replicate, maybe completely impossible.  
     > For that protection, you need to write a track that ends by the
     > beginning of a long sector. Due to the speed variation, you never
     > write twice the same exact track (i.e. the track write splice is
     > never at the same location). When reading the last sector (which
     > spreads over the index pulse) you actually read data from the end
     > of track plus data from the beginning of the track including the
     > write splice.  
     > By combining a 'read track' command and a 'read sector' command on
     > the last sector, we can read the full circular content of the track.  
     > The content is always different for each diskette...  
     > The only way to copy a diskette with this protection is to patch
     > the protection code/data according to what is actually read on
     > the newly copied track.*

     The protection code reads the last sector of the protected track
     (crossing the index and the write splice) and computes a checksum
     on the 1024 bytes of that sector.
     If the checksum matches one of 10 possible values, the protection
     continues, otherwise it starts the verification again.  
     If disk#1 is a copy, then the protection never exits.

   Finally, the third part of the IPL loads and starts the initial
   program of the game.

### Hidden Messages

Several *[hidden messages](https://en.wikipedia.org/wiki/Easter_egg_(media))*
can be found in memory when the protection is executed step by step under
a debugger.

The following messages are in plain text (unencrypted) on the disk:

1.
        TOKI-LOADER
2.
        Initial Program load [v2.0]  Tm 1989,1990 ThunderSoft Development
        Atari-ST IPL Track  
        IPL needs no custom chip
        do you think you can reproduce it?  
        better try programming demos, freaks!...........
        Arf hehe
        this version was finished on 29/05/1990    
        It's a professional protection can protect anything
        so this protection set the end of the cracking
        SOFT PROTECTION CODEDBY: Mr TRUONG NGOC Pascal TEL: 43 36 55 91
        DISK PROTECTION CODED BY Mr xxxxxxxx Frederic TEL: 92 66 63 16
        if you are interest by our protect so...

3.
        You cannot escape your destiny. You must face Dark Vador again...
        INSERT ORIGINAL DISK IN A

The following messages are decrypted during *Illegal*'s part:

1.
        Please do NOT crack

2.
        THUNDERSOFT,YE CRACKER'S NIGHTMARE!
        STEFAN:PART1.
        PASCAL:PART2.
        FRED:HARDWARE.
        PSYCHOTIC LAST PART BY BOTH STEFAN & PASCAL

3.
        You have made 33,33% of the protection.
        You can write now to ILLEGAL ! at the following address :
        Stephane xxxxxxxx xx bd Davout,75020 PARIS.
        I just ask you sincerely one thing : please wait 2 weeks before
        spreading it on the boards, it's hard to do, and easy to undo...

4.
        ILLEGAL GIVES A KISS TO LULU BECOS OF MY HARD DRIVE FUCK YA!

The following messages are decrypted during *Zarathustra*'s part:

1.
        may the force be with you

2.
        THIS IS THE GOOD CODE... GO ON !!
        WELL DONE ! PLEASE CONTACT ZARATHUSTRA

## The Checksum Routines

The second part of the protection is composed of several checksum routines
hidden in the main program of the game (**11** routines in the case of
*Son Shu Shi*).  
These routines are executed during the game and check the magic values
written in low memory by the IPL.  
If magic values are missing or incorrect, the game code or data is
corrupted to cause a malfunction or even a crash.  
This ensures that the IPL has not been removed by a hacker.

The trick is that the magic values are not just constant values, they are
actually computed using machine-specific information.  
Typically, magic values are computed using:
- The TOS version
- The TOS date
- The TOS start address
- The machine type (STf or STe)
- The memory configuration (512KB, 1MB,...)

Therefore, the magic values will not be the same on two different
machines. And this is what is verified by the checksum routines:
they compare the magic values found in low memory with the values
expected for the current machine.

So, if the cracking method is simply to:
- remove the IPL,
- write in low memory the magic values computed by the IPL on a
  specific machine,  

then the checksum routines will only succeed on this machine
(or identical) and fail on others.

And that's what happens with *Terminator Kid*'s crack!  
*Terminator Kid* cracked the checksum routines as follows: he ran
the first part of the protection (the IPL) on his machine, then
he dumped the contents of the low memory containing the magic values,
and he just created a small boot program that copies this dump into
low memory before starting the game.  
As a result, *Terminator Kid*'s version only works correctly on a
machine similar to the one he used to crack the game:  
**an Atari STe, with 4MB of RAM, using TOS 1.62**.  
When run on a different machine, the game will eventually crash.

To be exact, *Terminator Kid* managed to disable **7** checksum routines
out of the **11** present in *Son Shu Shi*. Indeed, his boot program also
includes a routine that dynamically generates certain magic values
correctly using machine-specific information.  
But since he did not find all the magic values and the corresponding
checksum routines, he finally used the simplistic approach of dumping
the low memory as a workaround.

It must be said that the checksum routines are very difficult to
find: they are mixed up with the code of the game, their code is
obfuscated and it is almost impossible to guess what it does by
simply reading it.

Below is a checksum routine taken from *Son Shu Shi*.  
It is called every time special enemies or objects appear on the
screen during the game.  
This checksum routine verifies the magic byte stored at *$4aa*,
that was calculated by the IPL using the value of the *memory banks*
configuration register (*$ff8001*). If the magic byte does not match 
the current value of *$ff8001* the game data is corrupted: the number
of enemies currently on the screen is reset to a random number, which
causes unexpected effects ranging from changing the number of enemies
on the screen to a crash of the game.

The following snippet shows how checksum routines are hidden
inside the code of the game. In this case, the checksum routine
is executed just after saving the current color palette and it
uses the contents of the registers left by the previous code.

    lea         $ffff8240.w,a0   ; Color palette registers 0-15
    lea         <buffer>(pc),a1  ; Destination buffer
    moveq       #7,d0
    .1:
    move.l      (a0)+,(a1)+      ; Save the color palette
    dbf         d0,.1
    lsr.w       #2,d0            ; d0=$3fff
    adda.w      d0,a0            ; a0=$ffffc25f
    move.b      $424b(a0),d0     ; [$4aa] = xx MB
    sub.b       -$425e(a0),d0    ; [$ffff8001] = xx MB
    beq.s       <addr>           ; Both values are the same => return
    ; Otherwise => corrupt the number of enemies

In the end, *Terminator Kid*'s crack contains **4** checksum routines that
are still active and that make the game crash at different stages.

> Note that *Terminator Kid*'s crack images available on the Internet are
> all corrupt (several tracks contain only garbage), which also causes
> crashes during the game.  
> Typically, the last 2 levels of the game and the secret passages cannot
> be played due to these bad tracks.

---

*Orion of The Replicants - March 2020*
