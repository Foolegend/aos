%include "pm.inc" ;常量,宏,以及一些说明
LinearAddrDemo equ 00401000h
ProcFoo        equ 00401000h
ProcBar        equ 00501000h
ProcPagingDemo equ 00301000h

PageDirBase0   equ 200000h;页目录开始地址
PageTblBase0   equ 201000h;页目录开始地址
org 0100h
jmp LABEL_BEGIN
[SECTION .gdt]
; GDT      段基址,  段界限,   段属性
LABEL_GDT: Descriptor 0, 0, 0 ;空描述符
LABEL_DESC_NORMAL:   Descriptor 0,         0ffffh, DA_DRW		; Normal 描述符
LABEL_DESC_CODE32:   Descriptor 0, SegCode32Len-1, DA_CR+DA_32		; 可读执行代码, 32
LABEL_DESC_CODE16:   Descriptor 0,         0ffffh, DA_C			; 非一致代码段, 16
LABEL_DESC_DATA:     Descriptor 0,      DataLen-1, DA_DRW		; Data
LABEL_DESC_STACK:    Descriptor 0,     TopOfStack, DA_DRWA+DA_32 ;32位Stack
LABEL_DESC_VIDEO:    Descriptor 0B8000h,   0ffffh, DA_DRW ;显存首地址
LABEL_DESC_FLAT_C:   Descriptor 0,         0fffffh, DA_CR|DA_32|DA_LIMIT_4K; 0~4G
LABEL_DESC_FLAT_RW:  Descriptor 0,         0fffffh, DA_DRW|DA_LIMIT_4K; 0~4G
;GDT 结束

GdtLen equ $ - LABEL_GDT ;GDT长度
GdtPtr dw GdtLen - 1 ;GDT界限
       dd 0          ;GDT基地址
; GDT选择子
SelectorNormal		equ	LABEL_DESC_NORMAL	- LABEL_GDT
SelectorCode32		equ	LABEL_DESC_CODE32	- LABEL_GDT
SelectorCode16		equ	LABEL_DESC_CODE16	- LABEL_GDT
SelectorData		equ	LABEL_DESC_DATA		- LABEL_GDT
SelectorStack		equ	LABEL_DESC_STACK	- LABEL_GDT
SelectorVideo		equ	LABEL_DESC_VIDEO	- LABEL_GDT
SelectorFlatC		equ	LABEL_DESC_FLAT_C	- LABEL_GDT
SelectorFlatRW		equ	LABEL_DESC_FLAT_RW	- LABEL_GDT
;END of SECTION .gdt      

[SECTION .data1]
ALIGN 32
[BITS 32]
LABEL_DATA:
 ;;实模式下使用下面的这些符号
_szPMMessage: db "In Protect Mode Now. ^_^",0Ah,0Ah,0 ;进入保护模式后显示此字符串
_szMemChkTitle: db "BaseAddrL  BaseAddrH  LengthLow LengthHigh Type",0Ah,0 ;进入保护模式后显示字符串
_szRAMSize:  db "RAM size:",0
_szReturn: db 0Ah,0
;变量
_wSPValueInRealMode dw 0
_dwMCRNumber: dd 0;Memory Check Result
_dwDispPos: dd (80*2 + 0)*2
_dwMemSize dd 0
_ADRStruct:    ;Address Range Descriptor Structure
  _dwBaseAddrLow: dd 0
  _dwBaseAddrHigh: dd 0
  _dwLengthLow: dd 0
  _dwLengthHigh: dd 0
  _dwType: dd 0
_MemChkBuf: times 256 db 0
_PageTableNumber dd 0

;保护模式下使用下面的符号
szPMMessage  equ _szPMMessage - $$
szMemChkTitle equ _szMemChkTitle - $$
szRAMSize equ _szRAMSize - $$
szReturn equ _szReturn - $$
dwDispPos equ _dwDispPos - $$
dwMemSize equ _dwMemSize - $$
dwMCRNumber equ _dwMCRNumber - $$
ADRStruct equ _ADRStruct - $$
   dwBaseAddrLow equ _dwBaseAddrLow - $$
   dwBaseAddrHigh equ _dwBaseAddrHigh - $$
   dwLengthLow equ _dwLengthLow - $$
   dwLengthHigh equ _dwLengthHigh - $$
   dwType equ _dwType - $$
MemChkBuf equ _MemChkBuf - $$
PageTableNumber equ _PageTableNumber - $$

DataLen  equ $ - LABEL_DATA
;END of [SECTION .data1]

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
   
   mov [LABEL_GO_BACK_TO_REAL+3], ax
   mov [_wSPValueInRealMode], sp
   
   ;得到内存数
   mov ebx,0
   mov di, _MemChkBuf
