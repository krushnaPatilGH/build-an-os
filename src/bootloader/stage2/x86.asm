bits 16

section _TEXT class=CODE

global _x86_Video_WriteCharTeletype
_x86_Video_WriteCharTeletype:
    push bp                 ; save old call frame
    mov bp, sp              ; initialize new call frame

    push bx                 ; sava bx

    ; [ bp + 0 ] => old call frame 
    ; [ bp + 2 ] => return address
    ; [ bp + 4 ] => first args (ch)
    ; [ bp + 6 ] => second args (page)
    mov ah, 0Eh 
    mov al, [ bp + 4 ]
    mov bh, [ bp + 6 ]

    int 10h

    pop bx

    ; restore old call frame
    mov sp, bp 
    pop bp
    ret