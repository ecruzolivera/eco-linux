---
name: planner
description: Create and manage implementation plans with citations and quality self-check
---

# Planner

> **Load this skill** when creating or updating implementation plans.

## TL;DR Checklist

When creating or updating a plan, ensure:

- [ ] File name prefixed with creation date: `YYYY-MM-DD`
- [ ] YAML frontmatter with `status`, `phase`, `updated`
- [ ] `## Goal` section (one sentence)
- [ ] `## Context & Decisions` table with citations
- [ ] Phases with status markers: `[COMPLETE]`, `[IN PROGRESS]`, `[PENDING]`
- [ ] Tasks with hierarchical numbering (1.1, 1.2, 2.1)
- [ ] Only ONE task marked `← CURRENT`
- [ ] Citations for all research-based decisions

---

## When to Use

1. Starting a multi-step implementation
2. After receiving a complex user request
3. When tracking progress across phases
4. After research that informs architectural decisions

## When NOT to Use

1. Simple one-off tasks → use built-in todos instead
2. Pure research/exploration → use delegations only
3. Quick fixes that don't need tracking
4. Single-file changes with no dependencies

---

## Plan Format

Use `plan_save` with this format:

```markdown
---
status: STATUS
phase: PHASE_NUMBER
updated: YYYY-MM-DD
---

# Implementation Plan

## Goal

ONE_SENTENCE_DESCRIBING_OUTCOME

## Context & Decisions

| Decision | Rationale | Source                               |
| -------- | --------- | ------------------------------------ |
| CHOICE   | WHY       | `ref:https://...` or `ref:./file.md` |

## Phase 1: NAME [STATUS_MARKER]

- [x] 1.1 Completed task
- [x] 1.2 Another completed task → `ref:https://docs.example.com/guide`

## Phase 2: NAME [IN PROGRESS]

- [x] 2.1 Completed task
- [ ] **2.2 Current task** ← CURRENT
- [ ] 2.3 Pending task

## Phase 3: NAME [PENDING]

- [ ] 3.1 Future task
- [ ] 3.2 Another future task

## Notes

- YYYY-MM-DD: Observation or decision `ref:./path/file.md`
```

### Frontmatter Fields

| Field     | Values                                              | Description          |
| --------- | --------------------------------------------------- | -------------------- |
| `status`  | `not-started`, `in-progress`, `complete`, `blocked` | Overall plan status  |
| `phase`   | Number (1, 2, 3...)                                 | Current phase number |
| `updated` | `YYYY-MM-DD`                                        | Last update date     |

### Phase Status Markers

| Marker          | Meaning                   |
| --------------- | ------------------------- |
| `[PENDING]`     | Not yet started           |
| `[IN PROGRESS]` | Currently being worked on |
| `[COMPLETE]`    | Finished successfully     |
| `[BLOCKED]`     | Waiting on dependencies   |

---

## State Machine

### Plan Lifecycle

```
not-started → in-progress → complete
                          ↘ blocked
```

### Phase Lifecycle

```
[PENDING] → [IN PROGRESS] → [COMPLETE]
                         ↘ [BLOCKED]
```

### Task Lifecycle

```
[ ] unchecked → [x] checked
```

### Critical Rules

1. **Only ONE phase** may be `[IN PROGRESS]` at any time
2. **Only ONE task** may have `← CURRENT` marker at any time
3. **Move `← CURRENT`** immediately when starting a new task
4. **Mark tasks `[x]`** immediately after completing them

---

## Citations

### Citation Formats

All citations use the `ref:` prefix, with three source types:

| Source Type        | Format               | Example                                           |
| ------------------ | -------------------- | ------------------------------------------------- |
| Webpage/URL        | `ref:https://...`    | `ref:https://docs.python.org/3/library/venv.html` |
| Local file         | `ref:./path/file.md` | `ref:./research/auth-patterns.md`                 |
| Session delegation | `ref:DELEGATION_ID`  | `ref:swift-amber-falcon`                          |

### When to Use Which

- **`ref:https://...`**: Web docs, API references, online articles, RFCs
- **`ref:./path` or `ref:file:///...`**: Local research files, saved findings, notes, always use relative paths when possible
- **`ref:DELEGATION_ID`**: Session-bound research from delegated agents (ephemeral)

### Saving Research (Recommended)

For persistent, traceable citations:

1. Delegate research to agent
2. Save key findings to `./research/{topic}.md`
3. Cite as `ref:./research/{topic}.md`

### When to Cite

| Situation                                | Action                           |
| ---------------------------------------- | -------------------------------- |
| Architectural decision based on research | Add to Context & Decisions table |
| Task informed by research                | Append `→ ref:id` to task line   |
| Implementation detail from research      | Inline citation in Notes         |

### Delegation IDs (Ephemeral)

For session-bound research:

- Use `delegation_list()` to see active delegations
- Use `delegation_read("id")` to verify content before citing
- Prefer saving research to file for long-lived plans

