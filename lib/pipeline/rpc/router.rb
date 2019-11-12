module Pipeline::Rpc

  class Router
    attr_reader :zmq_context, :poller, :response_socket, :notification_socket

    def initialize(zmq_context)
      @zmq_context = zmq_context

      @front_end_port = 5555
      @front_end = FrontEndSocket.new(zmq_context, @front_end_port)

      @public_hostname = Socket.gethostname
      @response_port = 5556
      @response_socket = ResponseSocket.new(zmq_context, @response_port)

      @poller = ChannelPoller.new

      @poller.register(@front_end)
      @poller.register(@response_socket)

      @in_flight_requests = RequestRegister.new

      @backend_channels = {}

      @work_channel_ports = {
        static_analyzers: {
          "*" => 5560
        },
        test_runners: {
          "*" => 5561,
          "ruby" => 33001,
          "csharp" => 33002
        },
        representers: {
          "*" => 5562
        }
      }
      @work_channel_ports.each do |type, entry|
        backend = @backend_channels[type] = {}
        entry.each do |topic, port|
          bind_address = "tcp://*:#{port}"
          work_channel = WorkChannel.new(zmq_context, bind_address)
          backend[topic] = work_channel
        end
      end

      @notification_port = 5557
      @notification_socket = NotificationSocket.new(zmq_context, @notification_port)
    end

    def force_worker_restart!
      @force_restart_at = Time.now
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
      elsif msg.type == "error_response"
        @in_flight_requests.forward_response(msg)
      elsif msg.type == "heartbeat"
        @in_flight_requests.flush_expired_requests
        emit_current_spec
      else
        puts "Unrecognised message: #{msg.type} #{msg.parsed_msg}"
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
      else
        select_backend_and_forward(req, channel)
      end
    end

    def select_backend_and_forward(req, channel)
      track_slug = req.parsed_msg["track_slug"]
      backend = channel[track_slug]
      if backend.worker_available?
        forward(backend, req)
        return
      end
      backend = channel["*"]
      if backend.worker_available?
        forward(backend, req)
      else
        req.send_error({ status: :worker_unavailable })
      end
    end

    def forward(backend, req)
      context = { credentials: temp_credentials }
      @in_flight_requests.register(req)
      backend.forward_to_backend(req, context)
    end

    def container_versions
      {
        static_analyzers: {
          "ruby" => [
            "a1f5549b6391443f7a05a038fed8dfebacd3db84",
            "398007701db580a09f198e806e680f4cdb04b3b4",
            "dc1c6c4897e63ebeb60ed53ec7423a3f6c33449d"
          ]
        },
        representers: {
          "ruby" => [
            "7dad3dd8b43c89d0ac03b5f67700c6aad52d8cf9"
          ]
        },
        test_runners: {
          "ruby" => [
            "b6ea39ccb2dd04e0b047b25c691b17d6e6b44cfb"
          ],
          "csharp" => [
            "sha-122a036658c815c2024c604046692adc4c23d5c1"
          ]
        }
      }
    end

    def emit_current_spec
      m = {
        action: "configure",
        specs: container_versions
      }
      m[:force_restart_at] = @force_restart_at.to_i if @force_restart_at
      set_temp_credentials(m)
      notification_socket.emit(m)
    end

    def respond_with_worker_config(req)
      channel = req.parsed_msg["channel"]
      if channel.nil?
        req.send_error({ msg: "channel unknown" })
        return
      end
      channel = channel.to_sym
      analyzer_spec = {}
      analyzer_spec["specs"] = container_versions

      topics = req.parsed_msg["topics"] || ["*"]
      workqueue_addresses = []

      puts channel
      puts @backend_channels.keys
      puts "------"
      channel_entry = @backend_channels[channel]
      puts channel_entry.keys
      topics.each do |topic|
        next unless channel_entry.has_key?(topic)
        port = channel_entry[topic].port
        workqueue_addresses << "tcp://#{@public_hostname}:#{port}"
      end

      analyzer_spec[:channel] = {
        channel: channel,
        workqueue_addresses: workqueue_addresses,
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
