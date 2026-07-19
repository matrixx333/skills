---
name: unit-tests
description: 'Create or refactor C# (.NET) unit tests to 100% line/branch/method
  coverage using the patterns already established in the codebase — fluent data
  builders, composition-root test harnesses, and a report-verified coverage loop.
  Works with NUnit, xUnit, or MSTest and Moq or NSubstitute; discovers the repo''s
  framework, assertion library, project layout, and naming conventions at runtime.
  Use whenever the user asks to write unit tests, add tests for a service/class,
  raise or fill in test coverage, refactor existing tests, or mentions
  builders/harnesses/coverage for C# code — even if they do not say the word
  "skill".'
---

# Unit Tests: create & refactor to full coverage

Your goal is to write (or refactor) C# unit tests that reach **100%
line, branch, and method coverage** for the class under test, using the
patterns already established in the codebase: **fluent builders** for
test data, **composition-root harnesses** for the system-under-test
(SUT), a shared **aggregate/repository builder** for grouped
dependencies where the project has one, and the project's **assertion
library** for readable assertions. Every test is happy-path *and*
edge/error case, AAA-structured, independent, and follows the repo's
framework, naming, and category conventions.

This skill teaches the **patterns**. It assumes the project is
**C#/.NET**, but every other specific — the test framework and its
attribute vocabulary, the assertion and mocking libraries, exact
test-project paths and versions, whether a shared aggregate builder
exists, and the source-to-test-project mapping — differs per repo and is
**discovered at runtime** in Step 0. Do not assume them.

## Step 0 — Load project conventions (do this first, always)

Before writing a single test, **read** the target repo's own
conventions. Do not rely on memory or on the examples in this skill;
confirm them against the actual project:

1. Read the root **`CLAUDE.md`** — especially any *Verification* table
   mapping source paths to the test project that covers them, plus the
   build/test commands and non-obvious quirks.
2. Read **`.claude/rules/testing.md`** (or the project's equivalent) for
   the **test framework and version** (NUnit / xUnit / MSTest — this
   determines the attribute vocabulary and setup mechanism), the
   **mocking library** (Moq / NSubstitute / …), the **assertion library**
   (FluentAssertions / Shouldly / built-in `Assert`), test-project
   locations, the **test-naming grammar**, and category/trait usage.
3. Read **`.claude/rules/code-style.md`** and **`.claude/rules/naming.md`**
   for line length, multi-line call formatting, private-method naming,
   and member ordering — new test files must obey the same style hooks as
   production code.
4. **Discover the existing test infrastructure** by looking at real
   neighbors, not by guessing:
   - Builders: search the test project's builders folder (glob
     `**/*Builder*.cs`). Note any shared **aggregate/repository builder**
     (a builder that defaults a whole bag of dependencies to mocks) and
     any entity/model builders.
   - Harnesses: glob `**/*Harness*.cs`. If none exist yet, the
     composition root likely lives inline in each fixture's setup — read
     one representative `*Tests.cs` to see how the SUT is wired and where
     such a helper would go.
   - Coverage tooling: read the test project's `.csproj` (and any
     `*.runsettings`) for how coverage is collected — `coverlet.msbuild`
     properties (`CollectCoverage`, `CoverletOutput`,
     `CoverletOutputFormat`, `Include`/`Exclude`), a `coverlet.collector`
     runsettings, or a `dotnet test --collect` setup.

If the project has none of those convention files, infer the same facts
from the test project itself — an existing `*Tests.cs`, the `.csproj`
package references, and the folder layout are the ground truth.

> **Example — one repo's completed Step 0 (yours will differ).** In the
> repo this skill was authored against, Step 0 surfaced: NUnit 4.2.2 +
> Moq 4.20.72 + FluentAssertions 6.12.1; test projects under
> `tests/**`; naming `Can_Action_ExpectedResult` /
> `Should_Action_ExpectedResult`; `[Category("UnitTest")]`; entity
> builders and a shared `RepositoriesBuilder` in the test project's
> `Builders/` folder; and `coverlet.msbuild` emitting cobertura. Verify
> these still hold — treat this paragraph as a hint, the files as the
> truth.

## Workflow

1. **Identify the class(es) under test.** Locate the SUT and, if it
   exists, its test class (glob `**/{ClassName}Tests.cs`).

2. **If a test class already exists and is below full coverage → ASK the
   user which refactor scope to apply.** Do not pre-decide. Offer:
   - **(a) Gaps only** — add the missing tests to reach 100%; leave the
     existing structure alone.
   - **(b) Gaps + light refactor** — reach 100% *and* migrate the new
     (and lightly, the touched) tests to the builder/harness pattern.
   - **(c) Full migration** — reach 100% *and* refactor the whole
     fixture to builders + harness + the project's assertion library.

   Proceed per their choice. For a brand-new test class, skip straight to
   step 3.

