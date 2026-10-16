// xte-cycle: display bring-up. Probes the panel controller, paints the
// embedded frame (site/frame.bin), then deep-sleeps. Power button wakes.
#include <Arduino.h>
#include <BoardConfig.h>
#include <FreeInkDisplay.h>
#include <SPI.h>
#include <XteinkDetect.h>
#include <driver/gpio.h>
#include <esp_sleep.h>

#include "frame_data.h"

// Pins are taken from BoardConfig::ACTIVE at begin(); these are the X3's for reference.
freeink::FreeInkDisplay display(8, 10, 21, 4, 5, 6);
RTC_DATA_ATTR int bootCount = 0;

static const gpio_num_t POWER_BTN = GPIO_NUM_3;
static const gpio_num_t GPIO13_RAIL = GPIO_NUM_13;

static void holdRail() {
  gpio_hold_dis(GPIO13_RAIL);
  gpio_set_direction(GPIO13_RAIL, GPIO_MODE_OUTPUT);
  gpio_set_level(GPIO13_RAIL, 1);
  gpio_hold_en(GPIO13_RAIL);
}

static void sleepFor(uint64_t seconds) {
  gpio_pullup_en(POWER_BTN);
  gpio_pulldown_dis(POWER_BTN);
  esp_deep_sleep_enable_gpio_wakeup(1ULL << POWER_BTN, ESP_GPIO_WAKEUP_GPIO_LOW);
  esp_sleep_enable_timer_wakeup(seconds * 1000000ULL);
  Serial.printf("XTE sleeping %llus\n", seconds);
  Serial.flush();
  delay(50);
  esp_deep_sleep_start();
}

void setup() {
  bootCount++;
  holdRail();
  Serial.begin(115200);
  delay(2000);
  Serial.printf("XTE boot=%d wake=%d\n", bootCount, (int)esp_sleep_get_wakeup_cause());

  BoardConfig::selectDevice(BoardConfig::Board::XteinkX3);
  const bool promoted = freeink::applyXteinkDisplayController();
  const auto& diag = freeink::getXteinkDisplayProbeDiag();
  Serial.printf("XTE probe ver=%02x %02x %02x verdict=%u promoted=%d busyTimeout=%d\n", diag.ver[0], diag.ver[1],
                diag.ver[2], diag.verdict, promoted, diag.busyTimedOut);
  if (BoardConfig::ACTIVE.displayController == BoardConfig::DisplayController::UC8279) {
    BoardConfig::selectDevice(BoardConfig::Board::XteinkX3Uc8279);
  }
  Serial.printf("XTE controller=%s profile=%s\n",
                BoardConfig::ACTIVE.displayController == BoardConfig::DisplayController::UC8279 ? "UC8279d" : "UC8253",
                BoardConfig::ACTIVE.name);

  SPI.begin(8, 7, 10, 21);
  display.setDisplayX3();
  display.begin();
  Serial.printf("XTE panel %ux%u buffer=%u frame=%u\n", display.getDisplayWidth(), display.getDisplayHeight(),
                display.getBufferSize(), frame_bin_len);

  if (display.getBufferSize() == frame_bin_len) {
    memcpy(display.getFrameBuffer(), frame_bin, frame_bin_len);
  } else {
    display.clearScreen(0xFF);
  }
  display.displayBuffer(freeink::FreeInkDisplay::FULL_REFRESH, true);
  Serial.println("XTE painted");
  display.deepSleep();
  sleepFor(600);
}

void loop() {}
