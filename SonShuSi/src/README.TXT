                      E N J O Y    T H E    V i O L E N C E
   /___  __ _ _ _ ___---------------___  ___---------------___ _ _ _ __  ___\
      /   / / ////                     \/                     \\\\ \ \   \
              ///                                              \\\
              //                                                \\
              /        ____           \  /           ____        \
              |       _\  /____    __      __    ____\  /_       |
              |       \ \/     ----\/_    _\/----     \/ /       |
              |        \             /    \             /        |
              /         \___________/      \___________/         \
        __   _\_                      .  :                      _/_   __ 
       /_/ //_                        |  |                        _\\ \_\
              \                      /|  |\                      /
               \__ _                 \/  \/                 _ __/
                 \_____ _  .                        .  _ _____/
                        \  :    .              .    :  /
                        \\ |                        | //
                         \\|    :    .    .    :    |//
                          /|    |    |    |    |    |\
                          /|    |    |    |    |    |\
                           |    |    |    |    |    |
                           :\__ | :  |    | :  | __/:
                               \\_\/_| :  |_\/_//
                                     |_\/_|

                    _______________________________________
                   |   |      |            ____  |         \
                   | ^ |      | SNS       |    | |          |
                   | | |      |           |    | |          |
                   !   !      | MF-2DD    |    | |          |
                 ____    __   | 720 KB    |    | |          |
                 \ / /_/ /_\  !           |____| |          |
                  / / / /__     _/\_ ____________|          !
_  _____ _  _____ _  _____   /\ \__/  _____ _  _____ _  _____ _  _____ _  ___ _
 _\\__  \__\\__  \__\\__  \_/  \\  |_\\__  \__\\__  \__\\__  \__\\__  \__\\__\_
|   /    /   /    /   /    /   /___|   /    /   /    /   /    /   /   _/   /__/
| _/ ___/_  /    /   /    /   /    /  /____/   /    /   /    /\__/    \_____  |
| \       \ ____/    ____/   /    /| /    /  __    /   /    /sns/    /    /   |
!__\       \____\____! .\_________\!______\__/_____\  /_____\  /_____\________!
.   \        /     . . |           .                \/  .   .                 .
     \  ____/      |   |           SiNCE 1988           |   |
.     \/           |   |  T H E    R E P L i C A N T S  |   |                 .
                   |   |                                |   |
                   |   |        CRACKiNG iS LiFE        |   |
                   | # |      THE REST iS DETAiLS!      |   |
                   |___|________________________________|___|


......................................................... ...  ..   .
:     README INFORMATiON FiLE FOR   SON SHU SHi   RELEASED ON 1o/Dec/2o22
:................................................................... ...  ..  .


            .   ..  ... .......................................................
                                                                              :
  Son Shu Shi - First 100% Version                                            :
                                                                              :
  Checksums removed, mega-trained, filed, repacked, linked, ramdisk,          :
  bug-fixed, hard-drive and MegaSTe/Falcon/TT/CT60 support                    :
                                                                              :
  Retro-hacking work done by Orion of The Replicants                          :
                                                                              :
.   ..  ... ..................................................................:


