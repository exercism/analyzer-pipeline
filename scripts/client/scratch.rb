require 'ffi-rzmq'
require 'pp'
require 'json'

@context = ZMQ::Context.new(1)

@socket = @context.socket(ZMQ::REQ)
@socket.setsockopt(ZMQ::LINGER, 0)
@socket.connect("tcp://localhost:5555")

def exchange(msg)
  @socket.setsockopt(ZMQ::RCVTIMEO, 10000)
  @socket.send_string(msg)
  return_code = @socket.recv_string(response = "")

  # LOCAL error condition 1, no network exchange
  puts "network timeout" if return_code == -1

  # LOCAL error 2, malformed response
  response = JSON.parse(response)

  puts "----------------------"
  pp response["status"]
  puts "----------------------"

  puts "----------------------"
  pp response["response"]
  puts "----------------------"

  puts "----------------------"
  pp response["context"]
  puts "----------------------"

  response
end

result = exchange("foo") # - 502
raise "error" unless result["status"]["status_code"] == 502

result = exchange("{}") # - 502
raise "error" unless result["status"]["status_code"] == 502

result = exchange("{ \"action\": \"beep\"}") # - 501
raise "error" unless result["status"]["status_code"] == 501

result = exchange("{ \"action\": \"test_solution\"}") # - 502 (no track slug)
raise "error" unless result["status"]["status_code"] == 502

result = exchange("{ \"action\": \"represent\", \"track_slug\": \"parsnip\"}") # - 502 (no container_version slug)
raise "error" unless result["status"]["status_code"] == 502

result = exchange("{ \"action\": \"represent\", \"track_slug\": \"parsnip\", \"container_version\": \"1234\", \"id\": \"_myid\"}") # - 503 (no worker()
raise "error" unless result["status"]["status_code"] == 503

## 504


msg = {
  action: "test_solution",
  track_slug: "parsnip",
  container_version: "1234",
  id: "_myid",
  exercise_slug: "xx",
  s3_uri: "xx"
}

result = exchange(msg.to_json)
raise "error" unless result["status"]["status_code"] == 511


msg = {
  action: "test_solution",
  track_slug: "ruby",
  container_version: "git-b6ea39ccb2dd04e0b047b25c691b17d6e6b44cfb",
  id: "_myid",
  exercise_slug: "xx",
  s3_uri: "xx"
}

result = exchange(msg.to_json)
raise "error" unless result["status"]["status_code"] == 512
# 
# pp result
# exit 1

msg = {
  action: "test_solution",
  track_slug: "ruby",
  container_version: "git-b6ea39ccb2dd04e0b047b25c691b17d6e6b44cfb",
  id: "_myid",
  exercise_slug: "two-fer",
  s3_uri: "s3://exercism-submissions/production/submissions/96"
}

result = exchange(msg.to_json)
raise "error" unless result["status"]["status_code"] == 200

pp result

puts "done"
