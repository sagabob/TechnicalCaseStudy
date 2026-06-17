using System;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Builder;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Azure.Messaging.ServiceBus;

var builder = FunctionsApplication.CreateBuilder(args);

builder.ConfigureFunctionsWebApplication();

// Register ServiceBusClient for sending messages from functions
builder.Services.AddSingleton(sp =>
{
    var connection = Environment.GetEnvironmentVariable("SERVICE_BUS_CONNECTION_STRING");
    if (string.IsNullOrEmpty(connection))
    {
        throw new InvalidOperationException("Environment variable 'SERVICE_BUS_CONNECTION_STRING' is not set.");
    }
    return new ServiceBusClient(connection);
});

builder.Services
    .AddApplicationInsightsTelemetryWorkerService()
    .ConfigureFunctionsApplicationInsights();

builder.Build().Run();
