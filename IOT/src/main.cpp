#include <WiFi.h>
#include <Firebase_ESP_Client.h>

#include <time.h>

// =========================
// WIFI
// =========================

#define WIFI_SSID "Momad Loki Wifi"
#define WIFI_PASSWORD "amiramar12"

// =========================
// FIREBASE
// =========================

#define API_KEY "AIzaSyBrqHEmCI-7ArtYXfye33QyjJ6MNGTXFOY"

#define DATABASE_URL "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app"

// =========================
// SENSOR PINS
// =========================

#define TRIG_PIN 5
#define ECHO_PIN 18
#define WATER_SENSOR 34

// LED
#define RED_LED 27
#define YELLOW_LED 26
#define GREEN_LED 25

// =========================
// FIREBASE OBJECTS
// =========================

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;
FirebaseData settingsFbdo;

// =========================
// VARIABLES
// =========================

long duration;
float distance;
int waterValue;

float waterHeight = 0.0;
float bucketDepth = 34.0;
float smoothedDistance = 34.0;
float smoothingFactor = 0.70;// Water height level
float warningWaterHeight = 10.0;
float dangerWaterHeight = 13.5;// Ultrasonic distance level
float safeLevel = bucketDepth - warningWaterHeight;    // 24 cm
float dangerLevel = bucketDepth - dangerWaterHeight;   // 20.5 cm

// Adjust after checking Serial Monitor
int waterWarningValue = 1000;
int waterDangerValue = 1700;

unsigned long lastHistorySave = 0;
unsigned long historyInterval = 5000; // save every 5 seconds
unsigned long lastSettingsRead = 0;
unsigned long settingsInterval = 10000; // read admin settings every 10 seconds
unsigned long lastDeviceHealthUpload = 0;
unsigned long deviceHealthInterval = 15000; // upload health every 15 seconds

bool defaultSettingsCreated = false;

String status = "SAFE";
String ledStatus = "GREEN";
String previousStatus = "";
String previousWaterSensorHealth = "";
String waterSensorHealth = "OK";
String ultrasonicHealth = "OK";
String backupMode = "NORMAL";

// For History Tracking

String getTimeStamp()
{
  struct tm timeinfo;

  if(!getLocalTime(&timeinfo))
  {
    return "No Time";
  }

  char buffer[30];

  strftime(
    buffer,
    sizeof(buffer),
    "%Y-%m-%d %H:%M:%S",
    &timeinfo
  );

  return String(buffer);
}

float readUltrasonicDistance()
{
  const int samples = 5;
  float readings[samples];

  for (int i = 0; i < samples; i++)
  {
    digitalWrite(TRIG_PIN, LOW);
    delayMicroseconds(2);

    digitalWrite(TRIG_PIN, HIGH);
    delayMicroseconds(10);

    digitalWrite(TRIG_PIN, LOW);

    long duration = pulseIn(ECHO_PIN, HIGH, 30000);

    float tempDistance = duration * 0.034 / 2;

    if (duration == 0 || tempDistance < 2 || tempDistance > bucketDepth + 5)
    {
      tempDistance = bucketDepth;
    }

    readings[i] = tempDistance;

    delay(10);
  }

  // Sort readings
  for (int i = 0; i < samples - 1; i++)
  {
    for (int j = i + 1; j < samples; j++)
    {
      if (readings[j] < readings[i])
      {
        float temp = readings[i];
        readings[i] = readings[j];
        readings[j] = temp;
      }
    }
  }

  // Return middle value
  return readings[samples / 2];
}

int readWaterSensor()
{
  const int samples = 5;
  long total = 0;

  for (int i = 0; i < samples; i++)
  {
    total += analogRead(WATER_SENSOR);
    delay(2);
  }

  return total / samples;
}

