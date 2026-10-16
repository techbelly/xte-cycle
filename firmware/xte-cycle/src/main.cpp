// xte-cycle firmware for the Xteink X3.
//
// Wakes at WAKE_HOURS (local time), joins WiFi, syncs the clock over NTP,
// fetches FRAME_URL (792x528, 1 bpp, 52,272 bytes) with If-None-Match, paints
// it, and deep-sleeps until the next wake. The power button forces a refresh.
// On any failure it leaves the old picture up and retries in RETRY_MINUTES.
#include <Arduino.h>
#include <BoardConfig.h>
#include <FreeInkDisplay.h>
#include <Imu.h>
#include <SPI.h>
#include <WiFi.h>
#include <XteinkDetect.h>
#include <driver/gpio.h>
#include <esp_crt_bundle.h>
#include <esp_http_client.h>
#include <esp_sleep.h>
#include <esp_sntp.h>
#include <time.h>

static const int WAKE_HOURS[] = {4, 18};
static const int RETRY_MINUTES = 30;
static const char* TZ_LONDON = "GMT0BST,M3.5.0/1,M10.5.0";
static const uint32_t WIFI_TIMEOUT_MS = 30000;
static const uint32_t NTP_TIMEOUT_MS = 10000;

freeink::FreeInkDisplay display(8, 10, 21, 4, 5, 6);

RTC_DATA_ATTR int bootCount = 0;
RTC_DATA_ATTR char lastEtag[96] = {0};

static const gpio_num_t POWER_BTN = GPIO_NUM_3;
static const gpio_num_t GPIO13_RAIL = GPIO_NUM_13;

static void holdRail() {
  gpio_hold_dis(GPIO13_RAIL);
  gpio_set_direction(GPIO13_RAIL, GPIO_MODE_OUTPUT);
  gpio_set_level(GPIO13_RAIL, 1);
  gpio_hold_en(GPIO13_RAIL);
}

static void sleepFor(uint64_t seconds, const char* why) {
  WiFi.disconnect(true);
  WiFi.mode(WIFI_OFF);
  display.deepSleep();
  gpio_pullup_en(POWER_BTN);
  gpio_pulldown_dis(POWER_BTN);
  esp_deep_sleep_enable_gpio_wakeup(1ULL << POWER_BTN, ESP_GPIO_WAKEUP_GPIO_LOW);
  esp_sleep_enable_timer_wakeup(seconds * 1000000ULL);
  Serial.printf("XTE sleeping %llus (%s)\n", seconds, why);
  Serial.flush();
  delay(50);
  esp_deep_sleep_start();
}

static bool connectWifi() {
  WiFi.onEvent(
      [](WiFiEvent_t, WiFiEventInfo_t info) {
        // 15 = 4-way handshake timeout (wrong password), 201 = no AP found, 202 = auth failed
        Serial.printf("XTE wifi disconnected reason=%d\n", (int)info.wifi_sta_disconnected.reason);
      },
      ARDUINO_EVENT_WIFI_STA_DISCONNECTED);
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASS);
  const uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < WIFI_TIMEOUT_MS) delay(100);
  if (WiFi.status() != WL_CONNECTED) {
    Serial.printf("XTE wifi failed status=%d\n", (int)WiFi.status());
    // Diagnose without printing names: is the configured network even visible?
    WiFi.disconnect();
    const int n = WiFi.scanNetworks();
    bool seen = false;
    for (int i = 0; i < n; i++) {
      if (WiFi.SSID(i) == WIFI_SSID) {
        seen = true;
        Serial.printf("XTE target network visible: ch=%d rssi=%d auth=%d\n", WiFi.channel(i), WiFi.RSSI(i),
                      (int)WiFi.encryptionType(i));
      }
    }
    if (!seen) Serial.printf("XTE target network NOT visible among %d networks on 2.4 GHz\n", n);
    return false;
  }
  Serial.printf("XTE wifi ok %s rssi=%d\n", WiFi.localIP().toString().c_str(), WiFi.RSSI());
  return true;
}

static bool haveTime() {
  time_t now = time(nullptr);
  return now > 1700000000;  // after Nov 2023, so not the 1970 default
}

// Waits for SNTP to actually complete: the RTC can hold a stale but plausible
// time across resets, so "time looks sane" is not enough to schedule a wake.
static bool syncTime() {
  configTzTime(TZ_LONDON, "pool.ntp.org", "time.cloudflare.com", "time.google.com");
  const uint32_t start = millis();
  bool synced = false;
  while (!synced && millis() - start < NTP_TIMEOUT_MS) {
    synced = esp_sntp_get_sync_status() == SNTP_SYNC_STATUS_COMPLETED;
    if (!synced) delay(100);
  }
  if (!synced) {
    Serial.printf("XTE ntp failed (clock %s)\n", haveTime() ? "plausible but unverified" : "unset");
    return false;
  }
  time_t now = time(nullptr);
  struct tm lt;
  localtime_r(&now, &lt);
  Serial.printf("XTE time %04d-%02d-%02d %02d:%02d:%02d %s\n", lt.tm_year + 1900, lt.tm_mon + 1, lt.tm_mday,
                lt.tm_hour, lt.tm_min, lt.tm_sec, lt.tm_isdst ? "BST" : "GMT");
  return true;
}

