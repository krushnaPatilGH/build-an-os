#include "stdint.h"
#include "stdio.h"

void _cdecl cstart_(uint16_t bootDrive){
    puts("hello world from c");
    for(;;);
}