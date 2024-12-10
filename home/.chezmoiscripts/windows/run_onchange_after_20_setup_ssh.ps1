$env:HOME_VOLUME = $null
if (Test-Path "F:\Users\${env:UserName}") {
	$env:HOME_VOLUME = "F:"
} elseif (Test-Path "D:\Users\${env:UserName}") {
	$env:HOME_VOLUME = "D:"
} else {
	throw [System.Exception]::new("Could not locate home volume (D:\ or F:\)")
}

# Define paths
$symlinkPath = "C:\Users\${env:UserName}\.ssh"
$targetPath = "${env:HOME_VOLUME}\Users\${env:UserName}\.ssh"

Write-Host "Target ssh directory: ${targetPath}" -ForegroundColor Blue

# Check if the target directory exists
if (-not (Test-Path -Path $targetPath)) {
    Write-Host "Target directory does not exist: $targetPath" -ForegroundColor Red
    exit 1
}

# Check if the symlink exists
if (-not (Test-Path -Path $symlinkPath)) {
    Write-Host "Symlink does not exist. Creating: $symlinkPath -> $targetPath" -ForegroundColor Yellow
    New-Item -ItemType SymbolicLink -Path $symlinkPath -Target $targetPath > $null
    Write-Host "Symlink created successfully." -ForegroundColor Green
} else {
    $currentTarget = (Get-Item $symlinkPath).Target
    if ($currentTarget -ne $targetPath) {
        Write-Host "Symlink exists but points to a different target: $currentTarget" -ForegroundColor Red
    } else {
        Write-Host "Symlink already exists and points to the correct target." -ForegroundColor Green
    }
}
