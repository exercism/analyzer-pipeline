#!/usr/bin/env ruby

require_relative "./client"

pipeline = PipelineClient.new

# return
lang = ARGV[0] || "ruby"

pipeline.build_test_runner(lang)
exit
# pipeline.release_latest(lang)
# exit
r = pipeline.analyze(lang, "two-fer", "soln-42", "s3://exercism-dev/iterations/fff07700-e1c3-402d-8937-823aeefb159f")
puts r
if r["logs"]
  r["logs"].each do |log_line|
    puts "+ #{log_line["cmd"]}"
    puts log_line["stdout"]
    puts log_line["stderr"]
  end
end

puts r["result"]
