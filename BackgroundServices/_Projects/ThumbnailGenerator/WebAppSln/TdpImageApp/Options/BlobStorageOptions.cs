namespace TdpImageApp.Options;

internal sealed class BlobStorageOptions
{
    public const string SectionName = "BlobStorage";

    public string ServiceUri { get; set; } = string.Empty;

    public string UploadsContainer { get; set; } = "uploads";
}
