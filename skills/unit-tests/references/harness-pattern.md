# Composition-root harness pattern

A **harness** is a test helper that owns the mocked dependencies of one
SUT, wires the SUT in its constructor, and exposes fluent `Given…()`
methods to arrange behavior. It turns a sprawling fixture-setup block into
a reusable, intention-revealing composition root and keeps each test's
Arrange section to only the behavior it cares about.

> **Discover before you build.** Glob `**/*Harness*.cs` first. If
> harnesses exist, match their shape. If none do, the composition root is
> probably inline in each fixture's setup — read a neighboring `*Tests.cs`
> to see exactly how the SUT is constructed, then generalize that into a
> reusable harness placed wherever the project keeps such helpers.
> Introduce a harness when a SUT has many dependencies or the setup
> repeats across tests; for a SUT with one or two dependencies, inline
> setup is fine.

## What inline setup looks like

> **Worked example — authoring repo (yours will differ).** From the
> authoring repo's `GeneralLedgerServiceTests` — mocks as fields, the
> shared repository builder, `Lazy<T>` wrappers, and the SUT constructed
> in NUnit `[SetUp]`. Your framework's setup hook (xUnit constructor,
> MSTest `[TestInitialize]`), dependency types, and namespaces will be
> your own:

```csharp
[SetUp]
public void SetUp()
{
    _mockContext = new Mock<IDataContext>();
    _mockTimeProvider = new Mock<ITimeProvider>();
    _mockInvoiceRepository = new Mock<IInvoiceRepository>();
    _mockGeneralLedgerRepository = new Mock<IGeneralLedgerRepository>();
    _mockPaymentRepository = new Mock<IPaymentRepository>();

    var mockRepositories = new RepositoriesBuilder()
        .With(_mockGeneralLedgerRepository)
        .With(_mockInvoiceRepository)
        .With(_mockPaymentRepository)
        .Build();

    _service = new GeneralLedgerService(
        new Lazy<IDataContext>(() => _mockContext.Object),
        new Lazy<ITimeProvider>(() => _mockTimeProvider.Object),
        new Lazy<IMemoryCache>(() => _mockMemoryCache.Object),
        mockRepositories,
        mockCrossCuttingServices,
        new Lazy<IInvoiceRepository>(() => _mockInvoiceRepository.Object),
        new Lazy<IGeneralLedgerRepository>(() => _mockGeneralLedgerRepository.Object),
        new Lazy<IPaymentRepository>(() => _mockPaymentRepository.Object)
    );
}
```

The harness pattern below packages exactly this into a class the fixture
can reuse.

## Rules

