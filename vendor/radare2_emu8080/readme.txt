r2 -ai8080 tinybas_work_emu8080.bin
> aaa
> v
> pD


发现一个反编译器radare2
网页链接
很适合用来反汇编一小段的二进制文件，例如使用rasm反汇编（假设全是代码段）
rasm2 -a x86 -dD -Bf a.exe -O a.txt
使用rabin打印非代码信息
rabin2 -a x86 -Ilse a.exe > a.txt ​​​


rasm2 -a i8080 -dDBf hello_work_emu8080.bin

0x00000000   3                   211000  lxi h, 0010
0x00000003   1                       7e  mov a, m
0x00000004   1                       b7  ora a
0x00000005   3                   ca0e00  jz 000E
0x00000008   2                     d301  out 01
0x0000000a   1                       23  inx h
0x0000000b   3                   c30300  jmp 0003
0x0000000e   1                       76  hlt
0x0000000f   1                       00  nop
0x00000010   1                       48  mov c, b
0x00000011   1                       65  mov h, l
0x00000012   1                       6c  mov l, h
0x00000013   1                       6c  mov l, h
0x00000014   1                       6f  mov l, a
0x00000015   1                       20  db 0x20
0x00000016   1                       57  mov d, a
0x00000017   1                       6f  mov l, a
0x00000018   1                       72  mov m, d
0x00000019   1                       6c  mov l, h
0x0000001a   1                       64  mov h, h
0x0000001b   2                     2100  lxi h, 0000


E:\ghidra\radare2-5.8.2-w64\radare2-5.8.2-w64\bin>rasm2 -hh
 -a [arch]    set architecture to assemble/disassemble (see -L)
 -A           show Analysis information from given hexpairs
 -b [bits]    set cpu register size (8, 16, 32, 64) (RASM2_BITS)
 -B           binary input/output (-l is mandatory for binary input)
 -c [cpu]     select specific CPU (depends on arch)
 -C           output in C format
 -d, -D       disassemble from hexpair bytes (-D show hexpairs)
 -e           use big endian instead of little endian
 -E           display ESIL expression (same input as in -d)
 -f [file]    read data from file
 -F [in:out]  specify input and/or output filters (att2intel, x86.pseudo, ...)
 -h, -hh      show this help, -hh for long
 -i [len]     ignore/skip N bytes of the input buffer
 -j           output in json format
 -k [kernel]  select operating system (linux, windows, darwin, ..)
 -l [len]     input/Output length
 -L           list RAsm plugins: (a=asm, d=disasm, A=analyze, e=ESIL)
 -LL          list RAnal plugins (see anal.arch=?) combines with -j
 -LLL         list RArch plugins (see arch.arch=?) combines with -j
 -o,-@ [addr] set start address for code (default 0)
 -O [file]    output file name (rasm2 -Bf a.asm -O a)
 -p           run SPP over input for assembly
 -q           quiet mode
 -r           output in radare commands
 -s [syntax]  select syntax (intel, att)
 -v           show version information
 -x           use hex dwords instead of hex pairs when assembling.
 -w           what's this instruction for? describe opcode
 If '-l' value is greater than output length, output is padded with nops
 If the last argument is '-' reads from stdin
Environment:
 RASM2_NOPLUGINS   do not load shared plugins (speedup loading)
 RASM2_ARCH        same as rasm2 -a
 RASM2_BITS        same as rasm2 -b
 R2_LOG_LEVEL=X    change the log level
 R2_DEBUG          if defined, show error messages and crash signal
 R2_DEBUG_ASSERT=1 lldb -- r2 to get proper backtrace of the runtime assert
Preprocessor directives:
.include
.error
.warning
.echo
.if
.ifeq
.endif
.else
.set
.get
.extern
Assembler directives:
.intel_syntax
.att_syntax     sets e asm.syntax=att to use AT&T syntax parser
.endian [0,1]   default endian is system endian, 0=little, 1=big
.big_endian     call e cfg.bigendian=true, same as .endian 1
.lil_endian     call e cfg.bigendian=false, same as .endian 0
.asciz "msg" zero byte terminated string
.string         non-null terminated string
.ascii          same as .string
.align          force a specific alignment when writing code
.arm            set asm.bits=32 when asm.arch=arm
.thumb          set asm.bits=16 when asm.arch=arm
.arch [mips]    specify asm.arch
.bits [32|64]   specify 8,16,32,64 e asm.bits
.fill [count]   fill N bytes with zeroes
.kernel [ios]   set asm.os=linux,windows,macos,...
.cpu [name]     set asm.cpu=?
.os [os]        same as .kernel
.hex 102030     set bytes in linear hexpair string, no endian applied
.int16 [num]    write int16 number honoring endian
.int32 [num]    same for 32bit
.int64 [num]    same for 64bit
.size           n/a
.section        n/a
.byte 0x10,0x20 space or comma separated list of byte values
.glob           n/a
.equ K=V        define K to be replaced with V in the lines below
.org            change the PC=$$ to make relative instructions work
.text           tell the linker where the code starts
.data           tell the linker where the data starts
.incbin foo.bin include binary file

E:\ghidra\radare2-5.8.2-w64\radare2-5.8.2-w64\bin>


