;; file: iforth.s
;; Settings: (VIM)
;; set ft=nasm tabstop=8 softtabstop=0 expandtab shiftwidth=8 smarttab

;; How to use registers
        ;;;     Priority order (tmp vars go in bottom first)
        ; ESP - stack pointer (almost never use for data)
        ; EAX - all calculations in here or end here
        ; EDX - store data for calculations
        ; ECX - use as loop counter
        ; EDI - PTR for where to write loop generated data
        ; ESI - PTR where to read data from
        ; EBP - free when not stack base

;; NASM Declarations
        bits 32

;; Globals
        ;global _start
        global main

;; Constants
        ; Sizes
        PTR     equ     4       ; Size of a pointer
        ; ascii definitions
        NULL    equ     0x00
        LF      equ     0x0A



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; System Section
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

%macro os_call 0
        int     0x80
%endmacro

%macro os_exit 0
        mov     eax, sys.exit
        xor     ebx, ebx
        os_call
%endmacro
%macro os_exit 1
        mov     eax, sys.exit
        mov     ebx, %1
        os_call
%endmacro

%macro os_out 2
        mov     eax, sys.write
        mov     ebx, file.stdout
        mov     ecx, %1
        mov     edx, %2
        os_call
%endmacro

%macro os_in 2
        mov     eax, sys.read
        mov     ebx, file.stdin
        mov     ecx, %1
        mov     edx, %2
        os_call
%endmacro

section .rodata
;; System variables
        sys.exit        equ 0x01
        sys.write       equ 0x04    ; 32bit
        sys.read        equ 0x03    ; 32bit
        file.stdout     equ 0x01
        file.stdin      equ 0x00

section .data
        buff.size       db 64

section .bss
        buff            resb 64
        buff.len        resd 1



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; C Section (glibc)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Variables
        extern  stdout
        extern  stdin
        ;extern  errno

;; IO: output
        extern  write           ; int write(fd, buff, char_count)
        extern  fprintf         ; int32 fprintf(stream, *format, ...)
        extern  printf          ; int32 printf(*format, ...)
                                        ; RET: num chars printed
        extern  fputs           ; int32 fputs(buff, stream)
                                        ; (no newline; puts has newline)
        extern  puts            ; int32 puts(buffer) // stdout till NULL
                                        ; RET: > -1 / EOF on error
        extern  putchar         ; int32 putchar(int32 char) // stdout
        extern  fputc           ; int32 putchar(int char, stream)

