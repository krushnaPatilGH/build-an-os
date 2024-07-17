#include <stdint.h>
#include "stdio.h"
#include "memory.h"
#include <hal/hal.h>

extern uint8_t __bss_start;
extern uint8_t __end;

void __attribute__((section(".entry"))) start(uint16_t bootDrive)
{
    memset(&__bss_start, 0, (&__end) - (&__bss_start));

    HAL_INITITALIZE();

    clrscr();

    printf("Hello world from kernel!!!\n");
    __asm("int $0x2");
    printf("Hello world from kernel!!!\n");
    __asm("int $0x3");
    printf("Hello world from kernel!!!\n");
    __asm("int $0x4");
    printf("Hello world from kernel!!!\n");
    __asm("int $0x5");
end:
    for (;;);
}