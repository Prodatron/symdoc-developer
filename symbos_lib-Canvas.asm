;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;@                                                                            @
;@                  S Y M B O S   C A N V A S   E N G I N E                   @
;@              SPRITES, COLLISION DETECTION, TILE BASED CANVAS               @
;@                                                                            @
;@             (c) 2023-2026 by Prodatron / SymbiosiS (Jörn Mika)             @
;@                                                                            @
;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@


;features
;- Supports canvas bitmaps up to 16K
;- Canvas, sprites, and tiles can each be individually placed in any 64 KB RAM
;  memory area, regardless of the location of the other sprites, tiles and the
;  application code
;- Independent of pixel encoding type, works with both CPC and MSX encoding on
;  all 2-, 4-, and 16-color platforms
;- Canvas can be pre-rendered with tiles
;- Tiles can be swapped out again on the canvas and displayed directly
;- Fast sprite movement with optimized background restoration
;- Sprites can optionally resize during animation
;- Collision detection between two individual sprites or between a sprite and
;  all existing enemy sprites



;--- INIT ---------------------------------------------------------------------
;### CVS_Init               -> reserves a background canvas in any bank and prepares everything for the canvas engine
;### CVS_Update             -> updates canvas encoding/xbytes after first display
;### CVS_Canvas_Fill        -> fills canvas with colour
;### CVS_Tile_Convert       -> converts a tile to another encoding or the current canvas bitmap encoding

;--- SPRITE ROUTINES ----------------------------------------------------------
;### CVS_Sprite_Animate     -> updates sprite and background restore controls and headers
;### CVS_Sprite_Collisions  -> collision detection
;### CVS_Sprite_Collision   -> collision detection between two specific sprites

;--- TILE AND CANVAS PLOTTING -------------------------------------------------
;### CVS_Tile_PlotShow      -> plots tile into canvas and shows it on the screen
;### CVS_Tile_Plot          -> plots tile into canvas

;--- SUB ROUTINES -------------------------------------------------------------
;### CVSTHD -> get tile header
;### CLCMU8 -> 8x8bit unsigned multiplication

;---



;canvas data record
bgr_xpos    equ 0   ;position within form
bgr_ypos    equ 1
bgr_adr     equ 2   ;address headers (spr_max*9+10); address of total block
bgr_adrbmp  equ 4   ;address background bitmap
bgr_adrtil  equ 6   ;address tile function + tile buffer
bgr_memsiz  equ 8   ;size of the reserved additional memory
bgr_bnk     equ 10  ;64k ram bank (1-15)
bgr_bnkcop  equ 11  ;bit0-3 app bank, bit4-7 background bitmap bank
bgr_enc     equ 12  ;encoding type (0 or 5);    **may change after first display!**
bgr_xbytes  equ 13  ;width in bytes;            **may change after first display!**

spr_count   equ 14  ;number of sprites
spr_headers equ 15  ;total size of background restore headers (=number*9)

spr_data    equ 16  ;begin of sprite data records

;sprite data sub record
spr_flag    equ 0   ;0=not used, +1=used, +2=check for collision, +4=size has shrunk
spr_old_x   equ 1   ;old x position
spr_pos_x   equ 2   ;new x position
spr_len_x   equ 3   ;    x size
spr_old_y   equ 4   ;old y position
spr_pos_y   equ 5   ;new y position
spr_len_y   equ 6   ;    y size
           ;equ 7   ;*reserved*
spr_contrl  equ 8   ;points to background restore (+00) and sprite (+16) control
spr_backgr  equ 10  ;points to background restore header
spr_len_x_o equ 12  ;old x size
spr_len_y_o equ 13  ;old y size

spr_reclen  equ 14

spr_max     equ 16




;==============================================================================
;### INIT #####################################################################
;==============================================================================

;### CVS_Init -> reserves a background canvas in any bank and prepares everything for the canvas engine
;### Input      A=number of sprites, E=xsize in bytes, L=xsize in pixels, H=ysize in pixels, D=encoding type (0 or 5), BC=tile buffer size
;###            IX=canvas data record, IY=sprite control data records
;### Output     CF=0 -> ok, A=memory/background bank, HL=background address, DE=memory address, BC=memory size
;###            CF=1 -> memory full
;### Destroyed  AF,B,D

