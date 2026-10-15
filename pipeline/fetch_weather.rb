#!/usr/bin/env ruby
# frozen_string_literal: true

# Fetches today's hourly forecast from Open-Meteo and writes facts only
# (no opinions) to site/data.js and site/data.json. The Elm app decides.
#
# Usage: ruby pipeline/fetch_weather.rb [config.yml] [site/]

require "json"
require "net/http"
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
today = now.strftime("%Y-%m-%d")

params = {
  latitude: loc.fetch("latitude"),
  longitude: loc.fetch("longitude"),
  hourly: %w[temperature_2m precipitation_probability precipitation
             wind_speed_10m wind_gusts_10m weather_code].join(","),
  daily: %w[sunrise sunset temperature_2m_max temperature_2m_min weather_code].join(","),
  timezone: tz,
  wind_speed_unit: "kmh",
  forecast_days: 1
}
uri = URI("https://api.open-meteo.com/v1/forecast")
uri.query = URI.encode_www_form(params)

def fetch_with_retry(uri, attempts: 5)
  attempts.times do |i|
    res = Net::HTTP.get_response(uri)
    body = JSON.parse(res.body)
    return body if res.is_a?(Net::HTTPSuccess) && body["hourly"]

    warn "Open-Meteo attempt #{i + 1}: #{res.code} #{body['reason']}"
    sleep(2**i)
  end
  abort "Open-Meteo did not answer after #{attempts} attempts"
end

raw = fetch_with_retry(uri)
h = raw.fetch("hourly")
d = raw.fetch("daily")

hours = h["time"].each_index.filter_map do |i|
  t = h["time"][i]
  next unless t.start_with?(today)

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
  date: today,
  weekday: now.strftime("%A"),
  yday: now.yday,
  generated_at: now.strftime("%H:%M"),
  location: loc.fetch("name"),
  daily: {
    sunrise: d["sunrise"][0][11, 5],
    sunset: d["sunset"][0][11, 5],
    tmax: d["temperature_2m_max"][0],
    tmin: d["temperature_2m_min"][0],
    code: d["weather_code"][0]
  },
  hours: hours
}

File.write(File.join(out_dir, "data.json"), JSON.pretty_generate(data) + "\n")
File.write(File.join(out_dir, "data.js"), "window.XTE_DATA = #{JSON.generate(data)};\n")
puts "Wrote #{hours.size} hours for #{data[:weekday]} #{today} (generated #{data[:generated_at]})"
