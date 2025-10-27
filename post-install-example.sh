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

# Spinner progress function
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

# 🛑 Help block — run before anything else
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
  echo "  🔁 Repo toggle (enterprise ↔ no-subscription)"
  echo "  🧬 Microcode install + blacklist cleanup"
  echo "  🔀 Open vSwitch install"
  echo "  🧠 Hugepage optimizer (2MB sysctl + 1GB boot flag advisory)"
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
  echo "🔧 [pve-postinstall] Microcode Installer"
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
  echo "🔧 [pve-postinstall] Open vSwitch Installer"
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
  echo "🔧 [pve-postinstall] Hugepage Optimizer"

  SYSCTL_FILE="/etc/sysctl.d/99-hugepages.conf"
  $DRY_RUN || touch "$SYSCTL_FILE"

  HP_1G=$(grep -i pdpe1gb /proc/cpuinfo | wc -l)
  HP_2M=$(grep -i pse /proc/cpuinfo | wc -l)

  [[ "$HP_1G" -gt 0 ]] && echo "✅ CPU supports 1GB hugepages." || echo "❌ No 1GB support."
  [[ "$HP_2M" -gt 0 ]] && echo "✅ CPU supports 2MB hugepages." || echo "❌ No 2MB support."

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
        echo "✅ $key already set to $value — no change needed"
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
    echo "⚠️ 1GB hugepages require kernel boot flags and hugetlbfs mount."
    CMDLINE=$(cat /proc/cmdline)
    if echo "$CMDLINE" | grep -q "hugepagesz=1G"; then
      echo "✅ Boot flags already include 1GB hugepage support:"
      echo "    $CMDLINE"
      echo "Generate a modified boot flag with a new page count? [y/N]"
      read -r modify_flag
      if [[ "$modify_flag" =~ ^[yY] ]]; then
        echo "Specify number of 1GB hugepages (or type 'auto'):"
        read -r new_count
        [[ "$new_count" == "auto" ]] && new_count=$((CORES / 2))
        echo "🔧 Suggested boot flag:"
        echo "    hugepagesz=1G hugepages=$new_count"
      fi
    else
      echo "⚠️ 1GB hugepages are supported but not enabled."
      echo "Generate a boot flag to enable them? [y/N]"
      read -r enable_flag
      if [[ "$enable_flag" =~ ^[yY] ]]; then
        echo "Specify number of 1GB hugepages (or type 'auto'):"
        read -r new_count
        [[ "$new_count" == "auto" ]] && new_count=$((CORES / 2))
        echo "🔧 Suggested boot flag:"
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

echo "✅ [pve-postinstall] Script complete."
$DRY_RUN && echo "🧪 Dry run mode: no changes were made."
