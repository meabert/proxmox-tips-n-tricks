<!-- lint-disable MD013 -->
![Docs Lint](https://github.com/meabert/proxmox-tips-n-tricks/actions/workflows/markdownlint.yml/badge.svg)

# Proxmox Tips & Tricks #

## Updated 10/26/2025 ##

Documenting the evolution of my homelab, this guide is not intended
to be a blanket solution or a one size fits all. The objective is
ultimately creating a unique resource that targets documenting nuanced
issues. The kind you Google and there's a bunch of forum posts with
questions but no answers.

> [!CAUTION]
> Everyone has different hardware, be sure to pay close attention
> to whether or not kernel flags apply to your CPU/GPU/HBA or
> whatever crazy nonsense particle accelerator is connected
> to your PCI slot.

## Objectives ##

Create a centralized repository for the inner workings of Proxmox,
Homelab tools and general Linux items that are directly related.

### What to install before starting ###

- A new Proxmox instance installed, booted and ready to go. Existing 
installs will also work just fine, however, I do not recommend testing these
changes on a live production server without ample testing. If your end goal 
is live production, please for ones own sanity get a lab or replica to break
before trying to roll this. The wrong boot flags can kill a system, literally.

- If you are new to Proxmox or Linux in general I strongly suggest you review
the official documentation before reading further:

> [Proxmox Official Documentation](https://pve.proxmox.com/pve-docs/) |
> [Admin Guide](https://pve.proxmox.com/pve-docs/pve-admin-guide.html)
> [QEMU/KVM Virtual Machines](https://pve.proxmox.com/pve-docs/chapter-qm.html) |
> [PCIe Passthrough](https://pve.proxmox.com/pve-docs/chapter-qm.html#qm_pci_passthrough) |
> [General Requirements](https://pve.proxmox.com/pve-docs/chapter-qm.html#_general_requirements) |
> [Host Device Passthrough](https://pve.proxmox.com/pve-docs/chapter-qm.html#_host_device_passthrough) |
> [SR-IOV](https://pve.proxmox.com/pve-docs/chapter-qm.html#_sr_iov) |
> [Mediated Devices](https://pve.proxmox.com/pve-docs/chapter-qm.html#_mediated_devices_vgpu_gvt_g) |
> [vIOMMU](https://pve.proxmox.com/pve-docs/chapter-qm.html#qm_pci_viommu)
> [Resource Mapping](https://pve.proxmox.com/pve-docs/chapter-qm.html#resource_mapping)

- Post-install script:


- Ensure apt is working with either the non-subscription or subscription repos:


- Optional: **Nala** - a drop in replacement for apt that enables parallel package
downloads and agile dependency resolution by way of verbose terminal output
of changes as they are made:



Nala is reminiscent of yum or dnf from CentOS/Fedora/Red Hat and can
be used as a replacement for apt:



```bash
sudo apt update && sudo apt install nala
```

Use nala in place of apt after it's installed, apt will remain in place if you
decide for whatever reason you like apt better. 

### CPU Scaling Governor ###

In order to get the desired functionality out of your setup the CPU governor
needs to match your workload and power expectations. I use on-demand for my
three nodes. The modes available vary widely depending on your CPU model,
it's age, if it has a p-state driver available. The cpupower command can
get you additional information about your CPU. This way make an informed
choice on the setting itself:

```bash
sudo apt update && sudo apt install linux-cpupower
```

```bash
sudo cpupower frequency-info
```

```bash
sudo cpupower frequency-set ondemand
```

```bash
sudo cpupower frequency-info
```

### Manually added packages ###

Adjust based on your hardware profiles:

<pre style="white-space: pre-wrap;">
apt install sudo iperf3 btop gcc make cmake automake autoconf build-essential
git unzip lm-sensors powertop htop btop pve-headers dkms devscripts debhelper
equivs nut nut-server nut-monitor ipmitool redfishtool nvme-cli
</pre>

## Hardware Provisioning for VM's ##

### PCI Express Passthrough ###

<p>This section covers how to enable vfio and passthrough a GPU,
test case has a hardware payload of NVIDIA RTX 4060 Ti and Broadcom
9400-16i HBA - please note this is for a full passthrough such as
for use in a virtual machine. Steps for running a GPU natively on
the host such as for containers is out of scope for this section
and different instructions should be used.</p>

Use case on the passthrough hardware:

GPU - Dedicated docker VM for LLMs, Transcoding and Rendering

HBA - TrueNAS - Storage Inventory - 12 Hard Disks (Data), 1 Optane for
L2ARC+SLOG, 6 SSD's (Metadata & Special Small Blocks) and three hot spares.

### Enable IOMMU in the bootloader ###

<p>Your mileage may vary with specific kernel boot flags, however
after testing across various devices to a custom built AMD Epyc server,
a converted gaming desktop and even some GMKTec NUC's. These are
the settings that have worked across the board for me.</p>

### Setting Kernel Boot Flags ###

> [!IMPORTANT]
> Make sure you update the right bootloader:
> systemdboot users should use proxmox-boot-tool<br>
> Grub users should shoud use update-grub

#### Kernel Admin Guide -  Boot Parameters ####

For documentation on what each boot flag is and the use case on when to use it
please refer to the offical kernel admin-guide for details:

##### Kernel.org #####

[Kernel - Admin Guide - Kernel Parameters](https://docs.kernel.org/admin-guide/kernel-parameters.html)

##### Github.com #####

[GitHub - Admin Guide - Kernel Parameters](https://github.com/torvalds/linux/blob/master/Documentation/admin-guide/boot.parameters.html)

> [!WARNING]
> Example bootflags are specific to my lab hardware, yours can and will likely
> be different. Due dilligence is required with any kernel flags and if you're
> not sure - refer to the offical kernel guides for your version.

### AMD Kernel Flags ###

For AMD IOMMU is enabled by default - simply make sure it is
enabled in the BIOS and add applicable kernel flags.

#### AMD systemd-boot ####

```bash
nano /etc/kernel/cmdline
```

```bash
root=ZFS=rpool/ROOT/pve-1 boot=zfs iommu=pt nomodeset vfio-pci.ids=10de:2803,10de:22bd vfio-pci.disable_idle_d3=1 video=vesafb:off video=efifb:off amd_pstate=guided transparent_hugepage=never hugepagesz=1G hugepages=16 hugepagesz=2M hugepages=2048
```

```bash
update-initramfs -u -k all && proxmox-boot-tool refresh
```

#### AMD GRUB ####

```bash
nano /etc/default/grub
```

```bash
GRUB_CMDLINE_LINUX_DEFAULT="iommu=pt nomodeset vfio-pci.ids=10de:2803,10de:22bd vfio-pci.disable_idle_d3=1 video=vesafb:off video=efifb:off amd_pstate=guided transparent_hugepage=never hugepagesz=1G hugepages=16 hugepagesz=2M hugepages=2048"
```

```bash
update-initramfs -u -k all && update-grub refresh
```

### Intel Kernel Flags ###

For Intel add applicable kernel flags to enable, also ensure
it is enabled in the BIOS.

#### Intel systemd-boot ####

```bash
nano /etc/kernel/cmdline
```

```bash
root=ZFS=rpool/ROOT/pve-1 boot=zfs quiet intel_iommu=on,relax_rmrr iommu=pt vfio-pci.disable_idle_d3=1 intremap=no_x2apic_optout i915.enable_hangcheck=0 intel_pstate=active default_hugepagesz=2MB hugepagesz=1G hugepages=16 hugepagesz=2M hugepages=2048
```

```bash
update-initramfs -u -k all && proxmox-boot-tool refresh
```

#### Intel GRUB ####

```bash
nano /etc/default/grub
```

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on,relax_rmrr iommu=pt vfio-pci.disable_idle_d3=1 intremap=no_x2apic_optout i915.enable_hangcheck=0 intel_pstate=active default_hugepagesz=2MB hugepagesz=1G hugepages=16 hugepagesz=2M hugepages=2048"
```

```bash
update-initramfs -u -k all && update-grub refresh
```

### Enable VFIO modules ###

```bash
echo "vfio" >> /etc/modules
echo "vfio_iommu_type1" >> /etc/modules
echo "vfio_pci" >> /etc/modules
```

> [!TIP]
> Don't forget - whenever making changes to boot related items always update
> the bootloader to finalize and apply the changes!

#### VFIO systemd-boot ####

```bash
update-initramfs -u -k all && proxmox-boot-tool refresh
```

#### VFIO GRUB ####

```bash
update-initramfs -u -k all && update-grub refresh
```

### Locate your PCI device ID's ###

#### GPU ####

In order to make the lspci output easier to read it's recommended to update
PCI ID's as they are updated frequently and will give names to devices that
otherwise may have ambiguous names:

```bash
update-pciids
```

List PCI devices:

```bash
lspci -nnk | grep 'NVIDIA'
```

43:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD106
[GeForce RTX 4060 Ti] <b>[10de:2803]</b> (rev a1) <br>

43:00.1 Audio device [0403]: NVIDIA Corporation AD106M High Definition
Audio Controller <b>[10de:22bd]</b> (rev a1)

#### Host Bus Adaper ####

```bash
lspci -nn | grep 'LSI'
```

02:00.0 Serial Attached SCSI controller [0107]: Broadcom / LSI SAS3416
Fusion-MPT Tri-Mode I/O Controller Chip (IOC) <b>[1000:00ac]</b> (rev 01)d

Now you can integrate these device ID's into the vfio configuration, note
that I've included two device ID's for the GPU - this is because one is for
video and the other for audio. Failure to include both can and will likely
cause issues.

### VFIO Configuration ###

> [!WARNING]
> The PCI ID's used in these example will likely not match your HBA or GPU
be sure to get the correct device ID utilizing the lspci command

```bash
echo "options vfio-pci ids=1000:00ac,10de:2803,10de:22bd" >> \
/etc/modprobe.d/vfio.conf
```

#### LSI or Broadcom HBA's ####

```bash
echo "softdep mpt3sas pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

#### NVIDIA GPU's - RTX, GeForce, Hopper, Ampere, Turing, Volta ####

```bash
echo "softdep nouveau pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep nvidia pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep nvidiafb pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep nvidia_modeset pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep nvidia_drm pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

##### HDMI Audio - NVIDIA GPU's #####

```bash
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

#### Dedicated - AMD GPU's ####

```bash
echo "softdep radeon pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep amdgpu pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep ccp pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep xhci_hcd pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

#### Integrated - Intel GPU's - iGPU ####

```bash
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep snd_hda_codec_hdmi pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep i915 pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep i2c_algo_bit pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

#### Dedicated - Intel GPU's - ARC ####

```bash
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep snd_hda_codec_hdmi pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep i915 pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep xe pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep i2c_algo_bit pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

### Blacklist Fallback - If VFIO Fails ###

#### NVIDIA Drivers ####

echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia_modeset" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidiafb" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia_drm" >> /etc/modprobe.d/blacklist.conf
echo "blacklist snd_hda_intel" >> /etc/modprobe.d/blacklist.conf
echo "blacklist snd_hda_codec_hdmi" >> /etc/modprobe.d/blacklist.conf

#### AMD Drivers ####

#### Intel iGPU Drivers ####

#### Intel ARC Drivers ####

```bash
echo "blacklist mpt3sas" >> /etc/modprobe.d/blacklist.conf
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
echo "blacklist amdgpu" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist ccp" >> /etc/modprobe.d/blacklist.conf
echo "blacklist xhci_hcd" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia_modeset" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidiafb" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia_drm" >> /etc/modprobe.d/blacklist.conf
echo "blacklist snd_hda_intel" >> /etc/modprobe.d/blacklist.conf
echo "blacklist snd_hda_codec_hdmi" >> /etc/modprobe.d/blacklist.conf
echo "blacklist i915" >> /etc/modprobe.d/blacklist.conf
echo "blacklist i2c_algo_bit" >> /etc/modprobe.d/blacklist.conf
echo "blacklist xe" >> /etc/modprobe.d/blacklist.conf
```

### Update initramfs and refresh bootloader ###

> [!TIP]
> Don't forget - whenever making changes to boot related items always update
> the bootloader to finalize and apply the changes!

#### Blacklist systemdboot ####

```bash
update-initramfs -u -k all && proxmox-boot-tool refresh
```

#### Blacklist Grub ####

```bash
update-initramfs -u -k all && update-grub refresh
```
