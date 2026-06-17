using Azure.Messaging.ServiceBus;
using Azure.Identity;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();

// Register ServiceBusClient for sending messages from functions
builder.Services.AddSingleton(sp =>
{
    // Prefer managed identity (Azure) when SERVICE_BUS_FQDN is set; fall back to connection string for local dev
    var fqdn = Environment.GetEnvironmentVariable("SERVICE_BUS_FQDN");
    var connection = Environment.GetEnvironmentVariable("SERVICE_BUS_CONNECTION_STRING");

    if (!string.IsNullOrEmpty(fqdn))
    {
        // Use DefaultAzureCredential which supports Managed Identity in Azure and developer credentials locally
        return new ServiceBusClient(fqdn, new DefaultAzureCredential());
    }

    return !string.IsNullOrEmpty(connection) ? new ServiceBusClient(connection) : throw new InvalidOperationException("Either SERVICE_BUS_FQDN or SERVICE_BUS_CONNECTION_STRING must be set.");
});

builder.Services
    .AddApplicationInsightsTelemetryWorkerService()
    .ConfigureFunctionsApplicationInsights();

builder.Build().Run();