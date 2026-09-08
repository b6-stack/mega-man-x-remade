# Mega Man X VR - Meta Quest Standalone Build & Deploy Automation
param (
    [string]$GodotBin = "D:\ProgrammingRepo\Godot\Godot_v4.5.1-stable_win64_console.exe",
    [switch]$Launch = $true,
    [ValidateSet("godot", "gradle")]
    [string]$Mode = "godot"
)

$ErrorActionPreference = "Stop"
$baseDir = $PSScriptRoot
Set-Location $baseDir

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Mega Man X VR - Meta Quest Build & Deploy Pipeline" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Environment Configuration
Write-Host "`n[1/5] Checking Android SDK and Java Environment..." -ForegroundColor Yellow

if (-not $env:JAVA_HOME -or -not (Test-Path $env:JAVA_HOME)) {
    $possibleJavaPaths = @(
        "C:\Program Files\Android\Android Studio\jbr",
        "C:\Program Files\Java\jdk-17",
        "C:\Program Files\Eclipse Adoptium\jdk-17"
    )
    foreach ($path in $possibleJavaPaths) {
        if (Test-Path $path) {
            $env:JAVA_HOME = $path
            break
        }
    }
}
Write-Host "  JAVA_HOME: $env:JAVA_HOME"

if (-not $env:ANDROID_HOME -or -not (Test-Path $env:ANDROID_HOME)) {
    $localAndroid = "$env:LOCALAPPDATA\Android\Sdk"
    if (Test-Path $localAndroid) {
        $env:ANDROID_HOME = $localAndroid
    }
}
Write-Host "  ANDROID_HOME: $env:ANDROID_HOME"

$keystorePath = "$env:APPDATA\Godot\keystores\debug.keystore"
if (-not (Test-Path $keystorePath)) {
    Write-Warning "Debug keystore not found at $keystorePath! Generating default debug keystore..."
    $keytool = Join-Path $env:JAVA_HOME "bin\keytool.exe"
    $keystoreDir = Split-Path -Parent $keystorePath
    if (-not (Test-Path $keystoreDir)) { New-Item -ItemType Directory -Path $keystoreDir -Force | Out-Null }
    & $keytool -genkey -v -keystore $keystorePath -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
}

# Find apksigner
$buildToolsDir = Join-Path $env:ANDROID_HOME "build-tools"
$latestBuildTools = Get-ChildItem -Path $buildToolsDir -Directory | Sort-Object Name -Descending | Select-Object -First 1
$apkSigner = Join-Path $latestBuildTools.FullName "apksigner.bat"
Write-Host "  ApkSigner: $apkSigner"

# 2. Prepare Meta Quest Android Template & OpenXR Vendor dependencies
Write-Host "`n[2/5] Verifying Meta Quest Android Build Template & Manifest..." -ForegroundColor Yellow

$buildVersionFile = Join-Path $baseDir "android\.build_version"
if (-not (Test-Path $buildVersionFile)) {
    Set-Content -Path $buildVersionFile -Value "4.5.1.stable" -Encoding utf8
}

$androidLibsDebug = Join-Path $baseDir "android\build\libs\debug"
if (-not (Test-Path $androidLibsDebug)) {
    New-Item -ItemType Directory -Path $androidLibsDebug -Force | Out-Null
}

$metaAarSource = Join-Path $baseDir "addons\godotopenxrvendors\meta\godotopenxr-meta-debug.aar"
$metaAarDest = Join-Path $androidLibsDebug "godotopenxr-meta-debug.aar"
if ((Test-Path $metaAarSource) -and (-not (Test-Path $metaAarDest))) {
    Copy-Item -Path $metaAarSource -Destination $metaAarDest -Force
    Write-Host "  Copied Meta OpenXR vendor AAR to android/build/libs/debug/"
}

