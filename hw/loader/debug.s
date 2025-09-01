.segment "HEADER"
    .byte "NES", $1A ; signature
    .byte 1          ; # of 16KB PRG-ROM banks
    .byte 2          ; # of 8KB CHR-ROM banks

.segment "CHR"
    .incbin "chr.bin"
