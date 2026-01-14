PPU_CTRL    = $2000
PPU_MASK    = $2001
PPU_STATUS  = $2002
PPU_SCROLL  = $2005
PPU_ADDR    = $2006
PPU_DATA    = $2007
JOYPAD1     = $4016
CTRL_REG    = $5000
BUTTONS_REG = $5001
STATUS_REG  = $5002

.segment "ZEROPAGE"
    zp_buttons: .res 1
    zp_ctrl:    .res 1
    zp_halt:    .res 1

.segment "CODE"
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
        sta zp_ctrl
        beq forever         ; If 0, nothing to do

    check_halt:
        lda zp_ctrl
        and #%00000001      ; Check bit 0
        beq check_load      ; If 0, skip halt action
        lda #$01
        sta zp_halt         ; Execute halt action

    check_load:
        lda zp_ctrl
        and #%00000010      ; Check bit 1
        beq end_loop        ; If 0, skip load action
        jmp load_app        ; Execute load action

    end_loop:
        jmp forever

    load_app:
        vblank_wait3:
            bit PPU_STATUS
            bpl vblank_wait3

        ldx #$fd
        txs ; reset stack pointer
        lda #$34
        pha
        lda #$00
        ldx #$00
        ldy #$00
        plp ; default status register
        jmp ($FFFC)

nmi:
    ; save registers
	pha

    lda zp_halt
    cmp #$01
    bne nmi_continue

    lda #$00
    sta PPU_CTRL
    sta PPU_MASK

    lda #%00000000 ; finished
    sta STATUS_REG

    jmp nmi_end

    nmi_continue:
        lda #%00000011 ; running|vblank
        sta STATUS_REG

        lda #$01
        sta JOYPAD1
        sta zp_buttons
        lsr a
        sta JOYPAD1

        read_joypad:
            lda JOYPAD1
            lsr a ; bit 0 -> Carry
            rol zp_buttons  ; Carry -> bit 0; bit 7 -> Carry
            bcc read_joypad
        lda zp_buttons
        sta BUTTONS_REG
    nmi_end:
	    ; restore registers and return
        pla
        rti

irq:
    rti

initial_palette:
	.byte $0F,$30,$28,$21

.segment "VECTORS"
    .addr nmi, reset, irq
