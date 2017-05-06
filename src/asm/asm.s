;; file: iforth.s
;; Settings: (VIM)
;; set ft=nasm tabstop=8 softtabstop=0 expandtab shiftwidth=8 smarttab

;; How to use registers
        ;;;     Priority order (use bottom first)
        ; ESP - stack pointer (almost never use for data)
        ; EAX - all calculations in here or end here
        ; EDX - store data for calculations
        ; ECX - use as loop counter
        ; EDI - PTR for where to write loop generated data
        ; ESI - PTR where to read data from
        ; EBP - free when not stack base
        ; EBX - base address for array lookup (preserved in C calls)

;; Globals
        global forth

;; Constants
        ; Sizes
        PTR     equ     4       ; Size of a pointer

        ; ascii definitions
        NULL    equ     0x00
        LF      equ     0x0A    ; LineFeed ascii code



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



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; C Section (glibc)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Variables
        extern  stdout
        extern  stdin

;; IO: output
        extern  write           ; int write(fd, buff, char_count)
        extern  fprintf         ; int fprintf(stream, *format, ...)
        extern  printf          ; int printf(*format, ...)
                                      ; RET: num chars printed
        extern  fputs           ; int fputs(buff, stream)
                                      ; (no newline; puts has newline)
        extern  puts            ; int puts(buffer) // stdout till NULL
                                      ; RET: > -1 / EOF on error
        extern  putchar         ; int putchar(int32 char) // stdout
        extern  fputc           ; int putchar(int char, stream)

;; IO: input
        extern  read            ; int read(fd, buff, count)
        extern  fgets           ; ptr fgets(buff, size, stream)
                                        ; RET: buff OR (NULL when done) 
        extern  fgetc           ; int fgetc(stream)
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
        


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Forth Section
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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


section .data   ;;; First Primitives

        ;; I/O Operations

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



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Interpreter
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
        
;;;     ESP: return stack
;;;     EBP: Buffer text buffer
;;;     EDI: data stack \ arg stack \ parameter stack
;;;     ESI: source code (dictionary)

section .bss
        align   PTR
        ret_stk:        resb PTR        ; Normally just ESP
        dat_stk:        resb PTR        ; aka parm, args, data
        src_stk:        resb PTR        ; aka Forth Dictionary
        c_stk:          resb PTR        ; In case we need to save ESP

section .text
        ;; Parent function externs
        extern main
        extern get_page

forth:  ;; main funtion of the interpreter
        enter   0, 0

        ;; Init memory for stacks
        call    get_mem_page

        ;; Exit the interpreter
        xor     eax, eax
.ret    leave           ; jmp here to return non 0
        ret


get_mem_page:   ; Call out to C func to get memory pages
        enter   0, 0
        call    get_page
        mov     [dat_stk], eax
        call    get_page
        mov     [src_stk], eax
        leave
        ret


