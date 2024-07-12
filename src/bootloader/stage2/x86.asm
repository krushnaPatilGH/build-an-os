bits 16

section _TEXT class=CODE

;
; U4D
;
; Operation:      Unsigned 4 byte divide
; Inputs:         DX;AX   Dividend
;                 CX;BX   Divisor
; Outputs:        DX;AX   Quotient
;                 CX;BX   Remainder
; Volatile:       none
;
global __U4D
__U4D:
    shl edx, 16         ; dx to upper half of edx
    mov dx, ax          ; edx - dividend
    mov eax, edx        ; eax - dividend
    xor edx, edx

    shl ecx, 16         ; cx to upper half of ecx
    mov cx, bx          ; ecx - divisor

    div ecx             ; eax - quot, edx - remainder
    mov ebx, edx
    mov ecx, edx
    shr ecx, 16

    mov edx, eax
    shr edx, 16

    ret


;
; U4M
; Operation:      integer four byte multiply
; Inputs:         DX;AX   integer M1
;                 CX;BX   integer M2
; Outputs:        DX;AX   product
; Volatile:       CX, BX destroyed
;
global __U4M
__U4M:
    shl edx, 16         ; dx to upper half of edx
    mov dx, ax          ; m1 in edx
    mov eax, edx        ; m1 in eax

    shl ecx, 16         ; cx to upper half of ecx
    mov cx, bx          ; m2 in ecx

    mul ecx             ; result in edx:eax (we only need eax)
    mov edx, eax        ; move upper half to dx
    shr edx, 16

    ret

; void _cdecl x86_div64_32(uint64_t dividend, uint32_t divisor, uint64_t* quotientOut, uint32_t* reminder);
global _x86_div64_32
_x86_div64_32:
    push bp                 ; save old call frame
    mov bp, sp              ; initialize new call frame

    push bx

    ; divide upper 32 bits
    mov eax, [ bp + 8  ]    ; eax dividend => upper 32 bits  
    mov ecx, [ bp + 12 ]    ; ecx divisor 
    xor edx, edx
    div ecx                 ; eax => quotient, edx => reminder

    ; store upper 32 bits of quotient
    mov bx, [ bp +  16 ]
    mov [ bx + 4 ], eax 

    ; divide lower 32 bits
    mov eax, [ bp + 4 ]
    div ecx

    ; store results
    mov [ bx ], eax
    mov bx, [ bp + 18 ]
    mov [ bx ], edx

    pop bx

    ; restore old call frame
    mov sp, bp 
    pop bp
    ret


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

;
;void _cdecl x86_Disk_Reset(uint8_t drive);
;
global _x86_Disk_Reset
_x86_Disk_Reset:

    push bp                 ; save old call frame
    mov bp, sp              ; initialize new call frame

    mov ah, 0h
    mov dl, [ bp + 4 ]      ; dl => drive number
    stc

    int 13h
    mov ax, 1
    sbb ax, 0

    ; restore old call frame
    mov sp, bp 
    pop bp
    ret

;
;void _cdecl x86_Disk_Read(uint8_t drive,
;                            uint16_t cylinder,
;                            uint16_t sector,
;                            uint16_t head, 
;                            uint8_t count,
;                            uint8_t far* dataout);
;
global _x86_Disk_Read
_x86_Disk_Read:

    push bp                 ; save old call frame
    mov bp, sp              ; initialize new call frame

    ; save modified regs
    push bx
    push es

    ; set up args
    mov dl, [ bp + 4 ]      ; dl => drive number

    mov ch, [ bp + 6 ]      ; ch => cylinder ( lower 8 bits )
    mov cl, [ bp + 7 ]      ; cl => cylinder to bits 6 - 7
    shl cl, 6               ; cl => xx000000

    mov al, [ bp + 8 ]      ; al => sector number but we need cl => 0 - 5 as sector number  
    and al, 3Fh             ; and 6 - 7 as cylinder number
    or  cl, al              ; xx000000 && 00yyyyyy => xxyyyyyy => 2 bits of cylinder and 6 bits of sectors


    mov dh, [ bp + 10 ]     ; dh => head

    mov al, [ bp + 12 ]     ; al => count ( 12 - 13 )

    mov bx, [ bp + 16 ]     ; 16 - 17 segment  es:bx => far data pointer out
    mov es, bx
    mov bx, [ bp + 14 ]     ; 14 - 15 offset
      
    ; call int 13h
    mov ah, 02h
    stc
    int 13h

    ; set return value   
    mov ax, 1
    sbb ax, 0

    ; pop es
    ; pop bx

    ; restore old call frame
    mov sp, bp 
    pop bp
    ret

;
;bool _cdecl x86_Disk_GetDriveParams(uint8_t drive,
;                                    uint8_t* driveTypeOut,
;                                    uint16_t* cylindersOut,
;                                    uint16_t* sectorsOut,
;                                    uint16_t* headsOut);  
;

global _x86_Disk_GetDriveParams
_x86_Disk_GetDriveParams:

    push bp                 ; save old call frame
    mov bp, sp              ; initialize new call frame

    ; save regs
    push es
    push bx
    push si
    push di

    ; call int 13h
    mov dl, [ bp + 4 ]
    mov ah, 08h
    mov di, 0h
    mov es, di
    stc
    int 13h

    ; return
    mov ax, 1
    sbb ax, 0

    ; out params
    mov si , [ bp + 6 ]     ; drive type 
    mov [ si ], bl

    mov bl, ch              ; lower cylinder bits in bl
    mov bh, cl              ; higher cylinder ( 2 ) bits in bh
    shr bh, 6
    mov si, [ bp + 8 ]      ; cylinders
    mov [ si ], bx

    xor ch, ch              ; ch = 0, put sectors in cx (clear ch)
    and cl, 3Fh             ; cl = sector 0 - 5 bits 00xxxxxx
    mov si, [ bp + 10 ]     ; sector pointer
    mov [ si ], cx

    mov cl, dh              ; heads = cl, cuz dl = drive number
    mov si, [ bp + 12 ]
    mov [ si ], cx

    ; restore regs
    pop di
    pop si
    pop bx
    pop es

    ; restore old call frame
    mov sp, bp 
    pop bp
    ret