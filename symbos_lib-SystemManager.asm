;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@                 S Y M B O S   S Y S T E M   L I B R A R Y                  @
;@                        - SYSTEM MANAGER FUNCTIONS -                        @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

;Author     Prodatron / Symbiosis
;Date       25.11.2025

;The system manager is responsible for starting and stopping applications and
;it also provides several dialogue services.
;This library supports you in using the system manager functions.

;The existance of
;- "App_PrcID" (a byte, where the ID of the applications process is stored)
;- "App_MsgBuf" (the message buffer, 14 bytes, which are placed in the transfer
;  ram area)
;- "App_BnkNum" (a byte, where the number of the applications' ram bank (0-15)
;  is stored)
;- "App_BegCode" (the address of the header/code area)
;is required.


;### SUMMARY ##################################################################

;use_SySystem_PRGRUN     equ 0   ;Starts an application or opens a document
;use_SySystem_PRGEND     equ 0   ;Stops an application and frees its resources
;use_SySystem_PRGSRV     equ 0   ;Manages shared services or finds applications
;use_SySystem_SYSWRN     equ 0   ;Opens an info, warning or confirm box
;use_SySystem_SELOPN     equ 0   ;Opens the file selection dialogue
;use_SySystem_HLPOPN     equ 0   ;Inits and opens the help file for this application
;use_SySystem_LNGLOD     equ 0   ;Loads a text pack from a language file


;### MAIN FUNCTIONS ###########################################################

ifdef use_SySystem_PRGRUN
    if use_SySystem_PRGRUN=1
SySystem_PRGRUN
;******************************************************************************
;*** Name           Program_Run_Command
;*** Input          HL = File path and name address
;***                A  = [Bit0-3] File path and name ram bank (0-15)
;***                     [Bit4  ] Flag, if additional options
;***                     [Bit5  ] Flag, if alternative priority
;***                     [Bit6  ] Flag, if always start as an application
;***                              (ignore file associations)
;***                     [Bit7  ] Flag, if system error message should be
;***                              suppressed
;***                - if alternative priority:
;***                E  = priority (1[high] - 7[low])
;***                - if additional options:
;***                IXL= [Bit0]   Flag, if working directory path available
;***                IXH= Window Mode (0=unchanged, 1=normal, 2=maximized,
;***                                  3=minimized, +128=open window centered)
;***                - if working directory available:
;***                IY = working directory (up to 128bytes including
;***                     0-terminator), same ram bank like file path
;*** Output         A  = Success status
;***                     0 = OK
;***                     1 = File does not exist
;***                     2 = File is not an executable and its type is not
;***                         associated with an application
;***                     3 = Error while loading (see P8 for error code)
;***                     4 = Memory full
;***                - If success status is 0:
;***                L  = Application ID
;***                H  = Process ID (the applications main process)
;***                - If success status is 3:
;***                L  = File manager error code
;*** Destroyed      F,BC,DE,IX,IY
;*** Description    Loads and starts an application or opens a document with a
;***                known type by loading the associated application first.
;***                If Bit7 of A is not set, the system will open a message box,
;***                if an error occurs during the loading process.
;***                If the operation was successful, you will find the
;***                application ID and the process ID in L and H. If it failed
;***                because of loading problems L contains the file manager
;***                error code.
;******************************************************************************
        call SySSMg2
        ld c,MSC_SYS_PRGRUN
        call SySystem_WaitMessage
        ld hl,(App_MsgBuf+8)
        ret
    endif
endif

ifdef use_SySystem_PRGEND
    if use_SySystem_PRGEND=1
SySystem_PRGEND
;******************************************************************************
;*** Name           Program_End_Command
;*** Input          L  = Application ID
;*** Output         -
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Stops an application and releases all its used system
;***                resources. This command first stops all processes of the
;***                application. After this all open windows will be closed and the
;***                reserved memory will be released.
;***                Please note, that this command can't release memory, stop
;***                processes and timers or close windows, which are not
;***                registered for the application. Such resources first have
;***                to be released by the application itself.
;******************************************************************************
        ld c,MSC_SYS_PRGEND
        jp SySystem_SendMessage
    endif
endif

ifdef use_SySystem_PRGDBL
    if use_SySystem_PRGDBL=1
