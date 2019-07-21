DA_LDT EQU 82h;局部描述符表段类型值
DA_32  EQU 4000h ;32位段
DA_DRW		EQU	92h	; 存在的可读写数据段属性值
DA_DRWA		EQU	93h	; 存在的已访问可读写数据段类型值
DA_C  EQU  98h  ;存在的只执行代码段属性

DA_386CGate	EQU	  8Ch	; 386 调用门类型值
DA_386TSS	EQU	  89h	; 可用 386 任务状态段类型值

DA_DPL0		EQU	  00h	; DPL = 0
DA_DPL1		EQU	  20h	; DPL = 1
DA_DPL2		EQU	  40h	; DPL = 2
DA_DPL3		EQU	  60h	; DPL = 3

SA_RPL0         EQU       0h    ;RPL = 0
SA_RPL1         EQU       1h    ;RPL = 1
SA_RPL2         EQU       2h    ;RPL = 2
SA_RPL3         EQU       3h    ;RPL = 3

SA_TIG		EQU	0	; ┓TI
SA_TIL		EQU	4	; ┛

;描述符定义,传进来的参数会自动装到对应的字节中
;usage:Descriptor Base,Limit,Attr
%macro Descriptor 3
       dw %2&0FFFFh ;段界限1
       dw %1&0FFFFh ;段基址1
       db (%1>>16)&0FFh ;段基址2
       dw ((%2>>8)&0F00h)|(%3&0F0FFh) ;属性1 + 段界限2 + 属性2
       db (%1>>24)&0FFh ;段基址3
%endmacro ;共8个字节

;门描述符的宏定义
;usage:Gate Selector,Offset,DCount,Attr
;Selector: dw
;Offset: dd
;Dcount: db
;Attr: db
%macro Gate 4
     dw (%2 & 0FFFFh) ;偏移1
     dw %1 ;门代码段选择子
     dw (%3 & 1Fh) | ((%4<<8)&0FF00h) ;属性
     dw ((%2>>16) & 0FFFFh) ;偏移2
%endmacro ;共8个字节
