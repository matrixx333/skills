# Advanced Configuration Patterns

Validators with dependencies, named options, complete production example, and testing configuration validators.

## Contents

- [Validators with Dependencies](#validators-with-dependencies)
- [Named Options](#named-options)
- [Complete Example - Production Settings Class](#complete-example---production-settings-class)
- [Testing Configuration Validators](#testing-configuration-validators)

## Validators with Dependencies

IValidateOptions validators are resolved from DI, so they can have dependencies:

```csharp
public class DatabaseSettingsValidator : IValidateOptions<DatabaseSettings>
{
    private readonly ILogger<DatabaseSettingsValidator> _logger;
    private readonly IHostEnvironment _environment;

    public DatabaseSettingsValidator(
        ILogger<DatabaseSettingsValidator> logger,
        IHostEnvironment environment)
    {
        _logger = logger;
        _environment = environment;
    }

    public ValidateOptionsResult Validate(string? name, DatabaseSettings options)
    {
        var failures = new List<string>();

        if (string.IsNullOrWhiteSpace(options.ConnectionString))
        {
            failures.Add("ConnectionString is required");
        }

        // Environment-specific validation
        if (_environment.IsProduction())
        {
            if (options.ConnectionString?.Contains("localhost") == true)
            {
                failures.Add("Production cannot use localhost database");
            }

            if (!options.ConnectionString?.Contains("Encrypt=True") == true)
            {
                _logger.LogWarning("Production database connection should use encryption");
            }
        }

        // Validate connection string format
        if (!string.IsNullOrEmpty(options.ConnectionString))
        {
            try
            {
                var builder = new SqlConnectionStringBuilder(options.ConnectionString);
                if (string.IsNullOrEmpty(builder.DataSource))
                {
                    failures.Add("ConnectionString must specify a Data Source");
                }
            }
            catch (Exception ex)
            {
                failures.Add($"ConnectionString is malformed: {ex.Message}");
            }
        }

        return failures.Count > 0
            ? ValidateOptionsResult.Fail(failures)
            : ValidateOptionsResult.Success;
    }
}
```

## Named Options

When you have multiple instances of the same settings type (e.g., multiple database connections):

```csharp
// appsettings.json
{
  "Databases": {
    "Primary": {
      "ConnectionString": "Server=primary;..."
    },
    "Replica": {
      "ConnectionString": "Server=replica;..."
    }
  }
}

// Registration
builder.Services.AddOptions<DatabaseSettings>("Primary")
    .BindConfiguration("Databases:Primary")
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddOptions<DatabaseSettings>("Replica")
    .BindConfiguration("Databases:Replica")
    .ValidateDataAnnotations()
    .ValidateOnStart();

// Consumption
public class DataService
{
    private readonly DatabaseSettings _primary;
    private readonly DatabaseSettings _replica;

    public DataService(IOptionsSnapshot<DatabaseSettings> options)
    {
        _primary = options.Get("Primary");
        _replica = options.Get("Replica");
    }
}
```

### Named Options Validator

```csharp
public class DatabaseSettingsValidator : IValidateOptions<DatabaseSettings>
{
    public ValidateOptionsResult Validate(string? name, DatabaseSettings options)
    {
        var failures = new List<string>();
        var prefix = string.IsNullOrEmpty(name) ? "" : $"[{name}] ";

        if (string.IsNullOrWhiteSpace(options.ConnectionString))
        {
            failures.Add($"{prefix}ConnectionString is required");
        }

        // Name-specific validation
        if (name == "Primary" && options.ReadOnly)
        {
            failures.Add("Primary database cannot be read-only");
        }

        return failures.Count > 0
            ? ValidateOptionsResult.Fail(failures)
            : ValidateOptionsResult.Success;
    }
}
```

## Complete Example - Production Settings Class

```csharp
using System.ComponentModel.DataAnnotations;
using Microsoft.Extensions.Options;

public class MessagingSettings
{
    public const string SectionName = "MessagingSettings";

    [Required]
    public string ServiceName { get; set; } = "MyService";

    public MessagingExecutionMode ExecutionMode { get; set; } = MessagingExecutionMode.InProcess;

    public bool LogConfigOnStart { get; set; } = false;

    public TransportOptions TransportOptions { get; set; } = new();

    public BrokerOptions BrokerOptions { get; set; } = new();

    public ServiceDiscoveryOptions ServiceDiscoveryOptions { get; set; } = new();
}

public enum MessagingExecutionMode
{
    InProcess,   // In-memory transport, single node
    Distributed  // Networked transport across multiple nodes
}

public class MessagingSettingsValidator : IValidateOptions<MessagingSettings>
{
    private readonly IHostEnvironment _environment;

    public MessagingSettingsValidator(IHostEnvironment environment)
    {
        _environment = environment;
    }

    public ValidateOptionsResult Validate(string? name, MessagingSettings options)
    {
        var failures = new List<string>();

        // Basic validation
        if (string.IsNullOrWhiteSpace(options.ServiceName))
        {
            failures.Add("ServiceName is required");
        }

        // Mode-specific validation
        if (options.ExecutionMode == MessagingExecutionMode.Distributed)
        {
            ValidateDistributedMode(options, failures);
        }

        // Environment-specific validation
        if (_environment.IsProduction() && options.ExecutionMode == MessagingExecutionMode.InProcess)
        {
            failures.Add("InProcess execution mode is not allowed in production");
        }

        return failures.Count > 0
            ? ValidateOptionsResult.Fail(failures)
            : ValidateOptionsResult.Success;
    }

    private void ValidateDistributedMode(MessagingSettings options, List<string> failures)
    {
        if (string.IsNullOrEmpty(options.TransportOptions.PublicHostName))
        {
            failures.Add("TransportOptions.PublicHostName is required in Distributed mode");
        }

        if (options.TransportOptions.Port is null or < 0)
        {
            failures.Add("TransportOptions.Port must be >= 0 in Distributed mode");
        }

        if (options.ServiceDiscoveryOptions.Enabled)
        {
            ValidateServiceDiscovery(options.ServiceDiscoveryOptions, failures);
        }
        else if (options.BrokerOptions.KnownEndpoints?.Length == 0)
        {
            failures.Add("Either service discovery must be enabled or KnownEndpoints must be specified");
        }
    }

    private void ValidateServiceDiscovery(ServiceDiscoveryOptions options, List<string> failures)
    {
        if (string.IsNullOrEmpty(options.ServiceName))
        {
            failures.Add("ServiceDiscoveryOptions.ServiceName is required");
        }

        if (options.RequiredEndpointCount <= 0)
        {
            failures.Add("ServiceDiscoveryOptions.RequiredEndpointCount must be > 0");
        }

        switch (options.DiscoveryMethod)
        {
            case DiscoveryMethod.Config:
                if (options.ConfigServiceEndpoints?.Length == 0)
                {
                    failures.Add("ConfigServiceEndpoints required for Config discovery");
                }
                break;

            case DiscoveryMethod.AzureTableStorage:
                if (options.AzureDiscoveryOptions == null)
                {
                    failures.Add("AzureDiscoveryOptions required for Azure discovery");
                }
                break;
        }
    }
}

// Registration
builder.Services.AddOptions<MessagingSettings>()
    .BindConfiguration(MessagingSettings.SectionName)
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddSingleton<IValidateOptions<MessagingSettings>, MessagingSettingsValidator>();
```

## Testing Configuration Validators

```csharp
[TestFixture]
public class SmtpSettingsValidatorTests
{
    private readonly SmtpSettingsValidator _validator = new();

    [Test]
    public void Validate_WithValidSettings_ReturnsSuccess()
    {
        var settings = new SmtpSettings
        {
            Host = "smtp.example.com",
            Port = 587,
            Username = "user@example.com",
            Password = "secret"
        };

        var result = _validator.Validate(null, settings);

        result.Succeeded.Should().BeTrue();
    }

    [Test]
    public void Validate_WithMissingHost_ReturnsFail()
    {
        var settings = new SmtpSettings { Host = "" };

        var result = _validator.Validate(null, settings);

        result.Succeeded.Should().BeFalse();
        result.FailureMessage.Should().Contain("Host is required");
    }

    [Test]
    public void Validate_WithUsernameButNoPassword_ReturnsFail()
    {
        var settings = new SmtpSettings
        {
            Host = "smtp.example.com",
            Username = "user@example.com",
            Password = null  // Missing!
        };

        var result = _validator.Validate(null, settings);

        result.Succeeded.Should().BeFalse();
        result.FailureMessage.Should().Contain("Password is required");
    }
}
```
