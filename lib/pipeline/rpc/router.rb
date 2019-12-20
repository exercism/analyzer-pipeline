module Pipeline::Rpc

  class Router
    attr_reader :zmq_context, :poller, :response_socket, :notification_socket, :container_versions, :config

    def initialize(zmq_context, config)
      @zmq_context = zmq_context
      @config = config

      @public_hostname = Socket.gethostname
      @response_port = 5556
      @notification_port = 5557
      @front_end_port = 5555

      @front_end = FrontEndSocket.new(zmq_context, @front_end_port)
      @response_socket = ResponseSocket.new(zmq_context, @response_port)

      @poller = ChannelPoller.new
      @poller.register(@front_end)
      @poller.register(@response_socket)

      @in_flight_requests = RequestRegister.new

      @backend_channels = {}
      config.each_worker do |worker_class, worker_config|
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
          bind_address = "tcp://#{@public_hostname}:#{port}"
          work_channel = WorkChannel.new(zmq_context, bind_address)
          backend[topic] = work_channel
        end
      end

      @worker_presence = WorkerPresence.new

      load_container_versions!

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

    def load_container_versions!
      @container_versions = {}
      config.each_worker do |worker_class, worker_config|
        worker_class = worker_class.to_sym
        cv = @container_versions[worker_class] = {}
        worker_config.each do |k,v|
          if k != "shared_queue"
            lang_spec = v
            cv[k] = lang_spec["worker_versions"]
          end
        end
      end
    end

    def on_service_response(msg)
      if msg.type == "response"
        @in_flight_requests.forward_as_response(msg)
      elsif msg.type == "error_response"
        @in_flight_requests.forward_as_error(msg)
      elsif msg.type == "heartbeat"
        @in_flight_requests.flush_expired_requests
        emit_current_spec
      elsif msg.type == "worker_heartbeat"
        identity = msg.parsed_msg["identity"]
        queues = msg.parsed_msg["workqueue_addresses"]
        puts "worker heartbeat #{msg.parsed_msg}"
        @worker_presence.mark_seen!(identity, queues, msg.parsed_msg)
      else
        puts "Unrecognised message: #{msg.type} #{msg.parsed_msg}"
      end
    end

    def on_frontend_request(req)
      req.handle do |action|
        if action == "configure_worker"
          respond_with_worker_config(req)
        elsif action == "analyze_iteration"
          # TODO check mandatory args
          req.ensure_param("id")
          req.ensure_param("track_slug")
          req.ensure_param("exercise_slug")
          req.ensure_param("s3_uri")
          req.ensure_param("container_version")
          handle_with_worker(:static_analyzers, req)
        elsif action == "test_solution"
          req.ensure_param("id")
          req.ensure_param("track_slug")
          req.ensure_param("exercise_slug")
          req.ensure_param("s3_uri")
          req.ensure_param("container_version")
          handle_with_worker(:test_runners, req)
        elsif action == "represent"
          # TODO check mandatory args
          req.ensure_param("id")
          req.ensure_param("track_slug")
          req.ensure_param("container_version")
          handle_with_worker(:representers, req)
        elsif action == "build_container"
          handle_with_worker(:builders, req)
        elsif action == "restart_workers"
          force_worker_restart!
          req.send_result({ message: "Request accepted" })
        elsif action == "restart_router"
          force_worker_restart!
          req.send_result({ message: "Request accepted" })
        elsif action == "current_config"
          req.send_result({ container_versions: container_versions })
        elsif action == "update_container_versions"
          update_container_versions(req)
        elsif action == "deploy_container_version"
          update_container_versions(req)
        elsif action == "list_available_containers"
          channel = req.parsed_msg["channel"]
          track_slug = req.parsed_msg["track_slug"]
          c = temp_credentials
          puts "C #{c}"
          credentials = to_aws_credentials(c)
          container_repo = Pipeline::Runtime::RuntimeEnvironment.container_repo(channel, track_slug, nil)
          images = container_repo.images_info
          req.send_result({ list_images: images })
        elsif action == "describe_workers"
          req.send_result({ workers_info: @worker_presence.workers_info })
        elsif action == "current_worker_status"
          req.send_result({ workers_status: current_worker_status })
        elsif action == "deployment_check"
          channel = req.parsed_msg["channel"]
          language_slug = req.parsed_msg["track_slug"]
          status = { status: version_check(channel, language_slug) }
          req.send_result(status)
        else
          req.send_error("Action <#{action}> unrecognised", 501)
        end
      end
    end

    def version_check(channel, language_slug)
      puts current_worker_status.keys
      puts channel
      status = current_worker_status[channel]
      worker_count = status[:online_workers].size
      deployed_versions = status[:deployed_versions][language_slug]
      check_status = {}
      deployed_versions.map do |version, workers|
        check_status[version] = workers.count >= worker_count
      end
      check_status
    end

    def current_worker_status
      status = {}
      container_versions.each do |worker_class, target_versions|
        channel = select_channel(worker_class)
        addresses = []
        channel.each do |key, backend|
          addresses << backend.public_address
        end
        workers =  @worker_presence.list_for(addresses)
        deployed_versions = Hash.new {|h,k| h[k] =  Hash.new {|h,k| h[k] = []} }
        target_versions.each do |lang, versions|
          versions.each do |version|
            deployed_versions[lang][version] = []
          end
        end
        worker_ids = []
        workers.each do |worker|
          identity = worker[:identity]
          worker_ids << identity
          worker[:info]["deployed_versions"].each do |lang, versions|
            versions.each do |version|
              deployed_versions[lang][version] << identity
            end
          end
        end
        status[worker_class] = {
          online_workers: worker_ids,
          deployed_versions: deployed_versions
        }
      end
      status
    end

    def to_aws_credentials(raw_credentials)
      key = raw_credentials["access_key_id"]
      secret = raw_credentials["secret_access_key"]
      session = raw_credentials["session_token"]
      Aws::Credentials.new(key, secret, session)
    end

    def handle_with_worker(worker_class, req)
      if req.params_missing?
        puts "MISSING"
        error = {
          missing_params: req.missing_params
        }
        req.send_error("Missing mandatory paraneters", 502, error)
        return
      end
      if req.versioned?
        track_slug = req.parsed_msg["track_slug"]
        container_version = req.parsed_msg["container_version"]
        puts "CHECK VERSION #{worker_class} #{track_slug} #{container_version}"
        configured_versions = container_versions[worker_class][track_slug]
        if configured_versions.nil?
          req.send_error("No configuration for track_slug <#{track_slug}>", 502)
          return
        elsif !configured_versions.include?(container_version)
          req.send_error("Container <#{track_slug}>:<#{container_version}> is not deployed. Configured versions are: #{configured_versions}", 505)
          return
        end
      end
      channel = select_channel(worker_class)
      if channel.nil?
        req.send_error("worker_class <#{worker_class}> unrecognised", 502)
        return
      end
      select_backend_and_forward(req, channel)
    end

    def select_channel(worker_class)
      @backend_channels[worker_class]
    end

    def select_backend_and_forward(req, channel)
      addresses = []
      track_slug = req.parsed_msg["track_slug"]
      backend = channel[track_slug]
      if backend
        addresses << backend.public_address
        if backend.worker_available?
          forward(backend, req)
          return
        end
      end
      backend = channel["*"]
      if backend
        addresses << backend.public_address
        if backend.worker_available?
          forward(backend, req)
          return
        end
      end
      info = {
        current_worker_count: @worker_presence.count_for(addresses)
      }
      req.send_error("No workers available for <#{track_slug}>", 503, info)
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

      channel_entry = @backend_channels[channel]
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

    def update_container_versions(req)
      channel = req.parsed_msg["channel"]
      if channel.nil?
        req.send_error({ msg: "channel unknown" })
        return
      end
      track_slug = req.parsed_msg["track_slug"]
      # TODO error if args are bad
      if req.parsed_msg["action"] == "update_container_versions"
        versions = req.parsed_msg["versions"]
        config.update_container_versions!(channel, track_slug, versions)
      elsif req.parsed_msg["action"] == "deploy_container_version"
        new_version = req.parsed_msg["new_version"]
        config.add_container_version!(channel, track_slug, new_version)
      elsif req.parsed_msg["action"] == "unload_container_version"
        new_version = req.parsed_msg["new_version"]
        req.send_error({ msg: "action not yet implemented" })
      else
        req.send_error({ msg: "action unknown" })
        return
      end
      load_container_versions!
      req.send_result({ container_versions: container_versions })
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