;; IO: input
        extern  read            ; int read(fd, buff, count)
        extern  fgets           ; ptr fgets(buff, size, stream)
                                        ; RET: buff OR (NULL when done) 
        extern  fgetc           ; int32 fgetc(stream)
                                        ; RET: EOF/char (cast to int32)
        extern  getchar         ; EQV: fgetc(stdin)
        extern  ungetc          ; (DON'T USE)  

;; Memory
        extern  mmap
        extern  malloc          ; ptr malloc(num_bytes)
        extern  realloc         ; ptr realloc(address, num_bytes)
        extern  calloc          ; ptr calloc(num_cells, cell_bytes)
                                        ;Inits to zero (allocate array)
        extern  free            ; null free(address)

;;; Linux C x86 calling convention
        ; align stack to 4 byte boundry (AND  ESP, DWORD -4)
        ; all args on the stack
        ; push args in reverse order (first arg is top of stack)
        ; assume EAX, ECX, EDX are garbage after each call 
                ; (save them if important)
        ; EBX, EDI, ESI, ESP, EBP are safe
        ; return value is in EAX (sometimes EDX:EAX)
        ; caller loads the stack
        ; caller unloads the stack

;; Macros
; %macro c_func 1         ; Use to build c function calls
        


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Forth Section
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;%macro next 0
;        lodsd
;        jmp [eax]
;%endmacro
;
;%macro stk.ret.push 1
;        lea ebp, [ebp-4]
;        mov [ebp], %1
;%endmacro
;
;%macro stk.ret.pop 1
;        mov %1, [ebp]
;        lea ebp, [ebp+4]
;%endmacro
;
;section .rodata
;        ;; Flags (For Forth word header)
;        F_IMMED         equ 0x80
;        F_HIDDEN        equ 0x20
;        F_LENMASK       equ 0x1f ;; Length mask
;
;        ;;Store the chain of links
;        link            equ 0x0:0
;
;section .bss
;        var_S0          resd 1
;
;section .text
;        align 4
;docol:
;        stk.ret.push esi
;        add     eax, 4
;        mov     esi, eax
;        next
;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Forth Word Header
        struc wrd_hdr
                .link   resb PTR
                .flags  resb 1
                .chars  resb 4
        endstruc
;; defword macro (macro to define a forth word)

;; Flags
        f_immed         equ 0x80
        f_hidden        equ 0x20
        f_lenmask       equ 0x1f

;%macro defword 4  ,,0,  ; name, namelen, flags=0, label
;section .data
;        align 4
;        global %1_
;        link    resb PTR


section .data
        align 4
        forth_wrd      db 6,"DOUBLE",NULL



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MAIN
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        
global forth
global key

;;;     ESP: return stack
;;;     EBP: Buffer text buffer
;;;     EDI: data stack \ arg stack \ parameter stack
;;;     ESI: source code (dictionary)

extern get_page

section .bss
        align   64
        line            resb    64
        line_size       equ     ($ - buff)
        
        ;; Input and output buffers
        align   64
        input           resb    64
        input_size      equ     ($ - input)
        output          resb    64
        output_size     equ     ($ - output)

        align   PTR
        ret_stk:        resb    PTR
        arg_stk:        resb    PTR
        dict:           resb    PTR
        c_stk       resb    PTR

section .text
        align PTR
forth:
        enter   0, 0
        ; does putchar work
        push 0x0A
        push "t"
        push "a"
        push "c"
        call putchar
        lea esp, [esp+4]
        call putchar
        lea esp, [esp+4]
        call putchar
        lea esp, [esp+4]
        call putchar
        lea esp, [esp+4]

        ; learn about registers
        xor eax, eax
        add al, 0xaa
        add ah, 0xbb
        add eax, 0xddcc0000

        ; learn about the stack
        push 0xabcdef69
        push 0x12345678
        push 0x89674523
        push 0x98765432
        push 0x4c4f5645
        push 0x45564f4c         ; "LOVE" in ascii 

key:    ; get char via C `getchar()` and write it to the data stack
        call    getchar
        inc     edi             ; data_stk.push.1
        mov     [edi], al       ; data_stk.push.2
        ret

echo:   ; Output top of the stack through `putchar()`
        xor     eax, eax        ; zero EAX cuz putchar takes an int
        mov     al, [edi]       ; data_stk.pop.1
        dec     edi             ; data_stk.pop.2
        ; Set up for putchar()
        push    eax             ; push DWORD char on stack (lsb)
        call    putchar
        add     esp, PTR
        ret


        
        

.get_mem_page:
        call    get_page
        mov     [ret_stk], eax
        call    get_page
        mov     [arg_stk], eax
        call    get_page
        mov     [dict],    eax

        ; Setup arg_stk
        mov     eax, [arg_stk]
        add     eax, 4092   ; last address in page is dict[4095]
                            ; 4092 is the last 4 byte aligned addr
        mov     [arg_stk], eax ; dict is now set to the bottom of the stack
        
        ; Switch stack pointer to forth arg_stack
        mov     eax, esp         ; Get ready to store C stack PTR
        mov     [c_stk], eax     ; store C stack PTR
        mov     eax, [arg_stk]   ; Load arg stack PTR
        mov     esp, eax         ; new stack PTR is set

        ; set EBX to be the return stack pointer
        mov ebx, [ret_stk]

global get_stream
get_stream:     ; Get line from stdin and write to buff
        ;mov     ebx, line
        ;mov     eax, stdin    ; load addrs
        ;push    eax
        ;push    dword line_size
        ;push    ebx             ; Push args onto the stack
        push    dword line_size
        push    line
        push    0
        call    read
        lea     esp, [esp-3*PTR]

put_stream:     ; Write the stream to buff
        ;mov     eax, [stdout]
        ;push    eax
        ;push    ebx             ; EBX still holds [line]
        ;call    fputs
        push    6
        push    line
        push    1
        call    write
        lea     esp, [esp-3*PTR]
        ;lea     esp, [esp-2*PTR]
        jmp     restore_stk



get_word:  ; Get chars from console, store on stack, then print it out
        push    NULL
.loop:  call    getchar
        push    eax             ; save the char we got
        test    eax, eax        ; Test so we can check if negative
        JNS     .loop           ; IF EAX > -1 (!EOF) push char
.l_end  lea     esp, [esp+PTR]  ; remove EOF from stack

put_word:  ; Put chars to stdout
.loop:  call    putchar
        lea     esp, [esp+PTR] ; remove the char from the stack
        test    eax, 0
        jnz     .loop

restore_stk:   ; Restore C stack PTR and Store forth stack PTR
        mov     eax, esp
        mov     [arg_stk], eax  ; Save arg_stk
        mov     eax, [c_stk]
        mov     esp, eax        ; Restore C stack

        ;; DONE
        jmp     clean_exit

         

.test_mem_exe:
        ; Write opcodes to memory
        mov     eax, [dict]
        mov     edi, eax        ; load EDI with start address
        lea     ecx, [22]       ; load counter; 22 DD (inc ebx x88)
        lea     eax, [0x43434343]; code: inc EBX x4
        rep     stosd           ; write (inc ebx) to mem
        lea     eax, [0x9090E0FF]; littlendin; jmp eax nop nop
        stosd                   ; write jmp to mem
        ; Get ready to jmp and ret from memory
        xor     ebx, ebx        ; zero our counter
        mov     edx, [dict]     ; load addr to jmp to
        mov     eax, exit       ; load ret addr
        jmp     edx
.test_mem_rw:
        mov     ebx, [arg_stk]
        lea     eax, [42]
        mov     [ebx], eax
        xor     eax, eax
        mov     eax, [ebx]
exit:
        mov     eax, ebx
        leave
        ret

clean_exit:
        xor eax, eax
        leave
        ret
        

.create_word:
        ;push    dict_root
        ;pop     ebx             ; get addr of dict start
        ;; mov     [ebx], ebx      ; write addr to first spot to show end
        ;
        ;lea     ecx, [2]        ; num of dWords to copy
        ;lea     esi, [forth_wrd]; source address
        ;lea     edi, [dict_root+PTR]; dest address
        ;rep     movsd



;; test output        
;; Print Message
        and     esp, dword -4   ; Align the stack to 4 bytes
        push    msg             ; put arg on stack
        call    printf
        lea     esp, [esp+PTR]    ; take arg off stack

;; Exit Program
        mov     eax, edi
        lea     eax, [42]
        ;xor     eax, eax
        ;dec     eax
        ;os_exit    42
        leave
        ret



        ;; Init, so we can start interperting
        cld                     ; Clear stack direction flag
        ;mov     var_S0, esp     ; Save the initial data stack ptr
        ;mov     ebp, stk.ret.top; Init the return stack
        ;call    seg.data.init

        mov     esi, cold_start ; Init the interpreter
        next                    ; Run the interpreter

section .rodata
cold_start:                     ; High-level code without a codeword
        quit            dd 0x00
        ;os_output  msg, len
        ;os_input   buff, buff.size
        mov     [buff.len], eax
        ;os_output  buff, [buff.len]
        os_exit

section .data
        msg     db      "Hello World!", LF, NULL
        len     equ     ($ - msg - 1)

