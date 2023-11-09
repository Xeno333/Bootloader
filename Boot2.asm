;Filename = Boot2.nasm
;Type = 2cn stage bootloader.

base = 0x7e00
Page_table = 0x1000
code_segment = 0x0008
vidset = 0 ;0: vidmode = 0x0e, 1: vidmode = 0x6a
vidmode = 0x03;0x6a;0x03
version = 0x1000;1.0.00

format binary
use16
org base
    jmp 0x0000:start

times 0x8 - ($-$$) db 0
ID: db 'BOOT'
times 0x10 - ($-$$) db 0


;real mode
start:
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00

    ;Set video mode.
    mov ax, vidmode
    int 0x10

    lea si, [vars.init]
    call print

    ;Get memory size. mem_map
    mov di, mem_map
    xor ebx, ebx 
    mov edx, 0x534D4150
    mov eax, 0x0000E820
    mov ecx, 24
    int 0x15
    jc mem_check_fail
    cmp eax, 0x534D4150
    jne mem_check_fail
    
    mov eax, 0xE820
    mov ecx, 24
    add di, 24
    int 0x15
    mov [boot_data_block.mem_map_e_size], cl
    cmp ebx, 0
    je .mem_l_d
    jc .mem_l_d
    inc dword[boot_data_block.mem_map_num_e]

    .mem_l:
        mov eax, 0xE820
        mov ecx, 24
        add di, 24
        int 0x15
        cmp ebx, 0
        je .mem_l_d
        pushf
        inc dword[boot_data_block.mem_map_num_e]
        popf
        jnc .mem_l

    .mem_l_d:


    ;Check for long mode
    lea si, [vars.checklong]
    call print

    pushfd
    pop eax
    mov ecx, eax
    xor eax, 0x200000
    xor eax, ecx
    shr eax, 21
    and eax, 1
    push ecx
    popfd

    test eax, eax
    jz long_mode_not_found

    mov eax, 0x80000000
    cpuid
    cmp eax, 0x80000001
    jb long_mode_not_found

    mov eax, 0x80000001
    cpuid
    test edx, 1 shl 29
    jz long_mode_not_found

    lea si, [vars.done]
    call print



    lea si, [vars.startlong]
    call print


    ;Start
    cld
    cli
    mov al, 0xFF
    out 0xA1, al
    out 0x21, al

    mov edi, Page_table
    mov cr3, edi
    mov ecx, 0x1000
    xor eax, eax
    rep stosd
    mov edi, Page_table

    mov dword[edi], Page_table+0x1003
    add edi, 0x1000
    mov dword[edi], Page_table+0x2003
    add edi, 0x1000

    mov ebx, 00000000000000000000000010000011b
    mov eax, 00000000000000000000000000000000b
    mov ecx, 8;8 pages, 16 MiB Kernel is loaded to 0x200000


page_table_loop:
    mov [edi], ebx
    mov [edi+4], eax
    add ebx, 0x200000
    add edi, 8
    dec ecx
    jnz page_table_loop
    mov eax, 0



    mov eax, 10100000b
    mov cr4, eax

    ;out of RM
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 shl 8
    wrmsr

    mov ebx, cr0
    or ebx, 1 shl 31 or 1 shl 0
    mov cr0, ebx

    ;out of PM
    mov ecx, 0xC0000080
    rdmsr
    or eax, 1 shl 8
    wrmsr
    mov ebx, cr0
    or ebx, 1 shl 31
    mov cr0, ebx

    lgdt [gdt_pointer]

    jmp code_segment:start_long_mode





macro GDT_64bit_entry arg0, arg1, arg2, arg3 {
    dw arg0 and 0xffff;Limit
    dw arg1 and 0xffff;Base
    db arg1 shr 16;Base
    db arg2;Access
    db (arg3 shl 4)+((arg0 shl 16) and 0xF);Limit and Flags. 4 = Flags.
    db arg1 shr 24;Base
}


gdt:
.null:
    GDT_64bit_entry 0, 0, 0, 0

.code:
    GDT_64bit_entry 0xfffff, 0, 10011110b, 1010b
.data:
    GDT_64bit_entry 0xfffff, 0, 10010010b, 1010b

gdt_end:

db 0

gdt_pointer:
    dw gdt_end - gdt - 1
    dq gdt






mem_check_fail:
    lea si, [vars.memfail]
    call print

    hlt
    cli


