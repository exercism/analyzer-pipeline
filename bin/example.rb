#!/usr/bin/env ruby

require_relative "./client"

pipeline = PipelineClient.new

puts "Sample for ruby:two-fer"

action = ARGV[0]
lang = "ruby"
exercise_slug = "two-fer"
solution_slug = "soln-demo"

source = ARGV[1] || "s3://exercism-iterations/production/iterations/1182520"

r = case action
when "test"
  pipeline.test_run(lang, exercise_slug, solution_slug, source)
when "analyze"
  pipeline.analyze(lang, exercise_slug, solution_slug, source)
when "represent"
  pipeline.represent(lang, exercise_slug, solution_slug, source)
else
  raise "Command #{action} unknown.\n Usage: ./example.rb test|analyze|represent [s3_url]"
end

pipeline.close_socket

puts " === Complete ==="


if r["logs"]
  r["logs"].each do |log_line|
    puts "+ #{log_line["cmd"]}"
    puts log_line["stdout"]
    puts log_line["stderr"]
  end
end

puts r["result"]
