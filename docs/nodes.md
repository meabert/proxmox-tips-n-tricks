# Homelab Proxmox Nodes #

## Selene - Primary Node ##

- AMD Epyc 7513
- Gigabyte MZ32-AR0 - Integrated ASPEED GPU
- 256GB (32GB x 8) DDR4 ECC Registered RAM
- NVIDIA GeForce RTX 4060 Ti
- Mellanox ConnectX-5 OCP 2.0 - Dual 25Gb SFP+
- Broadcom 9400-16i - SFF 8643 - Tri-Mode
- 1.5TB Intel Optane 905p (x1)
- 8TB Seagate Ironwolf Pro (x12)
- 1TB SATA SSD's (x8)
- Silverstone RM61-3212

High-performance compute and storage node powered by an AMD EPYC 7513 (32-core) and 256 GB ECC RAM. For GPU tasks an
NVIDIA 4060 Ti 16GB GPU is passed through via VFIO to a dedicated VM, reserved exclusively for tasks that benefit from
hardware acceleration. This includes everything from AI inference and video transcoding to 3D rendering, cryptographic
operations, scientific simulations, and real-time password entropy analysis.

While this setup uses a single GPU, it’s designed with scalability in mind. You can scale horizontally by adding more
GPU-backed VMs across nodes, or scale vertically with container orchestration platforms like Docker Swarm or 
Kubernetes — assuming sufficient technical knowledge, hardware budget, and power envelope. ZFS is configured locally 
on Proxmox as a six-vdev mirror RAID (2-wide), with three additional 2-wide SSD metadata vdevs. Intel Optane drives are
used for both SLOG and L2ARC, improving sync write performance and read caching for high-IO workloads.

The mirror layout was chosen after years of daily use, benchmarking, and workload tuning. Everyone’s use case is 
different, but in my scenario, spinning rust still handles some VM activity — the rest lives on fast flash. The 
six-mirror layout helps bridge the performance gap between SSDs and HDDs in a hybrid pool.

Using multiple mirrors serves two purposes:

- It gives ZFS more vdevs to stripe across in parallel, avoiding the IOPS penalty of parity math in RAIDZ.

- It sidesteps the RAIDZ dilemma: either build one large vdev (limited to the speed of a single drive) or multiple
RAIDZ vdevs (where throughput scales only by vdev count).

The previous config used two RAIDZ2 vdevs, which topped out around 210–285 MB/s per vdev (420–570 MB/s total). With the
optimized multi-mirror layout, I now see ~1200 MB/s, fully saturating my 10 GbE network — with headroom to spare, since
both Selene and Nyx are trunked at 25 Gb.

As a former TrueNAS user, this shift was both a performance and preference-driven decision. While TrueNAS offers
excellent features for multi-user environments, I don’t manage thousands of accounts and prefer the surgical precision
of the command line. 

That led me to remove my HBA from VFIO passthrough and let Proxmox handle it natively. The result? A measurable and
very welcomed performance gain — from ~800 MB/s in a TrueNAS VM to ~1200 MB/s natively on Proxmox. Your mileage may 
vary, but for my setup, the benefits were clear: better throughput, simpler access for LXCs, and faster NFS via direct
large packet size aka MTU 9000<sup>1</sup> or aka Jumbo Frames.<sup>1</sup>

> “Just because you can virtualize something doesn’t necessarily mean you should.”
> - Operator Note

### ZFS Pool ###

#### HDD - Data Disks ####

| Mirror-0 | Mirror-1 | Mirror-2 | Mirror-3 | Mirror-4 | Mirror-5 |
| --- | --- | --- | --- | --- | --- |
| 8TB HDD |  8TB HDD |  8TB HDD |  8TB HDD |  8TB HDD |  8TB HDD |
| 8TB HDD |  8TB HDD |  8TB HDD |  8TB HDD |  8TB HDD |  8TB HDD |

#### SSD - Metadata Disks ####

| Mirror-0 | Mirror-1 | Mirror-2 |
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

### Footnotes

<sup>1</sup> MTU 9000 refers to Jumbo Frames — larger Ethernet packets that reduce CPU overhead and improve throughput
for high-bandwidth transfers like NFS or iSCSI. Especially useful when saturating 10GbE or higher links.

## Pandorum ##

High-speed NVMe node built on a Minisforum MS-01 with an Intel Core i5-12600H and 96 GB RAM. All storage is
NVMe-based, including the PCIe slot via adapter, allowing for dense, low-latency workloads. This node also hosts
multiple USB-connected Seagate externals, serving as an “escape pod” for emergency recovery, offsite sync, and cold
storage. It’s optimized for fast I/O and flexible backup workflows, with minimal overhead and clean topology.

## Nyx ##

Fallback and orchestration node built on a SuperMicro X11SCL-F with a Xeon E-2236 and 128 GB ECC RAM. It uses a
Broadcom 9400-16e HBA connected to NetApp DS4246 and DS2246 expanders, supporting legacy SAS workloads and archival
storage. The boot drive is a SATA SSD in NVMe form factor — bandwidth-limited but stable. Nyx handles server
monitoring, orchestration tasks, and critical data backups. Despite being the oldest node in the cluster, it
remains the most adaptable, with broad compatibility and a proven track record for recovery scenarios

While some configurations push the edge (firmware, kernel flags, VFIO), others focus on onboarding clarity, contributor
safety, and long-term maintainability. This repo is designed to be both technically rigorous and approachable — useful
for homelabbers, but presentable for professional review.
