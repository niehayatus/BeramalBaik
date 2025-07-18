#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <LiquidCrystal_I2C.h>
#include <HTTPClient.h>
#include <time.h>
#include <Adafruit_Fingerprint.h>

// === WIFI & FIREBASE ===
#define WIFI_SSID "KOPI"
#define WIFI_PASSWORD "digoreng123"
#define API_KEY "AIzaSyD3gpQON7sS6gR1CTf3S0le5WmjJN-KQ8g"
#define DATABASE_URL "https://beramalbaik-90b62-default-rtdb.firebaseio.com/"
#define LEGACY_TOKEN "Kz12MOC1xz5UVZih8BU4g3mopL2fNdh3CMyynnc3"

// === PIN SENSOR ===
#define S0 14
#define S1 27
#define S2 26
#define S3 25
#define sensorOut 33
#define IR_KOIN_1000_1 32
#define IR_KOIN_1000_2 18
#define IR_KOIN_500_1 19
#define IR_KOIN_500_2 23


#define RELAY_PIN 2

LiquidCrystal_I2C lcd(0x27, 16, 2);

FirebaseData fbdo;
FirebaseAuth auth;
FirebaseConfig config;

Adafruit_Fingerprint finger = Adafruit_Fingerprint(&Serial2);

int totalUang = 0;
bool tampilSementara = false;
unsigned long waktuTampil = 0;
unsigned long waktuRefresh = 0;
String lastLine1 = "", lastLine2 = "";
bool bukaKunci = false;

volatile bool ir1000_1_triggered = false;
volatile bool ir1000_2_triggered = false;
volatile bool ir500_1_triggered  = false;
volatile bool ir500_2_triggered  = false;
unsigned long lastKoin1000 = 0;
unsigned long lastKoin500 = 0;
unsigned long debounceDelay = 30;
bool fingerprintGagalBaru = false;


volatile unsigned long lastInterrupt1000_1 = 0;
void IRAM_ATTR handleIR1000_1() {
  unsigned long now = millis();
  if (now - lastInterrupt1000_1 > debounceDelay) {
    ir1000_1_triggered = true;
    lastInterrupt1000_1 = now;
  }
}

volatile unsigned long lastInterrupt1000_2 = 0;
void IRAM_ATTR handleIR1000_2() {
  unsigned long now = millis();
  if (now - lastInterrupt1000_2 > debounceDelay) {
    ir1000_2_triggered = true;
    lastInterrupt1000_2 = now;
  }
}

volatile unsigned long lastInterrupt500_1 = 0;
void IRAM_ATTR handleIR500_1() {
  unsigned long now = millis();
  if (now - lastInterrupt500_1 > debounceDelay) {
    ir500_1_triggered = true;
    lastInterrupt500_1 = now;
  }
}

volatile unsigned long lastInterrupt500_2 = 0;
void IRAM_ATTR handleIR500_2() {
  unsigned long now = millis();
  if (now - lastInterrupt500_2 > debounceDelay) {
    ir500_2_triggered = true;
    lastInterrupt500_2 = now;
  }
}





void connectWiFi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.print("Menghubungkan WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    Serial.print(".");
    delay(500);
  }
  Serial.println(" Terhubung!");
}

void setupFirebase() {
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  config.signer.tokens.legacy_token = LEGACY_TOKEN;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);
}

void setupTCS3200() {
  pinMode(S0, OUTPUT);
  pinMode(S1, OUTPUT);
  pinMode(S2, OUTPUT);
  pinMode(S3, OUTPUT);
  pinMode(sensorOut, INPUT);
  digitalWrite(S0, HIGH);
  digitalWrite(S1, LOW);
}

int averageColorFrequency(int s2_val, int s3_val) {
  long total = 0;
  for (int i = 0; i < 3; i++) {
    digitalWrite(S2, s2_val);
    digitalWrite(S3, s3_val);
    delayMicroseconds(300);
    total += pulseIn(sensorOut, LOW);
  }
  return total / 3;
}

void tampilkanLCD(String line1, String line2) {
  if (line1 != lastLine1 || line2 != lastLine2) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(line1);
    lcd.setCursor(0, 1);
    lcd.print(line2);
    lastLine1 = line1;
    lastLine2 = line2;
  }
}

void tampilkanTotalUang() {
  if (Firebase.RTDB.getInt(&fbdo, "/kotak_amal/total_uang")) {
    totalUang = fbdo.intData();
    tampilkanLCD("Total Uang:", "Rp " + String(totalUang));
  }
}

void simpanKeHistory(int nominal) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    http.begin("https://kotakamal-api.vercel.app/api/kirimdata");
    http.addHeader("Content-Type", "application/json");
    String payload = "{\"nominal_uang\":" + String(nominal) + "}";
    int httpResponseCode = http.POST(payload);
    if (httpResponseCode > 0) {
      Serial.println("✅ History saved: " + http.getString());
    } else {
      Serial.println("❌ Gagal kirim history: " + http.errorToString(httpResponseCode));
    }
    http.end();
  } else {
    Serial.println("❌ WiFi belum terhubung");
  }
}

