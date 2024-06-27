org 0x7C00
bits 16

%define ENDL  0x0D , 0x0A

; FAT header
jmp short start
nop

bdb_oem:                    db 'MSWIN4.1'           ; 8 bytes
bdb_bytes_per_sector:       dw 512
bdb_sectors_per_cluster:    db 1
bdb_reserved_sectors:       dw 1
bdb_fat_count:              db 2
bdb_dir_entries_count:      dw 0E0h
bdb_total_sectors:          dw 2880                 ; 2880 * 512 = 1.44MB
bdb_media_descriptor_type:  db 0F0h                 ; F0 = 3.5" floppy disk
bdb_sectors_per_fat:        dw 9                    ; 9 sectors/fat
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0


; extended boot record
ebr_drive_number:			db 0
							db 0
ebr_signature:				db 28h
ebr_volume_id:				db 14h ,15h ,16h ,17h
ebr_volume_label:			db 'ZYRO OS    '
ebr_system_identifier:		db 'FAT12   '

; codeeeee

start:
	jmp main

puts:
	push si
	push ax

.loop:
	lodsb
	or al, al
	jz .done
	mov ah , 0x0E
	mov bh , 0
	int 0x10
	jmp .loop

.done:
	pop ax
	pop si
	ret
	


main:
	mov ax , 0
	mov ds , ax
	mov es , ax

	mov ss , ax
	mov sp , 0x7C00

	; read from floopy
	; bios should set dl to drive no
	mov [ebr_drive_number], dl 
	mov ax, 1									; LBA = 1 second sector from disk
	mov cl, 1									; 1 sector to read
	mov bx , 0x7E00								; data should be after the bootloader
	call disk_read


	mov si , msg
	call puts

	cli
	hlt



;
; error handlers
;
floppy_error:
	mov si, msg_read_fail
	call puts
	jmp wait_key_reboot
	

wait_key_reboot:
	mov ah, 0
	int 16h					; wait for keypress
	jmp 0FFFFh:0			; jmp to bios

.hlt:
	cli 
	hlt


;
; disk routines
;

;
; lba to chs
; params 
; 		- ax , lba address
; returns 
;		- cx , [0-5] : sector no
;		- cx , [6-15] : cylinder no
;		- dh : head no

lba_to_chs:
	push ax
	push dx

	xor dx , dx										; dx = 0
	div word [	bdb_sectors_per_track ]    			; ax = LBA / sectors per track
													; dx = LBA % sectors per track
	inc dx											; dx = ( LBA % sectors per track ) + 1 =  sector
	mov cx , dx										; cx = sector
	xor dx , dx
	div word [bdb_heads]							; ax = (LBA / sectors per track)/heads = cylinder
													; dx = (LBA / sectors per track)%heads = head
	mov dh, dl										; dl = head													
	mov ch, al										; ch = cylinder(lower 8 bits)
	shl ah, 6										; ah = (xx000000)
	or  ch, ah										; cx = (000000xx xxxxxxxx) cylinder [6-15]

	pop ax
	mov dl, al
	pop ax
	ret

;
; reads sectors from a disk
; params:
;		- ax : LBA address
;		- cl : number of sectors to read (128 max)
;       - dl : drive number
;		- es:bx : mem loc to store data

disk_read:
	push ax
	push bx
	push cx
	push dx
	push di



	push cx               							; save the value of cx
	call lba_to_chs									; compute chs
	pop ax											; no of sectors to read

	mov ah , 02h 
	mov di , 3										; retry atleast 3 times
	

.retry:
	pusha											; save all registers we dont know what bios modifies
	stc 											; set carry flag, some bios dont set it
	int 13h											; carry flag cleared = success operation

	jnc .done

	; read failed
	popa
	call disk_reset

	dec di
	test di , di
	jnz .retry

.fail:
	jmp floppy_error

.done:
	popa
	
	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	ret


;
; resets disk
;	params:	dl : drive no
;
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret

msg: 				db 'hello world' , ENDL , 0
msg_read_fail:		db 'read disk failure', ENDL , 0

times 510-($-$$) db 0
dw 0AA55h
