#!/bin/bash

# USB Drive Formatter to exFAT (32KB cluster size)
# Author: Script for formatting USB drives safely
# Date: 2025-12-08

set -e # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_color() {
  printf "${1}${2}${NC}\n"
}

# Function to check if running as root
check_root() {
  if [[ $EUID -ne 0 ]]; then
    return 1
  fi
  return 0
}

# Function to check required dependencies (non-root)
check_dependencies_basic() {
  local missing_deps=()

  # Check for required commands that don't need root
  for cmd in lsblk; do
    if ! command -v "$cmd" &>/dev/null; then
      missing_deps+=("$cmd")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    print_color $RED "Missing required dependencies:"
    for dep in "${missing_deps[@]}"; do
      echo "  - $dep"
    done
    print_color $YELLOW "Please install missing packages:"
    print_color $YELLOW "  Ubuntu/Debian: sudo apt install util-linux"
    print_color $YELLOW "  CentOS/RHEL: sudo yum install util-linux"
    print_color $YELLOW "  Arch: sudo pacman -S util-linux"
    exit 1
  fi
}

# Function to check formatting dependencies (root required)
check_dependencies_format() {
  local missing_deps=()

  # Check for required commands for formatting
  for cmd in fdisk mkfs.exfat; do
    if ! command -v "$cmd" &>/dev/null; then
      missing_deps+=("$cmd")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    print_color $RED "Missing required dependencies for formatting:"
    for dep in "${missing_deps[@]}"; do
      echo "  - $dep"
    done
    print_color $YELLOW "Please install missing packages:"
    print_color $YELLOW "  Ubuntu/Debian: sudo apt install util-linux exfatprogs"
    print_color $YELLOW "  CentOS/RHEL: sudo yum install util-linux exfatprogs"
    print_color $YELLOW "  Arch: sudo pacman -S util-linux exfatprogs"
    exit 1
  fi
}