bgrhed  ds 9*spr_max
bgrhed0 ds 10

CVS_Init
        ld (ix+spr_count),a
        ld (bgrhed0+1),hl
        ld l,a
        add a
        add a
        add a
        add l
        ld (ix+spr_headers),a
        ld a,d
        ld (bgrhed0+9),a
        ld (ix+bgr_enc),a
        push hl
        or a
        db #21:srl l
        jr z,cvsini3
        ld hl,0
cvsini3 ld (cvssprk),hl
        pop hl
        ld a,e
        ld (bgrhed0+0),a
        ld (ix+bgr_xbytes),a
        ld (cvstil4+1),a
        push bc
        ld e,a
        call clcmu8             ;hl=background bitmap size
        ld (bgrhed0+7),hl
        pop bc                  ;bc=tilebuffer size
        add hl,bc
        ld bc,9*spr_max+10+cvstil_end-cvstil0
        add hl,bc               ;hl=bitmap+tilebuffer+headers+plotroutine
        ld (ix+bgr_memsiz+0),l
        ld (ix+bgr_memsiz+1),h
        ld c,l
        ld b,h
        xor a
        ld e,1
        rst #20:dw jmp_memget
        ret c
        ld (ix+bgr_bnk),a       ;store bank
        ld (ix+bgr_adr+0),l     ;store total/headers address
        ld (ix+bgr_adr+1),h
        push hl
        ld bc,9*spr_max+10
        add hl,bc
        ld (ix+bgr_adrbmp+0),l  ;store bitmap address
        ld (ix+bgr_adrbmp+1),h
        ld (bgrhed0+3),hl
        dec hl
        ld (bgrhed0+5),hl       ;store encoding byte address
        inc hl
        ld bc,(bgrhed0+7)
        add hl,bc
        ld (ix+bgr_adrtil+0),l  ;store tile function address
        ld (ix+bgr_adrtil+1),h
        ld bc,cvstil_end-cvstil0
        add hl,bc
        ld (cvstil2+1),hl       ;store tile buffer address
        add a:add a:add a:add a
        ld hl,App_BnkNum
        add (hl)
        ld (ix+bgr_bnkcop),a    ;store src/dst bank for copying

        pop hl                  ;hl=headers address
        ld b,(ix+spr_count)
        ld c,(ix+bgr_bnk)
        push ix
        ld de,spr_data
        add ix,de
        push ix
cvsini1 ld (iy+00+2),64         ;deactivated
        ld (iy+00+3),c          ;header bank
        ld (iy+00+4),l          ;header address
        ld (iy+00+5),h

        ld a,(iy+16+10)         ;init sprite data record with form control data
        ld (ix+spr_len_x),a
        ld a,(iy+16+12)
        ld (ix+spr_len_y),a

        ld a,iyl
        ld (ix+spr_contrl+0),a
        ld a,iyh
        ld (ix+spr_contrl+1),a
        ld de,9
        add hl,de
        ld de,spr_reclen
        add ix,de
        ld de,32
        add iy,de
        djnz cvsini1

        pop ix
        ld de,bgrhed
        ld a,(ix-spr_data+spr_count)
cvsini2 ld (ix+spr_backgr+0),e
        ld (ix+spr_backgr+1),d
        ld hl,bgrhed0           ;prepare restore bitmap headers
        ldi
        ex de,hl
        ld (hl),2:inc hl:inc de
        ld (hl),2:inc hl:inc de
        ex de,hl
        ld bc,6
        ldir
        ld c,spr_reclen
        add ix,bc
        dec a
        jr nz,cvsini2

        pop ix
        ld c,9*spr_max+10
        call cvsspri
        ld a,(ix+bgr_bnkcop)
        ld e,(ix+bgr_adrtil+0)
        ld d,(ix+bgr_adrtil+1)
        ld hl,cvstil0
        ld bc,cvstil_end-cvstil0
        rst #20:dw jmp_bnkcop
        ld a,(ix+bgr_bnk)
        ld l,(ix+bgr_adr+0)
        ld h,(ix+bgr_adr+1)
        ld e,l
        ld d,h
        ld bc,9*spr_max
        add hl,bc
        ld c,(ix+bgr_memsiz+0)
        ld b,(ix+bgr_memsiz+1)
        ret


