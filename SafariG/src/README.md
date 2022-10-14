This directory contains the source files of the crack of ***Safari Guns***,
with plenty of explanations and comments:

- ***SAFARI.S***  
The main driver program in charge of executing the *Xmas* cracktro and the loader of the game.

- ***LOADER.S***  
The loader of the game providing the *ASCII* intro, trainer mode, linked-files/ramdisk support and on-the-fly files depacking.

- ***intro.lnk***  
Library file containing all binary files of the game intro, packed and linked together.

- ***intro.dir***  
Directory providing the list of all binary files linked in ***intro.lnk***.
This file is included and used by the loader code.

- ***game.lnk***  
Library file containing all binary files of the game, packed and linked together.

- ***game.dir***  
Directory providing the list of all binary files linked in ***game.lnk***.
This file is included and used by the loader code.

- ***NEWSCOR.DAT***  
Data file of the game providing high scores.

- ***README.TXT***  
Read-Me file provided on the floppy disk of the crack and describing the release.

- ***README.md***  
This file.
