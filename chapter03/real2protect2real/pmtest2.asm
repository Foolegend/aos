; ==========================================
; pmtest1.asm
; 编译方法：nasm pmtest1.asm -o pmtest1.bin
; ==========================================

%include "pm.inc" ;常量,宏,以及一些说明
org 0100h
jmp LABEL_BEGIN  ;跳到开始处执行,此时不会修改cs,cs仍然为0,偏移地址会加上7c00
[SECTION .gdt] ;定义GDT全局描述符号(为(段地址,段界限,属性)三元组,占8字节空间)
LABEL_GDT: Descriptor 0,0,0 ;空描述符  
LABEL_DESC_NORMAL:Descriptor 0, 0ffffh,DA_DRW ;Normal描述符
LABEL_DESC_CODE32:Descriptor 0,SegCode32Len-1,DA_C+DA_32 ;指向32位保护模式非一致代码段
LABEL_DESC_CODE16:Descriptor 0, 0ffffh,DA_C ;指向16位,非一致代码
LABEL_DESC_DATA:Descriptor 0, DataLen-1, DA_DRW ;Data 用来验证保护模式修改了这个值
LABEL_DESC_STACK:Descriptor 0,TopOfStack, DA_DRW+DA_32 ;stack,32位,用来存储函数调用时暂时存入的参数
LABEL_DESC_TEST:Descriptor 0500000h,0ffffh,DA_DRW;  保护模式下读取5M地址处的数据
LABEL_DESC_VIDEO:Descriptor 0B8000h,0ffffh,DA_DRW ;显存(显卡)首地址描述符
;GDT结束
GdtLen equ $-LABEL_GDT ;GDT长度
GdtPtr dw GdtLen-1 ;GDT界限
       dd 0   ;GDT基地址
;GDT选择子
SelectorNormal equ LABEL_DESC_NORMAL-LABEL_GDT
SelectorCode32 equ LABEL_DESC_CODE32-LABEL_GDT
SelectorCode16 equ LABEL_DESC_CODE16-LABEL_GDT
SelectorData equ LABEL_DESC_DATA-LABEL_GDT
SelectorStack equ LABEL_DESC_STACK-LABEL_GDT
SelectorTest equ LABEL_DESC_TEST-LABEL_GDT
SelectorVideo equ LABEL_DESC_VIDEO-LABEL_GDT
;这里比较特殊,各个描述符号的最右侧3位都为0,因此相减后,就是描述符在GDT表中的索引
;END of  [SECTION .gdt]
[SECTION .data1]
ALIGN 32
[BITS 32]
LABEL_DATA:
PMMessage:     db  "In Protect Mode now, ^_^",0 ;在保护模式中显示
OffsetPMMessage equ PMMessage-$$ ;保护模式下相对于选择子基址的偏移量
StrTest: db "ABCDEFGHIJKLMNOPQRSTUVWXYZ",0
OffsetStrTest equ StrTest-$$ ;保护模式下相对于选择子基址的偏移量
DataLen   equ $-LABEL_DATA
;END of [SECTION .data1]

;全局堆栈段
[SECTION .gs]
ALIGN 32
[BITS 32]
LABEL_STACK:
  times 512 db 0
TopOfStack equ $-LABEL_STACK-1 ;相对于堆栈选择子基址的字节偏移,指向512字节末尾字节
;END of [SECTION .gs]