.loop:
   mov eax,0E820h
   mov ecx,20
   mov edx,0534D4150h
   int 15h
   jc LABEL_MEM_CHK_FAIL
   add di,20
   inc dword [_dwMCRNumber]
   cmp ebx,0
   jne .loop
   jmp LABEL_MEM_CHK_OK
LABEL_MEM_CHK_FAIL:
   mov dword [_dwMCRNumber], 0
LABEL_MEM_CHK_OK:
  
   ;初始化16位代码描述符段
   mov	ax, cs
   movzx eax, ax
   shl	eax, 4
   add	eax, LABEL_SEG_CODE16
   mov	word [LABEL_DESC_CODE16 + 2], ax
   shr	eax, 16
   mov	byte [LABEL_DESC_CODE16 + 4], al
   mov	byte [LABEL_DESC_CODE16 + 7], ah

   ; 初始化 32 位代码段描述符
   xor	eax, eax
   mov	ax, cs
   shl	eax, 4
   add	eax, LABEL_SEG_CODE32
   mov	word [LABEL_DESC_CODE32 + 2], ax
   shr	eax, 16
   mov	byte [LABEL_DESC_CODE32 + 4], al
   mov	byte [LABEL_DESC_CODE32 + 7], ah

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

   ; 为加载 GDTR 作准备
   xor	eax, eax
   mov	ax, ds
   shl	eax, 4
   add	eax, LABEL_GDT		; eax <- gdt 基地址
   mov	dword [GdtPtr + 2], eax	; [GdtPtr + 2] <- gdt 基地址

   ; 加载 GDTR
   lgdt	[GdtPtr]

   ; 关中断
   cli

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


LABEL_REAL_ENTRY:		; 从保护模式跳回到实模式就到了这里
   mov	ax, cs
   mov	ds, ax
   mov	es, ax
   mov	ss, ax

   mov	sp, [_wSPValueInRealMode]

   in	al, 92h		; ┓
   and	al, 11111101b	; ┣ 关闭 A20 地址线
   out	92h, al		; ┛

   sti			; 开中断

   mov	ax, 4c00h	; ┓
   int	21h		; ┛回到 DOS
; END of [SECTION .s16]  

[SECTION .s32] ;32位代码段,由实模式跳入
[BITS 32]
LABEL_SEG_CODE32:
  mov ax, SelectorData
  mov ds, ax   ;数据段选择子
  mov es, ax
  mov ax, SelectorVideo
  mov gs, ax

  mov ax, SelectorStack  ;堆栈段选择子
  mov ss, ax
  
  mov esp, TopOfStack 
  push szPMMessage
  call DispStr
  add esp, 4
  
  push szMemChkTitle
  call DispStr
  add esp, 4
  
  call DispMemSize ;显示内存信息
  ;mov eax,4
  ;push eax
  ;call DispInt
  call PagingDemo  ;演示分页后的地址寻址
  jmp SelectorCode16:0 ;到此停止

%include "lib.inc"  ;引入lib库中的函数
;启动分页机制--------
SetupPaging:
  ;根据内存大小计算应初始化多少PDE以及多少页表
  xor edx, edx
  mov eax, [dwMemSize]  
  mov ebx, 400000h ;400000h = 4M = 4096*1024,一个页表对应的物理内存大小
  div ebx
  mov ecx, eax   ;此时ecx为页表的个数,也即PDE应该的个数
  test edx, edx  ;看下是否有余数,有余数则PDE个数多加一个
  jz   .no_remainder
  inc  ecx  ;余数不为0,页表的个数 + 1
.no_remainder:
  mov [PageTableNumber], ecx ;暂存页表个数,后面分页时要用
  
  ;初始化分页
  mov ax, SelectorFlatRW
  mov es, ax
  mov edi,PageDirBase0  ;
  xor eax,eax
  mov eax,PageTblBase0|PG_P|PG_USU|PG_RWW
.1:
  stosd
  add eax,4096 ;假设页表在内存中是连续的
  loop .1
  
  ;再初始化所有页表
  mov eax,[PageTableNumber];页表个数
  mov ebx,1024             ;每个页表1024个PTE
  mul ebx
  mov ecx,eax              ;PTE个数 = 页表个数*1024
  mov edi,PageTblBase0     ;此段首地址为PageTblBase0
  xor eax,eax  
  mov eax,PG_P|PG_USU|PG_RWW
.2:
  stosd
  add eax,4096
  loop .2
  mov eax, PageDirBase0
  mov cr3, eax
  mov eax, cr0
  or  eax, 80000000h  ;开启分页机制
  mov cr0, eax
  jmp short .3
.3:
  nop
  ret
;分页机制启动完毕----

