%include "pm.inc" ;常量,宏,以及一些说明
org 0100h
jmp LABEL_BEGIN
[SECTION .gdt]
; GDT      段基址,  段界限,   段属性
LABEL_GDT: Descriptor 0, 0, 0 ;空描述符
LABEL_DESC_CODE32:   Descriptor 0, SegCode32Len-1, DA_CR+DA_32		; 可读执行代码, 32
LABEL_DESC_STACK:    Descriptor 0,     TopOfStack, DA_DRWA+DA_32 ;32位Stack
LABEL_DESC_VIDEO:    Descriptor 0B8000h,   0ffffh, DA_DRW ;显存首地址
;GDT 结束

GdtLen equ $ - LABEL_GDT ;GDT长度
GdtPtr dw GdtLen - 1 ;GDT界限
       dd 0          ;GDT基地址
; GDT选择子
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK	- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT
;END of SECTION .gdt      

;IDT
[SECTION .idt]
ALIGN 32
[BITS 32]
LABEL_IDT:
 ;门: 目标段选择子, 偏移,DCount,属性
%rep 32
       Gate SelectorCode32,SupriousHandler, 0, DA_386IGate
%endrep
.020h: Gate SelectorCode32,   ClockHandler, 0, DA_386IGate
%rep 95
       Gate SelectorCode32,SupriousHandler, 0, DA_386IGate
%endrep
.080h: Gate SelectorCode32, UserIntHandler, 0, DA_386IGate

IdtLen equ $ - LABEL_IDT
IdtPtr dw  IdtLen - 1  ;段界限
       dd  0           ;idt段基地址
;End of section .idt


;全局堆栈段
[SECTION .gs]
ALIGN 32
[BITS 32]
LABEL_STACK:
  times 512 db 0
TopOfStack equ $ - LABEL_STACK - 1
;END of [SECTION .gs]

[SECTION .s16]
[BITS 16]
LABEL_BEGIN:
   mov ax, cs
   mov ds, ax
   mov es, ax
   mov ss, ax
   mov sp,0100h
   

   ; 初始化 32 位代码段描述符
   xor	eax, eax
   mov	ax, cs
   shl	eax, 4
   add	eax, LABEL_SEG_CODE32
   mov	word [LABEL_DESC_CODE32 + 2], ax
   shr	eax, 16
   mov	byte [LABEL_DESC_CODE32 + 4], al
   mov	byte [LABEL_DESC_CODE32 + 7], ah


   ; 初始化堆栈段描述符
   xor	eax, eax
   mov	ax, ds
   shl	eax, 4
   add	eax, LABEL_STACK
   mov	word [LABEL_DESC_STACK + 2], ax
   shr	eax, 16
   mov	byte [LABEL_DESC_STACK + 4], al
   mov	byte [LABEL_DESC_STACK + 7], ah

   ; 为加载 GDTR 作准备
   xor	eax, eax
   mov	ax, ds
   shl	eax, 4
   add	eax, LABEL_GDT		; eax <- gdt 基地址
   mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

   ;为加载IDTR做准备
   xor eax,eax
   mov ax, ds
   shl eax,4
   add eax,LABEL_IDT 
   mov dword [IdtPtr + 2], eax;

   ; 加载 GDTR
   lgdt	[GdtPtr]

   ; 关中断
   cli

   ;加载IDTR
   lidt [IdtPtr]
 
   ; 打开地址线A20
   in	al, 92h
   or	al, 00000010b
   out	92h, al

   ; 准备切换到保护模式
   mov	eax, cr0
   or	eax, 1
   mov	cr0, eax

   ; 真正进入保护模式
   jmp	dword SelectorCode32:0	; 执行这一句会把 SelectorCode32 装入 cs, 并跳转到 Code32Selector:0  处

[SECTION .s32] ;32位代码段,由实模式跳入
[BITS 32]
LABEL_SEG_CODE32:
  mov ax, SelectorVideo
  mov gs, ax

  mov ax, SelectorStack  ;堆栈段选择子
  mov ss, ax
  mov esp, TopOfStack 
 
  call Init8259A
  
  int 021h  ;显示一个"!"
  int 080h  ;显示一个动态的字符
  sti       ;利用时钟中断显示一个动态的字符
  jmp $

;Init8259A------
Init8259A:
   mov al,011h
   out 020h,al   ;主8259,ICW1
   call io_delay 

   out 0A0h,al   ;从8259,ICW1
   call io_delay 
   
   mov  al,020h   ;IRQ0对应中断向量0x20
   out  021h,al   ;主8259,ICW2
   call io_delay 
   
   mov  al,028h   ;IRQ8对应中断向量0x28
   out  0A1h,al   ;从8259,ICW2
   call io_delay 
  
   mov  al,004h   ;IRQ2对应从8259
   out  021h,al   ;从8259,ICW3
   call io_delay 
   
   mov  al,002h   ;对应主8259的IR2
   out  0A1h,al   ;从8259,ICW3
   call io_delay 

   mov  al, 001h
   out  021h,al   ;主8259,ICW4
   call io_delay
   
   out  0A1h,al   ;从8259,ICW4
   call io_delay
   
   mov  al, 11111110b ;仅开启定时器中断
   out  021h, al      ;主8259, OCW1
   call io_delay

   mov  al, 11111111b ;屏蔽从8259所有中断
   out  0A1h,al       ;从8259,OCW1
   call io_delay

   ret
;Init8259A结束---------

io_delay:
   nop
   nop
   nop
   nop
   ret

;int handler
_ClockHandler:
ClockHandler equ _ClockHandler - $$
   inc  byte [gs: (80*0+70)*2] ;屏幕第0行
   mov  al, 20h
   out  20h,al         ;发送EOI
   iretd

_UserIntHandler:
UserIntHandler equ _UserIntHandler - $$
   mov ah,0Ch
   mov al,'I'
   mov [gs:((80*0+70)*2)], ax
   iretd

_SupriousHandler:
SupriousHandler  equ  _SupriousHandler - $$
   mov ah,0ch
   mov al,'!'
   mov [gs:((80*0+75)*2)],ax ;屏幕第0行,第75列
   iretd
;--------
    
SegCode32Len	equ	$ - LABEL_SEG_CODE32
; END of [SECTION .s32]
