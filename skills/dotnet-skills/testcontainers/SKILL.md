---
name: testcontainers-integration-tests
description: Write integration tests using TestContainers for .NET with NUnit. Covers infrastructure testing with real databases, message queues, and caches in Docker containers instead of mocks.
invocable: false
---

# Integration Testing with TestContainers

## When to Use This Skill

Use this skill when:
- Writing integration tests that need real infrastructure (databases, caches, message queues)
- Testing data access layers against actual databases
- Verifying message queue integrations
- Testing Redis caching behavior
- Avoiding mocks for infrastructure components
- Ensuring tests work against production-like environments
- Testing database migrations and schema changes

## Reference Files

- [database-patterns.md](database-patterns.md): SQL Server, PostgreSQL, and migration testing examples
- [infrastructure-patterns.md](infrastructure-patterns.md): Redis, RabbitMQ, multi-container networks, container reuse, and Respawn

## Core Principles

1. **Real Infrastructure Over Mocks** - Use actual databases/services in containers, not mocks
2. **Test Isolation** - Each test gets fresh containers or fresh data
3. **Automatic Cleanup** - TestContainers handles container lifecycle and cleanup
4. **Fast Startup** - Reuse containers across tests in the same class when appropriate
5. **CI/CD Compatible** - Works seamlessly in Docker-enabled CI environments
6. **Port Randomization** - Containers use random ports to avoid conflicts

## Why TestContainers Over Mocks?

### The Problem with Mocking Infrastructure

```csharp
// BAD: Mocking a database
[TestFixture]
public class OrderRepositoryTests
{
    private readonly Mock<IDbConnection> _mockDb = new();

    [Test]
    public async Task GetOrder_ReturnsOrder()
    {
        // This doesn't test real SQL behavior, constraints, or performance
        _mockDb.Setup(db => db.QueryAsync<Order>(It.IsAny<string>()))
            .ReturnsAsync(new[] { new Order { Id = 1 } });

        var repo = new OrderRepository(_mockDb.Object);
        var order = await repo.GetOrderAsync(1);

        Assert.That(order, Is.Not.Null);
    }
}
```

Problems: doesn't test actual SQL queries, misses constraints/indexes, gives false confidence, doesn't catch SQL syntax errors.

### Better: TestContainers with Real Database

```csharp
// GOOD: Testing against a real database
[TestFixture]
public class OrderRepositoryTests
{
    private TestcontainersContainer _dbContainer = null!;
    private IDbConnection _connection = null!;

    // NUnit reuses one fixture instance for every test, so build the container in
    // [SetUp] (not the constructor) to give each test its own database.
    [SetUp]
    public async Task SetUpAsync()
    {
        _dbContainer = new TestcontainersBuilder<TestcontainersContainer>()
            .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
            .WithEnvironment("ACCEPT_EULA", "Y")
            .WithEnvironment("SA_PASSWORD", "Your_password123")
            .WithPortBinding(1433, true)
            .Build();

        await _dbContainer.StartAsync();
        var port = _dbContainer.GetMappedPublicPort(1433);
        var connectionString = $"Server=localhost,{port};Database=TestDb;User Id=sa;Password=Your_password123;TrustServerCertificate=true";
        _connection = new SqlConnection(connectionString);
        await _connection.OpenAsync();
        await RunMigrationsAsync(_connection);
    }

    [TearDown]
    public async Task TearDownAsync()
    {
        await _connection.DisposeAsync();
        await _dbContainer.DisposeAsync();
    }

    [Test]
    public async Task GetOrder_WithRealDatabase_ReturnsOrder()
    {
        await _connection.ExecuteAsync(
            "INSERT INTO Orders (Id, CustomerId, Total) VALUES (1, 'CUST1', 100.00)");

        var repo = new OrderRepository(_connection);
        var order = await repo.GetOrderAsync(1);

        Assert.That(order, Is.Not.Null);
        Assert.That(order.CustomerId, Is.EqualTo("CUST1"));
        Assert.That(order.Total, Is.EqualTo(100.00m));
    }
}
```

