---
name: verify-email-snapshots
description: Snapshot test email templates using Verify to catch regressions. Validates rendered HTML output matches approved baseline. Works with MJML templates and any email renderer.
invocable: false
---

# Snapshot Testing Email Templates with Verify

## When to Use This Skill

Use this skill when:
- Testing email template rendering for regressions
- Validating MJML templates compile to expected HTML
- Reviewing email changes in code review (diffs are visual)
- Ensuring variable substitution works correctly

**Related skills:**
- `aspnetcore/mjml-email-templates` - MJML template authoring
- `aspire/mailpit-integration` - Test email delivery locally
- `testing/snapshot-testing` - General Verify patterns

---

## Why Snapshot Test Emails?

Email templates are:
1. **Visual** - Small changes can break rendering across clients
2. **Hard to unit test** - Output is complex HTML, not simple values
3. **Prone to regression** - Template changes can have unintended effects

Snapshot testing captures the rendered HTML and fails when it changes unexpectedly.

---

## Installation

```bash
dotnet add package Verify.NUnit  # or Verify.Xunit, Verify.MSTest
```

---

## Basic Email Snapshot Test

```csharp
[Test]
public async Task UserSignupInvitation_RendersCorrectly()
{
    // Arrange
    var renderer = _services.GetRequiredService<IMjmlTemplateRenderer>();

    var variables = new Dictionary<string, string>
    {
        { "PreviewText", "You've been invited to join Acme Corp" },
        { "OrganizationName", "Acme Corporation" },
        { "InviteeName", "John Doe" },
        { "InviterName", "Jane Admin" },
        { "InvitationLink", "https://example.com/invite/abc123" },
        { "ExpirationDate", "December 31, 2025" }
    };

    // Act
    var html = await renderer.RenderTemplateAsync(
        "UserInvitations/UserSignupInvitation",
        variables);

    // Assert
    await Verify(html, extension: "html");
}
```

This creates `UserSignupInvitation_RendersCorrectly.verified.html` on first run.

---

## Reviewing Email Changes

When a template changes, the test fails with a diff. Review options:

### 1. Visual Diff Tool

```bash
# Configure diff tool (one-time)
dotnet tool install -g verify.tool
verify accept  # Accept all pending changes
verify review  # Open diff tool
```

### 2. Browser Preview

Open the `.received.html` file in a browser to see the actual rendering.

### 3. IDE Integration

Most IDEs show inline diffs for `.verified.html` vs `.received.html` files.

---

## Test Each Template Variant

Create tests for each email template to catch regressions:

```csharp
[TestFixture]
public class EmailTemplateSnapshotTests : EmailTestFixture
{
    private IMjmlTemplateRenderer _renderer = null!;

    // Runs after the base fixture's [OneTimeSetUp] has built Services
    [OneTimeSetUp]
    public void ResolveRenderer()
    {
        _renderer = Services.GetRequiredService<IMjmlTemplateRenderer>();
    }

    [Test]
    public async Task WelcomeEmail_NewUser() =>
        await VerifyTemplate("Welcome/NewUser", new Dictionary<string, string>
        {
            { "UserName", "John Doe" },
            { "LoginUrl", "https://example.com/login" }
        });

    [Test]
    public async Task WelcomeEmail_InvitedUser() =>
        await VerifyTemplate("Welcome/InvitedUser", new Dictionary<string, string>
        {
            { "UserName", "John Doe" },
            { "InviterName", "Jane Admin" },
            { "OrganizationName", "Acme Corp" }
        });

    [Test]
    public async Task PasswordReset() =>
        await VerifyTemplate("PasswordReset/PasswordReset", new Dictionary<string, string>
        {
            { "UserName", "John Doe" },
            { "ResetLink", "https://example.com/reset/abc123" },
            { "ExpirationMinutes", "30" }
        });

    [Test]
    public async Task PaymentReceipt() =>
        await VerifyTemplate("Billing/PaymentReceipt", new Dictionary<string, string>
        {
            { "UserName", "John Doe" },
            { "Amount", "$10.00" },
            { "InvoiceNumber", "INV-2025-001" },
            { "Date", "January 15, 2025" }
        });

    private async Task VerifyTemplate(
        string templateName,
        Dictionary<string, string> variables)
    {
        var html = await _renderer.RenderTemplateAsync(templateName, variables);
        await Verify(html, extension: "html")
            .UseMethodName(templateName.Replace("/", "_"));
    }
}
```

