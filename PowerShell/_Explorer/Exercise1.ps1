# Exercise 1: Write a script that reads the contents of the file sample.txt and displays the number of lines in the file.
$fileContent = Get-Content -Path ".\sample.txt"
Write-Host "Number of lines in the file: $($fileContent.Length)"
Write-Host "File content: $($fileContent)"

# Get one line at a time from the file (with line index)
$index = 0
$fileContent | ForEach-Object {
    Write-Host "Line ${index}: $_"
    $index++
}

