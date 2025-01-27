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
Microcode security patches both of which can be found VIA the following links.</P>

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

<b><h3>apt install</h3>
sudo<br />
iperf3<br />
btop<br />
gcc<br />
make<br />
cmake<br />
automake<br />
build-essential<br />
git<br />
unzip<br />
lm-sensors<br />
powertop<br />
htop<br />
btop<br />
vim-nox<br />
shim-signed<br />
shim-helpers-amd64-signed<br />
grub-efi-amd64-signed<br />
proxmox-headers-6.8.12-7-pve<br />
sbsigntool<br />
efibootmgr<br />
efitools<br />
uuid-runtime<br />
dkmssbsigntool<br />
mokutil<br />
devscripts<br />
debhelper<br />
equivs<br />
git<br /></b>

### Authentication - PAM Modules, add or remove as needed depending on your use case

<p>PAM or Pluggable Authentication Modules involve a variety of different
libraries used to facilitate different methods of authentication. I recommend
learning and adapting to various forms of authentication besides passwords.
Eventually passwords will become obsolete and from a security standpoint it's
excellent knowledge educating yourself on these methods. A common PAM would be
a YubiKey as an alternate form of ID, knowing this basic concept you can apply this
same concept to the libpam-zfs library as an example, this library is for
unlocking ZFS encrypted partitions.</p>

<b><h3>apt install</h3>
libpam-yubico<br />
libpam-zfs<br />
libpam-u2f<br />
libpam-ufpidentity<br />
libpam-ssh-agent-auth<br />
libpam-radius-auth<br />
libpam-python<br />
libpam-pwquality<br />
libpam-poldi<br />
libpam-oath<br />
libpam-modules<br />
libpam-modules-bin<br />
libpam-mount<br />
libpam-mount-bin<br />
libpam-mysql<br />
libpam-gnome-keyring<br />
libpam-google-authenticator<br />
libpam-doc<br />
libpam-ccreds<br />
libpam-cads<br />
libpam-cgroup<br />
libpam-alreadyloggedin<br />
libpam-apparmor<br />
libpam-abl<br />
libnginx-mod-http-auth-pam<br />
libapache2-mod-authnz-pam<br />
libapache2-mod-intercept-form-submit<br />
libauthen-pam-perl<br />
libauthen-simple-pam-perl<br />
libbio-tools-phylo-paml-perl<br /></b>

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
<b>vim /etc/kernel/cmdline</b>

Note: Grub users should instead modify /etc/default/grub

For AMD IOMMU is enabled by default - simply make sure it is
enabled in the BIOS and add applicable kernel flags.

<b>root=ZFS=rpool/ROOT/pve-1 boot=zfs iommu=pt nomodeset</b>

##### Intel Kernel Flags

For Intel add applicable kernel flags to enable, also ensure
it is enabled in the BIOS.

<b>root=ZFS=rpool/ROOT/pve-1 boot=zfs intel_iommu=on nomodeset</b>

##### Kernel Admin Guide -  Boot Parameters

<https://github.com/torvalds/linux/blob/master/Documentation/admin-guide/kernel-parameters.txt>

#### Enable the vfio modules

<b>echo "vfio" >> /etc/modules<br />
echo "vfio_iommu_type1" >> /etc/modules<br />
echo "vfio_pci" >> /etc/modules</b><br />

#### Locate your PCI device ID's

##### GPU

<b>lspci -nn | grep 'NVIDIA'</b>

43:00.0 VGA compatible controller [0300]: NVIDIA Corporation AD106
[GeForce RTX 4060 Ti] <b>[10de:2803]</b> (rev a1)

43:00.1 Audio device [0403]: NVIDIA Corporation AD106M High Definition
Audio Controller <b>[10de:22bd]</b> (rev a1)

##### HBA

<b>lspci -nn | grep 'LSI'</b>

02:00.0 Serial Attached SCSI controller [0107]: Broadcom / LSI SAS3416
Fusion-MPT Tri-Mode I/O Controller Chip (IOC) <b>[1000:00ac]</b> (rev 01)d

Now you can integrate these device ID's into the vfio configuration, note
that I've included two device ID's for the GPU - this is because one is for
video and the other for audio. Not passing through both can cause issues.

#### VFIO configuration file

echo "options vfio-pci ids=1000:00ac,10de:2803,10de:22bd" >> /etc/modprobe.d/vfio.conf

##### For NVIDIA GPU's

echo "softdep nouveau pre: vfio-pci" >> /etc/modprobe.d/vfio.conf<br />
echo "softdep nvidia pre: vfio-pci" >> /etc/modprobe.d/vfio.conf<br />
echo "softdep nvidiafb pre: vfio-pci" >> /etc/modprobe.d/vfio.conf<br />
echo "softdep nvidia_drm pre: vfio-pci" >> /etc/modprobe.d/vfio.conf<br />
echo "softdep drm pre: vfio-pci" >> /etc/modprobe.d/vfio.conf<br />

##### For AMD GPU's

echo "softdep radeon pre: vfio-pci" >> /etc/modprobe.d/vfio.conf<br />
echo "softdep amdgpu pre: vfio-pci" >> /etc/modprobe.d/vfio.conf<br />

##### For Intel GPU's

echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf<br />
echo "softdep snd_hda_codec_hdmi pre: vfio-pci" >> /etc/modprobe.d/vfio.conf<br />
echo "softdep i915 pre: vfio-pci" >> /etc/modprobe.d/vfio.conf<br />

#### Blacklist file for fallback in case first steps fail

vim /etc/modprobe.d/blacklist.conf

blacklist mpt3sas<br />
blacklist radeon<br />
blacklist amdgpu<br />
blacklist nouveau<br />
blacklist nvidia<br />
blacklist nvidiafb<br />
blacklist nvidia_drm<br />
blacklist snd_hda_intel<br />
blacklist snd_hda_codec_hdmi<br />
blacklist i915<br />

### Update initramfs and refresh boot tool

update-initramfs -u -k all<br/>
proxmox-boot-tool refresh
