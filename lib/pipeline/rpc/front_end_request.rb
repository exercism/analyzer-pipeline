module Pipeline::Rpc
  class FrontEndRequest

    DEFAULT_RESPONSES = {

      500 => "Internal platform Error",
      501 => "Unrecognised_action",
      502 => "Malformed request",
      503 => "No worker available",
      504 => "Request timed out while waiting for response from worker",
      505 => "Container version not yet deployed",

      510 => "Worker error",
      511 => "Container version is not available on worker",
      512 => "Failure in container setup",
      513 => "Failure in container invocation",
      514 => "Output missing or malformed",

      400 => "Bad input",
      401 => "Forced exit. Container ran too long",
      402 => "Forced exit. Container used too much IO",
      403 => "Forced exit. Container was terminated early.",

      200 => "OK"
    }

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
      @params_to_check = []
    end

    def send_error(msg, status_code, detail={})
      status_code ||= 500
      detail ||= {}
      detail[:error] = msg
      detail[:failed_request] = parsed_msg
      send_reply(status_code, detail)
    end

    def send_result(result)
      send_reply(200, result)
    end

    def current_timestamp
      (Time.now.to_f * 1000)
    end

    def default_timeout
      return 300 if parsed_msg["action"] == "build_container"
      return 2 + parsed_msg["execution_timeout"].to_i if parsed_msg["execution_timeout"]
      5
    end

    def handle
      begin
        @parsed_msg = JSON.parse(raw_msg)
      rescue JSON::ParserError => e
        puts e.message
        detail = {
          incoming: raw_msg
        }
        send_error("Could not parse message", 502, detail)
        return
      end
      action = @parsed_msg["action"]
      if action.nil?
        send_error("No action specified", 502)
      else
        begin
          yield(action)
        rescue => e
          puts e.message
          detail = {
            message: e.message,
            trace: e.backtrace
          }
          send_error("Unhandled error", 500, detail)
        end
      end
    end

    def ensure_param(param_name)
      @params_to_check << param_name
    end

    def params_missing?
      ! missing_params.empty?
    end

    def missing_params
      @missing_params ||= begin
        missing = []
        @params_to_check.each do |param|
          missing << param unless parsed_msg.include?(param)
        end
        missing
      end
    end

    def versioned?
      parsed_msg.include?("container_version")
    end

    def merge_context!(context_to_merge)
      context.merge!(context_to_merge)
    end

    private
    def send_reply(status_code, payload)
      msg = assemble_response(status_code, payload)
      puts ">>> #{msg}"
      reply = [raw_address, "", msg.to_json]
      @socket.send_strings(reply)
    end

    def assemble_response(status_code, payload)
      @end = current_timestamp
      @duration_milliseconds = @end - @start
      context[:timing] = {
        start_time: @start.to_i,
        end_time:  @end.to_i,
        duration_milliseconds: @duration_milliseconds.to_i
      }
      msg = {
        status: status_for(status_code),
        context: context
      }
      if status_code == 200
        msg[:response] = payload
      else
        msg[:context][:error_detail] = payload
        msg[:status][:error] = payload[:error] unless payload.nil?
      end
      msg
    end

    def context
      @context ||= {}
    end

    def status_for(code)
      textual_message = DEFAULT_RESPONSES[code]
      if textual_message.nil?
        group_code = (code.to_i / 100) * 100
        textual_message = DEFAULT_RESPONSES[group_code]
      end
      {
        status_code: code,
        message: textual_message
      }
    end

  end
end
