// Deep-sleep timer wake test for the Xteink X3 (ESP32-C3).
// Stays awake 8 s (long enough for esptool to grab it), then sleeps 20 s.
#include <Arduino.h>
#include <driver/gpio.h>
#include <esp_sleep.h>

RTC_DATA_ATTR int bootCount = 0;
static const gpio_num_t POWER_BTN = GPIO_NUM_3;   // active low
static const gpio_num_t BATTERY_LATCH = GPIO_NUM_13;  // CrossPoint drives this LOW to power off

static const char* causeName(esp_sleep_wakeup_cause_t c) {
  switch (c) {
    case ESP_SLEEP_WAKEUP_TIMER: return "TIMER";
    case ESP_SLEEP_WAKEUP_GPIO: return "GPIO(button)";
    case ESP_SLEEP_WAKEUP_UNDEFINED: return "cold boot / reset";
    default: return "other";
  }
}

void setup() {
  bootCount++;
  // Keep the battery rail on through sleep so this also works unplugged.
  gpio_hold_dis(BATTERY_LATCH);
  gpio_set_direction(BATTERY_LATCH, GPIO_MODE_OUTPUT);
  gpio_set_level(BATTERY_LATCH, 1);
  gpio_hold_en(BATTERY_LATCH);

  Serial.begin(115200);
  delay(2500);  // let USB CDC enumerate on the host
  for (int i = 0; i < 6; i++) {
    Serial.printf("SLEEPTEST boot=%d wake=%s awake_ms=%lu\n", bootCount,
                  causeName(esp_sleep_get_wakeup_cause()), millis());
    Serial.flush();
    delay(900);
  }

  gpio_pullup_en(POWER_BTN);
  gpio_pulldown_dis(POWER_BTN);
  esp_deep_sleep_enable_gpio_wakeup(1ULL << POWER_BTN, ESP_GPIO_WAKEUP_GPIO_LOW);
  esp_sleep_enable_timer_wakeup(20ULL * 1000000ULL);
  Serial.println("SLEEPTEST sleeping 20s");
  Serial.flush();
  delay(100);
  esp_deep_sleep_start();
}

void loop() {}
