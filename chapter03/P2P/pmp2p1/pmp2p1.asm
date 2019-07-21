; ==========================================
; pmldt.asm
; 编译方法：make -f MakeFileLDT
; ==========================================

%include "pm.inc" ;常量,宏,以及一些说明
org 0100h
jmp LABEL_BEGIN  ;跳到开始处执行,此时不会修改cs,cs仍然为0,偏移地址会加上7c00
[SECTION .gdt] ;定义GDT全局描述符号(为(段地址,段界限,属性)三元组,占8字节空间)
LABEL_GDT: Descriptor 0,0,0 ;空描述符  
LABEL_DESC_NORMAL:Descriptor 0, 0ffffh,DA_DRW ;Normal描述符
LABEL_DESC_CODE32:Descriptor 0,SegCode32Len-1,DA_C+DA_32 ;指向32位保护模式非一致代码段
LABEL_DESC_CODE16:Descriptor 0, 0ffffh,DA_C ;指向16位,非一致代码
LABEL_DESC_DATA:Descriptor 0, DataLen-1, DA_DRW+DA_DPL1 ;Data 用来验证保护模式修改了这个值
LABEL_DESC_STACK:Descriptor 0,TopOfStack, DA_DRWA+DA_32 ;stack,32位,用来存储函数调用时暂时存入的参数
LABEL_DESC_LDT:Descriptor 0, LDTLen - 1, DA_LDT  ;LDT基地址描述符
LABEL_DESC_VIDEO:Descriptor 0B8000h,0ffffh,DA_DRW ;显存(显卡)首地址描述符
;GDT结束
GdtLen equ $-LABEL_GDT ;GDT长度
GdtPtr dw GdtLen-1 ;GDT界限
       dd 0   ;GDT基地址
;GDT选择子
SelectorNormal equ LABEL_DESC_NORMAL-LABEL_GDT
SelectorCode32 equ LABEL_DESC_CODE32-LABEL_GDT
SelectorCode16 equ LABEL_DESC_CODE16-LABEL_GDT
SelectorData equ LABEL_DESC_DATA - LABEL_GDT + SA_RPL3
SelectorStack equ LABEL_DESC_STACK-LABEL_GDT
SelectorVideo equ LABEL_DESC_VIDEO-LABEL_GDT
SelectorLDT equ LABEL_DESC_LDT - LABEL_GDT  ;选择子指向LDT基址
;这里比较特殊,各个描述符号的最右侧3位都为0,因此相减后,就是描述符在GDT表中的索引
;END of  [SECTION .gdt]

[SECTION .data1]
ALIGN 32
[BITS 32]
LABEL_DATA:
SPValueInRealMode dw 0 ;从保护模式跳入实模式时,用来当做栈偏移地址
PMMessage:     db  "In Protect Mode now, ^_^",0 ;在保护模式中显示
OffsetPMMessage equ PMMessage-$$ ;保护模式下相对于选择子基址的偏移量
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

   mov [LABEL_GO_BACK_TO_REAL+3],ax  ;由保护模式跳回来,跳到这个基地址
   mov [SPValueInRealMode],sp

   ; 初始化数据段描述符
   xor	eax, eax
   mov	ax, ds
   shl	eax, 4
   add	eax, LABEL_DATA
   mov	word [LABEL_DESC_DATA + 2], ax
   shr	eax, 16
   mov	byte [LABEL_DESC_DATA + 4], al
   mov	byte [LABEL_DESC_DATA + 7], ah
   
   ;初始化LDT在GDT中的描述符,对准LDT表的基址
   xor eax,eax
   mov ax, ds
   shl eax, 4  ;注意偏移地址时这里一定时eax,要不然20位地址就溢出了
   add eax,LABEL_LDT
   mov word [LABEL_DESC_LDT+2],ax
   shr eax,16
   mov byte [LABEL_DESC_LDT+4],al
   mov byte [LABEL_DESC_LDT+7],ah


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
   
   ;初始化LDT中的描述符
   xor eax,eax
   mov ax,ds
   shl eax,4
   add eax,LABEL_CODE_A
   mov word [LABEL_LDT_DESC_CODEA+2],ax
   shr eax,16
   mov byte [LABEL_LDT_DESC_CODEA+4],al
   mov byte [LABEL_LDT_DESC_CODEA+7],ah
   
   ;初始化16位代码段全局描述符的段基址
   xor eax,eax
   mov ax,cs
   shl eax,4
   add eax,LABEL_SEG_CODE16
   mov word [LABEL_DESC_CODE16+2],ax
   shr eax,16
   mov byte [LABEL_DESC_CODE16+4],al
   mov byte [LABEL_DESC_CODE16+7],ah


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
   
    
  LABEL_REAL_ENTRY:    ;从保护模式跳回到实模式会走到这里
  mov ax,cs
  mov ds,ax
  mov es,ax
  mov ss,ax
  
  mov sp,[SPValueInRealMode] 
  
  in al,92h  ;关闭A20地址线
  and al,11111101b 
  out 92h, al 
  
  sti ;打中断
 
  mov ax,4c00h ;启动21号中断,回到dos窗口 
  int 21h ;
  ;END of  [SECTION .s16]
   
   
   
[SECTION .s32]
[BITS 32]
LABEL_SEG_CODE32:
  mov ax,SelectorData
  mov ds,ax ;数据段选择子
  
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

  
  ;Load LDT表
  mov ax,SelectorLDT
  lldt ax
  ;跳入LDT表中局部描述符指向的任务
  jmp SelectorLDTCodeA:0

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
;LDT

[SECTION .ldt]
ALIGN 32
LABEL_LDT:
;段基址 段界限  属性
LABEL_LDT_DESC_CODEA:Descriptor 0,CodeALen-1,DA_C+DA_32 ;Code,32位代码
LDTLen equ $-LABEL_LDT

;LDT选择子
SelectorLDTCodeA equ LABEL_LDT_DESC_CODEA - LABEL_LDT + SA_TIL ;LDT描述符指向要调用的地址,
;SA_TIL为表明描述符为LDT描述符,会将TIL位置位1,代表是LDT选择子
;END of [SECTION .ldt]

;CODEA(LDT,32位描述符)
[SECTION .la]
ALIGN 32
[BITS 32]
LABEL_CODE_A:
  mov ax, SelectorVideo
  mov gs, ax    ;视频段选择子,指向显示屏,输出信息
  
  mov edi,(80*12+0)*2 ;屏幕第12行,第0列输出信息
  mov ah,0ch  ;0是黑底,c是红色字
  mov al,'L'  ;显示屏上输出L
  mov [gs:edi],ax ;显示屏上输出
   
  ;LDT表指示的任务完成后,跳回实模式
  jmp SelectorCode16:0
CodeALen equ $-LABEL_CODE_A
;END of [SECTION .la]

[SECTION .s16code]
ALIGN 32
[BITS 16]
LABEL_SEG_CODE16: ;跳回实模式
  mov ax,SelectorNormal ;回到正常16位模式段
  mov ds,ax
  mov es,ax
  mov fs,ax
  mov ss,ax

  mov eax,cr0
  mov al,11111110b
  mov cr0,eax

LABEL_GO_BACK_TO_REAL:
  jmp 0:LABEL_REAL_ENTRY ;段地址在前面会重新被置为正确的值
Code16Len  equ $-LABEL_SEG_CODE16
;END of [SECTION .s16code]