;### CVS_Update -> updates canvas encoding/xbytes after first display
;### Input      IX=canvas data record
;### Destroyed  AF,BC,DE,HL
CVS_Update
        ld a,(ix+bgr_bnk)
        ld l,(ix+bgr_adrbmp+0)
        ld h,(ix+bgr_adrbmp+1)
        dec hl
        rst #20:dw jmp_bnkrbt
        ld (ix+bgr_enc),b           ;updates encoding
        ld a,b
        cp #11
        ret nz
        ld de,-10
        add hl,de
        ld a,(ix+bgr_bnk)
        rst #20:dw jmp_bnkrbt
        srl b
        ld l,(ix+bgr_adrtil+0)
        ld h,(ix+bgr_adrtil+1)
        ld de,cvstil4-cvstil0+1
        add hl,de
        rst #20:dw jmp_bnkwbt
        ret


;### CVS_Canvas_Fill -> fills canvas with colour
;### Input      IX=canvas data record, C=colour (0-15)
CVS_Canvas_Fill
        ld a,(ix+bgr_enc)
        or a
        jr z,cvsfil3            ;4col cpc
        cp #11
        jr z,cvsfil3            ;4col cpc downrendered
        bit 2,a
        jr z,cvsfil2            ;4col msx

        ld a,c                  ;* 16col msx
cvsfil1 add a:add a:add a:add a
        add c
        jr cvsfil5
cvsfil2 ld a,c                  ;* 4col msx
        and 3
        ld c,a
        add a:add a
        add c
        ld c,a
        jr cvsfil1
cvsfil3 xor a                   ;* 4col cpc
        rr c
        jr nc,cvsfil4
        ld a,#f0
cvsfil4 rr c
        jr nc,cvsfil5
        add #0f

cvsfil5 ld b,a
        ld l,(ix+bgr_adrtil+0)
        ld h,(ix+bgr_adrtil+1)
        inc hl:inc hl
        ld (cvstil1+2),hl
        ld l,(ix+bgr_adrbmp+0)
        ld h,(ix+bgr_adrbmp+1)
        ld a,(ix+bgr_bnk)
        rst #20:dw jmp_bnkwbt
        ld bc,-4
        add hl,bc
        rst #20:dw jmp_bnkrwd
        inc hl
        ld e,c
        ld d,b
        dec de
        jp cvstil6


;### CVS_Tile_Convert -> converts a tile to another encoding or the current canvas bitmap encoding
;### Input      A,HL=tile header bank and address, E=new encoding (-1=like canvas -> IX=canvas data record)
cvscnvd ds 254
cvscnvb db 0    ;tilebank
cvscnvt db 0    ;transfer tile->app bank

