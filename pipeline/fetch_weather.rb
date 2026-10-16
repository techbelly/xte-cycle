#!/usr/bin/env ruby
# frozen_string_literal: true

# Fetches the hourly forecast from Open-Meteo and writes facts only (no
# opinions) to site/data.js and site/data.json. The Elm app decides.
#
# Which day: before noon local time the frame is for today (the 04:00 device
# wake); from noon on it is for tomorrow (the 18:00 wake shows the next day).
#
# Usage: ruby pipeline/fetch_weather.rb [config.yml] [site/]

require "json"
require "net/http"
require "openssl"
require "time"
require "uri"
require "yaml"

config_path = ARGV[0] || "config.yml"
out_dir = ARGV[1] || "site"
config = YAML.safe_load_file(config_path)
loc = config.fetch("location")
tz = config.fetch("timezone")

ENV["TZ"] = tz
now = Time.now
target = now.hour >= 12 ? now + 86_400 : now
target_date = target.strftime("%Y-%m-%d")
day_index = now.hour >= 12 ? 1 : 0

params = {
  latitude: loc.fetch("latitude"),
  longitude: loc.fetch("longitude"),
  hourly: %w[temperature_2m precipitation_probability precipitation
             wind_speed_10m wind_gusts_10m weather_code].join(","),
  daily: %w[sunrise sunset temperature_2m_max temperature_2m_min weather_code].join(","),
  timezone: tz,
  wind_speed_unit: "kmh",
  forecast_days: 2
}
uri = URI("https://api.open-meteo.com/v1/forecast")
uri.query = URI.encode_www_form(params)

# Open-Meteo's free tier returns 503 "overloaded" now and then, and GitHub's
# runners occasionally time out connecting. Back off exponentially: waits of
# 5, 10, 20, 40, 80 and 160 seconds, about five minutes in total. The cron has a
# 45-minute margin before the device wakes, and a second run follows 30 minutes
# later anyway.
def fetch_with_retry(uri, attempts: 7)
  attempts.times do |i|
    begin
      res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 20, read_timeout: 30) do |http|
        req = Net::HTTP::Get.new(uri)
        req["User-Agent"] = "xte-cycle (github.com/techbelly/xte-cycle)"
        http.request(req)
      end
      body = JSON.parse(res.body)
      return body if res.is_a?(Net::HTTPSuccess) && body["hourly"]

      warn "Open-Meteo attempt #{i + 1}: HTTP #{res.code} #{body['reason']}"
    rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNRESET, Errno::ECONNREFUSED,
           OpenSSL::SSL::SSLError, JSON::ParserError, EOFError => e
      warn "Open-Meteo attempt #{i + 1}: #{e.class}: #{e.message}"
    end
    sleep(5 * 2**i) if i < attempts - 1
  end
  abort "Open-Meteo did not answer after #{attempts} attempts"
end

raw = fetch_with_retry(uri)
h = raw.fetch("hourly")
d = raw.fetch("daily")

hours = h["time"].each_index.filter_map do |i|
  t = h["time"][i]
  next unless t.start_with?(target_date)

  {
    hour: t[11, 2].to_i,
    temp: h["temperature_2m"][i],
    rain_prob: h["precipitation_probability"][i],
    precip: h["precipitation"][i],
    wind: h["wind_speed_10m"][i],
    gust: h["wind_gusts_10m"][i],
    code: h["weather_code"][i]
  }
end

data = {
  date: target_date,
  weekday: target.strftime("%A"),
  yday: target.yday,
  generated_at: now.strftime("%a %H:%M"),
  location: loc.fetch("name"),
  daily: {
    sunrise: d["sunrise"][day_index][11, 5],
    sunset: d["sunset"][day_index][11, 5],
    tmax: d["temperature_2m_max"][day_index],
    tmin: d["temperature_2m_min"][day_index],
    code: d["weather_code"][day_index]
  },
  hours: hours
}

File.write(File.join(out_dir, "data.json"), JSON.pretty_generate(data) + "\n")
File.write(File.join(out_dir, "data.js"), "window.XTE_DATA = #{JSON.generate(data)};\n")
puts "Wrote #{hours.size} hours for #{data[:weekday]} #{target_date} (generated #{data[:generated_at]})"
