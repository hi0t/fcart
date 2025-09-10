PPU_CTRL   = $2000
PPU_MASK   = $2001
PPU_STATUS = $2002
PPU_SCROLL = $2005
PPU_ADDR   = $2006
PPU_DATA   = $2007
JOYPAD1    = $4016
MAP_CTRL   = $5000
BUTTONS    = $5001

.segment "STARTUP"
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

    lda PPU_ADDR ; read PPU status to reset high-low latch

    lda #%00000001 ; vblank
    sta MAP_CTRL

	; load palette data into PPU
    lda #$3F
	sta PPU_ADDR
	lda #$00
	sta PPU_ADDR
    ldx #4
    copy_palete:
        lda initial_palette,x
        sta PPU_DATA
        dex
        bne copy_palete

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

    ; center viewer
    lda #0
    sta PPU_SCROLL
    sta PPU_SCROLL

    lda #%10000000 ; Enable NMI on vblank
	sta PPU_CTRL

    lda #%00001010 ; enbale background rendering
    sta PPU_MASK

    forever:
        jmp forever

nmi:
    lda #%00000001 ; vblank
    sta MAP_CTRL

    lda #$01
    sta JOYPAD1
    lda #$00
    sta JOYPAD1

    lda #$01
    read_joypad:
        pha
        lda JOYPAD1
        lsr a
        pla
        rol a
        bcc read_joypad
    sta BUTTONS

    rti

irq:
    rti

initial_palette:
	.byte $1F,$21,$33,$30

.segment "VECTORS"
    .addr nmi, reset, irq
