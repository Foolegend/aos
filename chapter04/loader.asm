org 0100h
  mov ax, 0B800h
  mov gs, ax
  mov ah, 0Fh ;黑底,白字
  mov al, 'L' ;显示一个字符L
  mov [gs: ((80*0 + 39)*2)], ax;屏幕第0行,第39列
  jmp $  ;停住
