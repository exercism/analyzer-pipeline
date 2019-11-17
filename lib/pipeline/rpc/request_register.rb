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

    def forward_response(msg)
      addr = msg.binary_return_address
      entry = @in_flight[addr]
      if entry.nil?
        puts "dropping response"
      else
        req = entry[:req]
        req.send_result(msg.parsed_msg)
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
        req.send_error({status: :timeout})
        puts "Timing out #{req}"
        unregister(req.raw_address)
      end
    end

    def unregister(addr)
      @in_flight.delete(addr)
    end

  end
end
