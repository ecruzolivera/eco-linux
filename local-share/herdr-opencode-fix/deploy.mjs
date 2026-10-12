import { createHash } from "node:crypto";
import { chmod, copyFile, mkdir, readFile, rename, stat, unlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const target = join(process.env.XDG_CONFIG_HOME ?? join(homedir(), ".config"), "opencode", "herdr-tui-session.js");
const mode = process.argv[2];
if (!["--check", "--apply", "--rollback"].includes(mode)) {
  console.error("Usage: node deploy.mjs --check | --apply | --rollback");
  process.exitCode = 2;
} else {
  const original = await readFile(join(root, "upstream", "herdr-tui-session.js"));
  const patched = await readFile(join(root, "source", "herdr-tui-session.js"));
  const installed = await readFile(target);
  const metadata = JSON.parse(await readFile(join(root, "metadata.json"), "utf8"));
  const hash = (content) => createHash("sha256").update(content).digest("hex");
  if (hash(original) !== metadata.upstreamSHA256) throw new Error("The recorded upstream source has changed.");
  if (hash(patched) !== metadata.patchedSHA256) throw new Error("Patched source differs from the verified version; rerun validation before deploying.");
  const current = hash(installed);
  if (![hash(original), hash(patched), metadata.previousPatchedSHA256].includes(current)) {
    throw new Error("Installed integration differs from both known versions; review it before deploying.");
  }
  if (mode === "--check") {
    console.log(current === hash(patched) ? "Patched integration is installed." :
      current === hash(original) ? "Original v13 integration is installed; patch can be applied." :
      "Known earlier patch is installed; the verified update can be applied.");
  } else {
    const replacement = mode === "--rollback" ? original : patched;
    if (current === hash(replacement)) {
      console.log("Requested integration version is already installed.");
    } else {
      const stamp = new Date().toISOString().replaceAll(/[:.]/g, "-");
      const backup = join(homedir(), ".config", "opencode-migration-backups", `herdr-patch-${stamp}`);
      await mkdir(backup, { recursive: true, mode: 0o700 });
      await copyFile(target, join(backup, "herdr-tui-session.js"));
      const temporary = `${target}.patch-${process.pid}`;
      const permissions = (await stat(target)).mode & 0o777;
      try {
        await writeFile(temporary, replacement, { flag: "wx", mode: permissions });
        await chmod(temporary, permissions);
        if (hash(await readFile(target)) !== current) throw new Error("Installed integration changed during deployment; refusing to overwrite it.");
        await rename(temporary, target);
      } finally {
        await unlink(temporary).catch((error) => { if (error.code !== "ENOENT") throw error; });
      }
      console.log(`${mode === "--rollback" ? "Restored upstream" : "Deployed patched"} integration: ${target}`);
      console.log(`Backup: ${backup}`);
    }
  }
}
