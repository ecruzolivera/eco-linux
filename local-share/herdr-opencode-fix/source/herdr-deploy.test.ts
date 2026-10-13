import { afterEach, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { spawnSync } from "node:child_process";
import { chmod, copyFile, mkdir, mkdtemp, readFile, readdir, rename, rm, stat, writeFile } from "node:fs/promises";
import { join } from "node:path";

const directories: string[] = [];
afterEach(async () => {
  for (const directory of directories.splice(0)) await rm(directory, { recursive: true });
});
const hash = (content: string | Buffer) => createHash("sha256").update(content).digest("hex");

async function sandbox(installed: "upstream" | "previous" | "earlier" | "patched" | "unknown") {
  const home = await mkdtemp("/tmp/opencode/herdr-deploy-");
  directories.push(home);
  const root = join(home, "patch");
  const target = join(home, ".config/opencode/herdr-tui-session.js");
  const original = await readFile(new URL("../upstream/herdr-tui-session.js", import.meta.url));
  const patched = await readFile(new URL("./herdr-tui-session.js", import.meta.url));
  const previous = Buffer.from("// known previous patch\n");
  const earlier = Buffer.from("// known earlier patch\n");
  const unknown = Buffer.from("// unrelated user edit\n");
  for (const path of [join(root, "upstream"), join(root, "source"), join(home, ".config/opencode")]) {
    await mkdir(path, { recursive: true });
  }
  await copyFile(new URL("../deploy.mjs", import.meta.url), join(root, "deploy.mjs"));
  await writeFile(join(root, "upstream/herdr-tui-session.js"), original);
  await writeFile(join(root, "source/herdr-tui-session.js"), patched);
  await writeFile(join(root, "metadata.json"), JSON.stringify({
    upstreamSHA256: hash(original), patchedSHA256: hash(patched),
    previousPatchedSHA256: hash(earlier), previousPatchedSHA256s: [hash(previous)],
  }));
  await writeFile(target, { upstream: original, previous, earlier, patched, unknown }[installed], { mode: 0o600 });
  return {
    home, root, target, original, patched, previous, unknown,
    run(mode: string) {
      return spawnSync("node", [join(root, "deploy.mjs"), mode], {
        encoding: "utf8", env: { ...process.env, HOME: home, XDG_CONFIG_HOME: join(home, ".config") },
      });
    },
    async backups() {
      return readdir(join(home, ".config/opencode-migration-backups"));
    },
  };
}

test("deployment accepts recorded upstream and earlier patches only", async () => {
  for (const installed of ["upstream", "previous", "earlier"] as const) {
    const fixture = await sandbox(installed);
    expect(fixture.run("--check").status).toBe(0);
    expect(fixture.run("--apply").status).toBe(0);
    expect(await readFile(fixture.target)).toEqual(fixture.patched);
    expect((await stat(fixture.target)).mode & 0o777).toBe(0o600);
    expect(await fixture.backups()).toHaveLength(1);
  }
});

test("deployment backs up the exact previous patch and reapplication is inert", async () => {
  const fixture = await sandbox("previous");
  expect(fixture.run("--apply").status).toBe(0);
  const backups = await fixture.backups();
  const backupDirectory = join(fixture.home, ".config/opencode-migration-backups", backups[0]!);
  expect((await stat(backupDirectory)).mode & 0o777).toBe(0o700);
  expect(await readFile(join(backupDirectory, "herdr-tui-session.js"))).toEqual(fixture.previous);
  expect(fixture.run("--apply").status).toBe(0);
  expect(await fixture.backups()).toEqual(backups);
  expect(fixture.run("--check").status).toBe(0);
});

test("deployment refuses unfamiliar edits and tampered sources without replacement", async () => {
  const fixture = await sandbox("unknown");
  for (const mode of ["--check", "--apply", "--rollback"]) {
    expect(fixture.run(mode).status).not.toBe(0);
    expect(await readFile(fixture.target)).toEqual(fixture.unknown);
  }
  await writeFile(fixture.target, fixture.previous);
  await writeFile(join(fixture.root, "source/herdr-tui-session.js"), "// unverified patch\n");
  expect(fixture.run("--apply").status).not.toBe(0);
  expect(await readFile(fixture.target)).toEqual(fixture.previous);
  await writeFile(join(fixture.root, "source/herdr-tui-session.js"), fixture.patched);
  await writeFile(join(fixture.root, "upstream/herdr-tui-session.js"), "// unverified upstream\n");
  expect(fixture.run("--apply").status).not.toBe(0);
  expect(await readFile(fixture.target)).toEqual(fixture.previous);
});

test("upstream rollback remains guarded and preserves target permissions", async () => {
  const fixture = await sandbox("patched");
  expect(fixture.run("--rollback").status).toBe(0);
  expect(await readFile(fixture.target)).toEqual(fixture.original);
  expect((await stat(fixture.target)).mode & 0o777).toBe(0o600);
  expect(fixture.run("--check").status).toBe(0);
});

test("a verified backup can restore the exact pre-update patch atomically", async () => {
  const fixture = await sandbox("previous");
  expect(fixture.run("--apply").status).toBe(0);
  const backup = join(fixture.home, ".config/opencode-migration-backups", (await fixture.backups())[0]!, "herdr-tui-session.js");
  expect(hash(await readFile(backup))).toBe(hash(fixture.previous));
  expect(hash(await readFile(fixture.target))).toBe(hash(fixture.patched));
  const temporary = `${fixture.target}.restore`;
  await copyFile(backup, temporary);
  await chmod(temporary, (await stat(fixture.target)).mode & 0o777);
  await rename(temporary, fixture.target);
  expect(await readFile(fixture.target)).toEqual(fixture.previous);
  expect((await stat(fixture.target)).mode & 0o777).toBe(0o600);
  expect(fixture.run("--check").status).toBe(0);
});
