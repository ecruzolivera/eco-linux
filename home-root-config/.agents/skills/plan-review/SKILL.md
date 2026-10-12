---
name: plan-review
description: Criteria for reviewing implementation plans (not code) against quality standards — citation quality, completeness, and actionability
---

# Plan Review

> **Load this skill** when reviewing implementation plans (not code). If the target is actual code, load `code-review` instead.

## TL;DR

Systematic plan review focused on 3 quality categories: Citation Quality, Completeness, and Actionability. Structural format is pre-validated by `plan_save` when a plan was created that way — focus on whether the plan provides actionable implementation guidance.

## When to Use This Skill

- When reviewing implementation plans before execution
- When auditing plan quality after creation
- When verifying plans meet documentation standards
- As part of the plan validation workflow
- When a reviewer/other skill routes a plan review here (e.g. the review agent's "Plan Reviews" path)

## Plan Review Checklist

### 1. Structure (Pre-validated)

> **Note:** Plans saved via `plan_save` are structurally validated before storage (YAML frontmatter, status markers, CURRENT marker, numbering). If the plan did not go through `plan_save`, verify structure manually: frontmatter, valid phase markers, and a single `← CURRENT` marker.

### 2. Citation Quality

| Requirement                 | Check                                        |
| --------------------------- | -------------------------------------------- |
| Decisions reference sources | `ref:https://`, `ref:./file`, or `ref:id` used |
| No unsubstantiated claims   | Architectural decisions cite research        |
| Research phases show refs   | Completed research tasks include citations   |
| Citations are verifiable    | IDs/files/URLs match actual sources          |

**Red Flags:**

- Decisions table with empty or `-` in Source column
- Claims like "industry standard" or "best practice" without citation
- Research tasks marked complete without `→ ref:...`
- Ephemeral delegation IDs cited in long-lived plans (should be saved to file)

### 3. Completeness

| Requirement               | Check                                         |
| ------------------------- | --------------------------------------------- |
| Goal is specific          | Measurable outcome, not vague intent          |
| Phases are logical        | Sequential, with clear progression            |
| Edge cases considered     | Error handling, failure modes addressed       |
| Notes section present     | Key decisions and observations documented     |
| Context & Decisions table | Captures architectural choices with rationale |

**Goal Quality Examples:**

- ❌ "Improve authentication" (vague)
- ❌ "Make it better" (unmeasurable)
- ✅ "Add JWT authentication with refresh token support" (specific)
- ✅ "Migrate user table to PostgreSQL with zero downtime" (measurable)

### 4. Actionability

| Requirement                 | Check                                              |
| --------------------------- | -------------------------------------------------- |
| Tasks are specific          | Clear what file/component is affected              |
| No ambiguous tasks          | Avoids "investigate" or "figure out" without scope |
| Dependencies clear          | Sequential tasks show logical order                |
| Implementation path obvious | Developer can start without clarification          |

**Actionability Examples:**

- ❌ "Set up the backend" (too vague)
- ❌ "Make it work" (no implementation path)
- ✅ "Create `src/auth/jwt.ts` with sign/verify functions" (specific file)
- ✅ "Add bcrypt password hashing to `UserService.create()`" (clear scope)

---

## Severity Classification

| Severity | Icon | Criteria                                                               | Action Required           |
| -------- | ---- | ---------------------------------------------------------------------- | ------------------------- |
| Critical | 🔴   | Missing citations for key decisions, no clear goal, unactionable tasks | Must fix before execution |
| Major    | 🟠   | Vague tasks, incomplete phases, missing edge case handling             | Should fix                |
| Minor    | 🟡   | Missing notes, unclear dependencies, incomplete rationale              | Nice to fix               |
| Nitpick  | 🟢   | Style preferences, wording suggestions                                 | Optional                  |

---

## Output Format

Structure your plan review as:

```markdown
## Plan Review

### Files Reviewed

- `PLAN.md` (or plan content from `plan_read`)

### Overall Assessment

APPROVE | REQUEST_CHANGES | NEEDS_DISCUSSION

### Summary

2-3 sentence overview of plan quality.

### Issues

#### 🔴 Critical

- [Issue description with specific location]

#### 🟠 Major

- [Issue description with specific location]

#### 🟡 Minor

- [Issue description with specific location]

#### 🟢 Nitpick

- [Suggestion]

### Quality Assessment

| Check                           | Status      |
| ------------------------------- | ----------- |
| Goal is specific and measurable | PASS / FAIL |
| Citations support key decisions | PASS / FAIL |
| Tasks are actionable            | PASS / FAIL |
| Edge cases addressed            | PASS / FAIL |

### Positive Observations

- [What's done well - always include at least one]
```

---

## What NOT to Do

- Do NOT re-validate format when the plan already passed `plan_save` structural validation
- Do **NOT evaluate code quality** — that is `code-review`'s job
- Do NOT apply the code-review 4 layers (correctness/security/performance/style) to plan text
- Do NOT execute or modify the plan during review
- Do NOT skip citation verification for decisions
- Do NOT accept vague goals or ambiguous tasks
- Do NOT forget to note positive observations

---

## Adherence Checklist

Before completing a plan review, verify:

- [ ] All 3 quality categories analyzed (Citations, Completeness, Actionability)
- [ ] Severity assigned to each finding
- [ ] Specific locations noted for all issues
- [ ] Quality Assessment table completed
- [ ] Positive observations noted
- [ ] Output follows the standard format