# Function to get removable drives (works without root)
get_removable_drives() {
  print_color $BLUE "Scanning for removable drives..."

  # Get removable drives using lsblk
  mapfile -t drives < <(lsblk -d -o NAME,SIZE,MODEL,TRAN -n 2>/dev/null | grep -E "(usb)" | awk '{print $1}')

  if [[ ${#drives[@]} -eq 0 ]]; then
    # Fallback: check for drives in /sys/block that are removable
    for device_path in /sys/block/sd*; do
      if [[ -d "$device_path" ]]; then
        device_name=$(basename "$device_path")
        if [[ -f "$device_path/removable" ]] && [[ $(cat "$device_path/removable" 2>/dev/null) == "1" ]]; then
          # Verify the device actually exists in /dev
          if [[ -b "/dev/$device_name" ]]; then
            drives+=("$device_name")
          fi
        fi
      fi
    done
  fi

  echo "${drives[@]}"
}

# Function to display drive information (works without root)
display_drives() {
  local drives=("$@")

  if [[ ${#drives[@]} -eq 0 ]]; then
    print_color $RED "No removable drives found!"
    print_color $YELLOW "Please ensure your USB drive is connected and try again."
    print_color $YELLOW "Note: Some drives may only be detected when running with sudo privileges."
    exit 1
  fi

  print_color $GREEN "Found ${#drives[@]} removable drive(s):"
  echo
  printf "%-4s %-12s %-10s %-20s %-10s %s\n" "No." "Device" "Size" "Model" "Transport" "Mount Points"
  printf "%-4s %-12s %-10s %-20s %-10s %s\n" "---" "--------" "--------" "----------------" "---------" "-------------"

  for i in "${!drives[@]}"; do
    local drive="${drives[$i]}"
    local device="/dev/$drive"

    # Get drive information
    local size=$(lsblk -d -o SIZE -n "$device" 2>/dev/null || echo "Unknown")
    local model=$(lsblk -d -o MODEL -n "$device" 2>/dev/null | tr -s ' ' || echo "Unknown")
    local tran=$(lsblk -d -o TRAN -n "$device" 2>/dev/null || echo "Unknown")
    local mountpoints=$(lsblk -o MOUNTPOINT -n "$device" 2>/dev/null | grep -v "^$" | tr '\n' ' ' || echo "Not mounted")

    printf "%-4s %-12s %-10s %-20s %-10s %s\n" "$((i + 1))" "$device" "$size" "$model" "$tran" "$mountpoints"
  done
  echo
}

# Function to unmount all partitions on a drive (requires root)
unmount_drive() {
  local device="$1"

  print_color $YELLOW "Unmounting all partitions on $device..."

  # Find all mounted partitions on this drive
  local partitions=$(lsblk -o NAME,MOUNTPOINT -n "$device" | grep -E "${device##*/}[0-9]+" | awk '$2 != "" {print "/dev/"$1}')

  if [[ -n "$partitions" ]]; then
    while IFS= read -r partition; do
      if [[ -n "$partition" ]]; then
        print_color $YELLOW "  Unmounting $partition..."
        umount "$partition" 2>/dev/null || true
      fi
    done <<<"$partitions"
  fi

  # Give the system a moment to process
  sleep 1
}

# Function to confirm formatting
confirm_format() {
  local device="$1"

  print_color $RED "WARNING: This will COMPLETELY ERASE all data on $device!"
  print_color $RED "This action is IRREVERSIBLE!"
  echo

  # Show current partition table (try without root first)
  print_color $BLUE "Current partition table for $device:"
  if fdisk -l "$device" 2>/dev/null | grep -E "(Disk|Device|^/dev)" >/dev/null 2>&1; then
    fdisk -l "$device" 2>/dev/null | grep -E "(Disk|Device|^/dev)" || echo "No partition table found"
  else
    echo "Cannot read partition table without root privileges"
  fi
  echo

  print_color $YELLOW "Please type 'YES' (all uppercase) to confirm formatting:"
  read -r confirmation

  if [[ "$confirmation" != "YES" ]]; then
    print_color $RED "Operation cancelled."
    exit 0
  fi
}

# Function to request sudo and restart with privileges
request_sudo_and_restart() {
  local device="$1"
  local label="$2"

  print_color $BLUE "Root privileges are required for formatting operations."
  print_color $YELLOW "The script will now request sudo access..."
  echo

  # Export the device and label for the elevated process
  export FORMAT_DEVICE="$device"
  export FORMAT_LABEL="$label"
  export FORMAT_MODE="true"

  # Restart script with sudo
  exec sudo -E "$0" "$@"
}

# Function to format drive (requires root)
format_drive() {
  local device="$1"
  local label="$2"

  print_color $BLUE "Starting format process for $device..."

  # Create new partition table
  print_color $YELLOW "Creating new partition table..."
  (
    echo o # Create new empty DOS partition table
    echo n # Create new partition
    echo p # Primary partition
    echo 1 # Partition number 1
    echo   # Default first sector
    echo   # Default last sector (use entire disk)
    echo t # Change partition type
    echo c # Set to W95 FAT32 (LBA)
    echo w # Write changes
  ) | fdisk "$device" >/dev/null 2>&1

  # Wait for partition to be recognized
  sleep 2
  partprobe "$device" 2>/dev/null || true
  sleep 2

  # Determine partition device
  local partition="${device}1"
  if [[ ! -b "$partition" ]]; then
    # Some systems might use different naming
    local base_name=$(basename "$device")
    partition="/dev/${base_name}1"
  fi

  # Format with exFAT (32KB cluster size)
  print_color $YELLOW "Formatting $partition with exFAT (32KB cluster size)..."

  # Use 32KB (32768 bytes) cluster size
  if command -v mkfs.exfat &>/dev/null; then
    mkfs.exfat -s 64 -n "$label" "$partition" # -s 64 = 64 sectors * 512 bytes = 32KB
  elif command -v mkexfatfs &>/dev/null; then
    mkexfatfs -s 64 -n "$label" "$partition"
  else
    print_color $RED "No exFAT formatter found!"
    exit 1
  fi

  # Sync to ensure all data is written
  sync

  print_color $GREEN "✓ Successfully formatted $device as exFAT with label '$label'"
  print_color $GREEN "✓ Cluster size: 32KB"
  print_color $GREEN "✓ Ready to use!"
}

# Function to handle the formatting process (called with sudo)
handle_format_mode() {
  local device="$FORMAT_DEVICE"
  local label="$FORMAT_LABEL"

  print_color $BLUE "=== Formatting Mode (Running with Root Privileges) ==="
  echo

  # Check formatting dependencies
  check_dependencies_format

  # Unmount drive
  unmount_drive "$device"

  # Format drive
  format_drive "$device" "$label"

  print_color $GREEN "Formatting completed successfully!"

  # Show final information
  echo
  print_color $BLUE "Drive information after formatting:"
  lsblk "$device" -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT || true
}

# Main function
main() {
  # Check if we're in format mode (running with sudo after confirmation)
  if [[ "$FORMAT_MODE" == "true" ]]; then
    handle_format_mode
    exit 0
  fi

  print_color $BLUE "=== USB Drive Formatter to exFAT (32KB) ==="
  echo

  # Check basic dependencies (no root needed)
  check_dependencies_basic

  # Get removable drives (works without root)
  mapfile -t available_drives < <(get_removable_drives)

  # Display available drives
  display_drives "${available_drives[@]}"

  # Get user selection
  while true; do
    print_color $BLUE "Select drive number to format (1-${#available_drives[@]}), or 'q' to quit:"
    read -r selection

    if [[ "$selection" == "q" || "$selection" == "Q" ]]; then
      print_color $YELLOW "Operation cancelled."
      exit 0
    fi

    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#available_drives[@]}" ]]; then
      selected_drive="/dev/${available_drives[$((selection - 1))]}"
      break
    else
      print_color $RED "Invalid selection. Please enter a number between 1 and ${#available_drives[@]}."
    fi
  done

  # Get volume label
  print_color $BLUE "Enter volume label (or press Enter for 'USB_DRIVE'):"
  read -r volume_label
  if [[ -z "$volume_label" ]]; then
    volume_label="USB_DRIVE"
  fi

  # Confirm operation
  confirm_format "$selected_drive"

  # NOW request sudo and restart with privileges
  request_sudo_and_restart "$selected_drive" "$volume_label"
}

# Run main function
main "$@"
