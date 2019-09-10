#!/usr/bin/env ruby

require 'ffi-rzmq'
require 'json'

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

end

pipeline = PipelineClient.new

# result = pipeline.build_analyzer("ruby")
# result["logs"].each do |log_line|
#   puts "+ #{log_line["cmd"]}"
#   puts log_line["stdout"]
#   puts log_line["stderr"]
# end

pipeline.release_latest("ruby")
