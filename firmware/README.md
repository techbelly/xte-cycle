# Firmware (phase 3, not started)

A small dedicated PlatformIO firmware for the Xteink X3 (ESP32-C3). It replaces
the reader firmware. Each morning it:

1. wakes from deep sleep on an RTC timer (around 06:15 local),
2. joins WiFi with baked-in credentials and syncs time over NTP,
3. GETs `frame.bin` from the GitHub Pages URL with `If-None-Match`,
4. writes the bytes straight into the panel buffer and does one full refresh,
5. sleeps until the next 06:15, with the power button as a second wake source.

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
