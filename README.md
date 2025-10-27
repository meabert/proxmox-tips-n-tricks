# Proxmox Tips & Tricks #

![markdownlint-cli2](https://github.com/meabert/proxmox-tips-n-tricks/actions/workflows/markdownlint-cli2-action.yml/badge.svg)

## Operator Overview - Updated 10/26/2025 ##

This repository documents the ongoing evolution of my Proxmox-based homelab cluster — not as a generic how-to, but as a
curated archive of edge-case fixes, hardware quirks, and kernel-level tooling. It’s built for operators who’ve Googled
a boot flag and landed in a 12-post thread with zero answers.

> [!CAUTION]
> Your hardware is not my hardware. Always verify kernel flags, BIOS settings, and driver behavior before applying
> anything here. Especially if your PCI slot is hosting a particle accelerator.

## Objectives ##

Create a centralized repository for the inner workings of Proxmox, Homelab tools and general Linux items that are
directly related.

### What to install before starting ###

- A new Proxmox instance installed, booted and ready to go. Existing installs will also work just fine, however, I do
  not recommend testing these changes on a live production server without ample testing. If your end goal is live
  production, please for ones own sanity get a lab or replica to break before trying to roll this. The wrong boot flags
  can kill a system, literally.

- If you are new to Proxmox or Linux overall I suggest reviewing the official documentation before reading further:

> [Proxmox Official Documentation][pvel-docs] |
> [Admin Guide][pvel-admin] |
> [QEMU/KVM Virtual Machines][pvel-kvm] |
> [PCIe Passthrough][pvel-pcie] |
> [General Requirements][pvel-requirements] |
> [Host Device Passthrough][pvel-hostpass] |
> [SR-IOV][pvel-SR-IOV] |
> [Mediated Devices][pvel-mediated] |
> [vIOMMU][pvel-IOMMU] |
> [Resource Mapping][pvel-resourcemap]

- Post-install process - Enable apt i.e. enterprise or no-subscription repos, update system to test connectivity.

- Node-to-node transfers

- Shared Ceph pools

- Access all nodes from one UI

### Clusters Only - Skip for Single Nodes ###

If you're running multiple Proxmox nodes and want full control over high availability behavior, you'll
need to disable Proxmox HA services. In my lab, I’ve done exactly that — HA is disabled, but Corosync active for:

Instead of relying on Proxmox’s HA stack, I use a redundant HAProxy + Keepalived setup to manage frontend failover and
routing. This gives me full visibility and control over how services are exposed — without the risk of Proxmox
auto-restarting VMs in ways I didn’t authorize.

> [!WARNING] You own the failover logic. With HA disabled, LXC containers and VMs won’t auto-migrate or restart on other
> nodes. If a node dies, it’s on you to detect it and recover workloads manually. This setup is ideal for labs and edge
> deployments where predictability and control matter more than automation. Just make sure your HAProxy + Keepalived
> config is tight — and test failover before you trust it. Want to add a diagram or table showing how your 
> HAProxy + Keepalived setup routes traffic across nodes? I can help you sketch it out in Markdown or Mermaid.


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

[Kernel.org - Admin Guide - Kernel Parameters][kernel-guide-official]

##### Github.com #####

[GitHub Tracking - Admin Guide - Kernel Parameters][kernel-guide-github]

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

### Be aware of device functions ###

If you only isolate the GPU, but not the audio you won't get any audio. Some GPU's also have USB-C connections for VR
and various other functions - these are no different, if the USB-C is not isolated and passed through in addition to 
the GPU the function will not work.

#### HDMI Audio ####

```bash
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
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
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

#### Dedicated - AMD GPU's Navi, Vega, Polaris, Instinct, Radeon Pro ####

```bash
echo "softdep radeon pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep amdgpu pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep ccp pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep xhci_hcd pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

### Special Care: Intel ARC + iGPU ###

> [!WARNING]
> If you run a newer hybrid Intel setup (e.g. Ultra 7 265K + Arc B580) you'll need to be **extremely careful** when
> blocking kernel modules for VFIO as some may overlap.

- iGPU uses ```i915``` - blocking this will break host graphics unless you have a fallback GPU that does not rely on
the **i915** module.
- ARC uses ```xe``` - this is the module you want to block for dedicated GPU's like the B580.

- Both GPU's may share the same HDMI audio ```snd_hda_intel``` and DRM stack ```drm``` & ```drm_kms_helper``` - block
these only if you're passing through a dedicated Intel ARC GPU.

> [!TIP]
> If all you have is an iGPU, consider instead **sharing it with the host** and running workloads in **LXC containers**
> instead of full passthrough. This avoids driver conflics and allows you to keep your local display running even while
> running isolated tasks.

#### Integrated - Intel GPU's - iGPU ####

```bash
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep snd_hda_codec_hdmi pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep i915 pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep i2c_algo_bit pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep drm pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep drm_kms_helper pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

#### Dedicated - Intel GPU's - ARC ####

```bash
echo "softdep xe pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep i2c_algo_bit pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep drm pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep drm_kms_helper pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep snd_hda_codec_hdmi pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

### Troubleshooting ###

> [!TIP]
> Update your PCI and SMART databases before running lspci — this helps decode ambiguous device names:
> ```bash
> sudo update-pciids && update-smart-drivedb
> ```

#### Step 1: Identify Your PCI Device ####

If VFIO isnt grabbing your device at boot, you can validate and override it **at runtime**. This isn't
persistent - changes will be lost on reboot - but it's excellent for testing.

Use ```lspci -nnk``` to find your device and its function numbers. Example output for a GPU:

```bash
41:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD106 [GeForce RTX 4060 Ti] [10de:2803] (rev a1)
41:00.1 Audio device [0403]: NVIDIA Corporation AD106M High Definition Audio Controller [10de:22bd] (rev a1)
```

> [!NOTE]
> Most GPUs expose **multiple functions** - video, audio, USB-C, optical. You must bind **all functions** to 
> VFIO or passthrough will break.


#### PCI ID Breakdown ####

| Segment | Definition |
| --- | --- |
| 0000 | PCI Domain |
| 41 | Bus Number |
| 00 | Device Number |
| .1 | Function number |

#### Step 2: Runtime Override (Temporary) ####

Replace ```YOUR:DE:VI.CE``` with your full PCI ID (e.g. 0000:41:00.1):

```bash
echo "vfio-pci" > /sys/bus/pci/devices/YOUR:DE:VI.CE/driver_override
echo 1 > /sys/bus/pci/devices/YOUR:DE:VI.CE/remove
echo 1 > /sys/bus/pci/rescan
```
Ensure there is an entry for each **device function** or you risk a kernel module loading which will block VFIO:

```bash
# GPU core
echo "vfio-pci" > /sys/bus/pci/devices/0000:41:00.0/driver_override
echo 1 > /sys/bus/pci/devices/0000:41:00.0/remove

# HDMI audio
echo "vfio-pci" > /sys/bus/pci/devices/0000:41:00.1/driver_override
echo 1 > /sys/bus/pci/devices/0000:41:00.1/remove

# Rescan PCI bus
echo 1 > /sys/bus/pci/rescan
```

### Blacklist Fallback - If VFIO Fails ###

#### NVIDIA Modules ####

echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia_modeset" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidiafb" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia_drm" >> /etc/modprobe.d/blacklist.conf
echo "blacklist snd_hda_intel" >> /etc/modprobe.d/blacklist.conf
echo "blacklist snd_hda_codec_hdmi" >> /etc/modprobe.d/blacklist.conf

#### AMD Modules ####

echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
echo "blacklist amdgpu" >> /etc/modprobe.d/blacklist.conf
echo "blacklist ccp" >> /etc/modprobe.d/blacklist.conf
echo "blacklist xhci_hcd" >> /etc/modprobe.d/blacklist.conf
echo "blacklist snd_hda_intel" >> /etc/modprobe.d/blacklist.conf

#### Intel iGPU Modules ####

echo "softdep i915 pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep xe pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep snd_hda_codec_hdmi pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep i2c_algo_bit pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep drm pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep drm_kms_helper pre: vfio-pci" >> /etc/modprobe.d/vfio.conf

#### Intel Modules ####

##### Intel ARC/Battlemage (dGPU) VFIO Blacklist #####

echo "blacklist xe" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist snd_hda_intel" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist drm" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist drm_kms_helper" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist i2c_algo_bit" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist intel_vsec" >> /etc/modprobe.d/vfio-blacklist.conf

##### Intel iGPU (Meteor Lake or older) VFIO Blacklist #####

echo "blacklist i915" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist snd_hda_intel" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist drm" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist drm_kms_helper" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist i2c_algo_bit" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist intel_gtt" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist intel_uncore" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist intel_vsec" >> /etc/modprobe.d/vfio-blacklist.conf

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
<!--
🧪 Operator Advisory: Link Glossary
All external references are declared below for markdownlint compliance and contributor clarity.
-->
[kernel-guide-github]: https://github.com/torvalds/linux/blob/master/Documentation/admin-guide/boot.parameters.html
[kernel-guide-official]: https://docs.kernel.org/admin-guide/kernel-parameters.html
[licensing-email]: mailto:licensing@techinasnap.com
[pvel-docs]: https://pve.proxmox.com/pve-docs/
[pvel-admin]: https://pve.proxmox.com/pve-docs/pve-admin-guide.html
[pvel-kvm]: https://pve.proxmox.com/pve-docs/chapter-qm.html
[pvel-pcie]: https://pve.proxmox.com/pve-docs/chapter-qm.html#qm_pci_passthrough
[pvel-requirements]: https://pve.proxmox.com/pve-docs/chapter-qm.html#_general_requirements
[pvel-hostpass]: https://pve.proxmox.com/pve-docs/chapter-qm.html#_host_device_passthrough
[pvel-SR-IOV]: https://pve.proxmox.com/pve-docs/chapter-qm.html#_sr_iov
[pvel-mediated]: https://pve.proxmox.com/pve-docs/chapter-qm.html#_mediated_devices_vgpu_gvt_g
[pvel-IOMMU]: https://pve.proxmox.com/pve-docs/chapter-qm.html#qm_pci_viommu
[pvel-resourcemap]: https://pve.proxmox.com/pve-docs/chapter-qm.html#resource_mapping

<!--
🛡️ Licensing Manifesto

Steal it. Brand it. Ship it.  
But if you profit, I invoice.

This project is dual-licensed:

- 🛠️ Scripts and tooling: Server Side Public License (SSPL)
- 📚 Documentation and guides: Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)

Free for learning. Forbidden for resale. Attribution required.  
Commercial use requires a separate license. Contact [licensing-email].

[licensing-email]: mailto:licensing@techinasnap.com
-->
## License ##

This project is dual-licensed:

- 🛠️ Scripts: [SSPL](https://www.mongodb.com/licensing/server-side-public-license)
- 📚 Docs: [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/)

Free to learn. Not free to resell.  
If you profit, I invoice.  
Contact [licensing][licensing-email] for commercial use.
<!--
🤖 Copilot Attribution Advisory

This project includes operator-friendly content generated with help from Microsoft Copilot.  
Copilot output is governed by the [Microsoft Services Agreement](https://www.microsoft.com/en-us/servicesagreement).  
No license obligations are imposed by Copilot itself. Attribution optional, but appreciated.

Copilot didn’t write this project — it riffed with me.  
Every splash block, every advisory zone, every breadcrumb is mine.  
Copilot just helped me sharpen the edges.

-->
