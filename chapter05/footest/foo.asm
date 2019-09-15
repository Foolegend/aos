extern choose ;int choose(int a, int b);
[section .data] ;数据在此
num1st dd 3
num2nd dd 4

[section .text] ;代码在此
global _start 
global myprint
_start:
   push dword [num2nd]
   push dword [num1st]
   call choose  ;choose(num1st, num2nd)
   add esp, 8
   mov ebx, 0
   mov eax, 1  ;sys_exit
   int 0x80    ;系统调用
myprint:
   mov edx,[esp+8] ;len 
   mov ecx,[esp+4] ;msg
   mov ebx,1
   mov eax,4 ;sys_write
   int 0x80  ;系统调用
   ret  
