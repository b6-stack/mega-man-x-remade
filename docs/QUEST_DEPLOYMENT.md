# Meta Quest Standalone VR Deployment Workflow

This document details the complete build, export, and deployment pipeline for running **Mega Man X VR** natively on Meta Quest devices (Quest 2, Quest Pro, Quest 3, Quest 3S) without requiring PC VR Link/AirLink.

---

## 1. Architecture & Prerequisites

### Tools Required
- **Godot Engine**: `4.5.1-stable` (Win64)
- **Android SDK**: Build-Tools `34.0.0` or higher, Platform SDK `android-34` / `android-35`
- **Java SDK**: JDK 17 (e.g. bundled in Android Studio JBR at `C:\Program Files\Android\Android Studio\jbr`)
- **Meta Quest Device**: In **Developer Mode**, connected via USB or ADB over Wi-Fi.

### OpenXR Vendors GDExtension Plugin
Meta Quest requires the official Godot OpenXR Vendors plugin to interface with the device's native OpenXR loader (`libopenxr_loader.so`) and compositor.
- Located in: `addons/godotopenxrvendors/`
- Vendor AAR for Meta runtime: `addons/godotopenxrvendors/meta/godotopenxr-meta-debug.aar` (automatically linked into `android/build/libs/debug/`).

---

## 2. Key Settings & Configuration

### A. Engine Project Settings (`project.godot`)
- **VRAM Compression**: `textures/vram_compression/import_etc2_astc=true` (Required by Android/Godot 4.5 for ASTC texture compression).
- **Renderer**: `rendering/renderer/rendering_method="forward_plus"`, `rendering_method.mobile="mobile"`.
- **XR OpenXR Enabled**: `xr/openxr/enabled=true`.
- **Form Factor**: `xr/openxr/form_factor=0` (0 = Head-Mounted Display / HMD; 1 = Handheld).
- **Reference Space**: `xr/openxr/reference_space=1` (Stage space for roomscale 6DOF).
- **Display Window**: `display/window/size/resizable=false`.

### B. Export Preset (`export_presets.cfg`)
- **Preset**: `Android`
- **Package Name**: `com.dp2kdevelopment.MMXVRT`
- **Gradle Build**: `gradle_build/use_gradle_build=true`
- **Min SDK**: `29`
- **Target SDK**: `34`
- **Architecture**: `arm64-v8a` enabled (`armeabi-v7a` disabled).
- **XR Mode**: `xr_features/xr_mode=1` (1 = OpenXR; value 2 disables XR).
- **Immersive Mode**: `screen/immersive_mode=true`.

### C. Android Manifest Requirements (`android/build/AndroidManifest.xml`)
To prevent Meta Horizon OS from launching the game in a 2D window or blocking launch with "Controllers Required":
1. **VR Intent Category** in `<activity>`:
   ```xml
   <category android:name="com.oculus.intent.category.VR" />
   ```
2. **Fixed Immersion**:
   ```xml
   android:resizeableActivity="false"
   ```
3. **Head Tracking & Optional Hand Tracking**:
   ```xml
   <uses-feature android:name="android.hardware.vr.headtracking" android:required="true" android:version="1" tools:node="replace" />
   <uses-feature android:name="oculus.software.handtracking" android:required="false" tools:node="replace" />
   <meta-data android:name="com.oculus.handtracking.version" android:value="V2.0" tools:node="replace" />
   <meta-data android:name="com.oculus.vr.focusaware" android:value="true" tools:node="replace" />
   <meta-data android:name="com.oculus.supportedDevices" android:value="quest|quest2|questpro|quest3|quest3s" tools:node="replace" />
   ```

---

## 3. Automated One-Click Build & Deploy Script

Run the automated PowerShell script from the repository root:

```powershell
.\build_and_deploy_quest.ps1
```

### What the Script Does:
1. **Auto-Detects Paths**: Discovers `JAVA_HOME`, `ANDROID_HOME`, `apksigner`, and debug keystore.
2. **Prepares Template**: Validates `android/.build_version`, copies the Meta OpenXR vendor AAR, and ensures manifest tags are up to date.
3. **Exports Project**: Invokes Godot in headless mode to package scenes, assets, and shaders into `build/MegaManXVR.apk`.
4. **Installs via ADB**: Detects connected Quest headset and installs the signed APK.
5. **Launches App**: Sends the intent `com.dp2kdevelopment.MMXVRT/com.godot.game.GodotApp` directly into the headset.

### Fast Iteration Mode (Gradle-only)
If you only need to recompile Java/Gradle components without re-exporting Godot PCK assets:
```powershell
.\build_and_deploy_quest.ps1 -Mode gradle
```

---

## 4. Verification & Diagnostics

To check real-time OpenXR runtime status from the headset:
```powershell
adb logcat -s godot:V OpenXR_SessionImpl:I VrRuntimeService:I
```

Expected log output indicating successful full-screen VR takeover:
```text
OpenXR: Running on OpenXR runtime: Oculus 207.221.0
Mega Man X VR: OpenXR interface initialized successfully.
Swapchain creation, id=187, idx=0, width: 1440, height: 1584, array size: 2
ClientMgr::SetPrimaryCompositorClient: com.dp2kdevelopment.MMXVRT
```
