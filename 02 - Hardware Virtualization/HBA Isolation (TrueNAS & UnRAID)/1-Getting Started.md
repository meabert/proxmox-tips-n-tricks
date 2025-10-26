# HBA Isolation - NAS Systems #
<!-- markdownlint-disable -->
[![pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](https://github.com/pre-commit/pre-commit)
<!-- markdownlint-enable -->
## 1 - Getting Started ##

### HBA Isolation - Giving the VM full control of the hardware ###

<p>Quick background - we will be using a Broadcom 9400-16i for this exercise, as
a bonus I already have an existing array for demonstration. Essentially we are
taking the bare metal TrueNAS installation I have now in my homelab and we will
be virtualizing it. Keep in mind there may be some additional steps required
depending on your hardware, this is a general overview using one of the most
common types of cards.</p>

> [!WARNING]
> Always have your storage array planned and tested before you ever roll it into
> production! Your personal planning and integrity are a direct reflection of
> the very same data integrity! Lastly for goodness sakes, RAID is NOT a backup!

## Dual RaidZ2 Array:<br/> ##

### Each VDEV (Virtual Device) has a two drive failure threshold ###

<p>This means you can lose two drives in each VDEV in the combined array (a
total of four
assuming one is that lucky) however as a consequence this is 32TB of sacrificed
space for integrity. However this nonetheless ultimately gives us 64TB of some
high throughput storage space - especially considering these are spinning rust,
additionally there are two 256GB NVMe drives for the ZFS Intent Log and finally
one 1.5TB Intel Optane drive for a modified L2ARC which is tuned more for
holding metadata vs actual data - this functions similar to a metadata
VDEV without the complications and insane risk that comes with operating a
"special VDEV". Normally if you have a metadata VDEV it can be dangerous because
if you lose that VDEV you lose the entire array, whereas the L2ARC can be added
and pulled at will with no impact to the data integrity.</p>

## ZFS VDEV Types ##

**Mirror:** Highest integrity, largest space loss - usually in pairs of two,su
three or more the data is the same on all drives in the pool.

### ZFS Lab Pool ###

#### HDD - Data Disks ####

| Mirror-0 | Mirror-1 | Mirror-2 | Mirror-3 | Mirror-4 | Mirror-5 |
| --- | --- | --- | --- | --- | --- |
| 8TB HDD |  8TB HDD |  8TB HDD |  8TB HDD |  8TB HDD |  8TB HDD |
| 8TB HDD |  8TB HDD |  8TB HDD |  8TB HDD |  8TB HDD |  8TB HDD |

#### SSD - Metadata Disks ####

| Mirror-0 | Mirror-1 | Mirror-3 |
| --- | --- | --- |
| 1TB SSD | 1TB SSD | 1TB SSD |
| 1TB SSD | 1TB SSD | 1TB SSD |

#### Optane - SLOG+L2ARC ####

| L2ARC | SLOG |
| --- | --- |
| 1.5TB SSD | 1.5TB SSD |

#### Hot Spares ####

| Data | Metadata |
| --- | --- |
| 8TB HDD | 1TB SSD |
| ------- | 1TB SSD |