// Seconds from now until the next WAKE_HOURS boundary (local time), at least 60.
static uint64_t secondsToNextWake() {
  time_t now = time(nullptr);
  struct tm lt;
  localtime_r(&now, &lt);
  time_t best = 0;
  for (int dayOffset = 0; dayOffset <= 1 && best == 0; dayOffset++) {
    for (int h : WAKE_HOURS) {
      struct tm cand = lt;
      cand.tm_mday += dayOffset;
      cand.tm_hour = h;
      cand.tm_min = 0;
      cand.tm_sec = 0;
      cand.tm_isdst = -1;  // let mktime resolve GMT/BST for that day
      time_t t = mktime(&cand);
      if (t > now + 60 && (best == 0 || t < best)) best = t;
    }
  }
  return static_cast<uint64_t>(best - now);
}

enum class Fetch { Painted, Unchanged, Failed };

static char responseEtag[96] = {0};

// esp_http_client only exposes response headers through this event.
static esp_err_t onHttpEvent(esp_http_client_event_t* evt) {
  if (evt->event_id == HTTP_EVENT_ON_HEADER && evt->header_key && evt->header_value &&
      strcasecmp(evt->header_key, "ETag") == 0) {
    strlcpy(responseEtag, evt->header_value, sizeof(responseEtag));
  }
  return ESP_OK;
}

// Streams the frame straight into the display buffer. Paints only when the
// full expected length arrived.
static Fetch fetchAndPaint() {
  uint8_t* buf = display.getFrameBuffer();
  const size_t want = display.getBufferSize();

  esp_http_client_config_t cfg = {};
  cfg.url = FRAME_URL;
  cfg.timeout_ms = 15000;
  cfg.crt_bundle_attach = esp_crt_bundle_attach;
  cfg.buffer_size = 2048;
  cfg.event_handler = onHttpEvent;
  responseEtag[0] = 0;
  esp_http_client_handle_t client = esp_http_client_init(&cfg);
  if (!client) return Fetch::Failed;
  esp_http_client_set_header(client, "User-Agent", "xte-cycle/1.0 (ESP32-C3)");
  if (lastEtag[0]) esp_http_client_set_header(client, "If-None-Match", lastEtag);

  Fetch result = Fetch::Failed;
  if (esp_http_client_open(client, 0) == ESP_OK) {
    const int64_t contentLength = esp_http_client_fetch_headers(client);
    const int status = esp_http_client_get_status_code(client);
    const char* etag = responseEtag[0] ? responseEtag : nullptr;
    Serial.printf("XTE http %d len=%lld etag=%s\n", status, (long long)contentLength, etag ? etag : "-");

    if (status == 304) {
      result = Fetch::Unchanged;
    } else if (status == 200 && (contentLength < 0 || static_cast<size_t>(contentLength) == want)) {
      size_t got = 0;
      while (got < want) {
        const int n = esp_http_client_read(client, reinterpret_cast<char*>(buf) + got, want - got);
        if (n <= 0) break;
        got += n;
      }
      char extra[1];
      const bool overrun = esp_http_client_read(client, extra, 1) > 0;
      if (got == want && !overrun) {
        display.displayBuffer(freeink::FreeInkDisplay::FULL_REFRESH, true);
        if (etag) strlcpy(lastEtag, etag, sizeof(lastEtag));
        result = Fetch::Painted;
      } else {
        Serial.printf("XTE bad frame length got=%u want=%u overrun=%d\n", (unsigned)got, (unsigned)want, overrun);
      }
    }
  } else {
    Serial.println("XTE http open failed");
  }
  esp_http_client_close(client);
  esp_http_client_cleanup(client);
  return result;
}

void setup() {
  bootCount++;
  holdRail();
  Serial.begin(115200);
  delay(1500);
  const auto cause = esp_sleep_get_wakeup_cause();
  Serial.printf("XTE boot=%d wake=%s\n", bootCount,
                cause == ESP_SLEEP_WAKEUP_TIMER ? "timer" : cause == ESP_SLEEP_WAKEUP_GPIO ? "button" : "cold");

  BoardConfig::selectDevice(BoardConfig::Board::XteinkX3);
  freeink::applyXteinkDisplayController();
  if (BoardConfig::ACTIVE.displayController == BoardConfig::DisplayController::UC8279) {
    BoardConfig::selectDevice(BoardConfig::Board::XteinkX3Uc8279);
  }
  // The tilt sensor idles at a few hundred microamps unless told to sleep, and
  // a reset leaves it awake. We never read it, so put it to sleep every boot.
  {
    freeink::Imu imu;
    const bool slept = imu.begin() && imu.sleep();
    Serial.printf("XTE imu %s\n", slept ? "asleep" : "not found");
  }

  SPI.begin(8, 7, 10, 21);
  display.setDisplayX3();
  display.begin();

  if (!connectWifi()) sleepFor(RETRY_MINUTES * 60, "no wifi");
  const bool timeOk = syncTime();

  // A button press forces a fresh download even if the server says unchanged.
  if (cause == ESP_SLEEP_WAKEUP_GPIO) lastEtag[0] = 0;

  const Fetch f = fetchAndPaint();
  Serial.printf("XTE fetch %s\n", f == Fetch::Painted ? "painted" : f == Fetch::Unchanged ? "unchanged" : "FAILED");

  if (f == Fetch::Failed || !timeOk) sleepFor(RETRY_MINUTES * 60, "retry");
  sleepFor(secondsToNextWake(), "until next wake");
}

void loop() {}
