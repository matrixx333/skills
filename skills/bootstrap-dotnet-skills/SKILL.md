---
name: bootstrap-dotnet-skills
description: Install the skills vendored in this repo's skills/ directory (design-patterns, unit-tests, and the dotnet-skills/* collection) into a target project's or user's Claude Code skills scope, then write a skills-routing block into the invoking project's CLAUDE.md. Use when the user asks to bootstrap skills, install or update the .NET or matrixx333 skills, sync skills from this repo, or set up this project's skills on a new machine.
---

# Bootstrap skills

Installs skills from this repo's `skills/` directory (or another `--repo`) into a Claude Code
skills scope — `~/.claude/skills` (user scope) or a project's `.claude/skills/` — and writes a
routing block into the invoking project's `CLAUDE.md`.

There is no manifest file. Every skill is discovered by walking the source repo's
`skills/**/SKILL.md`, so both root-level skills (`skills/design-patterns`) and nested ones
(`skills/dotnet-skills/testcontainers`) are found automatically. Use `--skills`/`--exclude` to
narrow what gets installed for one particular target project.

## Split of responsibility

- `scripts/install-skills.sh` does everything deterministic: precheck, clone, discover, filter,
  copy, clean up, and write the lockfile. It emits one JSON object on stdout; logging goes to
  stderr.
- This procedure does the one part that needs judgment: composing the routing block.

---

## Phase 1 — Install

**Ask first, before running anything.** Scope is an ambiguous, hard-to-undo choice — user scope
makes these skills available in every project on the machine, project scope confines them to the
one you're currently in — so do not silently default to either. Ask the user which they want:

- **User scope** (`~/.claude/skills`) — installs for every project on this machine. This is the
  script's own default if `--scope` is omitted.
- **Project scope** (`<this project>/.claude/skills`) — installs only for the project you're
  currently working in.

Do not pre-decide based on how the user phrased the request unless they already named a scope
explicitly (e.g. "install these user-wide" or "just for this project").

Once the scope is settled, run `scripts/install-skills.sh`, resolved **relative to wherever this
`SKILL.md` itself was loaded from** — never hardcode a path prefix. This skill may be installed
project-scoped (`.claude/skills/bootstrap-dotnet-skills/`), user-scoped
(`~/.claude/skills/bootstrap-dotnet-skills/`), or run in place from this library repo
(`skills/bootstrap-dotnet-skills/`); the script itself no longer assumes any particular nesting,
so just invoke the sibling `scripts/install-skills.sh` next to the copy of this file that was
actually loaded:

```bash
bash <skill-dir>/scripts/install-skills.sh --scope <path chosen above>
```

Useful flags:

- `--scope PATH` — install target, default `$HOME/.claude/skills`. Always pass this explicitly
  with whatever the user chose above, rather than relying on the default.
- `--skills NAME` (repeatable) — install only the named skill(s) instead of everything. Default
  is every skill discovered in the source repo, **except `bootstrap-dotnet-skills` itself** (pass
  `--skills bootstrap-dotnet-skills` explicitly to include it).
- `--exclude NAME` (repeatable) — drop a skill from whatever set was selected.
- `--repo URL` / `--ref REF` — install from somewhere other than this repo's default branch.
- `--dry-run` — resolve and report without writing anything.
- `--force` — ignore the lockfile and reinstall everything regardless of whether it changed.

Then:

- **Non-zero exit** → report the script's stderr and stop.
- **`"upToDate": true`** → nothing changed since the last install (same commit, same requested
  skill set) — skip straight to Phase 3, nothing to install or report per-skill.
- **Otherwise** → parse `installed[]` (each entry has `name`, `tree`, `changed`, `path`).

## Phase 2 — Verify and report

1. Confirm every installed directory has a non-empty `SKILL.md` with a frontmatter `name:` line.
   Do **not** require `name` to equal the directory name — several of the vendored skills
   legitimately differ (`csharp-api-design` declares `name: api-design`, `testcontainers` declares
   `name: testcontainers-integration-tests`, and so on) and they load fine. The directory name is
   what identifies the skill to Claude Code and to `--skills`/`--exclude`.
2. Report a table to the user: skill · new/changed vs. unchanged, plus the source repo/ref/commit.
   Mention that new skills load in a new session.

## Phase 3 — CLAUDE.md routing block

Runs once per bootstrap, including when the install reported `"upToDate": true`, since the target
project's `CLAUDE.md` may not have the block yet.

Read `references/claude-md-snippet.md` and follow it. In short:

```bash
bash <skill-dir>/scripts/install-skills.sh --emit-catalog --scope <the --scope used in Phase 1>
```

gives `{name, description}` for every skill currently installed under that scope, plus the
source `repo`/`ref`/`commit`. Compose the categorized routing block from that, and write it into
the **invoking project's** `CLAUDE.md` between the `<!-- BEGIN skills-routing … -->` /
`<!-- END skills-routing -->` markers — replacing between them if present, appending the whole
block if not.

Skill names in the block must be **directory names**, never frontmatter names — see point 1 in
Phase 2.

---

## Notes

- The branch to install from is auto-detected via `git ls-remote --symref` (this repo is on
  `main`); pass `--ref` to pin something else.
- This repo genuinely contains a directory named `opentelementry-dotnet-instrumentation`. That
  misspelling is upstream's (see `CLAUDE.md`'s vendoring notes); if selecting it via `--skills`,
  spell it exactly that way. Do not "correct" it.
- The lockfile lives at `<scope>/.bootstrap-dotnet-skills-lock.json` and records the source
  repo/ref/commit plus each installed skill's tree hash — this is what makes an unchanged re-run a
  no-op. It is written by the script directly; never hand-write it.
