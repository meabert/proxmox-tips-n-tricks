# 1 - Getting Started #

## HBA Isolation - Giving the VM full control of the hardware ##

<p>Quick background - we will be using a Broadcom 9400-16i for this exercise, as a bonus I
already have an existing array for demonstration. Essentially we are taking the bare metal
TrueNAS installation I have now in my homelab and we will be virtualizing it. Keep in mind
there may be some additional steps required depending on your hardware, this is a general
overview using one of the most common types of cards.</p>

> [!WARNING]
> Always have your storage array planned and tested before you ever roll it into production!
> Your personal planning and integrity are a direct reflection of the very same data integrity!
> Lastly for goodness sakes, RAID is NOT a backup!

## Dual RaidZ2 Array:<br/> ##

### Each VDEV (Virtual Device) has a two drive failure threshold ###

<p>This means you can lose two drives in each VDEV in the combined array (a total of four
assuming one is that lucky) however as a consequence this is 32TB of sacrificed space for
integrity. However this nonetheless ultimately gives us 64TB of some high throughput storage
space - especially considering these are spinning rust, additionally there are two 256GB NVMe
drives for the ZFS Intent Log and finally one 1.5TB Intel Optane drive for a modified L2ARC
which is tuned more for holding metadata vs actual data - this functions similar to a metadata
VDEV without the complications and insane risk that comes with operating a "special VDEV".
Normally if you have a metadata VDEV it can be dangerous because if you lose that VDEV you
lose the entire array, whereas the L2ARC can be added and pulled at will with no impact to
the data integrity. Again this isn't a ZFS lesson but adding context here in case anyone is
interested what a functioning setup looks like and how to set it up. </p>

## ZFS VDEV Types ##

<p>**Mirror:** Highest integrity, largest space loss - usually in pairs of two, three or more
 the data is the same on all drives in the pool.

### Vault VDEV ###

| RaidZ2 VDEV1 6xHDD Drives | RaidZ2 VDEV2 6xHDD Drives |    Parity   |
| ------------------------- | ------------------------- | ----------- |
| 8TB Seagate IronWolf SATA | 8TB Seagate IronWolf SATA |  Data Disk  |
| 8TB Seagate IronWolf SATA | 8TB Seagate IronWolf SATA |  Data Disk  |
| 8TB Seagate IronWolf SATA | 8TB Seagate IronWolf SATA |  Data Disk  |
| 8TB Seagate IronWolf SATA | 8TB Seagate IronWolf SATA |  Data Disk  |
| 8TB Seagate IronWolf SATA | 8TB Seagate IronWolf SATA | Parity Disk |
| 8TB Seagate IronWolf SATA | 8TB Seagate IronWolf SATA | Parity Disk |
| ------------------------- | ------------------------- | ----------- |
|                           |                           |
|                           |                           |
|                           |                           |
|                           |                           |
|                           |                           |
| 3400R / 2119W Block IOPS  | 3400R / 2200W Block IOPS  |
| ------------------------- | ------------------------- |
| ------------------------- | ------------------------- |
| ZIL LOG VDEV3 Write Cache |  L2ARC VDEV4 (Read Cache) |
| ------------------------- | ------------------------- |
| 256GB Samsung PM981a NVMe | Intel Optane 905p 1.5TB   |
| 256GB Samsung PM981a NVMe | NGFF U.2 NVMe Drive       |
| PCI-Express 3.0 x 4       | PCI-Express 3.0 x 4       |
|                           |                           |
|                           |                           |
| 2200MB/s Write Speed      | 2600MB/s Read Speed       |
| ------------------------- | ------------------------- |
|                           |                           |
|                           |                           |
|                           |                           |
| 2200MB/s Write Speed      | 2600MB/s Read Speed       |
| 150 TBW/MTBF 1.5 Million  | 27PBW / MTBF 1.6 Million  |
| 480,000 Random Write IOPS | 575,000 Random Read IOPS  |
| ------------------------- | ------------------------- |
|  Spare VDEV5 (Hot-Spare)   |
| -------------------------- |
| 8TB Seagate IronWolf SATA  |
|                            |  
|                            |
|                            |
|                            |
|                            |
| -------------------------- |
|                            |
|                            |
|                            |
|                            |
|                            |
|                            |
| -------------------------- |
| -------------------------- |