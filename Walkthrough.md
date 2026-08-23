# Arion DAQ - Telemetry System Walkthrough

Welcome to the Arion DAQ system. This document outlines how to deploy the natively compiled applications for Windows and Android, and how to connect the hardware.

## 1. Deploying the Windows Desktop Application
The Windows executable has been natively compiled for maximum performance.

**Location:** 
Navigate to `build\windows\runner\Release\` within the project directory.

**Packaging for the Team:**
To run the application on another Windows machine (like a pit-wall laptop), you must copy the entire `Release` folder, not just the `.exe`. 
1. Copy the `Release` folder to your flash drive.
2. Inside that folder on the target machine, run `arion_daq.exe`.
3. The `data` folder located next to it contains all the required Flutter assets and dynamic libraries. If you separate the `.exe` from the `data` folder, the application will crash or fail to launch.

> [!NOTE]
> During development, compiling the Windows application requires **Developer Mode** to be enabled in Windows Settings to allow symlink creation for Flutter plugins.

## 2. Deploying the Android Application
The Android application allows you to read live telemetry directly from the vehicle using a mobile phone or tablet.

**Location:**
Navigate to `build\app\outputs\flutter-apk\` and locate the `app-release.apk` file.

**Sideloading onto Team Phones:**
1. Transfer `app-release.apk` to your Android device via USB or cloud storage.
2. Open your file manager on Android and tap the `.apk`.
3. If prompted, allow your file manager to "Install unknown apps".
4. Follow the prompts to install the Arion DAQ app.

## 3. Connecting the Hardware (Live Telemetry)
The system communicates at a baud rate of **115200** via a CP2102 USB-to-Serial converter parsing our custom packet format (`Time_ms,TPS_Deg,TPS_V,Brake_Bar,Brake_V,Angle`).

**On Windows:**
1. Plug the CP2102 USB converter into a free USB port.
2. Launch the application.
3. Use the top control bar dropdown to select the corresponding COM port (e.g., `COM3`).
4. Click **CONNECT**.

**On Android:**
1. You will need a USB OTG (On-The-Go) adapter (USB-C to USB-A).
2. Plug the OTG adapter into your phone, and plug the CP2102 into the adapter.
3. Launch the Arion DAQ app. 
4. The Android OS should automatically prompt you for USB permissions. Accept the prompt to allow the app to access the serial device.
5. Select the device in the dropdown and tap **CONNECT**. 

> [!IMPORTANT]
> The Android app handles device connections locally using native USB host APIs (`usb_serial`). If the serial cable disconnects due to vibrations, the app will auto-poll and attempt to reconnect every 3 seconds.

## 4. Offline Analysis
If you are disconnected from the car, you can still review past telemetry runs.
Click the **Folder Icon** in the top control bar to pick and load a `.csv` or `.txt` log file from your local filesystem. The system will automatically parse the headers, map the master time index, and allow you to precisely playback the run using the horizontal timeline slider and playback speed multipliers (up to 5x).
