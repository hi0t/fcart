PPU_CTRL    = $2000
PPU_MASK    = $2001
PPU_STATUS  = $2002
PPU_OAMADDR = $2003
PPU_OAMDATA = $2004
PPU_SCROLL  = $2005
PPU_ADDR    = $2006
PPU_DATA    = $2007
JOYPAD1     = $4016
CTRL_REG    = $5000
STATUS_REG  = $5001
SST_ADDR    = $5002
SST_DATA    = $5003
SST_REC     = $5004

.segment "ZEROPAGE"
ptr:       .res 1
pages_cnt: .res 1

.segment "CODE"
ingame_entry:
    ; State Dump Map (Total size: $1180 = 4480 bytes)
    ; -----------------------------------------------
    ; Offset | Size  | Description
    ; -------|-------|--------------------
    ; $0000  | $0004 | CPU Registers (A, X, Y, S)
    ; $0004  | $0100 | Zero Page ($00-$FF)
    ; $0104  | $0700 | RAM ($0100-$07FF)
    ; $0804  | $0800 | Nametables ($2000-$27FF)
    ; $1004  | $0020 | Palettes ($3F00-$3F1F)
    ; $1024  | $0100 | OAM Data (256 bytes)
    ; $1124  | $0018 | APU Registers ($4000-$4017)
    ; $113C  | $0004 | PPU Registers (CTRL, MASK, SCROLLx2)

    ; registers are saved in order A, X, Y, S
    ; sst_addr is reset to 0 by hardware when reading NMI vector
    sta SST_DATA ; A at 0
    stx SST_DATA ; X at 1
    sty SST_DATA ; Y at 2

    ; dump S
    tsx
    stx SST_DATA ; S at 3

    ; Disable all IRQ
    sei
    lda #0
    sta PPU_CTRL
    sta PPU_MASK
    sta $4010
    sta $4015
    sta $4017
    bit PPU_STATUS ; reset high-low latch

    ; dump Zero Page ($00-$FF)
    ldx #0
    dump_zp:
        lda $00,x
        sta SST_DATA
        inx
        bne dump_zp

    ; now we can overwrite ZP to use as pointer
    ; dump RAM $0100-$07FF
    lda #0
    sta ptr
    lda #1
    sta pages_cnt ; pointer = $0100

    dump_ram_pages:
        ldy #0
        dump_page_bytes:
            lda (ptr),y
            sta SST_DATA
            iny
            bne dump_page_bytes
        inc pages_cnt
        lda pages_cnt
        cmp #8
        bne dump_ram_pages

    vblank_wait_dump:
        bit PPU_STATUS
        bpl vblank_wait_dump

    ; dump Nametables ($2000-$2800)
    lda #$20
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR
    lda PPU_DATA ; dummy read

    lda #8
    sta pages_cnt ; counter
    dump_nt_pages:
        ldy #0
        dump_nt_bytes:
            lda PPU_DATA
            sta SST_DATA
            iny
            bne dump_nt_bytes
        dec pages_cnt
        bne dump_nt_pages

    ; dump Palettes ($3F00-$3F20)
    lda #$3F
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR
    ldx #0
    dump_pal:
        lda PPU_DATA
        sta SST_DATA
        inx
        cpx #32
        bne dump_pal

    ; dump OAM (256 bytes)
    ; SST_REC starts at 0x000 (OAM)
    ldx #0
    dump_oam:
        lda SST_REC
        sta SST_DATA
        inx
        bne dump_oam

    ; dump APU registers ($4000-$4017) (24 bytes)
    ; SST_REC continues at 0x100
    ldx #24
    dump_apu_loop:
        lda SST_REC
        sta SST_DATA
        dex
        bne dump_apu_loop

    ; dump PPU registers (4 bytes)
    ; SST_REC continues at 0x118
    ldx #4
    dump_ppu_loop:
        lda SST_REC
        sta SST_DATA
        dex
        bne dump_ppu_loop

