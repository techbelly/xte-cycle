# Firmware

`xte-cycle/` is a small dedicated PlatformIO firmware for the Xteink X3
(ESP32-C3), built on the FreeInk SDK (`freeink-sdk/`, a git submodule) for the
panel driver. It replaces the reader firmware. Twice a day it:

1. wakes from deep sleep on the RTC timer at 04:00 and 18:00 local
   (today's frame in the morning, tomorrow's in the evening),
2. joins WiFi with baked-in credentials and syncs the clock over NTP,
3. GETs `frame.bin` from GitHub Pages with `If-None-Match`,
4. streams the bytes straight into the panel buffer and does one full refresh,
5. sleeps until the next wake. The power button forces a refresh. Any failure
   leaves the old picture up and retries in 30 minutes.

## Build and flash

    cd firmware/xte-cycle
    cp secrets.example.ini secrets.ini   # fill in WiFi name and password
    pio run
    esptool --chip esp32c3 --port /dev/cu.usbmodem3101 --baud 460800 write-flash \
      0x0 .pio/build/x3/bootloader.bin 0x8000 .pio/build/x3/partitions.bin \
      0x10000 .pio/build/x3/firmware.bin
    pio device monitor

`sleeptest/` is the earlier feasibility test and can be ignored.

Unlike CrossPoint it must **not** drive GPIO13 low on sleep: that cuts the
battery rail and nothing is left to fire the timer. Keep the device on USB power.

## Frame contract

`site/frame.bin` is exactly 52,272 bytes: 792 x 528 pixels, 1 bit per pixel,
MSB first, rows top to bottom, 99 bytes per row, **1 = white, 0 = black**.
This is the GxEPD2 buffer layout. `pipeline/frame.rb` is the reference
implementation and `test/frame_test.rb` pins the bit order.

## Before flashing anything

Back up the stock flash (device powered on first, then cable):

    esptool.py --chip esp32c3 --baud 460800 read_flash 0 0x1000000 x3-stock-backup.bin

## Findings from the device (16 Oct 2026)

- This unit is **not** factory-locked: esptool enters download mode normally.
  Chip ESP32-C3 rev 0.4, USB-Serial/JTAG mode, MAC 7c:e8:b1:70:c2:6c.
- Stock partition table: nvs 0x9000, otadata 0xe000, app0 0x10000 (7.4 MB),
  app1 0x780000, spiffs 0xef0000, coredump 0xff0000. otadata selects app0.
- Stock backup: `backup/x3-stock-20261016.bin` (gitignored), copy in ~/Documents.
  Restore with `esptool --chip esp32c3 write-flash 0x0 backup/x3-stock-20261016.bin`.
- **Timer wake works.** `sleeptest/` deep-sleeps 20 s and wakes with
  `ESP_SLEEP_WAKEUP_TIMER`, repeatedly, on USB power. GPIO13 held HIGH during sleep.
- The panel is **not** an SSD1677: xteinkos's SSD1677 driver gets "Busy Timeout".
  Use the FreeInk SDK display driver from CrossPoint, which probes UC8253 / UC8279d.
- Flashing tip: `pio run -t upload` at 921600 can drop mid-write ("chip stopped
  responding"). Flash with esptool at 460800 and always `verify-flash` after.
- The device's USB port stays enumerated but unreadable while the chip is asleep.
  Reflash during its awake window, or hold the power button to wake it first.
