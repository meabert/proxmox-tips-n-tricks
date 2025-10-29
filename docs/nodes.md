# Homelab Proxmox Nodes #

## Selene 

- AMD Epyc 7513
- 256GB DDR4

### ZFS Pool ###

graph TD
  subgraph Data VDEVs
    D0["Mirror-0: 8TB HDD + 8TB HDD"]
    D1["Mirror-1: 8TB HDD + 8TB HDD"]
    D2["Mirror-2: 8TB HDD + 8TB HDD"]
    D3["Mirror-3: 8TB HDD + 8TB HDD"]
    D4["Mirror-4: 8TB HDD + 8TB HDD"]
    D5["Mirror-5: 8TB HDD + 8TB HDD"]
  end

  subgraph Metadata VDEVs
    M0["Mirror-0: 1TB SSD + 1TB SSD"]
    M1["Mirror-1: 1TB SSD + 1TB SSD"]
    M2["Mirror-2: 1TB SSD + 1TB SSD"]
  end

  subgraph Cache Devices
    C1["SLOG: 1.5TB Optane"]
    C2["L2ARC: 1.5TB Optane"]
  end

  subgraph Hot Spares
    S1["8TB HDD"]
    S2["1TB SSD"]
    S3["1TB SSD"]
  end


High-performance compute and storage node built on an AMD EPYC 7513 (32-core) with 256 GB ECC RAM and dual GPUs  
(NVIDIA RTX 4060 Ti + ASPEED). It uses VFIO passthrough for a Broadcom 9400-16i HBA connected to 12× 8TB IronWolf  
drives. ZFS is configured locally on Proxmox as a six-vdev mirror RAID (2-wide), with three additional 2-wide SSD  
metadata vdevs. Intel Optane drives are used for both SLOG and L2ARC, improving sync write performance and read  
caching for high-IO workloads.

## Pandorum
High-speed NVMe node built on a Minisforum MS-01 with an Intel Core i5-12600H and 96 GB RAM. All storage is
NVMe-based, including the PCIe slot via adapter, allowing for dense, low-latency workloads. This node also hosts
multiple USB-connected Seagate externals, serving as an “escape pod” for emergency recovery, offsite sync, and cold
storage. It’s optimized for fast I/O and flexible backup workflows, with minimal overhead and clean topology.

## Nyx  
Fallback and orchestration node built on a SuperMicro X11SCL-F with a Xeon E-2236 and 128 GB ECC RAM. It uses a
Broadcom 9400-16e HBA connected to NetApp DS4246 and DS2246 expanders, supporting legacy SAS workloads and archival
storage. The boot drive is a SATA SSD in NVMe form factor — bandwidth-limited but stable. Nyx handles server
monitoring, orchestration tasks, and critical data backups. Despite being the oldest node in the cluster, it
remains the most adaptable, with broad compatibility and a proven track record for recovery scenarios

While some configurations push the edge (firmware, kernel flags, VFIO), others focus on onboarding clarity, contributor
safety, and long-term maintainability. This repo is designed to be both technically rigorous and approachable — useful
for homelabbers, but presentable for professional review.