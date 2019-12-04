module Pipeline::Rpc
  class RequestRegister

    def initialize
      @in_flight = {}
    end

    def register(req)
      timeout_seconds = req.default_timeout
      timeout_at = Time.now.to_i + timeout_seconds
      @in_flight[req.raw_address] = {timeout: timeout_at, req: req}
    end

    def forward_as_error(msg)
      addr = msg.binary_return_address
      entry = @in_flight[addr]
      if entry.nil?
        puts "dropping response"
      else
        req = entry[:req]
        resp = msg.parsed_msg
        resp.delete("msg_type")
        resp.delete("return_address")
        worker_error_code = resp.delete("worker_error_code") || 510
        req.send_error("Error from worker", worker_error_code, resp)
        unregister(addr)
      end
    end

    def forward_as_response(msg)
      addr = msg.binary_return_address
      entry = @in_flight[addr]
      if entry.nil?
        puts "dropping response"
      else
        req = entry[:req]
        resp = msg.parsed_msg
        resp.delete("msg_type")
        resp.delete("return_address")
        container_response = resp.delete("result")
        puts "keys: #{resp.keys}"
        puts "Here: #{resp}"
        req.merge_context!(resp)
        req.send_result(container_response)
        unregister(addr)
      end
    end

    def flush_expired_requests
      timed_out = []
      now = Time.now.to_i
      @in_flight.each do |addr, entry|
        expiry = entry[:timeout]
        timed_out << entry[:req] if expiry < now
      end
      timed_out.each do |req|
        req.send_error("Timed out request", 504)
        puts "Timing out #{req}"
        unregister(req.raw_address)
      end
    end

    def unregister(addr)
      @in_flight.delete(addr)
    end

  end
end
