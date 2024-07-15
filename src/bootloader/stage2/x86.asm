;
; switch to real mode 
;
%macro x86_EnterRealMode 0
    [bits 32]
    jmp word 18h:.pmode16            ; 1 jmp to 16 bit protected mode segment

.pmode16:
    [bits 16]
    ; 2 disable protected mode bit in CR0
    mov eax, cr0
    and al, ~1
    mov cr0, eax

    ; 3 jmp to real mode
    jmp word 00h:.rmode

.rmode:
    ; 4 set up segments
    mov ax, 0
    mov ds, ax
    mov ss, ax

    ; 5 enable interrupts
    sti

%endmacro

;
; switch to protected mode
;

%macro x86_EnterProtectedMode 0
    cli

    ; 4 set protection mode enable flag in CR0
    mov eax, cr0
    or al, 1
    mov cr0, eax
    
    ; 5 jmp to protected mode segment
    jmp word 08h:.pmode            

.pmode:
    ; we are in protected mode
    [bits 32]
    
    ; 6 - setup segment registers
    mov ax, 0x10
    mov ds, ax
    mov ss, ax


%endmacro

; 
; port control 
;
global x86_outb
x86_outb:
    [bits 32]
    mov dx, [ esp + 4 ]
    mov al, [ esp + 8 ]
    out dx, al
    ret

global x86_inb
x86_inb:
    [bits 32]
    mov dx, [ esp + 4 ]
    xor eax, eax
    in al, dx
    ret

;
; convert linear address to segment:offset address
; Args:
;   1 - linear address
;   2 - ( out ) target segment ( eg es )
;   3 - target 32 - bit register to use ( e.g. eax )
;   4 - target lower 16-bit half of #3 ( e.g. ax )
; 

%macro LinearToSegOffset 4

    mov %3, %1              ; eax <- linear address
    shr %3, 4               ; segment 4 bytes
    mov %2, %4
    mov %3, %1              ; eax <- linear address 
    and %3, 0xf             ; offset in %3

%endmacro



;
;
; disk functions
;
;


;
;bool __attribute__((cdecl)) x86_Disk_GetDriveParams(uint8_t drive,
;                                    uint8_t* driveTypeOut,
;                                    uint16_t* cylindersOut,
;                                    uint16_t* sectorsOut,
;                                    uint16_t* headsOut);  
;

global x86_Disk_GetDriveParams
x86_Disk_GetDriveParams:

    push ebp                 ; save old call frame
    mov ebp, esp              ; initialize new call frame

    x86_EnterRealMode
    [bits 16]
    ; save regs
    push es
    push bx
    push esi
    push di

    

    ; call int 13h
    mov dl, [ bp + 8 ]
    mov ah, 08h
    mov di, 0h
    mov es, di
    stc
    int 13h

    

    ; out params
    mov eax, 1
    sbb eax, 0

    ; drive type 
    LinearToSegOffset [ bp + 12 ], es, esi, si     
    mov es:[ si ], bl

    ; cylinders
    mov bl, ch              ; lower cylinder bits in bl
    mov bh, cl              ; higher cylinder ( 2 ) bits in bh
    shr bh, 6
    inc bx

    LinearToSegOffset [ bp + 16 ], es, esi, si       
    mov es:[ si ], bx

    ; sectors
    xor ch, ch              ; ch = 0, put sectors in cx (clear ch)
    and cl, 3Fh             ; cl = sector 0 - 5 bits 00xxxxxx

    LinearToSegOffset [ bp + 20 ], es, esi, si 
    mov es:[ si ], cx

    ; heads
    mov cl, dh              ; heads = cl, cuz dl = drive number
    inc cx
    LinearToSegOffset [ bp + 24 ], es, esi, si 
    mov es:[ si ], cx

    ; restore regs
    pop di
    pop esi
    pop bx
    pop es

    ; return
   
    push eax

    x86_EnterProtectedMode

    [bits 32]
    pop eax
    ; restore old call frame
    mov esp, ebp 
    pop ebp
    ret

;
;void __attribute__((cdeck)) x86_Disk_Reset(uint8_t drive);
;
global x86_Disk_Reset
x86_Disk_Reset:
    [bits 32]

    ; make new call frame
    push ebp                 ; save old call frame
    mov ebp, esp              ; initialize new call frame

    x86_EnterRealMode
    mov ah, 0h
    mov dl, [ bp + 4 ]      ; dl => drive number
    stc
    int 13h
    
    mov eax, 1
    sbb eax, 0

    push eax

    x86_EnterProtectedMode

    pop eax

    ; restore old call frame
    mov esp, ebp 
    pop ebp
    ret


;
;void __attribute__((cdecl)) x86_Disk_Read(uint8_t drive,
;                            uint16_t cylinder,
;                            uint16_t sector,
;                            uint16_t head, 
;                            uint8_t count,
;                            uint8_t far* dataout);
;
global x86_Disk_Read
x86_Disk_Read:

    push ebp                 ; save old call frame
    mov ebp, esp              ; initialize new call frame

    x86_EnterRealMode

    ; save modified regs
    push ebx
    push es

    ; set up args
    mov dl, [ bp + 8 ]      ; dl => drive number

    mov ch, [ bp + 12 ]      ; ch => cylinder ( lower 8 bits )
    mov cl, [ bp + 13 ]      ; cl => cylinder to bits 6 - 7
    shl cl, 6               ; cl => xx000000

    mov al, [ bp + 16 ]      ; al => sector number but we need cl => 0 - 5 as sector number  
    and al, 3Fh             ; and 6 - 7 as cylinder number
    or  cl, al              ; xx000000 && 00yyyyyy => xxyyyyyy => 2 bits of cylinder and 6 bits of sectors


    mov dh, [ bp + 20 ]     ; dh => head

    mov al, [ bp + 24 ]     ; al => count ( 12 - 13 )

    LinearToSegOffset [ bp + 28 ], es, ebx, bx
      
    ; call int 13h
    mov ah, 02h
    stc
    int 13h

    ; set return value   
    mov eax, 1
    sbb eax, 0

    pop es
    pop ebx

    push eax

    x86_EnterProtectedMode

    pop eax

    ; restore old call frame
    mov esp, ebp 
    pop ebp
    ret