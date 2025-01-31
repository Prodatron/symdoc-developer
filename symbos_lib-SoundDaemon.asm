;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@                 S Y M B O S   S Y S T E M   L I B R A R Y                  @
;@                         - SOUND DAEMON FUNCTIONS -                         @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

;Author     Prodatron / SymbiosiS
;Date       17.09.2023

;This library supports you in using all sound daemon functions.

;The existance of
;- "App_PrcID" (a byte, where the ID of the applications process is stored)
;- "App_MsgBuf" (the message buffer, 14 bytes, which are placed in the transfer
;  ram area)
;- "App_BnkNum" (a byte, where the number of the applications' ram bank (0-15)
;  is stored)
;is required.


;### SUMMARY ##################################################################

;    SySound_SNDINI              ;searches for Sound Daemon and gets infos
;use_SySound_MUSLOD      equ 0   ;loads and inits music data
;use_SySound_MUSFRE      equ 0   ;removes music data
;use_SySound_MUSRST      equ 0   ;restarts a music
;use_SySound_MUSCON      equ 0   ;continues playing a music
;use_SySound_MUSSTP      equ 0   ;pauses and mutes music
;use_SySound_MUSVOL      equ 0   ;sets music volume
;use_SySound_EFXLOD      equ 0   ;loads and inits effect data
;use_SySound_EFXFRE      equ 0   ;removes effect data
;use_SySound_EFXPLY      equ 0   ;starts playing an effect
;use_SySound_EFXSTP      equ 0   ;stop effects
;use_SySound_SNDCOO      equ 0   ;cooperation with SymAmp/3rd party sound players
;use_SySound_RMTCTR      equ 0   ;remote control
;use_SySound_RMTACT      equ 0   ;activates remote playing
;use_SySound_RMTDCT      equ 0   ;deactivates remote playing


;### GLOBAL VARIABLES #########################################################

SySound_PrcID db 0  ;sound daemon process ID (0=no sound daemon)


;### GENERAL FUNCTIONS ########################################################

SySound_SNDINI
;******************************************************************************
;*** ID             001 (SNDINI)
;*** Name           Sound_Init
;*** Input          -
;*** Output         CF   = Error state (0 = ok, 1 = Sound Daemon not running)
;***                - if CF is 0:
;***                (SySound_PrcID) = Sound daemon process ID
;***                A             = hardware flags
;***                                bit0 = 1 -> PSG  available
;***                                bit1 = 1 -> OPL4 available
;***                L             = prefered hardware (0=no hardware available,
;***                                                   1=PSG, 2=OPL4)
;***                C             = current effect master volume
;***                B             = current music  master volume
;***                - if OPL4 available:
;***                H             = number of total 64K blocks
;*** Destroyed      F,BC,DE,IX,IY
;*** Description    Before using any other functions of this library you have to
;***                call this first. It will check, if a sound daemon is running
;***                and will store its process ID if found.
;***                It will return information about the available and prefered
;***                sound hardware.
;******************************************************************************
        ld e,0
        ld hl,ssndmnt
        ld a,(App_BnkNum)
        call SySystem_PRGSRV
        or a
        scf
        ret nz
        ld a,h
        ld (SySound_PrcID),a
        call ssnmsgi_af
        db FNC_SND_SNDINF
        call ssnmsg1
        call ssnmsgo_afbchl
        or a
        ret
ssndmnt db "Sound Daemon"


;### MUSIC FUNCTIONS ##########################################################

ifdef use_SySound_MUSLOD
    if use_SySound_MUSLOD=1
