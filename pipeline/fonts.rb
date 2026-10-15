#!/usr/bin/env ruby
# frozen_string_literal: true

# Copies the chosen font (config.yml `font:`) into site/fonts as body-400/700.woff2.
# Usage: ruby pipeline/fonts.rb [font-name]   e.g. inter, atkinson, overpass, hammersmith
require "fileutils"
require "yaml"

FONTS = {
  "atkinson" => ["atkinson-hyperlegible", "atkinson-hyperlegible-latin-%s-normal.woff2"],
  "inter" => ["inter", "inter-latin-%s-normal.woff2"],
  "overpass" => ["overpass", "overpass-latin-%s-normal.woff2"],
  "hammersmith" => ["hammersmith-one", "hammersmith-one-latin-400-normal.woff2"], # single weight
  "bigshoulders" => ["big-shoulders-display", "big-shoulders-display-latin-%s-normal.woff2"],
  "fraunces" => ["fraunces", "fraunces-latin-%s-normal.woff2"],
  "spacemono" => ["space-mono", "space-mono-latin-%s-normal.woff2"],
  "vt323" => ["vt323", "vt323-latin-400-normal.woff2"], # single weight
  "bungee" => ["bungee", "bungee-latin-400-normal.woff2"] # single weight
}.freeze

name = ARGV[0] || YAML.safe_load_file("config.yml").fetch("font", "inter")
pkg, pattern = FONTS.fetch(name) { abort "unknown font #{name}; one of #{FONTS.keys.join(', ')}" }
FileUtils.mkdir_p("site/fonts")
%w[400 700].each do |w|
  src = File.join("node_modules/@fontsource", pkg, "files", format(pattern, w))
  FileUtils.cp(src, "site/fonts/body-#{w}.woff2")
end
puts "Font: #{name}"
