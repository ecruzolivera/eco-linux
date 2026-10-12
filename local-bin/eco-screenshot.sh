#!/bin/bash
# Niri-compatible screenshot: capture immediately → satty editor
# Captures first (no UI) so focus never leaves comboboxes/popups.
#
# Usage: eco-screenshot.sh [screen|all|region] [edit|copy|save] [--editor=<name>]
#   screen  — focused output only (default)
#   all     — all outputs combined
#   region  — select region with slurp
#   edit    — captures → opens satty for crop/annotate (default)
#   copy    — captures → clipboard, no file saved
#   save    — captures → save to output dir

[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs

PICTURES_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}"
OUTPUT_DIR="${OMARCHY_SCREENSHOT_DIR:-$PICTURES_DIR/Screenshots}"

if [[ ! -d $OUTPUT_DIR ]]; then
  mkdir -p "$OUTPUT_DIR"
  notify-send "Created screenshot directory: $OUTPUT_DIR" -u normal -t 2000
fi

SCREENSHOT_EDITOR="${OMARCHY_SCREENSHOT_EDITOR:-satty}"

ARGS=()
for arg in "$@"; do
  if [[ $arg == --editor=* ]]; then
    SCREENSHOT_EDITOR="${arg#--editor=}"
  else
    ARGS+=("$arg")
  fi
done
set -- "${ARGS[@]}"

MODE="${1:-screen}"
PROCESSING="${2:-edit}"

FILENAME="screenshot-$(date +'%Y-%m-%d_%H-%M-%S').png"
FILEPATH="$OUTPUT_DIR/$FILENAME"

# Captures immediately, before any window creation or focus change.
case "$MODE" in
screen)
  GEOMETRY=$(niri msg -j focused-output | jq -r '.logical | "\(.x),\(.y) \(.width)x\(.height)"') || exit 1
  grim -g "$GEOMETRY" "$FILEPATH" || exit 1
  ;;
  all)
    grim "$FILEPATH" || exit 1
    ;;
  region)
    grim -g "$(slurp -c '#ff0000ff')" "$FILEPATH" || exit 1
    ;;
  *)
  echo "Usage: $0 [screen|all|region] [edit|copy|save] [--editor=<name>]" >&2
  exit 1
  ;;
esac

case "$PROCESSING" in
edit)
  wl-copy <"$FILEPATH"

  if [[ $SCREENSHOT_EDITOR == "satty" ]]; then
    if [[ $MODE == "region" ]]; then
      satty --filename "$FILEPATH" --output-filename "$FILEPATH"
    else
      satty --filename "$FILEPATH" --output-filename "$FILEPATH" --initial-tool crop
    fi
  else
    $SCREENSHOT_EDITOR "$FILEPATH"
  fi

  echo "$FILEPATH"
  ;;
copy)
  wl-copy <"$FILEPATH"
  rm -f "$FILEPATH"
  ;;
save)
  echo "$FILEPATH"
  ;;
*)
  echo "Usage: $0 [screen|all|region] [edit|copy|save] [--editor=<name>]" >&2
  exit 1
  ;;
esac
