---
subagent: true
description: Rank, squash-merge, and verify Dependabot PRs one at a time
agent: build
---

# Merge Dependabot Command

Merge open Dependabot pull requests safely, starting with the lowest expected conflict risk. Treat the default branch's post-merge CI status as the gate for every subsequent merge.

User instructions: $ARGUMENTS

## Safety Rules

- Work only in the repository containing the current directory, unless `$ARGUMENTS` names a repository.
- Require a clean worktree before starting. Do not stash, discard, or overwrite user changes.
- Operate only on open pull requests authored by `app/dependabot`.
- Never use `--admin`, force-push, bypass branch protections, disable tests, or merge with failing required checks.
- Use squash merges for Dependabot PRs and repair PRs.
- Merge exactly one PR at a time. Refresh all remaining candidates after every successful merge or repair.
- Stop before the next Dependabot PR whenever the default branch does not have a completed successful CI result.
- Do not change repository settings, workflow definitions, or dependency update configuration merely to make CI pass.

## Workflow

1. **Establish context**
   - Confirm `gh auth status` succeeds and determine the repository with `gh repo view --json nameWithOwner,defaultBranchRef`.
   - Confirm the current worktree is clean with `git status --porcelain`.
   - Identify the default branch and its current HEAD SHA.
   - If no open Dependabot PRs exist, report that and stop.

2. **Discover and analyze candidates**
   - List every open Dependabot PR, including number, title, URL, head/base refs, merge state, review decision, labels, changed files, commits, additions, deletions, and check status.
   - Inspect changed file names and dependency metadata for each candidate. Compare all candidates for overlapping changed paths.
   - Classify each PR using this risk model and display the ordered table before merging:
     - **Lowest risk**: patch update, one ecosystem, lockfile-only or manifest-plus-lockfile change, mergeable, current base, and passing checks.
     - **Low risk**: minor update with isolated manifest/lockfile changes and no overlap with another candidate.
     - **Medium risk**: multiple packages/files, shared lockfile or manifest overlap, missing/in-progress checks, or a branch behind the base.
     - **High risk**: major update, dependency removal/replacement, source/test/config changes beyond expected dependency artifacts, merge conflicts, failed checks, blocked review, or overlapping major updates.
   - Within a risk tier, prefer: fewer changed files, smaller diff, patch before minor before major, then older PR first.
   - Skip and report PRs that cannot be merged because of conflicts, branch protection, a required review, or unrepaired failing pre-merge checks. Do not attempt to merge them later in the same run unless their state changes while handling another PR.

3. **Prepare the next PR**
   - Re-fetch its metadata and checks immediately before acting. Recalculate its risk and the ordering of all remaining candidates.
   - If its branch is behind the default branch, update it using GitHub's normal update-branch mechanism. Wait for its new checks and re-evaluate it.
   - Require all completed required checks to pass. If checks are pending, wait for them. If a check fails, inspect the failure and fix it only when the defect is clearly attributable to the dependency update and the repair is small and safe.
   - For a pre-merge repair, create a separate repair PR against the default branch. Do not modify a Dependabot-owned branch. Verify, squash-merge, and validate its post-merge CI before reconsidering any Dependabot PR.

4. **Merge and validate**
   - Squash-merge the selected PR with `gh pr merge <number> --squash --delete-branch` only after its required checks pass and GitHub reports it mergeable.
   - Record the merged PR number, resulting merge commit SHA, and affected dependency.
   - Locate every GitHub Actions workflow run triggered by that exact default-branch commit. Wait until each completes.
   - Treat any failed, cancelled, timed-out, or missing expected CI run as a failed post-merge validation. Inspect job logs before deciding whether a repair is appropriate.

5. **Repair post-merge CI failures**
   - First determine whether the failure is caused by the just-merged dependency update. Transient infrastructure failures may be rerun once; do not create a code repair for a clearly external failure.
   - If the failure is attributable and has a small, clear fix:
     - Create a branch named `fix/dependabot-ci-<merged-pr-number>` from the current default branch.
     - Make only the minimal required repair. Do not alter unrelated code or weaken validation.
     - Run the relevant local checks, then commit and push the repair branch.
     - Open a repair PR that links to the failed Dependabot PR and explains the CI failure and fix.
     - Wait for the repair PR's required checks, squash-merge it, then wait for and verify all CI triggered by its default-branch merge commit.
   - If the failure is not clearly attributable, needs an architectural/product decision, cannot be reproduced, or the repair PR cannot be merged cleanly, stop immediately and report the failure, logs, affected commit, and recommended next action. Do not merge another Dependabot PR.

6. **Continue or finish**
   - Continue with the newly lowest-risk remaining candidate only after the default branch is green.
   - When no safe candidates remain, report:
     - Merged Dependabot PRs with risk classification and merge commit.
     - Repair PRs created and their validation result.
     - Skipped or blocked PRs with specific reasons.
     - The final default-branch CI status.

## Reporting

- Announce the initial ranked order and each re-ranking caused by a merge or repair.
- Before each merge, state the PR number, dependency update, risk tier, changed paths, and check status.
- Link every failed CI workflow and repair PR in the final report.
- Never claim CI is green until the runs for the exact merged commit have completed successfully.
