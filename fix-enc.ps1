$files = Get-ChildItem -Path scripts\*.ps1
foreach ($f in $files) {
    $content = [System.IO.File]::ReadAllText($f.FullName)
    [System.IO.File]::WriteAllText($f.FullName, $content, [System.Text.Encoding]::UTF8)
}
Write-Host "Encoding fixed"
