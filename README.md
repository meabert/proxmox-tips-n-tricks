# Documentation

## Haphazardly collected scripts & tricks I've refined while building my homelab

### Objectives

Expand the scope beyond what is available VIA Proxmox Helper Scripts

<https://community-scripts.github.io/ProxmoxVE/scripts>
<https://github.com/community-scripts/ProxmoxVE>

<p>Reliable access to one-shot install clips and key third party package
repositories. So many concepts and lopsided code philosophy's have led
me to just document it instead! Waste less time doing tedious configurations
so you can instead spend that time building something unique.</p>

### Bare minimum packages to setup my workflow

<p>These are the packages I install after every Proxmox install, the only changes
that take place before this are running the Post-Installation Script and the CPU
Microcode security patches both of which can be found VIA the following links.</p>

#### Post-Install Script

<https://community-scripts.github.io/ProxmoxVE/scripts?id=post-pve-install>

#### Microcode Patches

<https://community-scripts.github.io/ProxmoxVE/scripts?id=microcode>

### Some optional items depending on your use-case

#### CPU Scaling Governor

<p>This allows you to set a power/performance profile to your CPU(s) assuming
they support a variety of profiles, some only support one or two.</p>

<https://community-scripts.github.io/ProxmoxVE/scripts?id=scaling-governor>

#### Host Backup

<p>Enables extensive customization of backup outputs and location, not to
be confused with Proxmox Backup Server.</p>

<https://community-scripts.github.io/ProxmoxVE/scripts?id=host-backup>

#### Proxmox Data Center Manager

<https://community-scripts.github.io/ProxmoxVE/scripts?id=proxmox-datacenter-manager>

### Manually added packages

```bash apt install sudo iperf3 btop gcc make cmake automake autoconf
build-essential git unzip lm-sensors powertop htop btop vim-nox 
shim-signed shim-helpers-amd64-signed grub-efi-amd64-signed 
proxmox-headers-6.8.12-7-pve sbsigntool efibootmgr efitools uuid-runtime 
dkms sbsigntool mokutil devscripts debhelper equivs git```

<b><h4>Bonus:</h4></b> If you are using a server chances are high the motherboard
has some sort of administrative controller, these tools will help to monitor, divulge
logs and send SET changes to the controller. Various tools, not all may be required
depending on your motherboard ex. Redfish is not manufacturer specific.

```bash
apt install ilorest python3-sushy redfishtool python3-pyipmi python3-pyghmi
prometheus-ipmi-exporter openipmi nut-ipmi ipmiutil ipmitool freeipmi
freeipmi-tools freeipm-ipmiseld freeipmi-bmc-watchdog freeipmi-ipmidetect
libipmimonitoring6
```

### Authentication - PAM Modules, add or remove as needed depending on your use case

<p>PAM or Pluggable Authentication Modules involve a variety of different
libraries used to facilitate different methods of authentication. I recommend
learning and adapting to various forms of authentication besides passwords.
Eventually passwords will become obsolete and from a security standpoint it's
excellent knowledge educating yourself on these methods. A common PAM would be
a YubiKey as an alternate form of ID, knowing this basic concept you can apply this
same concept to the libpam-zfs library as an example, this library is for
unlocking ZFS encrypted partitions.</p>

```text
apt install libpam-yubico libpam-zfs libpam-u2f libpam-ufpidentity
libpam-ssh-agent-auth libpam-radius-auth libpam-python libpam-pwquality
libpam-poldi libpam-oath libpam-modules libpam-modules-bin libpam-mount 
libpam-mount-bin libpam-mysql libpam-gnome-keyring libpam-google-authenticator 
libpam-doc libpam-ccreds libpam-cads libpam-cgroup libpam-alreadyloggedin libpam-apparmor
libpam-abl libnginx-mod-http-auth-pam libapache2-mod-authnz-pam
libapache2-mod-intercept-form-submit libauthen-pam-perl libauthen-simple-pam-perl
libbio-tools-phylo-paml-perl
```

### PCI Express Passthrough

<p>These directions cover how to enable vfio and passthrough a GPU
on a system running SecureBoot with an NVIDIA RTX 4080 and a Broadcom
9400-16i HBA - please note this is for a full passthrough such as
for use in a virtual machine. Steps for running a GPU natively on
the host such as for containers is out of scope for this section
and different instructions should be used.</p>

Use case on the passthrough hardware:

GPU - Dedicated docker VM for LLM, Transcoding and Rendering

HBA - Fully virtualized TrueNAS with 12 drive RaidZ2

#### Enable IOMMU in the bootloader

<p>Your mileage may vary with specific kernel boot flags, however
after testing across various devices to a custom built AMD Epyc server,
a converted gaming desktop and even some GMKTec NUC's. These are
the settings that have worked across the board for me.</p>

##### AMD Kernel Flags

SecureBoot:

```bash
vim /etc/kernel/cmdline
```

Note: Grub users should instead modify /etc/default/grub

For AMD IOMMU is enabled by default - simply make sure it is
enabled in the BIOS and add applicable kernel flags.

```bash
root=ZFS=rpool/ROOT/pve-1 boot=zfs iommu=pt nomodeset
```

##### Intel Kernel Flags

For Intel add applicable kernel flags to enable, also ensure
it is enabled in the BIOS.

```bash
root=ZFS=rpool/ROOT/pve-1 boot=zfs intel_iommu=on nomodeset
```

##### Kernel Admin Guide -  Boot Parameters

```text
https://github.com/torvalds/linux/blob/master/Documentation/admin-guide/kernel-parameters.txt
```

#### Enable the vfio modules

```bash
echo "vfio" >> /etc/modules
echo "vfio_iommu_type1" >> /etc/modules
echo "vfio_pci" >> /etc/modules
```

#### Locate your PCI device ID's

##### GPU

```bash
lspci -nn | grep 'NVIDIA'
```

43:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD106
[GeForce RTX 4060 Ti] <b>[10de:2803]</b> (rev a1)

43:00.1 Audio device [0403]: NVIDIA Corporation AD106M High Definition
Audio Controller <b>[10de:22bd]</b> (rev a1)

##### HBA

```bash
lspci -nn | grep 'LSI'
```

02:00.0 Serial Attached SCSI controller [0107]: Broadcom / LSI SAS3416
Fusion-MPT Tri-Mode I/O Controller Chip (IOC) <b>[1000:00ac]</b> (rev 01)d

Now you can integrate these device ID's into the vfio configuration, note
that I've included two device ID's for the GPU - this is because one is for
video and the other for audio. Not passing through both can cause issues.

#### VFIO configuration file

```bash
echo "options vfio-pci ids=1000:00ac,10de:2803,10de:22bd" >> /etc/modprobe.d/vfio.conf
```

##### For NVIDIA GPU's

```bash
echo "softdep nouveau pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep nvidia pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep nvidiafb pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep nvidia_drm pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep drm pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

##### For AMD GPU's

```bash
echo "softdep radeon pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep amdgpu pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

##### For Intel GPU's

```bash
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep snd_hda_codec_hdmi pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep i915 pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

#### Blacklist file for fallback in case first steps fail

```bash
vim /etc/modprobe.d/blacklist.conf
```

```bash
blacklist mpt3sas
blacklist radeon
blacklist amdgpu
blacklist nouveau
blacklist nvidia
blacklist nvidiafb
blacklist nvidia_drm
blacklist snd_hda_intel
blacklist snd_hda_codec_hdmi
blacklist i915
```

### Update initramfs and refresh boot tool

```bash
update-initramfs -u -k all
proxmox-boot-tool refresh
```
