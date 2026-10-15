# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.pattern = "test/*_test.rb"
end

desc "Fetch today's forecast into site/data.js"
task(:fetch) { ruby "pipeline/fetch_weather.rb" }

desc "Compile the Elm dashboard"
task(:elm) { sh "npx elm make src/Main.elm --optimize --output=site/elm.js" }

desc "Render site/index.html to site/frame.png"
task(:screenshot) { sh "node screenshot.mjs" }

desc "Pack site/frame.png into site/frame.bin"
task(:pack) { ruby "pipeline/pack_frame.rb" }

desc "Everything: fetch, elm, screenshot, pack"
task build: %i[fetch elm screenshot pack]

task default: :test
