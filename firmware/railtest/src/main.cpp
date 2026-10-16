// GPIO13 experiment. Wakes every 60 s and adds one black square along the top
// of the screen, then deep-sleeps with GPIO13 driven LOW and held. Run on
// battery: if squares keep appearing, GPIO13 is only the SD rail and can be
// driven low in production. If the screen freezes, it is the battery switch.
#include <Arduino.h>
#include <BoardConfig.h>
#include <FreeInkDisplay.h>
#include <SPI.h>
#include <XteinkDetect.h>
#include <driver/gpio.h>
#include <esp_sleep.h>

freeink::FreeInkDisplay display(8, 10, 21, 4, 5, 6);
RTC_DATA_ATTR int bootCount = 0;
static const gpio_num_t POWER_BTN = GPIO_NUM_3;
static const gpio_num_t GPIO13_RAIL = GPIO_NUM_13;

static void setRail(int level) {
  gpio_hold_dis(GPIO13_RAIL);
  gpio_set_direction(GPIO13_RAIL, GPIO_MODE_OUTPUT);
  gpio_set_level(GPIO13_RAIL, level);
  gpio_hold_en(GPIO13_RAIL);
}

static void fillRect(uint8_t* fb, int x0, int y0, int w, int h) {
  const int stride = display.getDisplayWidthBytes();
  for (int y = y0; y < y0 + h; y++)
    for (int x = x0; x < x0 + w; x++) fb[y * stride + (x >> 3)] &= ~(0x80 >> (x & 7));
}

void setup() {
  bootCount++;
  setRail(1);  // SD rail / whatever it is: on while awake, like stock
  Serial.begin(115200);
  delay(1500);
  Serial.printf("RAIL boot=%d wake=%d\n", bootCount, (int)esp_sleep_get_wakeup_cause());

  BoardConfig::selectDevice(BoardConfig::Board::XteinkX3);
  freeink::applyXteinkDisplayController();
  if (BoardConfig::ACTIVE.displayController == BoardConfig::DisplayController::UC8279)
    BoardConfig::selectDevice(BoardConfig::Board::XteinkX3Uc8279);
  SPI.begin(8, 7, 10, 21);
  display.setDisplayX3();
  display.begin();

  uint8_t* fb = display.getFrameBuffer();
  display.clearScreen(0xFF);
  // Row of squares: one per boot, 40 px with 10 px gaps, wrapping to new rows.
  for (int i = 0; i < bootCount && i < 150; i++) {
    fillRect(fb, 20 + (i % 15) * 50, 20 + (i / 15) * 50, 40, 40);
  }
  fillRect(fb, 0, 520, 792, 8);  // baseline so a blank boot is distinguishable from "off"
  display.displayBuffer(freeink::FreeInkDisplay::FULL_REFRESH, true);
  display.deepSleep();
  Serial.println("RAIL painted; sleeping 60s with GPIO13 LOW");
  Serial.flush();

  setRail(0);  // the experiment
  gpio_pullup_en(POWER_BTN);
  gpio_pulldown_dis(POWER_BTN);
  esp_deep_sleep_enable_gpio_wakeup(1ULL << POWER_BTN, ESP_GPIO_WAKEUP_GPIO_LOW);
  esp_sleep_enable_timer_wakeup(60ULL * 1000000ULL);
  esp_deep_sleep_start();
}

void loop() {}
