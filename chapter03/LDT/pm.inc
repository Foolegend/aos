DA_LDT EQU 82h;局部描述符表段类型值
DA_32  EQU 4000h ;32位段
DA_DRW		EQU	92h	; 存在的可读写数据段属性值
DA_DRWA		EQU	93h	; 存在的已访问可读写数据段类型值
DA_C  EQU  98h  ;存在的只执行代码段属性

DA_DPL1		EQU	  20h	; DPL = 1

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