void readThresholdSettings()
{
  if (!Firebase.ready())
  {
    return;
  }

  float newBucketDepth = bucketDepth;
  float newWarningHeight = warningWaterHeight;
  float newDangerHeight = dangerWaterHeight;

  if (Firebase.RTDB.getFloat(&settingsFbdo, "/Settings/bucketDepth"))
  {
    newBucketDepth = settingsFbdo.floatData();
  }

  if (Firebase.RTDB.getFloat(&settingsFbdo, "/Settings/warningWaterHeight"))
  {
    newWarningHeight = settingsFbdo.floatData();
  }

  if (Firebase.RTDB.getFloat(&settingsFbdo, "/Settings/dangerWaterHeight"))
  {
    newDangerHeight = settingsFbdo.floatData();
  }

  // Validate settings before applying
  if (newBucketDepth > 0 &&
      newWarningHeight > 0 &&
      newDangerHeight > newWarningHeight &&
      newDangerHeight < newBucketDepth)
  {
    bucketDepth = newBucketDepth;
    warningWaterHeight = newWarningHeight;
    dangerWaterHeight = newDangerHeight;

    safeLevel = bucketDepth - warningWaterHeight;
    dangerLevel = bucketDepth - dangerWaterHeight;

    Serial.println("Admin Threshold Settings Updated");
    Serial.print("Bucket Depth: ");
    Serial.println(bucketDepth);

    Serial.print("Warning Water Height: ");
    Serial.println(warningWaterHeight);

    Serial.print("Danger Water Height: ");
    Serial.println(dangerWaterHeight);

    Serial.print("Warning Distance: ");
    Serial.println(safeLevel);

    Serial.print("Danger Distance: ");
    Serial.println(dangerLevel);
  }
  else
  {
    Serial.println("Invalid threshold settings. Keeping old values.");
  }
}

void createDefaultSettings()
{
  if (!Firebase.ready())
  {
    return;
  }

  // Check if Settings already exists
  if (Firebase.RTDB.getFloat(&settingsFbdo, "/Settings/bucketDepth"))
  {
    Serial.println("Settings already exist. Default settings not overwritten.");
    defaultSettingsCreated = true;
    return;
  }

  // Create default Settings
  Firebase.RTDB.setFloat(
    &settingsFbdo,
    "/Settings/bucketDepth",
    34.0
  );

  Firebase.RTDB.setFloat(
    &settingsFbdo,
    "/Settings/warningWaterHeight",
    10.0
  );

  Firebase.RTDB.setFloat(
    &settingsFbdo,
    "/Settings/dangerWaterHeight",
    13.5
  );

  Firebase.RTDB.setString(
    &settingsFbdo,
    "/Settings/updatedBy",
    "ESP32 Default"
  );

  Firebase.RTDB.setString(
    &settingsFbdo,
    "/Settings/updatedAt",
    getTimeStamp()
  );

  defaultSettingsCreated = true;

  Serial.println("Default threshold settings created in Firebase.");
}

unsigned long getUnixTime()
{
  time_t now;
  time(&now);
  return (unsigned long)now;
}

String getWiFiQuality()
{
  int rssi = WiFi.RSSI();

  if (rssi >= -50)
  {
    return "Excellent";
  }
  else if (rssi >= -60)
  {
    return "Good";
  }
  else if (rssi >= -70)
  {
    return "Fair";
  }
  else
  {
    return "Weak";
  }
}

void updateSensorHealth()
{
  ultrasonicHealth = "OK";
  waterSensorHealth = "OK";
  backupMode = "NORMAL";

  // Ultrasonic check
  if (distance <= 2 || distance > bucketDepth + 5)
  {
    ultrasonicHealth = "CHECK SENSOR";
  }

  // Water sensor fault check
  // If ultrasonic says water already reached warning level,
  // but water sensor still reads very low, the water sensor may be faulty.
  if (waterHeight >= warningWaterHeight && waterValue < 200)
  {
    waterSensorHealth = "FAULT SUSPECTED";
    backupMode = "ULTRASONIC BACKUP ACTIVE";
  }
  else if (waterValue > 3800)
  {
    waterSensorHealth = "POSSIBLE SHORT / SUBMERGED";
    backupMode = "ULTRASONIC BACKUP ACTIVE";
  }
}