cvscnvc ;4col cpc->msx
db #00,#02,#08,#0A,#20,#22,#28,#2A,#80,#82,#88,#8A,#A0,#A2,#A8,#AA,#01,#03,#09,#0B,#21,#23,#29,#2B,#81,#83,#89,#8B,#A1,#A3,#A9,#AB
db #04,#06,#0C,#0E,#24,#26,#2C,#2E,#84,#86,#8C,#8E,#A4,#A6,#AC,#AE,#05,#07,#0D,#0F,#25,#27,#2D,#2F,#85,#87,#8D,#8F,#A5,#A7,#AD,#AF
db #10,#12,#18,#1A,#30,#32,#38,#3A,#90,#92,#98,#9A,#B0,#B2,#B8,#BA,#11,#13,#19,#1B,#31,#33,#39,#3B,#91,#93,#99,#9B,#B1,#B3,#B9,#BB
db #14,#16,#1C,#1E,#34,#36,#3C,#3E,#94,#96,#9C,#9E,#B4,#B6,#BC,#BE,#15,#17,#1D,#1F,#35,#37,#3D,#3F,#95,#97,#9D,#9F,#B5,#B7,#BD,#BF
db #40,#42,#48,#4A,#60,#62,#68,#6A,#C0,#C2,#C8,#CA,#E0,#E2,#E8,#EA,#41,#43,#49,#4B,#61,#63,#69,#6B,#C1,#C3,#C9,#CB,#E1,#E3,#E9,#EB
db #44,#46,#4C,#4E,#64,#66,#6C,#6E,#C4,#C6,#CC,#CE,#E4,#E6,#EC,#EE,#45,#47,#4D,#4F,#65,#67,#6D,#6F,#C5,#C7,#CD,#CF,#E5,#E7,#ED,#EF
db #50,#52,#58,#5A,#70,#72,#78,#7A,#D0,#D2,#D8,#DA,#F0,#F2,#F8,#FA,#51,#53,#59,#5B,#71,#73,#79,#7B,#D1,#D3,#D9,#DB,#F1,#F3,#F9,#FB
db #54,#56,#5C,#5E,#74,#76,#7C,#7E,#D4,#D6,#DC,#DE,#F4,#F6,#FC,#FE,#55,#57,#5D,#5F,#75,#77,#7D,#7F,#D5,#D7,#DD,#DF,#F5,#F7,#FD,#FF
cvscnvm ;16col msx->4col cpc
db %000000,%010000,%000001,%010001,%100000,%110000,%100001,%110001,%000010,%010010,%000011,%010011,%100010,%110010,%100011,%110011

CVS_Tile_Convert
        ld (cvscnvb),a
        ld (cvscnv5+1),hl
        push de
        call cvsthd
        pop de
        ld (cvscnvt),a
        ld bc,(cvstilh+7)   ;bc=bitmap len
        ld hl,(cvstilh+5)
        inc hl              ;hl=bitmap adr
        ld a,e
        cp -1
        jr nz,cvscnv2
        ld a,(ix+bgr_enc)
cvscnv2 call cvscnv0
        ld e,a
        ld a,(cvstilh+9)
        call cvscnv0
        cp e
        ret z               ;canvas=tile -> done
        cp 5
        jr z,cvscnv6

cvscnv3 push bc                 ;** tile is 4col CPC, canvas is 4col msx
        push hl
        call cvscnv1        ;load tile data part into buffer -> bc=loaded len
        ld b,c
        ld hl,cvscnvd
cvscnv4 push hl
        ld e,(hl)
        ld d,0
        ld hl,cvscnvc
        add hl,de
        ld a,(hl)
        pop hl
        ld (hl),a
        inc hl
        djnz cvscnv4
        pop hl              ;hl=adr, bc=loaded len
        call cvscnvs        ;save tile data part -> hl=next adr, bc=unmodified
        ex de,hl
        pop hl              ;hl=old rem length
        or a
        sbc hl,bc
        ld c,l
        ld b,h              ;bc=new rem len
        ex de,hl
        jr nz,cvscnv3
        ld a,1

cvscnv5 ld de,0             ;write back tile header
        ld hl,(cvstilh+5)
        ld b,a
        ld a,(cvscnvb)
        rst #20:dw jmp_bnkwbt
        ld hl,cvstilh
        ld bc,9
        ld a,(cvscnvt)
        rlca:rlca:rlca:rlca
        rst #20:dw jmp_bnkcop
        ret

cvscnv6 ld e,l                  ;** tile is 16col msx, canvas is 4col cpc
        ld d,h              ;de=adr converted data
        ld iy,cvscnvm       ;iy=converter table
cvscnv7 push bc
        push hl
        push de
        call cvscnvl        ;load tile data part into buffer -> bc=loaded len
        ld hl,cvscnvd
        ld de,cvscnvd
        ld b,c
        srl b
cvscnv8 push bc
        call cvscnv9
        add a:add a
        ld b,a
        call cvscnv9
        or b
        ld (de),a
        inc de
        pop bc
        djnz cvscnv8
        pop hl
        push bc
        srl c
        call cvscnvs        ;hl=new dst adr
        pop bc              ;bc=loaded len
        pop de              ;de=old src adr
        ex (sp),hl          ;hl=rem len, (sp)=dst adr
        or a
        sbc hl,bc
        push hl
        ex de,hl
        add hl,bc           ;hl=new src adr
        pop bc
        pop de
        ld a,c
        or b
        jr nz,cvscnv7
        ld hl,(cvstilh+7)
        srl h:rr l
        ld (cvstilh+7),hl
        ld a,(cvstilh+0)
        srl a
        ld (cvstilh+0),a
        xor a
        jr cvscnv5

