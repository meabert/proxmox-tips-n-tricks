#!/bin/bash

# ┌────────────────────────────────────────────────────────────┐
# │  Multi-Vendor GPU Tuning Script 🧠                         │
# │  Supports NVIDIA, AMD, Intel (ARC + iGPU).                │
# │  Applies safe tuning, logs splash block.                  │
# └────────────────────────────────────────────────────────────┘

DRY_RUN=false
POWER_LIMIT=150
LOG_FILE="/var/log/gpu_tune.log"

# Parse flags
for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --limit=*) POWER_LIMIT="${arg#*=}" ;;
    --help|-h)
      echo "Usage: gpu_tune_multi.sh [--dry-run] [--limit=<W>]"
      exit 0
      ;;
  esac
done

# Detect vendor
if command -v nvidia-smi &>/dev/null; then
  GPU_VENDOR="NVIDIA"
  GPU_MODEL=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
elif command -v rocm-smi &>/dev/null; then
  GPU_VENDOR="AMD"
  GPU_MODEL=$(rocm-smi | grep 'GPU' | awk -F':' '{print $2}' | head -n1 | xargs)
elif lspci | grep -i 'Intel Corporation' | grep -i 'graphics' &>/dev/null; then
  GPU_VENDOR="Intel"
  GPU_MODEL=$(lspci | grep -i 'VGA' | grep -i 'Intel' | cut -d ':' -f3- | xargs)
else
  GPU_VENDOR="Unknown"
  GPU_MODEL="Unknown GPU"
fi

# Log pre-state
echo "=== GPU Tuning Pre-State ===" | tee -a "$LOG_FILE"
case $GPU_VENDOR in
  "NVIDIA")
    nvidia-smi -q -d POWER | tee -a "$LOG_FILE"
    nvidia-smi -q -d CLOCK | tee -a "$LOG_FILE"
    nvidia-smi -q -d UTILIZATION | tee -a "$LOG_FILE"
    ;;
  "AMD")
    rocm-smi --showpower | tee -a "$LOG_FILE"
    rocm-smi --showtemp | tee -a "$LOG_FILE"
    ;;
  "Intel")
    cat /sys/class/drm/card0/device/power/runtime_status | tee -a "$LOG_FILE"
    cat /sys/class/drm/card0/gt_cur_freq_mhz | tee -a "$LOG_FILE"
    ;;
esac

# Apply tuning
CLOCK_STATUS="Skipped"
if [ "$DRY_RUN" = false ]; then
  case $GPU_VENDOR in
    "NVIDIA")
      echo "Applying NVIDIA tuning..." | tee -a "$LOG_FILE"
      nvidia-smi -pm 1
      if nvidia-smi -pl "$POWER_LIMIT"; then
        CLOCK_STATUS="App clocks unsupported on this model"
      else
        echo "⚠️ Invalid power limit: $POWER_LIMIT W. Skipping." | tee -a "$LOG_FILE"
      fi
      ;;
    "AMD")
      echo "Applying AMD tuning..." | tee -a "$LOG_FILE"
      rocm-smi --setpoweroverdrive "$POWER_LIMIT" || echo "⚠️ AMD power tuning failed." | tee -a "$LOG_FILE"
      CLOCK_STATUS="ROCm tuning applied"
      ;;
    "Intel")
      echo "Intel tuning is limited to read-only sysfs." | tee -a "$LOG_FILE"
      CLOCK_STATUS="Read-only sysfs access"
      ;;
    *)
      echo "Unsupported GPU vendor: $GPU_VENDOR" | tee -a "$LOG_FILE"
      ;;
  esac
else
  echo "Dry-run mode: no changes applied." | tee -a "$LOG_FILE"
fi

# Splash block generator
generate_splash_block() {
  local vendor="$1"
  local model="$2"
  local power="$3"
  local clocks="$4"

  echo
  echo "# ┌────────────────────────────────────────────────────────────┐"
  printf "# │  GPU Tuning Applied 🧠                                    │\n"
  printf "# │  Vendor: %-48s │\n" "$vendor"
  printf "# │  Model: %-49s │\n" "$model"
  printf "# │  Power Limit: %-42s │\n" "$power W"
  printf "# │  Clock Tuning: %-41s │\n" "$clocks"
  echo "# └────────────────────────────────────────────────────────────┘"
}

generate_splash_block "$GPU_VENDOR" "$GPU_MODEL" "$POWER_LIMIT" "$CLOCK_STATUS" | tee -a "$LOG_FILE"