# Verify AndroidManifest.xml has VR and optional hand-tracking settings
$manifestFile = Join-Path $baseDir "android\build\AndroidManifest.xml"
if (Test-Path $manifestFile) {
    $manifestText = Get-Content -Path $manifestFile -Raw -Encoding utf8
    $modified = $false

    if (-not ($manifestText -match "com\.oculus\.intent\.category\.VR")) {
        $manifestText = $manifestText.Replace(
            '<category android:name="android.intent.category.LAUNCHER" />',
            '<category android:name="android.intent.category.LAUNCHER" />' + "`n" + '                <category android:name="com.oculus.intent.category.VR" />'
        )
        $modified = $true
    }

    if (-not ($manifestText -match "oculus\.software\.handtracking")) {
        $manifestText = $manifestText.Replace(
            '<uses-feature android:name="android.hardware.vr.headtracking"',
            '<uses-feature android:name="oculus.software.handtracking" android:required="false" tools:node="replace" />' + "`n" + '    <uses-feature android:name="android.hardware.vr.headtracking"'
        )
        $modified = $true
    }

    if (-not ($manifestText -match "com\.oculus\.handtracking\.version")) {
        $manifestText = $manifestText.Replace(
            '<meta-data android:name="com.oculus.vr.focusaware"',
            '<meta-data android:name="com.oculus.handtracking.version" android:value="V2.0" tools:node="replace" />' + "`n" + '        <meta-data android:name="com.oculus.vr.focusaware"'
        )
        $modified = $true
    }

    if ($modified) {
        Set-Content -Path $manifestFile -Value $manifestText -Encoding utf8
        Write-Host "  Updated android/build/AndroidManifest.xml with Quest VR flags."
    }
}

# 3. Build APK
$targetDir = Join-Path $baseDir "build"
if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir -Force | Out-Null }
$targetApk = Join-Path $targetDir "MegaManXVR.apk"

Write-Host "`n[3/5] Building Standalone APK (Mode: $Mode)..." -ForegroundColor Yellow

if ($Mode -eq "godot") {
    if (-not (Test-Path $GodotBin)) {
        throw "Godot executable not found at '$GodotBin'. Please specify -GodotBin path."
    }
    Write-Host "  Running Godot headless export..."
    & $GodotBin --headless --export-debug "Android" $targetApk
    if ($LASTEXITCODE -ne 0) {
        throw "Godot export failed with exit code $LASTEXITCODE"
    }
} else {
    Write-Host "  Running Gradle assemble..."
    Set-Location (Join-Path $baseDir "android\build")
    .\gradlew.bat assembleStandardDebug -Pexport_package_name="com.dp2kdevelopment.MMXVRT" --daemon
    if ($LASTEXITCODE -ne 0) {
        throw "Gradle build failed with exit code $LASTEXITCODE"
    }
    Set-Location $baseDir

    $sourceApk = Join-Path $baseDir "android\build\build\outputs\apk\standard\debug\android_debug.apk"
    Copy-Item -Path $sourceApk -Destination $targetApk -Force

    Write-Host "  Signing APK..."
    & $apkSigner sign --ks $keystorePath --ks-pass pass:android --ks-key-alias androiddebugkey --key-pass pass:android $targetApk
}

Write-Host "  APK successfully built at: $targetApk" -ForegroundColor Green

# 4. ADB Device Detection and Installation
Write-Host "`n[4/5] Deploying to Meta Quest via ADB..." -ForegroundColor Yellow
$adbDevices = adb devices
$deviceLines = $adbDevices -split "`r?`n" | Where-Object { $_ -match "^\s*([^\s]+)\s+device$" }

if ($deviceLines.Count -gt 0) {
    $deviceId = ($deviceLines[0] -split "\s+")[0]
    Write-Host "  Connected device detected: $deviceId" -ForegroundColor Green
    Write-Host "  Installing $targetApk..."
    adb -s $deviceId install -r $targetApk
    if ($LASTEXITCODE -ne 0) {
        throw "ADB install failed with exit code $LASTEXITCODE"
    }
    Write-Host "  Successfully installed to $deviceId!" -ForegroundColor Green

    # 5. Launch
    if ($Launch) {
        Write-Host "`n[5/5] Launching Mega Man X VR on Headset..." -ForegroundColor Yellow
        adb -s $deviceId shell am start -n com.dp2kdevelopment.MMXVRT/com.godot.game.GodotApp
        Write-Host "  Game launched! Enjoy 6DOF VR!" -ForegroundColor Green
    }
} else {
    Write-Host "  No Quest device detected via ADB." -ForegroundColor Yellow
    Write-Host "  To install manually, connect Quest via USB or Wi-Fi with Developer Mode enabled and run:"
    Write-Host "    adb install -r `"$targetApk`"" -ForegroundColor Cyan
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host "  Build & Deploy Workflow Complete!" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
