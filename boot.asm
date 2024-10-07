;%define _BOOT_DEBUG_
%ifdef _BOOT_DEBUG_
 org 0100h
%else
 org 07c00h ;告诉编译器程序加载到7c00地址处
%endif
mov ax, cs
mov ds, ax
mov es, ax
call DispStr ;显示字符串
jmp $
DispStr:
 mov ax, BootMessage
 mov bp, ax    ;10号bios中断程序,功能号13时,显示字符串的起始地址为es:bp
 mov cx, 16    ;10号bios中断程序,功能号13时,显示字符串的长度在cx中
 mov ax, 1301h ;让ah=13,al=01,作为10号bios中断程序的传入参数
 mov bx, 000ch ;页号为0(BH=0) 黑底红字(BL=0ch)
 mov dx, 0     ;10号bios中断程序,功能号13时,字符串显示的横纵坐标为(dh,dl)
 int 10h       ;调用10h号bios中断子程序
 ret
BootMessage:  db   "Hello, OS world!"
times 510-($-$$) db 0 ;输出字符串往后的地址填0
dw 0xaa55             ;结束标志,代表前面的一段程序为系统引导程序
