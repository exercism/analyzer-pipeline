#!/usr/bin/env ruby

require_relative "./client"

pipeline = PipelineClient.new


# return
lang = ARGV[0] || "ruby"
lang = ARGV[1] || "ruby"

r = pipeline.represent(lang, "two-fer", "soln-42",
  "s3://exercism-iterations/production/iterations/1182520")
# puts r
if r["logs"]
  r["logs"].each do |log_line|
    puts "+ #{log_line["cmd"]}"
    puts log_line["stdout"]
    puts log_line["stderr"]
  end
end

puts r["result"]

pipeline.close_socket
