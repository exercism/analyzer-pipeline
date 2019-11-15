module Pipeline::Rpc

  class Router
    attr_reader :zmq_context, :poller, :response_socket, :notification_socket, :container_versions

    def initialize(zmq_context, config)
      @public_hostname = Socket.gethostname
      @response_port = 5556
      @notification_port = 5557
      @front_end_port = 5555

      @zmq_context = zmq_context

      @front_end = FrontEndSocket.new(zmq_context, @front_end_port)
      @response_socket = ResponseSocket.new(zmq_context, @response_port)

      @poller = ChannelPoller.new
      @poller.register(@front_end)
      @poller.register(@response_socket)

      @in_flight_requests = RequestRegister.new

      @backend_channels = {}
      config["workers"].each do |worker_class, worker_config|
        worker_class = worker_class.to_sym
        backend = @backend_channels[worker_class] = {}
        worker_config.each do |k,v|
          if k == "shared_queue"
            topic = "*"
            port = v
          else
            topic = k
            port = v["queue"]
          end
          bind_address = "tcp://*:#{port}"
          work_channel = WorkChannel.new(zmq_context, bind_address)
          backend[topic] = work_channel
        end
      end

      @container_versions = {}
      config["workers"].each do |worker_class, worker_config|
        worker_class = worker_class.to_sym
        cv = @container_versions[worker_class] = {}
        worker_config.each do |k,v|
          if k != "shared_queue"
            lang_spec = v
            cv[k] = lang_spec["worker_versions"]
          end
        end
      end

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

    def force_worker_restart!
      @force_restart_at = Time.now
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
        elsif action == "restart_workers"
          force_worker_restart!
          req.send_result({ message: "Request accepted" })
        elsif action == "restart_router"
          force_worker_restart!
          req.send_result({ message: "Request accepted" })
        elsif action == "current_config"
          req.send_result({ container_versions: container_versions })
        elsif action == "list_available_containers"
          channel = req.parsed_msg["channel"]
          track_slug = req.parsed_msg["track_slug"]
          c = temp_credentials
          puts "C #{c}"
          credentials = to_aws_credentials(c)
          container_repo = Pipeline::Runtime::RuntimeEnvironment.container_repo(channel, track_slug, nil)
          images = container_repo.images_info
          req.send_result({ list_images: images })
        else
          req.send_error({ status: :unrecognised_action })
        end
      end
    end

    private

    def to_aws_credentials(raw_credentials)
      key = raw_credentials["access_key_id"]
      secret = raw_credentials["secret_access_key"]
      session = raw_credentials["session_token"]
      Aws::Credentials.new(key, secret, session)
    end

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