SySystem_PRGDBL
;******************************************************************************
;*** Name           Program_Double_Command
;*** Input          -
;*** Output         ZF = 1 -> application is already running
;***                - if ZF:
;***                L  = existing Application ID
;***                H  = existing Process ID (the applications main process)
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Checks, if this application or at least an application with
;***                a name having the first 12 identical chars is already
;***                running.
;***                This can be used to prevent multiple execution of the same
;***                application - an application could quit itself immediately
;***                if it finds out, that it is already running.
;******************************************************************************
        ld hl,App_BegCode+15
        push hl
        ld de,SySPDbn
        ld bc,12
        ldir
        pop hl
        ld (hl),0
        ld hl,SySPDbn
        ld a,(App_BnkNum)
        ld e,0
        call SySystem_PRGSRV
        or a
        ld a,(SySPDbn)
        ld (App_BegCode+15),a
        ret

SySPDbn ds 12
    endif
endif

ifdef use_SySystem_PRGSRV
    if use_SySystem_PRGSRV=1
SySystem_PRGSRV
;******************************************************************************
;*** Name           Program_SharedService_Command
;*** Input          E  = Command type
;***                     0 = search application or shared service
;***                     1 = search, start and use shared service
;***                     2 = release shared service
;***                - if E is 0 or 1:
;***                HL = Address of the 12byte application ID string
;***                A  = Ram bank (0-15) of the 12byte application ID string
;***                - if E is 2:
;***                A  = Application ID of shared service
;*** Output         A  = Result status
;***                     0 = OK
;***                     5 = application or shared service not found (can only
;***                         occur on command type 0)
;***                     1-4=error while starting shared service; same codes
;***                         like in MSR_SYS_PRGRUN, please read there for a
;***                         detailed description
;***                - If command type was 0 or 1, and result status is 0:
;***                L  = Application ID
;***                H  = Process ID (the applications main process)
;***                - If result status is 3:
;***                L  = File manager error code
;*** Destroyed      F,BC,DE,IX,IY
;*** Description    This function can be used to find, start and release shared
;***                services or to find applications.
;***                For a detailed description please read chapter "System
;***                Manager", "Program_SharedService_Command" in the SymbOS
;***                Developer Documentation.
;******************************************************************************
        ld c,MSC_SYS_PRGSRV
        call SySystem_WaitMessage
        ld hl,(App_MsgBuf+8)
        ret
    endif
endif

ifdef use_SySystem_SYSWRN
    if use_SySystem_SYSWRN=1
