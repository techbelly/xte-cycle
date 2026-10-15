#!/usr/bin/env ruby
# frozen_string_literal: true

# site/frame.png -> site/frame.bin, plus site/frame-check.png (a round trip
# of the packed bytes, so what you see is exactly what the panel will get).
#
# Usage: ruby pipeline/pack_frame.rb [site/frame.png] [site/frame.bin]

require_relative "frame"

src = ARGV[0] || "site/frame.png"
dst = ARGV[1] || "site/frame.bin"

png = ChunkyPNG::Image.from_file(src)
bin = Frame.pack(png)
File.binwrite(dst, bin)
Frame.unpack(bin).save(dst.sub(/\.bin\z/, "-check.png"))

black = bin.unpack("C*").sum { |b| 8 - b.to_s(2).count("1") }
puts "Wrote #{dst}: #{bin.bytesize} bytes, #{(100.0 * black / (Frame::WIDTH * Frame::HEIGHT)).round(1)}% black"
