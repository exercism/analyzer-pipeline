module Pipeline::Rpc

  class Router
    attr_reader :zmq_context, :poller, :response_socket, :notification_socket

    def initialize(zmq_context)
      @zmq_context = zmq_context

      @front_end_port = 5555
      @front_end = FrontEndSocket.new(zmq_context, @front_end_port)

      @public_hostname = "localhost"
      @response_port = 5556
      @response_socket = ResponseSocket.new(zmq_context, @response_port)

      @poller = ChannelPoller.new

      @poller.register(@front_end)
      @poller.register(@response_socket)

      @in_flight_requests = RequestRegister.new

      @backend_channels = {}

      @work_channel_ports = {
        static_analyzers: 5560,
        test_runners: 5561,
        representers: 5562
      }
      @work_channel_ports.each do |type, port|
        bind_address = "tcp://*:#{@work_channel_ports[type]}"
        work_channel = WorkChannel.new(zmq_context, bind_address)
        @backend_channels[type] = work_channel
      end

      @notification_port = 5556
      @notification_socket = NotificationSocket.new(zmq_context, @notification_port)

    end

    def run
      Thread.new do
        response_socket.run_heartbeater
      end

      poller.listen_for_messages do |msg|
        case msg
        when FrontEndRequest
          on_frontend_request(msg)
        when ServiceResponse
          on_service_response(msg)
        end
      end
    end

    private

    def on_service_response(msg)
      if msg.type == "response"
        @in_flight_requests.forward_response(msg)
      elsif msg.type == "heartbeat"
        @in_flight_requests.flush_expired_requests
        emit_current_spec
      else
        puts "Unrecognised message"
      end
    end


    def on_frontend_request(req)
      req.handle do |action|
        if action == "configure_worker"
          respond_with_worker_config(req)
        elsif action == "analyze_iteration"
          handle_with_worker(:static_analyzers, req)
        elsif action == "test_solution"
          handle_with_worker(:test_runners, req)
        elsif action == "represent"
          handle_with_worker(:representers, req)
        else
          req.send_error({ status: :unrecognised_action })
        end
      end
    end

    private

    def handle_with_worker(worker_class, req)
      channel = @backend_channels[worker_class]
      if channel.nil?
        req.send_error({ status: :worker_class_unknown })
      elsif channel.worker_available?
        context = { credentials: temp_credentials }
        @in_flight_requests.register(req)
        channel.forward_to_backend(req, context)
      else
        req.send_error({ status: :worker_unavailable })
      end
    end

    def analyzer_versions
      {
        analyzer_spec: {
          "ruby" => [ "v0.0.3", "v0.0.5" ]
        }
      }
    end

    def emit_current_spec
      analyzer_spec = analyzer_versions
      m = {
        action: "configure",
        specs: analyzer_spec
      }
      set_temp_credentials(m)
      # message = ["_", "", m.to_json]
      puts "TODO"
      puts m
      notification_socket.emit_configuration(m)

      # @backend_channels.each do |channel_name,v|
      #   m = {
      #     action: "configure",
      #     channel: channel_name,
      #     spec: analyzer_spec[:analyzer_spec]
      #   }
      #   puts v
      #   puts m
      # end
    end

    def respond_with_worker_config(req)
      channel = req.parsed_msg["channel"]
      if channel.nil?
        req.send_error({ msg: "channel unknown" })
        return
      end
      channel = channel.to_sym
      analyzer_spec = {}
      analyzer_spec["specs"] = analyzer_versions
      analyzer_spec[:channel] = {
        channel: channel,
        workqueue_address: "tcp://#{@public_hostname}:#{@work_channel_ports[channel]}",
        response_address: "tcp://#{@public_hostname}:#{@response_port}",
        notification_address: "tcp://#{@public_hostname}:#{@notification_port}"
      }
      analyzer_spec["credentials"] = temp_credentials
      req.send_result(analyzer_spec)
    end

    def set_temp_credentials(msg)
      msg["credentials"] = temp_credentials
      msg
    end

    def temp_credentials
      sts =  Aws::STS::Client.new(region: "eu-west-1")
      session = sts.get_session_token(duration_seconds: 900)
      session.to_h[:credentials]
    end
  end
end
