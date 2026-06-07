(function () {
  const input = document.getElementById("image");
  const preview = document.getElementById("preview");
  const previewImage = document.getElementById("preview-image");
  const fileLabel = document.querySelector("[data-file-label]");

  if (!input || !preview || !previewImage || !fileLabel) {
    return;
  }

  let objectUrl = null;

  input.addEventListener("change", function () {
    if (objectUrl) {
      URL.revokeObjectURL(objectUrl);
      objectUrl = null;
    }

    const file = input.files && input.files[0];
    if (!file) {
      preview.hidden = true;
      previewImage.removeAttribute("src");
      fileLabel.textContent = "";
      return;
    }

    objectUrl = URL.createObjectURL(file);
    previewImage.src = objectUrl;
    fileLabel.textContent = file.name;
    preview.hidden = false;
  });
})();