long_mode_not_found:
    lea si, [vars.nolong]
    call print

    hlt
    cli


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
    .init: db 0x0a, 0x0d, ' ---------------------------------------------------------------- ', 0x0a, 0x0d, 0x0a, 0x0d, '2nd stage bootloader Started.', 0x0a, 0x0d, 0
    .checklong: db "Checking for 64-bit support...", 0
    .startlong: db "Starting longmode, new text should begin at top...", 0
    .done: db 'Done.', 0x0a, 0x0d, 0
    .nolong: db "Sorry, you CPU does not support long mode. Make sure BIOS mode is working or GET A NEW PC!", 0x0A, 0x0D, 0
    .memfail: db "Mem check failed. Make sure BIOS mode is working or GET A NEW PC!", 0x0a, 0x0d, 0



use64

vars64:
    .vgapos: dq 0xB8000
    .str1: db 'Longmode started! ', 0
    .Error: db 'Error: '
    .Error_code: dq '00000000', 0
    .hret: db 'For some reason the kernel has returned. Now halting CPU. If this was the perpose of the kernel, your proccess has finished', 0


boot_data_block:
    .video_mode: dq vidset
    .boot_ver: dq version
    .mem_map_adr: dq mem_map
    .mem_map_num_e: dq 0
    .mem_map_e_size: dq 0;20 or 24

    
func:
    .putc:
        push rdi
        mov rdi, [vars64.vgapos]
        mov byte [rdi], al
        mov byte [rdi+1], 15
        add qword [vars64.vgapos], 2
        pop rdi
        ret

    .puts:
        push rsi
        push rax
        .puts_l:
            lodsb
            cmp al, 0
            je .puts_e
            call .putc
            jmp .puts_l
        .puts_e:
            pop rax
            pop rsi
            ret

    .print_GPT_PART_name:
        push rsi
        push rax
        .print_GPT_PART_name_l:
            lodsw
            cmp al, 0
            je .print_GPT_PART_name_e
            call .putc
            jmp .print_GPT_PART_name_l
        .print_GPT_PART_name_e:
            pop rax
            pop rsi
            ret

Error:
    mov [vars64.Error_code], rax
    mov rsi, vars64.Error
    call func.puts
    cli 
    hlt


start_long_mode:
    mov rax, '00000002'
    mov rcx, 0x5452415020494645 ; 'EFI PART'
    mov [0x300000], rcx
    cmp [0x300000], rcx ;Min of 32 MiB memory
    jne Error

    ;turn off curser
    mov dx, 0x3D4
    mov al, 0xA
    out dx, al
    inc dx
    mov al, 0x20
    out dx, al

    mov rsi, vars64.str1
    call func.puts

    mov rax, 1
    mov rcx, 1
    mov rdx, 0
    mov rdi, 0x200000
    call read
    
    mov rax, '00000001'
    mov rcx, 0x5452415020494645; 'EFI PART'
    cmp [0x200000], rcx
    jne Error

    mov rax, [0x200048]
    mov rcx, 1
    mov rdx, 0
    mov rdi, 0x200000
    call read


    mov rax, [0x2000A0]
    mov r15, [0x2000A8]
    sub r15, rax
    mov rcx, 2048
    mov rdx, 0
    mov rdi, 0x200000
    call read

    mov rax, vidset
    mov rdi,boot_data_block
    call 0x200000

    mov qword [vars64.vgapos], 0xb8000+(160*23)
    mov rsi, vars64.hret
    call func.puts
    cli
    hlt






Disk_io_port = 0x1f0

    read:
        push rdi
        .read_l:

            push rcx
            push rax

            xchg eax, ecx
            mov dx, Disk_io_port+6      ; Port to send drive and bit 24 - 27 of LBA
            shr eax, 24          ; Get bit 24 - 27 in al
            or al, 11100000b     ; Set bit 6 in al for LBA mode and bit 4 for slave
            out dx, al

            mov dl, (Disk_io_port+2) and 0x00ff     ; Port to send number of sectors
            mov al, 1
            out dx, al
            xchg eax, ecx

            mov cl, 3
            .read_out_rax_loop:
                inc dl
                out dx, al
                shr eax, 8
                loop .read_out_rax_loop

            mov dl, (Disk_io_port+7) and 0x00ff      ; Command port
            mov al, 0x20         ; Read with retry.
            out dx, al

        .still_going:
            in al, dx
            and al, 8           ; the sector buffer requires servicing.
            jz .still_going      ; until the sector buffer is ready.

            mov cl, 128         ; CL is counter for INSD
            mov dl, (Disk_io_port) and 0x00ff          ; Data port, in and out
            rep insd             ; in to [RDI]

            pop rax
            pop rcx


        inc eax

        loop .read_l

        pop rdi
        ret

times 0x600 - ($-$$) db 0
mem_map:

times 0x800 - ($-$$) db 0