;******************************************************************************
;*** ID             008 (MUSLOD)
;*** Name           Music_Load
;*** Input          E    = Source type (0=file, 1=memory [for PSG only])
;***                D    = Device (1=PSG, 2=OPL4)
;***                - if E is 0:
;***                A    = File handle
;***                - if E is 1:
;***                A    = Bank (1-15)
;***                HL   = Address
;***                BC   = Length
;*** Output         CF   = Error state (0 = ok, 1 = error; A = error code)
;***                - if CF is 0:
;***                A    = Handle (always 0-254)
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Loads and initializes a music collection.
;***                The source is usually an already opened file (E=0), so the
;***                file handle has to be passed in A. Please note that the
;***                file won't be closed after executing this function and will
;***                stay still opened. The idea is to have the possibility to
;***                store multiple data in the same file and read them
;***                sequentially.
;***                Only PSG music can be loaded from memory (E=1).
;***                Currently only one music can be loaded at the same time.
;******************************************************************************
SySound_MUSLOD
        call ssnmsgi_afbcdehl
        db FNC_SND_MUSLOD
        call ssnmsg1
        jp ssnmsgo_af
    endif
endif

ifdef use_SySound_MUSFRE
    if use_SySound_MUSFRE=1
;******************************************************************************
;*** ID             009 (MUSFRE)
;*** Name           Music_Free
;*** Input          A    = Handle
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Removes a music collection.
;***                Don't forget to call this function before quiting your
;***                application. Currently only one music can be handled at the
;***                same time, so you would block the whole system.
;******************************************************************************
SySound_MUSFRE
        call ssnmsgi_af
        db FNC_SND_MUSFRE
        ret
    endif
endif

ifdef use_SySound_MUSRST
    if use_SySound_MUSRST=1
;******************************************************************************
;*** ID             010 (MUSRST)
;*** Name           Music_Restart
;*** Input          A   = Handle
;***                L   = Subsound ID
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Starts playing a music from the beginning.
;******************************************************************************
SySound_MUSRST
        call ssnmsgi_afhl
        db FNC_SND_MUSRST
        ret
    endif
endif

ifdef use_SySound_MUSCON
    if use_SySound_MUSCON=1
;******************************************************************************
;*** ID             011 (MUSCON)
;*** Name           Music_Continue
;*** Input          A   = Handle
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Continues playing the current music.
;******************************************************************************
SySound_MUSCON
        call ssnmsgi_af
        db FNC_SND_MUSCON
        ret
    endif
endif

ifdef use_SySound_MUSSTP
    if use_SySound_MUSSTP=1
;******************************************************************************
;*** ID             012 (MUSSTP)
;*** Name           Music_Stop
;*** Input          A   = Handle
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Pauses and mutes music.
;******************************************************************************
SySound_MUSSTP
        call ssnmsgi_af
        db FNC_SND_MUSSTP
        ret
    endif
endif

ifdef use_SySound_MUSVOL
    if use_SySound_MUSVOL=1
;******************************************************************************
;*** ID             013 (MUSVOL)
;*** Name           Music_Volume
;*** Input          A   = Handle
;***                H   = Volume (0-255)
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Sets music volume. 255 is the default volume. 0 means
;***                muted, 255 loud. After loading a new music collection
;***                (MUSLOD), the volume is always set back to 255 again.
;******************************************************************************
SySound_MUSVOL
        call ssnmsgi_afhl
        db FNC_SND_MUSVOL
        ret
    endif
endif


;### EFFECT FUNCTIONS #########################################################

ifdef use_SySound_EFXLOD
    if use_SySound_EFXLOD=1
;******************************************************************************
;*** ID             016 (EFXLOD)
;*** Name           Effect_Load
;*** Input          E    = source type (0=file, 1=memory [for PSG only])
;***                D    = Device (1=PSG, 2=OPL4)
;***                - if E is 0:
;***                A    = File handle
;***                - if E is 1:
;***                A    = Bank (1-15)
;***                HL   = Address
;***                BC   = Length
;*** Output         CF   = Error state (0 = ok, 1 = error; A = error code)
;***                - if CF is 0:
;***                A    = Handle (always 1-254)
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Loads and inits an effect collection.
;***                The source is usually an already opened file (E=0), so the
;***                file handle has to be passed in A. Please note that the
;***                file won't be closed after executing this function and will
;***                stay still opened. The idea is to have the possibility to
;***                store multiple data in the same file and read them
;***                sequentially.
;***                Only PSG effects can be loaded from memory (E=1).
;******************************************************************************
SySound_EFXLOD
        call ssnmsgi_afbcdehl
        db FNC_SND_EFXLOD
        call ssnmsg1
        jp ssnmsgo_af
    endif