cvscnv9 ld a,(hl)
        and #30
        rrca:rrca
        ld c,a
        ld a,(hl)
        inc hl
        and #03
        or c
        ld (cvscnva+2),a
cvscnva ld a,(iy+0)
        ret
;hl=adr, bc=remaining len -> load bitmap part -> bc=loaded len
cvscnvl inc b:dec b
        jr z,cvscnv1
        ld bc,254
cvscnv1 push bc
        ld de,cvscnvd
        ld a,(cvscnvt)
        rst #20:dw jmp_bnkcop   ;get tile bitmap data part
        pop bc
        ret
;hl=adr, bc=len -> save bitmap part -> hl=next adr
cvscnvs push hl
        push bc
        ex de,hl
        ld hl,cvscnvd
        ld a,(cvscnvt)
        rlca:rlca:rlca:rlca
        rst #20:dw jmp_bnkcop   ;save tile bitmap data part
        pop bc
        pop hl
        add hl,bc
        ret
;#11 and #05 is the same regarding the complete bitmap data
cvscnv0 cp #11
        ret nz
        xor a
        ret


;==============================================================================
;### SPRITE ROUTINES ##########################################################
;==============================================================================

;### CVS_Sprite_Animate -> updates sprite and background restore controls and headers
;### Input      ix=canvas data record
;### Destroyed  AF,BC,DE,HL,IX,IY
CVS_Sprite_Animate
        push ix

        bit 2,(ix+bgr_enc)
        ld a,3                      ;4col -> 4 pixels/byte (-1)
        jr z,cvsspr0
        ld a,1                      ;16col -> 2 pixels/byte (-1)
cvsspr0 ld (cvsspr9+1),a

        ld a,(ix+bgr_xpos)          ;patch code with background data
        ld (cvssprc+1),a
        ld (cvssprf+1),a
        ld a,(ix+bgr_ypos)
        ld (cvssprd+1),a
        ld (cvssprg+1),a
        ld a,(ix+bgr_xbytes)
        ld (cvsspre+1),a
        ld l,(ix+bgr_adrbmp+0)
        ld h,(ix+bgr_adrbmp+1)
        ld (cvssprh+1),hl

        ld a,(ix+spr_count)
        ld bc,spr_data
        add ix,bc
cvsspr1 push af
        ld a,(ix+spr_flag)
        or a
        jp z,cvssprb                ;not active -> skip

        ld c,(ix+spr_contrl+0)
        ld iyl,c
        ld c,(ix+spr_contrl+1)
        ld iyh,c                    ;iy=controls (+00=restore old background, +16=plot sprite at new position)

        bit 2,a                     ;size has shrunk?
        jr nz,cvssprj               ;yes -> restore all with old sizes
        ld (iy+00+02),64            ;first de-activate background restore

        ld a,(ix+spr_old_x)     ;*** XDIF?
        sub (ix+spr_pos_x)
        jr z,cvsspr4                ;no x-dif

        jr c,cvsspr2
        ld d,a                      ;d=dif = rest-xlen
        ld a,(ix+spr_len_x)
        cp d
        jr c,cvsspr7                ;len<dif -> restore all
        add (ix+spr_pos_x)
        ld e,a                      ;e=len+xnew = rest-xpos
        jr cvsspr3
cvsspr2 neg                         ;new>old
        cp (ix+spr_len_x)
        jr nc,cvsspr7               ;dif>=len -> restore all
        ld d,a                      ;b=dif = rest-xlen
        ld e,(ix+spr_old_x)
cvsspr3 ld a,(ix+spr_old_y)     ;*** RESTORE XDIF
        cp (ix+spr_pos_y)
        jr nz,cvsspr7               ;both x and ydif -> restore all
        ld c,a
        jr cvsspr8

