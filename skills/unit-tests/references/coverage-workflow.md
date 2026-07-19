# Coverage workflow

Prove 100% line, branch, and method coverage for the class under test —
don't assert it from memory. **How coverage is collected is discovered in
Step 0**, and it drives the exact command below. Common C# setups:

- **`coverlet.msbuild`** — MSBuild properties on the test `.csproj`; a
  scoped `dotnet test` emits a cobertura report during the build. (Build
  single-threaded — see below.)
- **`coverlet.collector`** — a VSTest data collector driven by a
  `*.runsettings` and `dotnet test --collect:"XPlat Code Coverage"`; also
  emits cobertura.
- **`dotnet test --collect` / `dotnet-coverage`** — Microsoft's collector;
  emits a binary `.coverage` you convert to a readable format.

The report-reading steps below assume cobertura, which coverlet emits in
either mode.

> **Confirm the tooling first.** Read the test project's `.csproj` (and
> any `*.runsettings`) so you know which setup above applies and where the
> report lands.
>
> **Worked example — authoring repo (yours will differ).** There,
> `App.Tests.csproj` set `coverlet.msbuild` properties:
> ```xml
> <CollectCoverage>true</CollectCoverage>
> <CoverletOutputFormat>cobertura</CoverletOutputFormat>
> <CoverletOutput>$(MSBuildThisFileDirectory)../TestResults/Coverage/</CoverletOutput>
> <Include>[App.Services]*,[App.Repositories]*</Include>
> <Exclude>[*]*.Migrations.*</Exclude>
> ```
> So `dotnet test` on that project wrote
> `tests/TestResults/Coverage/coverage.cobertura.xml`. A separate
> `runsettings.runsettings` collector was CI-only and emitted a binary
> `.coverage`; local verification used the cobertura output.

## 1. Run the scoped test project with coverage

Run **only** the test project that covers your change (root `CLAUDE.md`
Verification table maps source → test project), filtered to the target
fixture:

```bash
# Shape of the command — substitute your project and fixture, plus the
# coverage flags your setup needs (none extra if CollectCoverage is
# already set on the csproj).
dotnet test <path/to/Your.Tests.csproj> \
  --filter "FullyQualifiedName~<YourFixture>" \
  -m:1   # coverlet.msbuild only — see below
```

**The `-m:1` rule is specific to `coverlet.msbuild`.** It instruments
during the build, so parallel MSBuild (`/maxcpucount`, `-m` with no
value) can interleave instrumentation and produce **incomplete or
corrupted** coverage output. When using `coverlet.msbuild`, build
single-threaded (`-m:1`) for any run whose coverage numbers you intend to
trust. (`/maxcpucount` is fine for a plain build — just not for a
coverage run. Collector-based setups don't need `-m:1`.)

Filter granularity (`dotnet test --filter`):

```bash
# Whole fixture
--filter "FullyQualifiedName~<YourFixture>"

# Single test by name
--filter "Name=<Your_Test_Name>"

# Only unit tests in the project (trait key varies by framework:
# NUnit/xUnit use Category, MSTest uses TestCategory)
--filter "Category=UnitTest"
```

> Coverage reflects only the code that executed. Running just the target
> fixture is correct for verifying *that class* — read the target class's
> element in the report and ignore the project-wide totals, which will be
> low because you only ran one fixture.

If you need to force/scope coverage output explicitly (e.g. the property
isn't set in a given project), pass it on the command line:

```bash
dotnet test <project.csproj> --filter "FullyQualifiedName~<Fixture>" -m:1 \
  /p:CollectCoverage=true \
  /p:CoverletOutputFormat=cobertura \
  /p:CoverletOutput=./TestResults/Coverage/ \
  /p:Include="[Assembly.Under.Test]Namespace.ClassUnderTest"
```

Scoping `Include` to the single class under test makes the report's
top-line numbers meaningful for that class.

## 2. Read the cobertura report and confirm 100%

Open the cobertura report (its path is set by your coverage config — in
the authoring repo it was
`tests/TestResults/Coverage/coverage.cobertura.xml`) and find the
`<class>` element for the class under test (by its `name` / `filename`
attribute). Confirm:

- `line-rate="1"` on that class element,
- `branch-rate="1"` on that class element,
- every `<method>` under it has `line-rate="1"` (no method left at 0),
- no `<line ... hits="0">` and no `<line ... branch="true"
  condition-coverage="…(x/y)">` where `x < y`.

Quick greps to locate the class block and any gaps:

```bash
# The class summary line (rates live on this element)
grep -n 'class name="Namespace.ClassUnderTest"' path/to/coverage.cobertura.xml

# Any unhit lines / partially-covered branches anywhere in the report
grep -nE 'hits="0"|condition-coverage="(?!100)' path/to/coverage.cobertura.xml
```

A partially covered branch shows as `condition-coverage="50% (1/2)"` on a
`<line branch="true">` — that means one side of an `if`/ternary/`&&`
never ran. Add the missing-side test and re-run.

## 3. Manual branch-enumeration fallback

If no coverage collector is available, enumerate branches by hand and map
each to a test. For the class under test, list:

- **Every public method / property getter+setter** → at least one test
  each (method coverage).
- **Every conditional**: each `if`/`else if`/`else`, each `switch` arm
  **including the default**, each ternary `?:` (both sides), each
  null-conditional `?.` / null-coalescing `??` (null and non-null), each
  `&&`/`||` (short-circuit and full-evaluation paths).
- **Every loop**: zero iterations, one, and many.
- **Every `try`/`catch`/`finally`**: the throwing path *and* the
  non-throwing path; one test per distinct `catch`.
- **Every guard/throw**: each `throw` (argument validation, domain
  exceptions) with a test asserting it via your assertion library (e.g.
  `act.Should().Throw<TException>()`, `Should.Throw<TException>(...)`, or
  `Assert.Throws<TException>(...)`).
- **Edge inputs**: null, empty collection, boundary values (0, max,
  off-by-one), duplicates, and any documented special case.

Check each item off as you write its test. When the list is exhausted and
every item has a test, coverage is complete by construction.

## 4. Definition of done

- Target class: `line-rate` = 1 and `branch-rate` = 1 in cobertura.
- Every method exercised; no `hits="0"`; no partial `condition-coverage`.
- The scoped test run is **green**.
- If `coverlet.msbuild` was used, the coverage run was `-m:1`
  (trustworthy numbers).
