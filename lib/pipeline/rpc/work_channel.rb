module Pipeline::Rpc
  class WorkChannel

    attr_reader :queue_address, :port

    def initialize(zmq_context, queue_address)
      @queue_address = queue_address
      @port = URI(queue_address).port

      @socket = zmq_context.socket(ZMQ::PUSH)
      @socket.setsockopt(ZMQ::SNDHWM, 1)
      @socket.bind(queue_address)

      @poller = ZMQ::Poller.new
      @poller.register(@socket, ZMQ::POLLOUT)
    end

    def worker_available?
      poll_result = @poller.poll(500)
      puts "AVAILABILITY #{@poller.writables}"
      poll_result != -1 && @poller.writables.size > 0
    end

    def forward_to_backend(req, context=nil)
      m = req.parsed_msg.clone
      m[:context] = context unless context.nil?
      upstream_msg = [req.raw_address, "", m.to_json]
      @socket.send_strings(upstream_msg, ZMQ::DONTWAIT)
    end

    def inspect
      "WorkChannel<#{queue_address}>"
    end

  end
end