cvsspr4 ld a,(ix+spr_old_y)     ;*** YDIF?
        sub (ix+spr_pos_y)
        jp z,cvssprb                ;both no x and y dif -> skip restore

        jr c,cvsspr5
        ld b,a                      ;b=dif = rest-ylen
        ld a,(ix+spr_len_y)
        cp b
        jr c,cvsspr7                ;len<dif -> restore all
        add (ix+spr_pos_y)
        ld c,a                      ;c=len+ynew = rest-ypos
        jr cvsspr6
cvsspr5 neg
        cp (ix+spr_len_y)
        jr nc,cvsspr7               ;dif>=len -> restore all
        ld b,a                      ;b=dif = rest-ylen
        ld c,(ix+spr_old_y)

cvsspr6 ld e,(ix+spr_old_x)     ;*** RESTORE YDIF
        ld d,(ix+spr_len_x)
        jr cvsspr9

cvssprj res 2,(ix+spr_flag)     ;*** RESTORE ALL WITH OLD SIZES
        ld e,(ix+spr_old_x)
        ld d,(ix+spr_len_x_o)
        ld c,(ix+spr_old_y)
        ld b,(ix+spr_len_y_o)
        jr cvsspr9

cvsspr7 ld e,(ix+spr_old_x)     ;*** RESTORE ALL
        ld d,(ix+spr_len_x)
        ld c,(ix+spr_old_y)
cvsspr8 ld b,(ix+spr_len_y)

cvsspr9 ld a,0                  ;*** UPDATE controls and headers [e=rest-posx, d=rest-lenx, c=rest-posy, b=rest-leny]
        and e
        jr z,cvsspra
        ld l,a                      ;align to byte for xpos
        neg
        add e
        ld e,a
        ld a,d                      ;increase xlen, if xpos has been decreased
        add l
        ld d,a

cvsspra ld (iy+00+02),10            ;activate background restore
        ld (iy+00+10),d             ;store control xsize
        ld (iy+00+12),b             ;store control ysize

cvssprc ld a,0                      ;bgr_xpos
        add e
        ld (iy+00+06),a
        ld a,0
        adc a
        ld (iy+00+07),a             ;store control xpos

cvssprd ld a,0                      ;bgr_ypos
        add c
        ld (iy+00+08),a
        ld a,0
        adc a
        ld (iy+00+09),a             ;store control ypos

        ld h,c                      ;h=ypos
        ld c,b                      ;c=ysize
        push de                     ;(sp)=l-xpos, h-xsize
cvsspre ld e,0
        call clcmu8                 ;hl=ypos*xbytes
cvssprh ld de,0                     ;bgr_adrbmp
        add hl,de
        ex de,hl                    ;de=adr of bmp+ypos
        pop hl
        ld a,h                      ;a=xsize
        ld h,0                      ;hl=xpos
cvssprk ds 2        ;(srl l, if original 4colour background)
        srl l                       ;hl=xbyte
        add hl,de
        ex de,hl                    ;de=adr of bmp+ypos+xbyte
        ld l,(ix+spr_backgr+0)      ;hl=background bitmap header
        ld h,(ix+spr_backgr+1)
        inc hl
        ld (hl),a                   ;store bitmap xsize
        inc hl
        ld (hl),c                   ;store bitmap ysize
        inc hl
        ld (hl),e                   ;store bitmap adr
        inc hl
        ld (hl),d

        ld a,(ix+spr_pos_x)
        ld (ix+spr_old_x),a
cvssprf add 0                       ;bgr_xpos
        ld (iy+16+06),a
        ld a,0
        adc a
        ld (iy+16+07),a             ;store sprite xpos
        ld a,(ix+spr_pos_y)
        ld (ix+spr_old_y),a
cvssprg add 0                       ;bgr_ypos
        ld (iy+16+08),a
        ld a,0
        adc a
        ld (iy+16+09),a             ;store sprite ypos

cvssprb 
;****** \ not always necessary
;        ld a,(ix+spr_len_x)         ;update old sizes
;        ld (ix+spr_len_x_o),a
;        ld a,(ix+spr_len_y)
;        ld (ix+spr_len_y_o),a
;****** /

        ld de,spr_reclen
        add ix,de
        pop af
        dec a
        jp nz,cvsspr1

        pop ix
        ld c,(ix+spr_headers)
