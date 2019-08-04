_MemChkBuf: times 256 db 0
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

