;%define _BOOT_DEBUG_   ;做Boot Sector时一定将此行注释掉!
%ifdef _BOOT_DEBUG_
    org 0100h    ;调试时,编译成.COM文件时可以用
%else
    org 07c00h   ;Boot状态,Bios将把Boot Sector加载到0:7c00处并开始执行
%endif

%ifdef _Boot_DEBUG_
BaseOfStack  equ  0100h ;调试状态堆栈基地址
%else
BaseOfStack  equ  07c00h ;Boot状态堆栈基地址
%endif

BaseOfLoader   equ 09000h ;LOADER.BIN被加载到的位置---段地址
OffsetOfLoader equ 0100h ;LOADER.BIN 被加载到的位置---偏移地址

jmp short LABEL_START ;Start to boot.
nop 
%include "fat12hdr.inc"
;变量
wSectorNo           dw 0  ;要读取的扇区的号
bOdd                db 0  ;奇数还是偶数
wRootDirSizeForLoop dw RootDirSectors  ;RootDirector的总扇区

LoaderFileName     db "LOADER  BIN",0 ;LOADER.BIN之文件名
MessageLength      equ 9   ;每个字符串的长度设成固定的9个长度
BootMessage:       db "Booting  " 
Message1:          db "Ready.   "
Message2:          db "No Loader"

LABEL_START:
  mov ax, cs
  mov ds, ax
  mov es, ax
  mov ss, ax
  mov sp, BaseOfStack

  ;清屏
  mov ax, 0600h ;AH=6,AL=0h
  mov bx, 0700h ;黑底白字(BL=07h)
  mov cx, 0     ;左上角:(0,0)
  mov dx, 0184fh
  int 10h     ;10号中断
  mov dh, 0 ;"Booting "
  call DispStr  ;显示字符串
  
  xor ah, ah;
  xor dl, dl ;软驱复位
  int 13h

  ;下面在A盘的根目录寻找LOADER.BIN
  mov word [wSectorNo], SectorNoOfRootDirectory;Root目录区开始的位置
  
LABEL_SEARCH_IN_ROOT_DIR_BEGIN:
  cmp word [wRootDirSizeForLoop], 0 ;根目录未读的扇区的个数是否只剩下0个了
  jz  LABEL_NO_LOADERBIN ;没找到
  dec word [wRootDirSizeForLoop]  ;每遍历一次,根目录未读扇区少一个
  mov ax, BaseOfLoader
  mov es, ax
  mov bx, OffsetOfLoader
  mov ax, [wSectorNo]    ;要读取的扇区号
  mov cl, 1   ;读取一个扇区
  call ReadSector  ;将一个扇区中的数据读入到es:bx指向的位置
  mov si, LoaderFileName  ;ds:si指向文件名"LOADER BIN"
  mov di, OffsetOfLoader
  cld
  mov dx, 10h  ;每个目录项32字节,因此一个扇区有16个项
LABEL_SEARCH_FOR_LOADERBIN:
  cmp dx, 0 ;看下32个字节是否读取完了
  jz LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR  ;当前目录项遍历完了,遍历该扇区中下一个目录项
  dec dx  ;每读取一个字节,减1
  mov cx, 11  ;LOADER BIN是11个字节
LABEL_CMP_FILENAME:
  cmp cx, 0
  jz LABEL_FILENAME_FOUND ;如果比较了11个字符都相等,表示找到了
  dec cx
  lodsb  ;从ds:si指向的地址读取字符串,每次读取一个字节
  cmp al, byte [es:di]
  jz LABEL_GO_ON
  jmp LABEL_DIFFERENT ;只要发现不一样的字符表明当前目录项不是自己想要的
LABEL_GO_ON:
  inc di
  jmp LABEL_CMP_FILENAME ;循环遍历,将文件名中11个字符遍历完
LABEL_DIFFERENT:
  and di,0FFE0h  ;找不到将di指向当前目录项的起始地址处,
                 ;因为每个目录项占32字节,因此目录项起始地址的最后5位二进制位为0
  add di,20h     ;指向下一个目录项
  mov si,LoaderFileName ;看下一个目录项中是否是想要的文件
  jmp LABEL_SEARCH_FOR_LOADERBIN 
LABEL_GOTO_NEXT_SECTOR_IN_ROOT_DIR:
  add word [wSectorNo], 1 ;读取下一个扇区
  jmp LABEL_SEARCH_IN_ROOT_DIR_BEGIN
LABEL_NO_LOADERBIN:
  mov dh, 2 ;没有找到,显示数组中第2个字符串
  call DispStr    ;显示字符串
%ifdef _BOOT_DEBUG_
  mov ax, 4c00h
  int 21h  ;回到dos
%else
  jmp $  ;到这里停止
%endif 

LABEL_FILENAME_FOUND:  ;找到LOADER.BIN后便开始加载这个文件
  mov ax, RootDirSectors
  and di, 0FFE0h ;di->当前目录条目的开始地址(即LOADER.BIN文件的目录项)
  add di, 01Ah   ;di->移动到目录项中,首蔟所在的位置中
  mov cx, word [es:di]
  push cx    ;将首蔟在FAT中的序号压入堆栈
  add cx, ax
  add cx, DeltaSectorNo ;cl<-LOADER.BIN的起始扇区号
  mov ax, BaseOfLoader
  mov es, ax       
  mov bx, OffsetOfLoader ;数据会加载到BaseOfLoader:OffsetOfLoader指定的位置处
  mov ax, cx   ;ax<- 读取数据的起始Setctor号

