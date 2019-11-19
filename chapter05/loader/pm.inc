DA_32  EQU 4000h ;32位段
DA_LIMIT_4K	EQU	8000h	; 段界限粒度为 4K 字节

DA_DPL0		EQU	  00h	; DPL = 0
DA_DPL1		EQU	  20h	; DPL = 1
DA_DPL2		EQU	  40h	; DPL = 2
DA_DPL3		EQU	  60h	; DPL = 3
;----------------------------------------------------------------------------
; 选择子类型值说明
; 其中:
;       SA_  : Selector Attribute

SA_RPL0		EQU	0	; ┓
SA_RPL1		EQU	1	; ┣ RPL
SA_RPL2		EQU	2	; ┃
SA_RPL3		EQU	3	; ┛

SA_TIG		EQU	0	; ┓TI
SA_TIL		EQU	4	; ┛
;----------------------------------------------------------------------------
; 存储段描述符类型值说明
;----------------------------------------------------------------------------
DA_DR		EQU	90h	; 存在的只读数据段类型值
DA_DRW		EQU	92h	; 存在的可读写数据段属性值
DA_DRWA		EQU	93h	; 存在的已访问可读写数据段类型值
DA_C		EQU	98h	; 存在的只执行代码段属性值
DA_CR		EQU	9Ah	; 存在的可执行可读代码段属性值
DA_CCO		EQU	9Ch	; 存在的只执行一致代码段属性值
DA_CCOR		EQU	9Eh	; 存在的可执行可读一致代码段属性值



;描述符定义,传进来的参数会自动装到对应的字节中
;usage:Descriptor Base,Limit,Attr
%macro Descriptor 3
       dw %2&0FFFFh ;段界限1
       dw %1&0FFFFh ;段基址1
       db (%1>>16)&0FFh ;段基址2
       dw ((%2>>8)&0F00h)|(%3&0F0FFh) ;属性1 + 段界限2 + 属性2
       db (%1>>24)&0FFh ;段基址3
%endmacro ;共8个字节
