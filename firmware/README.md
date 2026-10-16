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

## On the device

- **Battery glyph** top-right, above the date, drawn from the BQ27220 gauge on
  every repaint. A bolt means the gauge sees charge current. At 100% on USB the
  charger has stopped, so it reads "discharging" and shows no bolt; that is normal.
- **Diagnostics screen:** hold either side button and press the power button.
  Shows build time, boot count, wake reason, battery, panel, WiFi, clock, HTTP
  result and time to next wake. The next wake repaints the dashboard.
- **Power button alone** forces a fresh download and repaint.

## Build and flash

    cd firmware/xte-cycle
    cp secrets.example.ini secrets.ini   # fill in WiFi name and password
    pio run
    esptool --chip esp32c3 --port /dev/cu.usbmodem3101 --baud 460800 write-flash \
      --flash-mode dio --flash-size 16MB --flash-freq 80m \
      0x0 .pio/build/x3/bootloader.bin 0x8000 .pio/build/x3/partitions.bin \
      0x10000 .pio/build/x3/firmware.bin
    pio device monitor

`--flash-size 16MB` is essential: without it esptool keeps the bootloader
image's default 4 MB header and the device boot-loops on "partition exceeds
flash chip size". The device only accepts a flash while awake: press the power
button and retry esptool until it connects (it is awake for ~10 s per wake).

Serial log of a good run:

    XTE boot=1 wake=cold
    XTE wifi ok 192.168.1.210 rssi=-66
    XTE time 2026-10-16 16:22:51 BST
    XTE http 200 len=52272 etag="6ad23b9f-cc30"
    XTE fetch painted
    XTE sleeping 5827s (until next wake)

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
- **GPIO13 is the battery switch**, settled by `railtest/` on battery: driving it
  LOW before sleep powers the device off (no timer wake, cold boot on the next
  button press). On USB it makes no difference. So the firmware holds it HIGH
  through sleep; the SDK profile's "SD rail" description is not the whole story.
- Sleep-current savings available: the QMI8658 tilt sensor is put to sleep every
  boot (firmware does this), and the SD card can simply be removed.
- The panel is **not** an SSD1677: xteinkos's SSD1677 driver gets "Busy Timeout".
  Use the FreeInk SDK display driver from CrossPoint, which probes UC8253 / UC8279d.
- Flashing tip: `pio run -t upload` at 921600 can drop mid-write ("chip stopped
  responding"). Flash with esptool at 460800 and always `verify-flash` after.
- The device's USB port stays enumerated but unreadable while the chip is asleep.
  Reflash during its awake window, or hold the power button to wake it first.