LABEL_GOON_LOADING_FILE:
  push ax  
  push bx
  mov ah, 0Eh
  mov al, '.'
  mov bl, 0Fh  ;/Booting......
  int 10h   ;
  pop bx
  pop ax
  
  mov cl, 1
  call ReadSector
  pop ax     ;取出此Sector在FAT中的扇区号
  call GetFATEntry  ;获取下一个扇区号,保存到ax中
  cmp ax, 0FFFh
  jz  LABEL_FILE_LOADED
  push ax  ;保存Sector在FAT中的序号
  mov  dx, RootDirSectors
  add  ax, dx
  add  ax, DeltaSectorNo
  add  bx, [BPB_BytsPerSec] ;es:bx偏移512字节,用来存储下一个扇区
  jmp  LABEL_GOON_LOADING_FILE

LABEL_FILE_LOADED:
  mov dh, 1
  call DispStr  ;显示字符串
  
  jmp BaseOfLoader: OffsetOfLoader ;这一句正式跳转到已加载到内存中LOADER.BIN的开始处,开始执行LOADER.BIN的代码
  ;Boot Sector的使命到此结束
DispStr:
  mov ax,MessageLength
  mul dh
  add ax,BootMessage
  mov bp, ax
  mov ax, ds
  mov es, ax  ;es:bp指向字符串地址
  mov cx, MessageLength 
  mov ax, 01301h ;AH=13h,AL=01h 
  mov bx, 0007h  ;页号0(BH=0),黑底白字(BL=07h)
  mov dl, 0
  int 10h   ;用10号中断显示字符串
  
  ret

GetFATEntry:
  push es
  push bx
  push ax
  mov  ax, BaseOfLoader
  sub  ax, 0100h ;基地址后移,腾出4k空间用来读取LOADER.BIN数据
  mov  es, ax
  pop  ax  ;ax为蔟号
  mov  byte [bOdd], 0
  mov  bx, 3
  mul  bx   ;ds:ax*3
  mov  bx, 2
  div  bx  ;ds:ax*3/2  指向的是一个蔟的起始地址字节
  cmp  dx,0
  jz   LABEL_EVEN
  mov  byte [bOdd], 1
LABEL_EVEN: ;偶数
  xor dx, dx
  mov bx, [BPB_BytsPerSec]
  div bx  ; 商ax对应于FAT扇区号,余数dx对应扇区中的偏移字节数
  push dx
  mov  bx,0 ;es:bx=(BaseOfLoader-100):00
  add  ax,SectorNoOfFAT1 ;此句之后的ax就是FATEntry所在的扇区号
  mov  cl,2
  call ReadSector ;读取FATEntry所在的扇区,一次读取两个,避免在边界发生错,
                  ;因为一个FATEntry可能跨越两个扇区(512/12有余数)
  pop dx
  add bx,dx  ;指向扇区偏移地址
  mov ax,[es:bx] ;
  cmp byte [bOdd], 1
  jnz  LABEL_EVEN_2
  shr ax,4   ;若是奇数,则取2个字节的的高12位
LABEL_EVEN_2:
  and ax, 0FFFh  ;若是偶数,则取2个字节的低12位
LABEL_GET_FAT_ENRY_OK:
  pop bx
  pop es
  ret
ReadSector:
  push bp
  mov  bp, sp
  sub  esp, 2  ;堆栈中留两个字节区域存储要读取的扇区书目
  
  mov  byte [bp-2], cl ;cl为要读取的扇区数目
  push bx      ;保存bx,下面要给int 13h中断用
  mov  bl, [BPB_SecPerTrk] ;每个磁道的扇区数
  div  bl   ;扇区编号:是按照柱面,磁头,磁道内扇区偏移的顺序编号的
            ;ax=2*柱面*bl + 磁头*bl + 扇区偏移   
  inc  ah  ; 余数在ah中,代表扇区偏移
  mov  cl, ah ;磁道内扇区偏移
  mov  dh, al ;商在al中2*柱面(最右边一位肯定为0)
              ; + 磁头(只有两个磁头,所以此值最多为1)
  shr  al, 1  ;向右平移一位则得到柱面号  
  mov  ch, al ;柱面号
  and  dh, 1 ;商 & 1得到磁头号
  pop  bx    ;用完之后,将bx中的值还原回去
             ;柱面好,磁头号,起始扇区号 给int 13h赋值好了
  mov  dl, [BS_DrvNum] ;驱动器号赋好值,用来读取数据
.GoOnReading:
  mov ah, 2 ;2类型代表int 13h是读取操作
  mov al, byte [bp-2] ;读al个扇区
  int 13h             ;读取数据放到[es:bx]指向的地址中
  jc  .GoOnReading ;如果读取错误 CF会被置1,然后重新读取
  add esp, 2
  pop bp
  ret
  
times 	510-($-$$)	db	0	; 填充剩下的空间，使生成的二进制代码恰好为512字节
dw 	0xaa55				; 结束标志 
