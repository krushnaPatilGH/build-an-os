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
	mov ax , 0
	mov ds , ax
	mov es , ax

	mov ss , ax
	mov sp , 0x7C00

	; some BIOSes might start us at 07C0:0000 instead of 0000:7C00, make sure we are in the
    ; expected location
	push es
	push word .after 
	retf

.after:

	; read something from floopy
	; bios should set dl to drive no
	mov [ebr_drive_number], dl 

	;show loading msg
	mov si , msg_loading
	call puts

	; read drive params (sectors per track and head count)
	; instead on relying on data on formatted disk
	push es
	mov ah, 08h
	int 13h
	jc floppy_error
	pop es

	and cl, 0x3f							; remove top 2 bits
	xor ch, ch
	mov [bdb_sectors_per_track] , cx		; sector count

	inc dh
	mov [bdb_heads], dh

	; compute LBA of root directory = reserved + fats * sectors_per_fat
	mov ax, [bdb_sectors_per_fat]    		; root dir lba = reserved sectors + sectors per fat * fat count
	mov bl, [bdb_fat_count]
	xor bh, bh
	mul bx									; ax = sectors per fat * fat count
	add ax , [bdb_reserved_sectors]			; ax = reserved sectors + sectors per fat * fat count = root dir lba
	push ax

	; compute size of root directory, root dir size = dir count * 32 / bytes per sector
	mov ax, [bdb_dir_entries_count]			
	shl ax, 5								; ax *= 32
	xor dx, dx
	div word [bdb_bytes_per_sector]			; number of sectors we need to read

	test dx,dx								; if reminder then inc
	jz .root_dir_after
	inc ax

.root_dir_after:

	; read root dir
	mov cl, al								; number of sectors to read
	pop ax									; saved lba of root dir
	mov dl, [ebr_drive_number]				; set earlier by us when dl was set by bios
	mov bx, buffer							; buffer to read root dir [es:bx]
	call disk_read

	;search for stage2.bin
	xor bx, bx
	mov di, buffer							; now all the records of root dir are in di

.search_stage2:
	mov si, file_stage2_bin					; si = stage2 file name
	mov cx, 11								; max 11 letters of name
	push di									; save di in stack i.e. root dir info
	repe cmpsb								; cmp str di and si i.e. file stage2 and root dir entries
	pop di
	je .found_stage2

	add di, 32								; 32 is the size of one dir entry so goto next entry
	inc bx
	cmp bx, [bdb_dir_entries_count]			; cmp current entry vs total entries
	jl .search_stage2

	; stage2 not found
	jmp stage2_not_found_error

.found_stage2:
	; di should have the address of the stage2
	mov ax, [di + 26]						; offset of first_cluster_low in the dir entry is 26
	mov [stage2_cluster], ax				; load the cluster of stage2

	; load fat from disk into memory
	mov ax, [bdb_reserved_sectors]
	mov bx, buffer
	mov cl, [bdb_sectors_per_fat]
	mov dl, [ebr_drive_number]
	call disk_read

	; read stage2 and process FAT chain
	mov bx, STAGE2_LOAD_SEGMENT
	mov es, bx
	mov bx, STAGE2_LOAD_OFFSET

.load_stage2_loop:
	
	;Read next cluster
	mov ax, [stage2_cluster]				; loc of first cluster must be changed in future
	add ax, 31

	mov cl, 1
	mov dl, [ebr_drive_number]
	call disk_read

	add bx, [bdb_bytes_per_sector]

	; compute location of next cluster
	mov ax, [stage2_cluster]
	mov cx, 3
	mul cx
	mov cx, 2
	div cx									; loc of next cluster = current cluster * 3 / 2

	mov si, buffer
	add si, ax
	mov ax, [ds:si]							; read entry from FAT table that is in buffer at index ax 

	or dx, dx
	jz .even

.odd:
	shr ax , 4
	jmp .next_cluster_after
.even:
	and ax, 0x0FFF

.next_cluster_after:
	cmp ax, 0x0FF8							; end of chain
	jae .read_finish

	mov [stage2_cluster] , ax				; load the value of next cluster into [stage2_cluster]
	jmp .load_stage2_loop

.read_finish:
	;jmp to our stage2
	mov dl, [ebr_drive_number]				; boot device in dl

	mov ax, STAGE2_LOAD_SEGMENT				; set segment registers
	mov ds, ax
	mov es, ax			

	jmp STAGE2_LOAD_SEGMENT:STAGE2_LOAD_OFFSET

	jmp wait_key_reboot

	cli
	hlt



;
; error handlers
;
floppy_error:
	mov si, msg_read_fail
	call puts
	jmp wait_key_reboot

stage2_not_found_error:
	mov si, msg_stage2_not_found
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
;print a string
;
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



file_stage2_bin:        db 'STAGE2  BIN'

stage2_cluster:			dw 0
msg_loading: 			db 'loading....' , ENDL , 0
msg_read_fail:			db 'read disk failure', ENDL , 0
msg_stage2_not_found:	db 'STAGE2.BIN file not found error', ENDL, 0

STAGE2_LOAD_SEGMENT		equ 0x0
STAGE2_LOAD_OFFSET      equ 0x500


times 510-($-$$) 		db 0
						dw 0AA55h

buffer: 