3. **Analyze the SUT.** Enumerate its full public surface (every public
   method/property), every branch (`if`/`else`, `switch`, ternary,
   null-conditional, `?:`, `&&`/`||` short-circuits, loops, `try/catch`),
   every dependency (constructor params), and every edge/error path
   (nulls, empty collections, boundary values, thrown exceptions,
   cancellation). This enumeration *is* your test list — see
   `references/coverage-workflow.md` for the branch checklist.

4. **Build test data with fluent builders.** Reuse existing builders;
   create new ones only when none fits, following the repo pattern
   (factory entry point, semantic `With…`/`For…`/`On…` methods returning
   `this`, non-null defaults, `Build()`). See
   `references/builder-pattern.md`.

5. **Construct the SUT via a composition-root harness.** Reuse an
   existing harness; otherwise create one (in the harnesses location
   Step 0 found, or alongside the fixture if the repo keeps setup inline)
   that owns the mock dependencies, wires the SUT in its constructor, and
   exposes fluent `Given…()` arrangement methods. If the project has a
   shared aggregate/repository builder, use it for those grouped
   dependencies. See `references/harness-pattern.md`. If the repo
   currently wires the SUT inline in its setup and the user did not ask
   for a harness, match the neighbors — but prefer a harness for SUTs
   with many dependencies.

6. **Write the tests.** For each item from step 3:
   - Happy path + every edge + every error path.
   - **AAA** with `// Arrange` / `// Act` / `// Assert` comments.
   - The project's **assertion library** — match what the neighbors use
     for new tests (e.g. FluentAssertions `result.Should().Be(...)` /
     `act.Should().Throw<T>()`, Shouldly, or built-in `Assert`); don't
     mix assertion styles within a fixture.
   - The project's **test-framework attributes and naming grammar** —
     e.g. NUnit `[TestFixture]`/`[Test]`/`[TestCase]`, xUnit
     `[Fact]`/`[Theory]`, or MSTest `[TestClass]`/`[TestMethod]`, plus
     the repo's category/trait convention (e.g. `[Category("UnitTest")]`).
   - `async Task` (never `async void`) for async tests; `await` the SUT.
   - Match the file conventions Step 0 found (e.g. `#nullable enable` at
     the top of new files where the project uses it).
   - Each test **fully independent** — no shared mutable state; arrange
     everything per test (or in the fixture setup), never rely on
     execution order.

7. **Verify coverage.** Run the scoped test project with coverage and
   confirm the target class hits `line-rate` = 1, `branch-rate` = 1, and
   every method exercised. See `references/coverage-workflow.md`.

## Verification

Follow `references/coverage-workflow.md`:

- Run **only** the test project that covers your change (per the root
  `CLAUDE.md` Verification table), filtered to the target fixture with
  `--filter "FullyQualifiedName~{Fixture}"`.
- Collect coverage the way the project is set up (Step 0) — e.g.
  `coverlet.msbuild`, a `coverlet.collector` runsettings, or
  `dotnet test --collect`. **If the project uses `coverlet.msbuild`,
  build single-threaded (`-m:1`)** — it instruments during the build, so
  parallel MSBuild (`/maxcpucount`) can corrupt its output.
- Read the coverage report (cobertura, when available) and confirm
  `line-rate` and `branch-rate` are `1` for the class under test, with
  every method covered.
- If no coverage collector is available, fall back to the manual
  branch-enumeration checklist in the reference.

## Quality checklist (before declaring done)

- [ ] 100% line, branch, and method coverage for the SUT, proven by the
      coverage report (not asserted from memory).
- [ ] Every branch from the step-3 enumeration has a test.
- [ ] Test data comes from fluent builders; existing builders reused, new
      ones follow the repo pattern.
- [ ] Where the project has a shared aggregate/repository builder, it is
      used for those grouped dependencies.
- [ ] SUT constructed via a harness (or inline setup matching neighbors,
      per the user's refactor choice).
- [ ] The project's naming grammar, test-framework attributes, category/
      trait convention, and code-style rules (line length, member
      ordering, private-method naming) all followed.
- [ ] The project's assertion library used consistently; async tests are
      `async Task` and awaited.
- [ ] No shared mutable state between tests; each runs independently.
- [ ] Scoped test run is green.

## References

- `references/builder-pattern.md` — fluent data builders and the shared
  aggregate/repository builder shape, with annotated examples.
- `references/harness-pattern.md` — composition-root harness, with an
  annotated example and how it differs from an integration base class.
- `references/coverage-workflow.md` — scoped coverage run, reading the
  cobertura report, and the manual branch-enumeration fallback.