cvsspri ld b,0
        ld a,(ix+bgr_bnkcop)
        ld e,(ix+bgr_adr+0)
        ld d,(ix+bgr_adr+1)
        ld hl,bgrhed
        rst #20:dw jmp_bnkcop
        ret


;### CVS_Sprite_Collisions -> collision detection
;### Input      IX=canvas data record, IY=player sprite data record within canvas data record
;### Output     CF=0 collision, A=sprite number (0-...)
;###            CF=1 no collision
;### Destroyed  AF,BC,DE,HL,IX
CVS_Sprite_Collisions
        ld l,(iy+spr_pos_x)     ;l=x1
        ld a,(iy+spr_len_x)
        add l
        dec a
        ld h,a                  ;h=x2
        ld e,(iy+spr_pos_y)     ;e=y1
        ld a,(iy+spr_len_y)
        add e
        dec a
        ld d,a                  ;d=y2
        ld a,(ix+spr_count)
        ld bc,spr_data
        add ix,bc
        ld (cvscol2+1),a
cvscol1 ld b,a
        bit 1,(ix+spr_flag)
        jr z,cvscol3            ;no enemy -> ignore sprite
        ld a,h
        cp (ix+spr_pos_x)
        jr c,cvscol3            ;px2<ex1 -> no collision
        ld a,(ix+spr_pos_x)
        add (ix+spr_len_x)
        dec a
        cp l
        jr c,cvscol3            ;ex2<px1 -> no collision
        ld a,d
        cp (ix+spr_pos_y)
        jr c,cvscol3            ;py2<ey1 -> no collision
        ld a,(ix+spr_pos_y)
        add (ix+spr_len_y)
        dec a
        cp e
        jr c,cvscol3            ;ey2<py1 -> no collision
cvscol2 ld a,0
        sub b                   ;collision detected -> a=sprite number
        ret
cvscol3 ld a,b
        ld bc,spr_reclen        ;try next
        add ix,bc
        dec a
        jr nz,cvscol1
        scf
        ret


;### CVS_Sprite_Collision -> collision detection between two specific sprites
;### Input      IX=sprite1 data record within canvas data record, IY=sprite2
;### Output     CF=1 no collision
;###            CF=0 collision
;### Destroyed  AF,BC,DE
CVS_Sprite_Collision
        ld e,(iy+spr_pos_y)     ;e=y1
        ld a,(iy+spr_len_y)
        add e
        dec a                   ;a=y2
        cp (ix+spr_pos_y)
        ret c                   ;py2<ey1 -> no collision
        ld d,(iy+spr_pos_x)     ;d=x1
        ld a,(iy+spr_len_x)
        add d
        dec a                   ;a=x2
        cp (ix+spr_pos_x)
        ret c                   ;px2<ex1 -> no collision
        ld a,(ix+spr_pos_x)
        add (ix+spr_len_x)
        dec a
        cp d
        ret c                   ;ex2<px1 -> no collision
        ld a,(ix+spr_pos_y)
        add (ix+spr_len_y)
        dec a
        cp e
        ret


;==============================================================================
;### TILE PLOTTING ############################################################
;==============================================================================

;### CVS_Tile_PlotShow -> plots tile into canvas and shows it on the screen
;### Input      A,HL=tile header bank and address, IX=canvas data record, C=xpos inside canvas in pixels (must be divisible by 4), B=ypos inside canvas in pixels
;###            IYL=tile xsize in pixels, IYH=tile ysize in pixels
;###            E=canvas control ID, D=window ID
;### Destroyed  AF,BC,DE,HL,IX,IY
CVS_Tile_PlotShow
        push de
        push ix
        push iy
        push bc
        call CVS_Tile_Plot
        pop bc          ;c=xofs, b=yofs
        pop ix          ;ixl=xsiz, ixh=ysiz
        pop iy
        ld e,b
        ld d,0
        ld l,(iy+bgr_ypos)
        ld h,d
        add hl,de
        ld e,c
        ld c,l:ld b,h   ;bc=ybeg
        ld l,(iy+bgr_xpos)
        add hl,de       ;hl=xbeg
        ld a,ixh
        ld ixh,d        ;ix=xlen
        ld iyl,a
        ld iyh,d        ;iy=ylen
        pop de
        ld a,d
        jp SyDesktop_WINPIN


