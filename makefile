
name = cforth
exe = $(exeDir)/$(name)

srcDir = src
asmDir = src/asm
buildDir = build
exeDir = bin

cSrc = $(wildcard $(srcDir)/*.c)
asmSrc = $(wildcard $(asmDir)/*.s)
asmObj = $(asmSrc:$(asmDir)%.s=$(buildDir)%.o)
cObj = $(cSrc:$(srcDir)%.c=$(buildDir)%.o)

AS = yasm
CC = gcc

asFlags = -f elf -m x86 -g dwarf2 -a x86 -I $(ASMDIR)/include
CFLAGS = -O0 -ggdb3 -Wall -m32

.PHONY: all, dir clean, run, debug, release

all: dir $(exe)

dir:
	@mkdir -p build

debug: $(exe)
	@gdb $(exe)

clean:
	@rm -r $(buildDir)

run: $(exe)
	@$(exe)

$(exe): $(asmObj) $(cObj)
	$(CC) $(CFLAGS) -o $(exe) $(asmObj) $(cObj)

$(buildDir)/%.o: $(asmDir)/%.s
	$(AS) $(asFlags) $< -o $@

$(buildDir)/%.o: $(srcDir)/%.c 
	$(CC) $(CFLAGS) -c $< -o $@
