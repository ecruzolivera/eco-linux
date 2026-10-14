#!/bin/bash
set -Eeuo pipefail
[[ $(id -u) != 0 ]] || { printf 'User bootstrap refuses root\n' >&2; exit 1; }
REPO=${1:?Repository path required}
[[ $REPO == /* ]] || { printf 'Absolute repository path required\n' >&2; exit 1; }
cd "$HOME"
export PATH="$HOME/.local/bin:/usr/bin:/bin"
export XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache"
state=$HOME/.local/state/eco-linux
mkdir -p "$state"
chmod 0700 "$state"
report=$state/user-setup.txt
stage=runtime-installation
expected_lock=
trap 'code=$?; if ((code)); then printf "INCOMPLETE: %s (exit %s)\n" "$stage" "$code" >> "$report"; fi; [[ -z $expected_lock ]] || rm -f -- "$expected_lock"' EXIT
printf 'User bootstrap started %s\n' "$(date -Iseconds)" > "$report"
mkdir -p "$HOME/Work/Personal" "$HOME/Work/Forme"
mise trust "$HOME/.config/mise/config.toml"
timeout 1800 mise install
runtime_environment=$(mise env --shell bash)
eval "$runtime_environment"
for tool in java javac node npm npx bun go; do
  command -v "$tool" >/dev/null || { printf 'Missing runtime command: %s\n' "$tool" >&2; exit 1; }
done
java_version=$(java -version 2>&1)
[[ $java_version == *'"21.'* ]] || { printf 'Temurin Java 21 is required\n' >&2; exit 1; }
export JAVA_HOME
JAVA_HOME=$(mise where java)
java -version 2>> "$report"
node --version >> "$report"
bun --version >> "$report"
go version >> "$report"
stage=rust-toolchain
# The reviewed git-status plugin builds with Cargo, including in the core profile.
rustup show active-toolchain >/dev/null 2>&1 || timeout 300 rustup default stable
# The Neovim Rust pack starts rust-analyzer directly, outside Mason.
timeout 900 rustup component add rust-analyzer rust-src
timeout 60 rust-analyzer --version >> "$report"
stage=neovim-restoration
timeout 60 python3 "$REPO/lib/check-nvim-worktrees.py"
expected_lock=$(mktemp "$state/nvim-lock.XXXXXXXX")
cp "$HOME/.config/nvim/lazy-lock.json" "$expected_lock"
timeout 1200 nvim --headless '+Lazy! restore' '+qa'
ECO_REPO="$REPO" ECO_NVIM_LOCK_FILE="$expected_lock" timeout 1200 nvim --headless '+lua dofile(vim.env.ECO_REPO .. "/lib/bootstrap-nvim.lua")'
stage=ltex-verification
timeout 60 "$HOME/.local/share/nvim/mason/bin/ltex-ls-plus" --version >> "$report" 2>&1
stage=integration-version-check
herdr_version=$(herdr --version)
opencode_version=$(opencode --version)
[[ $herdr_version == 'herdr 0.9.3' && $opencode_version == 'opencode v2.0.26' ]] || {
  printf 'Unreviewed integration versions: %s / %s\n' "$herdr_version" "$opencode_version" >&2
  exit 1
}
stage=herdr-plugins
timeout 600 python3 "$REPO/lib/bootstrap-herdr.py"
stage=herdr-patch
timeout 120 node "$HOME/.local/share/herdr-opencode-fix/deploy.mjs" --check
timeout 120 node "$HOME/.local/share/herdr-opencode-fix/deploy.mjs" --apply
stage=command-coverage
timeout 120 python3 "$REPO/tests/package-coverage.py" --profile "${ECO_APPS:-personal}" --commands >> "$report"
printf 'PASS: runtime/editor/integration bootstrap. Sign in to accounts separately; restore data and licensed apps manually.\n' >> "$report"
cat "$report"
