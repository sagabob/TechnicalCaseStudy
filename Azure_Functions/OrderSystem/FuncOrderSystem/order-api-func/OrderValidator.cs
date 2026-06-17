using System.Text.Json;

namespace order_api_func;

public static class OrderValidator
{
    public static bool TryValidateOrder(JsonElement root, out string message)
    {
        message = string.Empty;
        string[] requiredFields = { "customerName", "email", "items", "totalAmount", "orderDate" };

        foreach (var field in requiredFields)
        {
            if (root.TryGetProperty(field, out _)) continue;
            message = $"Missing required field: {field}";
            return false;
        }

        if (!root.TryGetProperty("items", out var itemsElement) || itemsElement.ValueKind != JsonValueKind.Array ||
            itemsElement.GetArrayLength() == 0)
        {
            message = "Order items must be a non-empty list";
            return false;
        }

        foreach (var item in itemsElement.EnumerateArray())
        {
            if (!item.TryGetProperty("productId", out _) || !item.TryGetProperty("quantity", out var qtyElement))
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
