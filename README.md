<!-- lint-disable MD013 -->

# Documentation - Updated 10/6/2025 #

Documenting the evolution of my homelab, this guide is not intended
to be a blanket solutionn or a one size fits all. The objective is
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

- A proxmox instance that is already, installed, booted and ready to go.
- Recommend running some form of post-install script or your own process
- Ensure apt is working with either the non-subscription or subscription repos
- Optional: I like nala as my apt frontend as it supports parallel downloads:

```bash
sudo apt update && sudo apt install nala
```

### CPU Scaling Governor ###

This will widely depend on your CPU, it's age, if it has a p-state driver.
Bottom line make sure you have it on the desired govenor and if applicable
the right p-state driver.

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

GPU - Dedicated docker VM for LLM, Transcoding and Rendering

HBA - Fully virtualized TrueNAS with 12 drive RaidZ2

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
> [!WARNING]
> Example bootflags are specific to my lab hardware, yours can and will likely
> be different. Due dilligence is required with any kernel flags and if you're
> not sure - refer to the offical kernel guides for your version.

### AMD Kernel Flags ###

For AMD IOMMU is enabled by default - simply make sure it is
enabled in the BIOS and add applicable kernel flags.

#### AMD systemdboot ####

```bash
nano /etc/kernel/cmdline
```

```bash
root=ZFS=rpool/ROOT/pve-1 boot=zfs iommu=pt nomodeset vfio-pci.ids=10de:2803,10de:22bd vfio-pci.disable_idle_d3=1 video=vesafb:off video=efifb:off amd_pstate=guided transparent_hugepage=never hugepagesz=1G hugepages=16 hugepagesz=2M hugepages=2048
```

```bash
update-initramfs -u -k all && proxmox-boot-tool refresh
```

#### AMD Grub ####

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

#### Intel systemdboot ####

```bash
nano /etc/kernel/cmdline
```

```bash
root=ZFS=rpool/ROOT/pve-1 boot=zfs quiet intel_iommu=on,relax_rmrr iommu=pt vfio-pci.disable_idle_d3=1 intremap=no_x2apic_optout i915.enable_hangcheck=0 intel_pstate=active default_hugepagesz=2MB hugepagesz=1G hugepages=16 hugepagesz=2M hugepages=2048
```

```bash
update-initramfs -u -k all && proxmox-boot-tool refresh
```

#### Intel Grub ####

```bash
nano /etc/default/grub
```

```bash
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on,relax_rmrr iommu=pt vfio-pci.disable_idle_d3=1 intremap=no_x2apic_optout i915.enable_hangcheck=0 intel_pstate=active default_hugepagesz=2MB hugepagesz=1G hugepages=16 hugepagesz=2M hugepages=2048"
```

```bash
update-initramfs -u -k all && update-grub refresh
```

##### Kernel Admin Guide -  Boot Parameters #####

```text
<https://github.com/torvalds/linux/blob/master/Documentation/admin-guide/>
```

#### Enable the vfio modules ####

```bash
echo "vfio" >> /etc/modules
echo "vfio_iommu_type1" >> /etc/modules
echo "vfio_pci" >> /etc/modules
```

**Update the bootloader**

Systemdboot

```bash
update-initramfs -u -k all && proxmox-boot-tool refresh
```

Grub

```bash
update-initramfs -u -k all && update-grub refresh
```

#### Locate your PCI device ID's ####

##### GPU #####

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

##### HBA #####

```bash
lspci -nn | grep 'LSI'
```

02:00.0 Serial Attached SCSI controller [0107]: Broadcom / LSI SAS3416
Fusion-MPT Tri-Mode I/O Controller Chip (IOC) <b>[1000:00ac]</b> (rev 01)d

Now you can integrate these device ID's into the vfio configuration, note
that I've included two device ID's for the GPU - this is because one is for
video and the other for audio. Failure to include both can and will likely
cause issues.

#### VFIO configuration file ####

```bash
echo "options vfio-pci ids=1000:00ac,10de:2803,10de:22bd" >> \
/etc/modprobe.d/vfio.conf
```

##### For LSI or Broadcomm HBA's #####

```bash
echo "softdep mpt3sas pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

##### NVIDIA GPU's #####

```bash
echo "softdep nouveau pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep nvidia pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep nvidiafb pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep nvidia_drm pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep drm pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

##### An exception may be needed for GPU audio  #####

```bash
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

##### For AMD GPU's #####

```bash
echo "softdep radeon pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep amdgpu pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

##### For Intel GPU's #####

```bash
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep snd_hda_codec_hdmi pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep i915 pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep xe pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

#### Blacklist file for fallback in case first steps fail ####

```bash
echo "blacklist mpt3sas" >> /etc/modprobe.d/blacklist.conf
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
echo "blacklist amdgpu" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nouveau" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidiafb" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia_drm" >> /etc/modprobe.d/blacklist.conf
echo "blacklist snd_hda_intel" >> /etc/modprobe.d/blacklist.conf
echo "blacklist snd_hda_codec_hdmi" >> /etc/modprobe.d/blacklist.conf
echo "blacklist i915" >> /etc/modprobe.d/blacklist.conf
echo "blacklist xe" >> /etc/modprobe.d/blacklist.conf
```

### Update initramfs and refresh bootloader ###


Systemdboot

```bash
update-initramfs -u -k all && proxmox-boot-tool refresh
```

Grub

```bash
update-initramfs -u -k all && update-grub refresh
```