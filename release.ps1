param(
    [switch]$AutoBuild
)

# 1. Read current version from pubspec.yaml
$pubspecPath = "pubspec.yaml"
$pubspecContent = Get-Content $pubspecPath
$versionLine = $pubspecContent | Where-Object { $_ -match "^version:\s*(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)\+(?<build>\d+)" }

if (-not $versionLine) {
    Write-Host "Could not find version string in pubspec.yaml" -ForegroundColor Red
    exit 1
}

$versionLine -match "^version:\s*(?<major>\d+)\.(?<minor>\d+)\.(?<patch>\d+)\+(?<build>\d+)" | Out-Null
$major = [int]$matches['major']
$minor = [int]$matches['minor']
$patch = [int]$matches['patch']
$build = [int]$matches['build']

# 2. Bump the version (increment patch and build)
$newPatch = $patch + 1
$newBuild = $build + 1
$oldVersionStr = "$major.$minor.$patch+$build"
$newVersionStr = "$major.$minor.$newPatch+$newBuild"
$oldAppVersion = "$major.$minor.$patch"
$newAppVersion = "$major.$minor.$newPatch"

Write-Host "Bumping version: $oldVersionStr -> $newVersionStr" -ForegroundColor Cyan

# 3. Update pubspec.yaml
(Get-Content $pubspecPath) -replace "version: \Q$oldVersionStr\E", "version: $newVersionStr" | Set-Content $pubspecPath

# 4. Update installer.iss
$issPath = "installer.iss"
if (Test-Path $issPath) {
    (Get-Content $issPath) -replace "#define MyAppVersion `"$oldAppVersion`"", "#define MyAppVersion `"$newAppVersion`"" | Set-Content $issPath
    Write-Host "Updated installer.iss to $newAppVersion" -ForegroundColor Green
}

# 5. Build Flutter
Write-Host "Building Flutter Windows executable..." -ForegroundColor Cyan
flutter build windows

# 6. Compile InnoSetup
$isccPath = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (Test-Path $isccPath) {
    Write-Host "Compiling Inno Setup installer..." -ForegroundColor Cyan
    & $isccPath $issPath
} else {
    Write-Host "ISCC.exe not found. Please open installer.iss in Inno Setup and click Compile, then press Enter here..." -ForegroundColor Yellow
    pause
}

# 7. Generate Hash and Update Manifest
$exePath = "installers\InferNotes_Setup_v$newAppVersion.exe"
if (Test-Path $exePath) {
    Write-Host "Calculating SHA-256 for $exePath..." -ForegroundColor Cyan
    $hash = (Get-FileHash $exePath -Algorithm SHA256).Hash.ToLower()
    
    # Save hash file
    $hash | Set-Content "installers\hash_v$newAppVersion.txt"
    Write-Host "Saved hash to installers\hash_v$newAppVersion.txt" -ForegroundColor Green

    # Update latest.json
    $jsonPath = "latest.json"
    $jsonContent = @"{
  ""version"": ""$newAppVersion"",
  ""downloadUrl"": ""https://github.com/omkar-4/infer_notes/releases/download/v$newAppVersion/InferNotes_Setup_v$newAppVersion.exe"",
  ""sha256"": ""$hash""
}"@
    $jsonContent | Set-Content $jsonPath -Encoding UTF8
    Write-Host "Updated latest.json successfully with hash: $hash" -ForegroundColor Green
    
    Write-Host "All done! You can now commit, push, and create your GitHub Release for v$newAppVersion!" -ForegroundColor Magenta
} else {
    Write-Host "Could not find compiled installer at $exePath." -ForegroundColor Red
}