- **One harness per SUT**, named `{Sut}Harness`, placed wherever the
  project keeps its harnesses (glob `**/*Harness*.cs`; if none exist yet,
  put it beside the fixtures or in a `Harnesses/` folder, and match the
  test project's namespace convention).
- **Expose each mocked dependency as a public `Mock<T>` property** so
  tests can `.Setup(...)` / `.Verify(...)` against them. Initialize them
  in the constructor (or inline).
- **The constructor wires the SUT** from those mocks — mirror the SUT's
  real constructor exactly (including `Lazy<T>` wrappers and the shared
  repository builder where the real code uses them). Expose the built SUT
  via a property (e.g. `public GeneralLedgerService Service { get; }`).
- **Fluent `Given…()` arrangement methods return `this`** so a test
  reads as a sentence: `harness.GivenInvoiceExists(invoice).GivenTime(now)`.
  Each `Given…` encapsulates a common `Setup(...)` on one of the mocks.
- **Capture state when useful** — e.g. expose a property holding what a
  mocked `Save` was called with, so assertions read cleanly.
- Keep the harness focused on **one** SUT. Cross-cutting fakes shared by
  many fixtures belong in a shared helper, not in a per-SUT harness.

## Annotated example

> **Worked example — authoring repo (yours will differ).** Generalized
> from the authoring repo's inline `GeneralLedgerServiceTests` setup — its
> types, `Lazy<T>` wrappers, attributes, and namespaces are that repo's.

```csharp
using App.Time;
using Microsoft.Extensions.Caching.Memory;
using Moq;
using App.Data.Contexts;
using App.Domain.Entities;
using App.Repositories.GeneralLedger;
using App.Repositories.Invoice;
using App.Repositories.Payment;
using App.Services.GeneralLedger;
using App.Tests.Builders;

namespace App.Tests.Unit.Harnesses;

/// <summary>
/// Composition-root harness for <see cref="GeneralLedgerService"/>. Owns the
/// mocked dependencies, wires the SUT, and offers fluent Given… arrangement.
/// </summary>
public class GeneralLedgerServiceHarness
{
    // Mocked dependencies, exposed for Setup/Verify.
    public Mock<IDataContext> Context { get; } = new();
    public Mock<ITimeProvider> TimeProvider { get; } = new();
    public Mock<IMemoryCache> MemoryCache { get; } = new();
    public Mock<IInvoiceRepository> InvoiceRepository { get; } = new();
    public Mock<IGeneralLedgerRepository> GeneralLedgerRepository { get; } = new();
    public Mock<IPaymentRepository> PaymentRepository { get; } = new();

    // The wired SUT.
    public GeneralLedgerService Service { get; }

    public GeneralLedgerServiceHarness()
    {
        var repositories = new RepositoriesBuilder()
            .With(GeneralLedgerRepository)
            .With(InvoiceRepository)
            .With(PaymentRepository)
            .Build();

        Service = new GeneralLedgerService
        (
            new Lazy<IDataContext>(() => Context.Object),
            new Lazy<ITimeProvider>(() => TimeProvider.Object),
            new Lazy<IMemoryCache>(() => MemoryCache.Object),
            repositories,
            _crossCuttingServices(),
            new Lazy<IInvoiceRepository>(() => InvoiceRepository.Object),
            new Lazy<IGeneralLedgerRepository>(() => GeneralLedgerRepository.Object),
            new Lazy<IPaymentRepository>(() => PaymentRepository.Object)
        );
    }

    // Fluent arrangement — reads like a sentence in the test.
    public GeneralLedgerServiceHarness GivenInvoiceExists(Invoice invoice)
    {
        InvoiceRepository
            .Setup(r => r.GetByIdAsync(invoice.Id))
            .ReturnsAsync(invoice);
        return this;
    }

    public GeneralLedgerServiceHarness GivenTime(DateTime utcNow)
    {
        TimeProvider.Setup(t => t.UtcNow).Returns(utcNow);
        return this;
    }

    // Private helpers last, _camelCase per repo style.
    private CrossCuttingServices _crossCuttingServices()
    {
        return new CrossCuttingServices(/* … nulls / mocks … */);
    }
}
```

Usage in a fixture — the Arrange section shrinks to intent:

```csharp
[TestFixture]
[Category("UnitTest")]
public class GeneralLedgerServiceTests
{
    private GeneralLedgerServiceHarness _harness;

    [SetUp]
    public void SetUp() => _harness = new GeneralLedgerServiceHarness();

    [Test]
    public async Task Should_ApplyPayment_WhenInvoiceIsOpen()
    {
        // Arrange
        var invoice = InvoiceBuilder.New().DueOn(new DateTime(2026, 3, 1)).Build();
        _harness
            .GivenTime(new DateTime(2026, 3, 2))
            .GivenInvoiceExists(invoice);

        // Act
        var result = await _harness.Service.ApplyPaymentAsync(invoice.Id, 100m);

        // Assert
        result.Should().NotBeNull();
        _harness.PaymentRepository.Verify(r => r.SaveAsync(It.IsAny<Payment>()), Times.Once);
    }
}
```

## Harness vs. an integration base class

Many codebases have a base class or fixture for **integration** tests —
don't confuse it with a unit harness:

- A **harness** is for **unit** tests — it constructs one SUT from
  **mocks**, touches no database or DI container, and is fast and
  isolated.
- An **integration base class** spins up the real DI container, config,
  and a real (or in-memory) database; integration tests inherit it and
  usually carry an integration category/trait.

> **Worked example — authoring repo.** There the integration base was
> `BaseTestsSetup` (under `.../Tests/Setup/`), wiring the real DI
> container, Key Vault config, and SQLite-backed fixtures, with
> integration tests marked `[Category("IntegrationTest")]`.

Use a harness for unit coverage work; reach for the integration base only
when the test genuinely needs the wired-up container.
