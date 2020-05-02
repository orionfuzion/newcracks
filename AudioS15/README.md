# Audio Sculpture 1.5 - Cracking the copy-protection under Hatari

The set of files present in this folder provides the means to crack the
copy-protection of
*[Audio Sculpture 1.5](http://www.atarimania.com/utility-atari-st-audio-sculpture_25173.html)*
using the debugging facilities of the
*[Hatari](https://hatari.tuxfamily.org/)* emulator.

The copy-protection of Audio Sculpture is called **IPL** which means
**Initial Program Load**.  
It consists of three different protections assembled into a single
mega-protection whose complete execution takes 15 seconds!  
It has been developed by
**Illegal** (*[The Replicants](https://demozoo.org/groups/31491)*),
**Altair** (*[VMAX](https://demozoo.org/groups/31500)*),
**Zarathustra** (*[The Invisibles](https://demozoo.org/groups/39198)*)
and **Redhead** (*[SYNC](https://demozoo.org/groups/2256)*).  
It is present on all software published by
*[Expose Software](http://www.atarimania.com/pgelstsoft.awp?system=S&publisher=2865)*:
**Audio Sculpture** (all versions), **No Buddies Land** and **Son Shu Shi**.

The cracking tutorial provided here focuses on the hardware mechanisms used
by the IPL copy-protection, that is, how tracks and sectors are physically
protected and verified by the IPL.  
The physical part of the copy-protection was originally described by
*[DrCoolZik](https://info-coach.fr/atari/index.php)*
in a PDF available *[here](../../../raw/master/AudioS15/AS_Prot_by_DrCoolZik.pdf)*.  
The technical terms used to classify the protection mechanisms are explained in this
*[document](http://info-coach.fr/atari/documents/_mydoc/Atari-Copy-Protection.pdf)*.

> The IPL copy-protection also provides an incredible software protection
> scheme used to prevent debugging and reverse engineering and thus make
> the protection unbreakable on a native Atari ST (of course, such software
> protection mechanisms are ineffective on today's emulator debuggers).
> This software part is not addressed here, but a detailed description
> can be found in the documented crack of Son Shu Shi. See *[here](../SonShuSi/IPL.md)*!

In order to crack Audio Sculpture 1.5, the original copy
(*[AudioSculpture1-5.STX](../../../raw/master/AudioS15/AudioSculpture1-5.STX)*)
has been duplicated using
*[FastCopy III](https://demozoo.org/productions/127423/)*.
This copy is provided as a regular ST image
(*[AudioSculpture1-5-COPY.ST](../../../raw/master/AudioS15/AudioSculpture1-5-COPY.ST)*).  
If this ST image is executed under Hatari without special actions, it will
crash due to the IPL copy-protection.

The *\*.ini* files provided in this folder implement a
*[breakpoint actions chain](https://hatari.tuxfamily.org/doc/debugger.html#Chaining_breakpoints)*
allowing to run the ST image of Audio Sculpture 1.5 under Hatari and to
perform actions such as patching the memory and the registers on-the-fly
in order to crack the IPL protection and to make the regular ST image
of Audio Sculpture 1.5 run correctly.

To crack the IPL and make the ST image work correctly, launch a Unix
shell, go to the *AudioS15* directory containing the *\*.ini* files and
launch Hatari as follows:

    $ <path_to_hatari>/hatari --configfile <your_hatari_config_file>  --disk-a ./AudioSculpture1-5-COPY.ST --parse ./as15_bp0.ini

It is also possible to run the original copy of Audio Sculpture 1.5
(the STX image) with the same breakpoint actions chain:

    $ <path_to_hatari>/hatari --configfile <your_hatari_config_file>  --disk-a ./AudioSculpture1-5.STX --parse ./as15_bp0.ini

This will dump the content of the protected tracks and sectors as well as
the routines that perform copy-protection checks.

This folder contains the following files:

- *README.md*  
  This file.

- *AS_Prot_by_DrCoolZik.pdf*  
  The physical part of the protection described by DrCoolZik.
  This document was originally provided on
  *[Atari Forum](http://www.atari-forum.com/viewtopic.php?f=14&t=31939&start=200#p392169)*.

- *AudioSculpture1-5.STX*  
  The image of the original protected disk of Audio Sculpture 1.5.

- *AudioSculpture1-5-COPY.ST*  
  The image of the copy (using FastCopy III) of Audio Sculpture 1.5
  (protected tracks and sectors are missing or incorrect).  
  The purpose of the *\*.init* files below is to be able to run this image
  correctly under Hatari.

- *as15_bp0.ini*  
  The head of the breakpoint actions chain that is used to crack the
  copy-protection of Audio Sculpture 1.5 under Hatari.

- *as15_bp1.ini*  
  Neutralize track#1 protection:
  *Hidden data into gap (HDG) and invalid data in gap (IDG)*.

- *as15_bp2_1.ini*  
  Neutralize track#2 protection (1st part):
  *Hidden data into gap (HDG) and invalid data in gap (IDG)*.

- *as15_bp2_2.ini*  
  Fix loading of IPL Part#3.

- *as15_bp3_1.ini*  
  Neutralize track#2 protection (2nd part):
  *Hidden data into gap (HDG) and invalid data in gap (IDG)*.

- *as15_bp3_2.ini*  
  Neutralize track#3 protection (1st part):
  *Hidden data in gap (HDG), sector data with no ID (SNI),
  invalid data in gap (IDG), invalid track number (ITN),
  ID within ID (IWI), write splice inside sector (SIS)*.

- *as15_bp3_3.ini*  
  Neutralize track#3 protection (2nd part):
  *Hidden data in gap (HDG), sector data with no ID (SNI),
  invalid data in gap (IDG), invalid track number (ITN),
  ID within ID (IWI), write splice inside sector (SIS)*.

- *as15_bp3_4.ini*  
  Neutralize track#3 protection (3rd part):
  *Hidden data in gap (HDG), sector data with no ID (SNI),
  invalid data in gap (IDG), invalid track number (ITN),
  ID within ID (IWI), write splice inside sector (SIS)*.

- *as15_bp4.ini*  
  Neutralize track#1 protection inside Audio Sculpture (outside the IPL):
  *Hidden data into gap (HDG) and invalid data in gap (IDG)*.

- *ipl_part3.bin*  
  The 3rd part of the IPL normally located on sectors of track#2.

- *as15_stx_log.txt*  
  The Hatari console output obtained by running the STX image of
  Audio Sculpture 1.5 with the provided scripts.

Every *.ini* file provides detailed comments about each part of the
copy-protection.

---

*Orion of The Replicants - January 2020*
