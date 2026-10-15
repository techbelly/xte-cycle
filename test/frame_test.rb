# frozen_string_literal: true

require "minitest/autorun"
require_relative "../pipeline/frame"

class FrameTest < Minitest::Test
  def test_size_constants
    assert_equal 52_272, Frame::SIZE
    assert_equal 99, Frame::ROW_BYTES
  end

  def test_all_white_is_all_ones
    png = ChunkyPNG::Image.new(Frame::WIDTH, Frame::HEIGHT, ChunkyPNG::Color::WHITE)
    assert_equal "\xFF".b * Frame::SIZE, Frame.pack(png)
  end

  def test_pixel_addressing_is_msb_first_row_major
    png = ChunkyPNG::Image.new(Frame::WIDTH, Frame::HEIGHT, ChunkyPNG::Color::BLACK)
    png[0, 0] = ChunkyPNG::Color::WHITE      # first pixel -> bit 7 of byte 0
    png[9, 1] = ChunkyPNG::Color::WHITE      # row 1, x=9 -> byte 99+1, bit 6
    bytes = Frame.pack(png).unpack("C*")
    assert_equal 0x80, bytes[0]
    assert_equal 0x40, bytes[Frame::ROW_BYTES + 1]
    assert_equal 2, bytes.sum { |b| b.to_s(2).count("1") }
  end

  def test_round_trip
    png = ChunkyPNG::Image.new(Frame::WIDTH, Frame::HEIGHT, ChunkyPNG::Color::WHITE)
    200.times { |i| png[i * 3 % Frame::WIDTH, i * 7 % Frame::HEIGHT] = ChunkyPNG::Color::BLACK }
    again = Frame.unpack(Frame.pack(png))
    assert_equal png.pixels, again.pixels
  end

  def test_grey_thresholds_and_alpha_counts_as_white
    png = ChunkyPNG::Image.new(8, 1, ChunkyPNG::Color::TRANSPARENT)
    png[0, 0] = ChunkyPNG::Color.grayscale(100)
    png[1, 0] = ChunkyPNG::Color.grayscale(200)
    assert_equal false, Frame.white?(png[0, 0])
    assert_equal true, Frame.white?(png[1, 0])
    assert_equal true, Frame.white?(png[2, 0])
  end

  def test_rejects_wrong_dimensions
    assert_raises(ArgumentError) { Frame.pack(ChunkyPNG::Image.new(10, 10)) }
  end
end