SySystem_SYSWRN
;******************************************************************************
;*** Name           Dialogue_Infobox_Command
;*** Input          HL = Content data address (#C000-#FFFF)
;***                A  = Content data ram bank (0-15)
;***                B  = [Bit0-2] Number of buttons (1-3)
;***                              1 = "OK" button
;***                              2 = "Yes", "No" buttons
;***                              3 = "Yes", "No", "Cancel" buttons
;***                     [Bit3-5] Titletext
;***                              0 = default (bit7=[0]"Error!"/[1]"Info")
;***                              1 = "Error!"
;***                              2 = "Info"
;***                              3 = "Warning"
;***                              4 = "Confirmation"
;***                     [Bit6  ] Flag, if window should be modal window
;***                     [Bit7  ] Box type
;***                              0 = default (warning [!] symbol)
;***                              1 = info (own symbol will be used)
;***                DE = 0 or data record of the caller window; the dialogue
;***                     window will be a modal window of it, during its open
;*** Content data   00  1W  Address of text line 1
;***                02  1W  4 * [text line 1 pen] + 2
;***                04  1W  Address of text line 2
;***                06  1W  4 * [text line 2 pen] + 2
;***                08  1W  Address of text line 3
;***                10  1W  4 * [text line 3 pen] + 2
;***                - if B[bit7] is 1:
;***                12  1W  Address of symbol (24x24px 4col SymbOS graphic format)
;***                        or 0
;***                - if B[bit7] is 1 and P12 is 0:
;***                14  1W  Address of symbol (24x24px 4col SymbOS graphic format)
;***                16  1W  Address of symbol (24x24px 16col SymbOS graphic format)
;*** Output         A  = Result status
;***                     0 -> The infobox is currently used by another
;***                          application. It can only be opened once at the
;***                          same time, if it's not a pure info message (one
;***                          button, not a modal window). The user should
;***                          close the other infobox first before it can be
;***                          opened again by the application.
;***                     2 -> The user clicked "OK".
;***                     3 -> The user clicked "Yes".
;***                     4 -> The user clicked "No".
;***                     5 -> The user clicked "Cancel" or the close button.
;***                     Please note -> if the alert is no modal window and
;***                              contains only one button, it will always return 0
;*** Destroyed      F,BC,DE,HL,IX,IY
;*** Description    Opens an info, warning or confirm box and displays three line
;***                of text and up to three click buttons.
;***                If Bit7 of B is set to 1, you can specify an own symbol, which
;***                will be showed left to the text. If this bit is not set, a "!"-
;***                warning symbol will be displayed.
;***                If Bit6 of B is set to 1, the window will be opened as a modal
;***                window, and you will receive a message with its window number
;***                (see MSR_SYS_SYSWRN).
;***                Please note, that the content data must always be placed in the
;***                transfer ram area (#C000-#FFFF). The texts itself and the
;***                optional graphic must always be placed inside a 16K (data ram
;***                area).
;***                As the text line pen, you should choose 1, so 6 would be the
;***                correct value.
;***                For more information about the mentioned memory types (data,
;***                transfer) see the "applications" chapter.
;***                For more information about the SymbOS graphic format see the
;***                "desktop manager data records" chapter.
;******************************************************************************
        ld (SySWrnW+2),de
        ld e,b
        ld c,MSC_SYS_SYSWRN
        push bc
        call SySystem_SendMessage
        ld a,MSR_SYS_SYSWRN
        ld (SySWMsN+1),a
        pop af
        and 7+64
        dec a
        ret z
SySWrn1 call SySWMs0
        ld b,a
SySWrnW ld ix,0
        ld a,ixl
        or ixh
        ld c,0
        jr z,SySWrn2
        ld (ix+51),c
        inc c
SySWrn2 ld a,b
        dec b
        ret nz
        dec c
        jr nz,SySWrn1
        ld a,(App_MsgBuf+2)
        ld (ix+51),a
        jr SySWrn1
    endif
endif

ifdef use_SySystem_SELOPN
    if use_SySystem_SELOPN=1
SySystem_SELOPN
;******************************************************************************
;*** Name           Dialogue_FileSelector_Command
;*** Input          HL = File mask, path and name address (#C000-#FFFF)
;***                     00  3B  File extension filter (e.g. "*  ")
;***                     03  1B  0
;***                     04 256B path and filename
;***                A  = [Bit0-3] File mask, path and name ram bank (0-15)
;***                     [Bit6  ] Flag, if "open" (0) or "save" (1) dialogue
;***                     [Bit7  ] Flag, if file (0) or directory (1) selection
;***                C  = Attribute filter
;***                     Bit0 = 1 -> don't show read only files
;***                     Bit1 = 1 -> don't show hidden files
;***                     Bit2 = 1 -> don't show system files
;***                     Bit3 = 1 -> don't show volume ID entries
;***                     Bit4 = 1 -> don't show directories
;***                     Bit5 = 1 -> don't show archive files
;***                IX = Maximum number of directory entries (<=512)
;***                IY = Maximum size of directory data buffer (<=16384)
;***                DE = Data record of the caller window; the file selector
;***                     window will be a modal window of it, during its open)
;*** Output         A  = Success status
;***                     0 -> The user choosed a file and closed the dialogue
;***                          with "OK". The complete file path and name can be
;***                          found in the filepath buffer of the application.
;***                     1 -> The user aborted the file selection. The content
;***                          of the applications filepath buffer is unchanged.
;***                     2 -> The file selection dialogue is currently used by
;***                          another application. It can only be opened once
;***                          at the same time. The user should close the
;***                          dialogue first before it can be opened again by
;***                          the application.
;***                     3 -> Memory full. There was not enough memory
;***                          available for the directory buffer and/or the
;***                          list data structure.
;***                     4 -> No window available. The desktop manager couldn't
;***                          open a new window for the dialogue, as the
;***                          maximum number of windows (32) has already been
;***                          reached.
;***                - if A is 0:
;***                L  = Path length
;*** Destroyed      F,BC,DE,HL,IX,IY
;*** Description    Opens the file selection dialogue. In this dialogue the user
;***                can move through the directory structure, change the drive and
;***                search and select a file or a directory for opening or saving.
;***                If you specify a path, the dialogue will start directly in the
;***                directory. If you append a filename, too, it will be used as
;***                the preselected file.
;***                You can filter the entries of the directory by attributes and
;***                filename extension. We recommend always to set Bit3 of the
;***                attribute filter byte.
;***                The File mask/path/name string (260 bytes) must always be
;***                placed in the transfer ram area (#C000-#FFFF). For more
;***                information about this memory types see the "applications"
;***                chapter.
;***                Please note, that the system will reserve memory to store the
;***                listed directory entries and the data structure of the list.
;***                With IX and IY you can choose, how much memory should be used.
;***                We recommend to set the number of entries between 100 and 200
;***                (Amsdos supports a maximum amount of 64 entries) and to set the
;***                data buffer between 5000 and 10000.
;******************************************************************************
        ld (SySSOp1+2),de
        call SySSMg1
        ld c,MSC_SYS_SELOPN
        call SySystem_WaitMessage
SySSOp1 ld ix,0
        ld (ix+51),0
        ld hl,(App_MsgBuf+2)
        cp -1
        ret nz
        ld (ix+51),l
        call SySWMs0
        jr SySSOp1
    endif
endif

ifdef use_SySystem_HLPOPN
    if use_SySystem_HLPOPN=1
;******************************************************************************
;*** Name           Help_Init
;*** Input          -
;*** Output         -
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Initializes the path for the help file. This has to be called
;***                before using the Help_Open function (see SySystem_HLPOPN).
;***                As it accesses the applications path string at the end of the
;***                code area you should call this function after the application
;***                started in case you use additional memory behind the code area
;***                later for other stuff.
;***                For more information see SySystem_HLPOPN.
;******************************************************************************
SySystem_HLPFLG db 0    ;flag, if HLP-path is valid
SySystem_HLPPTH db "%help.exe "
SySystem_HLPPTH1 ds 128
SySHInX db ".HLP",0

SySystem_HLPINI
        ld hl,(App_BegCode)
        ld de,App_BegCode
        dec h
        add hl,de                   ;HL = CodeEnd = Command line
        ld de,SySystem_HLPPTH1
        ld bc,0
        db #dd:ld l,128
SySHIn1 ld a,(hl)
        or a
        jr z,SySHIn3
        cp " "
        jr z,SySHIn3
        cp "."
        jr nz,SySHIn2
        ld c,e
        ld b,d
SySHIn2 ld (de),a
        inc hl
        inc de
        db #dd:dec l
        ret z
        jr SySHIn1
SySHIn3 ld a,c
        or b
        ret z
        ld e,c
        ld d,b
        ld hl,SySHInX
        ld bc,5
        ldir
        ld a,1
        ld (SySystem_HLPFLG),a
        ret

;******************************************************************************
;*** Name           Help_Open
;*** Input          -
;*** Output         -
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Opens the applications help file and displays it in the
;***                SymbOS help document browser.
;***                The help file has to have the same filename like the
;***                applications main EXE file with the file extension HLP, and
;***                it has to be located in the same directory.
;***                You have to call SySystem_HLPINI once when starting the
;***                application before you can use SySystem_HLPOPN.
;******************************************************************************
SySystem_HLPOPN
        ld a,(SySystem_HLPFLG)
        or a
        ret z
        ld hl,SySystem_HLPPTH
        ld a,(App_BnkNum)
        jp SySystem_PRGRUN
    endif
endif

ifdef use_SySystem_LNGLOD
    if use_SySystem_LNGLOD=1
SySystem_LNGLOD
;******************************************************************************
;*** Name           Language_Load
;*** Input          IXL= application's default language ID (usually 9 for english)
;***                IXH= pack
;***                IYL= version
;***                A  = application path bank
;***                DE = application path address
;***                C  = text bank
;***                HL = text address
;*** Output         A  = Success status
;***                     0 -> service not available
;***                     1 -> OK, the required language package has either been
;***                          loaded successfully, or the application's default
;***                          language matches the required language
;***                     2 -> no LNG file found or disc error
;***                     3 -> wrong version or pack number too high
;***                     4 -> language not available
;*** Destroyed      F,BC,DE,HL,IX,IY
;*** Description    Tries to replace the default language of the application with
;***                the alternative language, set by the user in the control panel,
;***                from the application's language pack (*.LNG) file. The path
;***                does not need to contain the exact LNG filename, as the
;***                function always replaces the file extension with "LNG".
;***                Therefore, you can usually just use the application's original
;***                path, which will not change when returning from the function.
;***                The text bank and address must point to the first entry in the
;***                text pointer list, which must be located directly before the
;***                section containing the text strings. Each text pointer is 3
;***                bytes in size. A byte with the value 1, followed by a word that
;***                references the text string. The number of text pointers must
;***                correspond to the number of texts in the respective package.
;***                The package number selects the text package if multiple text
;***                locations exist, whether in different memory areas or in
;***                multiple binaries of the same application. The version number
;***                helps avoid conflicts that can arise if different versions of
;***                the application binary and its language pack file (LNG) are
;***                accidentally present. The application's default language ID is
;***                used to check whether a text exchange is even necessary.
;******************************************************************************
        call SySSMg1
        ld a,(App_BnkNum)
        ld iyh,a
        ld c,MSC_SYS_EXTFNC
        ld l,FNC_DXT_LNGLOD
        jr SySystem_WaitMessage
    endif
endif


;******************************************************************************
;*** Name           Macro_APPINI
;*** Input          0/main window data record
;***                0/working_directory
;*** Destroyed      AF,BC,DE,HL
;*** Description    Optionally sets the window mode and working directory that
;***                have been configured for the application in the icon or
;***                start menu shortcut. The parameters must be the addresses
;***                of the window data record and the working directory string
;***                (up to 128 bytes including a zero terminator), which is
;***                used e.g. as the starting point when opening a document.
;***                If either parameter is set to 0, it is ignored.
;******************************************************************************
macro SyMacro_APPINI window_record, working_directory
    if "window_record" = "0"
    else
        ld a,(App_BegCode+47)       ;window mode
        or a
        jr z,@appini1
        ld (window_record+0),a
        @appini1
    endif
    if "working_directory" = "0"
    else
        ld a,(App_BegCode+46)       ;working directory
        bit 0,a
        jr z,@appini2
        ld hl,(App_BegCode)
        ld bc,App_BegCode
        add hl,bc
        ld bc,128
        sbc hl,bc
        ld de,working_directory
        ldir
        @appini2
    endif
mend





;### SUB ROUTINES #############################################################

SySystem_SendMessage
;******************************************************************************
;*** Input          C       = Command
;***                HL,A,DE = additional Parameters
;*** Output         -
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Sends a message to the system manager
;******************************************************************************
        ld (App_MsgBuf+3),a
SysSMg0 ld (App_MsgBuf+1),hl
        ld (App_MsgBuf+4),de
        ld iy,App_MsgBuf
        ld (iy+0),c
        ld ix,(App_PrcID)
        ld ixh,PRC_ID_SYSTEM
        rst #10
        ret
SySSMg1 ld (App_MsgBuf+6),a
        ld (App_MsgBuf+7),bc
        ld (App_MsgBuf+8),hl
SySSMg2 ld (App_MsgBuf+10),ix
        ld (App_MsgBuf+12),iy
        ret

SySystem_WaitMessage
;******************************************************************************
;*** Input          C       = Command
;***                HL,A,DE = additional Parameters
;*** Output         IY = message buffer
;***                A  = first byte in the Message buffer (IY+0)
;*** Destroyed      AF,BC,DE,HL,IX,IY
;*** Description    Sends a message to the System Manager and waits for
;***                response
;******************************************************************************
        ld (App_MsgBuf+3),a
        ld a,c
        add 128
        ld (SySWMsN+1),a
        call SysSMg0
SySWMs0 ld iy,App_MsgBuf
SySWMs1 ld ix,(App_PrcID)
        ld ixh,PRC_ID_SYSTEM
SySWMs2 rst #08             ;wait for a system manager message
        dec ixl
        jr nz,SySWMs1
        ld hl,(App_MsgBuf+0)
SySWMsN ld a,0              ;check, if matching response
        cp l
        ld a,h              ;a=(msgbuf+1)
        ret z
        ld ix,(App_PrcID-1) ;no -> ixl=sender (system), ixh=receiver (me)
        ld ixl,PRC_ID_SYSTEM
        rst #10             ;resend message to myself
        rst #30
        jr SySWMs1
