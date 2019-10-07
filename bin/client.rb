require 'ffi-rzmq'
require 'json'
require 'yaml'
require 'securerandom'

class PipelineClient

  attr_reader :context, :socket

  def initialize
    @context = ZMQ::Context.new(1)
    open_socket
    at_exit do
      close_socket
    end
  end

  def open_socket
    @socket = context.socket(ZMQ::REQ)
    @socket.setsockopt(ZMQ::LINGER, 0)
    @socket.connect("tcp://localhost:5566")
  end

  def close_socket
    @socket.close
  end

  def send_msg(msg, timeout)
    socket.setsockopt(ZMQ::RCVTIMEO, timeout*1000)
    send_result = socket.send_string(msg)
    response = ""
    recv_result = socket.recv_string(response)
    puts recv_result
    puts response
    raise("RCV timeout") if recv_result < 0
    parsed = JSON.parse(response)
    return parsed
  end

  def build_analyzer(track_slug)
    send_msg("build-analyzer_#{track_slug}", 300)
  end

  def build_test_runner(track_slug)
    send_msg("build-test-runner_#{track_slug}", 300)
  end

  def release_latest(track_slug)
    send_msg("release-analyzer_#{track_slug}", 30)
  end

  def analyze(track_slug, exercise_slug, solution_slug, iteration_folder)
    send_msg("analyze_#{track_slug}|#{exercise_slug}|#{solution_slug}|#{iteration_folder}", 10000)
  end

end
