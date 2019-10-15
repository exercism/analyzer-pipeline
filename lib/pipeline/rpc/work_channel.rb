module Pipeline::Rpc
  class WorkChannel

    def initialize(zmq_context, queue_address)
      @socket = zmq_context.socket(ZMQ::PUSH)
      @socket.setsockopt(ZMQ::SNDHWM, 1)
      @socket.bind(queue_address)

      @poller = ZMQ::Poller.new
      @poller.register(@socket, ZMQ::POLLOUT)
    end

    def worker_available?
      poll_result = @poller.poll(500)
      poll_result != -1 && @poller.writables.size > 0
    end

    def forward_to_backend(req, context=nil)
      m = req.parsed_msg.clone
      m[:context] = context unless context.nil?
      upstream_msg = [req.raw_address, "", m.to_json]
      @socket.send_strings(upstream_msg, ZMQ::DONTWAIT)
    end

  end
end
