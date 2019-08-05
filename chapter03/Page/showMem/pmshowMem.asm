;;lib.inc
%include "pm.inc" ;常量,宏,以及一些说明
org 0100h
jmp LABEL_BEGIN
[SECTION .gdt]
; GDT      段基址,  段界限,   段属性
LABEL_GDT: Descriptor 0, 0, 0 ;空描述符
LABEL_DESC_STACK:Decriptor 0,  TopOfStack, DA_DRWA + DA_32 ;32位Stack
LABEL_DESC_VIDEO:Descriptor 0B8000h, 0ffffh, DA_DRW ;显存首地址
;GDT 结束

GdtLen equ $ - LABEL_GDT ;GDT长度
GdtPtr dw GdtLen - 1 ;GDT界限
       dd 0          ;GDT基地址
; GDT选择子

      
%include "lib.inc"
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
_dwDispPos: dd (80*6 + 0)*2
_dwMemSize dd 0
_ARDStruct:    ;Address Range Descriptor Structure
  _dwBaseAddrLow: dd 0
  _dwBaseAddrHigh: dd 0
  _dwLengthLow: dd 0
  _dwLengthHigh: dd 0
  _dwType: dd 0
_MemChkBuf: times 256 db 0

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

  jmp SelectorCode16:0 ;到此停止

DispMemSize:
  push esi
  push edi
  push ecx
  
  mov esi,MemChkBuf
  mov ecx,[dwMCRNumber];每次得到一个ARDS,遍历内存结构数组

.loop:
   mov edx,5 ;每次得到ARDS中的一个成员
   mov edi,ARDStruct ;依次显示内存结构体中的成员

.1:
   push dword [esi]
   call DispInt  ;显示一个成员
   pop eax
   stosd  ;ARDStruct[j*4]=MemChkBuf[j*4]
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
   add esp,4
   push dword [dwMemSize]
   call DispInt 
   add esp,4
   pop ecx
   pop edi
   pop esi
   ret

   call szMemChkTitle  ;显示内存结构标题
   call DispStr
   add esp,4
   call DispMemSize  ;显示内存信息
