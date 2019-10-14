module Pipeline::Rpc
  class FrontEndRequest

    def self.recv(socket)
      msg = []
      socket.recv_strings(msg)
      self.new(msg, socket)
    end

    attr_reader :raw_address, :raw_msg, :parsed_msg

    def initialize(msg_strings, socket)
      @raw_address = msg_strings[0]
      @raw_msg = msg_strings[2]
      @socket = socket
    end

    def send_error(err)
      reply = [raw_address, "", err.to_json]
      @socket.send_strings(reply)
    end

    def send_result(result)
      reply = [raw_address, "", result.to_json]
      @socket.send_strings(reply)
    end

    def handle
      begin
        @parsed_msg = JSON.parse(raw_msg)
      rescue JSON::ParserError => e
        req.send_error({ status: :parse_error })
        return
      end
      action = @parsed_msg["action"]
      if action.nil?
        req.send_error({ status: :no_action })
      else
        yield(action)
      end
    end

  end
end
