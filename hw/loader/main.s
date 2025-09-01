PPU_CTRL   = $2000
PPU_MASK   = $2001
PPU_STATUS = $2002
PPU_SCROLL = $2005
PPU_ADDR   = $2006
PPU_DATA   = $2007

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

    ; enbale background rendering
    lda #%00001010
    sta PPU_MASK

    forever:
        jmp forever

nmi:
    rti

irq:
    rti

initial_palette:
	.byte $1F,$21,$33,$30

.segment "VECTORS"
    .addr nmi, reset, irq