endif

ifdef use_SySound_EFXFRE
    if use_SySound_EFXFRE=1
;******************************************************************************
;*** ID             017 (EFXFRE)
;*** Name           Effect_Free
;*** Input          A   = Handle
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Removes an effect collection.
;***                Don't forget to call this function before quiting your
;***                application to release memory and system resources.
;******************************************************************************
SySound_EFXFRE
        call ssnmsgi_af
        db FNC_SND_EFXFRE
        ret
    endif
endif

ifdef use_SySound_EFXPLY
    if use_SySound_EFXPLY=1
;******************************************************************************
;*** ID             018 (EFXPLY)
;*** Name           Effect_Play
;*** Input          A   = Handle
;***                L   = Effect ID
;***                H   = Volume (0-255)
;***                - if device is PSG:
;***                B   = Priority type
;***                      1 -> play always on specified channel
;***                      2 -> play only, if specified channel is free
;***                      3 -> play always on rotating channel
;***                      4 -> play only, if one rotating channel is free
;***                      5 -> play only, if no other active effect at all
;***                - if device is PSG and priority type is 1 or 2:
;***                C   = Channel (0=left, 1=middle, 2=right)
;***                - if device is OPL4:
;***                B   = Priority type
;***                      1 -> play
;***                      2 -> play, first stop same effects of same handle
;***                      3 -> play, first stop all other effects of same handle
;***                C   = Panning (0-255, 0=left, 255=right)
;***                DE  = Pitch (0=use sample standard pitch)
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Starts playing an effect.
;******************************************************************************
SySound_EFXPLY
        call ssnmsgi_afbcdehl
        db FNC_SND_EFXPLY
        ret
    endif
endif

ifdef use_SySound_EFXSTP
    if use_SySound_EFXSTP=1
;******************************************************************************
;*** ID             019 (EFXSTP)
;*** Name           Effect_Stop
;*** Input          A   = Handle
;***                L   = Effect ID
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Stops all effects with a specified ID.
;******************************************************************************
SySound_EFXSTP
        call ssnmsgi_afhl
        db FNC_SND_EFXSTP
        ret
    endif
endif


;### SPECIAL FUNCTIONS ########################################################

ifdef use_SySound_SNDCOO
    if use_SySound_SNDCOO=1
;******************************************************************************
;*** ID             003 (SNDCOO)
;*** Name           Sound_Cooperation
;*** Input          A    = type
;***                        0 -> ask for PSG usage
;***                        1 -> ask for OPL4 usage
;***                       16 -> release PSG usage
;***                       17 -> release OPL4 usage
;*** Output         - if type was 0 or 1:
;***                CF   = status (0=ok, 1=device is currently occupied)
;***                - if type was 1 and CF=0:
;***                DE,HL= OPL4 ram start address
;***                A    = number of total 64K blocks
;*** Destroyed      F,BC,IX,IY
;*** Description    this function is used by SymAmp or other 3rd party sound
;***                players for cooperative usage of the available sound
;***                hardware.
;******************************************************************************
SySound_SNDCOO
        call ssnmsgi_af
        db FNC_SND_SNDCOO
        call ssnmsg1
        jp ssnmsgo_afbcdehl
    endif
endif

ifdef use_SySound_RMTCTR
    if use_SySound_RMTCTR=1
