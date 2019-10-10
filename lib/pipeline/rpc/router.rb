module Pipeline::Rpc
  class Router
    attr_reader :context, :front_end_socket,
                :response_socket, :poller, :workers_poller

    def initialize(context)
      @context = context

      @front_end_socket = context.socket(ZMQ::ROUTER)
      @front_end_socket.bind('tcp://*:5566')

      @in_flight = {}

      @public_hostname = "localhost"
      @response_port = 5555

      @work_channel_ports = {
        static_analyzers: 5577,
        test_runners: 5578,
        representers: 5579
      }

      @response_socket = context.socket(ZMQ::SUB)
      @response_socket.setsockopt(ZMQ::SUBSCRIBE, "")
      @response_socket.bind("tcp://*:#{@response_port}")

      @poller = ZMQ::Poller.new
      @poller.register(@front_end_socket, ZMQ::POLLIN)
      @poller.register(@response_socket, ZMQ::POLLIN)

      @backend_channels = {}
      @work_channel_ports.each do |type, port|
        bind_address = "tcp://*:#{@work_channel_ports[type]}"
        channel = context.socket(ZMQ::PUSH)
        channel.setsockopt(ZMQ::SNDHWM, 1)
        channel.bind(bind_address)

        workers_poller = ZMQ::Poller.new
        workers_poller.register(channel, ZMQ::POLLOUT)

        @backend_channels[type] = {
          socket: channel,
          poller: workers_poller
        }
      end

    end

    def run_heartbeater
      puts "STARTING heartbeat_socket"
      heartbeat_socket = context.socket(ZMQ::PUB)
      heartbeat_socket.connect("tcp://127.0.0.1:#{@response_port}")
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

    def on_frontend_request
      msg = []
      front_end_socket.recv_strings(msg)
      raw_address = msg[0]
      raw_msg = msg[2]
      begin
        parsed_msg = JSON.parse(raw_msg)
      rescue JSON::ParserError => e
        reply = [msg.first, "", { status: :parse_error }.to_json]
        front_end_socket.send_strings(reply)
        return
      end
      action = parsed_msg["action"]
      if action.nil?
        reply = [msg.first, "", { status: :no_action }.to_json]
        front_end_socket.send_strings(reply)
        return
      end
      if action == "configure_worker"
        respond_with_worker_config(raw_address, parsed_msg)
      elsif action == "analyze_iteration"
        handle_with_worker(:static_analyzers, parsed_msg, msg)
      elsif action == "test_solution"
        handle_with_worker(:test_runners, parsed_msg, msg)
      elsif action == "represent"
        handle_with_worker(:representers, parsed_msg, msg)
      else
        reply = [msg.first, "", { status: :unrecognised_action }.to_json]
        front_end_socket.send_strings(reply)
      end
    end

    def handle_with_worker(worker_class, parsed_msg, msg)
      channel = @backend_channels[worker_class]
      if channel.nil?
        reply = [msg.first, "", { status: :worker_class_unknown }.to_json]
        front_end_socket.send_strings(reply)
      elsif worker_available?(channel)
        forward_to_backend(channel, msg)
      else
        reply = [msg.first, "", { status: :worker_unavailable }.to_json]
        front_end_socket.send_strings(reply)
      end
    end

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
        emit_current_spec
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

    def emit_current_spec
      analyzer_spec = analyzer_versions
      m = {
        action: "analyzer_spec",
        spec: analyzer_spec[:analyzer_spec]
      }
      set_temp_credentials(m)
      message = ["_", "", m.to_json]
      puts "TODO"
      puts message
      # back_end_socket.send_strings(message, ZMQ::DONTWAIT)
    end

    def respond_with_worker_config(address, message)
      analyzer_spec = analyzer_versions
      set_temp_credentials(analyzer_spec)
      analyzer_spec[:channels] = {
        workqueue_address: "tcp://#{@public_hostname}:#{@work_channel_ports[:static_analyzers]}",
        response_address: "tcp://#{@public_hostname}:#{@response_port}"
      }
      reply = [address, "", analyzer_spec.to_json]
      front_end_socket.send_strings(reply)
    end

    def worker_available?(channel)
      poller = channel[:poller]
      poll_result = poller.poll(500)
      poll_result != -1 && poller.writables.size > 0
    end

    def forward_to_backend(channel, msg)
      @in_flight[msg.first] = {msg: msg, timeout: Time.now.to_i + 5}
      raw_msg = msg[2]
      m = JSON.parse(raw_msg)
      set_temp_credentials(m)
      upstream_msg = [msg.first, "", m.to_json]
      socket = channel[:socket]
      socket.send_strings(upstream_msg, ZMQ::DONTWAIT)
    end

    def set_temp_credentials(msg)
      sts =  Aws::STS::Client.new(region: "eu-west-1")
      session = sts.get_session_token(duration_seconds: 900)
      msg["credentials"] = session.to_h[:credentials]
      msg
    end
  end
end
