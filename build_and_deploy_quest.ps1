# Mega Man X VR - Meta Quest Build & Deploy Script
$ErrorActionPreference = "Stop"

$baseDir = Split-Path -Parent $PSScriptRoot
Set-Location $baseDir

Write-Host "=== 1. Setting Up Android Build Environment ===" -ForegroundColor Cyan
$env:JAVA_HOME = "C:\Program Files\Android\Android Studio\jbr"
$env:ANDROID_HOME = "C:\Users\digit\AppData\Local\Android\Sdk"
$keystorePath = "C:\Users\digit\AppData\Roaming\Godot\keystores\debug.keystore"
$apkSigner = "C:\Users\digit\AppData\Local\Android\Sdk\build-tools\34.0.0\apksigner.bat"

Write-Host "=== 2. Compiling Android APK with Gradle ===" -ForegroundColor Cyan
Set-Location "$baseDir\android\build"
.\gradlew.bat assembleStandardDebug
Set-Location $baseDir

$sourceApk = "$baseDir\android\build\build\outputs\apk\standard\debug\android_debug.apk"
$targetApk = "$baseDir\build\MegaManXVR.apk"

if (-not (Test-Path "$baseDir\build")) {
    New-Item -ItemType Directory -Path "$baseDir\build" -Force | Out-Null
}

Write-Host "=== 3. Copying and Signing APK ===" -ForegroundColor Cyan
Copy-Item -Path $sourceApk -Destination $targetApk -Force
& $apkSigner sign --ks $keystorePath --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android $targetApk

Write-Host "=== 4. Checking ADB Device and Installing ===" -ForegroundColor Cyan
$devices = adb devices
Write-Host $devices

if ($devices -match "device\s*$") {
    Write-Host "Quest detected! Installing APK..." -ForegroundColor Green
    adb install -r $targetApk
    Write-Host "Successfully installed MegaManXVR.apk to Meta Quest!" -ForegroundColor Green
} else {
    Write-Host "No Quest device detected via ADB. APK is ready at: $targetApk" -ForegroundColor Yellow
}
