#include "disk.h"
#include "x86.h"
#include "stdio.h"
bool DISK_Initialize(DISK* disk, uint8_t driveNumber)
{
    uint8_t driveType;
    uint16_t cylinders, sectors, heads;

    if (!x86_Disk_GetDriveParams(driveNumber, &driveType, &cylinders, &sectors, &heads))
        return false;
    printf("%d : drive type \r\n", driveType);

    disk->id = driveNumber;
    disk->cylinders = cylinders + 1;
    disk->heads = heads + 1;
    disk->sectors = sectors;

    return true;
}
void DISK_LBA2CHS(DISK* disk, uint32_t lba, uint16_t* cylindersOut, uint16_t* sectorOut, uint16_t* headsOut)
{
    // sector      = ( LBA % sectors per track + 1 )
    *sectorOut     =  lba % disk->sectors + 1;

    // cylinder    = ( LBA / sectors per track ) / heads
    *cylindersOut  =  ( lba / disk->sectors ) / disk->heads;

    // heads   = ( LBA / sectors per track ) % heads
    *headsOut  =  ( lba / disk->sectors ) % disk->heads;
}



bool DISK_ReadSectors(DISK* disk, uint32_t lba, uint8_t sectors, uint8_t far* dataout)
{
    uint16_t cylinder, sector, head;
    
    DISK_LBA2CHS( disk, lba, &cylinder, &sector, &head );

    for (int i = 0; i < 3; i++)
    {
        if (x86_Disk_Read( disk->id, cylinder, sector, head, sectors, dataout ))
            return true;
        x86_Disk_Reset( disk->id );
    }
    
    return false;
}