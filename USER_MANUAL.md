# Smart Flood Monitoring System: User Manual

Welcome to the **Smart Flood Monitoring System** user manual. This guide provides comprehensive instructions for setting up the hardware node, installing the mobile application, calibrating sensors, and operating the system.

---

## 1. System Overview
The Smart Flood Monitoring System is an IoT-based flood detection and alert solution. It uses an **ESP32 microcontroller** connected to a dual-sensor array (Ultrasonic & conductivity moisture) to measure water level changes in real time. Data is pushed instantly to **Firebase Realtime Database** and visualized on a **Flutter Mobile App** with push notification alerts.

```
+--------------+       Wi-Fi       +------------------+       Stream       +------------+
|  ESP32 Node  |  -------------->  | Firebase Cloud   |  --------------->  | Mobile App |
|  & Sensors   |   (Secure HTTPS)  | Database (RTDB)  |   (Real-time)      | (Android)  |
+--------------+                   +------------------+                    +------------+
```

---

## 2. Hardware Setup & Installation

### 2.1 Sensor Node Placement
1. **Container Dimensions**: The system is calibrated for a bucket/drain depth of **34.0 cm**.
2. **Ultrasonic Sensor (HC-SR04)**: Mount the sensor securely at the **top rim** of the bucket facing downwards towards the bottom. Ensure there are no structural obstructions in its line of sight.
3. **Conductivity Water Touch Sensor**: Place the metal contact water sensor exactly **13.5 cm from the bottom** of the bucket. This acts as the physical danger contact point.
4. **Wiring & Connections**: Verify that the sensors are wired to the correct GPIO pins on the ESP32 (Refer to the wiring diagram in the project files).

### 2.2 Powering On
* Connect the ESP32 node to a stable 5V power source using a high-quality Micro-USB cable.
* **Recommended**: Use a dedicated 5V/1A wall adapter or a fully-charged power bank. Avoid weak laptop USB ports as Wi-Fi transmissions require high current peaks.

---

## 3. Wi-Fi Configuration

The ESP32 connects to a pre-defined Wi-Fi hotspot to transmit telemetry data.

1. **Default Settings**: By default, the ESP32 firmware looks for:
   * **SSID (Wi-Fi Name)**: `"Momad Loki Wifi"` (or your custom Mobile Hotspot name)
   * **Password**: `"amiramar12"`
2. **2.4 GHz Network Requirement**: The ESP32 hardware **only supports 2.4 GHz Wi-Fi**. 
   * **If using an Android Hotspot**: Set the Hotspot Band configuration to `2.4 GHz` (not `5 GHz`).
   * **If using an iPhone Hotspot**: Go to Settings > Personal Hotspot and turn **ON** the `"Maximize Compatibility"` toggle.
3. **Connection Indicator**: 
   * When powered on, the ESP32 will search for your hotspot. Once connected, it will begin sending data to Firebase.
   * If it successfully connects, the live database telemetry will update and the app dashboard will show **Firebase Connected** (Green Check).

---

## 4. Mobile App Setup & Installation

### 4.1 Installing the App (.APK)
1. Copy the compiled [app-release.apk](file:///C:/Users/User/Desktop/FYPIOT/app-release.apk) file to your Android phone.
2. Locate the file on your device and tap it to install.
3. If prompted by Android Play Protect, allow installation from "Unknown Sources".

### 4.2 Account Registration & Log In
1. Open the app to the **Login Page**.
2. **For General Users**: Tap **Register** to create a new account using your email and password.
3. **For Admins**: Log in using the admin account details (e.g., `admin@gmail.com`). Only registered admin accounts have access to configuration and deletion controls.

---

## 5. Mobile App Features & Operation

### 5.1 Real-Time Dashboard

The main screen is the **Dashboard**, which provides a complete snapshot of the system state:

* **Flood Status Header**: Displays the current calculated threat level:
  * <span style="color:green;font-weight:bold;">SAFE (Green)</span>: Water levels are normal.
  * <span style="color:orange;font-weight:bold;">WARNING (Yellow)</span>: Water is rising and has exceeded warning thresholds.
  * <span style="color:red;font-weight:bold;">DANGEROUS (Red)</span>: Water has reached danger thresholds or touched the conductivity sensor.
* **System Information Card**:
  * **Firebase Connection Indicator**: Shows `Connected` (Green check) when the app has an active network link to the cloud database, and `Disconnected` (Red cross) if internet connection is lost.
  * **System Notifications Toggle Switch**: Tap the switch to **Enable/Disable** notifications. When toggled off, all warning and danger push alerts are muted.
  * **Last Sync**: Displays the exact timestamp of the last telemetry packet received.
* **Sensor Metrics Cards**:
  * **Distance from Water**: Displays the distance (cm) from the top ultrasonic sensor to the water surface (accurate to 1 decimal place).
  * **Water Sensor Reading**: Displays the raw analog value from the moisture touch sensor (ranges from 0 to 4095).

---

## 6. Admin Controls (Calibration & Log Management)

### 6.1 Calibration Panel (Admin Only)
Authorized admins can adjust the threshold levels remotely without modifying the code:
1. Tap the **Settings/Admin Page** on the app drawer.
2. Enter the new parameters:
   * **Bucket Depth**: Total height of the container (Default: `34.0 cm`).
   * **Warning Water Height**: Trigger level for warnings (Default: `10.0 cm`).
   * **Danger Water Height**: Trigger level for danger status (Default: `13.5 cm`).
3. Tap **Save Settings**. The database updates instantly, and the physical ESP32 node adapts to the new thresholds in real-time.

### 6.2 Managing History Logs (Admin Only)
Every flood event is stored in the database. Admins can manage the logs to maintain clutter-free history:
1. Navigate to the **Flood History** page.
2. **Selective Deletion**: Long-press any log entry to enter **Selection Mode**. Tap to select multiple entries, and tap the **Delete Icon** at the top right to remove them.
3. **Clear All**: Tap the **Trash Can Icon** to clear the entire history log.
4. **Auto-Recalculate Stats**: Deleting records automatically recalculates and resets the dashboard threat counts (`warningCount` and `dangerousCount`).

---

## 7. Troubleshooting Guide

| Issue | Possible Cause | Solution |
| :--- | :--- | :--- |
| **ESP32 is always offline** | 1. Wrong Wi-Fi credentials.<br>2. Connected to a 5 GHz hotspot.<br>3. Weak Wi-Fi signal. | 1. Double check SSID/Password in `main.cpp`.<br>2. Ensure mobile hotspot is on 2.4 GHz (or "Maximize Compatibility" is on).<br>3. Move ESP32 closer to the hotspot device. |
| **No alerts on the phone** | 1. Notifications are muted.<br>2. Background service is killed by Android power management. | 1. Ensure the **System Notifications** toggle switch on the dashboard is turned ON.<br>2. Disable Battery Optimization for the Flood App in Android Settings. |
| **Sensor showing fault badge** | Hardware pin disconnected or short-circuited. | Unplug power, inspect the wiring between the sensor and ESP32 board, and reboot. |
| **Status does not turn Yellow** | Water depth calibration is offset. | Open the Admin Calibration page and ensure the `Bucket Depth` and `Warning Water Height` match the physical container dimensions. |