......................................................... ...  ..   .
: 
: Changes and improvements made to this game:
:
: - Completely remove the copy-protection and especially the checksum
:   routines
: - Add FDC/DMA and FAT12 loading support
: - Add 1.44 MB high density floppy disk support
: - Add ramdisk and hard drive loading support
: - Repack game files with UPX
: - Add a mega-trainer
: - Add support for MegaSTe, TT, Falcon and CT60 machines
: - Use improved sample replay routines (music modules and sound FX) that
:   work on Falcon and do not hang on ST in the high score screen
: - Improve the stability of the rasters in the high score screen
: - Allow the musics to be played at 50Hz, and the game frame rate to run at
:   the correct speed, on 60Hz monitors
: - Emulate the movep instruction on 68060 CPUs (CT60)
: - Open the low border (overscan) only on ST(e) machines running at 8MHz,
:   thereby avoiding a crash on faster machines.
: - Use improved ACIA/IKBD routines (keyboard/joystick) so that IKBD events
:   are no longer lost
: - Modify the game finale (special animation played when the game has been
:   finished) so that it is now possible to access the high score screen and
:   restart the game
: - Improve the blank screen routine (cleanup routine called at the end of
:   every game subprogram)
: - Fix a crash that may occur on fast machines when the scene (the
:   background) is drawn
: - Fix an out-of-bounds array access when too many objects (coins,
:   diamonds, food...) exist at the same time
: - Fix an out-of-bounds array access when too many projectiles appear
:   on the screen at the same time
: - Fix an out-of-bounds array access when 6 or more weapon bonuses
:   appear on the screen at the same time
: - Fix an underflow error that occurs in the state machine used to display
;   enemy animations
: 
:................................................................... ...  ..  .


            .   ..  ... .......................................................
                                                                              :
  Hardware requirements:                                                      :
                                                                              :
  - The game runs on ST(e), MegaSTe, TT, Falcon and CT60 machines             :
  - It runs from floppy disks on all machines including those with only       :
    512 KB of RAM                                                             :
  - It can run from a single 1.44 MB high-density floppy disk if supported by :
    hardware, otherwise 2 standard floppies should be used                    :
  - On a machine with 1 MB of RAM or more, the first disk is preloaded in a   :
    ramdisk to improve the loading speed and avoid having to periodically     :
    swap the two floppy disks                                                 :
  - The game can run from a hard drive on a machine with 2MB of RAM or more,  :
    just copy all files present on the floppy disks into a folder on your     :
    hard drive, move SSS.PRG out of the AUTO folder and place it next to the  :
    other files                                                               :
                                                                              :
.   ..  ... ..................................................................:


......................................................... ...  ..   .
: 
: This release contains the following files stored either on 2 standard floppy
: disks or on a single 1.44 MB high-density floppy disk:
:
: - AUTO/SSS.PRG
:   Loader of the game in charge of initializing the system, executing the main
:   and hidden cracktros, and providing all the changes and improvements to the
:   game: trainer mode, file loading (FDC/DMA/FAT12), ramdisk & HDD support,
:   UPX unpacking, multi-machines support and bug fixes
:
: - SSS_60HZ.PRG
:   A second version of the loader, identical to the one in the AUTO folder,
:   except that it sets the video refresh rate of the ST(e) family machines
:   to 60Hz instead of 50Hz. For use on NTSC compliant systems, for example.
:
: - CRACKTRO.68K
:   The main cracktro 
:
: - HIDDEN.68K
:   The hidden cracktro
:
: - SSS1.LNK
:   Library file containing the game files from disk#1, packed and linked
:   together
:
: - SSS2.LNK
:   Library file containing the game files from disk#2, packed and linked
:   together
:
: - README.TXT
:   This file
: 
:................................................................... ...  ..  .


            .   ..  ... .......................................................
                                                                              :
  Credits for this release:                                                   :
                                                                              :
  Retro-hacking work & game loader code by Orion / The Replicants             :
  Initial but not 100% crack by Terminator Kid                                :
  Working copy supplied by Mit / NeXT                                         :
  Floppy disks Kryoflux'ed by Brume / Atari Legend                            :
  Testing on real HW by Twister, GT Turbo, Cooper, Fury & Jade                :
  Game loader fonts by Walt (L'Ing), first used in Fury's "Bloody" intro      :
  Code of the main cracktro by Kelly.X / HMD                                  :
  Code of the "ghosts" animation by Fury / The Replicants                     :
  Code of the hidden cracktro by Fury / The Replicants                        :
  Code of the cracktro shell by Orion / The Replicants                        :
  Graphics of the main cracktro by Dieu / HMD                                 :
  Graphics of the hidden cracktro by Jade / HMD                               :
  Music of the main & hidden cracktros by Dma-Sc / Sector One                 :
  ASCII art of this README by Senser / Effect                                 :
  UPX packer by The UPX Team                                                  :
                                                                              :
  Git repository: https://github.com/orionfuzion/newcracks                    :
  Contact:        orion.replicants@gmail.com or orion.fuzion@gmail.com        :
                                                                              :
.   ..  ... ..................................................................:


