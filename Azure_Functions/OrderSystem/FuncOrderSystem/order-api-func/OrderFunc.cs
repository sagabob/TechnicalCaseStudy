using System.IO;
using System.Text.Json;
using System.Threading.Tasks;
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

        if (string.IsNullOrWhiteSpace(body))
        {
            return new BadRequestObjectResult(new { error = "Empty request body" });
        }

        JsonDocument doc;
        try
        {
            doc = JsonDocument.Parse(body);
        }
        catch (JsonException)
        {
            return new BadRequestObjectResult(new { error = "Invalid JSON" });
        }

        if (!TryValidateOrder(doc.RootElement, out var validationMessage))
        {
            return new BadRequestObjectResult(new { error = validationMessage });
        }

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

    private static bool TryValidateOrder(JsonElement root, out string message)
    {
        message = string.Empty;
        string[] requiredFields = { "customerName", "email", "items", "totalAmount", "orderDate" };

        foreach (var field in requiredFields)
        {
            if (root.TryGetProperty(field, out _)) continue;
            message = $"Missing required field: {field}";
            return false;
        }

        if (!root.TryGetProperty("items", out var itemsElement) || itemsElement.ValueKind != JsonValueKind.Array || itemsElement.GetArrayLength() == 0)
        {
            message = "Order items must be a non-empty list";
            return false;
        }

        foreach (var item in itemsElement.EnumerateArray())
        {
            if (!item.TryGetProperty("productId", out _ ) || !item.TryGetProperty("quantity", out var qtyElement))
            {
                message = "Each item must have productId and quantity";
                return false;
            }

            if (qtyElement.ValueKind == JsonValueKind.Number && qtyElement.TryGetInt32(out var qty) &&
                qty > 0) continue;
            message = "Item quantity must be a positive number";
            return false;
        }

        message = "Order is valid";
        return true;
    }
}
