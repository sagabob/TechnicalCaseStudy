using Azure.Core;
using Azure.Storage.Blobs;
using Microsoft.Extensions.Options;
using TdpImageApp.Options;

namespace TdpImageApp.Services;

internal sealed class BlobImageStorageService(
    IOptions<BlobStorageOptions> options,
    TokenCredential credential,
    ILogger<BlobImageStorageService> logger) : IImageStorageService
{
    private static readonly HashSet<string> AllowedExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"
    };

    public async Task<string> UploadAsync(IFormFile file, CancellationToken cancellationToken)
    {
        var settings = options.Value;

        if (string.IsNullOrWhiteSpace(settings.ServiceUri))
        {
            throw new InvalidOperationException(
                "BlobStorage:ServiceUri is not configured. Set it in appsettings or user secrets.");
        }

        if (file.Length == 0)
        {
            throw new InvalidOperationException("The selected file is empty.");
        }

        var extension = Path.GetExtension(file.FileName);
        if (!AllowedExtensions.Contains(extension))
        {
            throw new InvalidOperationException("Only image files are allowed.");
        }

        var blobServiceClient = new BlobServiceClient(
            new Uri(settings.ServiceUri),
            credential);

        var containerClient = blobServiceClient.GetBlobContainerClient(settings.UploadsContainer);
        var blobName = $"{Guid.NewGuid():N}{extension}";
        var blobClient = containerClient.GetBlobClient(blobName);

        logger.LogInformation("Uploading {FileName} as {BlobName}", file.FileName, blobName);

        await using Stream stream = file.OpenReadStream();
        await blobClient.UploadAsync(stream, overwrite: false, cancellationToken);

        return blobName;
    }
}
