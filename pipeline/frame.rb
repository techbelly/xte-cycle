# frozen_string_literal: true

require "chunky_png"

# Converts between PNG images and the X3 panel frame: 792x528 pixels,
# 1 bit per pixel, MSB first, rows top to bottom, 99 bytes per row,
# 1 = white, 0 = black. Total 52,272 bytes. Matches GxEPD2's buffer layout.
module Frame
  WIDTH = 792
  HEIGHT = 528
  ROW_BYTES = WIDTH / 8
  SIZE = ROW_BYTES * HEIGHT
  THRESHOLD = 128

  module_function

  def pack(png)
    unless png.width == WIDTH && png.height == HEIGHT
      raise ArgumentError, "expected #{WIDTH}x#{HEIGHT}, got #{png.width}x#{png.height}"
    end

    bytes = Array.new(SIZE, 0)
    HEIGHT.times do |y|
      WIDTH.times do |x|
        bytes[y * ROW_BYTES + (x >> 3)] |= (0x80 >> (x & 7)) if white?(png[x, y])
      end
    end
    bytes.pack("C*")
  end

  def unpack(bin)
    raise ArgumentError, "expected #{SIZE} bytes, got #{bin.bytesize}" unless bin.bytesize == SIZE

    bytes = bin.unpack("C*")
    png = ChunkyPNG::Image.new(WIDTH, HEIGHT, ChunkyPNG::Color::BLACK)
    HEIGHT.times do |y|
      WIDTH.times do |x|
        set = bytes[y * ROW_BYTES + (x >> 3)] & (0x80 >> (x & 7))
        png[x, y] = ChunkyPNG::Color::WHITE if set != 0
      end
    end
    png
  end

  def white?(color)
    # Composite over white so transparent pixels count as white.
    c = ChunkyPNG::Color.compose(color, ChunkyPNG::Color::WHITE)
    luma = 0.299 * ChunkyPNG::Color.r(c) + 0.587 * ChunkyPNG::Color.g(c) + 0.114 * ChunkyPNG::Color.b(c)
    luma >= THRESHOLD
  end
end
