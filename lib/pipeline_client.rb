require 'json'

require 'ffi-rzmq'
require 'json'
require 'yaml'
require 'securerandom'

class PipelineClient

  TIMEOUT_SECS = 20
  # ADDRESS = "tcp://analysis-router.exercism.io:5555"
  ADDRESS = "tcp://localhost:5555"

  def self.run_tests(*args)
    instance = new
    instance.run_tests(*args)
  ensure
    instance.close_socket
  end

  def initialize(address: ADDRESS)
    @address = address
    @socket = open_socket
  end

  def restart_workers!
    send_recv({
      action: :restart_workers
    })
  end

  def run_tests(track_slug, exercise_slug, test_run_id, s3_uri)
    params = {
      action: :test_solution,
      id: test_run_id,
      track_slug: track_slug,
      exercise_slug: exercise_slug,
      s3_uri: s3_uri,
      container_version: "b6ea39ccb2dd04e0b047b25c691b17d6e6b44cfb",
      # container_version: "sha-122a036658c815c2024c604046692adc4c23d5c1",
    }
    send_recv(params)
  end

  private

  attr_reader :address, :socket

  def send_recv(payload)
    # Get a response. Raises if fails
    resp = send_msg(payload.to_json, TIMEOUT_SECS)
    # Parse the response and return the results hash
    parsed = JSON.parse(resp)
    puts parsed
    raise "failed request" unless parsed["status"]["ok"]
    parsed
  end

  def open_socket
    ZMQ::Context.new(1).socket(ZMQ::REQ).tap do |socket|
      socket.setsockopt(ZMQ::LINGER, 0)
      socket.connect(address)
    end
  end

  def close_socket
    socket.close
  end

  def send_msg(msg, timeout)
    timeout_ms = timeout * 1000
    socket.setsockopt(ZMQ::RCVTIMEO, timeout_ms)
    socket.send_string(msg)

    # Get the response back from the runner
    recv_result = socket.recv_string(response = "")

    # Guard against errors
    raise TestRunnerTimeoutError if recv_result < 0
    case recv_result
    when 20
      raise TestRunnerTimeoutError
    when 31
      raise TestRunnerWorkerUnavailableError
    end

    # Return the response
    response
  end
end
