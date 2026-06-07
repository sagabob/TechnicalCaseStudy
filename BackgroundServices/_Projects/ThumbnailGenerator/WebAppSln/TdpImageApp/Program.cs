using Azure.Core;
using Azure.Identity;
using TdpImageApp.Options;
using TdpImageApp.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();
builder.Services.Configure<BlobStorageOptions>(
    builder.Configuration.GetSection(BlobStorageOptions.SectionName));

builder.Services.AddSingleton<TokenCredential>(serviceProvider =>
{
    IConfiguration configuration = serviceProvider.GetRequiredService<IConfiguration>();
    string? tenantId = configuration["AZURE_TENANT_ID"];
    string? clientId = configuration["AZURE_CLIENT_ID"];
    string? clientSecret = configuration["AZURE_CLIENT_SECRET"];

    if (!string.IsNullOrWhiteSpace(tenantId) &&
        !string.IsNullOrWhiteSpace(clientId) &&
        !string.IsNullOrWhiteSpace(clientSecret))
    {
        return new ClientSecretCredential(tenantId, clientId, clientSecret);
    }

    return new DefaultAzureCredential();
});

builder.Services.AddSingleton<IImageStorageService, BlobImageStorageService>();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Upload/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthorization();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Upload}/{action=Index}/{id?}");

app.Run();
