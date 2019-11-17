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
      @start = current_timestamp
    end

    def send_error(err, status_code=999)
      msg = {
        status: {
          ok: false,
          status_code: status_code
        },
        error: err,
        failed_request: parsed_msg
      }
      send_reply(msg)
    end

    def send_result(result, status_code=0)
      msg = {
        status: {
          ok: true,
          status_code: status_code
        },
        result: result,
        timing: {
          start_time: @start.to_i
        }
      }
      send_reply(msg)
    end

    def current_timestamp
      (Time.now.to_f * 1000)
    end

    def default_timeout
      return 300 if parsed_msg["action"] == "build_container"
      5
    end

    def send_reply(msg)
      @end = current_timestamp
      @duration_milliseconds = @end - @start
      msg[:timing] = {
        start_time: @start.to_i,
        end_time:  @end.to_i,
        duration_milliseconds: @duration_milliseconds.to_i
      }
      reply = [raw_address, "", msg.to_json]
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
