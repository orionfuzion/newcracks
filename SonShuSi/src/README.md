This directory contains the source files of the crack of ***Son Shu Shi***,
with plenty of explanations and comments.

You should read the comments at the beginning of ***[LOADER1.S](LOADER1.S)***
for a detailed description of the organization and contents of the various
source files of this crack.

In brief:

- ***LOADER1.S***, ***LOADER2.S*** and ***LOADERH.S***  
The loader of the game that initializes the system, loads the main and hidden
cracktros and implements all the changes and improvements made to the game:
trainer mode, file loading (*FDC*/*DMA*/*FAT12*), ramdisk & hard drive support,
*UPX* unpacking, multi-machines support and bug fixes.  

- ***ANIM.S*** and ***GHOSTS.S***  
The "*ghosts*" animation played while loading the hidden cracktro. Code by Fury!

- ***SHELL.S***  
A framework for the cracktros that provides system initialization/restoration
routines, VBL handler support (for frame rendering), 50Hz timer handler support
(for music playback), and mechanisms for exchanging information and synchronizing
with the loader.

- ***CRACKTRO.S***  
Simple example illustrating how to use the cracktro shell (as the source
code of the real cracktros is not provided).

- ***HIDDEN.TXT***  
The full text of the scroller of the hidden intro coded by Fury, with nostalgic
testimonials from 20 former Replicants members and friends who share their memories
and give news.

- ***SSS1.LNK***  
Library file containing the game files from disk#1, packed and linked together.

- ***SSS2.LNK***  
Library file containing the game files from disk#2, packed and linked together.

- ***README.TXT***  
Read-Me file provided on the floppy disk of the crack and describing the release.

- ***README.md***  
This file.
