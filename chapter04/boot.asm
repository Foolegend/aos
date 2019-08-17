jmp short LABEL_START ;Start to boot.
nop 
BS_OEMName     DB 'ForrestY' ;OEM String,必须8个字符
BPB_BytsPerSec DW 512;每个扇区的字节数
BPB_SecPerClus DB 1 ;每蔟多少个扇区
BPB_RsvdSecCnt DW 1;Boot记录占用多少扇区
BPB_NumFATs    DB 2;共有多少FAT表
BPB_RootEntCnt DW 224 ;根目录文件数最大值
BPB_TotSec16   DW 2880;逻辑扇区总数
BPB_Media      DB 0xF0;媒体描述符
BPB_FATSz16    DW 9;每FAT扇区数
BPB_SecPerTrk  DW 18 ;每磁道扇区数
BPB_NumHeads   DW 2 ;磁头数
BPB_HiddSec    DD 0 ;隐藏扇区数
BPB_TotSec32   DD 0 ;wTotalSectorCount为0时这个值记录扇区数
BS_DrvNum      DB 0 ;中断13的驱动器号
BS_Reserved1   DB 0 ;未使用
BS_BootSig     DB 29h ;扩展引导标记(29h)
BS_VolID       DD 0   ;卷序列号
BS_VolLab      DB 'OrangeS0.02' ;卷标,必须11个字节
BS_FileSysType DB 'FAT12   ' ;文件系统类型,必须8个字节

LABEL_START:

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
  int 13h
  
  