---

## Scrubbing Dynamic Values

Some values change between test runs. Scrub them:

```csharp
[Test]
public async Task EmailWithTimestamp_ScrubsDynamicValues()
{
    var html = await _renderer.RenderTemplateAsync("Welcome", variables);

    await Verify(html, extension: "html")
        .ScrubLinesContaining("Generated at:")
        .ScrubInlineGuids();  // Scrubs GUIDs in URLs
}
```

### Common Scrubbers

```csharp
// Scrub dates
.ScrubLinesContaining("Date:")
.AddScrubber(s => Regex.Replace(s, @"\d{4}-\d{2}-\d{2}", "SCRUBBED-DATE"))

// Scrub URLs with tokens
.AddScrubber(s => Regex.Replace(s, @"token=[a-zA-Z0-9]+", "token=SCRUBBED"))

// Scrub GUIDs
.ScrubInlineGuids()
```

---

## Test Fixture for Email Tests

```csharp
public abstract class EmailTestFixture
{
    public IServiceProvider Services { get; private set; } = null!;

    [OneTimeSetUp]
    public async Task InitializeAsync()
    {
        var services = new ServiceCollection();

        services.AddSingleton<IConfiguration>(new ConfigurationBuilder()
            .AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["SiteUrl"] = "https://example.com"
            })
            .Build());

        services.AddSingleton<IMjmlTemplateRenderer, MjmlTemplateRenderer>();

        Services = services.BuildServiceProvider();

        await Task.CompletedTask;
    }

    [OneTimeTearDown]
    public Task DisposeAsync() => Task.CompletedTask;
}
```

---

## Composer Snapshot Tests

Test the full composer output including subject and metadata:

```csharp
[Test]
public async Task SignupInvitation_ComposesCorrectEmail()
{
    var composer = _services.GetRequiredService<IUserEmailComposer>();

    var email = await composer.ComposeSignupInvitationAsync(
        recipientEmail: new EmailAddress("john@example.com"),
        recipientName: new PersonName("John Doe"),
        inviterName: new PersonName("Jane Admin"),
        organizationName: new OrganizationName("Acme Corp"),
        invitationUrl: new AbsoluteUri("https://example.com/invite/abc123"),
        expiresAt: new DateTimeOffset(2025, 12, 31, 0, 0, 0, TimeSpan.Zero));

    // Verify the full email object (subject, to, body)
    await Verify(new
    {
        email.To,
        email.Subject,
        HtmlBody = email.HtmlBody  // Will be stored as .html extension
    });
}
```

---

## CI Integration

### Fail on Missing Baseline

In CI, fail if no `.verified.html` file exists (prevents accidental acceptance):

```csharp
// In test setup or ModuleInitializer
VerifierSettings.ThrowOnMissingVerifiedFile();
```

### Git Configuration

Add to `.gitattributes` to improve diff handling:

```gitattributes
*.verified.html linguist-language=HTML
*.verified.html diff=html
```

---

## Best Practices

### DO

```csharp
// DO: Test each template variant
[Test] Task WelcomeEmail_NewUser_RendersCorrectly()
[Test] Task WelcomeEmail_InvitedUser_RendersCorrectly()

// DO: Use descriptive test names
[Test] Task PaymentReceipt_WithRefund_ShowsRefundAmount()

// DO: Scrub dynamic values consistently
.ScrubLinesContaining("Generated at:")

// DO: Review diffs carefully before accepting
verify review
```

### DON'T

```csharp
// DON'T: Skip email testing
// DON'T: Auto-accept changes without review
verify accept --all  // Dangerous!

// DON'T: Test only happy path
// DON'T: Ignore snapshot test failures
```

---

## Workflow

1. **Create template** - Write MJML template
2. **Write test** - Add snapshot test with sample variables
3. **Run test** - First run creates `.verified.html`
4. **Review** - Open in browser, verify rendering
5. **Commit** - Include `.verified.html` in source control
6. **Iterate** - Changes fail test, review diff, accept if correct

---

## Resources

- **Verify**: https://github.com/VerifyTests/Verify
- **Verify.NUnit**: https://github.com/VerifyTests/Verify#nunit
- **Diff Tools**: https://github.com/VerifyTests/DiffEngine
