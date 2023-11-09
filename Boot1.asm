;Filename = TinyBoot.nasm
;Type = bootsector.

base = 0x7c00
load_loc_def = 0x7e00

format binary
use16
org base

start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    jmp 0x0000:.clear_CS

;real mode
.clear_CS:
    lea si, [vars.init]
    call print


    ;check for LBA
    lea si, [vars.chklba]
    call print

    mov ah, 0x41
    mov bx, 0x55aa
    mov dl, 0x80
    int 0x13
    jc error

    lea si, [vars.done]
    call print
    

    ;Check for GPT
    lea si, [vars.chkgpt]
    call print

    mov si, LBA_readpacket
    mov ah, 0x42
    mov dl, 0x80
    int 0x13
    cmp ah, 0
    jne error

    cmp dword[load_loc_def], 'EFI '
    jne error
    cmp dword[load_loc_def+4], 'PART'
    jne error

    lea si, [vars.done]
    call print

    ;Find 2nd stage
    lea si, [vars.2nd]
    call print

    mov eax, [load_loc_def+0x48]
    mov [block], eax
    mov si, LBA_readpacket
    mov ah, 0x42
    mov dl, 0x80
    int 0x13
    cmp ah, 0
    jne error

    lea si, [vars.nl]
    call print


    ;Check flags
    lea si, [vars.2nd_flags]
    call print

    mov al, [load_loc_def+0x30]
    bt ax, 1
    jnc error
    bt ax, 2
    jnc error
    mov al, [load_loc_def+0x36]
    bt ax, 0
    jnc error

    lea si, [vars.done]
    call print


    ;Load
    lea si, [vars.load]
    call print

    mov eax, [load_loc_def+0x20]
    mov [block], eax
    mov si, LBA_readpacket
    mov ah, 0x42
    mov dl, 0x80
    int 0x13
    cmp ah, 0
    jne error

    lea si, [vars.done]
    call print


    ;Start
    lea si, [vars.starting]
    call print

    mov ax, [load_loc]
    jmp ax


    cli
    hlt





error:
    lea si, [vars.error]
    call print
    cli
    hlt


print:
    lodsb
    or al, al
    jz .done

    mov ah, 0x0E
    int 0x10

    jmp print

.done:
   ret


vars:
    .init: db 'Starting...', 0x0a, 0x0d, 0
    .chkgpt: db 'Checking for GPT...', 0
    .chklba: db 'Checking for LBA support...', 0
    .2nd_flags: db 'Checking partion flags...', 0
    .2nd: db 'Finding 2nd stage...', 0
    .done: db 'Done.';Must be folowed by .nl
    .nl: db 0x0a, 0x0d, 0
    .error: db 0x0a, 0x0d, 'Error.', 0
    .load: db 'Loading 2nd stage...', 0
    .starting: db 'Starting 2nd stage...', 0x0a, 0x0d, 0x0a, 0x0d, 0


align 4

times 440-16 - ($-$$) db 0

LBA_readpacket:
    db 16;size of packet
    db 0
    dw 4;num of sectors
    load_loc: dw load_loc_def;offset
    dw 0;segment 
    block: dd 1;low 32 bits
    dd 0;high 16 bits



times 440 - ($-$$) db 0;0x40 MBR 0x2 0xaa55

Sig: dd 0x0000
Resurved: dw 0
MBR:

times 0x200-0x2 - ($-$$) db 0;0x2 0xaa55

dw 0xaa55
end_of_bootsector:


