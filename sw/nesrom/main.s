PPU_CTRL   = $2000
PPU_MASK   = $2001
PPU_STATUS = $2002
PPU_SCROLL = $2005
PPU_ADDR   = $2006
PPU_DATA   = $2007

.segment "STARTUP"
reset:
    sei          ; disable IRQs
    cld          ; disable decimal mode
    ldx #$40
    stx $4017    ; disable APU frame IRQ
    ldx #$FF
    txs          ; Set up stack
    inx          ; now X = 0
    stx PPU_CTRL  ; disable NMI
    stx PPU_MASK  ; disable rendering
    stx $4010    ; disable DMC IRQs

    jsr vblankWait ; First wait for vblank to make sure PPU is ready

    clrMem:
        lda #$00
        sta $0000, x
        sta $0100, x
        sta $0400, x
        sta $0500, x
        sta $0600, x
        sta $0700, x
        lda #$FE
        sta $0300, x
        inx
        bne clrMem

    jsr vblankWait ; Second wait for vblank, PPU is ready after this

    lda PPU_STATUS       ; read PPU status to reset the high/low latch
    lda #$3F
    sta PPU_ADDR         ; write the high byte of $3F00 address
    lda #$00
    sta PPU_ADDR         ; write the low byte of $3F00 address
    ldx #$00            ; start out at 0
    loadPalettes:
        ;lda palette, x  ; load data from address (palette + the value in x)
        sta PPU_DATA
        inx
        cpx #$20
        bne loadPalettes

    lda PPU_STATUS       ; read PPU status to reset the high/low latch
    lda #$20
    sta PPU_ADDR
    lda #$CA
    sta PPU_ADDR
    ldx #$00
    loadBackground:
        ;lda nametable, x
        sta PPU_DATA
        inx
        cpx #$10
        bne loadBackground

    lda #$00        ; disable scrolling
    sta PPU_SCROLL
    sta PPU_SCROLL

    lda #$0A        ; enable background
    sta PPU_MASK

forever:
    jmp forever

vblankWait:
    bit PPU_STATUS
    bpl vblankWait
    rts

nmi:
    rti

irq:
    rti

.segment "VECTORS"
    .word nmi   ; when non-maskable interrupt happens, goes to label nmi
    .word reset ; when the processor first turns on or is reset, goes to reset
    .word irq   ; using external interrupt IRQ
