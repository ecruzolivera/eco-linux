#!/usr/bin/env bash

SAVE_DIR="$HOME/Videos"
mkdir -p "$SAVE_DIR"
FILE="$SAVE_DIR/$(date +'%Y-%m-%d_%H-%M-%S').mkv"

# Parse command line arguments
SILENT=false
while [[ $# -gt 0 ]]; do
  case $1 in
  --silent)
    SILENT=true
    shift
    ;;
  *)
    echo "Unknown option: $1"
    echo "Usage: $0 [--silent]"
    exit 1
    ;;
  esac
done

# ── Stop if already recording ──────────────────────────────────────────────
if pgrep -x wf-recorder >/dev/null; then

  notify-send "Stopping recording"

  pkill -INT wf-recorder

  # Wait up to 3 seconds for graceful shutdown
  for _ in {1..15}; do
    pgrep -x wf-recorder >/dev/null || break
    sleep 0.2
  done

  # Force kill if still running (prevents infinite loops with stuck processes)
  if pgrep -x wf-recorder >/dev/null; then
    pkill -9 wf-recorder
    sleep 0.5
  fi

  # Get the latest recorded file using find and sort by modification time
  LATEST=$(find "$SAVE_DIR" -maxdepth 1 -type f -name '*.mkv' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)

  if [[ ! -f "$LATEST" ]]; then
    notify-send -u critical "Error" "Recorded file not found!"
    exit 1
  else
    # Copy the file path to clipboard as text
    echo "$FILE" | wl-copy
  fi

  # Also try to open the file location in file manager for easy drag-and-drop
  if command -v xdg-open >/dev/null; then
    xdg-open "$(dirname "$LATEST")" &
  fi

  # Signal waybar to update
  pkill -RTMIN+8 waybar 2>/dev/null || true

  exit 0
fi

# ── Pick region ────────────────────────────────────────────────────────────
REGION=$(slurp) || exit 1

if [[ "$SILENT" == false ]]; then
  # ── Choose which ONE source to record ──────────────────────────────────────
  MIC_SRC=$(pactl info | awk -F': ' '/Default Source/ {print $2}')
  SILENT_SRC="$MIC_SRC"
  DESC=$(pactl list sources | awk -v s="$SILENT_SRC" '$2==s {getline;sub(/^\s*Description: /,"");print;exit}')

  notify-send "Recording… (source: $DESC)" --expire-time=1000

  wf-recorder -g "$REGION" --audio --audio-device "$SILENT_SRC" -f "$FILE" &
else
  notify-send "Recording… (silent mode)" --expire-time=1000

  wf-recorder -g "$REGION" -f "$FILE" &
fi

# Signal waybar to update
pkill -RTMIN+8 waybar 2>/dev/null || true