;### CVS_Tile_Plot -> plots tile into canvas
;### Input      A,HL=tile header bank and address (same decoding like canvas), IX=canvas data record, C=xpos inside canvas in pixels (must be divisible by 4), B=ypos inside canvas in pixels
;### Destroyed  AF,BC,DE,HL,IX,IY
cvstilh ds 10

CVS_Tile_Plot
        push bc
        push af
        call cvsthd             ;get tile header
        ld l,(ix+bgr_adrtil+0)
        ld h,(ix+bgr_adrtil+1)
        ld (cvstil1+2),hl
        ld de,cvstil_end-cvstil0
        add hl,de
        ex de,hl
        ld hl,(cvstilh+3)
        ld a,(ix+bgr_bnk)
        add a:add a:add a:add a
        pop bc
        add b
        ld bc,(cvstilh+7)
        rst #20:dw jmp_bnkcop   ;copy tile bitmap to tile buffer

        pop bc
        ld e,b                  ;e=ypos
        ld a,(ix+bgr_enc)
        push af
        cp #11
        ld h,(ix+bgr_xbytes)
        jr nz,cvstil7
        srl h
cvstil7 call clcmu8             ;hl=ypos ofs
        pop af
        srl c
        ld b,0                  ;bc=xpos/2
        cp 5
        jr z,cvstil8
        srl c
cvstil8 add hl,bc
        ld c,(ix+bgr_adrbmp+0)
        ld b,(ix+bgr_adrbmp+1)
        add hl,bc               ;hl=destination adr in background bitmap

        ld a,(cvstilh+9)
        bit 4,a
        ld a,(cvstilh+0)
        jr z,cvstil9
        srl a
cvstil9 ld e,a                  ;e=xsize
        ld a,(cvstilh+2)
        ld d,a                  ;d=ysize
cvstil6 ld b,(ix+bgr_bnk)       ;b=bank
cvstil1 ld ix,0                 ;ix=routine address
        ld iy,#fff4
        push bc
        push de
        push hl
        call jmp_bnklok
        pop hl
        pop de
        pop af
        inc c
        ret nz
        ld b,a
        rst #30
        jr cvstil1

;hl=dest adr, e=xsize, d=ysize
cvstil0 jr cvstil5
;hl=bmpadr, de=bmplen-1
        ld c,e
        ld b,d
        ld e,l
        ld d,h
        inc de
        ldir
        jp #ff0c    ;c is 0 here
cvstil5 push de
        pop ix
cvstil2 ld de,0                 ;de=src adr
        ex de,hl
cvstil3 ld c,ixl
        ld b,0
        push de
        ldir
        pop de
        ex de,hl
cvstil4 ld c,0                  ;bc=bgr xlen
        add hl,bc
        ex de,hl
        dec ixh
        jr nz,cvstil3
        ld c,b
        jp #ff0c
cvstil_end


;==============================================================================
;### SUB ROUTINES #############################################################
;==============================================================================

;### CVSTHD -> get tile header
;### Input      A,HL=tile header bank and address
;### Output     (cvstilh)=tile header, A=[b7-4]appbnk,[b3-0]tilbnk
;### Destroyed  F,BC,DE,HL
cvsthd  ld b,a
        ld a,(App_BnkNum)
        add a:add a:add a:add a
        add b
        ld de,cvstilh
        push af
        push bc
        ld bc,9
        rst #20:dw jmp_bnkcop   ;get tile header
        pop af
        ld hl,(cvstilh+5)
        rst #20:dw jmp_bnkrbt   ;get encoding type
        ld a,b
        ld (cvstilh+9),a
        pop af
        ret

;### CLCMU8 -> 8x8bit unsigned multiplication
;### Input      H,E=values
;### Output     HL=H*E, B=0
;### Destroyed  AF,B,D
clcmu8  ld d,0
        sla h
        sbc a
        and e
        ld l,a
        ld b,7
clcmu81 add hl,hl
        jr nc,clcmu82
        add hl,de
clcmu82 djnz clcmu81
        ret