String getISOTime() {
  time_t now;
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Gagal mendapatkan waktu");
    return "";
  }
  char isoTime[30];
  strftime(isoTime, sizeof(isoTime), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(isoTime);
}

void updateFirebase(int jumlah) {
  int currentTotal = 0;
  if (Firebase.RTDB.getInt(&fbdo, "/kotak_amal/total_uang")) {
    currentTotal = fbdo.intData();
  }
  int updatedTotal = currentTotal + jumlah;
  if (Firebase.RTDB.setInt(&fbdo, "/kotak_amal/total_uang", updatedTotal)) {
    Serial.println("Firebase updated: Rp " + String(updatedTotal));
  } else {
    Serial.println("Gagal update Firebase: " + fbdo.errorReason());
  }
  totalUang = updatedTotal;
  simpanKeHistory(jumlah);
}

bool cekFingerprint() {
  if (finger.getImage() != FINGERPRINT_OK) return false;
  if (finger.image2Tz() != FINGERPRINT_OK) return false;
  if (finger.fingerSearch() != FINGERPRINT_OK) return false;
  Serial.println("ID fingerprint terdeteksi: " + String(finger.fingerID));
  return true;
}

bool daftarFingerprint(int id) {
  Serial.println("Letakkan jari Anda untuk didaftarkan...");
  while (finger.getImage() != FINGERPRINT_OK);
  if (finger.image2Tz(1) != FINGERPRINT_OK) return false;

  Serial.println("Angkat jari, lalu letakkan kembali...");
  tampilkanLCD("Angkat jari", "Letakkan kembali");
  delay(2000);

  while (finger.getImage() != FINGERPRINT_OK);
  if (finger.image2Tz(2) != FINGERPRINT_OK) return false;

  if (finger.createModel() != FINGERPRINT_OK) return false;
  if (finger.storeModel(id) != FINGERPRINT_OK) return false;

  return true;
}


void tampilkanSementara(String line1, String line2, int nominal) {
  tampilkanLCD(line1, line2);
  updateFirebase(nominal);
  tampilSementara = true;
  waktuTampil = millis();
}

int stringToHashId(String input) {
  unsigned int hash = 0;
  for (int i = 0; i < input.length(); i++) {
    hash = 31 * hash + input.charAt(i);
  }
  return abs((int)(hash % 127) + 1); // pastikan dalam range 1–127
}


bool konfirmasiDeteksi(int pin1, int pin2) {
  delay(50); // debounce sensor
  return digitalRead(pin1) == LOW || digitalRead(pin2) == LOW;
}


void cekUangKertas() {
  static unsigned long lastDetectedTime = 0;
  static int lastDetectedValue = 0;
  static unsigned long lastCheck = 0;

  if (millis() - lastCheck < 200) return;
  lastCheck = millis();

  int red = averageColorFrequency(LOW, LOW);
  int green = averageColorFrequency(HIGH, HIGH);
  int blue = averageColorFrequency(LOW, HIGH);

  Serial.printf("RGB: R=%d G=%d B=%d\n", red, green, blue);

  int detectedValue = 0;

    if (red >= 28 && red <= 32 && green >= 40 && green <= 46 && blue >= 35 && blue <= 39) 
    detectedValue = 100000;
  else if (red >= 30 && red <= 33 && green >= 26 && green <= 30 && blue >= 22 && blue <= 26) 
    detectedValue = 50000;
  else if (red >= 42 && red <= 46 && green >= 42 && green <= 46 && blue >= 44 && blue <= 48) 
    detectedValue = 20000;
  else if (red >= 39 && red <= 43 && green >= 40 && green <= 44 && blue >= 33 && blue <= 37) 
    detectedValue = 10000;
  else if (red >= 22 && red <= 25 && green >= 33 && green <= 37 && blue >= 35 && blue <= 39) 
    detectedValue = 5000;
  else if (red >= 36 && red <= 40 && green >= 36 && green <= 40 && blue >= 31 && blue <= 35) 
    detectedValue = 2000;
  else if (red >= 25 && red <= 28 && green >= 28 && green <= 32 && blue >= 32 && blue <= 36) 
    detectedValue = 1000;

  if (detectedValue > 0 && (millis() - lastDetectedTime > 1500 || detectedValue != lastDetectedValue)) {
    tampilkanSementara("Uang Kertas:", "Rp " + String(detectedValue), detectedValue);
    lastDetectedTime = millis();
    lastDetectedValue = detectedValue;
  }
}

void cekKoin1000(unsigned long now) {
  if ((ir1000_1_triggered || ir1000_2_triggered) && (now - lastKoin1000 > debounceDelay)) {
    noInterrupts();
    ir1000_1_triggered = false;
    ir1000_2_triggered = false;
    interrupts();

    lastKoin1000 = now;
    tampilkanSementara("Koin Masuk:", "Rp 1000", 1000);
    Serial.println("✅ Koin Rp 1000 Terdeteksi");
  }
}

