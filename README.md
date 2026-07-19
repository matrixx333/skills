# skills

Custom [Agent Skills](https://docs.claude.com/en/docs/claude-code/skills) for [Claude Code](https://claude.com/claude-code) — Markdown instructions that teach Claude a workflow, then load automatically when a conversation matches it.

There's no application code here and nothing to build or test. Every file is Markdown, and a skill is only as good as its trigger and its instructions — that's what gets reviewed and changed.

## Available skills

| Skill | What it does |
| --- | --- |
| [`design-patterns`](skills/design-patterns/SKILL.md) | Explains, implements, suggests, or reviews any of the 23 GoF design patterns, language-agnostic. Triggers on pattern names (Singleton, Observer, Factory, Decorator, ...) or a described design problem, not just the phrase "design pattern". |
| [`unit-tests`](skills/unit-tests/SKILL.md) | Writes or refactors C#/.NET unit tests to 100% line/branch/method coverage, using whatever fluent builders, test harnesses, framework, and assertion library the target repo already has. Discovers those conventions at runtime instead of assuming one project's setup. |

## Installation

Claude Code loads skills from a `skills/` directory — either per-project (`.claude/skills/`) or for your user across all projects (`~/.claude/skills/`).

```bash
git clone https://github.com/matrixx333/skills.git
cp -r skills/skills/* ~/.claude/skills/
```

> [!TIP]
> Skills aren't invoked like slash commands — Claude reads each `SKILL.md`'s `description` up front and decides on its own whether a skill applies to what you just asked. If a skill isn't triggering when you expect, the fix is almost always to sharpen its `description`, not to change how you phrase the request.

## Structure

```
skills/
  <skill-name>/
    SKILL.md              # required: frontmatter + instructions, loaded when the skill triggers
    references/*.md       # optional: detail docs, loaded on demand, not upfront
```

`SKILL.md` stays short enough to read in full every time it triggers — modes or steps, not prose, plus a closing checklist Claude can self-check against. Anything heavier (pattern catalogs, annotated examples, step-by-step procedures) lives in `references/*.md` and is only read when `SKILL.md` points to it, keeping the always-loaded file lean.

## Writing a new skill

A skill that teaches a pattern but is grounded in one codebase's specifics (see `unit-tests`) should still work in any repo of that kind. The shape that makes that possible:

1. **A "Step 0"** that tells Claude to read the target repo's own conventions before writing anything, instead of trusting memory or this repo's examples.
2. **Hints, not hard assumptions** — concrete specifics (framework versions, paths, naming) are stated as a snapshot to verify against the actual files, not baked in as fact.
3. **Clear ownership of examples** — worked examples are labeled as the *authoring* repo's, never described as "this repo," since a portable skill runs in a different one each time.

See [`CLAUDE.md`](CLAUDE.md) for the full authoring conventions this repo follows.