void writeAuditLog(String action, String details, String severity)
{
  if (!Firebase.ready())
  {
    return;
  }

  String logPath = "/AuditLogs/";
  logPath += String(getUnixTime());
  logPath += "_";
  logPath += String(millis());

  String actionPath = logPath;
  actionPath += "/action";

  String detailsPath = logPath;
  detailsPath += "/details";

  String severityPath = logPath;
  severityPath += "/severity";

  String sourcePath = logPath;
  sourcePath += "/source";

  String categoryPath = logPath;
  categoryPath += "/category";

  String timestampPath = logPath;
  timestampPath += "/timestamp";

  String epochPath = logPath;
  epochPath += "/createdAtEpoch";

  Firebase.RTDB.setString(
    &fbdo,
    actionPath.c_str(),
    action
  );

  Firebase.RTDB.setString(
    &fbdo,
    detailsPath.c_str(),
    details
  );

  Firebase.RTDB.setString(
    &fbdo,
    severityPath.c_str(),
    severity
  );

  Firebase.RTDB.setString(
    &fbdo,
    sourcePath.c_str(),
    "ESP32"
  );

  Firebase.RTDB.setString(
    &fbdo,
    categoryPath.c_str(),
    "DEVICE"
  );

  Firebase.RTDB.setString(
    &fbdo,
    timestampPath.c_str(),
    getTimeStamp()
  );

  Firebase.RTDB.setInt(
    &fbdo,
    epochPath.c_str(),
    (int)getUnixTime()
  );

  Serial.print("Audit Log Created: ");
  Serial.println(action);
}

void uploadDeviceHealth()
{
  if (!Firebase.ready())
  {
    return;
  }

  updateSensorHealth();

  FirebaseJson healthJson;
  healthJson.set("online", true);
  healthJson.set("device_name", "ESP32 Flood Unit");
  healthJson.set("last_seen", getTimeStamp());
  healthJson.set("last_seen_epoch", (int)getUnixTime());
  healthJson.set("wifi_rssi", WiFi.RSSI());
  healthJson.set("wifi_quality", getWiFiQuality());
  healthJson.set("water_sensor_status", waterSensorHealth);
  healthJson.set("ultrasonic_status", ultrasonicHealth);
  healthJson.set("backup_mode", backupMode);
  healthJson.set("current_status", status);

  Firebase.RTDB.updateNode(
    &fbdo,
    "/DeviceStatus",
    &healthJson
  );

  // Audit log when flood status changes
  if (status != previousStatus)
  {
    String details = "Flood status changed to ";
    details += status;
    details += ". Water height: ";
    details += String(waterHeight, 2);
    details += " cm.";

    String severity = "LOW";

    if (status == "WARNING")
    {
      severity = "MEDIUM";
    }
    else if (status == "DANGEROUS")
    {
      severity = "HIGH";
    }

    writeAuditLog(
      "Flood status changed",
      details,
      severity
    );

    previousStatus = status;
  }

  // Audit log when water sensor health changes
  if (waterSensorHealth != previousWaterSensorHealth)
  {
    String details = "Water sensor status: ";
    details += waterSensorHealth;
    details += ". Backup mode: ";
    details += backupMode;

    writeAuditLog(
      "Sensor health updated",
      details,
      "MEDIUM"
    );

    previousWaterSensorHealth = waterSensorHealth;
  }

  Serial.println("Device Health Uploaded");
}

// =========================
// SETUP
// =========================

void setup() {

  Serial.begin(115200);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);

  pinMode(RED_LED, OUTPUT);
  pinMode(YELLOW_LED, OUTPUT);
  pinMode(GREEN_LED, OUTPUT);

  // =========================
  // WIFI CONNECT
  // =========================

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {

    delay(500);
    Serial.print(".");
  }

  Serial.println("");
  Serial.println("WiFi Connected");
  
  configTime(
  28800,
  0,
  "pool.ntp.org",
  "time.google.com",
  "time.nist.gov"
);

  // =========================
  // FIREBASE CONFIG
  // =========================

config.api_key = API_KEY;
config.database_url = DATABASE_URL;

Firebase.reconnectWiFi(true);

if (Firebase.signUp(&config, &auth, "", ""))
{
    Serial.println("Firebase SignUp OK");
}
else
{
    Serial.print("SignUp Error: ");
    Serial.println(config.signer.signupError.message.c_str());
}

Firebase.begin(&config, &auth);

Serial.println("Firebase Initialized");
}

// =========================
// LOOP
// =========================

