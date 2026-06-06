var builder = WebApplication.CreateBuilder(args);

// Add services to the container.

builder.Services.AddControllers();

// Scoped: a new repository instance per scope (typically per HTTP request).
builder.Services.AddScoped<IProductRepository, ProductRepository>();
// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

// Double-buffer: two in-memory slots with an atomic active/passive swap (no IMemoryCache).
builder.Services.AddSingleton<ProductDoubleBuffer>();
builder.Services.AddSingleton<ProductCacheState>();
builder.Services.AddSingleton<IProductCacheService, ProductCacheService>();

// IHostedService runs outside the HTTP pipeline — refreshes the passive buffer on a timer.
builder.Services.AddHostedService<ProductCacheRefreshWorker>();

// Registers a readiness probe; expose it with app.MapHealthChecks("/health") when wiring ops endpoints.
builder.Services
    .AddHealthChecks()
    .AddCheck<ProductCacheHealthCheck>("product_cache");

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