See [database-patterns.md](database-patterns.md) for complete SQL Server, PostgreSQL, and migration testing examples.

See [infrastructure-patterns.md](infrastructure-patterns.md) for Redis, RabbitMQ, multi-container networks, container reuse, and Respawn database reset patterns.

## Required NuGet Packages

```xml
<ItemGroup>
  <PackageReference Include="Testcontainers" Version="*" />
  <PackageReference Include="NUnit" Version="*" />
  <PackageReference Include="NUnit3TestAdapter" Version="*" />
  <PackageReference Include="NUnit.Analyzers" Version="*" />

  <!-- Database-specific packages -->
  <PackageReference Include="Microsoft.Data.SqlClient" Version="*" />
  <PackageReference Include="Npgsql" Version="*" /> <!-- For PostgreSQL -->
  <PackageReference Include="MySqlConnector" Version="*" /> <!-- For MySQL -->

  <!-- Other infrastructure -->
  <PackageReference Include="StackExchange.Redis" Version="*" /> <!-- For Redis -->
  <PackageReference Include="RabbitMQ.Client" Version="*" /> <!-- For RabbitMQ -->
</ItemGroup>
```

## Best Practices

1. **Always Use Async Lifecycle Attributes** - Async `[SetUp]`/`[TearDown]` per test, or `[OneTimeSetUp]`/`[OneTimeTearDown]` per fixture
2. **Wait for Port Availability** - Use `WaitStrategy` to ensure containers are ready
3. **Use Random Ports** - Let TestContainers assign ports automatically
4. **Clean Data Between Tests** - Either use fresh containers or truncate tables
5. **Reuse Containers When Possible** - Faster than creating new ones for each test
6. **Test Real Queries** - Don't just test mocks; verify actual SQL behavior
7. **Verify Constraints** - Test foreign keys, unique constraints, indexes
8. **Test Transactions** - Verify rollback and commit behavior
9. **Use Realistic Data** - Test with production-like data volumes
10. **Handle Cleanup** - Always dispose containers in `[TearDown]` or `[OneTimeTearDown]`

## Common Issues and Solutions

### Container Startup Timeout

```csharp
_container = new TestcontainersBuilder<TestcontainersContainer>()
    .WithImage("postgres:latest")
    .WithWaitStrategy(Wait.ForUnixContainer()
        .UntilPortIsAvailable(5432)
        .WithTimeout(TimeSpan.FromMinutes(2)))
    .Build();
```

### Port Already in Use

Always use random port mapping:
```csharp
.WithPortBinding(5432, true) // true = assign random public port
```

### Containers Not Cleaning Up

Ensure proper disposal:
```csharp
[TearDown]
public async Task TearDownAsync()
{
    await _connection?.DisposeAsync();
    await _container?.DisposeAsync();
}
```

### Tests Fail in CI But Pass Locally

Ensure CI has Docker support:
```yaml
# GitHub Actions
runs-on: ubuntu-latest # Has Docker pre-installed
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Integration Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Setup .NET
      uses: actions/setup-dotnet@v3
      with:
        dotnet-version: 9.0.x

    - name: Run Integration Tests
      run: |
        dotnet test tests/YourApp.IntegrationTests \
          --filter Category=Integration \
          --logger trx

    - name: Cleanup Containers
      if: always()
      run: docker container prune -f
```

## Performance Tips

1. **Reuse containers** - Share a fixture across tests with a `[SetUpFixture]`
2. **Use Respawn** - Reset data without recreating containers
3. **Parallel execution** - NUnit runs serially unless you opt in with `[Parallelizable]`; when you do, TestContainers handles port conflicts automatically
4. **Use lightweight images** - Alpine versions are smaller and faster
5. **Cache images** - Docker will cache pulled images locally