;******************************************************************************
;*** ID             005 (RMTCTR)
;*** Name           Remote_Control
;*** Input          A    = type
;***                        1 -> set master effect volume
;***                        2 -> set master music volume
;***                - if type is 1 or 2:
;***                L    = effect/music master volume
;*** Output         -
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Does remote control actions. Currently only used for
;***                setting the volume.
;******************************************************************************
SySound_RMTCTR
        call ssnmsgi_afhl
        db FNC_SND_RMTCTR
        call ssnmsg1
        ret
    endif
endif

ifdef use_SySound_RMTACT
    if use_SySound_RMTACT=1
;******************************************************************************
;*** ID             006 (RMTACT)
;*** Name           Remote_Activate
;*** Input          -
;*** Output         CF   = Error state (0 = ok, 1 = error; A = error code)
;***                - if CF is 0:
;***                HL   = Routine Address
;***                BC   = Routine Stack
;***                A    = Bank (1-15)
;*** Destroyed      F,DE,IX,IY
;*** Description    Activates remote playing.
;***                The sound daemon won't play music by itself anymore.
;***                Instead of that the application has to call its player
;***                routine once per frame (e.g. in an own timer process or
;***                after each RST #30 (MTSOFT).
;***                The player has to be called with the BNKCLL kernel function
;***                (Banking_Interbank_Call) in exactly this way:
;***
;***                LD IX,[Routine Address]
;***                LD IY,[Routine Stack]
;***                LD B,[Bank]
;***                CALL #FF03
;******************************************************************************
SySound_RMTACT
        call ssnmsgi
        db FNC_SND_RMTACT
        call ssnmsg1
        jp ssnmsgo_afbchl
    endif
endif

ifdef use_SySound_RMTDCT
    if use_SySound_RMTDCT=1
;******************************************************************************
;*** ID             007 (RMTDCT)
;*** Name           Remote_Deactivate
;*** Input          -
;*** Output         -
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Deactivates remote playing.
;***                The sound daemon continues playing music and effects by
;***                itself again.
;******************************************************************************
SySound_RMTDCT
        call ssnmsgi
        db FNC_SND_RMTDCT
        ret
    endif
endif


;### SUB ROUTINES #############################################################

ssnmsgi_afbcdehl
        ld (App_MsgBuf+06),de   ;store registers to message buffer
ssnmsgi_afbchl
        ld (App_MsgBuf+04),bc
ssnmsgi_afhl
        ld (App_MsgBuf+08),hl
ssnmsgi_af
        push af:pop hl
        ld (App_MsgBuf+02),hl
ssnmsgi pop hl
        ld a,(hl)               ;set command
        inc hl
        push hl
        ld (App_MsgBuf+0),a
        ld (ssnmsg2+1),a
        ld iy,App_MsgBuf
        ld a,(App_PrcID)
        db #dd:ld l,a
        ld a,(SySound_PrcID)
        db #dd:ld h,a
        ld (ssnmsg1+2),ix
        rst #10                 ;send message
        ret

ssnmsg1 ld ix,0                 ;wait for response
        rst #08
        db #dd:dec l
        jr nz,ssnmsg1
        ld a,(App_MsgBuf)
        sub 128
ssnmsg2 cp 0
        ret z
        ld a,(App_PrcID)        ;wrong response code -> put this back to the last entry in the message queue and wait for a correct one
        db #dd:ld h,a
        ld a,(SySound_PrcID)
        db #dd:ld l,a
        rst #10
        rst #30
        jr ssnmsg1

ssnmsgo_afbcdehl
        ld de,(App_MsgBuf+06)   ;get registers from the message buffer
ssnmsgo_afbchl
        ld bc,(App_MsgBuf+04)
ssnmsgo_afhl
        ld hl,(App_MsgBuf+02)
        push hl
        pop af
        ld hl,(App_MsgBuf+08)
        ret
ssnmsgo_af
        ld hl,(App_MsgBuf+02)
        push hl
        pop af
        ret