;测试分页机制------
PagingDemo:
   mov ax,cs
   mov ds,ax
   ;mov ah,07h
   ;mov al,'h'
   ;mov [gs:(80*16+10)*2], ax
   mov ax,SelectorFlatRW
   mov es, ax
   
  
   
   push LenFoo
   push OffsetFoo
   push ProcFoo
   call MemCpy ;拷贝到一个物理页开始位置,好进行后面的实验
   add esp,12
   
   push LenBar
   push OffsetBar
   push ProcBar
   call MemCpy ;拷贝到一个物理页开始位置,好进行后面的实验
   add esp,12

   push LenPagingDemoAll
   push OffsetPagingDemoProc
   push ProcPagingDemo
   call MemCpy ;拷贝到一个物理页开始的位置,好进行后面的实验
   add esp,12
   
   mov ax, SelectorData
   mov ds, ax
   mov es, ax      ;数据段选择子
   
   call SetupPaging  ;启动分页
   
   call SelectorFlatC:ProcPagingDemo
   call PSwitch    ;切换页目录,改变地址映射关系
   call SelectorFlatC:ProcPagingDemo

   ret


;切换分页,修改线性地址指向的地址
PSwitch:
   ;初始化页目录
   mov ax, SelectorFlatRW ;主要在改变PTE指向的页表首地址时会用到
   mov es, ax
   
   mov eax,LinearAddrDemo
   shr eax,22
   mov ebx,4096
   mul ebx  ;定位到页表首地址
   mov ecx,eax
   mov eax,LinearAddrDemo
   shr eax,12
   and eax,03FFh
   mov ebx,4  ;页表内偏移地址
   mul ebx
   add eax,ecx ;算出PTE地址
   add eax,PageTblBase0;算出PTE的地址
   mov dword [es:eax], ProcBar|PG_P|PG_USU|PG_RWW ;强行让PTE指向0501000h,0501000h刚好是一个页表的首地址
   
   mov eax,PageDirBase0  ;重新加载分页的线性地址
   mov cr3,eax           ;将cr3重新赋值,以重新加载修改后的线性地址   
   jmp short .3
.3:
   nop
   ret

;-----------------------
PagingDemoProc:
OffsetPagingDemoProc equ PagingDemoProc - $$
   mov eax,LinearAddrDemo
   call eax
   retf
LenPagingDemoAll equ $-PagingDemoProc

foo:
OffsetFoo  equ foo-$$
  mov ah,0ch
  mov al,'F'
  mov [gs:((80*17+0)*2)], ax;屏幕第17行,第0列
  mov al,'o'
  mov [gs:((80*17+1)*2)], ax;屏幕第17行,第1列
  mov [gs:((80*17+2)*2)], ax;屏幕第17行,第2列
  ret
LenFoo equ $ - foo

bar:
OffsetBar equ bar - $$
  mov ah,0Ch
  mov al,'B'
  mov [gs:((80*18+0)*2)], ax;屏幕第18行,第0列
  mov al,'a' 
  mov [gs:((80*18+1)*2)], ax;屏幕第18行,第1列
  mov al,'r'
  mov [gs:((80*18+2)*2)], ax;屏幕第18行,第2列
  ret
LenBar equ $ - bar  
   
   
  
DispMemSize:
  push esi
  push edi
  push ecx
  
  mov esi,MemChkBuf
  mov ecx,[dwMCRNumber];每次得到一个ARDS,遍历内存结构数组

.loop:
   mov edx,5 ;每次得到ARDS中的一个成员
   mov edi,ADRStruct ;依次显示内存结构体中的成员

.1:
   push dword [esi]
   call DispInt  ;显示一个成员
   pop eax
   stosd  ;ADRStruct[j*4]=MemChkBuf[j*4]
   add esi,4
   dec edx
   cmp edx,0
   jnz  .1
   call DispReturn
   
   cmp dword [dwType],1; 看下内存是否可用
   jne .2
   mov eax,[dwBaseAddrLow]
   add eax,[dwLengthLow]
   cmp eax,[dwMemSize];
   jb  .2
   mov [dwMemSize],eax
.2:
   loop .loop
   call DispReturn
   push szRAMSize    ;显示内存大小标题
   call DispStr
   add esp,4
   push dword [dwMemSize]
   call DispInt 
   add esp,4
   pop ecx
   pop edi
   pop esi
   ret
SegCode32Len	equ	$ - LABEL_SEG_CODE32
; END of [SECTION .s32]

; 16 位代码段. 由 32 位代码段跳入, 跳出后到实模式
[SECTION .s16code]
ALIGN	32
[BITS	16]
LABEL_SEG_CODE16:
	; 跳回实模式:
	mov	ax, SelectorNormal
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax

	mov	eax, cr0
	and     eax, 11111110b          ;关闭保护模式
	mov	cr0, eax

LABEL_GO_BACK_TO_REAL:
	jmp	0:LABEL_REAL_ENTRY	; 段地址会在程序开始处被设置成正确的值

Code16Len	equ	$ - LABEL_SEG_CODE16

; END of [SECTION .s16code]
