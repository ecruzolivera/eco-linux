#!/usr/bin/env python3
"""Validate payloads and exercise only 07-copy-config.sh in disposable homes."""

import argparse
import hashlib
import json
import os
import re
import shutil
import stat
import subprocess
import tempfile
import tomllib
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
PAYLOADS = {
    "xdg-config": ".config",
    "home-root-config": ".",
    "local-bin": ".local/bin",
    "local-share": ".local/share",
}
TEMPLATED = {
    ".config/niri/envs.kdl",
    ".config/niri/dms/binds.kdl",
    ".config/herdr/plugins/local/eco-ws-number/herdr-plugin.toml",
}


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def run(command, **kwargs):
    result = subprocess.run(command, capture_output=True, text=True, **kwargs)
    require(result.returncode == 0,
            f"Command failed: {command[0]}\n{result.stderr or result.stdout[-2000:]}")
    return result


def files(root):
    return sorted(p for p in root.rglob("*") if p.is_file() or p.is_symlink())


def fingerprint(path):
    if not os.path.lexists(path):
        return {"type": "absent"}
    info = path.lstat()
    if path.is_symlink():
        return {"type": "symlink", "target": os.readlink(path)}
    if path.is_dir():
        return {"type": "directory", "mode": stat.S_IMODE(info.st_mode)}
    return {"type": "file", "mode": stat.S_IMODE(info.st_mode),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def jsonc(text):
    # Preserve quoted strings while stripping JSONC comments/trailing commas.
    string = r'"(?:\\.|[^"\\])*"'
    text = re.sub(string + r'|//[^\n]*|/\*[\s\S]*?\*/',
                  lambda m: m[0] if m[0].startswith('"') else " ", text)
    text = re.sub(string + r'|,\s*(?=[}\]])',
                  lambda m: m[0] if m[0].startswith('"') else "", text)
    return json.loads(text)


def validate_payloads():
    require(jsonc('{"url":"https://example.test/",/* comment */"text":",}",}') ==
            {"url": "https://example.test/", "text": ",}"}, "JSONC parser mishandles strings")
    forbidden_names = {"service.json", "auth.json", "opencode-notifier-state.json", "plugins.json"}
    credentials = re.compile(
        r"sk-[A-Za-z0-9_-]{16,}|gh[pousr]_[A-Za-z0-9_]{16,}|"
        r"Bearer\s+[A-Za-z0-9._-]{16,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----",
        re.IGNORECASE,
    )
    config_count = 0
    for group in PAYLOADS:
        for path in files(REPO / group):
            relative = path.relative_to(REPO)
            require(not set(relative.parts) & {".git", "node_modules", "target", "__pycache__"},
                    f"Runtime/build metadata in payload: {relative}")
            require(path.name not in forbidden_names and not path.name.endswith((".bak", ".log", ".lock"))
                    and ".backup" not in path.name, f"Runtime/backup file in payload: {relative}")
            if path.is_symlink():
                continue
            try:
                text = path.read_text()
            except UnicodeDecodeError:
                continue
            require(not credentials.search(text), f"Possible credential in {relative}; values suppressed")
            if group == "xdg-config" and path.suffix in {".json", ".jsonc", ".toml"}:
                jsonc(text) if path.suffix != ".toml" else tomllib.loads(text)
                config_count += 1
            if path.suffix in {".js", ".mjs"} and shutil.which("node"):
                run(["node", "--check", str(path)])
    for path in [REPO / "install.sh", *files(REPO / "scripts"), *files(REPO / "local-bin")]:
        run(["bash", "-n", str(path)])
    for name in [".bashrc", ".profile"]:
        run(["bash", "-n", str(REPO / "home-root-config" / name)])
    if shutil.which("zsh"):
        run(["zsh", "-n", str(REPO / "home-root-config/.zshrc")])
    for name in ["home-root-config/.zshenv", "xdg-config/opencode/opencode.json", "xdg-config/opencode/skills"]:
        require(not (REPO / name).exists(), f"Retired payload reappeared: {name}")
    config = jsonc((REPO / "xdg-config/opencode/opencode.jsonc").read_text())
    require(isinstance(config["permissions"], list) and "servers" in config["mcp"], "Not native V2 config")
    cli = jsonc((REPO / "xdg-config/opencode/cli.json").read_text())
    require(cli["plugins"] == ["./herdr-opencode"], "Herdr CLI entrypoint is missing")
    require((REPO / "xdg-config/opencode/herdr-opencode/tui.js").is_file(), "Missing Herdr entrypoint")
    helper = (REPO / "local-bin/eco-herdr-lib").read_text()
    require("opencode --port" not in helper and "opencode --continue" in helper,
            "Launcher regressed to fixed-port discovery")
    worktrunk = tomllib.loads((REPO / "xdg-config/worktrunk/config.toml").read_text())
    require("post-remove" in worktrunk and "pre-remove" not in worktrunk, "Worktrunk remove hook regressed")
    packages = (REPO / "scripts/03-packages.sh").read_text()
    for name in ["opencode-beta", "herdr-bin", "kitty", "slurp", "libnotify", "python", "procps-ng", "util-linux"]:
        require(re.search(rf"^\s+{re.escape(name)}\s*$", packages, re.MULTILINE), f"Missing package: {name}")
    print(f"PASS: {config_count} configuration documents, shell/JS syntax, exclusions, secrets and integration declarations.")


def copy_payload(home, payload_repo=REPO):
    env = {**os.environ, "HOME": str(home), "REAL_HOME": str(home),
           "USER_CONFIG": str(home / ".config"), "ECO_REPO": str(payload_repo)}
    for group, variable in [
        ("xdg-config", "INSTALLER_XDG_CONFIG_DIR"),
        ("home-root-config", "INSTALLER_HOME_ROOT_CONFIG_DIR"),
        ("local-bin", "INSTALLER_LOCAL_BIN_DIR"),
        ("local-share", "INSTALLER_LOCAL_SHARE_DIR"),
    ]:
        env[variable] = str(payload_repo / group)
    return run(["bash", "-euo", "pipefail", "-c", """
        info() { :; }
        phase() { :; }
        warn() { printf '%s\\n' "$*" >&2; }
        source "$ECO_REPO/scripts/07-copy-config.sh"
    """], env=env, cwd=home)


def verify_copied(home, payload_repo=REPO):
    for group, destination in PAYLOADS.items():
        for source in files(payload_repo / group):
            target = home / destination / source.relative_to(payload_repo / group)
            require(os.path.lexists(target), f"Missing copied payload: {target}")
            if source.is_symlink():
                require(target.is_symlink() and os.readlink(source) == os.readlink(target), f"Symlink mismatch: {target}")
                continue
            expected = source.read_bytes()
            if str(target.relative_to(home)) in TEMPLATED:
                expected = expected.replace(b"__HOME__", str(home).encode())
            require(target.read_bytes() == expected, f"Rendered payload mismatch: {target}")
            mode = stat.S_IMODE(source.stat().st_mode)
            if target == home / ".config/opencode/cli.json":
                mode = 0o600
            if source.is_relative_to(payload_repo / "xdg-config/yazi/plugins"):
                mode = 0o444
            require(stat.S_IMODE(target.stat().st_mode) == mode, f"Permission mismatch: {target}")
    for name in [".config/opencode/opencode.json", ".zshenv", ".config/opencode/skills"]:
        require(not (home / name).exists(), f"Retired path recreated on clean install: {name}")
    for path in files(home / ".config"):
        if path.suffix in {".json", ".jsonc", ".toml"}:
            jsonc(path.read_text()) if path.suffix != ".toml" else tomllib.loads(path.read_text())
    niri = home / ".config/niri/config.kdl"
    for optional, include in re.findall(r'^include\s+(optional=true\s+)?"([^"]+)"', niri.read_text(), re.MULTILINE):
        require(optional or (niri.parent / include).is_file(), f"Missing required Niri include: {include}")
    for name in ["alttab", "colors", "layout", "outputs"]:
        require(f'include optional=true "dms/{name}.kdl"' in niri.read_text(), f"DMS first-boot include required: {name}")
    if shutil.which("niri"):
        run(["niri", "validate", "--config", str(niri)], env={**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config")})
    references = set()
    for path in (home / ".config/niri").rglob("*.kdl"):
        references.update(re.findall(r'spawn\s+"(?:[^"\n]*/)?(eco-[A-Za-z0-9_.-]+)"', path.read_text()))
    herdr = tomllib.loads((home / ".config/herdr/config.toml").read_text())
    references.update(entry["command"] for entry in herdr["keys"]["command"] if entry["command"].startswith("eco-"))
    plugin = tomllib.loads((home / ".config/herdr/plugins/local/eco-ws-number/herdr-plugin.toml").read_text())
    for group in ["startup", "events", "actions"]:
        for entry in plugin[group]:
            command = Path(entry["command"][0])
            require(command.is_relative_to(home) and os.access(command, os.X_OK), f"Missing local plugin command: {command}")
    references.add("eco-herdr-lib")
    for name in references:
        require(os.access(home / ".local/bin" / name, os.X_OK), f"Missing/non-executable referenced helper: {name}")
    if shutil.which("node"):
        run(["node", str(home / ".local/share/herdr-opencode-fix/deploy.mjs"), "--check"],
            env={**os.environ, "HOME": str(home), "XDG_CONFIG_HOME": str(home / ".config")})


def verify_live_snapshot(manifest):
    snapshot = json.loads(manifest.read_text())
    home = Path.home()
    for name, expected in snapshot["liveBefore"].items():
        require(fingerprint(home / name) == expected, f"Live path changed: ~/{name}")
    for destination, source in snapshot["mapping"].items():
        live = home / source
        target = REPO / destination
        if live.is_symlink():
            require(fingerprint(target) == fingerprint(live), f"Captured symlink differs: {destination}")
            continue
        expected = live.read_bytes()
        for old, new in snapshot["replacements"].get(destination, []):
            expected = expected.replace(old.encode(), new.encode())
        require(target.read_bytes() == expected, f"Payload differs from authoritative live file: {destination}")
        require(stat.S_IMODE(target.stat().st_mode) == stat.S_IMODE(live.stat().st_mode),
                f"Payload mode differs from live source: {destination}")
    for name, expected in snapshot["repoProtected"].items():
        require(fingerprint(REPO / name) == expected, f"Unrelated system/project configuration changed: {name}")
    require(run(["chezmoi", "status"]).stdout == snapshot["chezmoiStatusBefore"], "Chezmoi status changed")
    require(run(["git", "status", "--porcelain=v1", "--untracked-files=all"],
                cwd=home / ".local/share/chezmoi").stdout == snapshot["chezmoiGitBefore"], "Chezmoi source changed")
    require(run(["git", "rev-parse", "HEAD"], cwd=REPO).stdout.strip() == snapshot["gitHead"], "Unexpected commit")
    require(not run(["git", "diff", "--cached", "--name-only"], cwd=REPO).stdout, "Unexpected staging")
    print(f"PASS: {len(snapshot['mapping'])} payloads match live sources with declared adjustments; "
          f"{len(snapshot['liveBefore'])} live fingerprints, chezmoi and protected repository files unchanged.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live-manifest", type=Path, help="Optional private pre-capture snapshot for live-file comparison")
    args = parser.parse_args()
    validate_payloads()
    parent = Path("/tmp/opencode")
    with tempfile.TemporaryDirectory(prefix="eco-bootstrap-test-", dir=parent if parent.is_dir() else None) as directory:
        root = Path(directory)
        if shutil.which("nvim"):
            home = root / "nvim-test-home"
            home.mkdir()
            result = run(["nvim", "--headless", "-u", "NONE", "-i", "NONE", "-l", str(REPO / "tests/verify-nvim.lua")],
                         env={**os.environ, "HOME": str(home), "ECO_REPO": str(REPO),
                              "XDG_CONFIG_HOME": str(home / ".config"), "XDG_DATA_HOME": str(home / ".local/share"),
                              "XDG_STATE_HOME": str(home / ".local/state"), "XDG_CACHE_HOME": str(home / ".cache")}, timeout=30)
            print((result.stdout + result.stderr).strip())
        else:
            print("SKIP: Neovim/Lua checks (nvim is not installed).")
        for label in ["normal-home", "home with spaces & pipe|test"]:
            home = root / label
            home.mkdir()
            copy_payload(home)
            verify_copied(home)
            before = {str(p.relative_to(home)): fingerprint(p) for p in files(home)}
            copy_payload(home)
            after = {str(p.relative_to(home)): fingerprint(p) for p in files(home)}
            require(before == after, "Repeated copy is not idempotent")
        print("PASS: Clean homes, spaces/ampersand/delimiter substitution, Niri validation, permissions and copy idempotence.")
        # Simulate a Git checkout: only executable/non-executable file modes
        # survive cloning. Private and read-only modes must come from the module.
        release = root / "release-payload"
        for group in [*PAYLOADS, "scripts"]:
            shutil.copytree(REPO / group, release / group)
            for path in files(release / group):
                if not path.is_symlink():
                    path.chmod(0o755 if path.stat().st_mode & 0o111 else 0o644)
        home = root / "release-home"
        home.mkdir()
        copy_payload(home, release)
        verify_copied(home, release)
        print("PASS: Git-checkout mode simulation restores private CLI and read-only Yazi modes.")
        home = root / "existing-home"
        home.mkdir()
        existing = [".config/opencode/opencode.json", ".zshenv", ".config/opencode/skills/custom/SKILL.md", ".config/nvim/lua/plugins/user-extra.lua"]
        for name in existing:
            path = home / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("existing user content\n")
        before = {name: fingerprint(home / name) for name in existing}
        external = root / "outside-home-sentinel"
        external.write_text("must not be overwritten through a symlink\n")
        before_external = fingerprint(external)
        cli = home / ".config/opencode/cli.json"
        cli.symlink_to(external)
        result = copy_payload(home)
        require(all(fingerprint(home / name) == info for name, info in before.items()), "Existing unrelated or legacy content was deleted")
        require(result.stderr.count("Legacy path preserved:") == 3, "Legacy conflicts were not reported")
        require(not cli.is_symlink() and fingerprint(external) == before_external, "Copy followed a destination file symlink")
        print("PASS: Existing-home overlay preserves user/legacy files, reports conflicts and does not follow destination file symlinks.")
    if args.live_manifest:
        verify_live_snapshot(args.live_manifest)


if __name__ == "__main__":
    main()