reset:
    ; start initialization
    sei
    cld
    ldx #$40
    stx $4017
    ldx #$FF
    txs
    inx
    stx PPU_CTRL
    stx PPU_MASK
    stx $4010

    bit PPU_STATUS ; read PPU status to reset high-low latch

    vblank_wait1:
        bit PPU_STATUS
        bpl vblank_wait1

    clr_mem:
        sta $00,x
        sta $100,x
        sta $200,x
        sta $300,x
        sta $400,x
        sta $500,x
        sta $600,x
        sta $700,x
        inx
        bne clr_mem

    vblank_wait2:
        bit PPU_STATUS
        bpl vblank_wait2
    ; end initialization

    lda #%00000011 ; running|vblank
    sta STATUS_REG

	; load palette data into PPU
    lda #$3F
	sta PPU_ADDR
	lda #$00
	sta PPU_ADDR
    ldx #0
    copy_palete:
        lda initial_palette,x
        sta PPU_DATA
        inx
        cpx #4
        bcc copy_palete

    ; fill nametable with a pattern
    lda #$20
    sta PPU_ADDR
    lda #$00
    sta PPU_ADDR
    ldx #0
    ldy #3
    fill_nametable1:
        txa
        sta PPU_DATA
        inx
        bne fill_nametable1
        dey
        bne fill_nametable1

    fill_nametable2:
        lda #$00
        cpx #$C0
        bcs attribute_table
        txa
        attribute_table:
        sta PPU_DATA
        inx
        bne fill_nametable2

    lda #%10000000 ; Enable NMI on vblank
	sta PPU_CTRL

    lda #%00001010 ; enbale background rendering
    sta PPU_MASK

    ; center viewer
    lda #0
    sta PPU_SCROLL
    sta PPU_SCROLL

    forever:
        lda CTRL_REG
        beq forever         ; If 0, nothing to do

        lsr                 ; bit 0 -> C
        bcs start_app        ; If set, start

        lsr                 ; bit 1 -> C
        bcs restore_state   ; If set, restore

        jmp forever

    start_app:
        lda #0
        sta STATUS_REG ; launcher finished

        vblank_wait_start:
            bit PPU_STATUS
            bpl vblank_wait_start

        ; Disable nmi and background rendering
        lda #0
        sta PPU_CTRL
        sta PPU_MASK

        ldx #$fd
        txs ; reset stack pointer
        lda #$34
        pha
        lda #0
        ldx #0
        ldy #0
        plp ; default status register
        jmp ($FFFC)

    restore_state:
        lda #0
        sta STATUS_REG ; launcher finished

        vblank_wait_restore1:
            bit PPU_STATUS
            bpl vblank_wait_restore1

        ; Disable nmi and background rendering
        lda #0
        sta PPU_CTRL
        sta PPU_MASK

        ; Restore RAM ($0100-$07FF)
        ; Regs(4) + ZP(256) = 260 ($104)
        lda #$04
        sta SST_ADDR
        lda #$01
        sta SST_ADDR ; 0x0104

        ; Setup pointers for RAM copy
        lda #0
        sta ptr
        lda #1
        sta pages_cnt ; pointer = $0100

        res_loop_pages:
            ldy #0
            res_loop_bytes:
                lda SST_DATA
                sta (ptr),y
                iny
                bne res_loop_bytes
            inc pages_cnt
            lda pages_cnt
            cmp #8
            bne res_loop_pages

        ; Restore Nametables ($2000-$2800)
        bit PPU_STATUS ; Reset latch
        lda #$20
        sta PPU_ADDR
        lda #$00
        sta PPU_ADDR

        lda #8
        sta pages_cnt
        res_nt_pages:
            ldy #0
            res_nt_bytes:
                lda SST_DATA
                sta PPU_DATA
                iny
                bne res_nt_bytes
            dec pages_cnt
            bne res_nt_pages

        ; Restore Palettes ($3F00-$3F20)
        lda #$3F
        sta PPU_ADDR
        lda #$00
        sta PPU_ADDR

        ldx #0
        res_pal:
            lda SST_DATA
            sta PPU_DATA
            inx
            cpx #32
            bne res_pal

        ; Restore OAM
        lda #0
        sta PPU_OAMADDR
        ldx #0
        res_oam:
            lda SST_DATA
            sta PPU_OAMDATA
            inx
            bne res_oam

        ; Restore APU Registers (24 bytes)
        ; Skip $4016 (offset 22)
        ldx #0
        res_apu_loop:
            lda SST_DATA
            cpx #22 ; $4016
            beq res_apu_skip
            sta $4000,x
        res_apu_skip:
            inx
            cpx #24
            bne res_apu_loop

        ; Restore S
        ; Seek to offset 3
        lda #03
        sta SST_ADDR
        lda #00
        sta SST_ADDR
        ldx SST_DATA ; Value of S
        txs

        ; Restore Zero Page ($00-$FF)
        ldx #0
        res_zp_loop:
            lda SST_DATA
            sta $00,x
            inx
            bne res_zp_loop

        vblank_wait_restore2:
            bit PPU_STATUS
            bpl vblank_wait_restore2

        lda #$3C
        sta SST_ADDR
        lda #$11
        sta SST_ADDR

        lda SST_DATA
        sta PPU_CTRL ; PPU_CTRL (2000)
        lda SST_DATA
        sta PPU_SCROLL ; PPU_SCROLL (2005 X)
        lda SST_DATA
        sta PPU_SCROLL ; PPU_SCROLL (2005 Y)
        lda SST_DATA
        sta PPU_MASK ; PPU_MASK (2001)

        lda #00
        sta SST_ADDR
        sta SST_ADDR
        lda SST_DATA ; A
        ldx SST_DATA ; X
        ldy SST_DATA ; Y

        jmp resume_app

nmi:
    ; save registers
	pha
    txa
    pha

    lda #%00000011 ; running|vblank
    sta STATUS_REG

    lda #$01
    sta JOYPAD1
    lsr a
    sta JOYPAD1

    ldx #$08
    read_loop:
        lda JOYPAD1 ; strobe joypad read
        dex
        bne read_loop

    ; restore registers and return
    pla
    tax
    pla
    rti

irq:
    rti

initial_palette:
	.byte $0F,$30,$28,$21

.segment "RTI_TRAP"
resume_app:
    rti

.segment "VECTORS"
    .addr nmi, reset, irq
