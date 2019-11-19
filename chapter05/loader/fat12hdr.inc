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

;给予FAT12头的一些常量定义,可根据头信息进行适当的调整
FATSz equ 9
RootDirSectors equ 14    ;根目录占用14个扇区
SectorNoOfRootDirectory equ 19  ;Root Directory第一个扇区号
SectorNoOfFAT1 equ  1 ;FAT1的第一个扇区=BPB_RsvdSecCnt
DeltaSectorNo  equ  17 ;DeltaSectorNo=BPB_RsvdSecCnt+(BPB_NumFATS*FATs)-2 
                       ;文件的开始Sector号 = DirEntry中的开始Sector号 + 根目录占用Sector数目 + DeltaSectorNo
