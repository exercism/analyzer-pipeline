module Pipeline::Rpc

  class WorkChannel

    def initialize(zmq_context, queue_address)
      @socket = zmq_context.socket(ZMQ::PUSH)
      @socket.setsockopt(ZMQ::SNDHWM, 1)
      @socket.bind(queue_address)

      @poller = ZMQ::Poller.new
      @poller.register(@socket, ZMQ::POLLOUT)
    end

    def worker_available?
      poll_result = @poller.poll(500)
      poll_result != -1 && @poller.writables.size > 0
    end

    def forward_to_backend(req, context=nil)
      m = req.parsed_msg.clone
      m[:context] = context unless context.nil?
      upstream_msg = [req.raw_address, "", m.to_json]
      @socket.send_strings(upstream_msg, ZMQ::DONTWAIT)
    end

  end

  class RequestRegister

    def initialize
      @in_flight = {}
    end

    def register(req)
      timeout_at = Time.now.to_i + 5
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

  class ServiceResponse

    def self.recv(socket)
      msg = ""
      socket.recv_string(msg)
      self.new(msg, socket)
    end

    attr_reader :parsed_msg

    def initialize(raw_msg, socket)
      @raw_msg = raw_msg
      @socket = socket
      @parsed_msg = JSON.parse(raw_msg)
    end

    def type
      @parsed_msg["msg_type"]
    end

    def return_address
      @parsed_msg["return_address"]
    end

    def binary_return_address
      return_address.pack("c*")
    end

    def raw_msg
      @raw_msg
    end

  end

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

  class Router
    attr_reader :zmq_context, :front_end_socket, :response_socket, :poller

    def initialize(zmq_context)
      @zmq_context = zmq_context

      @front_end_socket = zmq_context.socket(ZMQ::ROUTER)
      @front_end_socket.bind('tcp://*:5566')

      @in_flight_requests = RequestRegister.new

      @public_hostname = "localhost"
      @response_port = 5555

      @work_channel_ports = {
        static_analyzers: 5577,
        test_runners: 5578,
        representers: 5579
      }

      @response_socket = zmq_context.socket(ZMQ::SUB)
      @response_socket.setsockopt(ZMQ::SUBSCRIBE, "")
      @response_socket.bind("tcp://*:#{@response_port}")

      @poller = ZMQ::Poller.new
      @poller.register(@front_end_socket, ZMQ::POLLIN)
      @poller.register(@response_socket, ZMQ::POLLIN)

      @backend_channels = {}
      @work_channel_ports.each do |type, port|
        bind_address = "tcp://*:#{@work_channel_ports[type]}"
        work_channel = WorkChannel.new(zmq_context, bind_address)
        @backend_channels[type] = work_channel
      end

    end

    def run_heartbeater
      puts "STARTING heartbeat_socket"
      heartbeat_socket = zmq_context.socket(ZMQ::PUB)
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
      req = FrontEndRequest.recv(front_end_socket)
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

    def on_service_response
      msg = ServiceResponse.recv(response_socket)
      if msg.type == "response"
        @in_flight_requests.forward_response(msg)
        @in_flight_requests.unregister(msg.return_address)
      elsif msg.type == "heartbeat"
        @in_flight_requests.flush_expired_requests
        emit_current_spec
      else
        puts "Unrecognised message"
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
    end

    def respond_with_worker_config(req)
      analyzer_spec = analyzer_versions
      analyzer_spec[:channels] = {
        workqueue_address: "tcp://#{@public_hostname}:#{@work_channel_ports[:static_analyzers]}",
        response_address: "tcp://#{@public_hostname}:#{@response_port}"
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
