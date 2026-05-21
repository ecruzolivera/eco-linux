#!/usr/bin/env bash

function run {
  if command -v "$1" >/dev/null 2>&1 && ! pgrep -f "$1" >/dev/null; then
    "$@" &
  fi
}
