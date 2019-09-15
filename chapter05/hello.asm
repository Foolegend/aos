[section .data] ;数据在此
strHello db "Hello, world!",0Ah
STRLEN   equ $-strHello
[section .text] ;代码在此
global _start 
_start:
   mov edx, STRLEN
   mov ecx, strHello
   mov ebx, 1
   mov eax, 4  ;sys_write
   int 0x80    ;系统调用
   mov ebx, 0
   mov eax, 1  ;sys_exit
   int 0x80    ;系统调用
   
