using System.Text.Json;
using Azure.Messaging.ServiceBus;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace order_api_func;

public class OrderFunc(ILogger<OrderFunc> logger, ServiceBusClient serviceBusClient)
{
    [Function(nameof(OrderFunc))]
    public async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequest req)
    {
        logger.LogInformation("C# HTTP trigger function received an order request.");

        using var reader = new StreamReader(req.Body);
        var body = await reader.ReadToEndAsync();

        if (string.IsNullOrWhiteSpace(body)) return new BadRequestObjectResult(new { error = "Empty request body" });

        JsonDocument doc;
        try
        {
            doc = JsonDocument.Parse(body);
        }
        catch (JsonException)
        {
            return new BadRequestObjectResult(new { error = "Invalid JSON" });
        }

        if (!OrderValidator.TryValidateOrder(doc.RootElement, out var validationMessage))
            return new BadRequestObjectResult(new { error = validationMessage });

        var queueName = Environment.GetEnvironmentVariable("QUEUE_NAME") ?? "orders-queue";

        try
        {
            var sender = serviceBusClient.CreateSender(queueName);
            var message = new ServiceBusMessage(body);
            await sender.SendMessageAsync(message);

            return new OkObjectResult(new { message = "Order has been processed successfully." });
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Error sending a message on the queue");
            return new ObjectResult(new { error = $"Service bus issue: {ex.Message}" }) { StatusCode = 500 };
        }
    }


}