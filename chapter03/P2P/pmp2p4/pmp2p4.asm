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
LABEL_DESC_VIDEO:Descriptor 0B8000h,0ffffh,DA_DRW + DA_DPL3;显存(显卡)首地址描述符
LABEL_DESC_CODE_DEST:Descriptor 0,SegCodeDestLen-1,DA_C+DA_32 ;32位非一致代码段
LABEL_CALL_GATE_TEST:Gate SelectorCodeDest,0,0,DA_386CGate + DA_DPL3 ;定义门描述符,指向门代码段选择子
LABEL_DESC_CODE_RING3:Descriptor 0,SegCodeRing3Len-1,DA_C+DA_32+DA_DPL3 ;指向3级别代码段的全局段描述符
LABEL_DESC_STACK3:Descriptor 0,TopOfStack3,DA_DRWA+DA_32+DA_DPL3 ;指向3级别栈段的全局段描述符
LABEL_DESC_TSS:Descriptor 0, TSSLen-1 ,DA_386TSS ;低级别跳转到高级别时需要用到TSS堆栈以切换不同级别的堆栈数据
;GDT结束
GdtLen equ $-LABEL_GDT ;GDT长度
GdtPtr dw GdtLen-1 ;GDT界限
       dd 0   ;GDT基地址
;GDT选择子
SelectorNormal equ LABEL_DESC_NORMAL-LABEL_GDT
SelectorCode32 equ LABEL_DESC_CODE32-LABEL_GDT
SelectorCode16 equ LABEL_DESC_CODE16-LABEL_GDT
SelectorData equ LABEL_DESC_DATA - LABEL_GDT
SelectorStack equ LABEL_DESC_STACK-LABEL_GDT
SelectorVideo equ LABEL_DESC_VIDEO-LABEL_GDT
SelectorLDT equ LABEL_DESC_LDT - LABEL_GDT  ;选择子指向LDT基址
SelectorCodeDest equ LABEL_DESC_CODE_DEST - LABEL_GDT  ;门代码段对应的选择子
SelectorCallGateTest equ LABEL_CALL_GATE_TEST - LABEL_GDT + SA_RPL3 ;门描述符对应的选择子
SelectorCodeRing3 equ LABEL_DESC_CODE_RING3 - LABEL_GDT + SA_RPL3 ;指向3级别代码段描述符的选择子
SelectorStack3 equ LABEL_DESC_STACK3 - LABEL_GDT + SA_RPL3 ;指向3级栈段描述符的选择子
SelectorTSS equ LABEL_DESC_TSS - LABEL_GDT ;指向TSS描述符的选择子
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

   ;初始化测试门代码段描述符
   xor eax,eax
   mov ax,cs
   shl eax,4
   add eax,LABEL_SEG_CODE_DEST
   mov word [LABEL_DESC_CODE_DEST + 2],ax
   shr eax,16
   mov byte [LABEL_DESC_CODE_DEST + 4],al
   mov byte [LABEL_DESC_CODE_DEST + 7],ah
   
   ;初始化3级别栈段描述符
   xor eax,eax
   mov ax,cs
   shl eax,4
   add eax,LABEL_STACK3
   mov word [LABEL_DESC_STACK3 + 2],ax
   shr eax,16
   mov byte [LABEL_DESC_STACK3 + 4],al
   mov byte [LABEL_DESC_STACK3 + 7],ah


   ;初始化3级别代码段描述符
   xor eax,eax
   mov ax,cs
   shl eax,4
   add eax,LABEL_CODE_RING3
   mov word [LABEL_DESC_CODE_RING3 + 2],ax
   shr eax,16
   mov byte [LABEL_DESC_CODE_RING3 + 4],al
   mov byte [LABEL_DESC_CODE_RING3 + 7],ah


   ;初始化3级别代码段描述符
   xor eax,eax
   mov ax,cs
   shl eax,4
   add eax,LABEL_TSS
   mov word [LABEL_DESC_TSS + 2],ax
   shr eax,16
   mov byte [LABEL_DESC_TSS + 4],al
   mov byte [LABEL_DESC_TSS + 7],ah

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
  mov ax,SelectorTSS ;指向TSS选择子
  ltr ax  ;加载TSS选择子
  
  push SelectorStack3 ;将3级别的堆栈选择子入栈,对应ss
  push TopOfStack3  ;将3级别堆栈栈顶偏移入栈,对应esp
  push SelectorCodeRing3  ;将3级别代码段选择子入栈,对应cs
  push 0  ;将3级别代码段的偏移入栈,对应eip
  retf  ;执行后,与三级别相关的参数会从栈中弹出,并将ss,esp,cs,eip赋好值,这样就会执行三级别的代码段
 
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

[SECTION .door];调用门目标段
[BITS 32]
LABEL_SEG_CODE_DEST:
   ;jmp $
   mov ax,SelectorVideo
   mov gs,ax  ;指向现存,视屏段选择子

   mov edi,(80*13+0)*2  ;屏幕第13行,第0列

   mov ah,0ch   ;0代表黑色背景,c代表红色字体
   mov al,'C'
   mov [gs:edi],ax
   
      
   ;Load LDT表
   mov ax,SelectorLDT
   lldt ax
   ;跳入LDT表中局部描述符指向的任务
   jmp SelectorLDTCodeA:0
  ; retf
   
SegCodeDestLen equ $-LABEL_SEG_CODE_DEST
;end of [SECTION .door]

;堆栈段ring3
[SECTION .stack3]
ALIGN 32
[BITS 32]
LABEL_STACK3:
  times 512 db 0
TopOfStack3 equ $-LABEL_STACK3-1
;END of [SECION .stack3]

;CodeRing3
[SECTION .ring3]
ALIGN 32
[BITS 32]
LABEL_CODE_RING3:
  mov ax,SelectorVideo
  mov gs,ax
  
  mov edi,(80*14+0)*2
  mov ah,0ch
  mov al,'3'
  mov [gs:edi],ax
  
  call SelectorCallGateTest:0 ;测试调用门(低级门访问告警权限)
  

SegCodeRing3Len equ $ - LABEL_CODE_RING3
;END of [SECTION .ring3]

;TSS
[SECTION .tss]
ALIGN 32
[BITS 32]
LABEL_TSS:
  DD 0  ;Back
  DD TopOfStack ;0级堆栈
  DD SelectorStack
  DD 0  ;1级堆栈
  DD 0  
  DD 0  ;2级堆栈
  DD 0  
  DD 0  ;CR3
  DD 0  ;EIP
  DD 0  ;EFLAGS
  DD 0  ;EAX
  DD 0  ;ECX
  DD 0  ;EDX
  DD 0  ;EBX
  DD 0  ;ESP
  DD 0  ;EBP
  DD 0  ;ESI
  DD 0  ;EDI
  DD 0  ;ES
  DD 0  ;CS
  DD 0  ;SS
  DD 0  ;DS
  DD 0  ;FS
  DD 0  ;GS
  DD 0  ;LDT
  DW 0  ;调试陷阱标志
  DW $ - LABEL_TSS + 2 ;I/O位图基址
  DB 0ffh ;I/O图结束标志
TSSLen  equ $-LABEL_TSS