[SECTION .s16]
[BITS 16]
LABEL_BEGIN:
   mov ax,cs
   mov ds,ax
   mov es,ax
   mov ss,ax
   mov sp,0100h


   ; 初始化数据段描述符
   xor	eax, eax
   mov	ax, ds
   shl	eax, 4
   add	eax, LABEL_DATA
   mov	word [LABEL_DESC_DATA + 2], ax
   shr	eax, 16
   mov	byte [LABEL_DESC_DATA + 4], al
   mov	byte [LABEL_DESC_DATA + 7], ah

   ; 初始化堆栈段描述符
    xor	eax, eax
    mov	ax, ds
    shl	eax, 4
    add	eax, LABEL_STACK
    mov	word [LABEL_DESC_STACK + 2], ax
    shr	eax, 16
    mov	byte [LABEL_DESC_STACK + 4], al
    mov	byte [LABEL_DESC_STACK + 7], ah

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
  mov ax,SelectorData
  mov ds,ax ;数据段选择子
  
  mov ax,SelectorTest
  mov es,ax  ;测试段选择子
  
  mov ax,SelectorVideo
  mov gs,ax    ;视屏段选择子
  
  mov ax,SelectorStack
  mov ss,ax      ;堆栈选择子 

  mov esp,TopOfStack  ;把栈顶初始化,ss:esp指向栈顶

  ;下面显示一个字符
  mov ah,0ch  ;0代表黑底,c代表红字
  xor esi,esi
  xor edi,edi
  mov esi,OffsetPMMessage ;ds:esi指向Data数据区
  mov edi,(80*10+0)*2 ;目的数据偏移.屏幕第10行,第0列
  cld

.1:
  lodsb  ;ds:esi指向的数据会自动加载到al中
  test al,al ;al为0时代表没有数据了需要结束显示
  jz .2
  mov [gs:edi],ax
  add edi,2   ;显示一个字符占两个字节(颜色和字)
  jmp .1
.2:  ;显示完毕
  
  call DispReturn ;在下一行开头处写数据

  call TestRead  ;读取5M数据段数据并显示

  call TestWrite ;将StrTest数据写入5M数据区

  call TestRead  ;重新读取5M数据段并显示
  
  ;到此停止
  jmp $

TestRead:
   xor esi,esi
   mov ecx,8 ;从5M数据段处读出8个字节
.loop:
   mov al,[es:esi]  ;将5M处数据段字节挨个取出到al中
   call DispAL
   inc esi
   loop .loop
   call DispReturn

   ret
;TestRead结束------

TestWrite:
   push esi
   push edi
   xor esi,esi
   xor edi,edi
   mov esi,OffsetStrTest  ;测试数据相对与测试数据选择子的便宜量
   cld
.1:
   lodsb  ;测试数据加载到al中
   test al,al
   jz  .2   ;没有数据后跳出
   mov [es:edi],al ;将数据写出到5M对应的数据段
   inc edi
   jmp .1
.2:
   pop edi
   pop esi
   ret 
;TestWrite结束-----

DispAL:
   push ecx
   push eax ;参数会压入栈中,以保存现场,调用结束后还原
  
   mov  ah,0ch
   mov  dl,al ;将数据暂存,一次处理4位
   shr  al,4 ;先处理高四位
   mov  ecx, 2  ;循环两次,先处理高四位再处理低四位
.begin:
   and al,01111b
   cmp al,9
   ja   .1  ;比9大说明时字母a,b,c,d,e,f
   add al,'0'
   jmp .2
.1:
   sub al,0Ah
   add al,'A' ;转换成字母输出
.2:
   mov [gs:edi],ax
   add edi,2

   mov al,dl ;开始处理低4位
   loop .begin
   add edi,2
   pop edx
   pop ecx
   ret ;函数结束一定要写这个代表回到开始调用的地方,此时cs,ip会从堆栈中还原回去
   ;DispAL结束------

DispReturn:
   push eax
   push ebx
   mov eax,edi
   mov bl,160
   div bl  ;计算出当前行号,一行占用160字节(80个字符)
   and eax,0ffh;上一步得到的商在eax存着,取出行数
   inc eax ;让行数加1
   mov bl,160
   mul bl   ;重新计算出行首的字节处
   mov edi,eax;上一步计算出的值在eax中,让显示屏定位到下一行行首
   pop ebx
   pop eax

   ret
;DispReturn结束------
       
SegCode32Len equ $-LABEL_SEG_CODE32
;END of  [SECTION .s32]
