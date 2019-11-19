[section .text]
global _start ;导出_start

_start:  ;跳到这里来的时候,我们假设gs指向显存
   mov ah, 0Fh ;黑底白字
   mov al, 'K'
   mov [gs:(80*1 + 39)*2], ax ;屏幕(1,39)写K
   jmp $
