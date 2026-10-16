# xte-cycle

A wall-mounted Xteink X3 e-reader that shows, every morning, the weather and
whether to cycle or take the train to work. Nothing runs live: a GitHub Action
builds one static image a day and the device fetches it from GitHub Pages.

    GitHub Actions, 03:15 and 17:15 local
      ruby pipeline/fetch_weather.rb   Open-Meteo -> site/data.js (facts only)
      elm make                          decision + layout -> site/elm.js
      node screenshot.mjs               792x528 PNG via headless Chromium
      ruby pipeline/pack_frame.rb       PNG -> site/frame.bin (1 bit/pixel)
      deploy site/ to GitHub Pages

    Xteink X3 (firmware/)
      wake 04:00 and 18:00 -> WiFi -> NTP -> GET frame.bin -> paint -> sleep

## Layout

- `config.yml` location for the forecast (one rounded mid-route point)
- `pipeline/` Ruby: fetch, pack, preview
- `src/` Elm: `Data` (decoder), `Rules` (the decision), `Delight` (one line a day), `Icons`, `View`
- `tests/` elm-test for the rules, `test/` minitest for the frame packer
- `site/` static shell; build outputs land here and are gitignored
- `fixtures/` sample days for previewing without waiting for weather
- `firmware/` the device side, not started

## Local use

    bundle install && npm install && npx playwright install chromium
    rake test && npx elm-test
    rake build                           # live data -> site/frame-check.png
    ruby pipeline/preview.rb fixtures/rainy.json
    open site/index.html                 # or site/frame-check.png for the 1-bit truth

## The rules

In `src/Rules.elm`. Morning window 05:00-07:00, evening 16:00-17:00, worst hour
in each. Train if thunder, snow or freezing rain, temperature at or below 0,
gusts at or above 55 km/h, or rain at or above 60% likely or 1 mm/h. Cycle with
waterproofs from 35% or 0.2 mm/h. Otherwise cycle. Friday to Sunday show no verdict.
