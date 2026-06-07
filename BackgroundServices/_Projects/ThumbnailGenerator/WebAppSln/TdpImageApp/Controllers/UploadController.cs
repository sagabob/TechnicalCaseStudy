using System.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using TdpImageApp.Models;
using TdpImageApp.Services;

namespace TdpImageApp.Controllers;

public sealed class UploadController(IImageStorageService imageStorageService) : Controller
{
    [HttpGet]
    public IActionResult Index()
    {
        return View();
    }

    [HttpPost]
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> Index(IFormFile? image, CancellationToken cancellationToken)
    {
        if (image is null || image.Length == 0)
        {
            TempData["Error"] = "Please choose an image file.";
            return View();
        }

        try
        {
            string blobName = await imageStorageService.UploadAsync(image, cancellationToken);
            TempData["Success"] = $"Uploaded successfully as {blobName}.";
        }
        catch (Exception ex)
        {
            TempData["Error"] = ex.Message;
        }

        return View();
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel
        {
            RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier
        });
    }
}
