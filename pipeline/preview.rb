#!/usr/bin/env ruby
# frozen_string_literal: true

# Render a fixture instead of live data: ruby pipeline/preview.rb fixtures/rainy.json
# Writes site/data.js from the fixture, screenshots, packs. Run `rake fetch` to go back to live data.
require "json"

fixture = ARGV[0] or abort "usage: preview.rb fixtures/NAME.json"
File.write("site/data.js", "window.XTE_DATA = #{JSON.generate(JSON.parse(File.read(fixture)))};\n")
system("node screenshot.mjs", exception: true)
system("ruby pipeline/pack_frame.rb", exception: true)
