#pragma once

// 0x00000000 - 0x000003FF  Interrupt vector table  1 KiB
// 0x00000400 - 0x000004FF  BDA (BIOS data area)    256 bytes
// 0x00000500 - 0x00007BFF  Conventional memory     26.75           (stack)
// 0x00007C00 - 0x00007DFF  Bootloader area         512 bytes       (our bootloader)
// 0x00007E00 - 0x0007FFFF  Conventional memory     480.5 KiB       (Kernel area)

#define MEMORY_MIN      0x00000500
#define MEMORY_MAX      0x00080000

// 0x00000500 - 0x00010500  FAT driver
#define MEMORY_FAT_ADDR  ((void far*) 0x00500000 )                  // segment:offset (SSSS:0000)
#define MEMORY_FAT_SIZE  0x00010000

// 0x00020000 - 0x00030000  stage 2

// 0x00030000 - 0x00080000 free

// 0x00080000 - 0x0009FFFF  Extended BIOS DATA area 128KiB
// 0x000A0000 - 0x000BFFFF  Video diaplay memory    128KiB
// 0x000C0000 - 0x000C7FFF  Video BIOS              32KiB
// 0x000C8000 - 0x000EFFFF  BIOS expansions         160KiB
// 0x000F0000 - 0x000FFFFF  Motherboard BIOS        64KiB