void cekKoin500(unsigned long now) {
  if ((ir500_1_triggered || ir500_2_triggered) && (now - lastKoin500 > debounceDelay)) {
    noInterrupts();
    ir500_1_triggered = false;
    ir500_2_triggered = false;
    interrupts();

    lastKoin500 = now;
    tampilkanSementara("Koin Masuk:", "Rp 500", 500);
    Serial.println("✅ Koin Rp 500 Terdeteksi");
  }
}



void setup() {
  Serial.begin(115200);
  lcd.init();
  lcd.backlight();

  setupTCS3200();
  connectWiFi();
  setupFirebase();
  configTime(7 * 3600, 0, "pool.ntp.org", "time.nist.gov");

  pinMode(IR_KOIN_1000_1, INPUT_PULLUP);
  pinMode(IR_KOIN_1000_2, INPUT_PULLUP);
  pinMode(IR_KOIN_500_1, INPUT_PULLUP);
  pinMode(IR_KOIN_500_2, INPUT_PULLUP);

  attachInterrupt(digitalPinToInterrupt(IR_KOIN_1000_1), handleIR1000_1, FALLING);
  attachInterrupt(digitalPinToInterrupt(IR_KOIN_1000_2), handleIR1000_2, FALLING);
  attachInterrupt(digitalPinToInterrupt(IR_KOIN_500_1), handleIR500_1, FALLING);
  attachInterrupt(digitalPinToInterrupt(IR_KOIN_500_2), handleIR500_2, FALLING);


  pinMode(RELAY_PIN, OUTPUT);
  digitalWrite(RELAY_PIN, HIGH);




  Serial2.begin(57600, SERIAL_8N1, 16, 17);
  finger.begin(57600);

  if (finger.verifyPassword()) {
    Serial.println("Sensor fingerprint terdeteksi.");
  } else {
    Serial.println("Sensor fingerprint TIDAK terdeteksi!");
    tampilkanLCD("Sensor Fingerprint", "TIDAK TERDETEKSI");
    delay(3000);  // tampilkan sebentar
    tampilkanTotalUang();  // kembali ke tampilan normal
  }


  tampilkanLCD("Kotak Amal", "Siap Digunakan");
  delay(2000);
  tampilkanTotalUang();
    // Reset trigger flags
  ir1000_1_triggered = false;
  ir1000_2_triggered = false;
  ir500_1_triggered = false;
  ir500_2_triggered = false;

  delay(1000); // Stabilkan sensor setelah boot
}

void loop() {
  cekUangKertas();
  unsigned long now = millis();
  cekKoin1000(now);
  cekKoin500(now);

  // === Tampilan Otomatis ===
  if (tampilSementara && millis() - waktuTampil >= 2000) {
    tampilSementara = false;
    tampilkanTotalUang();
  }

  if (!tampilSementara && millis() - waktuRefresh >= 3000) {
    tampilkanTotalUang();
    waktuRefresh = millis();
  }

  // ==== MODE DAFTAR FINGERPRINT (HANYA ID 1) ====
  if (Firebase.RTDB.getBool(&fbdo, "/status_daftar") && fbdo.boolData() == true) {
    Serial.println("🔄 Masuk Mode Daftar Fingerprint");

    finger.deleteModel(1);  // Hapus dulu ID 1
    delay(100);

    tampilkanLCD("Tempelkan jari", "untuk daftar");
    delay(1000);

    if (daftarFingerprint(1)) {
      Serial.println("✅ Berhasil daftar sidik jari di ID 1");
      tampilkanLCD("Pendaftaran", "berhasil");
    } else {
      Serial.println("❌ Gagal daftar sidik jari");
      tampilkanLCD("Pendaftaran", "gagal");
    }

    delay(2000);
    tampilkanTotalUang();

    // Reset status daftar
    Firebase.RTDB.setBool(&fbdo, "/status_daftar", false);
  }

  // ==== CEK FINGERPRINT UNTUK AKSES ====
  if (!tampilSementara) {
    if (cekFingerprint()) {
      fingerprintGagalBaru = false;
      Serial.println("Fingerprint cocok, membuka pintu...");
      tampilkanLCD("Fingerprint cocok", "Membuka kunci...");
      digitalWrite(RELAY_PIN, LOW);
      delay(3000);
      digitalWrite(RELAY_PIN, HIGH);
      tampilkanTotalUang();
    } else if (!fingerprintGagalBaru) {
      fingerprintGagalBaru = true;
      tampilkanLCD("Fingerprint", "tidak cocok!");
      delay(2000);
      tampilkanTotalUang();
    }
  }

  // ==== HAPUS SEMUA FINGERPRINT ====
  if (Firebase.RTDB.getBool(&fbdo, "/hapus_fingerprint_data") && fbdo.boolData() == true) {
    tampilkanLCD("Menghapus semua", "sidik jari...");
    Serial.println("Menghapus semua data sidik jari...");

    for (int i = 1; i < 128; i++) {
      if (finger.deleteModel(i) == FINGERPRINT_OK) {
        Serial.print("Hapus ID "); Serial.println(i);
      }
    }

    Firebase.RTDB.setBool(&fbdo, "/hapus_fingerprint_data", false);
    tampilkanLCD("Semua sidik jari", "telah dihapus");
    delay(2000);
    tampilkanTotalUang();
  }

  delay(5);
}
