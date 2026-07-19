# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A collection of **Claude Code Agent Skills** — no application code, no build/lint/test
tooling. Every file is Markdown. Changes here are evaluated by reading the skill content
itself (does the SKILL.md correctly trigger and instruct? do the references stay accurate?),
not by running a build.

## Structure

```
skills/
  <skill-name>/
    SKILL.md              # required: frontmatter + instructions, loaded when the skill triggers
    references/*.md       # optional: detail docs, loaded on demand by SKILL.md, not upfront
```

Each `SKILL.md` starts with YAML frontmatter:

```yaml
---
name: skill-name              # kebab-case, matches the directory name
description: >
  Third-person, written for a router deciding whether to invoke this skill —
  not for the end user. States what the skill does AND lists concrete trigger
  phrases/keywords ("even if they do not say the word X").
---
```

The `description` is the only field the routing system sees before loading the file, so it
carries the full trigger surface: explicit ask phrasing, domain keywords, and synonyms users
might use instead of naming the skill outright. When editing a skill, keep the description in
sync with any new triggers the body implies.

## Two-tier content pattern

Both existing skills split content the same way, and new skills should follow it:

- **`SKILL.md`** — the workflow/decision logic: modes or steps, when to do what, the checklist
  used to judge "done." Kept short enough to read in full every time the skill triggers.
- **`references/*.md`** — heavier per-topic detail (pattern catalogs, annotated code examples,
  step-by-step procedures) that SKILL.md points to and Claude reads *on demand*, not upfront.
  This keeps the always-loaded SKILL.md lean while still allowing deep, example-rich material.

## Writing a skill that must generalize across repos

`skills/unit-tests` is the model for a skill that teaches a *pattern* but is grounded in one
real codebase's specifics (test framework, builder names, file paths). It is scoped to a
language/platform (C#/.NET) but must work in *any* repo using that stack. Rather than assuming
one project's specifics apply everywhere, it separates three things:

1. **What must be discovered at runtime** — a "Step 0" that tells Claude to read the target
   repo's own conventions (its CLAUDE.md, its `.claude/rules/*`, its actual builder/harness
   files via glob) *before* writing anything, instead of trusting memory or this skill's
   examples.
2. **What's a hint vs. the truth** — the skill states the specifics it was written against
   (framework versions, paths, naming patterns) but explicitly flags them as a snapshot to
   verify, not a hard assumption: *"Verify these still hold — treat this paragraph as a hint,
   the files as the truth."*
3. **Whose specifics these are** — concrete code, paths, and type names are kept (they make the
   skill teachable) but labeled as a *worked example from the repo the skill was authored
   against* (e.g. "Worked example — authoring repo (yours will differ)"), **never** framed as
   "this repo." Inside a portable skill "this repo" means wherever the skill is running, so the
   authoring project is always "the authoring repo" and the current one "the target repo."

Follow this shape for any new skill whose concrete details (paths, tool names, versions) will
vary by the repo it's used in: teach the reusable pattern, point at how to discover the local
specifics, keep concrete examples but mark them as the authoring repo's, and don't bake a
single project's paths into instructions presented as universal.

## Skill content conventions (from `design-patterns` and `unit-tests`)

- SKILL.md bodies are organized as numbered **modes** or **steps**, not prose — each with a
  clear entry condition (e.g., "when the user asks 'what is X'" / "if a test class already
  exists and is below full coverage").
- Ambiguous situations get an explicit **ask-the-user branch** rather than a silent default
  (e.g., unit-tests' Step 2 offers three named refactor scopes and says "Do not pre-decide").
  Prefer this pattern over guessing when a skill's action is expensive or hard to undo.
- A trailing **quality checklist** (or per-mode "when NOT to" bullets) gives Claude a concrete
  definition of done to self-check against before finishing.
- Reference files are cross-linked by relative path from SKILL.md (`references/foo.md`) with a
  one-line note on when to open each one — not just listed, but told when they're relevant.
