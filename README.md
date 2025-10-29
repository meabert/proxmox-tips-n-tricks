# Proxmox Tips & Tricks #

A curated set of Proxmox enhancements for homelab and edge deployments — with CI/CD swagger.

## 🛠️ CI/CD Automation Status ##

| Workflow | Status |
|----------|--------|
| markdownlint-cli2 | ![Markdown Validation](https://github.com/meabert/proxmox-tips-n-tricks/actions/workflows/markdownlint-cli2-action.yml/badge.svg) |
| Post-Install | [![Script Injection](https://github.com/meabert/proxmox-tips-n-tricks/actions/workflows/inject-postinstall.yml/badge.svg)](https://github.com/meabert/proxmox-tips-n-tricks/actions/workflows/inject-postinstall.yml) |
| Repo Permission | [![CC BY-NC 4.0](https://img.shields.io/badge/License-CC%20BY--NC%204.0-lightgrey.svg)](https://creativecommons.org/licenses/by-nc/4.0/) |

## Operator Overview ##

This repository documents a multi-node Proxmox VE homelab designed for performance, auditability, and operator clarity.
It blends production-grade hygiene with experimental edge configurations — including post-install scripting, microcode
patching, PCI passthrough, and kernel-level tuning.

The goal is to create a repeatable, contributor-savvy setup that’s:

- ✅ Maintainable across hardware generations
- ✅ Transparent for audit and recovery
- ✅ Loud enough to warn future operators before regret sets in

For a breakdown of the hardware roles and topology, see [`Nodes Hardware`](docs/nodes.md).

> [!CAUTION]
> Your hardware is not my hardware. Always verify kernel flags, BIOS settings, and driver behavior before applying
> anything here. Especially if your PCI slot is hosting a particle accelerator.

## Project Objectives & Setup Prerequisites ##

This repository serves as a centralized reference for Proxmox VE enhancements, homelab tooling, and Linux configurations
directly related to virtualization, hardware provisioning, and infrastructure hygiene. It’s designed to help operators
build reliable, auditable systems with branded onboarding and contributor clarity.

### Objectives ###

- Document repeatable post-install workflows for Proxmox VE
- Share PCI passthrough strategies, kernel tuning, and VFIO setups
- Provide modular scripts and advisory blocks for onboarding and recovery
- Blend homelab experimentation with production-grade hygiene

### Prerequisites ###

Before applying any changes or running scripts from this repository, ensure the following:

- ✅ A fresh or existing Proxmox VE instance is installed and accessible
- ✅ You are **not** testing on a live production server without a lab or replica
- ✅ You’ve reviewed the official Proxmox documentation and understand the risks of kernel flag changes

> [!WARNING]
> The wrong boot flags can render a system unbootable. Always test in a
> controlled environment before applying changes to production.

If you're new to Proxmox or Linux, start with the official documentation:

- [Proxmox Official Documentation][pvel-docs]
- [Admin Guide][pvel-admin]
- [QEMU/KVM Virtual Machines][pvel-kvm]
- [PCIe Passthrough][pvel-pcie]
- [General Requirements][pvel-requirements]
- [Host Device Passthrough][pvel-hostpass]
- [SR-IOV][pvel-SR-IOV]
- [Mediated Devices][pvel-mediated]
- [vIOMMU][pvel-IOMMU]
- [Resource Mapping][pvel-resourcemap]

### Recommended Packages ###

Adjust based on your hardware, integration and compliance needs:

<pre style="white-space: pre-wrap;">
apt install sudo iperf3 btop gcc make cmake automake autoconf build-essential
git unzip lm-sensors powertop htop btop pve-headers dkms devscripts debhelper
equivs nut nut-server nut-monitor ipmitool redfishtool nvme-cli
</pre>

#### Post-Install Process ####

The post-install phase can be quick or deeply customized depending on your environment. While community scripts exist,
the most reliable and maintainable approach is to build your own — tailored to your infrastructure, workflows, and
operational standards. For inspiration, check out the post-install script I’ve put together. It’s modular,
operator-friendly, and easy to extend:

<details>
<summary>📜 View Full Post-Install Script</summary>

<!-- POSTINSTALL:START -->
```bash
# License: CC BY-NC 4.0
# You may reuse, remix, and adapt this script non-commercially with attribution.
# Commercial use requires explicit permission.
# https://creativecommons.org/licenses/by-nc/4.0/

#!/bin/bash

REPO_FILE="/etc/apt/sources.list.d/pve-enterprise.list"
NO_SUB_FILE="/etc/apt/sources.list.d/pve-no-subscription.list"
CODENAME="$(. /etc/os-release && echo "$VERSION_CODENAME")"
SHOW_HELP=false
JUST_SWITCH=false
DEBUG=false
DRY_RUN=false

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --just-switch-repos-no-prompt) JUST_SWITCH=true ;;
    --debug) DEBUG=true ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h) SHOW_HELP=true ;;
  esac
done

# Spinner function
spin() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while kill -0 "$pid" 2>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Verbose log
log() {
  $DEBUG && echo "[DEBUG] $1"
}

# \x1f6d1 Help block \x2014 run before anything else
if $SHOW_HELP; then
  echo "Usage: ./post-install.sh [options]"
  echo ""
  echo "Options:"
  echo "  --just-switch-repos-no-prompt   Toggle Proxmox repo without confirmation"
  echo "  --debug                         Enable verbose debug output"
  echo "  --dry-run                       Simulate all actions without making changes"
  echo "  --help, -h                      Show this help message and exit"
  echo ""
  echo "Modules included:"
  echo "  \x1f501 Repo toggle (enterprise \x2194 no-subscription)"
  echo "  \x1f9ec Microcode install + blacklist cleanup"
  echo "  \x1f500 Open vSwitch install"
  echo "  \x1f9e0 Hugepage optimizer (2MB sysctl + 1GB boot flag advisory)"
  exit 0
fi

# Repo toggling
switch_to_no_sub() {
  log "Commenting out enterprise repo..."
  if $DRY_RUN; then
    echo "[DRY RUN] Would comment out $REPO_FILE and write no-subscription repo for $CODENAME"
  else
    [ -f "$REPO_FILE" ] && sed -i 's|^deb|#deb|' "$REPO_FILE"
    echo "deb http://download.proxmox.com/debian/pve $CODENAME pve-no-subscription" > "$NO_SUB_FILE"
    (apt update &>/dev/null) &
    spin $!
  fi
  echo "Switched to no-subscription repo."
}

switch_to_enterprise() {
  log "Uncommenting enterprise repo..."
  if $DRY_RUN; then
    echo "[DRY RUN] Would uncomment $REPO_FILE and remove $NO_SUB_FILE"
  else
    [ -f "$REPO_FILE" ] && sed -i 's|^#deb|deb|' "$REPO_FILE"
    [ -f "$NO_SUB_FILE" ] && rm -f "$NO_SUB_FILE"
    (apt update &>/dev/null) &
    spin $!
  fi
  echo "Switched to enterprise repo."
}

# Microcode install
microcode_module() {
  echo "\x1f527 [pve-postinstall] Microcode Installer"
  echo "Install CPU microcode updates and remove blacklist? [y/N]"
  read -r mc_reply
  case "$mc_reply" in
    [yY][eE][sS]|[yY])
      if $DRY_RUN; then
        echo "[DRY RUN] Would install intel-microcode and amd64-microcode"
        echo "[DRY RUN] Would remove 'blacklist microcode' from /etc/modprobe.d/blacklist.conf"
      else
        apt install -y intel-microcode amd64-microcode
        [ -f /etc/modprobe.d/blacklist.conf ] && sed -i '/blacklist microcode/d' /etc/modprobe.d/blacklist.conf
      fi
      echo "Microcode install simulated."
      ;;
    *) echo "Skipped microcode install." ;;
  esac
}

# Open vSwitch install
ovs_module() {
  echo "\x1f527 [pve-postinstall] Open vSwitch Installer"
  echo "Install Open vSwitch? [y/N]"
  read -r ovs_reply
  case "$ovs_reply" in
    [yY][eE][sS]|[yY])
      if $DRY_RUN; then
        echo "[DRY RUN] Would install openvswitch-switch"
      else
        apt install -y openvswitch-switch
      fi
      echo "Open vSwitch install simulated."
      ;;
    *) echo "Skipped Open vSwitch." ;;
  esac
}

# Hugepage module
hugepage_module() {
  echo "\x1f527 [pve-postinstall] Hugepage Optimizer"

  SYSCTL_FILE="/etc/sysctl.d/99-hugepages.conf"
  $DRY_RUN || touch "$SYSCTL_FILE"

  HP_1G=$(grep -i pdpe1gb /proc/cpuinfo | wc -l)
  HP_2M=$(grep -i pse /proc/cpuinfo | wc -l)

  [[ "$HP_1G" -gt 0 ]] && echo "\x2705 CPU supports 1GB hugepages." || echo "\x274c No 1GB support."
  [[ "$HP_2M" -gt 0 ]] && echo "\x2705 CPU supports 2MB hugepages." || echo "\x274c No 2MB support."

  echo "Enable 1GB hugepages? [y/N]"
  read -r enable_1g
  echo "Enable 2MB hugepages? [y/N]"
  read -r enable_2m

  echo "Specify number of pages or type 'auto':"
  read -r page_count

  CORES=$(nproc)
  RAM_MB=$(free -m | awk '/Mem:/ {print $2}')
  ROOT_DEV=$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//')
  IS_SSD=$(lsblk -dno rota "$ROOT_DEV" 2>/dev/null | grep -q 0 && echo "NVMe/SSD" || echo "HDD")

  if [[ "$page_count" == "auto" ]]; then
    if [[ "$IS_SSD" == "NVMe/SSD" ]]; then
      PAGES_1G=$((CORES / 2))
      PAGES_2M=$((CORES * 256))
    else
      PAGES_1G=$((CORES / 4))
      PAGES_2M=$((CORES * 128))
    fi
  else
    PAGES_1G="$page_count"
    PAGES_2M="$page_count"
  fi

  set_sysctl_param() {
    local key="$1"
    local value="$2"
    if grep -q "^$key=" "$SYSCTL_FILE"; then
      CURRENT_VAL=$(grep "^$key=" "$SYSCTL_FILE" | cut -d= -f2)
      if [ "$CURRENT_VAL" != "$value" ]; then
        if $DRY_RUN; then
          echo "[DRY RUN] Would update $key to $value in $SYSCTL_FILE"
        else
          sed -i "s|^$key=.*|$key=$value|" "$SYSCTL_FILE"
        fi
      else
        echo "\x2705 $key already set to $value \x2014 no change needed"
      fi
    else
      if $DRY_RUN; then
        echo "[DRY RUN] Would add $key=$value to $SYSCTL_FILE"
      else
        echo "$key=$value" >> "$SYSCTL_FILE"
      fi
    fi
  }

  if [[ "$enable_2m" =~ ^[yY] && "$HP_2M" -gt 0 ]]; then
    set_sysctl_param "vm.nr_hugepages" "$PAGES_2M"
    $DRY_RUN || sysctl --system
  fi

  if [[ "$enable_1g" =~ ^[yY] && "$HP_1G" -gt 0 ]]; then
    echo "\x26a0\xfe0f 1GB hugepages require kernel boot flags and hugetlbfs mount."
    CMDLINE=$(cat /proc/cmdline)
    if echo "$CMDLINE" | grep -q "hugepagesz=1G"; then
      echo "\x2705 Boot flags already include 1GB hugepage support:"
      echo "    $CMDLINE"
      echo "Generate a modified boot flag with a new page count? [y/N]"
      read -r modify_flag
      if [[ "$modify_flag" =~ ^[yY] ]]; then
        echo "Specify number of 1GB hugepages (or type 'auto'):"
        read -r new_count
        [[ "$new_count" == "auto" ]] && new_count=$((CORES / 2))
        echo "\x1f527 Suggested boot flag:"
        echo "    hugepagesz=1G hugepages=$new_count"
      fi
    else
      echo "\x26a0\xfe0f 1GB hugepages are supported but not enabled."
      echo "Generate a boot flag to enable them? [y/N]"
      read -r enable_flag
      if [[ "$enable_flag" =~ ^[yY] ]]; then
        echo "Specify number of 1GB hugepages (or type 'auto'):"
        read -r new_count
        [[ "$new_count" == "auto" ]] && new_count=$((CORES / 2))
        echo "\x1f527 Suggested boot flag:"
        echo "    hugepagesz=1G hugepages=$new_count"
      fi
    fi
  fi
}

# Main flow
if grep -q '^deb ' "$REPO_FILE" 2>/dev/null; then
  if $JUST_SWITCH; then
    switch_to_no_sub
  else
    echo "Enterprise repo is active. Switch to no-subscription? [y/N]"
    read -r reply
    [[ "$reply" =~ ^[yY] ]] && switch_to_no_sub || echo "No changes made."
  fi
else
  if $JUST_SWITCH; then
    switch_to_enterprise
  else
    echo "Enterprise repo is disabled. Switch back to enterprise? [y/N]"
    read -r reply
    [[ "$reply" =~ ^[yY] ]] && switch_to_enterprise || echo "No changes made."
  fi
fi

# Run modules
hugepage_module
microcode_module
ovs_module

echo "\x2705 [pve-postinstall] Script complete."
$DRY_RUN && echo "\x1f9ea Dry run mode: no changes were made."
```
<!-- POSTINSTALL:END -->

</details>

### CPU Scaling Governor ###

In order to get the desired functionality out of your setup the CPU governor needs to match your workload and power
expectations. I use on-demand for my three nodes. The modes to you vary depending on your CPU model, it's age, and if
a p-state driver is available. The ```cpupower``` command will show you which governors are available to you.

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

### Clusters Only - Skip for Single Nodes ###

If you're running multiple Proxmox nodes and want full control over high availability behavior, you'll
need to disable Proxmox HA services. In my lab, I’ve done exactly that — HA is disabled, but Corosync active for:

- Node-to-node transfers

- Shared Ceph pools

- Access all nodes from one UI

Instead of relying on Proxmox’s HA stack, I use a redundant HAProxy + Keepalived setup to manage frontend failover and
routing. This gives me full visibility and control over how services are exposed — without the risk of Proxmox
auto-restarting VMs in ways I didn’t authorize.

> [!WARNING]
> You own the failover logic. With HA disabled, LXC containers and VMs won’t auto-migrate or restart on other
> nodes. If a node dies, it’s on you to detect it and recover workloads manually. This setup is ideal for labs and edge
> deployments where predictability and control matter more than automation.

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
> ```sudo update-pciids && update-smart-drivedb```

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

```bash
echo "blacklist nvidia" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia_modeset" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidiafb" >> /etc/modprobe.d/blacklist.conf
echo "blacklist nvidia_drm" >> /etc/modprobe.d/blacklist.conf
echo "blacklist snd_hda_intel" >> /etc/modprobe.d/blacklist.conf
echo "blacklist snd_hda_codec_hdmi" >> /etc/modprobe.d/blacklist.conf
```

#### AMD Modules ####

```bash
echo "blacklist radeon" >> /etc/modprobe.d/blacklist.conf
echo "blacklist amdgpu" >> /etc/modprobe.d/blacklist.conf
echo "blacklist ccp" >> /etc/modprobe.d/blacklist.conf
echo "blacklist xhci_hcd" >> /etc/modprobe.d/blacklist.conf
echo "blacklist snd_hda_intel" >> /etc/modprobe.d/blacklist.conf
```

#### Intel iGPU Modules ####

```bash
echo "softdep i915 pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep xe pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep snd_hda_intel pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep snd_hda_codec_hdmi pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep i2c_algo_bit pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep drm pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
echo "softdep drm_kms_helper pre: vfio-pci" >> /etc/modprobe.d/vfio.conf
```

#### Intel ARC/Battlemage (dGPU) Blacklist ####

```bash
echo "blacklist xe" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist snd_hda_intel" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist drm" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist drm_kms_helper" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist i2c_algo_bit" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist intel_vsec" >> /etc/modprobe.d/vfio-blacklist.conf
```

##### Intel iGPU (Meteor Lake or older) Blacklist #####

```bash
echo "blacklist i915" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist snd_hda_intel" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist drm" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist drm_kms_helper" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist i2c_algo_bit" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist intel_gtt" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist intel_uncore" >> /etc/modprobe.d/vfio-blacklist.conf
echo "blacklist intel_vsec" >> /etc/modprobe.d/vfio-blacklist.conf
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
<!--
🧪 Operator Advisory: Link Glossary
All external references are declared below for markdownlint compliance and contributor clarity.
-->
[kernel-guide-github]: https://github.com/torvalds/linux/blob/master/Documentation/admin-guide/boot.parameters.html
[kernel-guide-official]: https://docs.kernel.org/admin-guide/kernel-parameters.html
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

> 📜 This repository is licensed under [CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/).  
> You may reuse, remix, and adapt the content non-commercially with attribution.  
> Commercial use requires explicit permission — because good infrastructure deserves respect, not exploitation.

<!--
🤖 Copilot Attribution Advisory

This project includes operator-friendly content generated with help from Microsoft Copilot.  
Copilot output is governed by the [Microsoft Services Agreement](https://www.microsoft.com/en-us/servicesagreement).  
No license obligations are imposed by Copilot itself. Attribution optional, but appreciated.

Copilot didn’t write this project — it riffed with me.  
Every splash block, every advisory zone, every breadcrumb is mine.  
Copilot just helped me sharpen the edges.

-->
