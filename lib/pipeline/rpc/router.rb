module Pipeline::Rpc
  class Router
    attr_reader :context, :front_end_socket, :back_end_socket,
                :response_socket, :poller, :workers_poller

    def initialize(context)
      @context = context

      @front_end_socket = context.socket(ZMQ::ROUTER)
      @front_end_socket.bind('tcp://*:5566')

      @back_end_socket = context.socket(ZMQ::PUSH)
      @back_end_socket.setsockopt(ZMQ::SNDHWM, 1)
      @back_end_socket.bind('tcp://*:5577')

      @response_socket = context.socket(ZMQ::SUB)
      @response_socket.setsockopt(ZMQ::SUBSCRIBE, "")
      @response_socket.bind('tcp://*:5555')

      @poller = ZMQ::Poller.new
      @poller.register(@front_end_socket, ZMQ::POLLIN)
      @poller.register(@response_socket, ZMQ::POLLIN)

      @workers_poller = ZMQ::Poller.new
      @workers_poller.register(@back_end_socket, ZMQ::POLLOUT)

      @in_flight = {}
    end

    def run_heartbeater
      puts "STARTING heartbeat_socket"
      heartbeat_socket = context.socket(ZMQ::PUB)
      heartbeat_socket.connect('tcp://127.0.0.1:5555')
      sleep 2
      loop do
        heartbeat_socket.send_string({ msg_type: "heartbeat" }.to_json)
        puts "ping heartbeat"
        sleep 10
      end
    end

    def run_eventloop
      loop do
        poll_result = poller.poll
        break if poll_result == -1

        readables = poller.readables
        continue if readables.empty?

        readables.each do |readable|
          case readable
          when response_socket
            on_service_response
          when front_end_socket
            on_frontend_request
          end
        end
      end
    end

    private

    def analyzer_versions
      {
        analyzer_spec: {
          "ruby" => [ "v0.0.3", "v0.0.5" ]
        }
      }
    end

    def on_service_response
      msg = ""
      response_socket.recv_string(msg)
      status_message = JSON.parse(msg)
      type = status_message["msg_type"]
      if type == "response"
        return_address = status_message["return_address"]
        reply = [return_address.pack("c*"), "", msg]
        front_end_socket.send_strings(reply, ZMQ::DONTWAIT)
      elsif type == "heartbeat"
        flush_expired_requests
      else
        puts "Unrecognised message"
      end
    end

    def flush_expired_requests
      timed_out = []
      now = Time.now.to_i
      @in_flight.each do |addr, v|
        expiry = v[:timeout]
        timed_out << addr if expiry < now
      end
      timed_out.each do |addr|
        reply = [addr, "", { status: :timeout }.to_json]
        front_end_socket.send_strings(reply)
        puts "Timing out #{@in_flight[addr]}"
        @in_flight.delete(addr)
      end
    end

    def emit_analyzer_spec(msg)
      analyzer_spec = analyzer_versions
      set_temp_credentials(analyzer_spec)
      reply = [msg.first, "", analyzer_spec.to_json]
      front_end_socket.send_strings(reply)
    end

    def worker_available?
      poll_result = workers_poller.poll(500)
      poll_result != -1 && workers_poller.writables.size > 0
    end

    def forward_to_backend(msg)
      @in_flight[msg.first] = {msg: msg, timeout: Time.now.to_i + 5}
      raw_msg = msg[2]
      m = JSON.parse(raw_msg)
      set_temp_credentials(m)
      upstream_msg = [msg.first, "", m.to_json]
      back_end_socket.send_strings(upstream_msg, ZMQ::DONTWAIT)
    end

    def on_frontend_request
      msg = []
      front_end_socket.recv_strings(msg)
      if (msg[2] == "describe_analysers")
        emit_analyzer_spec(msg)
      elsif worker_available?
        forward_to_backend(msg)
      else
        reply = [msg.first, "", { status: :worker_unavailable }.to_json]
        front_end_socket.send_strings(reply)
      end
    end

    def set_temp_credentials(msg)
      sts =  Aws::STS::Client.new(region: "eu-west-1")
      session = sts.get_session_token(duration_seconds: 900)
      msg["credentials"] = session.to_h[:credentials]
      msg
    end
  end
end