### Never

- Make up citation sources
- Cite without verifying the source exists
- Skip citations for research-based decisions
- Use delegation IDs for long-lived decisions (save to file instead)

---

## Quality Self-Check

Before saving, verify:

### Citation Quality

| Check                                       | Requirement                                      |
| ------------------------------------------- | ------------------------------------------------ |
| `ref:` format used with valid source        | Decisions reference sources                      |
| Architectural decisions cite research       | No unsubstantiated claims                        |
| Completed research tasks include citations  | Research phases show refs                        |
| Persistent sources preferred over ephemeral | Use `ref:./file` or `ref:https://` when possible |

**Red Flags:**

- Decisions table with empty or `-` in Source column
- Claims like "industry standard" or "best practice" without citation
- Research tasks marked complete without `→ ref:id`
- Citing delegation IDs in long-lived plans (session will end)

### Completeness

| Check                                     | Requirement           |
| ----------------------------------------- | --------------------- |
| Measurable outcome, not vague intent      | Goal is specific      |
| Sequential, with clear progression        | Phases are logical    |
| Error handling, failure modes addressed   | Edge cases considered |
| Key decisions and observations documented | Notes section present |

**Goal Quality Examples:**

- ❌ "Improve authentication" (vague)
- ✅ "Add JWT authentication with refresh token support" (specific)

### Actionability

| Check                                              | Requirement        |
| -------------------------------------------------- | ------------------ |
| Clear what file/component is affected              | Tasks are specific |
| Avoids "investigate" or "figure out" without scope | No ambiguous tasks |
| Sequential tasks show logical order                | Dependencies clear |

**Actionability Examples:**

- ❌ "Set up the backend" (too vague)
- ✅ "Create `src/auth/jwt.ts` with sign/verify functions" (specific file)

---

## Examples

### ✅ Correct: Well-formed plan

```markdown
---
status: in-progress
phase: 2
updated: 2026-01-02
---

# Implementation Plan

## Goal

Add JWT authentication with refresh token support

## Context & Decisions

| Decision                | Rationale                                    | Source                                       |
| ----------------------- | -------------------------------------------- | -------------------------------------------- |
| Use bcrypt (12 rounds)  | Industry standard, balance of security/speed | `ref:https://cheatsheetseries.owasp.org/...` |
| JWT with refresh tokens | Stateless auth, mobile-friendly              | `ref:./research/token-strategies.md`         |

## Phase 1: Research [COMPLETE]

- [x] 1.1 Research auth patterns → `ref:https:// OWASP cheat sheets`
- [x] 1.2 Evaluate token strategies → `ref:./research/token-strategies.md`

## Phase 2: Implementation [IN PROGRESS]

- [x] 2.1 Set up project structure
- [ ] **2.2 Add password hashing** ← CURRENT
- [ ] 2.3 Implement JWT generation

## Phase 3: Testing [PENDING]

- [ ] 3.1 Write unit tests
- [ ] 3.2 Integration tests

## Notes

- 2026-01-02: Chose bcrypt over argon2 for broader library support `ref:https://cheatsheetseries.owasp.org/...`
```

### ❌ Wrong: Missing frontmatter

```markdown
# Implementation Plan

## Goal

Add authentication
```

**Error:** Plan must have YAML frontmatter with status, phase, updated.

### ❌ Wrong: Multiple CURRENT markers

```markdown
## Phase 2: Implementation [IN PROGRESS]

- [ ] **2.1 Task one** ← CURRENT
- [ ] **2.2 Task two** ← CURRENT
```

**Error:** Only one task may be marked CURRENT.

### ❌ Wrong: Decision without citation

```markdown
## Context & Decisions

| Decision  | Rationale | Source |
| --------- | --------- | ------ |
| Use Redis | It's fast | -      |
```

**Error:** Decisions must cite research with `ref:https://...`, `ref:./file`, or `ref:delegation-id`.

### ❌ Wrong: Invalid phase status

```markdown
## Phase 1: Research [DONE]
```

**Error:** Use `[COMPLETE]`, not `[DONE]`. Valid markers: `[PENDING]`, `[IN PROGRESS]`, `[COMPLETE]`, `[BLOCKED]`.

---

## Troubleshooting

| Error Message              | Fix                                                                       |
| -------------------------- | ------------------------------------------------------------------------- |
| "Missing frontmatter"      | Add `---\nstatus: in-progress\nphase: 1\nupdated: YYYY-MM-DD\n---` at top |
| "Multiple CURRENT markers" | Remove `← CURRENT` from all but the active task                           |
| "Invalid citation format"  | Use `ref:https://...`, `ref:./file.md`, or `ref:delegation-id`            |
| "Missing goal"             | Add `## Goal` section with one-sentence description                       |
| "Empty phase"              | Add at least one task to each phase                                       |
| "Invalid phase status"     | Use `[PENDING]`, `[IN PROGRESS]`, `[COMPLETE]`, or `[BLOCKED]`            |
