#!/usr/bin/env bash
#
# eco-delink.sh
# Usage: ./eco-delink.sh /path/to/directory
#
# Recursively replaces every symlink in the given directory (and subdirs)
# with a copy of the file/dir it points to.
# Preserves permissions, timestamps, etc. as much as possible.
# Skips broken symlinks (prints a warning).
# DANGEROUS: makes irreversible changes — BACKUP FIRST!

set -euo pipefail

# ── Guard: must be executed, not sourced ───────────────────────────────────────
#
# If sourced from zsh/bash, $0 will be the shell name (e.g. "zsh", "bash",
# "-zsh", "-bash") rather than this script's path.
# Sourcing is dangerous here: `exit` would kill the user's shell session.
#
_script_name=$(basename -- "$0")
if [[ "$_script_name" == "zsh" || "$_script_name" == "-zsh" ||
  "$_script_name" == "bash" || "$_script_name" == "-bash" ||
  "$_script_name" == "sh" || "$_script_name" == "-sh" ]]; then
  printf 'Error: Do not source this script — execute it instead.\n' >&2
  printf '  Wrong : source %s\n' "$0" >&2
  printf '  Right : bash %s <directory>\n' "$0" >&2
  printf '  Right : chmod +x %s && %s <directory>\n' "$0" "$0" >&2
  return 1 # `return` (not `exit`) so we don't kill the calling shell
fi

# ── Helpers ────────────────────────────────────────────────────────────────────

log() { printf '%s\n' "$*"; }
warn() { printf 'Warning: %s\n' "$*" >&2; }
err() { printf 'Error: %s\n' "$*" >&2; }

# ── Argument validation ────────────────────────────────────────────────────────

if [[ $# -ne 1 ]]; then
  err "Wrong number of arguments."
  log "Usage: $0 <directory>"
  log "Example: $0 ~/.config/nvim"
  exit 1
fi

TARGET_DIR="$1"

if [[ ! -d "$TARGET_DIR" ]]; then
  err "'$TARGET_DIR' is not a directory."
  exit 1
fi

# Convert to absolute path (without resolving symlinks in the path itself)
TARGET_DIR=$(realpath -m -- "$TARGET_DIR")

# ── Confirmation prompt ────────────────────────────────────────────────────────

log "Processing directory: $TARGET_DIR"
log "This will REPLACE all symlinks with real copies of their targets."
log "This operation is IRREVERSIBLE — make a backup first!"
log ""

# Explicitly read from /dev/tty so the prompt always goes to the terminal,
# even if stdin has been redirected (e.g. piped or sourced).
printf 'Continue? (y/N) '
read -r reply </dev/tty || {
  err "Could not read from terminal."
  exit 1
}

log ""

if [[ ! "$reply" =~ ^[Yy]$ ]]; then
  log "Aborted."
  exit 0
fi

# ── Main loop ──────────────────────────────────────────────────────────────────

success_count=0
skipped_count=0
error_count=0

while IFS= read -r -d '' link; do
  # Resolve the absolute target path
  if ! target=$(readlink -f -- "$link" 2>/dev/null) || [[ -z "$target" ]]; then
    warn "Broken or unresolvable symlink (skipping): $link"
    ((skipped_count++)) || true
    continue
  fi

  # Guard against a symlink pointing inside TARGET_DIR to avoid nested copies
  if [[ "$target" == "$TARGET_DIR"* ]]; then
    warn "Target is inside the same tree — may cause nested copies (skipping): $link → $target"
    ((skipped_count++)) || true
    continue
  fi

  log "Dereferencing: $link  →  $target"

  # Copy to a temp path first so $link is never left in a half-replaced state
  tmp="${link}.dereference_tmp_$$"

  if cp -a -- "$target" "$tmp"; then
    rm -f -- "$link"
    mv -- "$tmp" "$link"
    log "  ✓ replaced OK"
    ((success_count++)) || true
  else
    err "Failed to copy $target → $link (symlink left untouched)"
    rm -f -- "$tmp" 2>/dev/null || true
    ((error_count++)) || true
  fi

done < <(find "$TARGET_DIR" -type l -print0)

# ── Summary ────────────────────────────────────────────────────────────────────

log ""
log "Done."
log "  Replaced : $success_count"
log "  Skipped  : $skipped_count"
log "  Errors   : $error_count"
log ""
log "Review changes first with: chezmoi diff"
log "Then add them:             chezmoi add --exact $TARGET_DIR"
