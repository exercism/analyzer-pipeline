require 'ffi-rzmq'
require 'json'
require 'yaml'
require 'securerandom'

class PipelineClient

  attr_reader :context, :socket

  def initialize
    @context = ZMQ::Context.new(1)
    @socket = context.socket(ZMQ::REQ)
    socket.setsockopt(ZMQ::LINGER, 0)
    socket.connect("tcp://localhost:5555")
  end

  def send_msg(msg)
    socket.send_string(msg)
    response = ''
    rc = socket.recv_string(response)
    parsed = JSON.parse(response)
    parsed
  end

  def build_analyzer(track_slug)
    send_msg("build-analyzer_#{track_slug}")
  end

  def release_latest(track_slug)
    send_msg("release-analyzer_#{track_slug}")
  end

  def analyze(track_slug, exercise_slug, solution_slug, iteration_folder)
    send_msg("analyze_#{track_slug}|#{exercise_slug}|#{solution_slug}|#{iteration_folder}")
  end

end
