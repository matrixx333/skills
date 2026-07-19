# Fluent builder pattern

Fluent builders produce test data (entities, models, DTOs) with sensible
defaults so each test only names the fields it cares about. This keeps
tests short, intention-revealing, and resilient to unrelated constructor
or property changes.

> **Discover, don't assume.** Before creating a builder, glob the test
> project's builders folder (`**/*Builder*.cs`) and reuse what exists.
> (In the authoring repo they lived under
> `tests/App.Tests/Builders/` — e.g. `InvoiceBuilder`,
> `ScheduledAutoPaymentBuilder`, `RepositoriesBuilder` — but your
> layout and names will differ.) Match the style of the real neighbors
> over the examples here if they differ.

## Rules (generalized from real builders)

- **One builder per type**, named `{Type}Builder`, in the test project's
  builders folder and matching namespace (whatever the project calls it).
- **Private fields with non-null defaults**, initialized inline. Defaults
  should describe the *common valid case* (e.g. a frozen, non-canceled
  invoice). Use `Guid.NewGuid()` for ids so entities are distinct by
  default.
- **A `static {Type}Builder New()` factory** (`=> new();`) as the entry
  point — the authoring repo's convention. Prefer it over an `AValid…()`
  name unless the neighbors use something else.
- **Mutator methods return `this`** for chaining. Prefer **semantic
  names** that read like domain language (`ForCustomer`, `DueOn`,
  `OnDate`, `WithStatus`, `Numbered`, `Frozen`, `Disabled`) alongside the
  generic `WithId`. One concern per method.
- **A `{Type} Build()`** that constructs the object from the fields.
  Derive dependent fields inside `Build()` when it keeps callers honest
  (e.g. `Month`/`Year` derived from a `DueOn` date).
- **XML-doc `<summary>`** on the class stating what the defaults
  represent.
- Keep builders free of test-framework and mocking types — they build
  *data*, not behavior. (Mocked *dependencies* belong in the harness /
  repository builder.)

## Annotated example — entity builder

> **Worked example — authoring repo (yours will differ).** Generalized
> from the authoring repo's `InvoiceBuilder` (`ForCustomer` / `DueOn`
> semantic methods, defaults describing a frozen, non-canceled invoice).
> The namespaces and entity types below are that repo's — mirror your own
> project's instead.

```csharp
using App.Domain.Entities;

namespace App.Tests.Builders;

/// <summary>
/// Fluent builder for <see cref="Invoice"/> test entities. Defaults reflect a
/// frozen, non-canceled invoice with a random id and number.
/// </summary>
public class InvoiceBuilder
{
    // Non-null defaults describing the common valid case.
    private Guid _id = Guid.NewGuid();
    private Guid _customerId = Guid.NewGuid();
    private DateTime _dueOn = DateTime.UtcNow;
    private string _number = $"INV-{Guid.NewGuid():N}".Substring(0, 12);
    private bool _isFrozen = true;
    private bool _isCanceled = false;

    // Entry point.
    public static InvoiceBuilder New() => new();

    // Generic setter.
    public InvoiceBuilder WithId(Guid id)
    {
        _id = id;
        return this;
    }

    // Semantic, domain-reading setters.
    public InvoiceBuilder ForCustomer(Guid customerId)
    {
        _customerId = customerId;
        return this;
    }

    public InvoiceBuilder DueOn(DateTime dueOn)
    {
        _dueOn = dueOn;
        return this;
    }

    public InvoiceBuilder Canceled(bool isCanceled)
    {
        _isCanceled = isCanceled;
        return this;
    }

    public Invoice Build()
    {
        return new Invoice
        {
            Id = _id,
            CustomerId = _customerId,
            DueOn = _dueOn,
            Number = _number,
            Month = _dueOn.Month,   // derived from DueOn
            Year = _dueOn.Year,     // derived from DueOn
            IsFrozen = _isFrozen,
            IsCanceled = _isCanceled
        };
    }
}
```

Usage in a test — name only what matters:

```csharp
var invoice = InvoiceBuilder.New()
    .ForCustomer(customerId)
    .DueOn(new DateTime(2026, 3, 1))
    .Canceled(true)
    .Build();
```

## The shared aggregate/repository builder

Some codebases group many dependencies behind a single aggregate that a
SUT takes as one constructor argument — a repositories bag, a services
bundle, an options aggregate. Constructing it by hand in every test is
noise. If the project has a builder for that aggregate, use it; if you
need to create one, follow the "default everything, override the
interesting parts" shape shown here.

> **Worked example — authoring repo (yours will differ).** Services in
> the authoring repo took a `Repositories` aggregate (30+
> repositories), built with `RepositoriesBuilder`, which **defaults
> every repository to `Mock.Of<T>()`** so a test only supplies the
> repositories whose behavior it exercises:

```csharp
var mockInvoiceRepository = new Mock<IInvoiceRepository>();
var mockPaymentRepository = new Mock<IPaymentRepository>();

var repositories = new RepositoriesBuilder()
    .With(mockInvoiceRepository)     // pass the Mock<T>…
    .With(mockPaymentRepository)
    .Build();
```

`With<TRepository>(Mock<TRepository>)` registers a mock; an
`With<TRepository>(TRepository)` overload accepts a concrete instance.
Any repository you don't name is a no-op `Mock.Of<T>()`. Keep a field
reference to the `Mock<T>` you `.With(...)` so you can arrange behavior
(`.Setup(...)`) and verify calls (`.Verify(...)`).

> When creating a **new** aggregate/collaborator builder that follows
> this "default everything, override the interesting parts" shape, model
> it on `RepositoriesBuilder`: a `Dictionary<Type, object>` of
> overrides, `With(...)` returning `this`, and a `Build()` that falls
> back to `Mock.Of<T>()` for anything not overridden.

## Reuse vs. create — decision

1. **Reuse** an existing builder if one exists for the type. Add a
   missing semantic method to it rather than duplicating.
2. **Create** a new builder only when no builder covers the type. Put it
   in the test project's builders folder, follow the rules above, and
   mirror the closest existing builder.
3. Never inline a large object initializer in a test when a builder
   exists or is warranted — that is the repetition builders exist to kill.
