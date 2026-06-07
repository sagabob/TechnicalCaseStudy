namespace TdpImageApp.Services;

public interface IImageStorageService
{
    Task<string> UploadAsync(IFormFile file, CancellationToken cancellationToken);
}