void loop() {

  if (Firebase.ready() && !defaultSettingsCreated)
  {
    createDefaultSettings();
  }

  if (Firebase.ready() && millis() - lastSettingsRead >= settingsInterval)
  {
    readThresholdSettings();
    lastSettingsRead = millis();
  }

  // =========================
  // ULTRASONIC SENSOR
  // =========================

  distance = readUltrasonicDistance();

  smoothedDistance =
      (smoothingFactor * distance) +
      ((1 - smoothingFactor) * smoothedDistance);

  distance = smoothedDistance;

  // Calculate water height
  waterHeight = bucketDepth - distance;

  if (waterHeight < 0) {
    waterHeight = 0;
  }

  if (waterHeight > bucketDepth) {
    waterHeight = bucketDepth;
  }
  // =========================
  // WATER SENSOR
  // =========================

  waterValue = readWaterSensor();

  // =========================
  // STATUS LOGIC
  // =========================

  if (waterHeight < warningWaterHeight && waterValue < waterWarningValue)
  {
    status = "SAFE";
    ledStatus = "GREEN";

    digitalWrite(GREEN_LED, HIGH);
    digitalWrite(YELLOW_LED, LOW);
    digitalWrite(RED_LED, LOW);
  }
  else if ((waterHeight >= warningWaterHeight && waterHeight < dangerWaterHeight) ||
          (waterValue >= waterWarningValue && waterValue < waterDangerValue))
  {
    status = "WARNING";
    ledStatus = "YELLOW";

    digitalWrite(GREEN_LED, LOW);
    digitalWrite(YELLOW_LED, HIGH);
    digitalWrite(RED_LED, LOW);
  }
  else
  {
    status = "DANGEROUS";
    ledStatus = "RED";

    digitalWrite(GREEN_LED, LOW);
    digitalWrite(YELLOW_LED, LOW);
    digitalWrite(RED_LED, HIGH);
  }
// Reset history tracking when safe again


// =========================
// SERIAL MONITOR CHECKING
// =========================

Serial.print("Distance from sensor: ");
Serial.print(distance);
Serial.println(" cm");

Serial.print("Estimated water height: ");
Serial.print(waterHeight);
Serial.println(" cm");

Serial.print("Water sensor value: ");
Serial.println(waterValue);

Serial.print("Status: ");
Serial.println(status);

// =========================
// SEND TO FIREBASE
// =========================

  if (Firebase.ready())
  {
    bool success = true;

    // =========================
    // UPLOAD LIVE FLOOD DATA FIRST
    // =========================

    FirebaseJson telemetryJson;
    telemetryJson.set("distance_cm", distance);
    telemetryJson.set("water_height_cm", waterHeight);
    telemetryJson.set("water_level", waterValue);
    telemetryJson.set("flood_status", status);
    telemetryJson.set("led_indicator_status", ledStatus);

    success &= Firebase.RTDB.updateNode(
      &fbdo,
      "/FloodMonitoring",
      &telemetryJson
    );

    // =========================
    // UPLOAD DEVICE HEALTH AFTER LIVE DATA
    // =========================

    if (millis() - lastDeviceHealthUpload >= deviceHealthInterval)
    {
      uploadDeviceHealth();
      lastDeviceHealthUpload = millis();
    }

    Serial.print("Current Status: ");
    Serial.println(status);

    Serial.println("Checking History...");

  // Save History continuously every 5 seconds
  if ((status == "WARNING" || status == "DANGEROUS") &&
    millis() - lastHistorySave >= historyInterval)
  {
    String historyPath = "/History/";
    historyPath += String(millis());

    FirebaseJson historyJson;
    historyJson.set("distance_cm", distance);
    historyJson.set("water_height_cm", waterHeight);
    historyJson.set("water_level", waterValue);
    historyJson.set("flood_status", status);
    historyJson.set("led_indicator_status", ledStatus);
    historyJson.set("timestamp", getTimeStamp());

    success &= Firebase.RTDB.setJSON(
      &fbdo,
      historyPath.c_str(),
      &historyJson
    );

    lastHistorySave = millis();

    Serial.print("History Saved: ");
    Serial.println(status);

    String countPath = "";

  if (status == "WARNING")
  {
    countPath = "/Statistics/warningCount";
  }
  else if (status == "DANGEROUS")
  {
    countPath = "/Statistics/dangerousCount";
  }

  if (countPath != "")
  {
    int currentCount = 0;

    if (Firebase.RTDB.getInt(&fbdo, countPath.c_str()))
    {
      currentCount = fbdo.intData();
    }

    currentCount++;

    Firebase.RTDB.setInt(
      &fbdo,
      countPath.c_str(),
      currentCount
    );

    Serial.print("Statistics Updated: ");
    Serial.println(currentCount);
  }

  }

  if (success)
  {
    Serial.println("Firebase Upload Success");
  }
  else
  {
    Serial.println("Firebase Upload Failed");
    Serial.println(fbdo.errorReason());
  }
  }
  else
  {
    Serial.println("Firebase Not Ready");
  }

delay(500);
}