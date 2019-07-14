; ==========================================
; pmtest1.asm
; 编译方法：nasm pmtest1.asm -o pmtest1.bin
; ==========================================

%include "pm.inc" ;常量,宏,以及一些说明
org 07c00h
jmp LABEL_BEGIN  ;跳到开始处执行,此时不会修改cs,cs仍然为0,偏移地址会加上7c00
[SECTION .gdt] ;定义GDT全局描述符号(为(段地址,段界限,属性)三元组,占8字节空间)
LABEL_GDT: Descriptor 0,0,0 ;空描述符  
LABEL_DESC_CODE32:Descriptor 0,SegCode32Len-1,DA_C+DA_32 ;指向32位保护模式非一致代码段
LABEL_DESC_VIDEO:Descriptor 0B8000h,0ffffh,DA_DRW ;显存(显卡)首地址描述符
;GDT结束
GdtLen equ $-LABEL_GDT ;GDT长度
GdtPtr dw GdtLen-1 ;GDT界限
       dd 0   ;GDT基地址
;GDT选择子
SelectorCode32 equ LABEL_DESC_CODE32-LABEL_GDT
;这里比较特殊,各个描述符号的最右侧3位都为0,因此相减后,就是描述符在GDT表中的索引
SelectorVideo  equ LABEL_DESC_VIDEO-LABEL_GDT
;END of  [SECTION .gdt]
[SECTION .s16]
[BITS 16]
LABEL_BEGIN:
   mov ax,cs
   mov ds,ax
   mov es,ax
   mov ss,ax
   mov sp,0100h

;初始化32位代码段全局描述符的段基址
   xor eax,eax
   mov ax,cs
   shl eax,4
   add eax,LABEL_SEG_CODE32
   mov word [LABEL_DESC_CODE32+2],ax
   shr eax,16
   mov byte [LABEL_DESC_CODE32+4],al
   mov byte [LABEL_DESC_CODE32+7],ah
   ;为加载GDT表做准备,先将GDT表的界限和起始地址找到存到Gdtptr中
   xor eax,eax
   mov ax,ds
   shl eax,4
   add eax,LABEL_GDT
   mov dword [GdtPtr + 2],eax ;将GDT的基地址放好
   lgdt  [GdtPtr]  ;将GDT表加载进来,后面可以访问GDT表中的值
   ;关中断
   cli
   ;打开地址线A20
   in al,92h
   or al,00000010b
   out 92h,al
   ;准备切换到保护模式
   mov eax,cr0
   or eax,1
   mov cr0,eax

   ;真正进入保护模式
   jmp dword SelectorCode32:0 ;执行这句话,为了将SelectorCode32
                              ;指向的32为保护模式代码载入cs中
                              ;并跳转到SelectorCode32:0处
   ;END of  [SECTION .s16]
   
[SECTION .s32]
[BITS 32]
LABEL_SEG_CODE32:
   mov  ax,SelectorVideo
   mov  gs,ax ;视屏段选择子加载进gs
   mov  edi,(80*11 + 79)*2 ;屏幕第11行,79列
   mov  ah,0Ch      ;0,为黑字,c为红字
   mov  al,'P'     ;要显示的字符
   mov   [gs:edi],ax

   ;到此停止
   jmp $
    
   SegCode32Len equ $-LABEL_SEG_CODE32
   ;END of  [SECTION .s32]
