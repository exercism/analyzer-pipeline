module Pipeline::Rpc
  class WorkChannel

    attr_reader :queue_address, :port, :public_address

    def initialize(zmq_context, public_address)
      @public_address = public_address
      @port = URI(public_address).port
      @queue_address = "tcp://*:#{port}"

      @socket = zmq_context.socket(ZMQ::PUSH)
      @socket.setsockopt(ZMQ::SNDHWM, 1)
      @socket.bind(queue_address)

      @poller = ZMQ::Poller.new
      @poller.register(@socket, ZMQ::POLLOUT)

      @last_seen = {}
    end

    def worker_available?
      poll_result = poll_worker_status
      poll_result[:poll_success] && poll_result[:available_count] > 0
    end

    def poll_worker_status
      poll_result = @poller.poll(500)
      poll_success = poll_result != -1
      status = {
        poll_success: poll_success
      }
      writables = @poller.writables
      writables.each do |writable|
        puts writable
      end

      if poll_success
        status[:known_count] = @poller.instance_variable_get("@poll_items").size
        status[:available_count] = writables.size
      end
      puts "STATUS: #{status}"
      status
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
