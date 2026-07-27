# Infrastructure Testing Patterns

Patterns for testing Redis, RabbitMQ, multi-container networks, container reuse, and database reset with Respawn.

## Contents

- [Redis Integration Tests](#redis-integration-tests)
- [RabbitMQ Integration Tests](#rabbitmq-integration-tests)
- [Multi-Container Networks](#multi-container-networks)
- [Reusing Containers Across Tests](#reusing-containers-across-tests)
- [Database Reset with Respawn](#database-reset-with-respawn)

## Redis Integration Tests

```csharp
[TestFixture]
public class RedisTests
{
    private TestcontainersContainer _redisContainer = null!;
    private IConnectionMultiplexer _redis = null!;

    [SetUp]
    public async Task SetUpAsync()
    {
        _redisContainer = new TestcontainersBuilder<TestcontainersContainer>()
            .WithImage("redis:alpine")
            .WithPortBinding(6379, true)
            .WithWaitStrategy(Wait.ForUnixContainer().UntilPortIsAvailable(6379))
            .Build();

        await _redisContainer.StartAsync();

        var port = _redisContainer.GetMappedPublicPort(6379);
        _redis = await ConnectionMultiplexer.ConnectAsync($"localhost:{port}");
    }

    [TearDown]
    public async Task TearDownAsync()
    {
        await _redis.DisposeAsync();
        await _redisContainer.DisposeAsync();
    }

    [Test]
    public async Task Redis_ShouldCacheValues()
    {
        var db = _redis.GetDatabase();

        await db.StringSetAsync("key1", "value1");
        var value = await db.StringGetAsync("key1");

        Assert.That(value.ToString(), Is.EqualTo("value1"));
    }

    [Test]
    public async Task Redis_ShouldExpireKeys()
    {
        var db = _redis.GetDatabase();

        await db.StringSetAsync("temp-key", "temp-value",
            expiry: TimeSpan.FromSeconds(1));

        Assert.That(await db.KeyExistsAsync("temp-key"), Is.True);

        await Task.Delay(1100);

        Assert.That(await db.KeyExistsAsync("temp-key"), Is.False);
    }
}
```

## RabbitMQ Integration Tests

```csharp
[TestFixture]
public class RabbitMqTests
{
    private TestcontainersContainer _rabbitContainer = null!;
    private IConnection _connection = null!;

    [SetUp]
    public async Task SetUpAsync()
    {
        _rabbitContainer = new TestcontainersBuilder<TestcontainersContainer>()
            .WithImage("rabbitmq:management-alpine")
            .WithPortBinding(5672, true)
            .WithPortBinding(15672, true)
            .WithWaitStrategy(Wait.ForUnixContainer().UntilPortIsAvailable(5672))
            .Build();

        await _rabbitContainer.StartAsync();

        var port = _rabbitContainer.GetMappedPublicPort(5672);
        var factory = new ConnectionFactory
        {
            HostName = "localhost",
            Port = port,
            UserName = "guest",
            Password = "guest"
        };

        _connection = await factory.CreateConnectionAsync();
    }

    [TearDown]
    public async Task TearDownAsync()
    {
        await _connection.CloseAsync();
        await _rabbitContainer.DisposeAsync();
    }

    [Test]
    public async Task RabbitMq_ShouldPublishAndConsumeMessage()
    {
        using var channel = await _connection.CreateChannelAsync();

        var queueName = "test-queue";
        await channel.QueueDeclareAsync(queueName, durable: false,
            exclusive: false, autoDelete: true);

        var message = "Hello, RabbitMQ!";
        var body = Encoding.UTF8.GetBytes(message);
        await channel.BasicPublishAsync(exchange: "",
            routingKey: queueName,
            body: body);

        var consumer = new EventingBasicConsumer(channel);
        var tcs = new TaskCompletionSource<string>();

        consumer.Received += (model, ea) =>
        {
            var receivedMessage = Encoding.UTF8.GetString(ea.Body.ToArray());
            tcs.SetResult(receivedMessage);
        };

        await channel.BasicConsumeAsync(queueName, autoAck: true,
            consumer: consumer);

        var received = await tcs.Task.WaitAsync(TimeSpan.FromSeconds(5));

        Assert.That(received, Is.EqualTo(message));
    }
}
```

## Multi-Container Networks

When you need multiple containers to communicate:

```csharp
[TestFixture]
public class MultiContainerTests
{
    private INetwork _network = null!;
    private TestcontainersContainer _dbContainer = null!;
    private TestcontainersContainer _redisContainer = null!;

    [SetUp]
    public async Task SetUpAsync()
    {
        _network = new TestcontainersNetworkBuilder()
            .Build();

        _dbContainer = new TestcontainersBuilder<TestcontainersContainer>()
            .WithImage("postgres:latest")
            .WithNetwork(_network)
            .WithNetworkAliases("db")
            .WithEnvironment("POSTGRES_PASSWORD", "postgres")
            .Build();

        _redisContainer = new TestcontainersBuilder<TestcontainersContainer>()
            .WithImage("redis:alpine")
            .WithNetwork(_network)
            .WithNetworkAliases("redis")
            .Build();

        await _network.CreateAsync();
        await Task.WhenAll(
            _dbContainer.StartAsync(),
            _redisContainer.StartAsync());
    }

    [TearDown]
    public async Task TearDownAsync()
    {
        await Task.WhenAll(
            _dbContainer.DisposeAsync().AsTask(),
            _redisContainer.DisposeAsync().AsTask());
        await _network.DisposeAsync();
    }

    [Test]
    public async Task Containers_CanCommunicate()
    {
        // Both containers can reach each other via network aliases
        // db -> redis://redis:6379
        // redis -> postgres://db:5432
    }
}
```

## Reusing Containers Across Tests

For faster test execution, reuse one container across every test fixture in a namespace with a
`[SetUpFixture]`:

```csharp
namespace MyApp.IntegrationTests.Database;

[TestFixture]
public class FastDatabaseTests
{
    private DatabaseFixture Fixture => DatabaseCollection.Fixture;

    [Test]
    public async Task Test1()
    {
        // Use Fixture.Connection
    }

    [Test]
    public async Task Test2()
    {
        // Reuses the same container
    }
}

// Shared fixture
public class DatabaseFixture
{
    private readonly TestcontainersContainer _container;
    public IDbConnection Connection { get; private set; }

    public DatabaseFixture()
    {
        _container = new TestcontainersBuilder<TestcontainersContainer>()
            .WithImage("mcr.microsoft.com/mssql/server:2022-latest")
            .WithEnvironment("ACCEPT_EULA", "Y")
            .WithEnvironment("SA_PASSWORD", "Your_password123")
            .WithPortBinding(1433, true)
            .Build();
    }

    public async Task InitializeAsync()
    {
        await _container.StartAsync();
        // Setup connection
    }

    public async Task DisposeAsync()
    {
        await Connection.DisposeAsync();
        await _container.DisposeAsync();
    }
}

// Runs once for every fixture in this namespace
[SetUpFixture]
public class DatabaseCollection
{
    public static DatabaseFixture Fixture { get; private set; } = null!;

    [OneTimeSetUp]
    public async Task OneTimeSetUpAsync()
    {
        Fixture = new DatabaseFixture();
        await Fixture.InitializeAsync();
    }

    [OneTimeTearDown]
    public async Task OneTimeTearDownAsync() => await Fixture.DisposeAsync();
}
```

## Database Reset with Respawn

When reusing containers, use [Respawn](https://github.com/jbogard/Respawn) to reset database state between tests:

```xml
<PackageReference Include="Respawn" Version="*" />
```

### Basic Respawn Setup

```csharp
using Respawn;

// Driven by the [SetUpFixture] above
public class DatabaseFixture
{
    private readonly TestcontainersContainer _container;
    private Respawner _respawner = null!;
    public NpgsqlConnection Connection { get; private set; } = null!;
    public string ConnectionString { get; private set; } = null!;

    public async Task InitializeAsync()
    {
        await _container.StartAsync();

        var port = _container.GetMappedPublicPort(5432);
        ConnectionString = $"Host=localhost;Port={port};Database=testdb;Username=postgres;Password=postgres";

        Connection = new NpgsqlConnection(ConnectionString);
        await Connection.OpenAsync();

        await RunMigrationsAsync();

        _respawner = await Respawner.CreateAsync(ConnectionString, new RespawnerOptions
        {
            TablesToIgnore = new Table[]
            {
                "__EFMigrationsHistory",
                "AspNetRoles",
                "schema_version"
            },
            DbAdapter = DbAdapter.Postgres
        });
    }

    public async Task ResetDatabaseAsync()
    {
        await _respawner.ResetAsync(ConnectionString);
    }

    public async Task DisposeAsync()
    {
        await Connection.DisposeAsync();
        await _container.DisposeAsync();
    }
}
```

### Using Respawn in Tests

```csharp
namespace MyApp.IntegrationTests.Database;

[TestFixture]
public class OrderTests
{
    private DatabaseFixture Fixture => DatabaseCollection.Fixture;

    // NUnit reuses one fixture instance for the whole class, so reset the shared
    // database before every test rather than relying on a new instance.
    [SetUp]
    public async Task SetUpAsync()
    {
        await Fixture.ResetDatabaseAsync();
    }

    [Test]
    public async Task CreateOrder_ShouldPersist()
    {
        await Fixture.Connection.ExecuteAsync(
            "INSERT INTO orders (customer_id, total) VALUES (@CustomerId, @Total)",
            new { CustomerId = "CUST1", Total = 100.00m });

        var count = await Fixture.Connection.QuerySingleAsync<int>(
            "SELECT COUNT(*) FROM orders");

        Assert.That(count, Is.EqualTo(1));
    }

    [Test]
    public async Task AnotherTest_StartsWithCleanDatabase()
    {
        var count = await Fixture.Connection.QuerySingleAsync<int>(
            "SELECT COUNT(*) FROM orders");

        Assert.That(count, Is.EqualTo(0)); // Clean slate!
    }
}
```

### Respawn Options

```csharp
var respawner = await Respawner.CreateAsync(connectionString, new RespawnerOptions
{
    TablesToIgnore = new Table[]
    {
        "__EFMigrationsHistory",
        new Table("public", "lookup_data"),
    },
    SchemasToInclude = new[] { "public", "app" },
    SchemasToExclude = new[] { "audit", "logging" },
    DbAdapter = DbAdapter.Postgres,
    WithReseed = true
});
```

### Why Respawn Over Container Recreation

| Approach | Pros | Cons |
|----------|------|------|
| **New container per test** | Complete isolation | Slow (10-30s per container) |
| **Respawn** | Fast (~50ms), preserves schema/migrations | Requires careful table exclusion |
| **Transaction rollback** | Fastest | Can't test commit behavior |
