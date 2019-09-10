#!/usr/bin/env ruby

require_relative "./client"

pipeline = PipelineClient.new
r = pipeline.analyze("ruby", "two-fer", "soln-42", "s3://exercism-dev/iterations/fff07700-e1c3-402d-8937-823aeefb159f")
r["logs"].each do |log_line|
  puts "+ #{log_line["cmd"]}"
  puts log_line["stdout"]
  puts log_line["stderr"]
end

puts r["result"]
